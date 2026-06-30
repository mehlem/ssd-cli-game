---
name: sdd-brief
description: >-
  Phase-local guidance for SDD Brief. Use while extracting motivation,
  problem, vision, context, constraints, and Q&A into brief.md before Design,
  Research, Plan, or implementation begins.
when_to_use: >-
  Use when a full-mode SDD feature is in Brief and the next move is to extract
  or refine motivation, problem, vision, context, constraints, or the Q&A record
  before Design. Do not use for codebase research, planning, implementation,
  Review, Close, or lite Spec work.
argument-hint: "[feature-id or brief question]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd status*)
  - Bash(sdd phase*)
  - Bash(sdd check brief*)
  - Bash(sdd autonomy*)
  - Bash(sdd spec*)
---

# SDD Brief Phase

This is focused phase guidance for SDD intent extraction. The main
`spec-driven-development` skill remains the router and enforcement anchor for
first-response protocol, phase detection, hard gates, artifact contracts, and
approval boundaries.

Use `/sdd-brief` only when the active full-mode feature is in Brief and the
goal is to populate or refine `brief.md` from user intent and inspected project
context.

## Phase-Skill Latch Contract

Invoke `/sdd-brief` before protected Brief artifact edits or boundary commands.
For the latch, direct reads of this skill, the phase reference, or `brief.md` do not satisfy
the routing latch. The latch confirms phase-guidance routing only; it does not
prove `brief.md` correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Brief answers WHY the feature should exist before engineering artifacts begin.
It turns user intent plus lightweight project context into `brief.md` without
choosing files, architecture, tests, or implementation strategy.

This phase should read enough context to avoid bad questions: `CLAUDE.md`,
`.features/INDEX.md`, recent feature briefs, and one or two scoped files when
the feature name makes them relevant. The main `spec-driven-development` skill
remains the router and enforcement anchor.

Brief is controller-owned intent extraction. Use no worker delegation in this
phase; subagents can help later only after Design/Research has concrete
artifacts to bound their work.

## Relevant Commands

- `sdd status` - confirm active feature state before changing artifacts.
- `sdd phase <feature>` - verify the feature is still in Brief.
- `sdd check brief <feature>` - check whether `brief.md` is ready to leave
  Brief.
- `sdd autonomy on|off <feature>` - record the user's autonomy choice when
  Brief exits.
- `sdd spec <feature>` - transition only after intent is clear and SDD's
  approval boundary is satisfied.

## Preconditions

- The active feature is full mode and currently in Brief.
- `brief.md` exists or is the artifact being initialized.
- The user has provided enough intent to infer or ask about WHY-level content.

## First Actions

1. Run or inspect SDD state and confirm the active feature/phase.
2. Read existing `brief.md`, `CLAUDE.md`, `.features/INDEX.md`, and recent
   related feature context before asking.
3. Draft inferable sections with source labels, then ask only remaining
   intent-level questions with recommended answers.

## Output Contract

Update `brief.md` with Motivation, Problem, Vision, Context, Constraints, and a
Q&A Record. Every question recorded should include the recommendation offered to
the user and the user's actual answer.

## Return / Failure Protocol

Return to `spec-driven-development` when the feature is not in Brief, when the
user asks for design/research/implementation, or when a phase transition is
needed. If intent is still ambiguous, leave the ambiguity in `brief.md` and ask
for the missing WHY-level decision instead of guessing.

## Iron Law

**NO DESIGN, RESEARCH, OR CODE QUESTIONS IN THE BRIEF PHASE.**

The Brief phase captures why the feature should exist and what success should
feel like. Architecture, file ownership, implementation approach, and test
shape belong to later phases.

## Core Loop

1. Read `.features/<feature>/brief.md` if it already exists.
2. Inspect enough project context to avoid answerable questions.
3. Draft inferable Problem, Context, and Constraints with source labels.
4. Ask only intent-level questions about Motivation and Vision.
5. Pair each question with a recommended answer or option.
6. Keep the Q&A record current.
7. Stop when intent is clear enough for Design.

## Boundaries

- No production code.
- No implementation planning.
- No codebase research beyond lightweight context needed to avoid bad
  questions.
- No file, function, schema, hook, or test design decisions.
- No bypass of SDD approval boundaries.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/brief.md` for Brief process and
  exit criteria
- `spec-driven-development/templates/brief.md` for artifact structure
