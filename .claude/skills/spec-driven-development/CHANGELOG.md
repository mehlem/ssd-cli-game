# Changelog

All notable changes to the SDD plugin are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) with feature IDs as version anchors.

Each release groups one or more closed features. **Added** sections explain new user-facing capabilities in 2-4 sentences plus 1-3 bullets; **Changed** notes behavioral modifications concisely; **Fixed** captures bug fixes in one line each. Internal hardening, refactoring, and code cleanup are intentionally omitted unless they have user-visible impact.

For the themed view of how features relate to each other, see [README.md](./README.md). For the canonical artifacts of any feature, see `.features/<id>/`.

## [Unreleased]

### Added

- **No silent task-start regression coverage** ([0072-no-silent-task-start]) — SDD now has disposable plan/cache/hook regression coverage proving tasks stay pending until `sdd task start` mutates them. The tests pin that state refresh keeps `.tasks.in_progress == 0` and heartbeat names ready work only alongside `0 active`; no production mutator was reproduced, so `sdd-task.sh` gate semantics remain unchanged.

- **Setup realignment** ([0067-sdd-setup-realignment]) — `sdd setup` now reflects the current plugin surface and can recover cleanly from partially bootstrapped consumer copies. The installer accepts `--canonical <path>`, writes a v3 CLAUDE.md managed block, adds `manifest_version: 2`, initializes SDD-managed `.gitignore` entries, refreshes `.features/INDEX.md`, and documents current post-install commands including lite/full mode, autonomy, customization, epics, advisor, and record-close.
  - Setup verification now checks the newer installed components: `sdd-record-close.sh`, `sdd-epic.sh`, `sdd-advise.sh`, `sdd-continuity-refresh.sh`, and `.claude/.sdd-version`.
  - The setup skill's install summary now names the agent pack, hook surfaces, manifest, CLI shim, managed CLAUDE.md block, and generated feature scaffold.

- **Iron laws across all 7 phases** ([0066-iron-laws-stage-0]) — Every phase guide now opens with an iron law that captures the load-bearing rule for that phase, surfaced in `<sdd_directives>` whenever the agent enters or works within the phase. Builds on the format validated by 0065 (single-line all-caps mandate + 2-3 sentence corollary + nudge-style trigger). Implement phase gets two iron laws — Task Verification (authoring quality, from 0065) and Task Completion (completion honesty) — at separate H2 sections; together they say "your verification must be a real test AND you must actually run it before claiming done."
  - **Brief**: `NO DESIGN, RESEARCH, OR CODE QUESTIONS IN THE BRIEF PHASE` — keeps the WHY/WHAT focus from drifting into HOW questions the codebase will answer for free.
  - **Design**: `NO IMPLEMENTATION DETAILS IN THE SPEC — WHAT, NOT HOW` — prevents file paths, function signatures, and algorithmic choices from smuggling into the spec contract.
  - **Research**: `NO PATTERN CLAIMS WITHOUT READING THE FILE FIRST` — every behavioral claim in research.md must cite a `file:line`; grep hits locate candidates, not patterns.
  - **Plan**: `NO TASK WITHOUT A RUNNABLE VERIFICATION COMMAND THAT PROVES BEHAVIOR` — companion to 0065's authoring iron law; rejects always-pass and "manually verify" placeholders at task-authoring time.
  - **Implement (Completion)**: `NO TASK COMPLETE WITHOUT THE VERIFICATION COMMAND PASSING` — distinguishes phantom completions (marking done before running) from authoring quality.
  - **Review**: `NO REVIEW VERDICT WITHOUT READING SPEC BEFORE CODE AND EVIDENCE FOR EVERY AC` — rejects the confirmation-bias failure mode (verifying what was built rather than what was required) and the implementer-self-review trap.
  - **Close**: `NO CLOSE WITHOUT VERDICT PASS AND AT LEAST ONE KNOWLEDGE GRADUATION (OR EXPLICIT EMPTY-KNOWLEDGE OPT-OUT)` — preserves the closing quality gate and prevents discoveries from being lost; explicit `closed_with_empty_knowledge: true` opt-out exists for legitimately empty cases.
  - **Anti-patterns subsections.** Five phase-specific Red Flags rows from `SKILL.md:113-128` are now also surfaced inline in the relevant phase doc as `### Anti-patterns` subsections (rows are *copied*, not moved — SKILL.md table stays as a quick-reference summary). Plan picks up "flexibility for future use cases"; Implement picks up "small code tweak", "I'll update artifacts after", "close enough to current scope", "I'll also improve adjacent code"; Review picks up "review can happen later".
  - **Mechanism-agnostic phrasing throughout.** Per the lesson from 0065, no `&&`-specific narrowing, no language-specific examples, no programming-language syntax. Iron laws apply identically in TypeScript, Python, Go, Rust, or any other repo using SDD.
  - **No script changes.** Existing `sdd_phase_guide()` injection (sdd-lib.sh:5614) surfaces the new content automatically on every SessionStart and phase transition. SKILL.md Phase Methodology table gains one sentence pointing at the iron laws as the entry point of each phase guide.

