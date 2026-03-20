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

### [P2-1] Assess relationship between System A and System B
Write assessment answering: (1) Is meta-interpreter's monological model the right frame?
(2) Can proves/4 replace or augment solve/4 in the crisis pipeline? (3) Where does
Arche-Trace interact with each system, and what breaks? (4) What does this tell us about
the "mathematical skeleton" thesis?
**Why:** Core intellectual deliverable. Determines whether systems merge, layer, or stay separate.
**Context:** Author suspects meta-interpreter is philosophically suspect (monological ≠
intersubjectivity-first). Arche-Trace designed to break formal proofs — breakpoints are
the interesting part. Three number representations (recollection, Peano, integer) are
intentional philosophical layers.
**Depends on:** P1-2 and P1.5-1 (both systems verified running)

## Phase 3: Interactive Exploration

### [P3-1] Add structured event logging
Add JSON event log alongside stdout in execution_handler, oracle_server,
fsm_synthesis_engine, server.pl. Each ORR step emits a structured event.
**Why:** Frontend can't visualize the ORR cycle from a text blob. Structured events
are the prerequisite for any visualization.
**Depends on:** Phase 1 complete (pipeline verified running)

### [P3-2] Fix silent failure when all oracle strategies are learned
In execution_handler.pl, consult_oracle_for_solution/4 silently fails when all strategies
for an operation are already learned. Should produce an explicit diagnostic.
**Why:** "The oracle has nothing left to teach" is philosophically interesting and should
be visible in the interactive exploration.
**Depends on:** P3-1 (should be a structured event, not just format output)

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
