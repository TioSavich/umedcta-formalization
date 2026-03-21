# TODOS — UMEDCTA Formalization

## Phase 1: Fix & Verify (do now)

### [P1-1] Fix all Prolog warnings ✓ DONE
Fixed all singleton variable, discontiguous predicate, and broken module path warnings.
Production codebase loads with zero warnings on both `Prolog/load.pl` and `server.pl`.

### [P1-2] Run all 24 test files and document results ✓ DONE
Results: 16 PASS, 3 PARTIAL, 1 KNOWN BUG, 2 FAIL, 1 BROKEN (missing deps).
**Key finding:** 19 individual test failures across `test_synthesis.pl` (12/42 fail) and
`neuro/test_synthesis.pl` (7/20 fail) share one root cause: non-terminating recursion in
`is_recollection/2` when given `rdiv` (rational number) terms. The prover loops infinitely
trying to check if a rational is a recollection.
**Other failures:** `test_fractional_arithmetic.pl` missing `jason` and `fraction_semantics`
modules. `test_force_learn_all.pl` hits `not_implemented` for RMB strategy.
`test_inference_counting.pl` documents known bug: inference counter doesn't trigger exhaustion.
**All PML Core tests pass (28/28).** Crisis learning pipeline core tests all pass.

## Phase 1.5: PML Core

### [P1.5-1] Write dialectical_engine test ✓ DONE
Created `Prolog/tests/dialectical_engine_test.pl` — 15 tests covering:
- `run_computation/2`: identity sequent, PML rhythm transitions (U→A, A→LG),
  Oobleck dynamic, explosion, resource exhaustion, stress map tracking
- `run_fsm/4`: two-state automaton, stuck state, immediate accept, bare atom
  state, history ordering
All 15 pass. Core tests (28/28) unaffected.

## Phase 1.7: Fraction Crisis Learning

### [P1.7-0] Wire Jason PFS/FCS into oracle_server ✓ DONE
Added `jason_fsm` module (renamed from `jason_backup` to avoid module conflict with
`jason.pl`). Oracle now handles `fraction(Num, Den)` via PFS and
`fraction_composition(A-B, C-D)` via FCS. Both return results and black-box
interpretations through `query_oracle/4`.

### [P1.7-1] Wire oracle-backed fraction strategies into crisis pipeline
Add `consult_oracle_for_solution/4` clause in `execution_handler.pl` for fraction goals.
Add `fraction/3` to meta-interpreter's unknown_operation detection. Add primordial
`object_level:fraction/3` stub that triggers crisis.
**Why:** Gets fraction crises working through the existing ORR cycle.
**Difficulty:** Easy (~2 hours). Structurally identical to subtract/multiply/divide wiring.
**Depends on:** P1.7-0 (oracle fraction support)

### [P1.7-2] Design representation bridge for fraction goals
Decide how fraction goals enter the meta-interpreter. The ORR pipeline uses Peano
numbers; the fraction modules use recollection structures and `unit(Value, History)`.
The `curriculum_processor.pl` shows one bridge pattern (integer → recollection).
**Why:** This is a philosophical design question, not just a technical one. What does
"encountering a fraction" mean for a system that started with tally marks?
**Difficulty:** Medium. Requires design decision about representation.
**Depends on:** P1.7-1

### [P1.7-3] Add ENS primitives to FSM synthesis engine
Add `ens_partition`, `ens_disembed`, `ens_iterate` as synthesis primitives in
`fsm_synthesis_engine.pl`. Add `detect_hint/2` for fractional vocabulary (partition,
disembed, iterate, part, whole). Write `synthesize_partition_iterate` strategy builder.
**Why:** Without this, the system can only create oracle-backed fraction strategies
(philosophically hollow — the learner just memorizes a phone number). True synthesis
means discovering ENS operations from the interpretation hints.
**Difficulty:** Hard. This is where the manuscript's thesis gets tested.
**Depends on:** P1.7-2
**Note:** Failure here is *instructive*. Three specific challenges documented in
`prolog/FRACTION_CRISIS_ASSESSMENT.md`: variable base (not fixed like base-10),
three-level unit coordination (vs two-level for whole numbers), and metamorphic
accommodation (recursive strategy composition, not flat FSMs).

## Phase 2: System Architecture Assessment

### [P2-1] Assess relationship between System A and System B ✓ DONE
Written to `prolog/SYSTEM_ASSESSMENT.md`. Key findings:
- **Don't merge, layer explicitly.** solve/6 models computing, proves/4 models justifying.
  Merging conflates two activities the manuscript distinguishes.