- **Iron Law of Task Verification** ([0065-task-verification-authoring]) — Phase docs now surface a language-agnostic iron law that rules out a class of authoring failure caught in the wild (feature 0064 T-001 chicken-and-egg case). The mandate `A TASK'S VERIFICATION COMMAND MUST DEPEND ON THIS TASK'S STATUS — FAIL BEFORE THE TASK IS DONE, PASS AFTER` lands in `references/phases/implement.md` (full + lite shared) and `references/phases/lite.md` (lite-mode Spec section), with mechanism-agnostic guidance covering `&&` chains, multiple test invocations, combined runners, and CI steps. The `templates/tasks.md` Verification placeholder is also tightened to lead with the same dependency rule. No script changes — the existing `sdd_phase_guide()` injection (sdd-lib.sh:5614) surfaces the iron law in `<sdd_directives>` on every SessionStart and phase transition.
  - **Iron-law shape, not prose.** Format follows superpowers convention (single-line all-caps mandate + 2-sentence corollary + redirect). Mechanism-agnostic so the rule transfers cleanly to TypeScript, Python, Go, Rust, or any other repo using SDD — `&&` is named only as one example among several chaining mechanisms, never as the named mechanism.
  - **One-phase preview of broader iron-laws Stage 0.** This is a focused lite feature scoped to the verification-authoring rule. The 7-phase Stage 0 plan (`.claude/scratchpads/sdd-iron-laws-deep-dive.md`) builds on the validated format to add iron laws to Brief, Design, Research, Plan, Review, and Close phases plus a second Implement iron law (completion honesty).
  - **Real-time validation of the rule.** While implementing T-004, the original verification chain `sdd setup && diff -q ... && grep ...` was itself an instance of the anti-pattern this feature documents — chaining a probe (`sdd setup` runs) with a regression-baseline-shaped probe (consumer copy matches canonical) where the first probe's pass/fail was independent of T-004's actual outcome. Recognizing it during execution and rewriting was the strongest possible end-to-end validation that the iron law surfaces useful guidance in practice.

