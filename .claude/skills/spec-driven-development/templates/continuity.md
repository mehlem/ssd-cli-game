---
id: CONT-{{FEATURE_NUM}}
feature: "{{FEATURE_ID}}"
title: "{{FEATURE_TITLE}}"
type: continuity
schema_version: 2
# status: active | completed | abandoned | superseded
# Detection treats completed/abandoned/superseded as inactive — set explicitly
# when a feature is replaced (add `superseded_by:`) or dropped.
status: active
created: {{DATE}}
updated: {{DATE}}
related:
  brief: BRIEF-{{FEATURE_NUM}}
  spec: SPEC-{{FEATURE_NUM}}
  research: RESEARCH-{{FEATURE_NUM}}
  plan: PLAN-{{FEATURE_NUM}}
  tasks: TASKS-{{FEATURE_NUM}}
  review: REVIEW-{{FEATURE_NUM}}
  scratchpad: SCRATCH-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
tags: []
---

# Continuity: {{FEATURE_TITLE}}

## Goal

<!-- What is this feature trying to achieve? One sentence. -->

## Constraints / Assumptions

<!-- Non-negotiables and working assumptions for this feature -->

## Key Decisions

<!-- Architectural and design decisions made so far -->

## State

<!-- SDD-AUTO-START -->
### Done

<!-- Completed milestones and tasks -->

### Now

<!-- Currently active work -->

### Next

<!-- Upcoming work items -->

### Working Set

<!-- Files, artifacts, and resources actively being used -->
<!-- SDD-AUTO-END -->

## Open Questions

<!-- Unresolved questions blocking or influencing work -->

## Reasoning State

### Active Assumptions

<!-- Assumptions you are currently relying on; remove or revise when disproven -->

### Open Ambiguity

<!-- Ambiguities that still need clarification or evidence -->

### Current Blocker

<!-- The concrete blocker preventing progress right now, if any -->

### Next Verification Target

<!-- The next command, AC, or evidence check that should run before calling work done -->

### Active Scope Boundary

<!-- What is intentionally in scope for the current task and what is explicitly out -->
