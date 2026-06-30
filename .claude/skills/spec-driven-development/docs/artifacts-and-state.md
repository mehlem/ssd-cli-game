# Artifacts, State & Continuity

SDD's core strength is maintaining reliable, machine-readable state across long development sessions despite context constraints. This domain covers how SDD parses and refreshes artifacts (0003), synthesizes state into briefings (0007), tracks confidence and keeps derived state fresh (0012), recovers after context compaction (0013), and enforces evidence-based review rigor (0014).

## The Single Source of Truth Model

SDD treats feature artifacts as canonical sources: `spec.md`, `research.md`, `plan.md`, `tasks.md`, `review.md`, `brief.md`, and `continuity.md` are the authoritative state. Derived state lives in JSON control planes (`state.json`, `scope.txt`) and auto-generated briefings (`summary.md`, `summary-compact.md`). The invariant is strict: canonical artifacts flow forward; derived artifacts flow backward into refresh scripts.

Artifact frontmatter separates lifecycle from ownership. `status:` is the
artifact lifecycle/readiness value (`draft`, `active`, or `completed`), while
`phase:` names the SDD phase that owns the artifact. `phase:` does not track the
currently active execution phase; for example, `spec.md` remains owned by
`design` after the feature moves into Research or Implement.

Downstream scaffold commands intentionally complete predecessor artifacts when
they consume an exact `status: draft` predecessor. This is why creating
`research.md` can update `spec.md` to `status: completed`, creating `plan.md`
can update `research.md`, and creating `review.md` can update `tasks.md`.
Commands that perform this mutation report it in text output and JSON
`data.status_updates`, so the status transition is attributable instead of
appearing as an unexplained local edit.

**Markdown Hardening (0003)** makes this work. Parser fragility — duplicate verdict sources, ambiguous section separators, false positives in grep patterns — would break the invariant. The solution standardizes all templates with consistent H1 patterns (`# Type: Title`), uses `***` separators (not `---` to avoid CommonMark setext headings), stores review verdicts only in frontmatter, removes static Progress tables that drift, anchors grep patterns to avoid code-block matches, and applies portable sed for cross-platform compatibility. All changes remain backward-compatible: legacy `0001` and `0002` features continue to parse correctly. `.editorconfig` and `.gitattributes` enforce repo-wide LF line endings and UTF-8 to prevent anchor failures.

### Active Feature Pin & Audit Ledger (0044)

The active feature pin lives at `.features/.active` (a single line containing the feature ID) and is updated by `sdd select <feature>` or auto-set on `sdd init`. State stability (0044) adds two invariants on top of this pin:

- **Cache freshness gate**: `sdd_detect_feature_phase` cross-checks its cached `last_feature` against `.features/.active` and invalidates the cache on mismatch. This eliminates the bug where the cache served a stale feature ID after a manual `sdd select`.
- **`.features/.active.log`** — append-only NDJSON ledger. Every write to `.features/.active` is logged with timestamp, prior feature, new feature, and source (CLI invocation, hook, etc.) via the `sdd_set_active_feature` helper. Use the ledger when investigating "how did the active feature get to X" — it is the audit trail that complements `state.json`'s point-in-time snapshot.

## Synthesized State Briefings

After building state across multiple files, agents and humans need rapid reorientation. **Markdown Summary (0007)** adds a generator script that produces two derived markdown files per feature:

### Summary Files

- **summary.md** — full human-readable briefing with goal, phase, active work package (if any), current task, task counts (done/active/pending/blocked), phase rules, next action, scope highlights from research, recent changes from the log, confidence score and verdict, and review state
- **summary-compact.md** — compact 10-15-line briefing optimized for hook injection and subagent handoff, extracted to a single file suitable for SessionStart context injection

These briefings are also steering surfaces. They should preserve not only workflow state, but the parts of reasoning state that keep Claude grounded after compaction or restart: active assumptions, open ambiguity, the current blocker, the next verification target, and the relevant scope boundary when present.

The generator (`sdd-summary.sh`) reads canonical artifacts and synthesizes steering text by calling shared functions (`phase_rules()`, `next_move()`) moved into `sdd-lib.sh`. Summaries refresh automatically via the PostToolUse hook after any SDD command that changes state, and explicitly via `sdd summary <feature>`. Hooks prefer compact summary at SessionStart, with graceful fallback chains to continuity.md and then to the minimal `build_summary()` logic. On context compaction, `sdd-precompact.sh` snapshots the summary before the LLM drops context.

### Summary Generation Example

When `sdd-summary.sh 0012-sdd-confidence` runs on a feature in the implement phase:

```
# SDD Summary: 0012-sdd-confidence [selected]

- Goal: Make confidence scoring a first-class section in research, enrich state.json, auto-refresh scope.txt when research.md changes
- Phase: implement
- Active WP: wp-01-research-confidence
- Task: T-002: Parse confidence from research.md and write to state.json
- Progress: 1 done / 1 active / 2 pending / 0 blocked
- Rules: Work actively on in-progress tasks. Track blockers in scratchpad. Every task completion: update status, refresh state, document result in continuity.
- Process: see references/phases/implement.md for full methodology
- Next: Finish parsing confidence; run tests on sdd-status.sh; advance to next pending task.
- Confidence: 85/100 GO
- Review: not yet created
- Scope: sdd-lib.sh, sdd-status.sh, research.md
- Recent: 2026-04-13T14:22:11 | Edit | .features/0012-sdd-confidence/research.md
```