- **Continuity & knowledge upkeep** ([0058-sdd-continuity-upkeep]) — Feature-level `.features/<id>/continuity.md` and `knowledge.md` files now stay maintained without agent burden. A new `sdd-continuity-refresh.sh` script auto-fills the mechanical `### Done / Now / Next / Working Set` sections inside a marker-fenced block (`<!-- SDD-AUTO-START --> ... <!-- SDD-AUTO-END -->`) within `## State`, regenerated only when current task or phase changes. Two new helpers `sdd_continuity_state` and `sdd_knowledge_state` in `sdd-lib.sh` classify each artifact as `empty | partial | filled` while excluding scaffolding from the count, and that single signal flows through five steering surfaces: UserPromptSubmit nudges (state × staleness, state dominates), the SessionStart inject (no longer treats placeholder content as authoritative state), the Stop hook (blocks turn-end with reason when implement/review continuity is empty with completed tasks), the close advisor (warns on empty knowledge unless `closed_with_empty_knowledge: true` is set in continuity frontmatter), and `sdd status` (⚠️/✅ markers). Phase guides for research/implement/close gain explicit imperatives naming the file paths.
  - **Auto-fence pattern** — `templates/continuity.md` ships with the fence pre-placed inside `## State`. First-run migration on existing features wraps any agent-authored State content. Outside-fence content is byte-identical pre/post any refresh; agent edits to Decisions/Reasoning State/Open Questions are inviolable. Idempotent: two consecutive runs produce zero diff.
  - **Calibrated thresholds** — Continuity emptiness uses `<100B → empty / 100–399B → partial / ≥400B → filled` after stripping frontmatter, headings, HTML-comment-only lines, and auto-fence content (AD-002, calibrated against 56-feature corpus). Knowledge emptiness counts K-entry lines in three accepted formats: `^- K-NNN:`, `^- **K-NNN`, `^### K-NNN:` (AD-001, broadens FR-006 to absorb 8 substantive features that use alternate forms). Both helpers default to `filled` on parse error or missing file (defensive).
  - **No new hook events, no new slash commands** — All five steering surfaces extend existing infrastructure (`sdd-hook.sh`, `sdd-stop-gate.sh`, `sdd-advisor-preboundary.sh`, `sdd-cache-refresh.sh`, `sdd-status.sh`). Scope discipline: source skills `.claude/skills/continuity` and `.claude/skills/knowledge` remain repo-level only; their SKILL.md is updated to drop aspirational feature-level routing claims, but their scripts (`cont-init.sh`, `kb-init.sh`) are untouched.
  - **Stop hook block-with-reason** — `sdd-stop-gate.sh` now blocks turn-end when phase ∈ {implement, review} AND continuity is empty AND `tasks.completed >= 1`, with reason interpolating feature path and completed count. Earlier phases pass through. The existing review-verdict block is preserved; new branch fires before it.
  - **SessionStart fix** — Replaces `[ -s continuity.md ]` size-check with `sdd_continuity_state != empty`. On empty, falls through to `build_summary` AND appends a directive instructing population — preserves task-id/phase signal while removing the false-context-from-placeholder failure mode.
  - **Spec-entry seeding** — `sdd-advisor-preboundary.sh` now seeds continuity Goal/Constraints from brief.md Motivation/Constraints (fallback `state.json.description.short`) at `Bash(sdd spec *)`, but only when the target sections still match HTML-comment placeholder pattern. Idempotent.
  - **Test surface grew by +489 assertions** across 6 suites (sdd-lib +172, sdd-continuity-refresh +12, sdd-hook +183, sdd-stop-gate +59, sdd-advisor +26, sdd-status +37). 7 new fixture files cover all classification branches including the autofence-only edge case.
  - **Dogfooded** — 0058's own continuity.md auto-fenced and classified `filled`; knowledge.md populated with 10 K-entries documenting non-obvious findings (source-skill divergence, auto-fence exclusion invariant, K-entry format triplet, threshold calibration, etc.). Both reviewers (sdd-spec-reviewer + sdd-quality-reviewer) returned PASS at 92/100; convergent finding (cold-start cache-refresh trigger lacks explicit unit assertion — code is correct, assertion unpinned) logged for minor follow-up.

- **Task Verification linting** ([0057-sdd-task-verification-linting]) — SDD now catches malformed or unsafe `tasks.md` Verification commands before `sdd task complete` executes them. Static linting is integrated into `sdd check tasks` and exposed as a focused `sdd task lint <feature>` preflight, with deterministic failures surfaced as hard errors and heuristic safety risks kept as warnings so `sdd close` remains usable.
  - Rules cover known SDD JSON contract mistakes such as `.error.status`, invalid Bash syntax, missing static shell scripts, placeholder/manual Verification commands, same-feature `sdd record-close --commit`, generic git commit risks, and lower-confidence live-feature lifecycle mutations.
  - JSON mode exposes structured lint findings (`rule`, `severity`, `task`, `message`, `suggestion`) under `data.lint` on success and `error.details.lint` on failure; the error envelope continues to use `error.type`.
  - `templates/tasks.md` and `references/phases/plan.md` now explicitly direct agents to use disposable fixtures, not the active feature or real git repo, when verifying mutating SDD lifecycle commands.

