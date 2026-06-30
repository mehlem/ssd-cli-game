# Design Phase Guide

**Goal:** Define WHAT to build — requirements and acceptance criteria.
**Produces:** `.features/{{FEATURE}}/spec.md` | **Gate:** No implementation, no code, no task execution.

## Phase Entry Contract

Invoke `/sdd-spec` before editing `spec.md` or running a protected boundary
command that exits Design. Direct reads of this phase reference, `SKILL.md`, or
`spec.md` do not satisfy the routing latch. The latch proves the agent routed
through Design guidance; it does not prove artifact correctness.

## The Iron Law of Spec Design

**NO IMPLEMENTATION DETAILS IN THE SPEC — WHAT, NOT HOW.**

A spec that names file paths, function signatures, data structures, or algorithmic choices has smuggled HOW into WHAT. The spec is the contract between user intent and implementation; it must be verifiable by someone who never reads the code. Implementation choices buried in the spec cannot be reviewed and cannot be changed without re-opening the spec.

If you find yourself writing which files to modify, which functions to call, or how data will be stored, that's a sign the design is leaking into solution space — lift back to "what behavior must change" and defer the rest to Research and Plan.

## Process

First-entry autonomy check: if `.features/{{FEATURE}}/state.json` has `autonomous: null`, ask once whether to enable autonomous mode and record via `sdd autonomy on {{FEATURE}}` or `sdd autonomy off {{FEATURE}}`.
1. Read `.features/{{FEATURE}}/brief.md` — understand Motivation, Vision, Constraints.
2. Search the codebase for existing patterns relevant to the feature before asking anything.
3. Identify gaps: scope boundaries, edge cases, data flows, integration points.
4. Ask up to **5 targeted clarification questions** — each with options and a recommendation.
5. Translate answers into structured functional requirements (FR-xxx) and acceptance criteria (AC-xxx).
6. Write `spec.md` with all required sections.
7. Review with user; refine until requirements are unambiguous.

## Strategy

- Explore the codebase before asking — unask every answerable question.
- Frame each question with options (A/B/C) and your recommendation so user can confirm quickly.
- Surface competing interpretations explicitly — if ambiguity changes behavior, scope, or verification, do not pick silently.
- Use User Stories (US-xx) to anchor FRs in real workflows.
- ACs must be verifiable — each should map to a testable behavior.
- Non-Goals are as important as goals — make scope explicit.
- If uncertainty remains after repo inspection, leave it as an open question instead of smuggling HOW into WHAT.

## Artifacts to read

- `.features/{{FEATURE}}/brief.md` — required, the WHY foundation.
- Related spec.md files in other features for format conventions.

## Maintenance

- Update `.features/{{FEATURE}}/spec.md` as requirements crystallize.
- Track open questions in spec.md Open Questions section.
- Update `.features/{{FEATURE}}/scratchpad.md` with design decisions.

## spec.md required sections

- **Problem** — from brief.md Motivation + Problem
- **Solution** — high-level approach (not implementation details)
- **User Stories** — US-xx: As a [user], I want [goal], so that [benefit]
- **Functional Requirements** — FR-xxx (referenced by all downstream artifacts)
- **Acceptance Criteria** — AC-xxx as checkboxes (validated in Review)
- **Non-Goals** — explicitly out of scope
- **Constraints** — from brief.md

## Exit criteria

`spec.md` exists with at least: Problem, one FR, and one AC. Open questions tracked.
