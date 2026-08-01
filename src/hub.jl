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

function ManyUI.render(model::HubModel, ::TUI)
    lst = List(model.demos, (w) -> begin
        idx = w.sel.cursor
        if idx > 0 && idx <= length(model.demos)
            ManyUI.execute!(model, LaunchDemo(model.demos[idx]))
            app = ManyUI.app(w)
            app !== nothing && ManyUITUI.quit!(app)
        end
    end; id=:demolist)

    modes = ["tui", "web", "webtui"]
    rg = RadioGroup(modes, (w) -> begin
        idx = w.selected[]
        if idx > 0 && idx <= length(modes)
            ManyUI.execute!(model, SetMode(modes[idx]))
        end
    end; id=:backend_mode)
    
    # Initialize UI state
    idx = findfirst(==(model.mode), modes)
    if idx !== nothing
        rg.selected[] = idx
        rg.cursor[] = idx
    end

    Container(
        Label("🚀 ManyUI Demos Hub (Tab to focus list, Enter to launch)"),
        Label(""),
        Container(
            Container(Label("Choose Backend:"); classes=[:backend_label]),
            rg;
            classes=[:backend_panel]
        ),
        Label(""),
        lst,
        Label(""),
        Button("Quit", btn -> begin
            ManyUI.execute!(model, QuitHub())
            app = ManyUI.app(btn)
            app !== nothing && ManyUITUI.quit!(app)
        end)
    )
end

function run_hub()
    demos_dir = joinpath(pkgdir(@__MODULE__), "demos")
    demo_files = filter(f -> endswith(f, ".jl") && f != "tachikoma_web.jl", readdir(demos_dir))
    
    while true
        model = HubModel(demo_files, "", "tui", false)
        
        println("\nStarting ManyUI Hub...")
        ManyUITUI.launch(model, TUI())
        
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