And `summary-compact.md` is rendered at SessionStart:

```markdown
> AUTO-GENERATED — DO NOT EDIT

# SDD Summary: 0012-sdd-confidence [selected]

- Goal: Make confidence scoring a first-class section in research, enrich state.json, auto-refresh scope.txt when research.md changes
- Phase: implement
- Active WP: wp-01-research-confidence
- Task: T-002: Parse confidence from research.md and write to state.json
- Progress: 1 done / 1 active / 2 pending / 0 blocked
- Rules: Work actively on in-progress tasks. Track blockers in scratchpad. Every task completion: update status, refresh state, document result in continuity.
- Process: see references/phases/implement.md for full methodology
- Next: Finish parsing confidence; run tests on sdd-status.sh; advance to next pending task.
- Confidence: 85/100 GO
- Review: not yet created
- Scope: sdd-lib.sh, sdd-status.sh, research.md
- Recent: 2026-04-13T14:22:11 | Edit | .features/0012-sdd-confidence/research.md
```

## Confidence Scoring & Artifact Refresh

The research phase gates entry to planning, but without a machine-readable confidence signal, agents cannot assess readiness. **Confidence and Artifact Refresh (0012)** adds a structured rubric to `research.md`: five dimensions (Scope clarity, Pattern familiarity, Dependency awareness, Edge cases, Test strategy), each 0-20, totaling 0-100, plus a GO/HOLD verdict line.

### Confidence Rubric Format

The research template includes a `## Confidence` section:

```markdown
## Confidence

- **Scope clarity** (0-20): How well are success criteria and feature scope defined?
  - 0-5: Scope is vague; success criteria unclear.
  - 6-12: Scope is mostly clear but has gaps in edge cases or constraints.
  - 13-20: Scope is explicit; success criteria are specific and measurable.

- **Pattern familiarity** (0-20): Is this a familiar pattern or novel implementation?
  - 0-5: No precedent; pattern is new and poorly understood.
  - 6-12: Partial precedent; similar work exists but with significant unknowns.
  - 13-20: Pattern is well-known; precedent exists in codebase or public examples.

- **Dependency awareness** (0-20): Are external/internal dependencies mapped and acceptable?
  - 0-5: Key dependencies are unknown or unclear.
  - 6-12: Most dependencies identified but interaction risks remain.
  - 13-20: All dependencies mapped; interaction risks assessed and acceptable.

- **Edge cases** (0-20): Are boundary conditions and failure modes understood?
  - 0-5: Edge cases are largely unexamined.
  - 6-12: Common edge cases identified; some gaps in failure-mode analysis.
  - 13-20: Edge cases fully mapped; failure modes and recovery strategies clear.

- **Test strategy** (0-20): Is testing approach clear and feasible?
  - 0-5: Test strategy is undefined or infeasible.
  - 6-12: Basic test plan exists; some complex scenarios lack test coverage.
  - 13-20: Test strategy is specific, feasible, and covers normal + edge cases.

- **Total**: 0-100
  - 0-30: HOLD — too many unknowns; return to research.
  - 31-69: HOLD — moderate risk; consider extending research.
  - 70+: GO — sufficient confidence; ready for planning or implementation.

- **Verdict**: GO | HOLD
```

`sdd-status.sh` parses the Confidence section and writes the score and verdict to `state.json` alongside the review verdict and other feature-local cache fields. Invocation-scoped metadata from a specific CLI call stays in the command JSON envelope (`resolution_source`) and is not persisted into the tracked cache; that keeps `state.json` deterministic across callers. More importantly, `sdd-cache-refresh.sh` becomes artifact-aware: when it detects that `research.md` was edited, it automatically regenerates `scope.txt` and refreshes both summary files. The result is that derived artifacts drift no longer — editing a canonical source triggers a cascade of refresh operations that keep the entire state tree in sync.

### state.json Enrichment

The persisted `state.json` snapshot contains:

```json
{
  "confidence": {
    "score": 85,
    "verdict": "GO"
  },
  "review": {
    "verdict": "pending"
  },
  "feature": "0012-sdd-confidence-and-artifact-refresh",
  "phase": "implement",
  "current_task": {
    "id": "T-002",
    "heading": "T-002: Parse confidence from research.md"
  },
  "tasks": {
    "completed": 1,
    "in_progress": 1,
    "pending": 2,
    "blocked": 0
  }
}
```

## Semantic Readiness Sidecars

Structural checks answer "is the artifact present and shaped correctly?" Semantic gates answer "is the artifact actually good enough for the next phase?" Feature 0024 adds a second derived control-plane layer under `.features/<feature>/semantic/`, one JSON file per gated artifact:

- `brief.json`
- `spec.json`
- `research.json`
- `plan.json`

The markdown artifacts remain canonical. Semantic files are derived judgments that can be recomputed and discarded.

### Sidecar Schema

Each semantic sidecar stores the latest judgment for one artifact:

```json
{
  "schema_version": 1,
  "feature": "0024-sdd-semantic-phase-gates",
  "artifact": "spec",
  "artifact_path": ".features/0024-sdd-semantic-phase-gates/spec.md",
  "rubric_path": "sdd-plugin/skills/spec-driven-development/references/rubrics/spec.md",
  "score": 82,
  "verdict": "GO",
  "reason": "Problem framing is concrete, FRs are specific, and ACs are testable enough to support research.",
  "source": {
    "kind": "agent-hook",
    "trigger": "pretooluse:bash:sdd research",
    "model": "haiku"
  },
  "artifact_sha256": "6e90580d5a0f4d6eb7d5b0e96ea90d0fd35d7e8c2b2d4b6a6dfe4c53b97e93d0",
  "evaluated_at": "2026-04-14T13:22:11Z"
}
```

### Freshness Model

Semantic readiness is **not** re-evaluated on every edit. Instead:

1. Hooks or explicit semantic checks write the sidecar after an evaluation.
2. The sidecar stores the SHA-256 of the artifact as it existed at evaluation time.
3. `sdd-status.sh` compares the stored hash with the current artifact hash when rebuilding `state.json`.
4. If no sidecar exists, readiness is `pending`.
5. If the hash differs, readiness becomes `stale`.
6. If the hash matches, readiness is `current`.

This keeps edit-time refreshes cheap while still exposing semantic drift immediately.

### state.json Projection

`state.json` mirrors semantic readiness into a per-artifact object:

```json
{
  "semantic_readiness": {
    "brief": {
      "status": "pending",
      "score": null,
      "verdict": null,
      "reason": null,
      "evaluated_at": null
    },
    "spec": {
      "status": "current",
      "score": 82,
      "verdict": "GO",
      "reason": "Problem framing is concrete, FRs are specific, and ACs are testable enough to support research.",
      "evaluated_at": "2026-04-14T13:22:11Z"
    },
    "research": {
      "status": "stale",
      "score": 78,
      "verdict": "GO",
      "reason": "Affected files and dependency mapping are strong, but the artifact changed after evaluation.",
      "evaluated_at": "2026-04-14T12:08:02Z"
    },
    "plan": {
      "status": "pending",
      "score": null,
      "verdict": null,
      "reason": null,
      "evaluated_at": null
    }
  }
}
```

Status and summaries can then surface either the next relevant semantic gate or the full per-artifact readiness map without reparsing markdown prose.

## Typed Worker Contracts (0023)

Worker dispatch and results are persisted as feature-local JSON sidecars under:

```
.features/<feature>/workers/
├── dispatch-<dispatch_id>.json   # Packet sent to worker
└── result-<dispatch_id>.json     # Structured result from worker
```

Dispatch packets carry a typed header embedded in the markdown assignment:
```json
{
  "dispatch_id": "DISP-0001-T-003",
  "schema_version": "1",
  "role": "sdd-implementer",
  "feature": "0001-user-auth",
  "phase": "implement"
}
```

Worker results include a matching `result_id` linking back to the dispatch, a `status` value (DONE, DONE_WITH_CONCERNS, BLOCKED, NEEDS_CONTEXT), and a `warnings` array for non-blocking issues. The `sdd status --json` output exposes the worker ledger under `workers.pending` and `workers.history`.

## Review Adjudication Sidecars

Feature 0025 extends the review phase with durable evidence capture and deterministic merge state. The canonical review artifact is still `review.md`; adjudication sidecars live alongside it under `.features/<feature>/review-adjudication/`.

### Evidence Sources

- `.features/<feature>/verification/<task-id>.json` stores persisted verification output from `sdd task complete`
- `.features/<feature>/workers/result-<dispatch_id>.json` stores typed reviewer results from the 0023 worker ledger
- `.features/<feature>/review-adjudication/input.json` stores the assembled adjudication bundle
- `.features/<feature>/review-adjudication/current.json` stores the latest derived adjudication state used by merge, status, summary, and gates

Work-package adjudication uses the same schema under a nested scope directory:

- `.features/<feature>/review-adjudication/<wp-id>/input.json`
- `.features/<feature>/review-adjudication/<wp-id>/current.json`

### Verification Sidecar Schema

Each verification record captures the task-local command outcome exactly as it ran during task completion:

```json
{
  "schema_version": 1,
  "feature": "0025-sdd-review-adjudication",
  "work_package": null,
  "task": {
    "id": "T-001",
    "title": "Capture task verification output under verification/",
    "phase": "PH-01",
    "implements": "FR-001, FR-004",
    "tasks_file": ".features/0025-sdd-review-adjudication/tasks.md"
  },
  "captured_at": "2026-04-14T16:18:02Z",
  "verification": {
    "mode": "block",
    "command": "bash sdd-plugin/skills/spec-driven-development/scripts/tests/sdd-task-test.sh",
    "result": "pass",
    "exit_code": 0,
    "stdout": "...",
    "stderr": "..."
  }
}
```

