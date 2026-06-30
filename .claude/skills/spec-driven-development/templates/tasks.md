---
id: TASKS-{{FEATURE_NUM}}
feature: "{{FEATURE_ID}}"
title: "{{FEATURE_TITLE}}"
type: tasks
schema_version: 2
status: draft
phase: implement
created: {{DATE}}
updated: {{DATE}}
source: PLAN-{{FEATURE_NUM}}
links: {"derived_from":["PLAN-{{FEATURE_NUM}}"],"informed_by":[],"supersedes":[]}
related:
  brief: BRIEF-{{FEATURE_NUM}}
  spec: SPEC-{{FEATURE_NUM}}
  research: RESEARCH-{{FEATURE_NUM}}
  plan: PLAN-{{FEATURE_NUM}}
  review: REVIEW-{{FEATURE_NUM}}
  scratchpad: SCRATCH-{{FEATURE_NUM}}
  continuity: CONT-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
tags: []
---

# Tasks: {{FEATURE_TITLE}}

## Approach

<!-- Lite: required, include at least one concrete bullet. Full: encouraged, <=5 bullets, no AD/PH IDs; detailed architecture stays in plan.md. -->

- [High-level implementation approach]

## T-001: [Task title]

> Status: pending
> Phase: PH-01
> Implements: ["FR-001"]
> Files: ["src/auth/oauth.ts (create)", "src/auth/types.ts (modify)"]

### Description

[Atomic outcome — one clear thing to accomplish]

### Done When

- [Observable result that makes this task complete]

### Non-Goals

<!-- Omit or write "(none)" if the task has no meaningful non-goals beyond its scope boundary. -->
- [What this task explicitly does not do]

### Scope Boundary

<!-- Hard scope boundary: name what this task may touch and what it must leave alone. -->
- In scope: [specific files, behaviors, or verification targets this task may touch]
- Out of scope: [adjacent cleanup, follow-up work, or files this task must not change]

### Steps

1. [Concrete action]
2. [Concrete action]

### Acceptance Criteria

- [ ] [Testable criterion]

### Verification

```bash
[runnable command — must depend on THIS task's status (fail before the task is done, pass after); must prove the task's actual outcome, not a proxy; every script, subcommand, or resource it needs must already exist or be produced by this task; use a disposable fixture, not the active feature, when verifying mutating SDD lifecycle commands; expected-failure probes are diagnostics, so a red-test-only task must wrap the probe and exit 0 when the expected failure is observed; regression guards and final green suites belong in a final task, implementation task, or shared test suite, never bundled with the new-behavior probe (no chaining via `&&`, multiple test invocations, or combined runners)]
```