- **Reviewer dispatch discipline** ([0056-reviewer-dispatch-discipline]) — SDD now enforces independent review for non-trivial features. The review phase steering language moves from "prefer sdd-spec-reviewer and sdd-quality-reviewer" (advisory) to "dispatch sdd-spec-reviewer + sdd-quality-reviewer" (required for non-trivial features), with self-review allowed only for trivial diffs (≤2 ACs and ≤2 tasks). The autonomy-vs-dispatch conflict is resolved by baking dispatch *into* the autonomy rules string itself — `sdd_phase_rules review` autonomous variant now emits dispatch and "advance autonomously" on the same line, so neither overrides the other. Implementer self-review is named explicitly as the failure mode the review phase exists to prevent.
  - **Gate-level enforcement.** `sdd check review` emits an advisory warning when the feature has ≥3 ACs OR ≥5 tasks OR autonomous mode AND no `result-*.json` files exist for both `role: spec-reviewer` and `role: quality-reviewer`. `sdd-stop-gate.sh` escalates this to a soft-block when autonomous mode is on (with the same threshold). Lite-mode features short-circuit before detection. The `--self-reviewed` override flag, set via the new `sdd autonomy --self-reviewed <feature>` setter, writes `session_flags.self_reviewed_at` for sticky pass-through; `sdd reopen` clears the flag automatically.
  - **Cross-phase Opus 4.7 calibration.** `sdd-task.sh` (6 dispatch sites across `task next` and `task start`, both text and JSON modes) replaces conditional "for large tasks, dispatch sdd-implementer" with positive framing: "default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits." `sdd-research.sh` and `sdd-plan.sh` (cmd_plan only) gain new `Delegate:` lines naming `sdd-research-scout` and `sdd-plan-drafter` respectively.
  - **Doctrine surfaces aligned.** `references/phases/review.md` has a new `## Reviewer Dispatch Discipline` section. `references/autonomous-halts.md` documents `self_review_without_dispatch` as a soft-halt and notes that subagent dispatch is non-interactive under autonomy mode (autonomy means no per-phase user confirmation, not no tool calls). `references/workers.md` "When to Use Workers" review row is strengthened to MUST tier with the trivial-exception threshold. `SKILL.md` adds a fifth Non-Negotiable Boundary, "Independent review for non-trivial work."
  - **No new mechanism.** All detection uses the existing `workers/result-*.json` ledger from features 0010 + 0020 + 0036 — no new state-machine fields, no new hook events, no new CLI surfaces beyond `sdd autonomy --self-reviewed`. Three new helpers in `sdd-lib.sh`: `sdd_reviewer_dispatch_phrase` (canonical shared phrase), `sdd_reviewer_dispatch_present` (ledger detection), `sdd_review_dispatch_hint` (UserPromptSubmit cue). Test suites grew by +12 (sdd-lib-test 149→161; new fixtures in sdd-stop-gate-test and sdd-check-test).
  - **Dogfooded.** This feature's own review phase dispatched both `sdd-spec-reviewer` and `sdd-quality-reviewer`; both returned PASS, and the quality-reviewer surfaced a real defect (dead AC/task arithmetic in the stop-gate review branch) that was fixed inline before close.

- **Close commit traceability** ([0055-close-commit-traceability]) — Closed features now carry a deterministic, in-artifact pointer to the commit that sealed them. After `sdd close`, Claude is instructed (via `references/phases/close.md`) to ask the user, commit per a new documented convention, then run a new helper `sdd record-close <feature>` that captures `git rev-parse HEAD` and writes `close_commit:` (40-char SHA) and `closed_at:` (YYYY-MM-DD from git author date `%cs`) into the feature's `review.md` frontmatter atomically and idempotently. No hooks, no implicit auto-commits — the close commit is always an explicit user-approved action.
  - `sdd record-close <feature> [--commit] [--sha <sha>]` — idempotent SHA recorder; `--commit` produces an opt-in `chore(<id>): record close sha <short>` follow-up that stages only `review.md` via `git commit --only`; `--sha` overrides HEAD lookup for cases where HEAD has moved past the close commit.
  - `references/git-commits.md` — single source of truth for the close commit-message convention: `<type>(<feature-id>): <subject> (close)` with type/subject derivation rules and a body template (`Feature:` / `Verdict:` / `Tasks:` / `Refs:`).
  - `references/phases/close.md` extends the Process list with steps 8–10 (ask, commit, record) plus an Edge Cases subsection (no-git-repo, pre-commit hook fail, reopen → re-close).
  - `templates/review.md` documents `close_commit:` and `closed_at:` placeholder frontmatter fields.
  - `sdd-close.sh` post-success output (text and JSON, both normal-close and force-close paths) now includes a "Record:" guidance line and a `record_command` field in the JSON `data` block; `sdd close` itself remains free of git operations.
  - Lite-mode parity verified; backwards-compatible (existing closed features 0001–0054 carry no `close_commit:` and need no retroactive backfill).

