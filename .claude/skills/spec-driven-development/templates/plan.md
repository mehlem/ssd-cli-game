---
id: PLAN-{{FEATURE_NUM}}
feature: "{{FEATURE_ID}}"
title: "{{FEATURE_TITLE}}"
type: plan
schema_version: 2
status: draft
phase: plan
created: {{DATE}}
updated: {{DATE}}
source: RESEARCH-{{FEATURE_NUM}}
links: {"derived_from":["RESEARCH-{{FEATURE_NUM}}"],"informed_by":[],"supersedes":[]}
related:
  brief: BRIEF-{{FEATURE_NUM}}
  spec: SPEC-{{FEATURE_NUM}}
  research: RESEARCH-{{FEATURE_NUM}}
  tasks: TASKS-{{FEATURE_NUM}}
  review: REVIEW-{{FEATURE_NUM}}
  scratchpad: SCRATCH-{{FEATURE_NUM}}
  continuity: CONT-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
tags: []
---

# Plan: {{FEATURE_TITLE}}

## Research Findings

<!-- What was learned from codebase exploration and external research.
     Include: existing patterns, relevant code locations, best practices. -->
<!-- Use confirmed Research facts for decisions, risks, task boundaries, and verification quality. -->
<!-- If a finding is a hypothesis or unknown, mark it explicitly instead of relying on it as fact. -->

## Architectural Decisions

- AD-001: [Decision title]
  - **Decision**: [What was decided]
  - **Rationale**: [Why this over alternatives]
  - **Alternatives considered**: [What was rejected and why]

## Phases

<!-- Each phase is a vertical slice — a thin end-to-end path through all layers.
     Each phase should be independently demoable or verifiable. -->

### PH-01: [Phase title]

> Addresses: FR-001
> Acceptance: AC-001

[Description of this vertical slice. What end-to-end behavior it delivers.]

### PH-02: [Phase title]

> Addresses: FR-002
> Acceptance: AC-002

[Description of this vertical slice.]

## Risks & Mitigations

| Risk | Impact | Mitigation |
|:-----|:-------|:-----------|
| [Risk] | [Impact] | [How to handle] |

## Open Questions

- [ ] OQ-001: [Carried from spec or newly discovered — check when resolved]
