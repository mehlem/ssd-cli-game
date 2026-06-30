---
name: sdd-implement
description: >-
  Phase-local guidance for SDD Implement. Use while executing one active task
  from tasks.md, keeping edits within the task file scope, running its
  verification command, and recording completion honestly.
when_to_use: >-
  Use when an SDD feature is in Implement and the next move is to start,
  execute, verify, or complete exactly one task from tasks.md. Do not use for
  scope changes without artifact updates, Review verdicts, Close, planning, or
  edits outside the active task's Files list.
argument-hint: "[feature-id or T-xxx]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd status*)
  - Bash(sdd phase*)
  - Bash(sdd task*)
  - Bash(sdd check tasks*)
  - Bash(sdd trace acknowledge*)
---

# SDD Implement Phase

This is focused phase guidance for task execution. The main
`spec-driven-development` skill remains the router and enforcement anchor for
first-response protocol, phase detection, hard gates, artifact contracts, and
approval boundaries.

Use `/sdd-implement` only when the active feature is in Implement and the goal
is to execute the current task from `tasks.md`.

## Phase-Skill Latch Contract

Invoke `/sdd-implement` before protected Implement artifact edits or boundary
commands. For the latch, direct reads of this skill, the phase reference, or `tasks.md` do not satisfy the routing latch. The latch confirms phase-guidance routing only; it
does not prove task completion or implementation correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Implement builds the feature task by task. The active task in `tasks.md` is the
scope contract: files, done criteria, and verification command define what may
change and what must pass.

Use `sdd-implementer` only for bounded worker execution when the controller has
started the task and the dispatch packet defines scope. The main
`spec-driven-development` skill remains the router and enforcement anchor.

## Relevant Commands

- `sdd task next <feature>` - find the next dependency-ready task.
- `sdd task start <feature> <T-xxx>` - begin exactly one task and lock the
  scope boundary.
- `sdd check tasks <feature>` - confirm task metadata remains valid.
- `sdd task complete <feature> <T-xxx>` - mark done only after the task
  verification command passed.
- `sdd trace acknowledge <feature> --confirmed` - clear a suspect trace only
  after re-grounding against changed upstream artifacts.

## Preconditions

- The active feature is in Implement.
- `tasks.md` contains concrete tasks and one task is selected or ready.
- The files to edit are listed in the active task's Files block.
- The task verification command is known before editing begins.

## First Actions

1. Run `sdd task next <feature>` or read `tasks.md` to identify the next task.
2. Start the task with `sdd task start <feature> <T-xxx>` if it is not already
   in progress.
3. Read the active task and every listed file before editing.

## Output Contract

Modify only files covered by the active task, run the task verification command,
record relevant scratchpad observations, and complete the task only after
verification passes.

## Return / Failure Protocol

Return to `spec-driven-development` when scope changes, files are missing from
the task, verification fails in a way that changes requirements, or a phase
transition is needed. If the task cannot be completed honestly, leave it
in-progress and record the blocker.

## Iron Law

**NO TASK COMPLETE WITHOUT THE VERIFICATION COMMAND PASSING.**

Writing code is not completion. The task is complete only when its declared
verification command has been run and passed.

## Core Loop

1. Read the active task in `.features/<feature>/tasks.md`.
2. Start exactly one task with `sdd task start <feature> <T-xxx>`.
3. Read every file listed in that task before editing.
4. Make only the smallest change that satisfies the task.
5. If scope changes, update artifacts before continuing.
6. Run the task verification command.
7. Mark the task complete only after verification passes.
8. Update scratchpad with what changed and what was learned.

## Boundaries

- One task at a time.
- No silent scope changes.
- No edits outside the task's Files list without artifact updates.
- No relocation of scope-drift enforcement out of plugin hooks or CLI gates.
- No drive-by cleanup.
- No task completion before verification passes.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/implement.md` for Implement
  process and exit criteria
- `spec-driven-development/templates/tasks.md` for task structure