- **Lean brief interview** ([0054-lean-brief-interview]) — Brief-phase posture shift from "interview to fill 5 sections" to "intent-extraction & drafting". Claude now gathers context first (CLAUDE.md, INDEX, scoped repo), proposes ideas or drafts inferable sections (Problem, Context, Constraints) from inspection rather than open questions, and asks only intent-level questions for Motivation and Vision. Soft cap of ~3 questions, each paired with a `**Recommended**:` line. Forbidden question types are explicit: research/plan-phase questions, code-logic questions, anything answerable by inspection. The `interview_complete` gate at all-5-sections is unchanged — lean behavior is delivered purely through directive language and documentation; future loosening (e.g., Context optional) is a deferred follow-up.
  - SessionStart full-mode hint and UserPromptSubmit compact cue both reinforce the new posture every turn.
  - `references/phases/brief.md`, `references/rubrics/brief.md` (Ambiguity resolution dimension), `docs/agent-steering.md`, `templates/brief.md` (now ships with inline lean instructions and a populated example Q&A), `scripts/sdd-init.sh` first-touch guidance, and `README.md` all updated to a single shared phrase set ("intent-extraction", "gather context", "propose", "soft cap ~3", "every question paired with a recommendation", "label inferred content").
  - Inferred Problem/Context/Constraints content must be labeled with `<!-- inferred from <source> -->` so the audit trail distinguishes user-stated from inferred content.

- **Lite profile** ([0050-sdd-lite-mode]) — Opt-in scaffold profile for bug fixes, single-area improvements, refactors without behavior change, perf tweaks, doc/config updates, and small additions to well-trod paths. Lite features run a 3-phase Spec → Implement → Review chain with three artifacts (`spec.md`, `tasks.md`, `review.md`) plus the working artifacts (scratchpad, continuity, knowledge, scope), skipping `brief.md`, `research.md`, `plan.md`, `trace.json`, and archive output. Behavioral core, hard gates (tasks-before-code, review verdict, scope discipline), AC numbering, and post-compact recovery are unchanged across profiles. Full mode behavior is unchanged except for an additive optional `## Approach` section in the `tasks.md` template.
  - `sdd init <name> --mode lite|full "<desc>"`; omitted flag defaults to `full`. Claude picks the mode at scaffold time using a rubric in SKILL.md and announces the choice in one short line.
  - Profile is stored in `state.json.profile`; missing values default to `full` so existing features need no migration.
  - New surfaces: `references/profiles.md`, `references/phases/lite.md`, `templates/spec-lite.md`, SKILL.md "Mode Selection" section.
  - `sdd status` and `sdd handoff` surface the active profile in human and JSON output.
  - `sdd-spec.sh`, `sdd-research.sh`, `sdd-plan.sh`, and `sdd-archive.sh` refuse to operate on lite features with a clear "not applicable in lite mode" message.

### Changed

- ([0074-red-test-verification-guidance]) Clarified task Verification guidance so red-test-only tasks pass when expected failure evidence is observed, while implementation tasks own final green suites and no task depends on a future task's green state.
- Normal `sdd close` now requires a successful `sdd check all <feature>` readiness pass in addition to `review.md` verdict/evidence gates before artifact statuses are marked completed. Force-close behavior remains administrative and unchanged.
- ([0050-sdd-lite-mode]) Trace-aware consumers (`sdd-task.sh` suspect gate, `sdd-cache-refresh.sh` trace-ensure on artifact edits) now skip trace machinery for lite features, since lite opts out of `trace.json` scaffolding.

### Fixed

