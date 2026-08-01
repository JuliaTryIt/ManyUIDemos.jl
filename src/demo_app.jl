module DemoApp

using ManyUI, ManyUITUI
using ManyUIWeb

using Dates

# ==========================================
# 1. Domain & Actions (The Core Model)
# ==========================================
struct Save <: Action
    filename::String
end

struct Quit <: Action end

mutable struct MyModel
    current_file::String
    unsaved_changes::Bool
    log::Vector{String}
end

# ==========================================
# 2. Action Execution (Domain Logic)
# ==========================================
function ManyUI.execute!(model::MyModel, action::Save)
    timestamp = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")
    push!(model.log, "[$timestamp] Saved data to $(action.filename)")
    model.unsaved_changes = false
end

function ManyUI.execute!(model::MyModel, action::Quit)
    timestamp = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")
    push!(model.log, "[$timestamp] Quitting...")
end

# ==========================================
# 3. Presentation & Routing (Multiple Dispatch)
# ==========================================

# 3.1 TUI Projection
function ManyUI.render(model::MyModel, ::TUI)
    # Build the visual widget tree using ManyUI, ManyUITUI components
    log_labels = [Label(msg) for msg in model.log]
    
    Container(
        Label("File: $(model.current_file) (Unsaved: $(model.unsaved_changes))"),
        Button("Save", _ -> ManyUI.execute!(model, Save(model.current_file))),
        Button("Quit", btn -> begin
            ManyUI.execute!(model, Quit())
            app = ManyUI.app(btn)
            if app !== nothing
                ManyUITUI.quit!(app)
            end
        end),
        Container(
            Label("--- System Log ---"),
            log_labels...;
            classes=[:log_panel]
        )
    )
end

# 3.2 WebTerminal Projection (Terminal Emulation)
function ManyUI.render(model::MyModel, ::WebTerminal)
    # For now, the WebTerminal uses the exact same layout as TUI, 
    # but the framework knows to transport it over WebSocket.
    ManyUI.render(model, TUI())
end

# 3.3 WebNative Projection (HTML/DOM Native)
function ManyUI.render(model::MyModel, ::WebNative)
    # WebNative uses the exact same Widget tree! The backend translates it to HTML/DOM
    ManyUI.render(model, TUI())
end

const global_model = MyModel("data.csv", true, ["App started"])

function run_demo(mode::String="tui")
    if mode == "tui"
        println("Launching in TUI mode (Press Ctrl-C or click Quit to exit)...")
        ManyUITUI.launch(global_model, TUI())
    elseif mode == "webtui"
        println("Launching in WebTerminal mode at http://localhost:8000 ...")
        ManyUITUI.launch(global_model, WebTerminal(); port=8000)
    elseif mode == "web"
        println("Launching in WebNative mode at http://localhost:8080 ...")
        ManyUITUI.launch(global_model, WebNative(); port=8080)
    else
        println("Unknown mode: $mode")
    end

    println("\n=== Final Model State ===")
    println("Unsaved changes: ", global_model.unsaved_changes)
    println("Log:")
    for msg in global_model.log
        println("  - ", msg)
    end
end

end # module DemoApp

# If running as a script, execute automatically
if abspath(PROGRAM_FILE) == @__FILE__
    DemoApp.run_demo(get(ARGS, 1, "tui"))
end

