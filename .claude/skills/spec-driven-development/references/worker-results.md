# SDD Worker Result Contract

Structured result contract, status taxonomy, and return formats for SDD worker sessions. See [workers.md](workers.md) for the dispatch guide, packet schemas, and conceptual model.

## Status Taxonomy

Every worker result includes a status field. The status determines how the controller processes the result.

| Status | Meaning | When to Use | Controller Action |
|:-------|:--------|:------------|:------------------|
| `DONE` | Worker assignment completed successfully | Work finished, verification or assigned analysis completed, no concerns | Implementer: mark assigned task complete. Scout/drafter: controller processes structured output. |
| `DONE_WITH_CONCERNS` | Worker assignment completed but with caveats | Work is functional but has quality issues, technical debt, unresolved edge cases, or research/planning gaps | Review concerns, decide whether to address before proceeding |
| `BLOCKED` | Cannot complete the task | Missing dependencies, architectural blockers, or insufficient context | Assess blocker, provide context, break task into smaller pieces, or re-dispatch |
| `NEEDS_CONTEXT` | Missing information to proceed | Task requires clarification on requirements, scope, or approach | Provide missing information and re-dispatch with updated packet |

### Status Selection Guide

- If verification passes and everything looks good → `DONE`
- If verification passes but there are code quality concerns, technical debt, or minor scope concerns → `DONE_WITH_CONCERNS`
- If you cannot proceed because of an external blocker (dependency, architecture decision, environment) → `BLOCKED`
- If you cannot proceed because you lack information that the controller can provide → `NEEDS_CONTEXT`

Never silently produce work you are unsure about. Use `DONE_WITH_CONCERNS` rather than `DONE` if you have doubts. Use `BLOCKED` rather than guessing when you are stuck.

## Machine Result Record

Every worker result MUST include a dedicated `## Machine Result Record` section containing exactly one fenced `json` block. This is the canonical machine-readable return payload used by `SubagentStop` and later controller-side consumers.

### Section Contract

- The section heading MUST be `## Machine Result Record`
- The section MUST contain exactly one fenced `json` block
- `schema_version` MUST be `sdd-result-v1`
- `dispatch_id` MUST be copied unchanged from the dispatch packet
- The machine result block MUST appear once per worker result and should not be reused for examples elsewhere in the report body

### Common Machine Result Schema

| Field | Type | Required | Description |
|:------|:-----|:---------|:------------|
| `schema_version` | string | yes | Must be `sdd-result-v1` |
| `dispatch_id` | string | yes | Correlation key copied from the packet |
| `role` | string | yes | Worker role |
| `status` | string | yes | Role-appropriate status value |
| `summary` | string | yes | Short summary of the work or review outcome; missing summaries are auto-filled with a normalization warning |

Role-specific fields are required in addition to the common fields:

- **Implementer**: `task`, `files_changed`, `verification`
- **Reviewer**: `scope`, `findings`, `verdict`
- **Research scout**: `scope`, `findings`, `confidence`, `files_discovered`
- **Plan drafter**: `scope`, `proposed_decisions`, `proposed_tasks`

Reviewer machine results may also include these optional adjudication fields:

- `requirements_checked`: array of `{id, status, evidence, notes}` rows for FR/AC-level verification
- `verified_clean`: array of `{area, method, result}` rows for explicitly checked clean areas

Codex-imported results add provider metadata after `sdd worker import-result`
validates the machine record against a dispatch sidecar:

- `provider: "codex"`
- `support_only: true|false`
- `support_category: "review-support"` for support-only review evidence
- `import`: source file/stdin, import timestamp, and dispatch sidecar path

Codex reviewer-shaped output is support evidence by default. It is visible in
review adjudication support tables, but it does not satisfy required
`spec-reviewer` or `quality-reviewer` roles and cannot determine the Review
verdict by itself.

### Minimal Machine Result Example

