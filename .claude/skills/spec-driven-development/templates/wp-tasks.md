---
id: WP-TASKS-{{FEATURE_NUM}}-{{WP_ID}}
feature: "{{FEATURE_ID}}"
work_package: "{{WP_ID}}"
parent: TASKS-{{FEATURE_NUM}}
addresses: []
title: "{{WP_NAME}}"
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
  tasks: TASKS-{{FEATURE_NUM}}
  review: WP-REVIEW-{{FEATURE_NUM}}-{{WP_ID}}
  scratchpad: WP-SCRATCH-{{FEATURE_NUM}}-{{WP_ID}}
  continuity: CONT-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
tags: []
---

# Tasks: {{WP_NAME}}

## T-001: [Task title]

> Status: pending
> Phase: PH-01
> Implements: ["FR-001"]
> Files: ["src/module/file.ts (create)", "src/module/other.ts (modify)"]

### Description

[Atomic outcome — one clear thing to accomplish]

### Steps

1. [Concrete action]
2. [Concrete action]

### Acceptance Criteria

- [ ] [Testable criterion]

### Verification

```bash
[runnable command — must prove the task's actual outcome, not a proxy; must fail when the implementation is broken; every script, subcommand, or resource it needs must already exist or be produced by this task]
```
