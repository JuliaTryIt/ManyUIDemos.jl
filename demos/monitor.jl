# monitor.jl -- a server supervisor screen, in a browser or a terminal.
#
#     julia --project=ManyUIDemos ManyUIDemos/demos/monitor.jl tui
#
# This is not a gallery. It is a DELIBERATE REBUILD of one real screen
# -- the Server tab of the Kaimon TUI, a Tachikoma application -- and it
# exists to answer a question a feature checklist cannot: could ManyUI
# render this?
#
# Everything on it is something ManyUI grew for this target: a captioned
# frame, a tab strip whose shortcut keys are coloured inside the
# caption, a log list that colours only its level column, a status bar
# that knows what to drop, and a palette named by semantic tokens rather
# than by hex. Not one of the five was expressible six commits ago.
#
# What it does NOT reach is recorded at the bottom of this file, because
# a rebuild that only reports its successes is not evidence.

using ManyUI, ManyUITUI
using ManyUIWeb
Base.include(@__MODULE__, joinpath(@__DIR__, "_optional_cimgui.jl"))

const SHEET = parse_css("""
    #screen   { layout: column; background: var(--bg); color: var(--text); }
    #tabs     { height: 1; shrink: 0; }
    #status   { border: round var(--border); height: 2; shrink: 0; }
    #logbox   { border: round var(--border); grow: 1; }
    #logbox:focus-within { border: round var(--accent); }
    #log      { grow: 1; }
    #footer   { height: 1; shrink: 0; color: var(--text_dim); }
""")

# --- the data the screen shows ---------------------------------------

struct LogEntry
    "Wall-clock stamp, already formatted: a monitor shows a time, it
     does not compute with one, so this demo needs no date library."
    at::String
    level::Symbol
    text::String
end

const LEVEL_TOKEN = Dict(:info => :accent, :warn => :warning,
                         :error => :error, :debug => :text_dim)

"""
One log row: the timestamp dim, the level in its own colour, the
message in the widget's. Three colours, ONE node -- which is the whole
argument for rich text over a widget per fragment.
"""
function log_row(e::LogEntry)
    tok = get(LEVEL_TOKEN, e.level, :text_dim)
    return RichText(TextRun(e.at, Style(fg = token(:text_dim))),
                    TextRun(" " * rpad(String(e.level), 5),
                            Style(fg = token(tok), bold = true)),
                    TextRun(" " * e.text))
end

"""
A tab caption with its shortcut key coloured inside it. The case that
motivated `RichText`: three nodes per tab was the alternative.
"""
tab_caption(key, name) =
    RichText(TextRun(key, Style(fg = token(:warning), bold = true)),
             TextRun(" " * name))

const SEED_LOG = [
    LogEntry("11:03:33", :info, "Session initialized  id=98ad5d15"),
    LogEntry("11:03:33", :info, "SSE flush: tools/list_changed"),
    LogEntry("10:44:01", :info, "MCP client initialized  v2.1.226"),
    LogEntry("10:42:23", :warn, "Extension 'slate' slow to start"),
    LogEntry("10:38:44", :info, "Extension 'slate' ready -- 45 tools"),
    LogEntry("10:38:24", :info, "MCP server listening on port 2828"),
    LogEntry("10:38:23", :error, "Database lock contended, retrying"),
    LogEntry("10:38:23", :info, "Database ready"),
    LogEntry("10:38:22", :debug, "Service endpoint bound (ROUTER)"),
]

# --- the screen ------------------------------------------------------

function monitor_app()
    entries = copy(SEED_LOG)

    tabs = Tabs(tab_caption("1", "Server") => Container(; id = :t_server),
                tab_caption("2", "Sessions") => Container(),
                tab_caption("3", "Activity") => Container();
                id = :tabs)

    uptime = Label(RichText(
        TextRun("* ", Style(fg = token(:success), bold = true)),
        TextRun("ManyUI monitor "),
        TextRun("v0.1.0", Style(fg = token(:accent))),
        TextRun(" -- :2828 -- "),
        TextRun("running", Style(fg = token(:success)))); id = :uptime)
    counts = Label(RichText(
        TextRun("Gate: "), TextRun("2", Style(fg = token(:accent))),
        TextRun(" sessions -- Tool calls: "),
        TextRun("1", Style(fg = token(:accent)))); id = :counts)

    status = Container(uptime, counts; id = :status,
                       title = "Server Status")

    log = List(entries; format = log_row, id = :log)
    logbox = Container(log; id = :logbox,
                       title = RichText(
                           TextRun("Server Log "),
                           TextRun("($(length(entries)))",
                                   Style(fg = token(:text_dim)))))

    footer = StatusBar(; id = :footer,
                       left = RichText(
                           TextRun("localhost:2828",
                                   Style(fg = token(:accent))),
                           TextRun(" -- 2 sessions")),
                       right = RichText(
                           TextRun("tab", Style(fg = token(:warning))),
                           TextRun(":focus  "),
                           TextRun("q", Style(fg = token(:warning))),
                           TextRun(":quit")))

    return Container(tabs, status, logbox, footer; id = :screen)
end

# --- WHAT THIS SCREEN CANNOT DO YET ----------------------------------
#
# Written down because a rebuild that reports only its successes proves
# nothing. Three gaps, found by building it and not by reading a list:
#
#   1. The outer frame carries ONE caption. Kaimon's has a title at the
#      left AND a mark at the right of the same top edge, and
#      `border_title` has one slot with one alignment. A border FOOTER
#      is already on the roadmap; a second title on the same edge is
#      not, and should be.
#
#   2. The footer is a ROW, not the frame's bottom edge. Kaimon fuses
#      its status line into the border, which saves a line on an
#      80x24 terminal -- the same border-footer gap, from the other
#      side.
#
#   3. The log pane does not follow its own tail. Nothing here keeps a
#      `List` pinned to the last row as rows arrive; an application
#      does it by hand with `scroll_to!`. Worth a `follow` flag on the
#      row widgets.
#
# Everything else the Server tab does, this does.

function main()
    mode = length(ARGS) >= 1 ? ARGS[1] : "web"
    port = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 8000
    if mode == "tui"
        app = ManyUITUI.launch(monitor_app; stylesheet = SHEET,
                               wait = false)
        try
            while app.running
                sleep(0.1)
                ManyUI.post!(app, ManyUI.TickEvent(time()))
            end
        catch e
            e isa InterruptException || rethrow()
        finally
            ManyUITUI.stop!(app.driver)
        end
        app.error === nothing || throw(app.error)
    elseif mode == "webtui"
        server = serve(monitor_app; port = port, stylesheet = SHEET,
                       title = "Monitor WebTUI")
        println("Monitor WebTUI running at ", ManyUIWeb.url(server))
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
    elseif mode == "cimgui"
        _need_cimgui()
        ManyUICImGui.launch_manyui(monitor_app; title = "Monitor CImGui")
    elseif mode == "cimguitui"
        _need_cimgui()
        ManyUICImGui.launch_tui(monitor_app; title = "Monitor CImGui TUI",
                                stylesheet = SHEET)
    else
        server = ManyUITUI.launch(monitor_app, ManyUI.WebNative();
                                  port = port, wait = false)
        println("Monitor running at ", ManyUIWeb.url(server))
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