- ([0087-sdd-lite-lifecycle-status-alignment]) Lite phase/status now derive readiness from populated lite artifacts instead of stale draft frontmatter, and review AC row counts stay aligned when table cells contain pipe characters.
- ([0073-research-affected-files-schema]) Affected Files schema handling now filters parser rows by the column-2 Action enum, rejects actionless tables with the canonical schema hint, and documents the research-scout `files_discovered[]` machine shape.
- ([0070-json-literal-boolean-roundtrip]) `sdd_json_literal false` and `sdd_set_session_flag <flag> false` now preserve JSON boolean values instead of string-encoding `"false"`.
- ([0069-reviewer-foreground-ledger-recovery]) Foreground `sdd-spec-reviewer` and `sdd-quality-reviewer` results now persist to the workers ledger even when Claude Code does not deliver a `SubagentStart` dispatch sidecar; recovered dispatch/result records are explicitly marked, and non-reviewer or mismatched-identity stops still block.
- ([0069-reviewer-foreground-ledger-recovery]) The Agent guard now reads current Claude Code `subagent_type` tool input while preserving the legacy `agent_type` fallback, so prompts containing manual Machine Dispatch Records are blocked before dispatch.
- ([0068-frontmatter-inline-comments]) `sdd close` and phase detection now accept YAML-style inline comments on simple review frontmatter values such as `verdict: pass  # rationale`.
- ([0067-sdd-setup-realignment]) `sdd setup` no longer fails opaquely when the consumer copy is missing `agents/`; it resolves canonical sources via `--canonical`, `CLAUDE_PLUGIN_ROOT`, or `<repo-root>/sdd-plugin`, then prints an actionable recovery command if none are reachable.
- ([0067-sdd-setup-realignment]) Re-running setup now prunes SDD-owned hook entries before merging canonical hooks, so stale partial advisor blocks are fully refreshed without touching user hooks.
- ([0067-sdd-setup-realignment]) User-modified `sdd-*.md` agent files are backed up under project-root `.sdd-local-patches/<UTC-timestamp>/...` before overwrite, including first-install cases without a prior manifest.
- ([0067-sdd-setup-realignment]) Consumer skill copies no longer include development-only `scripts/tests/`.
- ([0061-sdd-shared-id-parser]) `sdd check spec`, `sdd check plan`, and trace extraction now share a colon-anchored ID parser, so bold-prefixed FR/AC/AD/OQ declarations and compound `Addresses` / `Acceptance` plan lines no longer produce false gate or trace failures.
- ([0051-lite-tasks-stale-frontmatter]) Lite-scaffolded `tasks.md` frontmatter now sets `source: SPEC-<num>` and `links.derived_from: ["SPEC-<num>"]` instead of the dangling `PLAN-<num>` references inherited from the full-mode template. Full-mode behavior unchanged. First lite-mode dogfood feature.
- ([0052-trace-rules-profile-aware]) Trace coverage no longer reports `artifact.spec.derived_from`, `artifact.tasks.derived_from`, `plan.Addresses`, and `plan.Acceptance` as failures on lite features — these rules assume full-mode artifacts and are now skipped when the active feature has `profile: lite`. `trace-rules.json` schema bumped to v2 with an optional `"profile"` field per rule (default behavior when absent: applies to all profiles, fully backward-compatible). Lite trace scores now reflect only applicable rules. Full-mode behavior unchanged.
- ([0053-lite-steering-alignment]) Steering surfaces (Pitfall, Next, Avoid, maintenance-hint, phase-rules, next-move, init IDs line, summary process pointer) now emit lite-aware text on lite features instead of suggesting `research.md`, "Ready for Research", or full-only artifact IDs. `sdd_phase_rules` and `sdd_next_move` gain a `spec)` clause so lite's first phase has structured guidance. `sdd_maintenance_hints` accepts an optional profile arg and defaults to full when omitted (backward-compatible). Full-mode behavior unchanged.

- Scope-drift warnings now recognize deterministic one-group brace-list entries such as `src/{main,helper}.ts` in both `scope.txt` and `task-scope.txt`, avoiding false warnings without adding broad glob semantics.
- `sdd status` with no arguments no longer fails under `set -u` on an empty parsed-argument array.

## [2026-04-29]

### Added

- **Autonomous mode** ([0047-sdd-autonomous-mode]) — Opt-in per-feature mode that lets Claude advance design → close without per-phase confirmation pauses. Activation is conversational at brief-end, persisted in `state.json`, and honors mechanical halt conditions only (suspect artifacts, repeated tool failure, verification failure, genuine intent ambiguity). Default behavior is unchanged for features that don't opt in.
  - New `sdd autonomy on|off|status` subcommand
  - Halt vocabulary mirrors existing `Uncertain / Inspect / Next / Avoid` form
  - Brief interview remains interactive; reviewer agents stay ignorant of the flag

- **Context freshness nudges** ([0048-sdd-context-freshness-guard]) — Extends the existing scratchpad staleness counter to also track `continuity.md` (threshold 5 tool calls) and `knowledge.md` (threshold 10). One nudge per turn, priority-ordered, so compaction recovery resumes from a current picture and discoveries graduate before they're buried.

### Changed

