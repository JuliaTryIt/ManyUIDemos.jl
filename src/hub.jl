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
end

function ManyUI.execute!(model::HubModel, action::LaunchDemo)
    model.selected = action.filename
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
    #title { color: #7dd3fc; shrink: 0; }
    #backend_panel { layout: row; gap: 2; shrink: 0; border: round #475569; padding: 1; }
    #backend_label { color: #cbd5e1; }
    #demolist { grow: 1; border: round #475569; color: #e2e8f0; }
    Button { color: #bbf7d0; shrink: 0; }
    RadioGroup { color: #e2e8f0; }
""")

function ManyUI.render(model::HubModel, ::TUI)
    lst = List(model.demos, (w) -> begin
        idx = w.sel.cursor
        if idx > 0 && idx <= length(model.demos)
            ManyUI.execute!(model, LaunchDemo(model.demos[idx]))
            app = ManyUI.app(w)
            app !== nothing && ManyUITUI.quit!(app)
        end
    end; id=:demolist)

    display_modes = ["TUI", "Web (Native)", "WebTerm"]
    internal_modes = ["tui", "web", "webtui"]
    
    rg = RadioGroup(display_modes, (w) -> begin
        idx = w.selected[]
        if idx > 0 && idx <= length(display_modes)
            ManyUI.execute!(model, SetMode(internal_modes[idx]))
        end
    end; id=:backend_mode)
    
    # Initialize UI state
    idx = findfirst(==(model.mode), internal_modes)
    if idx !== nothing
        rg.selected[] = idx
        rg.cursor[] = idx
    end

    Container(
        Label("🚀 ManyUI Demos Hub (Tab to navigate, Space to select backend, Enter to launch)"; id=:title),
        Container(
            Label("Choose Backend:"; id=:backend_label),
            rg;
            id=:backend_panel
        ),
        lst,
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
        model = HubModel(demo_files, "", "tui", false)
        
        println("\nStarting ManyUI Hub...")
        ManyUITUI.launch(model, TUI(); stylesheet=HUB_SHEET)
        
        if model.should_quit || model.selected == ""
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
