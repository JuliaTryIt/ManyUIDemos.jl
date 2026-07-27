# ManyUIDemos.jl

A centralized demonstration hub for the `ManyUI` ecosystem.

## Usage
`ManyUIDemos` aggregates the functionalities of `ManyUI`, `ManyUIWeb`, and `ManyUICLI` into a single testable harness.
It exposes a command-line interface (powered by `ManyUICLI`) to launch the demos.

### Running Demos

From the monorepo root, you can use the `justfile` recipes:
```bash
# Launch the CLI projection
just cli arg1 arg2 ...

# Launch the WebTerminal projection
just demo webtui

# Launch the Native HTML Web projection
just demo web

# Launch the classic TUI
just demo tui
```
