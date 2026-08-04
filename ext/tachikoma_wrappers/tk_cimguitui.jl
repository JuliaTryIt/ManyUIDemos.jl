# tk_cimguitui.jl -- Tachikoma demo bridge for the ManyUICImGui TUI backend.
#
# Tachikoma has its own Terminal/Buffer/Cell model, distinct from ManyUI's.
# This bridge runs `Tachikoma.app(model)` with an injected IO sink and input
# pipe, then paints Tachikoma's cell grid into an ImGui window via ImDrawList.
# ImGui mouse/keyboard events are translated to SGR mouse bytes and ANSI key
# bytes that Tachikoma's existing input parser reads from the pipe.

using TachikomaDemos
using Tachikoma
using ManyUICImGui
using CImGui
using GLFW
using ModernGL

# ── Tachikoma color → ImGui packed RGBA ───────────────────────────────

_im_pack(r::UInt8, g::UInt8, b::UInt8, a::UInt8 = 0xff) =
    (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(g) << 8) | UInt32(r)

function _tk_color_rgb(c::Tachikoma.AbstractColor)::Tuple{UInt8,UInt8,UInt8}
    rgb = Tachikoma.to_rgb(c)
    return (rgb.r, rgb.g, rgb.b)
end

# ── Tachikoma Cell → ImGui render ─────────────────────────────────────

function _tk_paint_buffer!(dl, buf::Tachikoma.Buffer, ox::Float32, oy::Float32,
                           cell_w::Float32, cell_h::Float32, font,
                           font_size::Float32, bg_default::UInt32,
                           text_default::UInt32)
    area = buf.area
    for row in area.y:Tachikoma.bottom(area)
        for col in area.x:Tachikoma.right(area)
            idx = Tachikoma.buf_index(buf, col, row)
            cell = buf.content[idx]
            # Skip wide-char continuation cells
            cell.char == Tachikoma.WIDE_CHAR_PAD && continue

            px = ox + (col - area.x) * cell_w
            py = oy + (row - area.y) * cell_h

            # Background
            if !(cell.style.bg isa Tachikoma.NoColor)
                r, g, b = _tk_color_rgb(cell.style.bg)
                bg_col = _im_pack(r, g, b)
                cw = Float32(Tachikoma.cell_width(cell))
                CImGui.AddRectFilled(dl, (px, py),
                    (px + cw * cell_w, py + cell_h), bg_col)
            end

            # Foreground text
            glyph = Tachikoma.cell_glyph(cell)
            (isempty(glyph) || cell.char == ' ') && continue
            if cell.style.fg isa Tachikoma.NoColor
                fg_col = text_default
            else
                r, g, b = _tk_color_rgb(cell.style.fg)
                fg_col = _im_pack(r, g, b)
            end
            cw = Float32(Tachikoma.cell_width(cell))
            if cw == 2
                CImGui.AddText(dl, font, font_size, (px, py), fg_col,
                    glyph, C_NULL, 2 * cell_w)
            else
                CImGui.AddText(dl, font, font_size, (px, py), fg_col, glyph)
            end
        end
    end
end

# ── ImGui event → ANSI bytes for Tachikoma's input parser ─────────────

# Map ImGui keys to the ANSI escape sequences Tachikoma's parser expects.
const _TK_KEY_ESC = Dict{CImGui.lib.ImGuiKey, String}(
    CImGui.ImGuiKey_Enter      => "\r",
    CImGui.ImGuiKey_Backspace  => "\x7f",
    CImGui.ImGuiKey_Tab        => "\t",
    CImGui.ImGuiKey_Escape     => "\x1b",
    CImGui.ImGuiKey_UpArrow    => "\x1b[A",
    CImGui.ImGuiKey_DownArrow  => "\x1b[B",
    CImGui.ImGuiKey_RightArrow => "\x1b[C",
    CImGui.ImGuiKey_LeftArrow  => "\x1b[D",
    CImGui.ImGuiKey_Home       => "\x1b[H",
    CImGui.ImGuiKey_End        => "\x1b[F",
    CImGui.ImGuiKey_PageUp     => "\x1b[5~",
    CImGui.ImGuiKey_PageDown   => "\x1b[6~",
    CImGui.ImGuiKey_Insert     => "\x1b[2~",
    CImGui.ImGuiKey_Delete     => "\x1b[3~",
    CImGui.ImGuiKey_F1  => "\x1bOP",  CImGui.ImGuiKey_F2  => "\x1bOQ",
    CImGui.ImGuiKey_F3  => "\x1bOR",  CImGui.ImGuiKey_F4  => "\x1bOS",
    CImGui.ImGuiKey_F5  => "\x1b[15~", CImGui.ImGuiKey_F6  => "\x1b[17~",
    CImGui.ImGuiKey_F7  => "\x1b[18~", CImGui.ImGuiKey_F8  => "\x1b[19~",
    CImGui.ImGuiKey_F9  => "\x1b[20~", CImGui.ImGuiKey_F10 => "\x1b[21~",
    CImGui.ImGuiKey_F11 => "\x1b[23~", CImGui.ImGuiKey_F12 => "\x1b[24~",
)

