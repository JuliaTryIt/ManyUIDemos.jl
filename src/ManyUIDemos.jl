module ManyUIDemos

using Comonicon

include("harness_demo.jl")
include("demo_app.jl")
include("cli_demo.jl")

"""
Run the architecture harness demo (validates the core loop without UI).
"""
@cast function harness()
    ManyUIHarness.run_harness()
end

"""
Run the main demo application.

# Args
- `mode`: The mode to run the application in (either "tui" or "web").
"""
@cast function showapp(mode::String="tui")
    DemoApp.run_demo(mode)
end

"""
Run the CLI projection demo. Pass arguments to see it in action.
"""
@cast function cli(args...)
    # We forward the string arguments to the CLI demo's main parser
    CLIDemo.command_main(String[args...])
end

# ManyUIDemos - A collection of demonstrations for the ManyUI ecosystem.
Comonicon.@main

end # module ManyUIDemos
