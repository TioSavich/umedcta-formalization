/** <module> ORR Cycle HTTP Server

    Minimal HTTP server exposing the ORR cycle as a JSON API.
    Serves the frontend and handles computation requests.

    Usage:
        swipl server.pl
        % Server starts on http://localhost:8080
*/

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_files)).

:- use_module(execution_handler).
:- use_module(oracle_server).
:- use_module(event_log).
:- use_module(more_machine_learner, []).

% Route definitions
:- http_handler(root(api/compute), handle_compute, []).
:- http_handler(root(api/strategies), handle_strategies, []).
:- http_handler(root(api/knowledge), handle_knowledge, []).
:- http_handler(root(api/reset), handle_reset, []).
:- http_handler(root(.), serve_frontend, [prefix]).

% CORS for local dev
:- set_setting(http:cors, [*]).

%!  server_port(-Port) is det.
%   Default port for the ORR server.
server_port(8080).

%!  start_server is det.
%   Start the HTTP server on the default port.
start_server :-
    server_port(Port),
    http_server(http_dispatch, [port(Port)]),
    format('ORR Cycle Explorer running at http://localhost:~w~n', [Port]).

% ═══════════════════════════════════════════════════════════════════════
% API Handlers
% ═══════════════════════════════════════════════════════════════════════

%!  handle_compute(+Request) is det.
%
%   POST /api/compute
%   Body: {"operation": "add", "a": 3, "b": 2, "limit": 20}
%   Returns: {"success": bool, "problem": {...}, "events": [...]}
%
handle_compute(Request) :-
    cors_enable(Request, [methods([post])]),
    http_read_json_dict(Request, Input),
    atom_string(Op, Input.operation),
    A = Input.a,
    B = Input.b,
    Limit = Input.get(limit, 20),

    % Reset event log, run computation, collect events.
    % Redirect stdout to a string — run_computation uses writeln
    % which would otherwise corrupt the HTTP response stream.
    reset_events,
    build_goal(Op, A, B, Goal),
    (   catch(
            with_output_to(string(_Stdout),
                run_computation(Goal, Limit)),
            Error,
            (   emit(computation_failed, _{goal: Goal, error: Error}),
                fail
            )
        )
    ->  Success = true
    ;   Success = false
    ),
    get_events(Events),
    maplist(event_to_dict, Events, EventDicts),
    get_learned_strategies(Knowledge),
    reply_json_dict(_{
        success: Success,
        problem: _{operation: Op, a: A, b: B},
        budget: Limit,
        events: EventDicts,
        knowledge: Knowledge
    }).

%!  handle_strategies(+Request) is det.
handle_strategies(Request) :-
    cors_enable(Request, [methods([get])]),
    http_parameters(Request, [operation(OpStr, [])]),
    atom_string(Op, OpStr),
    (   oracle_server:list_available_strategies(Op, Strategies)
    ->  reply_json_dict(_{operation: Op, strategies: Strategies})
    ;   reply_json_dict(_{operation: Op, strategies: []})
    ).

%!  handle_knowledge(+Request) is det.
%
%   GET /api/knowledge
%   Returns learned strategies per operation.
%
handle_knowledge(Request) :-
    cors_enable(Request, [methods([get])]),
    get_learned_strategies(Knowledge),
    reply_json_dict(Knowledge).

%!  handle_reset(+Request) is det.
%
%   POST /api/reset
%   Resets the machine to primordial state (forgets all learned strategies).
%
handle_reset(Request) :-
    cors_enable(Request, [methods([post])]),
    retractall(more_machine_learner:run_learned_strategy(_,_,_,_,_)),
    reset_events,
    reply_json_dict(_{status: reset}).

% ═══════════════════════════════════════════════════════════════════════
% Knowledge Tracking
% ═══════════════════════════════════════════════════════════════════════

get_learned_strategies(Knowledge) :-
    findall(
        _{operation: Op, learned: Learned},
        (   member(Op, [add, subtract, multiply, divide]),
            oracle_server:list_available_strategies(Op, Available),
            findall(S, (
                member(S, Available),
                clause(more_machine_learner:run_learned_strategy(_,_,_,S,_), _)
            ), Learned)
        ),
        Knowledge
    ).

% ═══════════════════════════════════════════════════════════════════════
% Goal Construction
% ═══════════════════════════════════════════════════════════════════════