function _tk_im_mods()::Tuple{Bool,Bool,Bool}
    shift = CImGui.IsKeyDown(CImGui.ImGuiKey_LeftShift) ||
            CImGui.IsKeyDown(CImGui.ImGuiKey_RightShift)
    alt   = CImGui.IsKeyDown(CImGui.ImGuiKey_LeftAlt) ||
            CImGui.IsKeyDown(CImGui.ImGuiKey_RightAlt)
    ctrl  = CImGui.IsKeyDown(CImGui.ImGuiKey_LeftCtrl) ||
            CImGui.IsKeyDown(CImGui.ImGuiKey_RightCtrl)
    return (shift, alt, ctrl)
end

function _tk_pump_keys!(input_pipe)
    for (ik, esc_seq) in _TK_KEY_ESC
        if CImGui.IsKeyPressed(ik, false)
            write(input_pipe, esc_seq)
        end
    end
    # Character input from ImGui's InputQueueCharacters (UTF-16 surrogate pairs)
    io = CImGui.GetIO()
    io_ptr = unsafe_load(convert(Ptr{CImGui.lib.ImGuiIO}, io))
    chars = io_ptr.InputQueueCharacters
    n = chars.Size
    data = chars.Data
    if n > 0 && data != C_NULL
        i = 0
        while i < n
            w = unsafe_load(data, i + 1)
            if 0xD800 <= w <= 0xDBFF && i + 1 < n
                w2 = unsafe_load(data, i + 2)
                if 0xDC00 <= w2 <= 0xDFFF
                    cp = 0x10000 + ((Int(w) - 0xD800) << 10) +
                         (Int(w2) - 0xDC00)
                    write(input_pipe, String(Char(cp)))
                    i += 2
                    continue
                end
            end
            # Skip control chars already sent as named keys
            if !(w in (0x0D, 0x0A, 0x09, 0x1B, 0x7F))
                write(input_pipe, String(Char(Int(w))))
            end
            i += 1
        end
    end
end

function _tk_pump_mouse!(input_pipe, ox::Float32, oy::Float32,
                         cell_w::Float32, cell_h::Float32,
                         cols::Int, rows::Int)
    shift, alt, ctrl = _tk_im_mods()
    mod_bits = (shift ? 4 : 0) | (alt ? 8 : 0) | (ctrl ? 16 : 0)

    mouse_pos = CImGui.GetMousePos()
    mx = Float32(mouse_pos.x)
    my = Float32(mouse_pos.y)
    cx = floor(Int, (mx - ox) / cell_w) + 1
    cy = floor(Int, (my - oy) / cell_h) + 1
    in_bounds = 1 <= cx <= cols && 1 <= cy <= rows

    for (btn, base) in ((CImGui.ImGuiMouseButton_Left, 0),
                        (CImGui.ImGuiMouseButton_Right, 2),
                        (CImGui.ImGuiMouseButton_Middle, 1))
        if CImGui.IsMouseClicked(btn, false) && in_bounds
            cb = base | mod_bits
            write(input_pipe, "\x1b[<$(cb);$(cx);$(cy)M")
        elseif CImGui.IsMouseReleased(btn) && in_bounds
            cb = base | mod_bits
            write(input_pipe, "\x1b[<$(cb);$(cx);$(cy)m")
        end
    end

    # Wheel
    io = CImGui.GetIO()
    io_ptr = unsafe_load(convert(Ptr{CImGui.lib.ImGuiIO}, io))
    wy = io_ptr.MouseWheel
    if wy > 0 && in_bounds
        cb = 64 | mod_bits
        write(input_pipe, "\x1b[<$(cb);$(cx);$(cy)M")
    elseif wy < 0 && in_bounds
        cb = 65 | mod_bits
        write(input_pipe, "\x1b[<$(cb);$(cx);$(cy)M")
    end
end

# ── The bridge: run Tachikoma.app + ImGui render loop ─────────────────

mutable struct TkBridgeState
    term::Union{Nothing, Tachikoma.Terminal}
    cols::Int
    rows::Int
end

