using TachikomaDemos
import ManyUIWeb
import Tachikoma

# ── Web UX overrides for TachikomaDemos ──
# We wrap the model instead of redefining methods globally,
# to avoid recompilation and modifying upstream files.
struct WebLauncherModel <: Tachikoma.Model
    inner::TachikomaDemos.LauncherModel
    term::Ref{Any}
end

Tachikoma.should_quit(m::WebLauncherModel) = Tachikoma.should_quit(m.inner)
Tachikoma.update!(m::WebLauncherModel, evt::Tachikoma.Event) = Tachikoma.update!(m.inner, evt)
function Tachikoma.init!(m::WebLauncherModel, t::Tachikoma.Terminal)
    m.term[] = t
    Tachikoma.init!(m.inner, t)
end

# 1. Single click to launch
function Tachikoma.update!(m::WebLauncherModel, evt::Tachikoma.MouseEvent)
    if evt.action == Tachikoma.mouse_press && evt.button == Tachikoma.mouse_left
        handled = Tachikoma.handle_mouse!(m.inner.tree, evt)
        if handled
            idx = TachikomaDemos._flat_row_to_demo_idx(m.inner.tree)
            if idx > 0
                m.inner.launch_idx = idx
                return
            end
        end
        return
    end
    Tachikoma.handle_mouse!(m.inner.tree, evt)
end

# 2. Hide "Press Enter to launch"
function Tachikoma.view(m::WebLauncherModel, f::Tachikoma.Frame)
    Tachikoma.view(m.inner, f)
    target = "Press Enter to launch"
    buf = f.buffer
    for y in max(1, f.area.height-5):f.area.height
        # Reconstruct string to find the text
        row_str = String([buf.content[Tachikoma.buf_index(buf, x, y)].char for x in 1:f.area.width])
        idx = findfirst(target, row_str)
        if idx !== nothing
            # Convert byte index to char index for correct column erasure
            char_start = length(row_str[1:prevind(row_str, idx.start)]) + 1
            char_stop = length(row_str[1:idx.stop])

            # Erase the text and the marker before it
            start_col = max(1, char_start - 2)
            end_col = min(f.area.width, char_stop)
            for x in start_col:end_col
                buf.content[Tachikoma.buf_index(buf, x, y)] = Tachikoma.Cell()
            end
        end
    end
end
function main()
    mode = length(ARGS) >= 1 ? ARGS[1] : "tui"
    if mode == "tui"
        TachikomaDemos.launcher()
    elseif mode == "webtui"

        server = ManyUIWeb.serve_tachikoma(() -> begin
            return function(s_out, s_w, s_h, s_term_hook)

                model = WebLauncherModel(TachikomaDemos.LauncherModel(), Ref{Any}(nothing))

                # Monkey patch DEMO_ENTRIES closures for this web session
                orig_entries = copy(TachikomaDemos.DEMO_ENTRIES)
                for i in 1:length(TachikomaDemos.DEMO_ENTRIES)
                    entry = orig_entries[i]

                    # Wrap the launch closure to use our web socket and dimensions
                    new_launch = () -> begin
                        orig_io = Tachikoma.DEFAULT_IO[]
                        orig_size = Tachikoma.DEFAULT_SIZE[]
                        orig_on_term = Tachikoma.DEFAULT_ON_TERMINAL[]

                        current_w = model.term[] !== nothing ? model.term[].size.width : s_w
                        current_h = model.term[] !== nothing ? model.term[].size.height : s_h

                        Tachikoma.DEFAULT_IO[] = s_out
                        Tachikoma.DEFAULT_SIZE[] = (rows=current_h, cols=current_w)
                        Tachikoma.DEFAULT_ON_TERMINAL[] = s_term_hook

                        try
                            entry.launch()
                        finally
                            Tachikoma.DEFAULT_IO[] = orig_io
                            Tachikoma.DEFAULT_SIZE[] = orig_size
                            Tachikoma.DEFAULT_ON_TERMINAL[] = orig_on_term
                        end
                    end

                    TachikomaDemos.DEMO_ENTRIES[i] = TachikomaDemos.DemoEntry(entry.name, entry.category, entry.description, new_launch)
                end

                try
                    while true
                        result = Tachikoma.app(model; fps=30, io=s_out, tty_size=(rows=s_h, cols=s_w), on_terminal=s_term_hook)
                        result === :restart && continue
                        model.inner.launch_idx == 0 && break
                        idx = model.inner.launch_idx
                        model.inner.quit = false
                        model.inner.launch_idx = 0
                        model.inner.tick = 0

                        try
                            TachikomaDemos.DEMO_ENTRIES[idx].launch()
                        catch e
                            e isa InterruptException && rethrow()
                            @warn "Demo exited with error" exception=(e, catch_backtrace())
                        end
                    end
                finally
                    # Restore original entries
                    for i in 1:length(orig_entries)
                        TachikomaDemos.DEMO_ENTRIES[i] = orig_entries[i]
                    end
                end
            end
        end; port=8000, title="Tachikoma Demos")
        wait(server)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
