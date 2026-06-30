---
name: sdd-spec
description: >-
  Phase-local guidance for SDD requirements authoring. Use while writing or
  refining full Design `spec.md` artifacts, or lite Spec `spec.md` and
  `tasks.md` artifacts, when the work needs WHAT-level user stories,
  functional requirements, acceptance criteria, non-goals, and constraints
  without implementation planning.
when_to_use: >-
  Use in full Design when translating brief.md into WHAT-level requirements,
  or in lite Spec when defining a bounded change in spec.md and deriving tasks
  before implementation. Do not use for Research, Plan architecture,
  production edits, Review, Close, or file/function-level implementation
  choices.
argument-hint: "[feature-id or requirement question]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd *)
---

# SDD Spec Phase

This is focused phase guidance for SDD requirements authoring. The main
`spec-driven-development` skill remains the router and enforcement anchor for
first-response protocol, phase detection, hard gates, artifact contracts, and
approval boundaries.

Use `/sdd-spec` only inside:

- full Design, where `spec.md` defines WHAT to build
- lite Spec, where `spec.md` and `tasks.md` define the bounded change before
  implementation

## Phase-Skill Latch Contract

Invoke `/sdd-spec` before protected Design or lite Spec artifact edits or
boundary commands. For the latch, direct reads of this skill, the phase reference, `spec.md`, or `tasks.md` do not satisfy the routing latch. The latch confirms
phase-guidance routing only; it does not prove requirements correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Spec defines WHAT must be true before anyone decides HOW to build it. In full
Design, it turns `brief.md` into `spec.md`; in lite Spec, it also keeps
`tasks.md` concrete enough for a small, bounded implementation.

The phase is successful when user stories, FRs, ACs, non-goals, and constraints
are reviewable without reading implementation code. The main
`spec-driven-development` skill remains the router and enforcement anchor.

## Relevant Commands

- `sdd status` - confirm active feature and current phase.
- `sdd phase <feature>` - distinguish full Design from lite Spec.
- `sdd check spec <feature>` - verify `spec.md` has substantive requirements.
- `sdd check tasks <feature>` - in lite Spec, verify `tasks.md` is ready before
  implementation.
- `sdd research <feature>` - in full mode, transition after Design approval.
- `sdd task start <feature> <T-xxx>` - in lite mode, start work only after
  tasks are concrete and checked.

## Preconditions

- The active feature is in full Design or lite Spec.
- Full Design has `brief.md`; lite Spec has a bounded change request.
- Requirements are still at WHAT level, not file/function/task execution level.

## First Actions

1. Confirm mode and phase from SDD state.
2. For full Design, read `brief.md`; for lite Spec, read existing `spec.md` and
   `tasks.md` if present.
3. Inspect enough nearby project context to avoid answerable questions, then
   write or refine verifiable FRs and ACs.

## Output Contract

Produce or refine `spec.md` with Problem, Solution, User Stories, Functional
Requirements, Acceptance Criteria, Non-Goals, Constraints, and Open Questions
when needed. In lite Spec, also populate task entries only after the
requirements are clear.

## Return / Failure Protocol

Return to `spec-driven-development` when the current phase is not full Design or
lite Spec, when implementation details are required, or when a phase transition
is needed. If an AC cannot be verified, rewrite it before leaving the phase.

## Iron Law

**WHAT, NOT HOW.**

The spec describes observable behavior, user value, requirements, acceptance
criteria, non-goals, and constraints. It does not choose files, functions,
data structures, shell implementation, hook internals, or test fixture layout.

## Full Design

When the active feature is full mode and in Design:

1. Read `.features/<feature>/brief.md`.
2. Inspect enough repo context to avoid asking answerable questions.
3. Draft or refine `.features/<feature>/spec.md`.
4. Keep every FR and AC verifiable without reading implementation code.
5. Ask targeted questions only when ambiguity changes behavior, scope, or
   verification.
6. Stop before Research until the user confirms the spec.

## Lite Spec

When the active feature is lite mode and in Spec:

1. Keep the scope narrow enough for a lite change.
2. Write requirements in `spec.md` at WHAT level.
3. Add compact Scope/Codebase Notes to `spec.md` when inspection changes scope
   or risk; do not expand that into full Research.
4. Populate `scope.txt` once affected files are known.
5. Derive concrete implementation tasks in `tasks.md` only after the spec is
   clear.
6. Do not start production edits until `tasks.md` passes the tasks gate.

## Required Shape

For `spec.md`, preserve the repository's artifact template and include:

- Problem
- Solution
- User Stories
- Functional Requirements
- Acceptance Criteria
- Non-Goals
- Constraints
- Open Questions when uncertainty remains

Every acceptance criterion should be testable in Review. If an AC cannot be
verified by command output, file evidence, or an explicit inspection probe,
rewrite it before leaving the phase.

## Boundaries

- No production code.
- No implementation plan in the spec.
- No file-level or function-level instructions in requirements.
- No bypass of SDD approval boundaries.
- No changes outside the current feature artifacts unless the main SDD task
  contract covers them.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/design.md` for full Design
- the main SDD lite-mode rules for lite Spec behavior
- `spec-driven-development/templates/spec.md` and
  `spec-driven-development/templates/tasks.md` for artifact structure
