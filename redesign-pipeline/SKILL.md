---
name: redesign-pipeline
description: Redesign a processing pipeline through whole-pipeline diagnosis, competing hypotheses, and iterative experiments. Use when asked to improve a pipeline's architecture against end-to-end targets or resume an evidence-driven redesign; localized bug fixes and implementation of an already settled design use their existing workflows.
---

# Redesign a pipeline

Own the loop from the behavioral contract through measured redesign to the user's requested delivery state. Adapt the architecture to the evidence, carrying forward useful smaller improvements. This workflow applies to pipelines such as builds, ingestion, media processing, and network transport.

Use repository instructions and existing tools for implementation, review, and publication. This skill supplies the experimental reasoning; it does not require a particular language, benchmark harness, tracker, service, host, or companion skill. Respect companion skills' invocation rules.

## 1. Establish the contract and working record

Discover the current implementation, existing findings, supported workloads, measurement commands, correctness checks, and delivery workflow. Recover prior experiment records before repeating work. Resolve missing product choices with the user while continuing independent investigation; make routine technical decisions within existing authorization.

Create or update a compact working record in the project's established documentation or diagnostics location:

- **Contract:** useful output and completion boundary; absolute targets and any comparator; representative workloads; correctness invariants; resource and compatibility constraints; permitted changes; requested delivery state.
- **Current design:** pipeline map, retained changes, unresolved hypotheses, and next experiment.
- **Evidence:** links to an append-only experiment ledger and reproducible artifacts.
- **Delivery:** implementation state, qualification coverage, and remaining work.

These may be sections of one document. Discover repository commands and configuration instead of copying them into this skill. Record assumptions where evidence is missing; leave unresolved target values explicit rather than inventing success criteria.

**Complete when:** the record identifies the scope, measurable outcome, preserved behavior, known constraints, and requested finishing point, with unresolved choices distinguished from established requirements.

## 2. Trace the whole pipeline

Follow representative input through useful completion, including control feedback and cleanup. For each stage, identify its work, execution context, queue or wait, data owner, ownership transfers, allocation or copy costs, and repeated decisions. Trace at least one concrete item through the actual callers and owners; mark uninspected paths.

Distinguish the throughput limiter, critical-path latency, total resource consumption, and mechanisms that preserve correctness. Examine where work runs and what overlaps: moving work can improve throughput without reducing its total cost. Include cancellation, failure, retry, and disposal where they affect ownership or completion.

**Complete when:** the map explains the exercised path from input to completion, identifies the evidence behind suspected limits, and marks the supported paths still needing investigation.

## 3. Establish trustworthy measurements

Prefer the existing harness. Pin source revisions, uncommitted patches, build settings, workload, measurement boundaries, and environment in the experiment ledger. Measure useful output alongside total work, latency, CPU, memory, and relevant resource limits; choose metrics from the contract.

Separate CPU consumption from waiting and critical-path placement. Treat sampled profile totals as attribution evidence, accounting for overlap and normalization before estimating removable cost. Report comparator and candidate absolute values alongside ratios so comparator slowdowns remain visible.

Inspect contention on the resources the workload actually uses. Account for core classes, topology, runtime limits, caches, and background activity as relevant. A busy host alone does not invalidate a measurement; record demonstrated interference or the uncertainty it introduces. Keep environmental controls proportionate to the question. Existing authorization governs remote uploads and shared-host changes; when changing shared state, capture the original state and restore and verify it afterward.

Preserve failed and contaminated runs with their validity assessment. Exclude invalid timing from performance conclusions while retaining independently valid correctness evidence. Choose repetition and run order to address observed variability, carryover, or drift; record the reason for each rerun.

**Complete when:** baseline artifacts are reproducible, metric boundaries are explicit, and measurement uncertainty is characterized well enough to choose a discriminating experiment. If timing remains unreliable, continue only with questions the available evidence can answer.

## 4. Choose a hypothesis and structural change

Compare plausible explanations before committing to a redesign. Look for repeated decisions, duplicated representations, misplaced work, unnecessary coordination, avoidable transfers, and unsuitable algorithms or batching. Prefer a coherent construction/use/disposal owner when it removes obligations; justify additional queues, caches, and replicated state by their full lifecycle cost.

Consult other implementations when a specific unresolved design question warrants it. Transfer the mechanism only after checking its workload, semantics, ownership, and resource assumptions against this pipeline.

