# _optional_cimgui.jl -- shared by every demo in this directory.
#
# The CImGui backend is OPTIONAL and it is HEAVY: it drags in a GPU
# stack. `ManyUICImGui` already knows this and keeps CImGui, GLFW and
# ModernGL as weak dependencies behind a package extension, so
# `import ManyUICImGui` on its own costs nothing -- the backend simply
# stays asleep until the three are loaded too.
#
# The demos used to load all four EAGERLY, at the top of the file. That
# made a demo unopenable on a machine with no GPU stack, even to read
# its widget tree, and it is how eight headless web tests that never go
# near a GPU came to fail: they `include` a demo for its `*_app()`
# function and inherited an import none of them wanted. No demo in this
# directory uses a single CImGui, GLFW or ModernGL SYMBOL -- the three
# are there only to wake the extension.
#
# So: try, remember, and refuse cleanly if a CImGui mode is actually
# asked for. Building the widgets never needs any of it.

"""
True when the CImGui backend and its three dependencies are available
in the active environment.
"""
const HAS_CIMGUI = try
    @eval import CImGui, GLFW, ModernGL
    @eval import ManyUICImGui
    true
catch
    false
end

"""
Refuse a CImGui mode with a message that says what is missing, rather
than an `UndefVarError` on a package name.
"""
_need_cimgui() =
    HAS_CIMGUI || error(
        "this mode needs CImGui, GLFW and ModernGL in the active " *
        "environment. The demo's widgets need none of them -- run it " *
        "with no argument for the web backend, or `tui` for the " *
        "terminal.")
