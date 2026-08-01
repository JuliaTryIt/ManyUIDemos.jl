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
    should_quit::Bool
end

function ManyUI.execute!(model::HubModel, action::LaunchDemo)
    model.selected = action.filename
    model.should_quit = false
end

function ManyUI.execute!(model::HubModel, action::QuitHub)
    model.should_quit = true
end

function ManyUI.render(model::HubModel, ::TUI)
    lst = List(model.demos; id=:demolist)
    
    # Listen to Enter key on the list to launch
    ManyUI.on!(lst, :submit, (w) -> begin
        if w.selected > 0 && w.selected <= length(model.demos)
            ManyUI.execute!(model, LaunchDemo(model.demos[w.selected]))
            app = ManyUI.app(w)
            app !== nothing && ManyUITUI.quit!(app)
        end
    end)
    
    lst.focusable = true

    Container(
        Label("🚀 ManyUI Demos Hub (Tab to focus list, Enter to launch)"),
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
        model = HubModel(demo_files, "", false)
        
        println("\nStarting ManyUI Hub...")
        ManyUITUI.launch(model, TUI())
        
        if model.should_quit || model.selected == ""
            println("Exiting hub.")
            break
        end
        
        println("\n=======================================================")
        println("Launching: $(model.selected)")
        println("=======================================================\n")
        
        demo_path = joinpath(demos_dir, model.selected)
        
        # Run the demo as a subprocess so it gets a clean environment and terminal state
        try
            cmd = `$(Base.julia_cmd()) --project=$(pkgdir(@__MODULE__)) $demo_path`
            run(cmd)
        catch e
            println("Demo exited or was interrupted.")
        end
        
        println("\nPress Enter to return to the Hub...")
        readline()
    end
end

end # module