- **Meta-interpreter IS monological** but System A doesn't escape it either — the sequent
  calculus represents intersubjective structure without enacting it.
- **Arche-Trace marks the skeleton boundary**: proofs about crisis experience, strategy
  preference, and recognition get erased. These erasure points are where interpretive
  analysis (LLM, teacher, human judgment) must take over.
- **Three augmentation points**: post-synthesis normative validation (P2-2), finer crisis
  classification (P2-3), modal cost unification (P2-4).

### [P2-2] Post-synthesis normative validation ✓ DONE
Added `validate_synthesis/3` to `execution_handler.pl`. After strategy synthesis, the
system now verifies the new strategy produces results matching the oracle's answer before
retrying. If validation fails, the faulty strategy is retracted. Currently validates
procedural correctness (result agreement); future extension point for deeper normative
validation via System A's `proves/4` when arithmetic axioms are added to the sequent
calculus.

### [P2-3] Finer crisis classification via incompatibility semantics ✓ DONE
Added `classify_crisis/3` to `execution_handler.pl`. Five crisis types:
- `efficiency_crisis` — strategy works but too slow (resource exhaustion)
- `unknown_operation` — operation type never encountered
- `normative_crisis` — mathematical norms of current context violated
- `incoherence_crisis` — contradictory commitments detected
- `unclassified` — fallback for unrecognized perturbations
Each classification includes a `skeleton_signal` — a natural-language description of
what an LLM-as-oracle would need to consider at this crisis point.

### [P2-4] Unify modal cost models ✓ DONE
Modified `solve(incur_cost(Action), ...)` in `meta_interpreter.pl` to multiply action
costs by modal context (compressive=2×, expansive/neutral=1×). A `unit_count` that costs
5 in neutral context now costs 10 under compressive necessity. Strategy runtime costs
(`strategy_runtime_cost/4`) also context-adjusted. Unifies System A's
`get_inference_cost/2` with System B's `cognitive_cost/2`.

### [P2-5] Document Arche-Trace erasure points ✓ DONE
Written to `prolog/ARCHE_TRACE_ERASURE.md`. Ran 14 experiments cataloging the precise
boundary: any proof where sequent variables carry the `arche_trace` attribute produces
`erasure(...)` instead of `proof(...)`. Three zones mapped: clear formal (normal proofs),
erasure zone (derivation succeeds but proof object is hollow), incoherence zone (claim
is rejected outright). Erasure points: identity with Trace, S-O Inversion, double
negation elimination, Oobleck S→O transfer. Unsatisfiable Desire is incoherence, not
just erasure.

## Phase 3: Interactive Exploration

### [P3-1] Add structured event logging ✓ DONE
Created `event_log.pl` module (emit/2, reset_events/0, get_events/1, events_to_json/1).
Wired emit/2 calls into every ORR cycle step in `execution_handler.pl`:
computation_start, computation_success, crisis_detected, crisis_classified,
oracle_consulted, oracle_exhausted, synthesis_attempted, synthesis_succeeded/failed,
validation_passed/failed, retry, computation_failed.
Custom JSON serializer — no external library dependency.

### [P3-2] Fix silent failure when all oracle strategies are learned ✓ DONE
Added `find_novel_strategy/2` helper in `execution_handler.pl`. When all strategies
for an operation are already learned, emits `oracle_exhausted` event with
`reason: all_strategies_learned` instead of silently failing.

### [P3-S] Build HTTP server and frontend ✓ DONE
Created `server.pl` — minimal HTTP server exposing the ORR cycle as a JSON API.
Three endpoints: POST /api/compute, GET /api/strategies, GET /api/events.
Inline single-page frontend at / — dark-themed timeline visualization of ORR events.
Stdout from run_computation captured via `with_output_to/2` to avoid corrupting HTTP.
Usage: `swipl server.pl` → http://localhost:8080

### [P3-3] Fix config.pl race condition (thread-safety)
web server uses retractall/assertz for max_inferences — global mutable state that races
in multi-threaded SWI-Prolog HTTP server. Fix with thread_local or parameter passing.
**Why:** Will cause mysterious bugs if multiple browser tabs send concurrent requests.
**Depends on:** Phase 3 frontend work (single-user local dev until then)

### [P3-4] Document performance bounds for large inputs
Note that Peano/recollection representations are intentionally slow for large numbers.
Interactive exploration should warn users that add(100, 50) with high limits will be slow.
**Why:** Slowness is by design (triggers crisis) but users need to understand this.
**Depends on:** P3-1 (interactive exploration exists)
