module HubApp

using ManyUI, ManyUITUI
using ManyUIWeb

struct QuitHub <: Action end
struct LaunchDemo <: Action
    filename::String
end

mutable struct HubModel
    demos::Vector{String}
    selected::String
    mode::String
    should_quit::Bool
    launch_requested::Bool
    port::Int
end

function ManyUI.execute!(model::HubModel, action::LaunchDemo)
    model.selected = action.filename
    model.launch_requested = true
    model.should_quit = false
end

struct SetMode <: Action
    mode::String
end

function ManyUI.execute!(model::HubModel, action::SetMode)
    model.mode = action.mode
end

function ManyUI.execute!(model::HubModel, action::QuitHub)
    model.should_quit = true
end

const HUB_SHEET = parse_css("""
    #screen { layout: column; gap: 1; padding: 1; }
    #header { color: #7dd3fc; shrink: 0; }
    #main_area { layout: row; gap: 2; grow: 1; }
    #left_panel { layout: column; gap: 1; width: 30; shrink: 0; }
    #demolist { grow: 1; border: round #475569; color: #e2e8f0; }

    #right_panel { layout: column; gap: 1; grow: 1; border: round #475569; padding: 1; }
    #demo_title { color: #bae6fd; shrink: 0; }
    #demo_desc { color: #f1f5f9; grow: 1; }
    #compat_label { color: #94a3b8; shrink: 0; }
    #backend_panel { layout: column; gap: 1; shrink: 0; }
    #backend_label { color: #cbd5e1; }
    #btn_panel { layout: row; gap: 2; shrink: 0; }

    Button { color: #bbf7d0; shrink: 0; }
    .primary_btn { color: #000000; background: #22c55e; }
    RadioGroup { color: #e2e8f0; }
""")

const COMPAT_MATRIX = Dict(
    "dashboard.jl" => (tui=true, web=true, webtui=true, cimgui=false, cimguitui=true),
    "datatable.jl" => (tui=true, web=true, webtui=true, cimgui=true, cimguitui=true),
    "gallery.jl"   => (tui=true, web=true, webtui=true, cimgui=true, cimguitui=true),
    "scrollpane.jl"=> (tui=true, web=true, webtui=true, cimgui=false, cimguitui=true),
    "unicode.jl"   => (tui=true, web=true, webtui=true, cimgui=true, cimguitui=true),
    "life.jl"      => (tui=true, web=true, webtui=true, cimgui=false, cimguitui=true),
    "rain.jl"      => (tui=true, web=true, webtui=true, cimgui=false, cimguitui=true),
    "snake.jl"     => (tui=true, web=true, webtui=true, cimgui=false, cimguitui=true),
)
const DEMO_PATHS = Dict{String, String}()

const DEMO_DESCRIPTIONS = Dict(
    "dashboard.jl" => "Interactive Dashboard\n\nA comprehensive showcase of UI elements including search filtering, reactive lists, and complex flexbox layouts.",
    "datatable.jl" => "High-Performance Grid\n\nA spreadsheet-like data table widget. Features keyboard navigation, row selection, and smooth scrolling over large datasets.",
    "gallery.jl"   => "Widget Gallery\n\nA tour of all standard ManyUI components: buttons, text inputs, radio groups, checkboxes, and layout primitives.",
    "scrollpane.jl"=> "Nested Scrolling\n\nTests the limits of the clipping engine with deeply nested scrollable areas and dynamic content injection (like a live log tailer).",
    "unicode.jl"   => "Unicode & Wide Chars\n\nValidates the ANSI encoder's ability to render complex emojis, CJK wide characters, and zero-width joiners accurately.",
    "life.jl"      => "Conway's Game of Life\n\nAn animated simulation of cellular automata. (Web Only)",
    "rain.jl"      => "Digital Rain\n\nA Matrix-inspired falling text animation using dynamic colors. (Web Only)",
    "snake.jl"     => "Snake Game\n\nA fully playable classic Snake game built entirely with UI primitives. (Web Only)"
)