```json
{
  "schema_version": "sdd-result-v1",
  "dispatch_id": "agent-abc123",
  "role": "implementer",
  "status": "DONE",
  "task": {
    "id": "T-002",
    "heading": "Emit and persist typed dispatch JSON at SubagentStart"
  },
  "summary": "Added typed dispatch schema docs and updated worker role prompts.",
  "files_changed": [
    {
      "path": "sdd-plugin/skills/spec-driven-development/references/workers.md",
      "action": "modify",
      "description": "Added machine dispatch record section"
    }
  ],
  "verification": {
    "command": "rg -n 'dispatch_id|schema_version|```json' ...",
    "result": "pass"
  }
}
```

## Validation Tiers

The SubagentStop hook validates worker results in two tiers. Understanding the tiers helps workers produce acceptable results on the first attempt.

### Tier 1 — Blocking (Identity and Correlation)

Tier 1 failures block the worker stop entirely. The worker must repair and re-submit.

| Check | Failure behavior |
|:------|:----------------|
| `schema_version` must be `sdd-result-v1` | Blocked |
| `dispatch_id` must match the originating dispatch | Blocked |
| `role` must be a recognized SDD worker role | Blocked |
| `status` must be valid for the role (e.g., implementer cannot use `PASS`) | Blocked |

### Tier 2 — Blocking Until Degraded (Structural Quality)

Tier 2 validates role-specific structure after automatic normalization. On attempts 1 and 2, Tier 2 failures block the worker stop with repair guidance. On attempt 3 and later, the hook enters degraded mode: if Tier 1 passes, it skips Tier 2 and persists the result with a degraded-quality warning. This prevents infinite stop-hook loops without accepting malformed identity or correlation data.

| Check | On failure |
|:------|:----------|
| Implementer `task.id` present | Blocked until repaired, or persisted only in degraded mode |
| Implementer `files_changed` is an array | Normalized when possible, then blocked until repaired if still invalid |
| Implementer `verification` is an object | Normalized when possible, then blocked until repaired if still invalid |
| Reviewer `scope` present | Blocked until repaired, or persisted only in degraded mode |
| Reviewer `findings` is an array | Blocked until repaired, or persisted only in degraded mode |
| Reviewer `verdict` present | Blocked until repaired, or persisted only in degraded mode |
| Research scout `scope` present | Blocked until repaired, or persisted only in degraded mode |
| Research scout `findings` is an array | Blocked until repaired, or persisted only in degraded mode |
| Research scout `confidence` is an object | Blocked until repaired, or persisted only in degraded mode |
| Research scout `files_discovered` is an array | Blocked until repaired, or persisted only in degraded mode |
| Plan drafter `scope` present | Blocked until repaired, or persisted only in degraded mode |
| Plan drafter `proposed_decisions` is an array | Blocked until repaired, or persisted only in degraded mode |
| Plan drafter `proposed_tasks` is an array | Blocked until repaired, or persisted only in degraded mode |

Normalization runs automatically before Tier 2 checks (see Automatic Normalization below).

## Automatic Normalization

The SubagentStop hook normalizes common near-miss result shapes before Tier 2 validation. Workers do not need to worry about these edge cases — normalization is transparent. The `_normalization_warnings` field in the persisted result lists what was coerced.

| Input shape | Normalized to |
|:------------|:-------------|
| `task_id: "T-004"` (flat string) | `task: {id: "T-004", heading: ""}` |
| `verification: "PASS"` (string) | `verification: {command: "", result: "PASS"}` |
| `files_changed: ["file.txt"]` (string array) | `files_changed: [{path: "file.txt", action: "unknown", description: ""}]` |
| Missing `summary` | `summary` auto-filled with placeholder |
| Already-correct input | Passed through unchanged with empty warnings |

## Repair Feedback

When a Tier 1 or Tier 2 validation failure blocks a result, the hook provides structured repair guidance in the block message:

- **Collect-all errors:** All failures for the active tier are reported in a single message — not just the first one. The worker can fix all issues in one pass.
- **Filled-in example:** The block message includes a pre-filled example JSON using the actual `dispatch_id`, `role`, and task context from the originating dispatch. Research-scout examples include `confidence` and `files_discovered`; plan-drafter examples include `proposed_decisions` and `proposed_tasks`.
- **Bounded retry:** The hook tracks stop attempts per agent session. On the first and second attempt, full validation runs. After 3 failed attempts, the hook relaxes to Tier 1 checks only and persists the result with a degraded-quality warning. This prevents infinite loops without silently dropping results.

**Cross-reference:** The dispatch packet now includes a `## Machine Result Template` section with a pre-filled result JSON matching the worker's role. Workers should use this template as their starting point (feature 0036 PH-02).