build_goal(add, A, B, object_level:add(PA, PB, _)) :-
    int_to_peano(A, PA), int_to_peano(B, PB).
build_goal(subtract, A, B, object_level:subtract(PA, PB, _)) :-
    int_to_peano(A, PA), int_to_peano(B, PB).
build_goal(multiply, A, B, object_level:multiply(PA, PB, _)) :-
    int_to_peano(A, PA), int_to_peano(B, PB).
build_goal(divide, A, B, object_level:divide(PA, PB, _)) :-
    int_to_peano(A, PA), int_to_peano(B, PB).

int_to_peano(0, 0) :- !.
int_to_peano(N, s(P)) :-
    N > 0,
    N1 is N - 1,
    int_to_peano(N1, P).

% ═══════════════════════════════════════════════════════════════════════
% Event Serialization
% ═══════════════════════════════════════════════════════════════════════

event_to_dict(Event, SafeDict) :-
    dict_pairs(Event, Tag, Pairs),
    maplist(safe_pair, Pairs, SafePairs),
    dict_pairs(SafeDict, Tag, SafePairs).

safe_pair(Key-Value, Key-SafeValue) :-
    safe_value(Value, SafeValue).

safe_value(V, V) :- number(V), !.
safe_value(V, V) :- atom(V), !.
safe_value(V, V) :- string(V), !.
safe_value(V, S) :- is_dict(V), !, event_to_dict(V, S).
safe_value(V, S) :- is_list(V), !, maplist(safe_value, V, S).
safe_value(V, S) :- term_to_atom(V, S).

% ═══════════════════════════════════════════════════════════════════════
% Frontend
% ═══════════════════════════════════════════════════════════════════════

serve_frontend(Request) :-
    memberchk(path(Path), Request),
    (   Path == '/'
    ->  serve_index(Request)
    ;   atom_concat('public', Path, FilePath),
        exists_file(FilePath)
    ->  http_reply_file(FilePath, [], Request)
    ;   serve_index(Request)
    ).

serve_index(_Request) :-
    inline_frontend(HTML),
    format('Content-type: text/html~n~n'),
    format('~w', [HTML]).

inline_frontend(HTML) :-
    HTML = '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ORR Cycle Explorer</title>
<style>
:root {
  --bg: #0f0f1a;
  --surface: #1a1a2e;
  --surface2: #16213e;
  --border: #2a2a4a;
  --text: #d4d4e0;
  --text-dim: #7a7a9a;
  --accent: #e94560;
  --success: #4ecca3;
  --warn: #f0a050;
  --oracle: #9b7aed;
  --mono: "SF Mono", "Fira Code", "Cascadia Code", "Consolas", monospace;
  --sans: -apple-system, "Segoe UI", sans-serif;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: var(--sans);
  background: var(--bg);
  color: var(--text);
  min-height: 100vh;
  line-height: 1.6;
}

.container { max-width: 720px; margin: 0 auto; padding: 2rem 1.5rem; }

header { margin-bottom: 2rem; }
h1 { font-size: 1.5rem; font-weight: 600; margin-bottom: 0.25rem; }
.subtitle { color: var(--text-dim); font-size: 0.9rem; }

/* Controls */
.controls {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}
.controls-row {
  display: flex; gap: 0.75rem; align-items: end; flex-wrap: wrap;
}
.field label {
  display: block; font-size: 0.7rem; color: var(--text-dim);
  text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.25rem;
}
.field select, .field input {
  background: var(--bg); border: 1px solid var(--border);
  color: var(--text); padding: 0.45rem 0.6rem; border-radius: 4px;
  font-family: var(--mono); font-size: 0.85rem; width: 100%;
}
.field select { width: 130px; }
.field input[type=number] { width: 65px; }
.controls-row .spacer { flex: 1; }
button.run {
  background: var(--accent); color: white; border: none;
  padding: 0.45rem 1.5rem; border-radius: 4px; cursor: pointer;
  font-family: var(--sans); font-size: 0.85rem; font-weight: 600;
  white-space: nowrap;
}
button.run:hover { filter: brightness(1.1); }
button.run:disabled { opacity: 0.4; cursor: not-allowed; }
button.reset {
  background: none; border: 1px solid var(--border); color: var(--text-dim);
  padding: 0.45rem 0.75rem; border-radius: 4px; cursor: pointer;
  font-size: 0.8rem;
}
button.reset:hover { border-color: var(--text-dim); }
.limit-warning {
  font-size: 0.75rem; color: var(--warn); margin-top: 0.5rem;
  display: none;
}