function register_demo!(name::String, description::String, path::String, compat=nothing)
    DEMO_DESCRIPTIONS[name] = description
    DEMO_PATHS[name] = path
    if compat !== nothing
        compat_full = (
            tui = hasproperty(compat, :tui) ? compat.tui : false,
            web = hasproperty(compat, :web) ? compat.web : false,
            webtui = hasproperty(compat, :webtui) ? compat.webtui : false,
            cimgui = hasproperty(compat, :cimgui) ? compat.cimgui : false,
            cimguitui = hasproperty(compat, :cimguitui) ? compat.cimguitui : false
        )
        COMPAT_MATRIX[name] = compat_full
    end
end

struct SelectDemo <: Action
    idx::Int
end

function ManyUI.execute!(model::HubModel, action::SelectDemo)
    if action.idx > 0 && action.idx <= length(model.demos)
        model.selected = model.demos[action.idx]
        compat = get(COMPAT_MATRIX, model.selected,
            (tui=true, web=true, webtui=true, cimgui=true, cimguitui=true))

        if model.mode == "tui" && !compat.tui
            model.mode = compat.web ? "web" : "webtui"
        elseif model.mode == "web" && !compat.web
            model.mode = compat.tui ? "tui" : "webtui"
        elseif model.mode == "webtui" && !compat.webtui
            model.mode = compat.web ? "web" : "tui"
        elseif model.mode == "cimgui" && !compat.cimgui
            model.mode = compat.cimguitui ? "cimguitui" :
                         (compat.web ? "web" : "tui")
        elseif model.mode == "cimguitui" && !compat.cimguitui
            model.mode = compat.cimgui ? "cimgui" :
                         (compat.web ? "web" : "tui")
        end
    end
end

import ManyUICImGui

function backend_capabilities_table(mode::String)
    mode_name = Dict("tui" => "TUI", "web" => "Web Native",
                     "webtui" => "WebTerm", "cimgui" => "CImGui",
                     "cimguitui" => "CImGui TUI")[mode]

    b = if mode == "tui"
        ManyUITUI.TerminalBackend()
    elseif mode == "web"
        ManyUI.WebNative()
    elseif mode == "webtui"
        ManyUIWeb.WebBackend()
    elseif mode == "cimgui"
        ManyUICImGui.ImGuiBackend()
    elseif mode == "cimguitui"
        ManyUICImGui.ImGuiTUIBackend()
    end

    caps = ManyUI.backend_capabilities(b)

    lines = ["Capabilities for $mode_name:",
             "+-----------------+------+",
             "| Capability      | OK?  |",
             "+-----------------+------+"]

    for k in keys(caps)
        val = getproperty(caps, k)
        mark = val ? " Yes" : " No "
        padded_k = rpad(String(k), 15)
        push!(lines, "| $padded_k | $mark |")
    end
    push!(lines, "+-----------------+------+")
    return join(lines, "\n")
end

function update_hub_ui!(app, model)
    title = ManyUI.query_one(app.root, "#demo_title", Label)
    if title !== nothing
        title.text[] = "$(model.selected)"
    end

    desc = ManyUI.query_one(app.root, "#demo_desc", Label)
    if desc !== nothing
        desc.text[] = get(DEMO_DESCRIPTIONS, model.selected, "No description available.")
    end

    ct = ManyUI.query_one(app.root, "#compat_table", Label)
    if ct !== nothing
        ct.text[] = backend_capabilities_table(model.mode)
    end

    launch_text = if model.mode == "web"
        "🌐 Launch Web Server (opens port 8000)"
    elseif model.mode == "tui"
        "📺 Launch in Terminal"
    elseif model.mode == "webtui"
        "🖥️ Launch WebTerm (opens port 8000)"
    elseif model.mode == "cimgui"
        "🖼️ Launch CImGui Window (native widgets)"
    else
        "🖥️ Launch CImGui TUI (terminal grid)"
    end

    btn = ManyUI.query_one(app.root, "#launch_btn", Button)
    if btn !== nothing
        btn.label[] = "🚀 " * launch_text
    end

    rg = ManyUI.query_one(app.root, "#backend_mode", RadioGroup)
    if rg !== nothing
        compat = get(COMPAT_MATRIX, model.selected,
            (tui=true, web=true, webtui=true, cimgui=true, cimguitui=true))
        disabled_set = Set{Int}()
        !compat.tui && push!(disabled_set, 1)
        !compat.web && push!(disabled_set, 2)
        !compat.webtui && push!(disabled_set, 3)
        !compat.cimgui && push!(disabled_set, 4)
        !compat.cimguitui && push!(disabled_set, 5)
        rg.disabled[] = disabled_set

        internal_modes = ["tui", "web", "webtui", "cimgui", "cimguitui"]
        idx_mode = findfirst(==(model.mode), internal_modes)
        if idx_mode !== nothing
            rg.selected[] = idx_mode
            rg.cursor[] = idx_mode
        end
    end
