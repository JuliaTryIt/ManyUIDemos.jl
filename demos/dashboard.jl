# dashboard.jl -- a filter box driving a list, in a browser.
#
#     julia --project=ManyUIWeb ManyUIWeb/examples/dashboard.jl
#
# then open http://127.0.0.1:8000/.
#
#   type            to filter
#   enter           to apply the filter
#   tab             to move between the box and the list
#   up/down         to move the cursor, the wheel to scroll
#
# The point of this one is the wiring: a widget's callback mutates
# another widget, that mutation marks only what changed, and the next
# frame sends only the cells that differ.

using ManyUI, ManyUITUI
using ManyUIWeb

const LANGUAGES = [
    "Julia", "Python", "Rust", "Go", "C", "C++", "Haskell", "OCaml",
    "Elm", "Elixir", "Erlang", "Clojure", "Scheme", "Common Lisp",
    "Racket", "F#", "Scala", "Kotlin", "Swift", "Zig", "Nim", "Crystal",
    "Ruby", "Perl", "Lua", "JavaScript", "TypeScript", "Fortran",
    "COBOL", "Ada", "Prolog", "Smalltalk", "Forth", "APL", "J",
]

# `shrink: 0` on the three fixed rows is load-bearing, and the reason is
# worth knowing: a `List` measures to the whole viewport, so a column
# holding one asks for more height than it has. Flex then shrinks every
# child that CAN shrink, and with the default `shrink: 1` the labels are
# what give way -- a one-row label becomes a zero-row label and simply
# vanishes. Pinning them makes the list the only thing that yields.
#
# `height: 1` on the filter is its CONTENT height; the border adds the
# two rows around it, for three in total.
const SHEET = parse_css("""
    #screen { layout: column; }
    #title  { color: #7dd3fc; shrink: 0; }
    #filter { border: round #475569; height: 1; shrink: 0; }
    #hits   { color: #94a3b8; shrink: 0; }
    #langs  { grow: 1; }
    #footer { color: #94a3b8; shrink: 0; align: center; }
    List    { color: #e2e8f0; }
""")

struct DashboardScreen <: Widget
    node::WidgetNode
    content::Widget
end

ManyUI.node(w::DashboardScreen) = w.node
ManyUI.children(w::DashboardScreen) = (w.content,)

function ManyUI.on_event!(w::DashboardScreen, d::Dispatch{KeyEvent})
    e = d.event
    if e.code === Key.ESCAPE || (e.code === Key.CHAR && e.char == 'q') || (e.code === Key.CHAR && e.char == 'c' && e.ctrl)
        a = ManyUI.app(w)
        a === nothing || quit!(a)
        consume!(d)
    end
    return nothing
end

"""
The screen. Called once per client, so each browser tab filters its own
copy without disturbing anyone else's.
"""
function dashboard_app()
    list = List(copy(LANGUAGES); id = :langs)
    hits = Label("$(length(LANGUAGES)) of $(length(LANGUAGES))"; id = :hits)

    filter_fn = w -> begin
        q = lowercase(w.text[])
        keep = isempty(q) ? copy(LANGUAGES) :
            filter(l -> occursin(q, lowercase(l)),
                   LANGUAGES)
        set_items!(list, keep)
        hits.text[] = "$(length(keep)) of $(length(LANGUAGES))"
        nothing
    end

    # `on_change` fires on every edit/keystroke.
    filter_box = TextInput("", _ -> nothing;
                           on_change = filter_fn,
                           placeholder = "type to filter...",
                           id = :filter)

    content = Container(
        Label("languages"; id = :title),
        filter_box,
        hits,
        list,
        Label("Esc or Ctrl-C to quit"; id = :footer);
        id = :screen,
    )

    n = WidgetNode(; type_name=:DashboardScreen, focusable=true)
    push!(n.children, content)
    w = DashboardScreen(n, content)
    ManyUI.node(content).parent = w
    return w
end

function main()
    mode = length(ARGS) >= 1 ? ARGS[1] : "web"
    if mode == "tui"
        ManyUITUI.launch(dashboard_app; stylesheet = SHEET)
    elseif mode == "webtui"
        ManyUITUI.launch(dashboard_app; backend = WebBackend(port = 8000), stylesheet = SHEET)
    else
        server = ManyUITUI.launch(dashboard_app, ManyUI.WebNative(); port = 8000)
        println("Dashboard running at ", ManyUIWeb.url(server))
        println("Ctrl-C to stop.")
        try
            wait(server)
        catch e
            e isa InterruptException || rethrow()
        finally
            ManyUITUI.stop!(server)
            println("stopped")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