/* Narrative cards */
.narrative { display: flex; flex-direction: column; gap: 0; }
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.25rem 1.5rem;
  margin-bottom: 0;
  position: relative;
  animation: fadeIn 0.3s ease both;
}
.card + .connector {
  width: 2px; height: 24px; background: var(--border);
  margin: 0 auto;
}
.card + .connector + .card { }
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; } }
.card:nth-child(1)  { animation-delay: 0s; }
.card:nth-child(3)  { animation-delay: 0.15s; }
.card:nth-child(5)  { animation-delay: 0.3s; }
.card:nth-child(7)  { animation-delay: 0.45s; }
.card:nth-child(9)  { animation-delay: 0.6s; }

.card-phase {
  font-size: 0.65rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: 0.12em; margin-bottom: 0.5rem; display: flex;
  align-items: center; gap: 0.5rem;
}
.card-phase .dot {
  width: 8px; height: 8px; border-radius: 50%; display: inline-block;
}
.card p { margin-bottom: 0.5rem; font-size: 0.9rem; }
.card p:last-child { margin-bottom: 0; }
.card .dim { color: var(--text-dim); }
.card .emph { font-weight: 600; }

/* Phase colors */
.card.observe .card-phase { color: var(--text-dim); }
.card.observe .dot { background: var(--text-dim); }
.card.crisis .card-phase { color: var(--warn); }
.card.crisis .dot { background: var(--warn); }
.card.crisis { border-color: rgba(240,160,80,0.3); }
.card.reorganize .card-phase { color: var(--oracle); }
.card.reorganize .dot { background: var(--oracle); }
.card.reorganize { border-color: rgba(155,122,237,0.2); }
.card.resolve .card-phase { color: var(--success); }
.card.resolve .dot { background: var(--success); }
.card.resolve { border-color: rgba(78,204,163,0.3); }
.card.direct-success .card-phase { color: var(--success); }
.card.direct-success .dot { background: var(--success); }
.card.failure .card-phase { color: var(--accent); }
.card.failure .dot { background: var(--accent); }
.card.failure { border-color: rgba(233,69,96,0.3); }

/* Tallies */
.tallies {
  font-family: var(--mono); font-size: 1rem;
  letter-spacing: 0.15em; margin: 0.5rem 0;
  line-height: 1.8;
}
.tallies .group { display: inline; margin-right: 0.4em; }
.tallies .mark { color: var(--text); }
.tallies .mark.counted { color: var(--success); }
.tallies .mark.uncounted { color: var(--border); opacity: 0.5; }
.tallies .op { color: var(--text-dim); margin: 0 0.3em; }
.tallies .bracket { color: var(--oracle); font-weight: bold; }

/* Resource bar */
.resource-bar {
  margin: 0.75rem 0 0.25rem;
  display: flex; align-items: center; gap: 0.5rem;
  font-family: var(--mono); font-size: 0.75rem; color: var(--text-dim);
}
.bar-track {
  flex: 1; height: 6px; background: var(--bg);
  border-radius: 3px; overflow: hidden; max-width: 200px;
}
.bar-fill {
  height: 100%; border-radius: 3px;
  transition: width 0.5s ease;
}
.bar-fill.ok { background: var(--success); }
.bar-fill.warn { background: var(--warn); }
.bar-fill.exhausted { background: var(--accent); }

/* Oracle quote */
.oracle-quote {
  background: rgba(155,122,237,0.08);
  border-left: 3px solid var(--oracle);
  padding: 0.5rem 0.75rem;
  margin: 0.5rem 0;
  font-size: 0.85rem;
  font-style: italic;
  color: var(--text);
}

/* Synthesis checklist */
.checklist { list-style: none; margin: 0.5rem 0; }
.checklist li {
  font-size: 0.85rem; padding: 0.15rem 0;
  display: flex; align-items: center; gap: 0.4rem;
}
.checklist .ok { color: var(--success); }
.checklist .fail { color: var(--accent); }