end

function ManyUI.render(model::HubModel, ::TUI)
    lst = List(model.demos, (w) -> begin
        ManyUI.execute!(model, SelectDemo(w.sel.cursor))
        app = ManyUI.app(w)
        app !== nothing && update_hub_ui!(app, model)
    end; on_change = (w) -> begin
        ManyUI.execute!(model, SelectDemo(w.sel.cursor))
        app = ManyUI.app(w)
        app !== nothing && update_hub_ui!(app, model)
    end, id=:demolist)

    # Initialize list selection
    idx = findfirst(==(model.selected), model.demos)
    if idx !== nothing
        lst.sel.cursor = idx
        lst.sel.anchor = idx
    end

    display_modes = ["TUI", "Web (Native)", "WebTerm",
                     "CImGui (Native)", "CImGui TUI"]
    internal_modes = ["tui", "web", "webtui", "cimgui", "cimguitui"]

    compat = get(COMPAT_MATRIX, model.selected,
        (tui=true, web=true, webtui=true, cimgui=true, cimguitui=true))
    disabled_set = Set{Int}()
    !compat.tui && push!(disabled_set, 1)
    !compat.web && push!(disabled_set, 2)
    !compat.webtui && push!(disabled_set, 3)
    !compat.cimgui && push!(disabled_set, 4)
    !compat.cimguitui && push!(disabled_set, 5)

    rg = RadioGroup(display_modes, (w) -> begin
        idx = w.selected[]
        if idx > 0 && idx <= length(display_modes)
            ManyUI.execute!(model, SetMode(internal_modes[idx]))
            app = ManyUI.app(w)
            app !== nothing && update_hub_ui!(app, model)
        end
    end; disabled=disabled_set, id=:backend_mode)

    idx_mode = findfirst(==(model.mode), internal_modes)
    if idx_mode !== nothing
        rg.selected[] = idx_mode
        rg.cursor[] = idx_mode
    end

    launch_text = if model.mode == "web"
        "🌐 Launch Web Server (opens port $(model.port))"
    elseif model.mode == "tui"
        "📺 Launch in Terminal"
    elseif model.mode == "webtui"
        "🖥️ Launch WebTerm (opens port $(model.port))"
    elseif model.mode == "cimgui"
        "🖼️ Launch CImGui Window (native widgets)"
    else
        "🖥️ Launch CImGui TUI (terminal grid)"
    end

    right_panel = Container(
        Label("$(model.selected)"; id=:demo_title),
        Label(get(DEMO_DESCRIPTIONS, model.selected, "No description available."); id=:demo_desc),
        Label(backend_capabilities_table(model.mode); id=:compat_table),
        Label(""),
        Container(
            Label("Choose Backend:"; id=:backend_label),
            rg;
            id=:backend_panel
        ),
        Label(""),
        Container(
            Button("🚀 " * launch_text, btn -> begin
                ManyUI.execute!(model, LaunchDemo(model.selected))
                app = ManyUI.app(btn)
                app !== nothing && ManyUITUI.quit!(app)
            end; classes=[:primary_btn], id=:launch_btn),
            id=:btn_panel
        );
        id=:right_panel
    )

    Container(
        Label("🚀 ManyUI Demos Hub (Tab to navigate)"; id=:header),
        Container(
            Container(
                Label("Demos List:"),
                lst;
                id=:left_panel
            ),
            right_panel;
            id=:main_area
        ),
        Button("Quit", btn -> begin
            ManyUI.execute!(model, QuitHub())
            app = ManyUI.app(btn)
            app !== nothing && ManyUITUI.quit!(app)
        end);
        id=:screen
    )
end

