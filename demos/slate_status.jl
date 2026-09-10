# slate_status.jl -- the KaimonSlateDesktop admin panel, as a ManyUI screen.
#
#     julia --project=ManyUIDemos ManyUIDemos/demos/slate_status.jl        # web native
#     julia --project=ManyUIDemos ManyUIDemos/demos/slate_status.jl tui    # terminal
#
# A SECOND deliberate rebuild, after monitor.jl. That one took a screen
# from Kaimon's TUI; this one takes a screen that exists as hand-written
# HTML today -- `KaimonSlateAdmin.server_status()` in KaimonSlateDesktop
# -- and asks whether ManyUI can replace it.
#
# The question is sharper than monitor.jl's, because the incumbent is not
# a terminal. It is a browser panel that already works. ManyUI has to be
# BETTER than the HTML it replaces, not merely possible.
#
# What it exercises that monitor.jl does not: a `DataTable` as the
# primary content, which is the shape every remaining Kaimon tab wants
# (Sessions, Activity, Extensions).

using ManyUI, ManyUITUI
using ManyUIWeb

const SHEET = parse_css("""
    #frame  { layout: column; padding: 0 1; border: round var(--border);
              background: var(--bg); color: var(--text); }
    #screen { layout: column; grow: 1; }
    #health { border: round var(--border); shrink: 0; }
    #nbbox  { border: round var(--border); grow: 1; }
    #nbbox:focus-within { border: round var(--accent); }
    #notebooks { grow: 1; }
    #footer { height: 1; shrink: 0; color: var(--text_dim); }
""")

# --- the data the screen shows ---------------------------------------
#
# Mirrors `KaimonSlateDesktop.NotebookRow` field for field, so the port
# into the product is a change of RENDERER and not of model.

struct NotebookRow
    id::String
    cells::Int
    running::Int
    stale::Int
    errors::Int
end

const SEED_NOTEBOOKS = [
    NotebookRow("welcome", 2, 0, 0, 0),
    NotebookRow("report", 12, 3, 1, 0),
    NotebookRow("regression-sweep", 48, 0, 7, 2),
    NotebookRow("scratch", 1, 0, 0, 0),
]

"""
One service line: a lit dot, the name, and where to reach it.

The dot carries the state and the URL stays quiet, because a reader
scans a status panel for the colour first and the address only once
something is wrong.
"""
function health_line(name::AbstractString, up::Bool, detail::AbstractString)
    dot = up ? TextRun("● ", Style(fg = token(:success))) :
               TextRun("○ ", Style(fg = token(:error)))
    state = up ? TextRun(detail, Style(fg = token(:accent))) :
                 TextRun("unreachable at " * detail, Style(fg = token(:error)))
    return RichText(dot, TextRun(rpad(name, 12), Style(bold = true)), state)
end

"A count that disappears when it is zero: only the non-zero ones are news."
function count_cell(n::Int, tok::Symbol)
    n == 0 && return RichText(TextRun("", Style(fg = token(:text_dim))))
    return RichText(TextRun(string(n), Style(fg = token(tok), bold = true)))
end

# --- the screen ------------------------------------------------------

function slate_status_app()
    health = Container(
        Label(health_line("Slate hub", true, "http://127.0.0.1:8765")),
        Label(health_line("Kaimon MCP", true, "http://127.0.0.1:2828"));
        id = :health, title = "Services")

    cols = [Column("Notebook"; width = fr(1)),
            Column("Cells"; width = cells(7), align = Align.END),
            Column("Run"; width = cells(5), align = Align.END),
            Column("Stale"; width = cells(7), align = Align.END),
            Column("Err"; width = cells(5), align = Align.END)]

    notebooks = DataTable(
        SEED_NOTEBOOKS, cols;
        key = r -> r.id,
        cell = (r, j) -> j == 1 ? RichText(TextRun(r.id, Style(bold = true))) :
                         j == 2 ? RichText(TextRun(string(r.cells))) :
                         j == 3 ? count_cell(r.running, :accent) :
                         j == 4 ? count_cell(r.stale, :warning) :
                                  count_cell(r.errors, :error),
        id = :notebooks)

    nbbox = Container(notebooks; id = :nbbox,
                      title = RichText(TextRun("Notebooks "),
                                       TextRun("($(length(SEED_NOTEBOOKS)))",
                                               Style(fg = token(:text_dim)))))

    footer = StatusBar(; id = :footer,
        left = RichText(TextRun("⠿ ", Style(fg = token(:success))),
                        TextRun("KaimonSlateDesktop")),
        right = RichText(TextRun("tab", Style(fg = token(:warning))),
                         TextRun(":focus  "),
                         TextRun("q", Style(fg = token(:warning))),
                         TextRun(":quit")))

    screen = Container(health, nbbox, footer; id = :screen)
    return Container(screen; id = :frame, title = "Slate status")
end

function main()
    mode = isempty(ARGS) ? "web" : ARGS[1]
    port = 8010
    if mode == "tui"
        ManyUITUI.run!(slate_status_app; stylesheet = SHEET)
    else
        server = ManyUITUI.launch(slate_status_app, ManyUI.WebNative();
                                  port = port, wait = false)
        println("Slate status running at ", ManyUIWeb.url(server))
        println("Ctrl-C to stop.")
        try
            while true
                sleep(0.2)
            end
        catch e
            e isa InterruptException || rethrow()
        finally
            ManyUIWeb.stop!(server)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