/* Knowledge panel */
.knowledge-panel {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.25rem 1.5rem;
  margin-top: 2rem;
}
.knowledge-panel h2 {
  font-size: 0.9rem; font-weight: 600; margin-bottom: 0.75rem;
}
.knowledge-op {
  display: flex; align-items: baseline; gap: 0.5rem;
  margin-bottom: 0.4rem; font-size: 0.85rem;
}
.knowledge-op .op-name {
  font-family: var(--mono); font-weight: 600;
  min-width: 70px; color: var(--text-dim);
}
.knowledge-op .strategies { color: var(--text); }
.knowledge-op .primordial {
  font-style: italic; color: var(--text-dim); font-size: 0.8rem;
}
.knowledge-op .arrow { color: var(--success); margin: 0 0.2rem; }

/* Empty state */
.empty-state {
  text-align: center; padding: 3rem 1rem; color: var(--text-dim);
}
.empty-state p { font-size: 0.9rem; margin-bottom: 0.5rem; }
.empty-state .suggestion {
  font-size: 0.8rem; font-family: var(--mono);
  background: var(--surface); display: inline-block;
  padding: 0.3rem 0.6rem; border-radius: 4px; margin-top: 0.5rem;
}

/* About */
.about {
  margin-top: 2rem; border-top: 1px solid var(--border);
  padding-top: 1rem;
}
.about summary {
  font-size: 0.8rem; color: var(--text-dim); cursor: pointer;
  list-style: none;
}
.about summary::before { content: "+ "; font-family: var(--mono); }
.about[open] summary::before { content: "- "; }
.about .about-body {
  font-size: 0.8rem; color: var(--text-dim); line-height: 1.7;
  margin-top: 0.75rem;
}
.about .about-body h3 {
  font-size: 0.8rem; color: var(--text); margin: 1rem 0 0.25rem;
}
.about .about-body p { margin-bottom: 0.5rem; }
</style>
</head>
<body>
<div class="container">

<header>
  <h1>ORR Cycle Explorer</h1>
  <p class="subtitle">Watch a machine learn arithmetic through crisis</p>
</header>

<div class="controls">
  <div class="controls-row">
    <div class="field">
      <label>Operation</label>
      <select id="op" onchange="checkWarnings()">
        <option value="add">add</option>
        <option value="subtract">subtract</option>
        <option value="multiply">multiply</option>
        <option value="divide">divide</option>
      </select>
    </div>
    <div class="field">
      <label>A</label>
      <input type="number" id="a" value="8" min="0" max="99" onchange="checkWarnings()">
    </div>
    <div class="field">
      <label>B</label>
      <input type="number" id="b" value="5" min="0" max="99" onchange="checkWarnings()">
    </div>
    <div class="field">
      <label>Limit</label>
      <input type="number" id="limit" value="20" min="5" max="500">
    </div>
    <div class="spacer"></div>
    <button class="run" id="run" onclick="compute()">Run</button>
    <button class="reset" onclick="resetMachine()">Reset</button>
  </div>
  <div class="limit-warning" id="warning">
    Numbers above ~15 use Peano representation (tally marks) and will be slow by design.
    This slowness triggers crisis and learning.
  </div>
</div>

<div id="narrative" class="narrative">
  <div class="empty-state">
    <p>The machine starts knowing only one thing: how to count.</p>
    <p>Give it a problem it cannot solve by counting alone.</p>
    <div class="suggestion">Try: 8 + 5 with limit 20</div>
  </div>
</div>

<div id="knowledge-panel" class="knowledge-panel">
  <h2>What the machine knows</h2>
  <div id="knowledge"></div>
</div>

<details class="about">
  <summary>About this system</summary>
  <div class="about-body">
    <h3>The ORR Cycle</h3>
    <p>Observe, Reorganize, Reflect. The machine attempts a computation using what it knows.
    When its approach fails (resource exhaustion or unknown operation), it enters crisis.
    Crisis triggers oracle consultation, strategy synthesis, and retry.</p>

    <h3>Counting All</h3>
    <p>The machine starts with one strategy: build both numbers as tallies (successor applications),
    then count the total from 1. This is how young children add before learning shortcuts.
    It works, but it is expensive: adding 8 + 5 requires constructing 13 tally marks and counting
    each one, which exceeds a tight inference budget.</p>

    <h3>The Oracle</h3>
    <p>The oracle is a black box containing expert strategies (from Carpenter and Fennema''s
    Cognitively Guided Instruction research). It returns a result and a description of the method, but not
    its internal workings. The machine must reconstruct the strategy from its own primitives
    (successor, predecessor, decompose). This models pragmatic expressive bootstrapping:
    observing vocabulary and reconstructing the practice that makes it intelligible.</p>

    <h3>Why this matters</h3>
    <p>This is not a calculator. It is a formal model of crisis-driven learning from the
    manuscript <em>Understanding Mathematics as an Emancipatory Discipline: A Critical Theory
    Approach</em>. The interesting thing is not the arithmetic but the structure of the
    developmental crisis and the limits of what formal systems can capture about learning.</p>
  </div>
