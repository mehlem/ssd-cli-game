# Fact Claim Convention

Fact claims are artifact-local statements that classify evidence quality during
SDD work. They help Research separate what is known from what is inferred, and
help Plan consume Research without turning guesses into implementation
decisions.

Fact claims do not create a new phase, gate, CLI, status ledger, or `.facts`
workflow. The main SDD router, phase skills, CLI scripts, hooks, trace gates,
task gates, review verdicts, and Knowledge workflow remain authoritative.

## Claim Types

- **confirmed fact**: A specific statement backed by inspected evidence. It
  names the evidence source, such as `file:line`, command output, artifact ID,
  or external source reference.
- **hypothesis**: A plausible interpretation that is not confirmed yet. It must
  say what evidence would confirm or reject it.
- **unknown**: A meaningful gap that affects planning, scope, verification, or
  risk. It must say why the gap matters.
- **durable fact**: A confirmed fact that remains useful beyond the current
  feature and can graduate to `KNOWLEDGE.md` during Close.
- **non-fact**: Task status, review verdicts, command intent, TODOs, stale
  memory, search hits, grep-only observations, and uninspected assumptions.

## Required Fields

A fact claim should be short and atomic:

```text
- FC-001 (confirmed fact): [claim]
  Evidence source: [file:line, command output, artifact ID, or source]
  Relates to: [FR/AC/AD/T id, optional]
```

`FC-xxx` labels are optional local trace aids. They do not carry status, imply
completion, or replace existing SDD IDs such as FR, AC, AD, PH, T, review
verdict, or K entries.

## Research Rules

- A confirmed fact must be based on inspected evidence.
- A grep-only or search-hit-only observation is not a confirmed fact.
- A broad pattern claim is not a confirmed fact until the relevant files have
  been opened and read.
- If evidence is incomplete, record a hypothesis or unknown instead of upgrading
  it to a confirmed fact.
- Research should produce facts that Plan can use for decisions, risks, task
  scope, and verification design.

## Knowledge Boundary

During Close, only durable facts graduate to `KNOWLEDGE.md`. Do not graduate
task status, review verdicts, feature-local progress, or facts that are obvious
from the feature artifacts themselves.