function _tk_cimguitui_render(st, input_pipe, cols, rows)
    # Resolve font and cell pitch
    font = CImGui.GetFont()
    fs = CImGui.GetFontSize()
    CImGui.PushFont(font, fs)
    sz = CImGui.CalcTextSize("M")
    CImGui.PopFont()
    cell_w = Float32(sz.x)
    cell_h = CImGui.GetTextLineHeight()
    cell_w <= 0 && (cell_w = fs * 0.6)
    cell_h <= 0 && (cell_h = fs)

    avail = CImGui.GetContentRegionAvail()
    avail_w = Float32(avail.x)
    avail_h = Float32(avail.y)
    new_cols = max(1, floor(Int, avail_w / cell_w))
    new_rows = max(1, floor(Int, avail_h / cell_h))

    # Resize the Tachikoma terminal when the window changed size
    if st.term !== nothing && (new_cols != st.cols || new_rows != st.rows)
        st.cols = new_cols
        st.rows = new_rows
        Tachikoma.set_size!(st.term, (cols=new_cols, rows=new_rows))
    end

    pos = CImGui.GetCursorScreenPos()
    ox = Float32(pos.x)
    oy = Float32(pos.y)

    # Pump ImGui events → Tachikoma input pipe
    _tk_pump_keys!(input_pipe)
    _tk_pump_mouse!(input_pipe, ox, oy, cell_w, cell_h, cols, rows)

    # Paint the Tachikoma buffer
    if st.term !== nothing
        buf = Tachikoma.current_buf(st.term)
        dl = CImGui.GetWindowDrawList()
        bg_ptr = CImGui.GetStyleColorVec4(CImGui.ImGuiCol_WindowBg)
        bg = unsafe_load(bg_ptr)
        bg_col = _im_pack(UInt8(round(bg.x * 255)),
                          UInt8(round(bg.y * 255)),
                          UInt8(round(bg.z * 255)),
                          UInt8(round(bg.w * 255)))
        text_col = _im_pack(0xff, 0xff, 0xff, 0xff)
        _tk_paint_buffer!(dl, buf, ox, oy, cell_w, cell_h, font, fs,
                          bg_col, text_col)
    end

    CImGui.Dummy((avail_w, avail_h))
end

"""
    tk_cimguitui(model_factory; title, width, height, fps)

Run a Tachikoma model inside an ImGui window using the TUI cell-grid renderer.
The model_factory is `() -> Tachikoma.Model`.
"""
function tk_cimguitui(model_factory::Function;
                      title::String = "Tachikoma CImGui TUI",
                      width::Integer = 1280,
                      height::Integer = 720,
                      fps::Integer = 30)
    # Input pipe: ImGui writes ANSI bytes here, Tachikoma reads them
    pipe = Base.Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true,
                    writer_supports_async = true)
    input_reader = pipe.in
    input_writer = pipe.out

    st = TkBridgeState(nothing, 100, 30)

    # Run Tachikoma.app in a task with injected io and input
    tachikoma_task = @async begin
        try
            model = model_factory()
            # Use an IOBuffer as the output sink (we read the buffer directly
            # from the Terminal, not from the io sink)
            sink = IOBuffer()
            Tachikoma.app(model;
                io = sink,
                input = input_reader,
                tty_size = (rows = st.rows, cols = st.cols),
                fps = fps,
                on_terminal = t -> begin
                    st.term = t
                end)
        catch e
            e isa InterruptException || rethrow()
        end
    end

    # ImGui render loop
    draw = () -> begin
        flags = CImGui.ImGuiWindowFlags_NoTitleBar |
                CImGui.ImGuiWindowFlags_NoResize |
                CImGui.ImGuiWindowFlags_NoMove |
                CImGui.ImGuiWindowFlags_NoCollapse |
                CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus |
                CImGui.ImGuiWindowFlags_NoNavFocus |
                CImGui.ImGuiWindowFlags_NoScrollbar |
                CImGui.ImGuiWindowFlags_NoScrollWithMouse
        CImGui.SetNextWindowPos((0, 0), CImGui.ImGuiCond_Always, (0, 0))
        CImGui.SetNextWindowSize((Float32(width), Float32(height)),
            CImGui.ImGuiCond_Always)
        is_open = Ref(true)
        CImGui.Begin(title, is_open, flags)
        try
            _tk_cimguitui_render(st, input_writer, st.cols, st.rows)
        finally
            CImGui.End()
        end
        nothing
    end

    try
        ManyUICImGui.launch_imgui(draw; width = width, height = height,
                                  title = title, wait = true)
    finally
        # Close the input pipe to unblock Tachikoma's stdin monitor
        close(input_writer)
        close(input_reader)
        # Wait for Tachikoma to finish
        try; wait(tachikoma_task); catch; end
    end
end

function main()
    mode = length(ARGS) >= 1 ? ARGS[1] : "cimguitui"
    if mode == "cimguitui"
        println("🖥️  User input: CImGui TUI window (terminal grid)")
        tk_cimguitui(() -> TachikomaDemos.LauncherModel();
                     title = "Tachikoma Demos (CImGui TUI)")
    elseif mode == "tui"
        TachikomaDemos.launcher()
    elseif mode == "webtui"
        # Fall back to the existing webtui path from tk_launcher.jl
        include(joinpath(@__DIR__, "tk_launcher.jl"))
        empty!(ARGS); push!(ARGS, "webtui")
        Main.main()
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end