</details>

</div>

<script>
const OP_SYMBOLS = { add: "+", subtract: "\\u2212", multiply: "\\u00d7", divide: "\\u00f7" };

const STRATEGY_NAMES = {
  "COBO": "Count On by Bases and Ones",
  "RMB": "Rearranging to Make Bases",
  "Chunking": "Chunking",
  "Rounding": "Rounding to Nearest Ten",
  "COBO (Missing Addend)": "Count On (Missing Addend)",
  "CBBO (Take Away)": "Count Back (Take Away)",
  "Decomposition": "Decomposition",
  "Sliding": "Sliding",
  "Chunking A": "Chunking (variant A)",
  "Chunking B": "Chunking (variant B)",
  "Chunking C": "Chunking (variant C)",
  "C2C": "Count to Count",
  "CBO": "Count By Ones to Base",
  "Commutative Reasoning": "Commutative Reasoning",
  "DR": "Doubling and Redistribution",
  "Dealing by Ones": "Dealing By Ones",
  "CBO (Division)": "Count By Ones to Base",
  "IDP": "Inverse Division by Product",
  "UCR": "Unit Coordination and Remainders"
};

const CRISIS_EXPLANATIONS = {
  efficiency_crisis: (a, b, op, limit) =>
    `The machine can ${op} by counting, but ${a} ${OP_SYMBOLS[op]} ${b} requires more ` +
    `counting steps than its ${limit}-inference budget allows. ` +
    `Counting All touches every unit one at a time \\u2014 it works, but at a cost ` +
    `proportional to the size of the numbers.`,
  unknown_operation: (a, b, op) =>
    `The machine has never encountered ${op}. It has no concept of this operation ` +
    `and cannot even begin to attempt it. This is not an efficiency problem \\u2014 ` +
    `the operation is entirely absent from the machine''s repertoire.`
};

function strategyDisplay(abbrev) {
  const full = STRATEGY_NAMES[abbrev];
  return full ? `${full} (${abbrev})` : abbrev;
}

function tallies(n) {
  if (n > 25) return `[${n}]`;
  let html = "";
  for (let i = 0; i < n; i++) {
    if (i > 0 && i % 5 === 0) html += " ";
    html += "\\u2758";
  }
  return html;
}

function resourceBar(used, total) {
  const pct = Math.min(100, Math.round((used / total) * 100));
  const cls = pct >= 100 ? "exhausted" : pct > 70 ? "warn" : "ok";
  return `<div class="resource-bar">
    <div class="bar-track"><div class="bar-fill ${cls}" style="width:${pct}%"></div></div>
    <span>${used}/${total} inferences${pct >= 100 ? " (exhausted)" : ""}</span>
  </div>`;
}

function makeCard(phase, cls, content) {
  return `<div class="card ${cls}">
    <div class="card-phase"><span class="dot"></span>${phase}</div>
    ${content}
  </div>`;
}

function connector() { return \'<div class="connector"></div>\'; }

function checkWarnings() {
  const a = parseInt(document.getElementById("a").value) || 0;
  const b = parseInt(document.getElementById("b").value) || 0;
  const warn = document.getElementById("warning");
  warn.style.display = (a > 15 || b > 15) ? "block" : "none";
}

async function compute() {
  const btn = document.getElementById("run");
  const narr = document.getElementById("narrative");
  btn.disabled = true;
  narr.innerHTML = "<p class=\\"dim\\" style=\\"text-align:center;padding:2rem\\">Computing...</p>";

  const problem = {
    operation: document.getElementById("op").value,
    a: parseInt(document.getElementById("a").value),
    b: parseInt(document.getElementById("b").value),
    limit: parseInt(document.getElementById("limit").value)
  };

  try {
    const res = await fetch("/api/compute", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(problem)
    });
    const data = await res.json();
    renderNarrative(data, problem);
    renderKnowledge(data.knowledge);
  } catch (e) {
    narr.innerHTML = `<div class="card failure">
      <div class="card-phase"><span class="dot"></span>Error</div>
      <p>${e.message}</p>
    </div>`;
  } finally {
    btn.disabled = false;
  }
}