### Adjudication Bundle Schema

`input.json` is the evidence assembly surface for `sdd review adjudicate`:

```json
{
  "schema_version": 1,
  "feature": "0025-sdd-review-adjudication",
  "work_package": null,
  "review_path": ".features/0025-sdd-review-adjudication/review.md",
  "generated_at": "2026-04-14T16:21:55Z",
  "required_roles": ["spec-reviewer", "quality-reviewer"],
  "verification_records": [],
  "reviewer_results": []
}
```

`current.json` is the merge-ready derived state projection:

```json
{
  "schema_version": 1,
  "feature": "0025-sdd-review-adjudication",
  "work_package": null,
  "review_path": ".features/0025-sdd-review-adjudication/review.md",
  "input_path": ".features/0025-sdd-review-adjudication/review-adjudication/input.json",
  "current_path": ".features/0025-sdd-review-adjudication/review-adjudication/current.json",
  "adjudicated_at": "2026-04-14T16:22:01Z",
  "verdict_source": "adjudicated",
  "evidence_status": "insufficient",
  "overall_verdict": "pending",
  "required_roles": ["spec-reviewer", "quality-reviewer"],
  "missing_roles": ["quality-reviewer"],
  "verification_count": 1,
  "reviewer_count": 1,
  "verification_records": [],
  "reviewer_results": []
}
```

### Merge Contract

`sdd-review-merge.sh` treats the `## Adjudication` section in `review.md` as a managed block. The merge is deterministic:

- frontmatter `verdict`, `verdict_source`, `evidence_status`, and `adjudicated_at` are upserted on every merge
- the markdown between `<!-- SDD-ADJUDICATION:START -->` and `<!-- SDD-ADJUDICATION:END -->` is replaced wholesale
- other review sections remain human-editable and are not rewritten by adjudication

This preserves `review.md` as the single canonical review document while keeping the machine-audit trail in sidecars.

## Task Dependency Graph (0026)

Tasks in `tasks.md` support a `Depends-on:` field listing prerequisite task IDs:

```
- [ ] T-003 — Implement auth middleware
  - Depends-on: T-001, T-002
  - Files: src/middleware/auth.ts
```

`sdd task next` respects this graph — it only surfaces tasks whose dependencies are complete. `sdd task start` blocks on unresolved dependencies (pass `--force` to override). `sdd task graph <feature>` returns the full DAG as JSON, and `sdd check tasks` validates for cycles, missing IDs, and self-dependencies.

On `sdd task start`, a `task-scope.txt` is auto-generated listing exactly the files in scope for that task, enabling precise scope-drift detection during implementation.

## Continuity & Post-Compaction Recovery

Continuity is not just a progress log. It is the bridge that keeps the steering core alive after compaction: surface ambiguity instead of hiding it, preserve grounded facts separately from open hypotheses, record the smallest safe next move, and keep the next verification target visible.

Long sessions eventually hit context limits. Claude Code's session compaction drops accumulated context but preserves the LLM's conversation summary. **Post-Compact and Handoff (0013)** captures that summary into continuity.md for richer recovery.

The PostCompact hook is side-effect-only per Claude Code spec — it cannot inject context, only capture state. `sdd-postcompact.sh` reads the LLM's `compact_summary` from the hook input and appends it to continuity.md under a `## Compaction Summary` heading with timestamp. It then refreshes `state.json` and summary files so that the subsequent `SessionStart(compact)` handler has the freshest possible data. A flag (`post_compact_pending`) marks cases where the compact summary dropped critical state (feature ID, phase, or current task); the next prompt reinjects anchoring context.

### Continuity Structure with Compaction Capture

When compaction fires (auto or manual), the hook appends:

```markdown
# Continuity: 0012-sdd-confidence

## Goal

Make confidence scoring a first-class section in research.md, enrich state.json with confidence and review verdict metadata, make sdd-cache-refresh.sh artifact-aware so editing research.md auto-refreshes scope.txt, and surface new signals in summary files.

## Session 1 Work

Completed research phase:
- Defined five confidence dimensions (Scope clarity, Pattern familiarity, Dependency awareness, Edge cases, Test strategy)
- Mapped Affected Files table to sdd-review.sh scope conformance pre-fill
- Designed state.json enrichment structure

## Compaction Summary (2026-04-13T14:22:11Z)

- Trigger: auto

Completed parsing confidence rubric from research.md template. In-progress on feature 0012 during implement phase. Current work: T-002 (Parse confidence from research.md and write to state.json). Key blockers: ensuring jq JSON generation maintains backward compatibility with pre-confidence features. Recent changes: updated research.md template with Confidence section, began sdd-status.sh modifications. All work committed; ready to resume on T-002 completion.
```

