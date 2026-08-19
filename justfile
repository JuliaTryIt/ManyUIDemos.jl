default:
	@just --list

# Run the central interactive demo hub
hub:
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["hub"])'

# Run the hub with a specific backend (tui, web, webtui, cimgui, cimguitui)
hubb backend="tui":
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["hub", "--backend", "{{backend}}"])'

# The base environment has no CImGui/GLFW/ModernGL -- they are weak
# dependencies there -- so a cimgui mode launched by `just hub` or
# `just hubb` can only report what is missing. Use the recipes below
# for cimgui and cimguitui.

# Run the hub from CImGuiEnv, the environment where CImGui modes work
hub-cimgui backend="cimguitui":
	julia --project=CImGuiEnv -e 'using ManyUIDemos; ManyUIDemos.command_main(["hub", "--backend", "{{backend}}"])'

# Run one demo file in a CImGui mode (cimgui or cimguitui)
demo-cimgui demo="gallery.jl" mode="cimguitui":
	julia --project=CImGuiEnv demos/{{demo}} {{mode}}

# Resolve and precompile CImGuiEnv (first run, or after a pull)
instantiate-cimgui:
	julia --project=CImGuiEnv -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Run the architecture harness demo
harness:
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["harness"])'

# Run the main demo application (mode can be "tui", "webtui", or "web")
demo mode="tui":
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["showapp", "{{mode}}"])'

# Run the CLI projection demo
cli +args:
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(vcat(["cli"], ARGS))' -- {{args}}

# Run the unified hub help
help:
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["-h"])'

test:
	julia --project=@. -e 'using Pkg; Pkg.test()'

instantiate:
	julia --project=@. -e 'using Pkg; Pkg.instantiate()'

dev:
	julia --project=@.