function renderNarrative(data, problem) {
  const narr = document.getElementById("narrative");
  const events = data.events;
  const op = problem.operation;
  const a = problem.a, b = problem.b;
  const sym = OP_SYMBOLS[op];
  const limit = problem.budget || problem.limit;

  const cards = [];
  let resolveEvent = null;

  // Process events into cards
  let i = 0;
  while (i < events.length) {
    const e = events[i];

    if (e.type === "computation_start" && i + 1 < events.length) {
      const next = events[i + 1];

      if (next.type === "computation_success") {
        // Direct success
        const used = next.inferences_used || "?";
        const result = next.result != null ? next.result : "?";
        const isRetry = cards.length > 0;

        if (isRetry) {
          // This is the resolution after learning
          const strategy = resolveEvent ? resolveEvent.strategy : null;
          cards.push(makeCard("Resolve", "resolve", `
            <p class="emph" style="font-size:1.3rem">${a} ${sym} ${b} = ${result}</p>
            ${strategy ? `<p>Using ${strategyDisplay(strategy)}</p>` : ""}
            ${strategy ? renderStrategyVisual(op, a, b, result, strategy) : ""}
            ${resourceBar(used, limit)}
          `));
        } else {
          cards.push(makeCard("Observe", "direct-success", `
            <p>The machine computes <span class="emph">${a} ${sym} ${b} = ${result}</span></p>
            <p class="dim">Solved directly with current knowledge.</p>
            ${resourceBar(used, limit)}
          `));
        }
        i += 2;
        continue;
      }

      if (next.type === "crisis_detected") {
        // Failed attempt
        cards.push(makeCard("Observe", "observe", `
          <p>The machine attempts <span class="emph">${a} ${sym} ${b}</span>
          using its only approach: <span class="emph">Counting All</span>.</p>
          <p class="dim">Build both numbers as tallies, then count the total from 1.</p>
          <div class="tallies">${tallies(a)} <span class="op">${sym}</span> ${tallies(b)}</div>
          <p class="dim">Each tally mark costs an inference. The meta-interpreter adds overhead
          for each step of the computation.</p>
          ${resourceBar(limit, limit)}
        `));
        i += 2;

        // Crisis classification
        if (i < events.length && events[i].type === "crisis_classified") {
          const cls = events[i];
          const crisisType = cls.classification || "unclassified";
          const explanation = CRISIS_EXPLANATIONS[crisisType]
            ? CRISIS_EXPLANATIONS[crisisType](a, b, op, limit)
            : cls.signal || "The machine''s current approach has failed.";
          cards.push(makeCard("Crisis", "crisis", `
            <p class="emph">${crisisType.replace(/_/g, " ")}</p>
            <p>${explanation}</p>
            <p class="dim">The machine''s current way of being is inadequate.
            It must learn or fail.</p>
          `));
          i++;
        }

        // Reorganize: collect oracle + synthesis events
        const reorgParts = [];
        let synthesisOk = false;
        let validationOk = false;
        let oracleStrategy = null;
        let oracleResult = null;
        let oracleInterp = null;

        while (i < events.length && events[i].type !== "computation_start"
               && events[i].type !== "computation_failed") {
          const re = events[i];
          if (re.type === "oracle_consulted") {
            oracleStrategy = re.strategy;
            oracleResult = re.result;
            oracleInterp = re.interpretation;
          }
          if (re.type === "oracle_exhausted") {
            reorgParts.push(`<p class="dim">The oracle has nothing left to teach for this operation.</p>`);
          }
          if (re.type === "synthesis_succeeded") synthesisOk = true;
          if (re.type === "synthesis_failed") synthesisOk = false;
          if (re.type === "validation_passed") validationOk = true;
          if (re.type === "validation_failed") validationOk = false;
          if (re.type === "retry") resolveEvent = { strategy: oracleStrategy };
          i++;
        }

        if (oracleStrategy) {
          cards.push(makeCard("Reorganize", "reorganize", `
            <p class="emph">Oracle consultation</p>
            <p>Strategy: ${strategyDisplay(oracleStrategy)}</p>
            <div class="oracle-quote">${oracleInterp || ""}</div>
            <p class="dim">The oracle provides the result (${oracleResult}) and a description of
            the method, but not its internal workings. The machine receives
            <em>what</em> and <em>how</em>, but must reconstruct <em>why</em> from
            its own primitives (successor, predecessor, decompose).</p>
            <ul class="checklist">
              <li><span class="${synthesisOk ? "ok" : "fail"}">${synthesisOk ? "\\u2713" : "\\u2717"}</span>
                Strategy synthesized from primitives</li>
              <li><span class="${validationOk ? "ok" : "fail"}">${validationOk ? "\\u2713" : "\\u2717"}</span>
                Validation: result matches oracle</li>
            </ul>
            ${reorgParts.join("")}
          `));
        } else {
          cards.push(makeCard("Reorganize", "failure", `
            <p class="emph">Oracle could not help</p>
            ${reorgParts.join("")}
            <p class="dim">No strategy available. The crisis remains unresolved.</p>
          `));
        }
        continue;
      }
    }

    // Fallback for computation_failed at top level
    if (e.type === "computation_failed") {
      cards.push(makeCard("Failed", "failure", `
        <p>The computation failed. The machine could not solve
        ${a} ${sym} ${b} within its constraints.</p>
      `));
      i++;
      continue;
    }

    i++;
  }

  // Join cards with connectors
  narr.innerHTML = cards.join(connector());
}

