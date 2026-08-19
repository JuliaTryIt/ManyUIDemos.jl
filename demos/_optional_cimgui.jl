# _optional_cimgui.jl -- shared by every demo in this directory.
#
# The CImGui backend is OPTIONAL and it is HEAVY: it drags in a GPU
# stack. `ManyUICImGui` already knows this and keeps CImGui, GLFW,
# HarfBuzz and ModernGL as weak dependencies behind a package
# extension, so `import ManyUICImGui` on its own costs nothing -- the
# backend simply stays asleep until all FOUR are loaded too.
#
# The demos used to load them EAGERLY, at the top of the file. That
# made a demo unopenable on a machine with no GPU stack, even to read
# its widget tree, and it is how eight headless web tests that never go
# near a GPU came to fail: they `include` a demo for its `*_app()`
# function and inherited an import none of them wanted. No demo in this
# directory uses a single CImGui, GLFW, HarfBuzz or ModernGL SYMBOL --
# they are there only to wake the extension.
#
# So: try, remember, and refuse cleanly if a CImGui mode is actually
# asked for. Building the widgets never needs any of it.
#
# HarfBuzz belongs in this list. `ManyUICImGuiCImGuiExt` is declared as
# `["CImGui", "GLFW", "HarfBuzz", "ModernGL"]` -- an extension fires
# only when EVERY trigger is loaded, so importing three of the four
# left the extension asleep while this file still reported success.
# `launch_manyui` then reached the stub in `ManyUICImGui/src` and threw
# "native support requires CImGui, GLFW, HarfBuzz and ModernGL" from an
# environment that had three of them installed.

"""
True when the CImGui backend and all four of its extension triggers are
available in the active environment -- AND the extension actually woke
up. Loading the triggers is necessary but not sufficient: a trigger can
fail to precompile, in which case Julia reports the failure and carries
on with the extension unloaded.
"""
const HAS_CIMGUI = try
    @eval import CImGui, GLFW, HarfBuzz, ModernGL
    @eval import ManyUICImGui
    ManyUICImGui.native_available()
catch
    false
end

"""
Refuse a CImGui mode with a message that says what is missing, rather
than an `UndefVarError` on a package name.
"""
macro need_cimgui()
    return :(getglobal(@__MODULE__, :HAS_CIMGUI) || begin
        println("\n⚠️  The CImGui backend is not available in the active environment.")
        println("   It needs CImGui, GLFW, HarfBuzz and ModernGL -- all four, since")
        println("   they are the extension's triggers -- and it needs them to have")
        println("   precompiled. Scroll up for a precompilation error if you expected")
        println("   this to work.")
        println("   The GPU stack lives in a SEPARATE environment, because it")
        println("   cannot share this one -- see ../Project.toml. Run:")
        println()
        println("       just demo-cimgui <demo>.jl cimguitui   # one demo")
        println("       just hub-cimgui                        # the hub")
        println()
        println("   or, by hand, `julia --project=CImGuiEnv demos/<demo>.jl")
        println("   cimguitui`. First time, `just instantiate-cimgui`.")
        println("   The demo's widgets need none of them -- run it with no argument")
        println("   for the web backend, or `tui` for the terminal.\n")
        return 0
    end)
end
