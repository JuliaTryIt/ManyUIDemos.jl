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
    #compat_label { color: #94a3b8; shrink: 0; }
    #backend_panel { layout: column; gap: 1; shrink: 0; }
    #backend_label { color: #cbd5e1; }
    #btn_panel { layout: row; gap: 2; shrink: 0; }
    
    Button { color: #bbf7d0; shrink: 0; }
    .primary_btn { color: #000000; background: #22c55e; }
    RadioGroup { color: #e2e8f0; }
""")

const COMPAT_MATRIX = Dict(
    "dashboard.jl" => (tui=true, web=true, webtui=true),
    "datatable.jl" => (tui=true, web=true, webtui=true),
    "gallery.jl"   => (tui=true, web=true, webtui=true),
    "scrollpane.jl"=> (tui=true, web=true, webtui=true),
    "unicode.jl"   => (tui=true, web=true, webtui=true),
    "life.jl"      => (tui=false, web=true, webtui=false),
    "rain.jl"      => (tui=false, web=true, webtui=false),
    "snake.jl"     => (tui=false, web=true, webtui=false),
)

struct SelectDemo <: Action
    idx::Int
end

function ManyUI.execute!(model::HubModel, action::SelectDemo)
    if action.idx > 0 && action.idx <= length(model.demos)
        model.selected = model.demos[action.idx]
        compat = get(COMPAT_MATRIX, model.selected, (tui=true, web=true, webtui=true))
        # Auto-select web if tui is not supported
        if model.mode == "tui" && !compat.tui
            model.mode = "web"
        end
    end
end

function ManyUI.render(model::HubModel, ::TUI)
    lst = List(model.demos, (w) -> begin
        ManyUI.execute!(model, SelectDemo(w.sel.cursor))
    end; id=:demolist)
    
    # Initialize list selection
    idx = findfirst(==(model.selected), model.demos)
    if idx !== nothing
        lst.sel.cursor = idx
        lst.sel.anchor = idx
    end

    display_modes = ["TUI", "Web (Native)", "WebTerm"]
    internal_modes = ["tui", "web", "webtui"]
    
    rg = RadioGroup(display_modes, (w) -> begin
        idx = w.selected[]
        if idx > 0 && idx <= length(display_modes)
            ManyUI.execute!(model, SetMode(internal_modes[idx]))
        end
    end; id=:backend_mode)
    
    idx_mode = findfirst(==(model.mode), internal_modes)
    if idx_mode !== nothing
        rg.selected[] = idx_mode
        rg.cursor[] = idx_mode
    end

    compat = get(COMPAT_MATRIX, model.selected, (tui=true, web=true, webtui=true))
    t_icon = compat.tui ? "✅" : "❌"
    w_icon = compat.web ? "✅" : "❌"
    wt_icon = compat.webtui ? "✅" : "❌"
    
    compat_text = "Compatibility:  $t_icon TUI   $w_icon Web Native   $wt_icon WebTerm"
    
    launch_text = if model.mode == "web"
        "🌐 Launch Web Server (opens port 8000)"
    elseif model.mode == "tui"
        "📺 Launch in Terminal"
    else
        "🖥️ Launch WebTerm (opens port 8000)"
    end

    right_panel = Container(
        Label("$(model.selected)"; id=:demo_title),
        Label(compat_text; id=:compat_label),
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
            end; classes=[:primary_btn]),
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

function run_hub()
    demos_dir = joinpath(pkgdir(@__MODULE__), "demos")
    demo_files = filter(f -> endswith(f, ".jl") && f != "tachikoma_web.jl", readdir(demos_dir))
    
    while true
        model = HubModel(demo_files, isempty(demo_files) ? "" : demo_files[1], "tui", false, false)
        
        println("\nStarting ManyUI Hub...")
        ManyUITUI.launch(model, TUI(); stylesheet=HUB_SHEET)
        
        if model.should_quit || !model.launch_requested
            println("Exiting hub.")
            break
        end
        
        println("\n=======================================================")
        println("Launching: $(model.selected) in $(model.mode) mode")
        println("=======================================================\n")
        
        demo_path = joinpath(demos_dir, model.selected)
        
        # Run the demo as a subprocess so it gets a clean environment and terminal state
        try
            cmd = `$(Base.julia_cmd()) --project=$(pkgdir(@__MODULE__)) $demo_path $(model.mode)`
            run(cmd)
        catch e
            println("Demo exited or was interrupted.")
        end
        
        println("\nPress Enter to return to the Hub...")
        readline()
    end
end

end # module