For explicit session transitions, `sdd handoff [feature]` generates a reader-oriented handoff document that compiles current status, task breakdown by status, recent changes from `changes.log`, open questions from `scratchpad.md`, and a copy-pasteable resume prompt. Handoff is a read-only view over canonical artifacts, not a new source of truth — it exits after printing to stdout.

### Handoff Document Example

Running `sdd handoff 0012-sdd-confidence` outputs:

```markdown
# SDD Handoff: 0012-sdd-confidence

## Status

- Feature: 0012-sdd-confidence
- Phase: implement
- Current task: T-002: Parse confidence from research.md and write to state.json
- Progress: 1 completed, 1 in-progress, 2 pending, 0 blocked
- Confidence: 85/100 GO
- Review: not yet created

## Task Breakdown

### Completed

- T-001: Design confidence rubric and state.json enrichment

### In Progress

- T-002: Parse confidence from research.md and write to state.json

### Pending

- T-003: Auto-refresh scope.txt when research.md changes
- T-004: Add confidence and review verdict to summary files

### Blocked

(none)

## Recent Changes

- 2026-04-13T14:22:11 | Edit | .features/0012-sdd-confidence/research.md
- 2026-04-13T14:10:22 | Write | .features/0012-sdd-confidence/tasks.md
- 2026-04-13T13:55:43 | Edit | .features/0012-sdd-confidence/plan.md
- 2026-04-13T13:42:19 | Edit | .features/0012-sdd-confidence/research.md

## Open Questions

- Should HOLD verdict prevent sdd plan <feature>? (Resolved: no — HOLD flags a gap but doesn't block.)
- Do we need backward-compat logic for features without a Confidence section? (In progress: yes.)

## Resume Prompt

`Resume feature 0012-sdd-confidence in implement phase. Current task: T-002: Parse confidence from research.md and write to state.json. Next: Finish parsing confidence; run tests on sdd-status.sh; advance to next pending task.`
```

## Review Rigor & Evidence Requirements

SDD's review phase is mandatory but soft. Reviewers can report findings without verifying them, validate acceptance criteria with vague status labels instead of evidence, and hedge language ("consider...", "ensure...") adds noise without catching bugs. **Verified Review Rigor (0014)** upgrades the review contract to be evidence-first.

The review template gains three sections:

1. **Review Protocol** — states rules at the top: every finding requires `file:line` citation, hedging is banned, unverified claims are dropped, use "Verified Clean" sections to declare areas checked and confirmed problem-free
2. **Scope Conformance** — cross-checks actual file changes against research.md Affected Files; columns are File, Expected (from research), Actually Changed (from changes.log), Status (expected/unexpected/missing), Notes
3. **Verified Clean** — let reviewers explicitly list areas they checked with no issues, replacing padding-by-vagueness

### Review Protocol Section

The template begins:

```markdown
# Review: 0012-sdd-confidence

## Review Protocol

Every finding in this review MUST meet these requirements:

- **Evidence**: Every finding requires concrete evidence: `file:line` citations, test output, or quoted code. Status labels alone are not evidence.
- **No hedging**: Ban hedging language ("consider...", "ensure that...", "might...", "should probably..."). Use imperative statements only ("refactor X", "add test for Y", "remove Z").
- **Verified only**: Report only issues you have verified by reading code, running tests, or examining output. Do not speculate or infer.
- **Verified Clean sections**: When an area has been checked and found problem-free, declare it explicitly in the Verified Clean section instead of omitting it from findings.

Unverified claims will be dropped during review. Hedging language will be rewritten or removed. This is not nitpicking — it is precision.
```

### Scope Conformance Table

When `sdd-review.sh` scaffolds the review, it pre-fills the Scope Conformance table by parsing `research.md` Affected Files and `changes.log`:

```markdown
## Scope Conformance

| File | Expected | Actually Changed | Status | Notes |
|:-----|:---------|:-----------------|:-------|:------|
| sdd-lib.sh | yes | yes | expected | Core shared functions |
| sdd-status.sh | yes | yes | expected | Parses confidence; writes to state.json |
| sdd-summary.sh | yes | yes | expected | Renders confidence in summaries |
| scripts/templates/research.md | yes | yes | expected | Added Confidence section |
| scripts/templates/review.md | yes | yes | expected | Added Review Protocol, Scope Conformance, Verified Clean |
| sdd-cache-refresh.sh | yes | — | expected | Planned for artifact-aware refresh |
| .features/0012-sdd-confidence/research.md | — | yes | expected | Feature artifact edited during implementation |
| README.md | — | yes | unexpected | Why was README modified? Check for scope creep. |
```

### Verified Clean Section

Reviewers can declare areas checked:

```markdown
## Verified Clean

Areas examined and confirmed problem-free:

- **Backward compatibility**: Tested `sdd status 0001-sdd-agent-harness` and `sdd status 0002-sdd-work-packages`. Both parse correctly with new code; confidence fields default to 0/pending when absent.
- **JSON structure**: Verified that state.json is valid when confidence section is missing (defaults applied), and valid when present (parsing works).
- **Parsing correctness**: Spot-checked confidence parsing in 5 sample research.md files; all dimensions and verdicts extracted correctly.
- **Summary injection**: Verified that summary-compact.md confidence line renders correctly in hook injection without formatting breaks.
```

