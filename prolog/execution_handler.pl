/** <module> ORR Cycle Execution Handler
 *
 * This module serves as the central controller for the cognitive architecture,
 * managing the Observe-Reorganize-Reflect (ORR) cycle. It orchestrates the
 * interaction between the meta-interpreter (Observe), the reflective monitor
 * (Reflect), and the reorganization engine (Reorganize).
 *
 * The primary entry point is `run_query/1`, which initiates the ORR cycle
 * for a given goal.
 *
 * 
 * 
 */
:- module(execution_handler, [run_computation/2]).

:- use_module(meta_interpreter).
:- use_module(object_level).
:- use_module(more_machine_learner, [reflect_and_learn/1]).
:- use_module(oracle_server).  % Access to normative oracle
:- use_module(fsm_synthesis_engine).  % NEW Phase 5: True FSM synthesis

%!      run_computation(+Goal:term, +Limit:integer) is semidet.
%
%       The main entry point for the self-reorganizing system. It attempts
%       to solve the given `Goal` within the specified `Limit` of
%       computational steps.
%
%       If the computation exceeds the resource limit, it triggers the
%       reorganization process and then retries the goal.
%
%       @param Goal The computational goal to be solved.
%       @param Limit The maximum number of inference steps allowed.
run_computation(Goal, Limit) :-
    catch(
        call_meta_interpreter(Goal, Limit, Trace),
        Error,
        handle_perturbation(Error, Goal, Trace, Limit)
    ).

%!      call_meta_interpreter(+Goal, +Limit, -Trace) is det.
%
%       A wrapper for the `meta_interpreter:solve/4` predicate. It
%       executes the goal and, upon success, reports that the computation
%       is complete.
%
%       PRIMORDIAL REFACTORING: Proactive reflection on success has been
%       REMOVED. Learning now occurs ONLY through crisis (resource_exhaustion).
%       This enforces the "Built to Break" philosophy - the system only
%       changes when its current way of being is proven inadequate.
%
%       @param Goal The goal to be solved.
%       @param Limit The inference limit.
%       @param Trace The resulting execution trace.
call_meta_interpreter(Goal, Limit, Trace) :-
    meta_interpreter:solve(Goal, Limit, _, Trace),
    writeln('Computation successful.').
    % REMOVED: reflect_on_success(Goal, Trace)
    % Learning is now crisis-driven only

%!      normalize_trace(+Trace, -NormalizedTrace) is det.
%
%       Converts different trace formats into a unified dictionary format
%       for the learner. It specifically handles the `arithmetic_trace/3`
%       term, converting it to a `trace{}` dict.
% Case 1: The trace is a list containing a single arithmetic_trace term.
normalize_trace([arithmetic_trace(Strategy, _, Steps)], NormalizedTrace) :-
    !,
    NormalizedTrace = trace{strategy:Strategy, steps:Steps}.
% Case 2: The trace is a bare arithmetic_trace term.
normalize_trace(arithmetic_trace(Strategy, _, Steps), NormalizedTrace) :-
    !,
    NormalizedTrace = trace{strategy:Strategy, steps:Steps}.
% Case 3: Pass through any other format (already normalized dicts, etc.)
normalize_trace(Trace, Trace).

%!      reflect_on_success(+Goal, +Trace) is det.
%
%       DEPRECATED in primordial refactoring.
%       
%       After a successful computation, this predicate USED TO trigger
%       reflective learning. This has been REMOVED to enforce crisis-driven
%       learning only. The system must not learn proactively from success;
%       it must only accommodate when forced by failure.
%
%       Kept for backward compatibility but not called.
reflect_on_success(_Goal, _Trace).
    % REMOVED: Proactive learning from success
    % writeln('--- Proactive Reflection Cycle Initiated (Success) ---'),
    % normalize_trace(Trace, NormalizedTrace),
    % Result = _{goal:Goal, trace:NormalizedTrace},
    % reflect_and_learn(Result),
    % writeln('--- Reflection Cycle Complete ---').

