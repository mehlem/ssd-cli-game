---
name: sdd-research
description: >-
  Phase-local guidance for SDD Research. Use while mapping WHERE a feature
  lives in the codebase, gathering file-cited evidence, populating
  research.md, checking dependencies and tests, and preparing inputs for Plan.
  This skill is read-only and forbids production code edits.
when_to_use: >-
  Use when a full-mode SDD feature is in Research and the next move is to read
  spec.md and brief.md, map affected files, gather file-cited evidence,
  identify tests/dependencies/risks, or prepare plan inputs. Do not use for
  production edits, task execution, Review, Close, or speculative planning.
argument-hint: "[feature-id or research question]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(sdd status*)
  - Bash(sdd phase*)
  - Bash(sdd check research*)
  - Bash(sdd plan create*)
---

# SDD Research Phase

This is focused phase guidance for SDD evidence gathering and codebase
mapping. The main `spec-driven-development` skill remains the router and
enforcement anchor for first-response protocol, phase detection, hard gates,
artifact contracts, and approval boundaries.

Use `/sdd-research` only when the active full-mode feature is in Research and
the goal is to populate or refine `research.md` from evidence.

## Phase-Skill Latch Contract

Invoke `/sdd-research` before protected Research artifact edits or boundary
commands. For the latch, direct reads of this skill, the phase reference, or `research.md` do not satisfy the routing latch. The latch confirms phase-guidance routing only;
it does not prove research correctness.

Do not use this skill as an independent gate bypass. If the active phase or
task boundary is unclear, return to `spec-driven-development` and the current
feature artifacts before continuing.

## Phase Goal & Context

Research answers WHERE the feature lives in the codebase. It converts
`spec.md` and `brief.md` into evidence: affected files, entry points, patterns,
tests, dependencies, risks, and unknowns that Plan can trust.

Use the shared fact claim convention in
`spec-driven-development/references/fact-claims.md` when recording facts. A
confirmed fact needs an evidence source; grep-only or search-hit-only
observations remain hypotheses or unknowns until inspected.

The phase is read-only. Use a bounded `sdd-research-scout` or research scout
only for delegated scans that return evidence to the controller. The main
`spec-driven-development` skill remains the router and enforcement anchor.

## Relevant Commands

- `sdd status` - confirm active feature state before exploring.
- `sdd phase <feature>` - verify the feature is still in Research.
- `sdd check research <feature>` - check affected-file and FR coverage.
- `sdd plan create <feature>` - transition after research is complete and
  accepted.

## Preconditions

- The active feature is full mode and currently in Research.
- `spec.md` exists and contains FRs/ACs to map.
- `brief.md` exists and may contain constraints that affect the search.

## First Actions

1. Read `spec.md` and `brief.md` before searching code.
2. Extract FRs, ACs, domain terms, commands, artifact names, and likely
   surfaces.
3. Search with `rg`, then open candidate files before recording any pattern
   claim.

## Output Contract

Populate `research.md` with Summary, Affected Files, Code Context,
Dependencies, Test Landscape, Prior Art, Configuration, Risks, and unknowns as
applicable. Every FR should map to at least one affected-file row or an explicit
reason why no code file is affected.

## Return / Failure Protocol

Return to `spec-driven-development` when code edits, planning decisions, or
phase transitions are needed. If evidence is missing, label the item as
unknown or hypothesis; do not record grep-only claims as facts.

## Iron Law

**NO PATTERN CLAIMS WITHOUT READING THE FILE FIRST.**

Grep locates candidates. It does not prove behavior, ownership, or local
conventions. A research finding is not a fact until the relevant file section
has been read and cited.

## Core Loop

1. Read `.features/<feature>/spec.md` before searching implementation code.
2. Extract FRs, ACs, domain terms, commands, artifact names, and affected
   surfaces from the spec.
3. Search with `rg` or file-tree tools to find candidate files.
4. Open the relevant files and record concrete evidence with file references.
5. Populate the Affected Files table using exact enums:
   `create | modify | delete | review` and
   `local | module | cross-module | breaking`.
6. Map every FR to at least one affected-file row.
7. Record test landscape, dependencies, prior art, config, and risks when
   applicable.

## Evidence Rules

- Distinguish fact, hypothesis, and unknown.
- Cite file paths and line references for behavioral claims.
- Record each confirmed fact claim with an evidence source and keep it atomic
  enough for Plan to consume.
- Prefer adjacent code and existing tests over broad assumptions.
- Use subagents only for bounded, read-only scans when the user or current
  workflow authorizes delegation.
- Update `scratchpad.md` during longer investigations so findings survive
  compaction.

## Boundaries

- No production code.
- No task execution.
- No implementation plan beyond research facts, risks, and affected surfaces.
- No edits outside `.features/<feature>/research.md`, scratchpad, continuity,
  or knowledge unless the active SDD contract explicitly covers them.
- No pattern claims from grep-only evidence.

## Canonical References

This skill is a thin phase-local wrapper. The canonical methodology remains:

- `spec-driven-development/SKILL.md` for SDD gates and routing
- `spec-driven-development/references/phases/research.md` for Research process
  and exit criteria
- `spec-driven-development/templates/research.md` for artifact structure
