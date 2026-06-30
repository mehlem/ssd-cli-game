---
id: WP-REVIEW-{{FEATURE_NUM}}-{{WP_ID}}
feature: "{{FEATURE_ID}}"
work_package: "{{WP_ID}}"
parent: REVIEW-{{FEATURE_NUM}}
title: "{{WP_NAME}}"
type: review
schema_version: 2
status: draft
phase: review
created: {{DATE}}
updated: {{DATE}}
source: SPEC-{{FEATURE_NUM}}
links: {"derived_from":["SPEC-{{FEATURE_NUM}}"],"informed_by":[],"supersedes":[]}
related:
  brief: BRIEF-{{FEATURE_NUM}}
  spec: SPEC-{{FEATURE_NUM}}
  research: RESEARCH-{{FEATURE_NUM}}
  plan: PLAN-{{FEATURE_NUM}}
  tasks: WP-TASKS-{{FEATURE_NUM}}-{{WP_ID}}
  review: REVIEW-{{FEATURE_NUM}}
  scratchpad: WP-SCRATCH-{{FEATURE_NUM}}-{{WP_ID}}
  continuity: CONT-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
verdict: pending
tags: []
---

# Review: {{WP_NAME}}

> **Review Protocol — Verified-Only**
> Every finding must be verified against actual code before it is reported. Unverified claims must be dropped.
> Cite `file:line` for every finding. If you cannot point to specific code, the finding is not valid.
> Banned language (drop any finding that uses these): "consider adding", "ensure that", "might cause", "could lead to", "should probably".
> Use the Verified Clean section to explicitly record areas checked and confirmed clean.

## Acceptance Criteria Validation

<!-- Import ACs from spec.md that this WP addresses. -->
<!-- Evidence column must contain file:line citations, test output, or quoted code — not summaries. -->

| AC | Description | Status | Evidence |
|:---|:------------|:-------|:---------|
| AC-001 | [from spec.md] | — | — |

## Code Quality

| Category | Status | Notes |
|:---------|:-------|:------|
| Correctness | — | |
| Tests | — | |
| Security | — | |
| Performance | — | |
| Readability | — | |

## Adjudication

<!-- SDD-ADJUDICATION:START -->
<!-- Populated by sdd-review-merge.sh after typed adjudication runs. -->
<!-- SDD-ADJUDICATION:END -->

## Scope Conformance

<!-- Cross-check actual changes against research.md Affected Files for this work package. -->

| File | Expected | Actually Changed | Status | Notes |
|:-----|:---------|:----------------|:-------|:------|
| [scope-from-research] | — | — | — | — |

## Files Changed

<!-- Compare against research.md Affected Files for this WP. Note any unexpected changes. -->

| File | Tasks | Action | Lines |
|:-----|:------|:-------|:------|
| [path] | T-001 | modified | +20, -5 |

## Test Results

```bash
[run test suite and paste output]
```

## Issues Found

<!-- Review Suppressions: do not flag trivial formatting, import reordering, whitespace-only changes, or test-file console.log -->

### Critical (must fix before close)

| Issue | Location | Evidence |
|:------|:---------|:---------|
| (none) | — | — |

### Minor (noted, can proceed)

| Issue | Location | Evidence |
|:------|:---------|:---------|
| (none) | — | — |

## Verified Clean

<!-- Record areas explicitly checked and confirmed to have no issues. -->

| Area | Method | Result |
|:-----|:-------|:-------|
| Hardcoded secrets | Grepped for password, secret, key, token | None found |
| [area] | [how checked] | [result] |
