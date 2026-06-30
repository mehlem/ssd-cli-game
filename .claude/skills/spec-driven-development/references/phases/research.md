# Research Phase Guide

**Goal:** Map WHERE in the codebase this feature lives — the implementation landscape.
**Produces:** `.features/{{FEATURE}}/research.md` | **Gate:** No production code.

## Phase Entry Contract

Invoke `/sdd-research` before editing `research.md` or running a protected
boundary command that exits Research. Direct reads of this phase reference,
`SKILL.md`, or `research.md` do not satisfy the routing latch. The latch proves
the agent routed through Research guidance; it does not prove artifact
correctness.

## The Iron Law of Research

**NO PATTERN CLAIMS WITHOUT READING THE FILE FIRST.**

Grep hits locate candidates — they do not establish patterns. Every behavioral claim recorded in research.md must be grounded in an actual file read with a `file:line` citation. Unread evidence labeled as fact corrupts the plan and every downstream artifact.

If you find yourself writing "the codebase uses X pattern" based only on grep output, that's a sign the claim is unverified — open the file, read the relevant section, then record the finding with a precise citation.

Use the shared fact claim convention in `references/fact-claims.md` when
recording Research facts. A confirmed fact needs an evidence source; a
grep-only or search-hit-only observation stays a hypothesis or unknown until
the relevant file, artifact, command output, or external source has been
inspected.

## Process

First-entry autonomy check: if `.features/{{FEATURE}}/state.json` has `autonomous: null`, ask once whether to enable autonomous mode and record via `sdd autonomy on {{FEATURE}}` or `sdd autonomy off {{FEATURE}}`.
1. **Read spec.md** — internalize all FRs and ACs before touching the codebase.
2. **Search codebase** — grep for domain terms, types, function names from spec.md.
3. **Map affected files** — populate the Affected Files table for every file touched by any FR.
4. **Read key files** — understand entry points, types, public contracts, and patterns.
5. **Trace dependencies** — follow imports/calls to understand coupling.
6. **Check tests** — discover existing test infrastructure, helpers, and coverage patterns.
7. **Check config** — find env vars, feature flags, infrastructure dependencies.
8. **Find prior art** — locate similar implementations in the codebase to follow.
9. **Assess data changes** — identify DB schemas, API contracts, shared types affected.
10. **Flag risks** — note anything surprising, complex, or potentially breaking.

## Strategy

- **Use Explore subagent for parallel codebase scanning** — preserves main context for implementation. Dispatch with: "Search for X, Y, Z — return file paths, function signatures, and patterns found."
- **Use context7 MCP for external library/framework documentation** — call `resolve-library-id` then `query-docs` before reading unfamiliar library code.
- **Investigate before claiming** — do not infer a pattern from grep hits alone; open the file before you treat it as evidence.
- **Separate fact claims, hypotheses, and unknowns** — grounded findings drive the plan; unverified guesses stay labeled as guesses.
- **Keep facts Plan-usable** — each confirmed fact should be atomic enough to support Plan decisions, risks, task boundaries, or verification strategy.
- Affected Files table uses structured enums — use them exactly:
  - **Action**: `create | modify | delete | review`
  - **Impact**: `local | module | cross-module | breaking`
- Every FR from spec.md must map to at least one row in the Affected Files table.

## Artifacts to read

- `.features/{{FEATURE}}/spec.md` — required. Every FR must be covered.
- `.features/{{FEATURE}}/brief.md` — for constraints that affect scope.

## Maintenance

- Populate `.features/{{FEATURE}}/research.md` incrementally as you explore.
- Update Affected Files table whenever a new file is discovered.
- Update `.features/{{FEATURE}}/scratchpad.md` with findings every 3–5 tool calls.
- When research surfaces a non-obvious finding, append a K-entry to `.features/<id>/knowledge.md` immediately so discoveries do not wait for close.

## research.md required sections

- **Summary** — key findings, scope assessment
- **Affected Files** — table: File | Action | Module | Impact | Relates To
- **Code Context** — entry points, types & contracts, patterns & conventions
- **Dependencies** — internal module deps + external package deps

## research.md contextual sections (when applicable)

- Data Changes, Configuration, Test Landscape, Prior Art, System Context, Risks & Concerns

## Exit criteria

`research.md` exists. All FRs from spec.md have at least one affected file mapped. Key entry points and patterns documented.