### Issues Found Section with Evidence

The table for findings now requires evidence:

```markdown
## Issues Found

| Severity | Location | Description | Evidence | Notes |
|:---------|:---------|:------------|:---------|:------|
| critical | sdd-status.sh:142 | Confidence parsing assumes `## Confidence` header; fails silently if missing | Tested with pre-confidence feature 0001; no error but confidence defaulted to 0. Added fallback at line 145. | Must handle legacy features. |
| important | sdd-summary.sh:198 | Confidence verdict extraction uses regex; returns empty on malformed Verdict line | Created test case with garbled "- **Verdict**: GOOOO"; verdict parsed as "pending" instead of failing. Fixed regex anchoring. | Edge case but possible. |
| minor | scripts/templates/research.md | Confidence section example uses "0-5", "6-12", "13-20" ranges; one WP used "0-10", "11-20" instead. | Found in WP review feedback; ranges were inconsistent across placeholders. Standardized all to 0-5 / 6-12 / 13-20. | For next WP baseline. |
```

`sdd-review.sh` pre-fills the Scope Conformance table by parsing `research.md` Affected Files and `changes.log` to populate Expected and Actually Changed columns. The Issues Found section gets an Evidence column. Reviewer worker results are tightened: Location and Evidence become required fields (not optional) for critical and important findings. Reviewer agents (`sdd-spec-reviewer.md`, `sdd-quality-reviewer.md`) are briefed on the protocol: read code first, cite `file:line`, drop unverified claims, use Verified Clean sections instead of invented problems.

## The Artifact Refresh Cascade

Changes flow through the system in layers:

1. **Canonical editing** — agent edits spec.md, research.md, or other feature artifacts
2. **PostToolUse hook fires** — `sdd-cache-refresh.sh` runs asynchronously
3. **Artifact-aware refresh** — if research.md was edited, regenerate scope.txt; always regenerate state.json
4. **Derived briefing refresh** — re-run summary.md and summary-compact.md
5. **Next SessionStart injection** — hook pulls fresh summary-compact.md and injects it as context

When context compaction occurs:

1. **Conversation drops** — Claude Code discards accumulated context
2. **PostCompact fires** — `sdd-postcompact.sh` captures the LLM's summary to continuity.md, refreshes state and summaries
3. **SessionStart (compact matcher)** — hooks inject the refreshed summary-compact.md plus a re-anchoring context block if `post_compact_pending` was set
4. **Recovery continues** — agent resumes with fresh state tree and rich continuity history

### Artifact Refresh Timing

The PostToolUse hook registers `sdd-cache-refresh.sh` and runs after each Edit/Write/Bash tool invocation. The script:

1. Detects the active feature via `sdd-phase.sh`
2. Derives the feature from the edited file path (if available, to handle cross-feature edits)
3. Calls `sdd-status.sh --json` to regenerate state.json
4. Calls `sdd-summary.sh` to regenerate summary.md and summary-compact.md
5. Detects if the edited file is research.md; if so, calls `sdd-scope.sh refresh` to regenerate scope.txt
6. Appends the edit to changes.log with timestamp, tool name, and file path
7. Updates a local state cache for nudge detection and event-aware steering

The model is self-healing: canonical artifacts are never stale, derived state follows automatically, and compaction loss is mitigated by captured summaries. Confidence scoring and scope tracking make readiness signals transparent. Evidence requirements in review make verification explicit. The artifact chain is the contract: readers trust that everything they see has been checked and refreshed.

## Summary of Features and Their Artifacts

| Feature | Key Artifacts | Core Behavior |
|:--------|:--------------|:--------------|
| **0003** (Markdown Hardening) | templates/*review.md, .editorconfig, .gitattributes | Standardizes markdown structure, anchors grep patterns, enforces LF line endings to prevent parsing failures |
| **0007** (Markdown Summary) | summary.md, summary-compact.md, sdd-lib.sh (phase_rules, next_move) | Auto-generates briefings from canonical artifacts; refreshes via PostToolUse hook; injected at SessionStart |
| **0012** (Confidence & Refresh) | research.md (Confidence section), state.json (confidence, review, selection_source), sdd-cache-refresh.sh | Adds confidence rubric; enriches state.json; auto-refreshes scope.txt when research.md changes |
| **0013** (Post-Compact & Handoff) | continuity.md (Compaction Summary sections), sdd-postcompact.sh, sdd-handoff.sh | PostCompact hook captures LLM summary; handoff command generates reader-oriented session view |
| **0014** (Verified Review Rigor) | review.md (Review Protocol, Scope Conformance, Verified Clean sections), sdd-review.sh pre-fill | Enforces evidence-first review discipline; cross-checks actual changes against scope; lets reviewers declare verified-clean areas |
| **0034** (Feature Description Metadata) | brief.md (Short/Long Description sections), sdd-lib.sh (sdd_feature_description_json), sdd-index.sh, sdd-status.sh, sdd-handoff.sh, sdd-archive.sh, sdd-cache-refresh.sh | Canonical description fields in brief.md with shared resolver; exposed through index/status/handoff/archive; async cache-refresh keeps INDEX.md fresh |

## Canonical Feature Descriptions (0034)

`brief.md` is the canonical home for feature descriptions via two body sections:

- **`## Short Description`** — one sentence, reused by INDEX.md, status, handoff, and archive context (prefer <= 200 chars)
- **`## Long Description`** — optional 1-3 paragraph reusable description

