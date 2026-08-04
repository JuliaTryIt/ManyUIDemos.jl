default:
	@just --list

# Run the central interactive demo hub
hub:
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["hub"])'

# Run the hub with a specific backend (tui, web, webtui, cimgui, cimguitui)
hubb backend="tui":
	julia --project=@. -e 'using ManyUIDemos; ManyUIDemos.command_main(["hub", "--backend", "{{backend}}"])'

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