- ([0049-sdd-docs-sync]) Plugin documentation synced with features 0032-0046: new reference files for trace coverage, trace acknowledge, customization, and hook architecture; CLI contract command tables completed; `/sdd-help` routing corrected for rubric advisor, trace acknowledge, and project customization; brief.md template now produces the `## Short Description` / `## Long Description` sections scaffolding expects.

## [2026-04-28]

### Added

- **Project customization layer** ([0045-sdd-project-customization]) — `.sdd/customization.yaml` (and optional `.features/<id>/customization.yaml`) inject scope-tagged guidance bullets into hook emissions and subagent dispatch packets. 15 known scope keys, 4 interpolation tokens, append-only semantics so user content never replaces canonical plugin output. Zero per-turn token cost in repos that don't customize.
  - `sdd customize init` scaffolds the file with inline-commented scope keys
  - `sdd customize check` validates schema and surfaces unknown keys
  - Subagents receive scope-targeted guidance in dispatch packets without re-priming
- **Active-feature audit ledger** ([0044-sdd-state-stability]) — `.features/.active.log` is an append-only ledger recording every active-pin change (timestamp, previous feature, new feature, source). Pairs with a 22-test predicate suite (`tests/sdd-active-feature-test.sh`) that locks in the durability contract end-to-end across SessionStart, PreCompact, PostCompact, InstructionsLoaded, and Stop hooks.

### Changed