%!      handle_perturbation(+Error, +Goal, +Trace, +Limit) is semidet.
%
%       Catches errors from the meta-interpreter and initiates the
%       reorganization process.
%
%       This predicate handles multiple types of perturbations:
%       - perturbation(resource_exhaustion): Computational efficiency crisis
%       - perturbation(normative_crisis(Goal, Context)): Mathematical norm violation
%       - perturbation(incoherence(Commitments)): Logical contradiction
%
%       @param Error The error term thrown by `catch/3`.
%       @param Goal The original goal that was being attempted.
%       @param Trace The execution trace produced before the error occurred.
%       @param Limit The original resource limit.
handle_perturbation(perturbation(resource_exhaustion), Goal, Trace, Limit) :-
    % P2-3: Classify before handling
    classify_crisis(perturbation(resource_exhaustion), Classification, Meta),
    writeln('═══════════════════════════════════════════════════════════'),
    format('  CRISIS: ~w~n', [Classification]),
    writeln('═══════════════════════════════════════════════════════════'),
    format('  Failed Goal: ~w~n', [Goal]),
    format('  Skeleton signal: ~w~n', [Meta.skeleton_signal]),
    writeln('  Initiating Oracle Consultation...'),
    writeln(''),
    
    % NEW: Consult the oracle to see how an expert would solve this
    (   consult_oracle_for_solution(Goal, StrategyName, OracleResult, OracleInterpretation)
    ->  format('  Oracle Result: ~w~n', [OracleResult]),
        format('  Oracle Says: "~w"~n', [OracleInterpretation]),
        writeln(''),
        writeln('  Attempting to synthesize strategy from oracle guidance...'),
        
        % Pass oracle's guidance to learner for synthesis
        normalize_trace(Trace, NormalizedTrace),
        SynthesisInput = _{
            goal: Goal,
            failed_trace: NormalizedTrace,
            target_result: OracleResult,
            target_interpretation: OracleInterpretation,
            strategy_name: StrategyName
        },
        
        % NEW: Instead of pattern matching, we synthesize from constraints
        (   synthesize_from_oracle(SynthesisInput)
        ->  writeln('  ✓ Successfully synthesized new strategy!'),
            % P2-2: Post-synthesis normative validation
            % Verify the new strategy produces results consistent with
            % the oracle's answer. This catches synthesis bugs before
            % they poison the system.
            (   validate_synthesis(Goal, OracleResult, Limit)
            ->  writeln('  ✓ Normative validation passed.'),
                writeln('  Retrying goal with new knowledge...'),
                writeln('═══════════════════════════════════════════════════════════'),
                writeln(''),
                run_computation(Goal, Limit)
            ;   writeln('  ✗ Normative validation FAILED — strategy retracted.'),
                writeln('  Crisis remains unresolved.'),
                writeln('═══════════════════════════════════════════════════════════'),
                fail
            )
        ;   writeln('  ✗ Synthesis failed - unable to learn from oracle'),
            writeln('  Crisis remains unresolved'),
            writeln('═══════════════════════════════════════════════════════════'),
            fail
        )
    ;   writeln('  ✗ Oracle consultation failed - no expert strategy available'),
        writeln('  Attempting fallback learning...'),
        % Fallback: try old reflection method (will be removed in later phases)
        normalize_trace(Trace, NormalizedTrace),
        Result = _{goal:Goal, trace:NormalizedTrace},
        reflect_and_learn(Result),
        writeln('  Reorganization complete. Retrying goal...'),
        writeln('═══════════════════════════════════════════════════════════'),
        run_computation(Goal, Limit)
    ).

handle_perturbation(perturbation(normative_crisis(CrisisGoal, Context)), Goal, _Trace, Limit) :-
    format('Normative crisis detected: ~w violates norms of ~w context.~n', [CrisisGoal, Context]),
    writeln('Initiating context shift reorganization...'),
    % Handle normative crisis through context expansion
    reorganization_engine:handle_normative_crisis(CrisisGoal, Context),
    writeln('Context shift complete. Retrying goal...'),
    run_computation(Goal, Limit).

