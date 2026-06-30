---
name: sdd-review
description: >-
  Phase-local guidance for SDD Review. Use while scaffolding review.md,
  validating each acceptance criterion with evidence, checking scope
  conformance, dispatching reviewers when required, and setting the review
  verdict.
when_to_use: >-
  Use when an SDD feature is in Review and the next move is to create or refine
  review.md, validate ACs with evidence, compare scope, dispatch required
  reviewers, or set the verdict. Do not use for silent implementation,
  research-only scans, Close, or skip/force-close workarounds.
argument-hint: "[feature-id or review question]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd status*)
  - Bash(sdd phase*)
  - Bash(sdd review*)
  - Bash(sdd check review*)
  - Bash(sdd check all*)
  - Bash(sdd task start*)
---

# SDD Review Phase

This is focused phase guidance for acceptance and quality verification. The
main `spec-driven-development` skill remains the router and enforcement anchor
for first-response protocol, phase detection, hard gates, artifact contracts,
and approval boundaries.

Use `/sdd-review` only when the active feature is in Review and the goal is to
validate `review.md` against the spec, implementation, tests, and scope.

## Phase-Skill Latch Contract

Invoke `/sdd-review` before protected Review artifact edits or boundary
commands. Review routes to `/sdd-review`, never `/sdd-research`. For the latch, direct reads of this skill, the phase reference, or `review.md` do not satisfy the routing
latch. The latch confirms phase-guidance routing only; it does not prove review
correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Review verifies the implemented feature against the spec AC by AC. It is not a
cleanup phase and not a chance to continue implementation silently; failures are
recorded first, then the feature returns to Implement if fixes are needed.

Codex review-support evidence can inform the controller, but it is not a verdict
source and does not satisfy the required `sdd-spec-reviewer` or
`sdd-quality-reviewer` roles by itself.

For non-trivial work, the main SDD rule requires independent `sdd-spec-reviewer`
and quality-reviewer dispatch before Close: 3+ ACs, 5+ tasks, or autonomous
mode require independent review unless the user explicitly accepts
self-review. The main `spec-driven-development` skill remains the router and
enforcement anchor.

## Relevant Commands

- `sdd review <feature>` - scaffold `review.md` and import ACs.
- `sdd phase <feature>` - confirm the feature is in Review.
- `sdd check review <feature>` - validate review artifact structure and
  verdict readiness.
- `sdd check all <feature>` - run the full artifact gate before Close.
- `sdd task start <feature> <T-xxx>` - return to Implement only after a review
  finding is recorded and a fix task exists.

## Preconditions

- All implementation tasks are completed.
- `spec.md` contains ACs to validate.
- `tasks.md` and changed files are available for scope comparison.
- `review.md` exists or can be scaffolded by `sdd review <feature>`.

## First Actions

1. Run `sdd review <feature>` if `review.md` is missing.
2. Read `spec.md` before reading implementation files.
3. Validate each AC with command output or file evidence, then check changed
   files against expected scope.

## Output Contract

Populate `review.md` with per-AC PASS/FAIL evidence, scope findings, reviewer
results and adjudication when required, quality notes, test evidence, and a
verdict of `pass` or `fail`.

## Return / Failure Protocol

Return to `spec-driven-development` when fixes are needed, when reviewer
dispatch is required, or when Close should begin. If an AC fails, record the
finding before any implementation resumes; never offer skip or force-close
workarounds.

## Iron Law

**NO REVIEW VERDICT WITHOUT READING SPEC BEFORE CODE AND EVIDENCE FOR EVERY AC.**

Review verifies what was required, not what happened to be built. Every PASS or
FAIL needs concrete evidence from files, commands, or test output.

## Core Loop

1. Run `sdd review <feature>` if `review.md` is missing.
2. Read `spec.md` before implementation files.
3. Validate every AC one at a time with evidence.
4. Check changed files against `research.md` and `tasks.md`.
5. Dispatch independent reviewers when the main SDD rules require it.
6. Adjudicate reviewer findings before setting the final verdict.
7. Record findings before any return to Implement.
8. Set verdict to `pass` only when every AC has passing evidence.

## Boundaries

- No silent continued implementation.
- No skip or force-close workarounds.
- No review verdict without AC-by-AC evidence.
- No code-quality claims without reading the relevant files.
- No trusting "already tested" without command evidence.
- No bypass of SDD approval boundaries.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/review.md` for Review process and
  exit criteria
- `spec-driven-development/templates/review.md` for artifact structure