These are body sections (not frontmatter) because the codebase's frontmatter readers only handle single-line values.

### Shared Resolver

`sdd_feature_description_json <feature-id>` in `sdd-lib.sh` provides consistent resolution with a backward-compatible fallback chain:

**Short description** (6-level): Short Description > Long Description first paragraph > summary-compact.md Goal > Motivation first paragraph > brief title > feature ID

**Long description** (3-level): Long Description body > Motivation+Vision body > null

Output shape: `{"short":"...","long":"..."|null,"short_source":"...","long_source":"..."|null}`

### Derived State

`state.json` includes a `description` object (populated by `sdd-status.sh`):
```json
"description": {
  "short": "...",
  "long": "..." or null,
  "short_source": "brief.short_description",
  "long_source": "brief.long_description" or null
}
```

### Index Freshness

`sdd-cache-refresh.sh` (PostToolUse async hook) rebuilds INDEX.md after every tool use, so index stays fresh even after brief/task/review edits — not just lifecycle events.

## Session Flags Schema (0019)

Hooks coordinate via a `session_flags` object in `state.json` rather than direct hook-to-hook calls, keeping the system acyclic. Fields:

| Flag | Type | Set by | Read by | Purpose |
|:-----|:-----|:-------|:--------|:--------|
| `post_compact_pending` | boolean | PostCompact | UserPromptSubmit | Signals that compaction occurred; next prompt should inject re-anchoring context with feature, phase, task |
| `instructions_reloaded` | boolean | InstructionsLoaded | UserPromptSubmit | Triggers re-orientation guidance when instructions reload on context-compaction recovery |
| `last_tool_failure` | object\|null | PostToolUseFailure | UserPromptSubmit | Captures failed tool name and error; triggers failure-recovery guidance to aid diagnosis and retry |
| `dispatch_epoch` | integer | SubagentStart | SubagentStop | Monotonic counter correlating subagent dispatch with result validation (reserved for feature 0020) |

Hooks read these flags at startup, act on them (emitting targeted context or guidance), then clear the flag to prevent double-firing. The pattern keeps each hook self-contained while allowing cross-hook coordination without direct hook-to-hook calls, preserving acyclicity.

## Trace Graph & Provenance (0030)

SDD maintains a typed provenance graph as a feature-local sidecar:

```
.features/<feature>/
└── trace.json    # typed dependency graph
```

### Typed Links in Frontmatter

Artifact frontmatter gains a `links:` field with typed parent references as inline JSON. The field captures multi-source provenance:

```yaml
---
id: PLAN-0021
feature: "0021-feature-name"
type: plan
links: {"derived_from":["SPEC-0021","RESEARCH-0021"],"informed_by":["external-design-doc"],"supersedes":[]}
based_on: {"SPEC-0021":"sha256:6aab15c1c8d3","RESEARCH-0021":"sha256:07d4f2a2e91b"}
---
```

**Link types**:
- `derived_from`: direct upstream sources that this artifact was synthesized from (replaces legacy `source:` field semantics, supporting multi-parent)
- `informed_by`: secondary inputs or external sources that influenced but did not directly generate this artifact
- `supersedes`: artifacts this one replaces in a version lineage

Each downstream artifact also carries a `based_on:` field recording the revision (SHA-256) hash of upstream artifacts at the time of derivation. This enables detection of stale work: if the upstream hash changes, the downstream artifact is flagged `suspect: true`.

### Hash Normalization and Basis Stamps

Content hashes are computed by:
1. Reading the artifact's full content
2. Stripping volatile frontmatter keys (created, updated, status, based_on, suspect) to prevent false positives when only metadata changes
3. Computing SHA-256 of the normalized content
4. Storing the hex hash in `based_on: {artifact_id: "sha256:6aab15c1..."}`

When `sdd-spec.sh` creates or regenerates `spec.md`, it stamps `based_on` with the hash of `BRIEF-0021` at that moment. When `sdd-plan.sh` creates or regenerates `plan.md`, it stamps `based_on` with hashes of both `SPEC-0021` and `RESEARCH-0021` as they existed when the plan was derived.

### Transitive Suspect Propagation

When an upstream artifact's content changes:

