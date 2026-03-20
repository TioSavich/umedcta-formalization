# prolog/ — Crisis-Driven Arithmetic Learning System (System B)

A Prolog system that learns arithmetic through crisis-driven accommodation.
Bootstraps from a primordial state (only counting-all addition) to full
4-operation arithmetic by detecting computational inadequacy and consulting
an oracle for expert strategies.

## Epistemological commitment

This system enacts **enactivist/Piagetian constructivism** mediated by
**encultured cognition** (Vygotsky): the oracle acts as cultural authority,
transmitting strategies only when the learner's crisis makes them receivable.
Learning occurs through the ORR cycle (Observe-Reorganize-Reflect), not through
pre-loaded templates.

The meta-interpreter's dual role — executing AND observing execution — creates
the computational analogue of divasion (inside/outside). See DIVASION_ARCHITECTURE.md.

## Architecture

```
Primordial State → Crisis → Oracle Consultation → Synthesis → Accommodation
     (add only)     ↓         (expert guidance)      ↓       (new capability)
                 Unknown
                 Operation                      Learn Strategy
```

## Core components

### Entry points
| File | Purpose |
|------|---------|
| `primordial_start.pl` | Primordial machine entry point (loads minimal kernel) |
| `main.pl` | Test query entry point |
| `config.pl` | System configuration (inference limits, costs) |

### ORR cycle (cognitive core)
| File | Role | Epistemology |
|------|------|-------------|
| `meta_interpreter.pl` | **Observe** — execute with resource limits, produce trace | System-specific |
| `reflective_monitor.pl` | **Reflect** — detect disequilibrium from trace | System-specific |
| `reorganization_engine.pl` | **Reorganize** — modify knowledge base | System-specific |
| `execution_handler.pl` | ORR orchestrator, crisis handling | System-specific |
| `reorganization_log.pl` | Logs ORR cycle events | System-specific |

### Knowledge
| File | Purpose | Epistemology |
|------|---------|-------------|
| `object_level.pl` | Dynamic knowledge base (starts primordial) | System-specific |
| `incompatibility_semantics.pl` | Core logic, modal operators, entailment | Reusable theory |
| `learned_knowledge_v2.pl` | Auto-generated learned strategies | System-specific |
| `more_machine_learner.pl` | Strategy learning engine | System-specific |
| `strategies.pl` | Strategy coordination | System-specific |

### Oracle and synthesis
| File | Purpose | Epistemology |
|------|---------|-------------|
| `oracle_server.pl` | Black-box expert interface (20+ strategies) | System-specific |
| `fsm_synthesis_engine.pl` | Create oracle-backed strategies from guidance | System-specific |
| `fsm_engine.pl` | Unified FSM execution engine | Reusable |
| `crisis_processor.pl` | Crisis type analysis | System-specific |
| `curriculum_processor.pl` | Representation bridge (Peano ↔ integer ↔ recollection) | Reusable |

### Grounded arithmetic
| File | Purpose | Epistemology |
|------|---------|-------------|
| `grounded_arithmetic.pl` | Embodied math operations with cost tracking | Reusable |
| `grounded_utils.pl` | Utility functions for grounded math | Reusable |
| `grounded_ens_operations.pl` | Equal-N-Sharing (fractional partitioning) | Reusable |
| `composition_engine.pl` | Embodied grouping for unit composition | Reusable |
| `normalization.pl` | Iterative equivalence-rule normalization | Reusable |

### Other
| File | Purpose | Epistemology |
|------|---------|-------------|
| `hermeneutic_calculator.pl` | Strategy dispatch by name | System-specific |
| `interactive_ui.pl` | Text-based menu interface | System-specific |
| `math_benchmark.pl` | Performance benchmarking | System-specific |

## Curriculum files

Three curriculum files model how a teacher's numerical choices force different
kinds of crises. Comparing their outcomes tests the manuscript's claim that crises
are productive.

| File | Pedagogy | Number format | Key property |
|------|----------|---------------|-------------|
| `crisis_curriculum_primordial.txt` | Hegelian escalation | Peano `s(s(0))` | Deliberately provokes resource exhaustion |
| `crisis_curriculum.txt` | Pragmatic escalation | Integer `add(50,50)` | Quick testing, less philosophical grounding |
| `mathematical_curriculum.txt` | Gentle progressive | Integer `add(1,1)` | Never forces a crisis — incremental only |

The primordial curriculum is the primary one. The gentle curriculum exists as a
control: a teacher using only gentle sequencing never produces the finite/infinite
dialectic. The interesting comparison is whether the same system, fed different
curricula, develops differently.

## Subdirectories

| Directory | Contents |
|-----------|----------|
| `Prolog/` | System A — PML Core (sequent calculus prover, modal logic) |
| `Prolog/math/` | Children's arithmetic strategy automata (reusable across systems) |
| `Prolog/tests/` | System A tests (core_test 28/28, dialectical_engine_test 15/15) |
| `Modal_Logic/` | LaTeX appendices, manuscript, philosophical dictionary |
| `tests/` | System B tests (integration, phase, and feature tests) |

## Documentation

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | System architecture overview |
| `BOOTSTRAP_CHECKLIST.md` | Implementation roadmap (phases 1-3 complete) |
| `DIVASION_ARCHITECTURE.md` | Philosophical grounding of computational self-transcendence |
| `REFACTORING_CHECKLIST.md` | Historical development log (10 phases complete) |
| `FRACTION_CRISIS_ASSESSMENT.md` | Gap analysis for fraction crisis learning (P1.7) |

## Quick start

```bash
# Run System A (PML Core)
cd Prolog && swipl -l load.pl

# Run System B bootstrap test
cd tests && swipl -g test_all -t halt test_phase_3_simple.pl

# Run System A tests
cd Prolog/tests && swipl -l core_test.pl && swipl -l dialectical_engine_test.pl
```

## Epistemology key

- **System-specific**: Enacts this system's particular epistemological commitments
  (enactivist crisis learning, oracle-as-cultural-authority, etc.)
- **Reusable**: Describes empirical content or provides infrastructure usable under
  different epistemological frameworks. Math strategy automata, grounded arithmetic,
  and the FSM engine are reusable. The ORR cycle and oracle interface are not.
- **Reusable theory**: Incompatibility semantics is philosophically committed (Brandom)
  but potentially shared between systems.

## Relationship between System A and System B

System A (PML Core in `Prolog/`) uses sequent calculus with modal cost tracking.
System B (this directory) uses a meta-interpreter with crisis detection and oracle
consultation. Both can use the arithmetic strategy automata in `Prolog/math/`.
Whether they should merge, layer, or stay separate is P2-1 in TODOS.md.