- ([0046-sdd-skill-scoped-hooks]) Plugin is now silent by default in non-SDD sessions. All 14 hook scripts self-gate via the new public predicate `sdd_has_active_feature` (composes phase ≠ close + continuity status ∉ {completed, abandoned, superseded}). Architecture decision recorded: hooks remain plugin-level; skill-frontmatter `hooks:` is ruled out because of [GH#40630](https://github.com/anthropics/claude-code/issues/40630) (subagent forwarding bug).

### Fixed

- ([0044-sdd-state-stability]) Stale `.claude/tmp/sdd-state-cache.json` no longer leaks a previous session's `last_phase` into `sdd_detect_feature_phase`. Cache is now gated by an `.active`-freshness check, so hooks read accurate phase state for the operator's currently-pinned feature.

## [2026-04-27]

### Added

- **`sdd trace acknowledge`** ([0043-sdd-trace-acknowledge]) — New disciplined path for clearing trace-suspect flags after the operator has verified that an upstream artifact change is incorporated downstream. Restamps `based_on` hashes and records a structured entry in `.features/<id>/changes.log`. Replaces the `--force` reflex on `sdd task start` with an audit-trailed alternative.
  - `sdd trace acknowledge <feature> [<ARTIFACT-ID>…] --confirmed [--reason <text>]`
  - Mandatory `--confirmed` guard prints what would change before writing
- **Windows support** ([0042-sdd-windows-compat]) — The plugin works out-of-the-box on Windows + Git Bash + jq 1.7.x. CRLF normalization across the 799 jq call sites, flat install layout (no nested `spec-driven-development/spec-driven-development/`), Defender-retry on `sdd setup`, and an opt-in `sdd setup --install-shim` walk-up wrapper that puts `sdd` on PATH. Windows CI now blocks merges that regress portability.
  - macOS / Linux behavior unchanged
  - Scope-drift hook no longer fires on edits inside the active feature's own artifacts during implement phase

### Fixed

- ([0041-sdd-indexing-performance]) `sdd_task_summary_cheap` removes graph-storm from hot hook paths; `sdd-hook.sh` UserPromptSubmit and `sdd-trace.sh ensure` now complete in <100ms and <1s respectively, and `sdd index rebuild` dropped from ~66s to <5s on a 40+ feature repo.
- ([0043-sdd-trace-acknowledge]) `SKILL.md:191` no longer claims `sdd trace refresh` resolves suspect (it never did) — points at `sdd trace acknowledge` instead.

## [2026-04-17]

### Added

- **Rubric advisor** ([0040-sdd-rubric-advisor]) — Lightweight Haiku-backed advisor that surfaces grounded, non-blocking suggestions when artifact content drifts from documented conventions. Two narrow hooks (pre-boundary and post-authoring) shell to `claude -p --bare --model haiku` against rubric files at `references/rubrics/*.md`, plus an on-demand CLI for mid-phase checkups. Never blocks, never persists, never scores; bounded to ~$0.06 per feature lifecycle.
  - `sdd advise <artifact> <feature>` for manual evaluation
  - `SDD_ADVISOR_DISABLED=1` kill switch
  - Legacy 0–100 `sdd semantic` infrastructure retired in favor of this simpler model

## [2026-04-16]

### Added

- **Steering coherence sweep** ([0038-sdd-steering-coherence-hardening]) — A unified behavioral core (surface ambiguity, ground claims in inspected code, prefer the smallest viable change, treat done as verified evidence) now appears consistently across hooks, CLI guidance, templates, worker prompts, summaries, setup output, archive docs, rubrics, and evals. Authored the six rubric files at `references/rubrics/*.md` that the advisor (0040) later consumes.

### Changed

- ([0037-json-stderr-guidance]) SDD CLI commands running under `--json` now emit human-readable steering (Boundary / Gate / Pitfall / phase references) to stderr, so Claude still sees per-command guidance even when stdout is piped through `jq`. JSON envelope on stdout is unchanged; internal cache-refresh calls (already silenced) are unaffected.

## [Pre-history] — through 2026-04-15

Features 0001–0036 established the SDD lifecycle and the production-grade harness around it. Themed view (full provenance under `.features/`):

- **Workflow foundations** ([0001-sdd-agent-harness], [0002-sdd-work-packages], [0003-sdd-markdown-hardening], [0004-sdd-plugin-conversion], [0005-sdd-agent-steering], [0006-sdd-feature-selection]) — Core phase lifecycle, work-package decomposition, artifact chain, feature initialization, phase detection, multi-phase coordination, feature selection via `sdd select`.
- **Artifacts & continuity** ([0003-sdd-markdown-hardening], [0007-sdd-markdown-summary], [0012-sdd-confidence-and-artifact-refresh], [0013-sdd-postcompact-and-handoff], [0014-sdd-verified-review-rigor]) — Markdown reliability, summary generation, confidence scoring, context preservation across compaction, review rigor validation.
- **Evaluation framework** ([0008-sdd-eval-framework], [0009-sdd-eval-hardening], [0015-sdd-description-optimization]) — Behavioral evals, fixture hardening, trigger-based testing, LLM grader patterns.
- **Subagent workers** ([0010-sdd-claude-code-subagent-workers], [0011-sdd-agent-role-pack], [0020-sdd-subagent-dispatch], [0023-sdd-typed-worker-contracts], [0036-sdd-worker-orchestration-hardening]) — Claude Code subagent integration, typed worker contracts, dispatch packets, result validation hooks, bounded SubagentStop revalidation, batched validation failure reporting.
- **Agent steering** ([0005-sdd-agent-steering], [0016-sdd-phase-aware-injection], [0019-sdd-steering-hardening], [0021-sdd-cli-steering], [0035-brief-phase-steering]) — Phase-aware hook infrastructure, context injection, 25+ lifecycle event coverage, brief-phase interview tracking with per-turn cues.
- **Agent-first CLI** ([0022-sdd-agent-first-cli]) — Deterministic machine path with `--json`, `--feature auto`, `--non-interactive`, semantic exit codes (0/2/3/4/5/6/7), and read selectors.
- **Quality gates** ([0024-sdd-semantic-phase-gates], [0025-sdd-review-adjudication]) — Semantic phase gates (content-aware readiness checks), evidence-backed review adjudication with machine-checkable verdict.
- **Task management** ([0026-sdd-task-dependency-graph]) — Dependency graph with cycle detection; `sdd task next` respects execution order constraints.
- **Feature lifecycle** ([0028-sdd-feature-archive-docs], [0031-feature-index], [0032-sdd-auto-setup], [0034-feature-description-metadata]) — Auto-generated archive docs per closed feature, persistent INDEX.md at `.features/`, canonical description metadata, `sdd setup` command to bootstrap SDD into any project.
- **Trace & provenance** ([0030-sdd-trace-graph], [0033-sdd-trace-coverage-rules]) — `trace.json` typed dependency graph linking artifacts → requirements → tasks → code; suspect propagation on upstream changes; coverage rules manifest with PASS/FAIL/SKIP rule taxonomy.
- **Codebase hardening** ([0004-sdd-plugin-conversion], [0017-sdd-codebase-hardening], [0018-sdd-skill-progressive-disclosure], [0027-sdd-bash-hardening], [0029-sdd-references-consolidation]) — Plugin architecture, error handling, dead code removal, data consistency, progressive disclosure, Bash safety hardening, references reorganization.