## Implementer Result Format

Task implementers return results in this format:

````markdown
## Worker Result

## Machine Result Record

```json
{
  "schema_version": "sdd-result-v1",
  "dispatch_id": "[dispatch_id copied from packet]",
  "role": "implementer",
  "status": "DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT",
  "task": {
    "id": "T-xxx",
    "heading": "[task description]"
  },
  "summary": "[brief description of what was implemented or attempted]",
  "files_changed": [
    {
      "path": "src/module/file.ts",
      "action": "create",
      "description": "[what was created and why]"
    }
  ],
  "verification": {
    "command": "[verification command from tasks.md]",
    "result": "[pass/fail/partial with details]"
  },
  "discoveries": [],
  "concerns": [],
  "suggested_artifact_updates": []
}
```

**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
**Task**: T-xxx: [task description]
**Role**: implementer

### Summary

[Brief description of what was implemented or attempted]

### Files Changed

| Path | Action | Description |
|:-----|:-------|:------------|
| src/module/file.ts | create | [what was created and why] |
| src/existing/file.ts | modify | [what was changed and why] |
| tests/module/test.ts | create | [test file created] |

### Verification

**Command**: [verification command from tasks.md]
**Result**: [pass/fail/partial with details]

### Discoveries

[Optional — new patterns, risks, or dependencies discovered during implementation]

| Discovery | Type | Description |
|:----------|:-----|:------------|
| [pattern or risk name] | pattern/risk/dependency | [what was found and why it matters] |

### Concerns

[Optional — only present when status is DONE_WITH_CONCERNS]

| Concern | Severity |
|:--------|:---------|
| [description of concern] | low/medium/high |

### Suggested Artifact Updates

[Optional — suggestions for the controller to apply to SDD artifacts]

| Artifact | Update |
|:---------|:-------|
| tasks.md | [e.g., "Add new task T-xxx for discovered dependency"] |
| research.md | [e.g., "Add newly discovered file src/utils/cache.ts to affected files"] |
| knowledge.md | [e.g., "New entry: project uses pattern X for Y"] |
````

### Field Details

- **Status**: Required. One of the four status values.
- **Machine Result Record**: Required. Must include the canonical `dispatch_id` and typed result fields.
- **Task**: Required. The task ID and description from the dispatch packet.
- **Role**: Required. Always `implementer` for this format.
- **Summary**: Required. What was implemented or attempted.
- **Files Changed**: Required. Every file the worker created, modified, or deleted.
- **Verification**: Required. The verification command and its result. If blocked, explain why verification could not run.
- **Discoveries**: Optional. New patterns, risks, or dependencies found during implementation.
- **Concerns**: Optional (required when status is `DONE_WITH_CONCERNS`). Describe quality issues, technical debt, or edge cases.
- **Suggested Artifact Updates**: Optional. Proposals for the controller to update SDD artifacts. The controller reviews and applies these.

## Reviewer Result Format

Spec reviewers and quality reviewers return results in this format:

````markdown
## Worker Result

## Machine Result Record

