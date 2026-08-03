module ManyUIDemosTachikomaExt

using ManyUIDemos
using TachikomaDemos

const WRAPPERS_DIR = joinpath(@__DIR__, "tachikoma_wrappers")

function __init__()
    ManyUIDemos.HubApp.register_demo!(
        "Tachikoma Demos",
        "Tachikoma Demos Hub\n\nLaunches the native Tachikoma demo browser to explore all Tachikoma widgets and examples.",
        joinpath(WRAPPERS_DIR, "tk_launcher.jl"),
        (tui=true, web=false, webtui=true)
    )
end

end # module
