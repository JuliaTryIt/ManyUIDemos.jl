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
    #frame    { layout: column; padding: 0 1; border: round var(--border);
                background: var(--bg); color: var(--text); }
    #screen   { layout: column; grow: 1; }
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
    # The stamp and the level CARRY; the message RECEDES. A log is
    # scanned down its left edge, so the columns a reader scans are the
    # bright ones and the prose behind them is dim -- which is the
    # opposite of the obvious choice.
    return RichText(TextRun(e.at, Style(fg = token(:text))),
                    TextRun(" " * rpad(String(e.level), 5),
                            Style(fg = token(tok), bold = true)),
                    TextRun(" " * e.text, Style(fg = token(:text_dim))))
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
        TextRun(" \u00b7 :2828 \u00b7 "),
        TextRun("running", Style(fg = token(:success)))); id = :uptime)
    counts = Label(RichText(
        TextRun("Gate: "), TextRun("2", Style(fg = token(:accent))),
        TextRun(" sessions \u00b7 Tool calls: "),
        TextRun("1", Style(fg = token(:accent)))); id = :counts)

    status = Container(uptime, counts; id = :status,
                       title = "Server Status")

    # SelectMode.NONE: a log is READ, not chosen from. `List` is a
    # selection widget and this is the closest ManyUI has to a pane of
    # rich lines -- see the gap list below.
    log = List(entries; format = log_row, mode = SelectMode.NONE,
               id = :log)
    logbox = Container(log; id = :logbox,
                       title = RichText(
                           TextRun("Server Log "),
                           TextRun("($(length(entries)))",
                                   Style(fg = token(:text_dim)))))

    footer = StatusBar(; id = :footer,
                       left = RichText(
                           TextRun("\u283f ", Style(fg = token(:success))),
                           TextRun("localhost:2828",
                                   Style(fg = token(:accent))),
                           TextRun(" \u00b7 2 sessions")),
                       right = RichText(
                           TextRun("tab", Style(fg = token(:warning))),
                           TextRun(":focus  "),
                           TextRun("q", Style(fg = token(:warning))),
                           TextRun(":quit")))

    screen = Container(tabs, status, logbox, footer; id = :screen)
    # The OUTER frame Kaimon puts round everything. One caption, at the
    # left -- see gap 1.
    return Container(screen; id = :frame, title = "ManyUI monitor")
end

# --- WHAT THIS SCREEN CANNOT DO YET ----------------------------------
#
# Written down because a rebuild that reports only its successes proves
# nothing. Compared side by side against the real Kaimon Server tab,
# four things are the FRAMEWORK's and not this file's:
#
#   1. THE TAB STRIP IS FLAT. Kaimon draws each tab as its own bordered
#      box, the boxes joined into a strip, and the ACTIVE one open at
#      the bottom so it reads as continuous with the pane beneath it.
#      `TabStrip` paints a row of captions and reverses the active one;
#      there is no boxed style, and the joinery is the interesting part.
#
#   2. ONE CAPTION PER EDGE. Kaimon's outer frame has a title at the
#      left AND a mark at the right of the same top edge.
#      `border_title` has one slot and one alignment.
#
#   3. THE STATUS BAR IS A ROW, not the frame's bottom edge. Kaimon
#      fuses its status line INTO the border, which buys back a line on
#      an 80x24 terminal. A border footer is on the roadmap.
#
#   4. A LOG IS NOT A SELECTION. `List` is the closest ManyUI has to a
#      pane of rich lines, and it is built around a cursor -- so a log
#      pane borrows a widget whose whole point is choosing a row.
#      `SelectMode.NONE` removes the semantics, not the shape. What is
#      missing is a scrollable pane of `RichText` lines: `MarkdownPane`
#      is one for one input format, and a plain one would serve a log,
#      a transcript and a diff.
#
# Two more, already recorded on the roadmap: no interactive controls in
# a border caption (Kaimon's `[wrap:off] [F]ollow:on` live in one), and
# no tail-following on a row widget.
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