```json
{
  "schema_version": "sdd-result-v1",
  "dispatch_id": "[dispatch_id copied from packet]",
  "role": "spec-reviewer | quality-reviewer",
  "status": "PASS | FAIL | NEEDS_CONTEXT",
  "scope": "[what was reviewed]",
  "summary": "[short review summary]",
  "findings": [
    {
      "id": "F-001",
      "severity": "critical",
      "category": "missing-requirement",
      "description": "[what's missing]",
      "location": "file:line",
      "evidence": "[quoted evidence]",
      "suggestion": "[how to fix]"
    }
  ],
  "verdict": "[overall assessment]",
  "requirements_checked": [
    {
      "id": "AC-001",
      "status": "PASS",
      "evidence": "src/module/file.ts:42",
      "notes": "Behavior matches the acceptance criterion."
    }
  ],
  "verified_clean": [
    {
      "area": "Secret handling",
      "method": "Grep + code read",
      "result": "No hardcoded secrets found"
    }
  ]
}
```

**Status**: PASS | FAIL | NEEDS_CONTEXT
**Scope**: [what was reviewed — task IDs, file paths, or feature scope]
**Role**: spec-reviewer | quality-reviewer

### Findings

| ID | Severity | Category | Description | Location | Evidence | Suggestion |
|:---|:---------|:---------|:------------|:---------|:---------|:-----------|
| F-001 | critical | missing-requirement | [what's missing] | file:line | [evidence] | [how to fix] |
| F-002 | important | extra-work | [what was built but not requested] | file:line | [evidence] | [how to fix] |
| F-003 | minor | readability | [naming or organization issue] | file:line | [evidence] | [how to fix] |

### Verdict

[Overall assessment: PASS if all findings are minor and acceptable, FAIL if any
critical or important findings exist, NEEDS_CONTEXT if review cannot be completed]

[Explanation of verdict and recommendation for next steps]
````

### Field Requirements

- **Location** and **Evidence** are **required** for any finding with severity `critical` or `important`.
- **Machine Result Record** is required and must preserve the packet `dispatch_id`.
- A finding at `critical` or `important` severity without a `file:line` location and concrete evidence (quoted code, test output, or grep result) is invalid and must be dropped by the controller before processing.
- Summaries, paraphrases, and speculative descriptions do not qualify as evidence.
- `requirements_checked` and `verified_clean` are optional but strongly preferred for adjudication-aware review merge flows.

### Verified Clean

When a reviewer explicitly checks an area and finds no issues, that area should be recorded in a **Verified Clean** section in their result. Format:

| Area | Method | Result |
|:-----|:-------|:-------|
| [area checked] | [how it was checked] | [outcome] |

This distinguishes "checked and clean" from "not checked". Areas that were not checked should not appear in Verified Clean.

### Finding Severity Levels

| Severity | Meaning | Action |
|:---------|:--------|:-------|
| `critical` | Must fix before proceeding | Blocks task completion |
| `important` | Should fix before merging | May proceed with documented tech debt |
| `minor` | Nice to fix | Can be addressed later |

### Finding Categories

For **spec reviewers** (`spec-reviewer` role):
- `missing-requirement`: An FR or AC is not satisfied
- `extra-work`: Implementation includes features not in the spec
- `misunderstanding`: Implementation solves the wrong problem or interprets a requirement differently than intended
- `partial-implementation`: An FR is partially satisfied

For **quality reviewers** (`quality-reviewer` role):
- `correctness`: Logic errors, off-by-one bugs, unhandled error cases
- `tests`: Insufficient test coverage, tests that don't verify real behavior
- `security`: Injection vulnerabilities, secret handling issues, permission gaps
- `performance`: Obvious performance issues, inappropriate data structures
- `readability`: Unclear names, poor organization, hard-to-understand code
- `file-organization`: Files with unclear responsibilities, units not decomposed

## Research Scout Result Format

Research scouts return results in this format:

````markdown
## Worker Result

## Machine Result Record

```json
{
  "schema_version": "sdd-result-v1",
  "dispatch_id": "[dispatch_id copied from packet]",
  "role": "research-scout",
  "status": "DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT",
  "scope": "[what was explored]",
  "summary": "[short research summary]",
  "findings": [],
  "confidence": {
    "scope_clarity": 0,
    "pattern_familiarity": 0,
    "dependency_awareness": 0,
    "edge_case_coverage": 0,
    "test_strategy": 0,
    "total": 0,
    "verdict": "GO | HOLD"
  },
  "files_discovered": [
    {
      "path": "[file path]",
      "action": "create | modify | delete | review",
      "module": "[module]",
      "impact": "[impact]",
      "relates_to": "[FR/RQ id]"
    }
  ],
  "suggested_artifact_updates": []
}
```

**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
**Scope**: [what was explored — domain, file patterns, questions]
**Role**: research-scout

### Findings

[Structured answers to each question from the dispatch packet. Include
evidence-bearing fact claims, hypotheses, unknowns, affected surfaces, and
risks. Do not present search hits or uninspected assumptions as facts.]

### Confidence Score

| Dimension | Score | Notes |
|:----------|:------|:------|
| Scope clarity | [0-20] | [what you know about file scope] |
| Pattern familiarity | [0-20] | [whether similar patterns exist] |
| Dependency awareness | [0-20] | [what depends on relevant code] |
| Edge case coverage | [0-20] | [identifiable edge cases] |
| Test strategy | [0-20] | [how to verify changes] |
| **Total** | **[0-100]** | |

**Verdict**: GO (>= 70) | HOLD (< 70)

### Files Discovered

| Path | Relevance | Description |
|:-----|:----------|:------------|
| [file path] | high/medium/low | [what it contains and why it's relevant] |

`files_discovered[]` is the canonical machine boundary for research.md affected-file updates. Each entry uses:

| Field | Type | Description |
|:------|:-----|:------------|
| `path` | string | File path to render in the `File` column |
| `action` | enum | One of `create | modify | delete | review` |
| `module` | string | Module or subsystem name |
| `impact` | string | Expected blast radius |
| `relates_to` | string | FR/RQ id that the file supports |

Render `files_discovered[]` into the canonical Affected Files table format: `File | Action | Module | Impact | Relates To`. The human discovery table above is for communication only — pasting it verbatim can cause `sdd check research` to report zero valid rows.

### Suggested Artifact Updates

| Artifact | Update |
|:---------|:-------|
| research.md | [e.g., "Add src/cache/ to affected files with action review"] |
| knowledge.md | [e.g., "New entry: caching uses Redis with TTL pattern"] |
````

## Plan Drafter Result Format

Plan drafters return results in this format:

````markdown
## Worker Result

## Machine Result Record

```json
{
  "schema_version": "sdd-result-v1",
  "dispatch_id": "[dispatch_id copied from packet]",
  "role": "plan-drafter",
  "status": "DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT",
  "scope": "[what was planned]",
  "summary": "[short planning summary]",
  "proposed_decisions": [],
  "proposed_tasks": [],
  "risks": [],
  "suggested_artifact_updates": []
}
```

**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
**Scope**: [what was planned — architectural decisions, task decomposition]
**Role**: plan-drafter

### Proposed Architectural Decisions

[If applicable — in AD-xxx format from plan.md conventions]

- AD-xxx: [Title]
  - **Decision**: [what was decided]
  - **Rationale**: [why]
  - **Alternatives considered**: [what else was evaluated]

### Proposed Tasks

[If applicable — use the exact blockquote field syntax required by the tasks.md parser. Do NOT use bullet-list syntax for these fields — `sdd task list` silently returns zero rows if the format is wrong. Read `templates/tasks.md` to confirm the format before authoring.]

```markdown
## T-xxx: [Title]

> Status: pending
> Phase: PH-xx
> Implements: ["FR-xxx"]
> Depends-on: []
> Files: ["path/to/file (create|modify)"]

### Description
[atomic outcome — one sentence]

### Done When
[observable result, not a restatement of the steps]

### Steps
1. [step]

### Verification
\`\`\`bash
[command that fails when the implementation is broken]
\`\`\`
```

### Risks and Concerns

[Optional — risks identified during planning]

### Suggested Artifact Updates

| Artifact | Update |
|:---------|:-------|
| plan.md | [e.g., "Add AD-008 for caching strategy"] |
| tasks.md | [e.g., "Add T-008 through T-010 for caching layer"] |
````

## Suggested Artifact Updates

Workers return suggested artifact updates in the `suggested_artifact_updates` field of their result. The controller reviews each suggestion and decides whether to apply it.

### Format

```markdown
| Artifact | Update |
|:---------|:-------|
| tasks.md | Add new task T-xxx for [description] |
| research.md | Add [file] to affected files with action [create/modify/review] |
| knowledge.md | New entry: [discovery description] |
| review.md | Add finding [id]: [description] |
| continuity.md | Update progress: [what changed] |
```

### What Belongs in Each Artifact

| Artifact | Acceptable Suggestions | Not Acceptable |
|:---------|:----------------------|:---------------|
| `tasks.md` | New task additions, task reordering suggestions | Changes to other tasks' status, phase transitions |
| `research.md` | New affected files, pattern discoveries, dependency updates | Removing existing affected files, restructuring the document |
| `knowledge.md` | New knowledge entries, graduation-worthy findings | Editing existing entries, removing entries |
| `review.md` | Review findings (from reviewer roles) | Verdict changes, spec compliance judgments |
| `continuity.md` | Progress note updates | Goal changes, constraint changes |

### Tiered Ownership Reminder

| Tier | Artifacts | Worker Action |
|:-----|:----------|:--------------|
| SAFE | `scratchpad.md` observations, `sdd task complete` for assigned task | Worker may do directly |
| SUGGESTED | `tasks.md`, `research.md`, `knowledge.md`, `review.md`, `continuity.md` | Worker returns suggestion, controller applies |
| FORBIDDEN | `spec.md`, `plan.md`, `brief.md`, phase transitions, other tasks' status | Worker must not attempt |

## Escalation Guidance

### When to Return BLOCKED

Return `BLOCKED` when:
- A dependency is missing or broken and you cannot proceed
- An architectural decision is needed that is beyond your assigned scope
- The task requires modifying files outside your assigned scope
- You cannot make progress without external resources (APIs, services, environments)

**How to describe a blocker:**
- Be specific about what is blocking you
- Describe what you have tried
- Explain what kind of help would unblock you
- Include relevant error messages or logs

### When to Return NEEDS_CONTEXT

Return `NEEDS_CONTEXT` when:
- The task description is ambiguous or incomplete
- Requirements from spec.md are unclear for your assigned task
- You need information about the broader feature context that was not in the dispatch packet
- Multiple valid interpretations exist and you need the controller to choose

**How to describe missing context:**
- Identify the specific question or ambiguity
- List the possible interpretations you considered
- Explain what additional information would resolve the ambiguity

### When to Return DONE_WITH_CONCERNS

Return `DONE_WITH_CONCERNS` when:
- The task is functionally complete but has known quality issues
- You completed the main requirement but some edge cases are unhandled
- The verification command passes but you are not confident in correctness
- You had to make assumptions that should be reviewed

**How to describe concerns:**
- Categorize severity (low, medium, high)
- Be specific about what the concern is and where it manifests
- Suggest how the concern could be addressed
- Never silently produce work you are unsure about

## Cross-References

- **Worker dispatch guide and packet schema**: [workers.md](workers.md)
- **Canonical agent role files**: [`../agents/`](../agents/) — copy-ready definitions for each role
- **Agent routing guide**: [`../agents/README.md`](../agents/README.md)
- **Eval scenarios for worker behavior**: [`../evals/eval-scenarios.md`](../evals/eval-scenarios.md)
