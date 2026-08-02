module ImmediateDemo

using ManyUI
using ManyUI.Immediate
using ManyUITUI

# ---------------------------------------------------------
# Demo App
# ---------------------------------------------------------

function my_immediate_app()
    Immediate.text("Welcome to the Immediate Mode API in ManyUI!")

    if Immediate.button("Click me!")
        Immediate.text("You clicked the button just now!")
    end

    # Simple state loop for progress
    ctx = Immediate.CURRENT_CTX[:manyui_immediate_ctx]
    prog = get(ctx.state, "prog_val", 0.0)

    Immediate.progressbar(prog)

    if Immediate.button("Advance Progress")
        ctx.state["prog_val"] = min(1.0, prog + 0.1)
    end

    if Immediate.button("Reset Progress")
        ctx.state["prog_val"] = 0.0
    end

    name = Immediate.textinput("Enter your name and press Enter")
    if !isempty(name)
        Immediate.text("Hello, $name!")
    end
end

struct AppModel end
ManyUI.render(::AppModel, ::ManyUI.TUI) = ImmediateContainer(my_immediate_app)

function run()
    println("Launching Immediate Mode demo in TUI...")
    ManyUITUI.launch(AppModel(), ManyUI.TUI())
end

end # module