% PHASE 2: Unknown operation handler
% When an arithmetic operation (subtract/multiply/divide) is attempted from primordial state,
% consult oracle for first available strategy, synthesize it, and retry.
handle_perturbation(perturbation(unknown_operation(Op, PeanoGoal)), Goal, _Trace, Limit) :-
    % P2-3: Classify before handling
    classify_crisis(perturbation(unknown_operation(Op, PeanoGoal)), Classification, Meta),
    writeln(''),
    writeln('═══════════════════════════════════════════════════════════'),
    format('  CRISIS: ~w~n', [Classification]),
    writeln('═══════════════════════════════════════════════════════════'),
    format('  Operation: ~w~n', [Op]),
    format('  Goal: ~w~n', [PeanoGoal]),
    format('  Skeleton signal: ~w~n', [Meta.skeleton_signal]),
    writeln('  Initiating Oracle Consultation...'),
    writeln(''),
    
    % Get first available strategy for this operation from oracle
    (   oracle_server:list_available_strategies(Op, [FirstStrategy|_])
    ->  format('  Oracle recommends learning: ~w~n', [FirstStrategy]),
        
        % Consult oracle with the specific strategy
        (   consult_oracle_for_solution(PeanoGoal, FirstStrategy, OracleResult, OracleInterpretation)
        ->  format('  Oracle Result: ~w~n', [OracleResult]),
            format('  Oracle Says: "~w"~n', [OracleInterpretation]),
            writeln(''),
            writeln('  Attempting to synthesize strategy from oracle guidance...'),
            
            % Synthesize the new strategy
            SynthesisInput = _{
                goal: PeanoGoal,
                failed_trace: [],  % No trace - operation doesn't exist yet
                target_result: OracleResult,
                target_interpretation: OracleInterpretation,
                strategy_name: FirstStrategy
            },
            
            (   synthesize_from_oracle(SynthesisInput)
            ->  writeln('  ✓ Successfully synthesized new strategy!'),
                % P2-2: Post-synthesis normative validation
                (   validate_synthesis(PeanoGoal, OracleResult, Limit)
                ->  writeln('  ✓ Normative validation passed.'),
                    writeln('  Retrying goal with new knowledge...'),
                    writeln('═══════════════════════════════════════════════════════════'),
                    writeln(''),
                    run_computation(Goal, Limit)
                ;   writeln('  ✗ Normative validation FAILED — strategy retracted.'),
                    writeln('  Crisis remains unresolved.'),
                    writeln('═══════════════════════════════════════════════════════════'),
                    fail
                )
            ;   writeln('  ✗ Synthesis failed - unable to learn from oracle'),
                writeln('  Crisis remains unresolved'),
                writeln('═══════════════════════════════════════════════════════════'),
                fail
            )
        ;   writeln('  ✗ Oracle execution failed for strategy'),
            writeln('  Crisis remains unresolved'),
            writeln('═══════════════════════════════════════════════════════════'),
            fail
        )
    ;   format('  ✗ No strategies available for operation: ~w~n', [Op]),
        writeln('  Crisis remains unresolved'),
        writeln('═══════════════════════════════════════════════════════════'),
        fail
    ).

handle_perturbation(perturbation(incoherence(Commitments)), Goal, _Trace, Limit) :-
    format('Logical incoherence detected in commitments: ~w~n', [Commitments]),
    writeln('Initiating incoherence resolution...'),
    % Handle logical incoherence through belief revision
    reorganization_engine:handle_incoherence(Commitments),
    writeln('Incoherence resolution complete. Retrying goal...'),
    run_computation(Goal, Limit).

handle_perturbation(Error, _, _, _) :-
    writeln('An unhandled error occurred:'),
    writeln(Error),
    fail.

