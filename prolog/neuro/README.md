# neuro/ — Neuro-Symbolic Bridge

Experimental bridge between learned proof strategies and the incompatibility
semantics prover. This directory connects empirical strategy learning (System B)
with formal proof (System A).

## Epistemological status: hybrid

The neuro-symbolic bridge attempts to learn proof strategies from successful
computations and suggest them for future proofs. This sits between the normative
(Brandom) and constructivist (Piaget/Steffe) epistemologies — it uses empirical
pattern recognition to inform normative inference.

## Files

| File | Purpose |
|------|---------|
| `neuro_symbolic_bridge.pl` | Strategy suggestion and learning (`suggest_strategy/3`, `learn_euclid_strategy/0`) |
| `incompatibility_semantics.pl` | Extended IS with neural-backed strategy selection |
| `incompatibility_semantics.py` | Python companion for neural components |
| `learned_knowledge_v2.pl` | Persistent storage for learned proof strategies |
| `test_synthesis.pl` | Tests for synthesis with neural bridge (7/20 fail — rdiv recursion bug) |

## Known issues

`test_synthesis.pl` shares the `is_recollection/2` rdiv recursion bug with the
root-level test_synthesis.pl. Both loop infinitely when encountering rational
number terms.
