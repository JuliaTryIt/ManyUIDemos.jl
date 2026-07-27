module ManyUIHarness

# ==========================================
# 1. Backends (The Traits/Types)
# ==========================================
abstract type Backend end
struct CLI <: Backend end
struct TUI <: Backend end
struct WebTerminal <: Backend end
struct WebNative <: Backend end

# ==========================================
# 2. Domain & Actions (The Core Model)
# ==========================================
abstract type Action end

struct Save <: Action
    filename::String
end

struct Quit <: Action end

mutable struct MyModel
    current_file::String
    unsaved_changes::Bool
end

struct Application
    model::MyModel
end

# ==========================================
# 3. Presentation & Routing (Multiple Dispatch)
# ==========================================

# 3.1 CLI Projection
function render(app::Application, ::CLI)
    println("CLI Presentation: Building command-line parser...")
    println(" -> Command 'save <filename>' mapped to Save(filename)")
    println(" -> Command 'quit' mapped to Quit()")
    # In reality, this would hook into ManyUICLI / Comonicon
end

# 3.2 TUI Projection
function render(app::Application, ::TUI)
    println("TUI Presentation: Building visual widget tree...")
    println(" -> Container(")
    println("      Label(\"File: $(app.model.current_file)\"),")
    println("      Button(\"Save\", Save(app.model.current_file))")
    println("    )")
    # In reality, this would hook into ManyUI / Tachikoma
end

# 3.3 WebTerminal Projection (Terminal Emulation)
function render(app::Application, ::WebTerminal)
    println("WebTerminal Presentation: Starting WebSocket server...")
    println(" -> Running TUI loop and broadcasting ANSI stream to xterm.js client")
    # In reality, this would hook into ManyUIWeb
end

# 3.4 WebNative Projection (True HTML/DOM)
function render(app::Application, ::WebNative)
    println("WebNative Presentation: Generating HTML/DOM elements...")
    println(" -> <div>")
    println("      <span>File: $(app.model.current_file)</span>")
    println("      <button onclick=\"dispatch(Save('$(app.model.current_file)'))\">Save</button>")
    println("    </div>")
    # In reality, this would hook into a Native Web backend (e.g., Genie / Dash / custom HTML generator)
end

# ==========================================
# 4. Action Execution (Domain Logic)
# ==========================================
function execute!(app::Application, action::Save)
    println("[DOMAIN LOGIC] Executing Save: Writing data to $(action.filename)...")
    app.model.unsaved_changes = false
end

function execute!(app::Application, action::Quit)
    println("[DOMAIN LOGIC] Executing Quit: Exiting application gracefully.")
end

function run_harness()
    println("Initializing Application...")
    app = Application(MyModel("data.csv", true))

    println("\n--- [ PROJECTION: CLI ] ---")
    render(app, CLI())

    println("\n--- [ PROJECTION: TUI ] ---")
    render(app, TUI())

    println("\n--- [ PROJECTION: Web Terminal ] ---")
    render(app, WebTerminal())

    println("\n--- [ PROJECTION: Native Web ] ---")
    render(app, WebNative())

    println("\n--- [ SIMULATING ACTION ] ---")
    execute!(app, Save("data.csv"))
end

end # module

# If running as script
if abspath(PROGRAM_FILE) == @__FILE__
    ManyUIHarness.run_harness()
end
