---
name: sdd-close
description: >-
  Phase-local guidance for SDD Close. Use after review verdict pass while
  graduating knowledge, finalizing artifacts, running sdd close, and recording
  close commit metadata without adding new scope.
when_to_use: >-
  Use when an SDD feature is in Close after review.md has verdict pass and the
  next move is to graduate knowledge, finalize artifacts, run sdd close, or
  record close metadata. Do not use for new scope, Review bypasses, force-close
  workarounds, implementation fixes, or reopening without sdd reopen.
argument-hint: "[feature-id or close question]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd status*)
  - Bash(sdd phase*)
  - Bash(sdd close*)
  - Bash(sdd record-close*)
  - Bash(sdd check all*)
  - Bash(sdd reopen*)
---

# SDD Close Phase

This is focused phase guidance for clean feature finalization. The main
`spec-driven-development` skill remains the router and enforcement anchor for
first-response protocol, phase detection, hard gates, artifact contracts, and
approval boundaries.

Use `/sdd-close` only when the active feature is in Close and the goal is to
finalize artifacts after `review.md` has a passing verdict.

## Phase-Skill Latch Contract

Invoke `/sdd-close` before protected Close commands or finalization edits.
For the latch, direct reads of this skill, the phase reference, or Close artifacts do not satisfy the routing latch. The latch confirms phase-guidance routing only; it
does not prove close correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Close finishes a reviewed feature cleanly. It handles knowledge graduation,
artifact finalization, close execution, optional archive generation, and close
commit metadata without adding new scope.

Graduate durable fact entries from scratchpad and feature knowledge only when
they are reusable beyond the current feature. Do not turn task status, review
verdicts, or feature-local progress into Knowledge entries.

Close is only valid after `review.md` has `verdict: pass`. The main
`spec-driven-development` skill remains the router and enforcement anchor for
review and close gates.

## Relevant Commands

- `sdd phase <feature>` - confirm the feature is in Close.
- `sdd check all <feature>` - verify all artifact gates before finalization.
- `sdd close <feature>` - finalize artifacts after review passes and knowledge
  is handled.
- `sdd record-close <feature>` - record close commit metadata after the
  user-approved close commit exists.
- `sdd reopen <feature>` - return to Implement only when legitimate new scope
  or a post-review fix requires reopening.

## Preconditions

- `review.md` exists with `verdict: pass`.
- All tasks in `tasks.md` are completed.
- Scratchpad and feature knowledge artifacts have been read for durable
  findings.
- The user has approved any commit or close metadata action that requires it.

## First Actions

1. Confirm the feature is in Close and `review.md` passed.
2. Read `scratchpad.md`, `.features/<feature>/knowledge.md`, and relevant
   continuity notes for findings to graduate.
3. Run `sdd check all <feature>` before finalizing artifacts.

## Output Contract

Finalize feature artifacts, graduate or explicitly opt out of durable knowledge,
run `sdd close <feature>`, and record `close_commit` metadata with
`sdd record-close <feature>` after the approved close commit exists.

## Return / Failure Protocol

Return to `spec-driven-development` when Review has not passed, knowledge is
unhandled, new scope appears, or close metadata depends on a user-approved
commit. Use `sdd reopen <feature>` for legitimate post-review fixes; do not use
force-close workarounds.

## Iron Law

**NO CLOSE WITHOUT VERDICT PASS AND KNOWLEDGE HANDLED.**

Close is not a shortcut around Review. It finalizes a reviewed feature and
preserves durable lessons so future work does not rediscover the same facts.

## Core Loop

1. Verify `review.md` has `verdict: pass`.
2. Verify all tasks are completed.
3. Read scratchpad and graduate durable findings.
4. Ensure knowledge is captured or explicitly opted out.
5. Finalize artifact statuses.
6. Run `sdd close <feature>`.
7. After a user-approved close commit exists, run `sdd record-close <feature>`.
8. Consider archive generation after close.

## Boundaries

- No new scope.
- No review gate shortcuts, and no bypass of close gates.
- No force-close workaround for normal completion.
- No reopening without `sdd reopen`.
- No empty knowledge by accident.
- No commit or close metadata shortcut without user approval where required.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/close.md` for Close process and
  exit criteria
- `spec-driven-development/templates/review.md` for close metadata fields