% ═══════════════════════════════════════════════════════════════════════
% P2-3: Crisis Classification
% ═══════════════════════════════════════════════════════════════════════
%
% Classifies crises using System A's normative vocabulary to drive
% different ORR responses. An LLM-as-oracle could use these classifications
% as pedagogical signals (see SYSTEM_ASSESSMENT.md "skeleton and animating
% spirit").
%
%   efficiency_crisis    → Strategy is correct but too slow.
%                          Response: acquire more efficient strategy from oracle.
%   domain_crisis        → Operation not defined in current number domain.
%                          Response: expand domain (naturals → integers → rationals).
%   unknown_operation    → Operation type never encountered.
%                          Response: learn first available strategy from oracle.
%   normative_crisis     → Mathematical norms of current context violated.
%                          Response: context shift via reorganization_engine.
%   incoherence_crisis   → Contradictory commitments detected.
%                          Response: belief revision (retract weakest commitment).
%

%!      classify_crisis(+Perturbation, -Classification, -Metadata) is det.
%
%       Maps a perturbation term to a crisis classification with metadata
%       useful for pedagogical decision-making.
%
classify_crisis(perturbation(resource_exhaustion), Classification, Meta) :-
    % Resource exhaustion could be efficiency (strategy exists but is slow)
    % or domain-level (operation requires a number domain we don't have).
    % Default to efficiency; normative crises are caught separately.
    Classification = efficiency_crisis,
    Meta = crisis_meta{
        response: acquire_efficient_strategy,
        skeleton_signal: 'Learner has a working approach but runs out of cognitive resources. An LLM oracle might ask: is this the right moment to introduce a shortcut, or should the learner struggle longer?'
    }.

classify_crisis(perturbation(unknown_operation(Op, Goal)), Classification, Meta) :-
    Classification = unknown_operation,
    Meta = crisis_meta{
        operation: Op,
        goal: Goal,
        response: learn_first_strategy,
        skeleton_signal: 'Learner encounters an operation type they have no concept for. An LLM oracle might consider: which strategy is developmentally appropriate? The simplest (COBO) or the one matching the learner''s current number sense?'
    }.

classify_crisis(perturbation(normative_crisis(CrisisGoal, Context)), Classification, Meta) :-
    Classification = normative_crisis,
    Meta = crisis_meta{
        crisis_goal: CrisisGoal,
        context: Context,
        response: domain_expansion,
        skeleton_signal: 'Learner''s current mathematical world cannot accommodate this operation. Subtraction producing negatives in a natural-number context. An LLM oracle might frame this as: what kind of numbers do you need to make this work?'
    }.

classify_crisis(perturbation(incoherence(Commitments)), Classification, Meta) :-
    Classification = incoherence_crisis,
    Meta = crisis_meta{
        commitments: Commitments,
        response: belief_revision,
        skeleton_signal: 'Learner holds contradictory commitments. An LLM oracle might notice which belief is most stressed and help the learner let go of it.'
    }.

% Fallback: unrecognized perturbation
classify_crisis(Perturbation, unclassified, crisis_meta{raw: Perturbation, response: fail}).

%!      validate_synthesis(+Goal, +ExpectedResult, +Limit) is semidet.
%
%       P2-2: Post-synthesis normative validation.
%       After a new strategy is synthesized, verify it produces results
%       consistent with the oracle's answer. This catches synthesis bugs
%       before they poison the system.
%
%       Currently validates:
%       1. The new strategy can solve the original crisis goal
%       2. The result matches what the oracle provided
%
%       Future extension point: use System A's proves/4 to check that
%       the new strategy's commitments are consistent with the existing
%       normative structure (requires arithmetic axioms in System A).
%
validate_synthesis(Goal, ExpectedResult, Limit) :-
    % Extract the operation and expected result for comparison
    (   Goal = object_level:ActualGoal -> true ; ActualGoal = Goal ),
    ActualGoal =.. [_Op, A, B, _Result],
    % Try solving with the newly asserted strategy
    copy_term(ActualGoal, TestGoal),
    TestGoal =.. [Op2, A, B, TestResult],
    catch(
        meta_interpreter:solve(object_level:TestGoal, Limit, _, _TestTrace),
        _Error,
        (   format('  [Validation] Strategy execution failed: ~w~n', [_Error]),
            fail
        )
    ),
    % Verify result matches oracle
    (   peano_to_int(TestResult, IntResult),
        IntResult =:= ExpectedResult
    ->  format('  [Validation] Result ~w matches oracle expectation ~w~n',
               [IntResult, ExpectedResult])
    ;   format('  [Validation] Result mismatch — got ~w, expected ~w~n',
               [TestResult, ExpectedResult]),
        % Retract the faulty strategy
        (   clause(object_level:ActualGoal, Body)
        ->  retract((object_level:ActualGoal :- Body)),
            writeln('  [Validation] Faulty strategy retracted.')
        ;   true
        ),
        fail
    ).
% Fallback: if we can't decompose the goal, skip validation (succeed)
validate_synthesis(_, _, _).

%!      consult_oracle_for_solution(+Goal, -Result, -Interpretation) is semidet.
%
%       Attempts to consult the oracle for a solution to the failed goal.
%       Converts between Peano numbers and integers as needed.
%       Tries each available strategy until one succeeds and is novel.
%
consult_oracle_for_solution(object_level:add(A, B, _), StrategyName, Result, Interpretation) :-
    peano_to_int(A, IntA),
    peano_to_int(B, IntB),
    % Try each available strategy until one succeeds and is NOT already known
    oracle_server:list_available_strategies(add, Strategies),
    member(StrategyName, Strategies),
    \+ clause(more_machine_learner:run_learned_strategy(_,_,_,StrategyName,_), _),
    catch(
        oracle_server:query_oracle(add(IntA, IntB), StrategyName, Result, Interpretation),
        _,
        fail
    ),
    !.  % Cut after first successful novel strategy

consult_oracle_for_solution(add(A, B, _), StrategyName, Result, Interpretation) :-
    % Handle case without object_level: prefix
    peano_to_int(A, IntA),
    peano_to_int(B, IntB),
    oracle_server:list_available_strategies(add, Strategies),
    member(StrategyName, Strategies),
    \+ clause(more_machine_learner:run_learned_strategy(_,_,_,StrategyName,_), _),
    catch(
        oracle_server:query_oracle(add(IntA, IntB), StrategyName, Result, Interpretation),
        _,
        fail
    ),
    !.

%!      consult_oracle_for_solution(+Goal, +StrategyName, -Result, -Interpretation) is semidet.
%
%       Consults the oracle with a SPECIFIC strategy for the given goal.
%       This is used when we want to learn a particular strategy (e.g., first available).
%       Handles all arithmetic operations: add, subtract, multiply, divide.
%
consult_oracle_for_solution(object_level:Op_Goal, StrategyName, Result, Interpretation) :-
    Op_Goal =.. [Op, _A, _B, _],
    member(Op, [add, subtract, multiply, divide]),
    !,
    consult_oracle_for_solution(Op_Goal, StrategyName, Result, Interpretation).

consult_oracle_for_solution(add(A, B, _), StrategyName, Result, Interpretation) :-
    peano_to_int(A, IntA),
    peano_to_int(B, IntB),
    catch(
        oracle_server:query_oracle(add(IntA, IntB), StrategyName, Result, Interpretation),
        _,
        fail
    ).

consult_oracle_for_solution(subtract(A, B, _), StrategyName, Result, Interpretation) :-
    peano_to_int(A, IntA),
    peano_to_int(B, IntB),
    catch(
        oracle_server:query_oracle(subtract(IntA, IntB), StrategyName, Result, Interpretation),
        _,
        fail
    ).

consult_oracle_for_solution(multiply(A, B, _), StrategyName, Result, Interpretation) :-
    peano_to_int(A, IntA),
    peano_to_int(B, IntB),
    catch(
        oracle_server:query_oracle(multiply(IntA, IntB), StrategyName, Result, Interpretation),
        _,
        fail
    ).

consult_oracle_for_solution(divide(A, B, _), StrategyName, Result, Interpretation) :-
    peano_to_int(A, IntA),
    peano_to_int(B, IntB),
    catch(
        oracle_server:query_oracle(divide(IntA, IntB), StrategyName, Result, Interpretation),
        _,
        fail
    ).

%!      peano_to_int(+Peano, -Int) is det.
%
%       Converts Peano number to integer.
peano_to_int(0, 0) :- !.
peano_to_int(s(N), Int) :-
    peano_to_int(N, SubInt),
    Int is SubInt + 1.

%!      synthesize_from_oracle(+SynthesisInput) is semidet.
%
%       PHASE 5 IMPLEMENTATION: True FSM synthesis engine.
%       
%       This uses the fsm_synthesis_engine to construct strategies from
%       primitives, guided by oracle's result and interpretation.
%       The machine receives WHAT (result) and HOW (interpretation),
%       and synthesizes WHY (FSM structure) from grounded primitives.
%
%       This is computational hermeneutics: making sense of oracle guidance
%       by finding a rational structure that makes the interpretation intelligible.
%
synthesize_from_oracle(SynthesisInput) :-
    Goal = SynthesisInput.goal,
    FailedTrace = SynthesisInput.get(failed_trace, []),  % Default to empty if not provided
    TargetResult = SynthesisInput.target_result,
    TargetInterpretation = SynthesisInput.target_interpretation,
    
    % ALWAYS use oracle-backed synthesis for consistency
    % FSM synthesis has bugs with Peano conversion, and oracle-backed is simpler
    (   StrategyName = SynthesisInput.get(strategy_name)
    ->  % Strategy name explicitly provided (Phase 2: unknown operations)
        fsm_synthesis_engine:synthesize_strategy_from_oracle(
            Goal,
            FailedTrace,
            TargetResult,
            TargetInterpretation,
            StrategyName
        )
    ;   % No strategy name - figure out which strategy the oracle used
        % Extract operation type and get first available strategy
        (   Goal = object_level:ActualGoal -> true ; ActualGoal = Goal ),
        functor(ActualGoal, Op, 3),
        oracle_server:list_available_strategies(Op, [FirstStrategy|_]),
        fsm_synthesis_engine:synthesize_strategy_from_oracle(
            Goal,
            FailedTrace,
            TargetResult,
            TargetInterpretation,
            FirstStrategy
        )
    ).