function renderStrategyVisual(op, a, b, result, strategy) {
  if (!strategy) return "";

  if (strategy === "COBO" && op === "add") {
    // COBO decomposes B into tens (bases) and ones, then counts on
    const bases = Math.floor(b / 10);
    const ones = b % 10;
    const baseSteps = [];
    let cur = a;
    for (let s = 0; s < bases; s++) { cur += 10; baseSteps.push(cur); }
    const oneSteps = [];
    for (let s = 0; s < ones; s++) { cur += 1; oneSteps.push(cur); }
    let viz = `<div class="tallies"><span class="bracket">[${a}]</span>`;
    if (bases > 0) viz += `<span class="dim"> +${bases} tens: ${baseSteps.join(", ")}</span>`;
    if (ones > 0) viz += `<span class="dim"> +${ones} ones: ${oneSteps.join(", ")}</span>`;
    viz += `<span class="dim"> \\u2192 ${result}</span></div>`;
    return viz;
  }

  if (strategy === "COBO (Missing Addend)" && op === "subtract") {
    const steps = [];
    for (let s = b + 1; s <= a; s++) steps.push(s);
    return `<div class="tallies">
      <span class="bracket">[${b}]</span>
      <span class="dim"> count up to ${a}: ${steps.join(", ")} \\u2192 gap = ${result}</span>
    </div>`;
  }

  return "";
}

function renderKnowledge(knowledge) {
  const el = document.getElementById("knowledge");
  if (!knowledge) { el.innerHTML = "<p class=\\"dim\\">Loading...</p>"; return; }

  let html = "";
  for (const k of knowledge) {
    const learned = k.learned || [];
    const display = learned.length > 0
      ? "Counting All <span class=\\"arrow\\">\\u2192</span> " +
        learned.map(s => strategyDisplay(s)).join(", ")
      : "<span class=\\"primordial\\">Counting All only</span>";
    html += `<div class="knowledge-op">
      <span class="op-name">${k.operation}</span>
      <span class="strategies">${display}</span>
    </div>`;
  }
  el.innerHTML = html;
}

async function resetMachine() {
  if (!confirm("Reset the machine to primordial state? All learned strategies will be forgotten.")) return;
  await fetch("/api/reset", { method: "POST" });
  document.getElementById("narrative").innerHTML = `
    <div class="empty-state">
      <p>Machine reset to primordial state.</p>
      <p>It knows only Counting All.</p>
    </div>`;
  // Refresh knowledge
  const res = await fetch("/api/knowledge");
  const knowledge = await res.json();
  renderKnowledge(knowledge);
}

// Load initial knowledge state
(async function() {
  try {
    const res = await fetch("/api/knowledge");
    const knowledge = await res.json();
    renderKnowledge(knowledge);
  } catch(e) {}
})();

checkWarnings();
</script>
</body>
</html>'.

% ═══════════════════════════════════════════════════════════════════════
% Auto-start
% ═══════════════════════════════════════════════════════════════════════

:- initialization((start_server, thread_get_message(_))).
