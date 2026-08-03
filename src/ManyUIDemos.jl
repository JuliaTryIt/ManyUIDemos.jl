module ManyUIDemos

using Comonicon

include("harness_demo.jl")
include("demo_app.jl")
include("cli_demo.jl")
include("hub.jl")

"""
Run the architecture harness demo (validates the core loop without UI).
"""
@cast function harness()
    ManyUIHarness.run_harness()
end

"""
Run the central demo hub to interactively select and launch demos.

# Options
- `-p, --port <port>`: The port to use for Web/WebTUI modes (default: 8000).
"""
@cast function hub(; port::Int=8000)
    HubApp.run_hub(port)
end

"""
Run the main demo application.

# Args
- `mode`: The mode to run the application in (either "tui" or "web").

# Options
- `-p, --port <port>`: The port to use for Web/WebTUI modes (default: 8000).
"""
@cast function showapp(mode::String="tui"; port::Int=8000)
    DemoApp.run_demo(mode, port)
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

function __init__()
    # Try to load TachikomaDemos to trigger the weak dependency extension
    # so that the Tachikoma Demos show up in the hub automatically if installed.
    try
        Base.require(@__MODULE__, :TachikomaDemos)
    catch
    end
end

end # module ManyUIDemos
