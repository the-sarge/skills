# Experiment: <ID — decision to resolve>

Use one entry per experiment. Fill the plan before running; append observations and the disposition afterward. Link shared workload and environment definitions rather than repeating them. Mark irrelevant fields as not applicable with a short reason. Keep raw artifacts outside the narrative where appropriate.

## Plan

- **Question:** What design decision will this experiment resolve?
- **Observation:** What measured behavior motivates it? Link evidence.
- **Hypothesis:** What mechanism causes that behavior?
- **Alternatives:** What other explanations could produce it?
- **Intervention:** What changes, through which owners and callers? What remains controlled?
- **Prediction:** What observable change should occur, in which metrics and direction? State a meaningful magnitude or decision threshold when justified by the contract and measurement precision.
- **Falsification:** What valid observation would contradict the hypothesis?
- **Decision rules:** What would lead to retain, revise, reject, or inconclusive?
- **Invariants:** What correctness, ordering, lifetime, compatibility, or resource properties must remain true? How will they be checked?
- **Scope:** Which workloads and paths are exercised? Which supported paths remain untested or unimplemented?

## Reproduction and validity

- **Control:** Repository and exact revision; patch artifact if dirty; build command and settings.
- **Candidate:** Repository and exact revision; patch artifact if dirty; build command and settings.
- **Workload:** Input identity, size, distribution, concurrency, duration, and warm-up or cache state where relevant.
- **Commands:** Exact setup, correctness, measurement, and profiling commands, or links to immutable scripts/configuration. Omit secrets.
- **Metric boundaries:** Useful output definition, start/end events, units, denominator, and aggregation. Distinguish wall time, CPU time, and sampled profiles.
- **Environment:** Hardware/runtime versions and relevant resource placement, limits, topology, and observed contention; link captured details.
- **Run design:** Order, repetitions, and variability or carryover being addressed. Explain why this comparison can distinguish the hypotheses.
- **Termination:** Finite run scope and stop conditions; applicable existing budget, if any.
- **Shared-state changes:** Authorization already held or needed; original state; restoration procedure. Use none when no change is required.
- **Artifacts:** Durable location for source, configuration, raw output, profiles, and environment observations.

## Observations — append after execution

- **Run inventory:** Every attempted run's ID, source, time, outcome, and artifact link, including failures.
- **Deviations:** Changes from the plan and their effects on interpretation.
- **Correctness:** Checks and outcomes; scope of the evidence.
- **Validity:** Eligible runs and reasons; contaminated, failed, or incomplete runs and the conclusions they cannot support.

| Metric / unit / workload | Control absolute | Candidate absolute | Difference / ratio | Variability / uncertainty | Contract target |
| --- | --- | --- | --- | --- | --- |
| <useful throughput, latency, CPU per useful output, memory, or other relevant metric> | | | | | |

- **Mechanism evidence:** Work removed, moved, overlapped, or added; queueing and ownership changes. Separate direct observation from inference.
- **Tradeoffs:** Regressions, resource movement, complexity, and new lifecycle obligations.
- **Restoration:** Shared-state restoration and verification evidence, or remaining cleanup.

## Decision — append after interpretation

- **Disposition:** Retain / revise / reject / inconclusive, with evidence.
- **Claim supported:** Local mechanism, end-to-end effect, correctness scope, or combination; state the limits.
- **Original prediction:** Supported, contradicted, or unresolved, and why.
- **Overall targets:** Met / missed / unverified for this candidate and scope.
- **Design update:** What survives into the combined design? What is removed or revised?
- **Rejected alternative / revisit condition:** What evidence would make another attempt worthwhile?
- **Next question:** Highest-value unresolved decision; new experiment, qualification, or delivery action. For a rerun, identify the invalidity or uncertainty it addresses.
- **Record links:** Current design and delivery status.

Append dated corrections and follow-up evidence below; preserve the original plan and observations.