1. `sdd-trace.sh refresh` computes the current hash of the upstream artifact
2. It compares against the `based_on` hashes in downstream artifacts' frontmatter
3. Any mismatch marks the downstream artifact `suspect: true` with a specific reason ("SPEC-0021 changed: was sha256:abc123, now sha256:def456")
4. A second pass propagates suspect transitively: if `SPEC-0021` is suspect and `plan.md` is `derived_from SPEC-0021`, then plan becomes suspect; if tasks.md is `derived_from plan`, tasks become suspect too
5. The propagation is recorded in `trace.json` with the full chain of suspect reasons

This ensures that stale work is detected early: when `sdd task start` is called on a suspect task, the agent is hard-blocked with a list of which upstream artifacts changed (and how), and has the option to pass `--force` to override.

### Trace Graph Structure

`trace.json` contains:
- **nodes**: artifact nodes (spec.md, plan.md, tasks.md, etc.), FR nodes (FR-001, FR-002, etc.), AC nodes, task nodes (T-001, T-002), file nodes, with kind, status, path, and revision hash per node
- **edges**: typed links (derived_from, informed_by, implements, addresses, validates, touches, depends_on) extracted from artifact frontmatter and body references
- **indexes**: reverse lookups for "which tasks implement FR-001?", "which artifacts depend on this one?", "which tasks are ready to start?" (dependencies satisfied)
- **basis**: per-artifact suspect state, based_on hashes, and specific mismatch reasons
- **problems**: validation issues (unresolved refs, missing coverage)

When an upstream artifact changes, downstream artifacts are flagged as suspect. `sdd task start` hard-blocks on suspect tasks. `sdd trace refresh <feature>` re-evaluates the graph but **does not** clear suspect flags — it only updates the structural view.

To clear suspect after the operator has verified the upstream change is incorporated, use `sdd trace acknowledge <feature> [ARTIFACT-ID...]`:

- Restamps `based_on` hashes in suspect artifact frontmatter (via `sdd_stamp_based_on`).
- Records a structured `trace_acknowledge` entry to `.features/<feature>/changes.log` with timestamp, acknowledged artifact IDs, and the optional `--reason <text>` annotation.
- Auto-runs `sdd trace refresh` afterwards so the operator immediately sees the green state.
- Requires `--confirmed` (refuses without it; dry-run shape printed otherwise).
- Prefer this over `--force` on the suspect gate: `--force` has no audit trail, acknowledge does. The full clearing-path contract lives in `references/trace-acknowledge.md`.

`sdd trace doctor <feature>` reports suspect nodes and gap chains; `sdd trace coverage <feature>` evaluates the trace against `references/trace-rules.json` and reports orphaned requirements, untraceable tasks, and an overall coverage score (also integrated into `sdd check all`).

## Trace Coverage Rules (0033)

Trace completeness is evaluated against a declarative rules manifest at `references/trace-rules.json`. Coverage rules define what link types are required between artifact pairs, which body fields must be populated, and what traceability relationships must exist.

```bash
sdd trace coverage <feature>       # evaluate coverage, print gap report
sdd trace coverage --json <feature> # machine-readable coverage score
```

The coverage report shows:
- **Coverage score** (0–100) computed from rules satisfied vs. total applicable rules
- **Orphaned requirements** — FR-xxx IDs in spec.md with no downstream task link (no task implements this FR)
- **Untraceable tasks** — T-xxx items with no upstream requirement link (task doesn't implement any FR)
- **Missing link types** — artifact pairs that should have a `derived_from` or `informed_by` link but don't (e.g., plan without research link)
- **Gap details** — specific rule failures with counts and item IDs

Coverage evaluation is integrated into `sdd check all`. A coverage score below the configured threshold produces an informational warning (non-blocking by default in v1). The threshold and required link types are configured in `references/trace-rules.json`.

### Coverage Rules Schema

`references/trace-rules.json` defines default coverage expectations:

- **Artifact link rules**: required link types per artifact type (e.g., spec must derive_from at least 1 BRIEF-*, plan must derive_from SPEC or RESEARCH)
- **Body field coverage rules**: expected relationships from body content (e.g., every FR must be implemented by at least 1 task, every AC must be validated by at least 1 task via plan Acceptance mapping)
- **Constraint rules**: structural constraints (e.g., task Depends-on must be acyclic, no orphaned FRs)

The default ruleset enforces SDD best practices:
- Every FR-xxx in spec.md must have at least 1 task that implements it (via task body: `> Implements: [FR-xxx]`)
- Every AC-xxx in spec.md must have at least 1 task or plan phase that addresses it (via plan body: `> Acceptance: [AC-xxx]`)
- spec.md must derive from at least 1 BRIEF-*
- plan.md must derive from SPEC-* and/or RESEARCH-*
- No task should exist without implementing at least 1 FR (no untraceable work)

### Integration with Phase Gates

When `sdd check all <feature>` runs, it includes coverage results alongside structural readiness. Coverage gaps appear as informational items showing:
- Which specific FRs have no implementing tasks
- Which specific tasks don't implement any FR
- The current trace score (% of coverage rules met)

When `sdd review` scaffolds review.md, it includes a coverage summary prefilled from trace.json and the coverage report, enabling reviewers to see at a glance which requirements have task-level verification and which lack task coverage entirely.