Before editing a candidate, use [the experiment template](assets/experiment-template.md) to record the mechanism, prediction, preserved invariants, alternatives, supporting and falsifying observations, and the decision each outcome would enable. Select the smallest experiment that distinguishes the leading explanations. Define a finite run scope and termination condition appropriate to the hypothesis, using existing budgets where supplied.

**Complete when:** the next experiment can change a stated design decision, and its observations can distinguish success, failure, and insufficient evidence without moving the target afterward.

## 5. Implement and exercise a representative candidate

Build through the real owners and callers needed to test the mechanism. Exercise the relevant invariants, including boundary and failure cases exposed by changed ownership or timing. Mark routes the prototype does not implement; qualify conclusions to the exercised scope.

Keep temporary instrumentation and diagnostic shortcuts identifiable. Preserve the control and candidate source artifacts. Isolate changes sufficiently to attribute results; when mechanisms must change together, state that the evidence supports the combination and use ablation only when separating effects would change a decision.

Run the planned comparison, retaining raw outputs and deviations. Record instrumentation overhead or use separate profiling and timing runs when it materially affects results.

**Complete when:** the exact candidate, correctness evidence, raw measurements, environment observations, and deviations are recorded, including an unsuccessful or interrupted run.

## 6. Disposition the evidence

Append a conclusion to the experiment entry; preserve prior predictions and results, adding corrections explicitly. Choose:

| Disposition | Evidence and consequence |
| --- | --- |
| Retain | The mechanism or simplification has supported value, acceptable costs, and fits the emerging design. Carry it into the candidate. |
| Revise | Evidence supports the mechanism but identifies a specific design or implementation defect. Name the correction and its discriminating check. |
| Reject | Benefit is unsupported or costs violate the contract. Preserve the reason and conditions that would justify revisiting it. |
| Inconclusive | Measurement validity or coverage cannot distinguish the hypotheses. Identify the missing evidence and whether obtaining it is worthwhile. |

Assess end-to-end behavior, resource tradeoffs, correctness, and maintenance obligations together. A local allocation reduction or cleaner profile establishes a local result; claim an end-to-end gain only with corresponding evidence. Retain useful small improvements without requiring each to meet the overall target. Track interactions and evaluate the combined candidate rather than adding isolated percentage gains.

**Complete when:** the entry separates observations from inference, assigns a disposition with its costs and limitations, and updates the retained design and next decision.

## 7. Reassess and iterate

Revisit the whole-pipeline map after each disposition. Deepen that reassessment when local costs fall but end-to-end results stall, the bottleneck moves, a new owner or duplicate state appears, or correctness findings reveal a structural cause. Reconsider the design at the responsible boundary before accumulating compensating patches.

Return to step 4 with the most useful next question. Return to step 3 when the workload, measurement boundary, comparator, or environment has changed enough to invalidate comparisons. Preserve both the original baseline and an explicitly identified current control.

Continue while useful in-scope experiments remain and the requested outcome is unmet. When progress requires an unresolved product choice, unavailable authority or resource, or an exhausted user-specified budget, record the concrete dependency and seek the needed decision. Technical difficulty alone is a reason to adapt the experiment.

**Complete when:** the working record names the next justified experiment, establishes readiness for delivery, or documents a specific dependency that prevents further meaningful progress.

## 8. Qualify and deliver

Once feasibility is demonstrated, complete the requested implementation and qualification. Remove diagnostic shortcuts, cover every supported path affected by the redesign, and run the repository's required correctness and review checks. Validate the combined deliverable against all acceptance metrics on representative workloads, identifying the exact source and environment tested.

A successful prototype establishes feasibility for its tested scope. Keep product qualification, integration, and delivery status separate. When the user requested a handoff, package the retained design, rejected alternatives, reproducible evidence, dependency order, and remaining acceptance work. When implementation was requested, continue through its authorized delivery workflow instead of substituting a plan.

Update the delivery record with what changed, the mechanism behind each retained improvement, absolute results and ratios, qualification limits, and unresolved tradeoffs. Restore temporary shared-environment changes and report any cleanup that remains.

**Complete when:** the requested delivery state is reached with evidence for its claims, or an explicit external dependency is documented with the work completed and recommendation for proceeding. State whether each overall target is met, missed, or unverified.
