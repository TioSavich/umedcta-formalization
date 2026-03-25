# 03 — Oracle Redesign

## Purpose

Redesign the oracle from an answer-giving expert to a normative scorekeeper
that validates projections, asks questions, and says "no." The oracle is the
second-person layer — the community of practice that teaches vocabulary and
enforces norms.

## What the oracle currently does (and shouldn't)

The current `oracle_server.pl`:
- Receives an operation and strategy name
- Internally runs the strategy FSM
- Returns the result AND an interpretation string
- The synthesis engine wraps this in a clause and asserts it

This is philosophically wrong. The oracle does the learner's work. The
"learned" strategy is just a call back to the oracle. The system demonstrates
crisis-driven learning as architecture but not genuine knowledge construction.

## What the oracle should do

### 1. Validate or reject claims

```prolog
%% oracle_validate(+Claim, -Response)
%% Claim: a proposition the system asserts, e.g.,
%%   partition(ten, seven, three)
%%   more(five, three, two)
%%   add(eight, five, thirteen)
%% Response: yes | no
```

The oracle does NOT explain why. It does not provide the correct answer on
rejection. It just says yes or no. The system must figure out what went wrong.

### 2. Ask questions

```prolog
%% oracle_question(+Context, -Question)
%% Context: the current state of the system's knowledge
%% Question: a query the oracle poses, e.g.,
%%   "What is seven more than three?"
%%   "Is five three-more-than-two?"
%%   "Count from three to ten. How many steps?"
```

Questions serve two functions:
- **Prompting reflection**: The question forces the system to examine its own
  traces and meaning fields.
- **Testing projective validity**: The question presents a new context in which
  existing rules might or might not extend.

The oracle's question-selection is where the "intelligence" of the teaching
lives. This is analogous to a teacher choosing which problems to pose. For now,
questions can be hard-coded per curriculum level. A more sophisticated system
might select questions based on the current state of meaning fields.

### 3. Name things (normatively)

```prolog
%% oracle_name(+TallySequence, -NumberWord)
%% oracle_name(s(s(0)), two).
%% oracle_name(s(s(s(0))), three).
```

Naming is normative — the oracle teaches that THIS tally-sequence is CALLED
`two`. The system has no access to this mapping until taught. Number-words are
Prolog atoms with no built-in arithmetic significance.

### 4. Provide curriculum structure

```prolog
%% oracle_curriculum_level(+Level, -Questions)
%% Returns the questions appropriate for the current level.
%% Level 0: naming (tallies → number-words)
%% Level 1: counting (successor, predecessor, more, less)
%% Level 2: partitions of benchmark numbers
%% Level 3: addition/subtraction strategies
%% Level 4: multiplication/division strategies
%% Level 5: fractions
```

The oracle does NOT prescribe the curriculum in full. It provides questions
appropriate to the current level. The system's responses — and the oracle's
validations/rejections — generate the actual learning trajectory.

## What the oracle must NOT do

- **Must NOT compute results.** The oracle validates claims; it does not solve
  problems. If the system asks "what is eight plus five?" the oracle does not
  answer. It can ask "IS eight plus five thirteen?" and the system can check.
- **Must NOT provide strategy descriptions.** The current oracle returns
  interpretation strings like "Count on from 8 by 5." The redesigned oracle
  does not explain strategies. Strategies are discovered through the system's
  own activity and validated by the oracle.
- **Must NOT use Prolog's native arithmetic internally for validation.**
  The oracle should validate against a table of endorsed facts — facts that
  have been established through the system's own counting and the oracle's
  prior validations. (Exception: an outer "objective check" layer may use
  native arithmetic, but this should be clearly separated and labeled as
  o/1 objective validity, not n/1 normative validity.)

## The "no" as information

The oracle's rejection is the most important pedagogical act. It is the
**informative signal** that depopulates meaning fields:

- Child takes pizza AND ice cream → parent says "no" → XOR is learned
- System claims `partition(ten, four, seven)` → oracle says "no" → this
  interpretation is rejected, connective becomes XOR
- System projects counting-on into subtraction incorrectly → oracle says
  "no" → the projection is recorded as invalid

Each "no" is a determination. It doesn't just remove a possibility — it
structures the meaning field by establishing what is incompatible with what.

The critical expressivist alternative to "you are wrong": the oracle might
say "others may not understand what you are trying to say." In the
formalization, this translates to: the oracle rejects the claim but does not
penalize the system. The rejected claim is recorded, and the system must
determine why the rejection occurred through its own reflection.

## Philosophical constraints

- The oracle operates at the **normative** (n/1) level only. It represents the
  community's scorekeeping, not objective truth or subjective experience.
- The oracle's authority is **revisable**. In principle, the oracle could be
  wrong (norms can be challenged). The formalization doesn't need to implement
  this, but documentation should acknowledge it.
- The oracle is the **enabling condition for recognition**, not a dictator.
  Education is partially an enabling condition for recognition (Savich, 2022,
  p. 221). The oracle enables the system to participate in mathematical
  practices by teaching vocabulary and validating moves.

## Migration path from current oracle

1. Keep `oracle_server.pl` file but gut internals
2. Replace `query_oracle/4` with `oracle_validate/2`
3. Add `oracle_question/2` and `oracle_name/2`
4. Remove all direct FSM execution from oracle — strategies run in the system,
   not in the oracle
5. The objective check (Prolog's native arithmetic) should be a separate module,
   clearly labeled as o/1 validation, available for testing but not for learning

## Open questions

- How does the oracle decide which questions to ask? Hard-coded per level is
  honest but limited. Adaptive question selection based on meaning field state
  would be more interesting but harder.
- Should the oracle ever volunteer information, or only respond to system
  claims and ask questions? The latter is more Socratic and more aligned with
  the philosophy.
- How does the oracle handle the system making the same wrong claim
  repeatedly? This might trigger a different kind of intervention — not "no"
  again, but a question designed to prompt reflection on why the claim fails.