const HUB_BACKENDS = Dict{String,Function}(
    "tui"      => (model; kwargs...) ->
        ManyUITUI.launch(model, TUI(); stylesheet=get(kwargs, :stylesheet,
                                                      HUB_SHEET)),
    "web"      => (model; kwargs...) ->
        _launch_web_hub(model, ManyUI.WebNative();
                        port=get(kwargs, :port, 8000),
                        stylesheet=get(kwargs, :stylesheet, HUB_SHEET)),
    "webtui"   => (model; kwargs...) ->
        ManyUITUI.launch(model, TUI();
                         backend=ManyUIWeb.WebBackend(),
                         port=get(kwargs, :port, 8000),
                         stylesheet=get(kwargs, :stylesheet, HUB_SHEET)),
    "cimgui"   => (model; kwargs...) ->
        ManyUICImGui.launch_manyui(() -> ManyUI.render(model, TUI());
                                   title="ManyUI Hub (CImGui)"),
    "cimguitui"=> (model; kwargs...) ->
        ManyUICImGui.launch_tui(() -> ManyUI.render(model, TUI());
                                title="ManyUI Hub (CImGui TUI)",
                                stylesheet=HUB_SHEET),
)

# Web-native hub needs the server to block until the user returns, so the
# hub loop can resume in the console after the demo is launched.
function _launch_web_hub(model, backend; port::Int=8000, kwargs...)
    server = ManyUITUI.launch(() -> ManyUI.render(model, TUI()), backend;
                              port=port, wait=false, kwargs...)
    println("🌐 Hub running at ", ManyUIWeb.url(server))
    println("👉 User input: browser (", ManyUIWeb.url(server), ")")
    println("   Press Enter in this console to stop the hub server.")
    try
        readline()
    catch e
        e isa InterruptException || rethrow()
    finally
        ManyUITUI.stop!(server)
    end
end

# Where the user's interaction continues after the hub is launched, per
# backend. Printed BEFORE the hub blocks so the user knows where to look.
const HUB_FLUX_MESSAGE = Dict{String,String}(
    "tui"       => "📺 User input: console (terminal)",
    "web"       => "🌐 User input: browser (http://127.0.0.1:%port%)",
    "webtui"    => "🖥️  User input: browser (http://127.0.0.1:%port%)",
    "cimgui"    => "🖼️  User input: CImGui window (native widgets)",
    "cimguitui" => "🖥️  User input: CImGui TUI window (terminal grid)",
)

# Where the user's interaction continues after a DEMO is launched, per
# mode. Printed so the user always knows where to look.
const DEMO_FLUX_MESSAGE = Dict{String,String}(
    "tui"       => "📺 User input: console (terminal)",
    "web"       => "🌐 User input: browser (http://127.0.0.1:%port%)",
    "webtui"    => "🖥️  User input: browser (http://127.0.0.1:%port%)",
    "cimgui"    => "🖼️  User input: CImGui window (native widgets)",
    "cimguitui" => "🖥️  User input: CImGui TUI window (terminal grid)",
)

