---
name: sdd-plan
description: >-
  Phase-local guidance for SDD Plan. Use while turning research.md into
  architectural decisions, vertical slices, and atomic tasks with runnable
  verification commands before implementation starts.
when_to_use: >-
  Use when a full-mode SDD feature is in Plan and the next move is to turn
  research.md into plan.md decisions, vertical slices, tasks.md, and runnable
  verification commands. Do not use for production edits, executing tasks,
  Review, Close, or requirements authoring that belongs in Design.
argument-hint: "[feature-id or planning question]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd status*)
  - Bash(sdd phase*)
  - Bash(sdd plan create*)
  - Bash(sdd check plan*)
  - Bash(sdd check tasks*)
---

# SDD Plan Phase

This is focused phase guidance for SDD design-to-task decomposition. The main
`spec-driven-development` skill remains the router and enforcement anchor for
first-response protocol, phase detection, hard gates, artifact contracts, and
approval boundaries.

Use `/sdd-plan` only when the active full-mode feature is in Plan and the goal
is to populate or refine `plan.md` and `tasks.md` from `research.md`.

## Phase-Skill Latch Contract

Invoke `/sdd-plan` before protected Plan artifact edits or boundary commands.
For the latch, direct reads of this skill, the phase reference, `plan.md`, or `tasks.md` do not satisfy the routing latch. The latch confirms phase-guidance routing only;
it does not prove planning correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Plan answers HOW to build the feature without starting production edits. It
turns `research.md` into decisions, vertical slices, and atomic tasks whose
verification commands prove completion.

Use confirmed Research facts for architectural decisions, risks, task
boundaries, and verification quality. If the plan depends on a hypothesis or
unknown, keep that assumption explicit instead of upgrading it to fact.

Use `sdd-plan-drafter` or a plan drafter only for bounded planning help when the
controller keeps artifact authority. The main `spec-driven-development` skill
remains the router and enforcement anchor.

## Relevant Commands

- `sdd status` - confirm active feature and phase.
- `sdd phase <feature>` - verify the feature is still in Plan.
- `sdd plan create <feature>` - scaffold or refresh `plan.md`.
- `sdd check plan <feature>` - validate decisions and slice coverage.
- `sdd plan create-tasks <feature>` - derive `tasks.md` from the approved plan.
- `sdd check tasks <feature>` - verify task metadata and runnable commands
  before implementation.

## Preconditions

- The active feature is full mode and currently in Plan.
- `research.md` exists and maps affected files, risks, tests, and dependencies.
- `spec.md` exists with FRs/ACs that every slice and task must trace to.

## First Actions

1. Read `research.md`, `spec.md`, and `brief.md`.
2. Identify meaningful decisions and vertical slices before writing tasks.
3. For each task, define files, scope boundary, done criteria, and a runnable
   verification command that can pass at task completion.
4. Include trace fields and dependencies where shared resources or ordering
   constraints make task provenance important.

## Output Contract

Produce or refine `plan.md` with AD-xxx decisions, PH-xx slices, risks, and
mitigations, then produce `tasks.md` with atomic T-xxx tasks mapped to FRs/ACs,
file scope, trace fields, dependencies, shared-resource coordination, and
runnable verification.

## Return / Failure Protocol

Return to `spec-driven-development` when the feature is not in Plan, when a
user approval boundary is reached, or when implementation should begin. If a
task cannot be verified by a runnable command, split or rewrite it before
leaving Plan.

## Iron Law

**NO TASK WITHOUT A RUNNABLE VERIFICATION COMMAND THAT PROVES BEHAVIOR.**

Planning is not complete until every task can prove its own completion. A task
with vague steps, missing files, or a verification command that always passes
is not ready for implementation.

## Core Loop

1. Read `research.md`, `spec.md`, and `brief.md`.
2. Write AD-xxx decisions only for meaningful implementation choices.
3. Define PH-xx vertical slices mapped to FRs and ACs.
4. Convert slices into atomic T-xxx tasks.
5. Give each task concrete files, scope boundaries, and done criteria.
6. Add Depends-on relationships for shared-resource conflicts and ordering
   requirements.
7. Write a runnable verification command for each task.
8. Run `sdd check plan` and `sdd check tasks` before implementation.

## Boundaries

- No production code.
- No task execution.
- No vague "do the phase" tasks.
- No verification written as prose.
- No hidden expansion beyond `research.md` affected files without updating the
  artifacts.
- No bypass of SDD approval boundaries.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/plan.md` for Plan process and
  exit criteria
- `spec-driven-development/templates/plan.md` and
  `spec-driven-development/templates/tasks.md` for artifact structure
