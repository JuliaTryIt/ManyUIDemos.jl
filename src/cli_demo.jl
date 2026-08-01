module CLIDemo

using ManyUI, ManyUITUI
using ManyUICLI
using Comonicon

# Re-use the existing model and actions from demo_app.jl for consistency,
# or define simple ones here just for the CLI demo.
mutable struct MyModel
    file::String
    log::Vector{String}
end

struct Save
    file::String
end

struct Process
    items::Int
end

# The single execute! dispatch that mutates the state
function ManyUI.execute!(model::MyModel, action::Save)
    model.file = action.file
    push!(model.log, "Saved to $(action.file)")
    println("Domain logic executed: Data saved to $(action.file)")
end

function ManyUI.execute!(model::MyModel, action::Process)
    push!(model.log, "Processed $(action.items) items")
    println("Domain logic executed: $(action.items) items processed.")
end

# A global instance for the CLI to act upon
const APP_MODEL = MyModel("data.csv", String[])

# ==============================================================================
# The magic happens here! We map the Model's actions to CLI subcommands.
# ==============================================================================

@project_cli APP_MODEL begin
    Save(file::String)
    Process(items::Int)
end

# And we tell Comonicon to use these as subcommands
Comonicon.@main

end # module CLIDemo