function run_hub(port::Int=8000; hub_backend::String="tui")
    demos_dir = joinpath(pkgdir(@__MODULE__), "demos")
    demo_files = filter(f -> endswith(f, ".jl") && f != "tachikoma_web.jl", readdir(demos_dir))

    for f in demo_files
        DEMO_PATHS[f] = joinpath(demos_dir, f)
    end

    all_demos = sort(collect(keys(DEMO_PATHS)))

    # Validate the hub backend.
    hub_launcher = get(HUB_BACKENDS, hub_backend) do
        nothing
    end
    if hub_launcher === nothing
        error("Unknown hub backend: '$hub_backend'. " *
              "Valid: $(join(sort(collect(keys(HUB_BACKENDS))), ", "))")
    end

    while true
        model = HubModel(all_demos, isempty(all_demos) ? "" : all_demos[1],
                         "tui", false, false, port)

        # Default the demo mode to the hub backend if it is compatible,
        # so launching a demo from a web/cimgui hub does not drop back to
        # the terminal unexpectedly.
        if hasproperty(COMPAT_MATRIX[model.selected], Symbol(hub_backend))
            if getproperty(COMPAT_MATRIX[model.selected], Symbol(hub_backend))
                model.mode = hub_backend
            end
        end

        println("\nStarting ManyUI Hub (backend: $hub_backend)...")
        flux_msg = get(HUB_FLUX_MESSAGE, hub_backend, "")
        if occursin("%port%", flux_msg)
            flux_msg = replace(flux_msg, "%port%" => string(port))
        end
        println(flux_msg)

        hub_launcher(model; port=port, stylesheet=HUB_SHEET)

        if model.should_quit || !model.launch_requested
            println("Exiting hub.")
            break
        end

        println("\n=======================================================")
        println("Launching: $(model.selected) in $(model.mode) mode")
        # Always tell the user where the demo's interaction continues.
        demo_flux = get(DEMO_FLUX_MESSAGE, model.mode, "")
        if occursin("%port%", demo_flux)
            demo_flux = replace(demo_flux, "%port%" => string(model.port))
        end
        println(demo_flux)
        println("=======================================================\n")

        demo_path = DEMO_PATHS[model.selected]
        retry_launch = true
        while retry_launch
            retry_launch = false

            stop_monitor = false
            main_task = current_task()
            esc_task = nothing
            if model.mode in ("web", "webtui")
                println("🌐 Server should be running at: http://127.0.0.1:$(model.port)")
                println("Press Enter in this console to stop the server and return to Hub.")
                esc_task = @async begin
                    try
                        # Wait for the user to press Enter
                        readline()
                        if !stop_monitor
                            # Throw an InterruptException locally to unblock wait(server)
                            Base.throwto(main_task, InterruptException())
                        end
                    catch
                    end
                end
            elseif model.mode in ("cimgui", "cimguitui")
                println("🖥️  CImGui window should be open. Close it to return to Hub.")
            end

            try
                # We use a persistent module per demo so Revise.jl works correctly
                mod_sym = Symbol("Demo_", replace(model.selected, r"[^a-zA-Z0-9]" => ""))
                if !isdefined(Main, mod_sym)
                    Core.eval(Main, :(module $mod_sym end))
                end
                m = Core.eval(Main, mod_sym)
                Core.eval(m, :(ARGS = [$(model.mode), string($(model.port))]))

                if isdefined(Main, :Revise)
                    Core.eval(Main, :(Revise.includet($m, $demo_path)))
                else
                    Base.include(m, demo_path)
                end

                if isdefined(m, :main)
                    Core.eval(m, :(Base.invokelatest(main)))
                else
                    println("Error: No main() function found in $(model.selected)")
                end
            catch e
                stop_monitor = true
                if esc_task !== nothing && !istaskdone(esc_task)
                    Base.throwto(esc_task, InterruptException())
                end

                err = e isa LoadError ? e.error : e
                if err isa ManyUIWeb.PortInUseError || (err isa Base.IOError && err.code == Base.UV_EADDRINUSE)
                    port_in_use = err isa ManyUIWeb.PortInUseError ? err.port : model.port
                    println("\n⚠️  Port $port_in_use is already in use!")
                    if Sys.isunix()
                        try
                            # lsof -t -i:<port> returns just the PIDs
                            pids = split(strip(read(`lsof -t -i:$port_in_use`, String)))
                            if !isempty(pids) && !all(isempty, pids)
                                println("It seems PID(s) $(join(pids, ", ")) are using this port.")
                                print("Do you want to kill them to free the port? [y/N]: ")
                                ans = lowercase(strip(readline()))
                                if ans == "y" || ans == "yes"
                                    for pid in pids
                                        run(ignorestatus(`kill -9 $pid`))
                                    end
                                    println("✅ Processes killed. Relaunching the server now...")
                                    retry_launch = true
                                    continue
                                end
                            end
                        catch
                            println("Could not automatically determine or kill the process holding the port.")
                        end
                    end
                elseif !(err isa InterruptException)
                    println(stderr, "\n❌ DEMO CRASHED:")
                    println(stderr, "Hub caught exception: ", typeof(err))
                    Base.showerror(stderr, e, catch_backtrace())
                    println(stderr, "\n")
                end
                println("Demo exited or was interrupted.")
            finally
                stop_monitor = true
            end
            if !retry_launch
                println("\nPress Enter to return to the Hub...")
                readline()
            end
        end
    end
end

end # module
