---
id: RESEARCH-{{FEATURE_NUM}}
feature: "{{FEATURE_ID}}"
title: "{{FEATURE_TITLE}}"
type: research
schema_version: 2
status: draft
phase: research
created: {{DATE}}
updated: {{DATE}}
source: SPEC-{{FEATURE_NUM}}
links: {"derived_from":["SPEC-{{FEATURE_NUM}}"],"informed_by":[],"supersedes":[]}
related:
  brief: BRIEF-{{FEATURE_NUM}}
  spec: SPEC-{{FEATURE_NUM}}
  plan: PLAN-{{FEATURE_NUM}}
  tasks: TASKS-{{FEATURE_NUM}}
  review: REVIEW-{{FEATURE_NUM}}
  scratchpad: SCRATCH-{{FEATURE_NUM}}
  continuity: CONT-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
tags: []
---

# Research: {{FEATURE_TITLE}}

## Summary

<!-- One paragraph: what was researched, key findings, scope/complexity assessment. -->

## Facts

<!-- Code-backed observations only. Cite exact files, entry points, or contracts you actually inspected. -->
<!-- Use fact claims from references/fact-claims.md. A confirmed fact must include an Evidence source. -->
<!-- Optional local label format: FC-001 (confirmed fact): [claim] / Evidence source: [file:line, command output, artifact ID, or source]. -->

- [Fact from inspected code or artifact]

## Hypotheses

<!-- Informed interpretations that still need confirmation before they become facts. -->
<!-- Record what would confirm or reject each hypothesis. -->
<!-- Omit or write "(none)" if the research is already settled and there are no active hypotheses. -->

- [Hypothesis and what would confirm or reject it]

## Unknowns

<!-- Gaps that still need clarification, repo evidence, or stakeholder input before planning. -->
<!-- Record why each unknown matters for Plan decisions, risks, task scope, or verification. -->
<!-- Omit or write "(none)" if there are no material unknowns blocking planning. -->

- [Unknown and why it matters]

## Affected Files

<!-- The structured map of all files this feature will touch. -->

| File | Action | Module | Impact | Relates To |
|:-----|:-------|:-------|:-------|:-----------|
| [path/to/file] | create | [module] | local | FR-001 |
| [path/to/file] | modify | [module] | module | FR-001 |

<!-- Action: create | modify | delete | review -->
<!-- Impact: local | module | cross-module | breaking -->

## Code Context

### Entry Points

<!-- Functions, methods, handlers, routes that will change. Language-agnostic: use "entry point" for any callable. -->

| Entry Point | File | Signature | Change |
|:------------|:-----|:----------|:-------|
| [name] | [file:line] | [signature] | [what changes] |

### Types & Contracts

<!-- Interfaces, schemas, API contracts, shared types affected. -->

| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|
| [name] | [file:line] | extend | module |

<!-- Change: create | modify | extend | deprecate -->

### Patterns & Conventions

<!-- How similar things are done in this codebase. Prose, not table — patterns need explanation. -->

- [Pattern description and where to find it]

## Dependencies

### Internal

<!-- Module-to-module dependencies relevant to this feature. -->

| From | To | Type |
|:-----|:---|:-----|
| [module] | [module] | import |

<!-- Type: import | api-call | db-access | event | config -->

### External

<!-- Third-party packages, APIs, services. -->

| Package/Service | Version | Purpose | New? |
|:----------------|:--------|:--------|:-----|
| [name] | [version] | [why needed] | yes/no |

## Data Changes

<!-- Include if the feature touches database, schemas, or shared state. -->

| Entity | Location | Change | Reversible |
|:-------|:---------|:-------|:-----------|
| [table/collection] | [DB/file] | [create/modify/delete] | yes/no |

## Configuration

<!-- Include if the feature needs new env vars, feature flags, or config changes. -->

| Config | Location | Change | Required By |
|:-------|:---------|:-------|:------------|
| [name] | [.env/config.yaml] | new | [module] |

## Test Landscape

<!-- What test infrastructure exists for the affected areas. -->

- **Framework**: <!-- jest, pytest, go test, etc. -->
- **Helpers**: <!-- relevant test utilities, fixtures, factories -->
- **Coverage**: <!-- current coverage in affected areas -->
- **Integration**: <!-- existing integration test patterns -->

## Prior Art

<!-- Similar implementations in the codebase to learn from or reuse. -->

- [description of similar feature and where to find it]

## System Context

<!-- Data/dependency flow diagram for this feature. ASCII art. -->

```text
[input] → [component] → [component] → [output]
                ↓
           [side effect]
```

## Risks & Concerns

<!-- Things that could go wrong, need special attention, or were surprising. -->

- [risk/concern and why it matters]

## Confidence

| Dimension | Score | Notes |
|:----------|------:|:------|
| Scope clarity | /20 | <!-- How well-defined is the change boundary? --> |
| Pattern familiarity | /20 | <!-- How well do existing patterns cover this work? --> |
| Dependency awareness | /20 | <!-- How well-mapped are upstream/downstream impacts? --> |
| Edge cases | /20 | <!-- How thoroughly are failure modes identified? --> |
| Test strategy | /20 | <!-- How clear is the verification approach? --> |

- **Total**: 0/100
- **Verdict**: GO or HOLD
