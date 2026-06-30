---
name: spec-driven-development
description: >-
  Use when starting feature work, resuming work tracked in .features/, or making
  changes that must follow the SDD artifact chain, phase gates, and verification
  workflow. Activates on: "implement feature", "add feature", "start building",
  "resume work", "what's next", or any task referencing .features/ directories.
when_to_use: >-
  This skill should be used when the user asks to start or resume feature work,
  implement any change that touches spec/plan/tasks/review, references
  .features/ directories, or requests multi-step work that needs verification —
  even if they don't explicitly mention SDD, phases, or artifacts. Trigger on
  "let's build X", "what's next on this feature", "is this done", "resume
  work", or any implied multi-step workflow with acceptance criteria.
argument-hint: "[feature description or feature-id to resume]"
allowed-tools: Bash(sdd *) Bash(bash *sdd*.sh *) Read Glob Grep
compatibility: Requires bash 3.2+, jq, git. SDD scripts must be on PATH or invoked via plugin.
---

# Spec-Driven Development

## Purpose

SDD is a seven-phase methodology (Brief → Design → Research → Plan → Implement → Review → Close) that keeps feature work grounded in explicit artifacts rather than model memory. Each phase produces a durable artifact the next phase consumes, making intent, decisions, and evidence traceable end-to-end — from requirement (FR-001) through plan, task, changed files, and review verdict.

This skill enforces the phase gates, behavioral core, CLI, and verification contracts that prevent common LLM failure modes: silent scope expansion, phantom completions, drift between what was asked and what was built, and lost context across sessions. Without it, Claude builds the wrong thing confidently; with it, Claude operates as a grounded author of machine-checkable artifacts.

## The Golden Circle

Write it down before you build it: understand WHY before you define WHAT.
`WHY → WHAT → WHERE → HOW → DO → VERIFY → DONE`
`brief.md → spec.md → research.md → plan.md → tasks.md → review.md → close`

## Behavioral Core

Across all phases, SDD steers Claude toward the same six behaviors (canonical source: [references/steering-core.md](references/steering-core.md)):

- **Surface ambiguity**: State assumptions. If ambiguity changes behavior, scope, or verification, clarify or return `NEEDS_CONTEXT` instead of guessing silently.
  - If a simpler or better path exists than what was requested, propose it before building. Disagreement is cheaper than rework.
- **Investigate before claiming**: Read the relevant artifact or code before making behavioral, architectural, or review claims. Label anything unverified as a hypothesis.
- **Prefer the smallest viable solution**: Solve the requested problem with the least added mechanism. Defer abstraction, configurability, and "future-proofing" until current requirements justify them.
  - No features beyond what was asked.
  - No abstractions for single-use code.
  - No error handling for impossible scenarios.
  - Senior engineer test: if it looks overcomplicated, simplify.
- **Change surgically**: Keep edits traceable to the active task or request. Match local style and avoid drive-by cleanup unless your change created the orphan.
  - Match existing style even when you disagree with it.
  - Notice unrelated dead code or style issues; mention them, do not fix them without being asked.
  - Remove only orphans your change created; leave pre-existing dead code alone.
- **Treat done as verified evidence**: Completion means the verification command passed or the cited evidence exists. Writing code is not the definition of done.
- **Reason through failures before retrying**: When a tool or gate fails, name what is uncertain, inspect the relevant output or artifact, then choose the safest next move.

## Mode Selection

At scaffold time choose `lite`, `normal`, or `deep`, announce the choice in one short line, and proceed when the signal is clear.
- Use `lite` for bug fixes, single-area improvements, no-behavior refactors, perf tweaks, docs/config updates, and small additions to well-trod paths.
- Use `normal` for net-new user-facing behavior, multi-component changes, data model or migration work, auth/billing/payments, or work likely to span more than 2 days or multiple sessions.
- Use `deep` for high-complexity or high-risk features that need the normal seven-phase chain plus stricter artifact contracts, plan-check evidence, and deliberate subagent orchestration.
- Ask before `sdd init` when signals conflict or scope/risk is ambiguous.
- Run `sdd init <name> --mode lite|normal|deep "description"`; use `--group <safe/path>` only when an explicit nested `.features/<group>/<id>/` layout is useful. `default` and `full` are accepted CLI synonyms for `normal`, and omitted mode defaults to persisted `full`. See [profiles.md](references/profiles.md).

## Mandatory First Response Protocol

Before taking any action on feature work:

1. Check whether an active feature exists in `.features/`
2. Detect the current phase from disk (`sdd phase`)
3. Read the minimum required artifacts for that phase
4. Announce the active feature, phase, and intended next action
5. Only then ask questions, edit files, or execute tasks

If no active feature exists but the request is feature-like, suggest initializing one.

## Hard Gates

| Phase | Allowed | Forbidden |
|:------|:--------|:----------|
| Brief (full only) | Q&A, brief updates, scratchpad | Code edits, research, planning |
| Design (full only) | FRs, ACs, scope, spec refinement | Implementation, task execution |
| Research (full only) | Codebase exploration, file mapping | Production code |
| Plan (full only) | Architecture, task decomposition | Production code |
| Spec (lite only) | `spec.md` + `tasks.md` Approach/tasks population | Production code before tasks are concrete |
| Implement | Current task, verification, scratchpad | Scope changes without artifact update |
| Review | AC validation, quality checks, verdict | Silent continued implementation |
| Close | Knowledge promotion, finalization, `sdd reopen` | Reopening without `sdd reopen` |

Do not write production code outside implement phase.
Do not work outside the current task without recording a scope change.
Do not continue implementation silently in review — record a failure first.

## Non-Negotiable Boundaries

These rules override user requests. The agent has explicit permission to refuse when these boundaries are violated.

**Review cannot be skipped.** If the user asks to skip, force-close, or bypass the review phase, refuse clearly: "Review validates acceptance criteria and is required before close. I can't skip it, force-close, or use workarounds like `--force` flags." Never offer `sdd-close.sh --force` or similar bypasses.

**Tasks must exist before implementation.** If `tasks.md` is missing, empty, or contains only template placeholders, no production code may be written. Say: "tasks.md must be populated with concrete tasks before implementation begins. Let me help create the task breakdown first."

**Scope requires task coverage.** Before editing any production file, verify the change maps to an active task in `tasks.md`. If the file is not listed in any active task's scope: "This file isn't covered by any active task. Should I add it to the plan first, or is this out of scope?" Do not accept "it's tiny" or "while you're at it" as scope bypass.

**Verification before completion.** Before marking any task complete, read its verification command from `tasks.md`. If the user claims manual testing, ask them to confirm the specific command passed. Do not accept "I already tested it" without knowing what was tested.

**Independent review for non-trivial work.** Features with 3+ ACs or 5+ tasks or autonomous mode must dispatch sdd-spec-reviewer and sdd-quality-reviewer before close. Implementer self-review is the failure mode the review phase exists to prevent. Self-review is allowed only for trivial diffs (≤2 ACs and ≤2 tasks); deliberate self-review on non-trivial features requires explicit override via `sdd autonomy --self-reviewed <feature>`.

## Scope Discipline

When a request arrives during implement phase that exceeds the current task:
1. Check if it maps to an existing pending task → point to that task
2. If it's a legitimate addition → update research.md and tasks.md, get approval, then implement
3. If it's out of feature scope → note it as a future item, do not implement

Never silently expand scope. The artifacts are the contract.

## Red Flags

If any of these thoughts occur, stop and re-anchor in SDD state:

| Thought | Reality |
|:--------|:--------|
| "I can just answer quickly first" | Read active feature state first |
| "This is probably unrelated" | Check `.features/` before assuming |
| "I know what phase we're in" | Read from disk, not memory |
| "This is a small code tweak" | Small tweaks still need task alignment |
| "I'll update artifacts after" | That is how drift starts |
| "Review can happen later" | Review is a phase, not optional cleanup |
| "Close enough to current scope" | Map to task or record scope change |
| "I'll also improve this adjacent code" | Drive-by refactoring. Mention it; don't fix it. |
| "Let me add flexibility for future use cases" | Speculative. One use-case, one function. |

## Priority Order

When SDD is active: 1) User instructions 2) Phase hard gates 3) Current task 4) Supporting disciplines (TDD, continuity) 5) General preferences

## Worker Mode

Workers are Claude Code subagents dispatched with an explicit assignment packet.
**Authority**: Dispatch packets override hook context for conflicting assignment fields (feature, phase, task).
**Artifact Ownership**: SAFE (worker does directly): scratchpad observations, `sdd task complete` for assigned task. SUGGESTED (worker returns suggestion): new tasks, research updates, knowledge entries. FORBIDDEN (controller only): spec, plan, brief, phase transitions, other tasks' status.
**Worker Prohibitions**: Do not restart the SDD lifecycle. Do not infer conflicting assignment from disk when explicit dispatch is provided. Do not expand scope without controller approval. Do not modify forbidden artifacts.
**Automated Dispatch**: SubagentStart injects typed packets (`dispatch_id`, `schema_version`, role, feature, phase); SubagentStop validates results in two tiers (blocking + non-blocking) with bounded retry.
See [workers.md](references/workers.md) for the dispatch guide and schema,
[worker-results.md](references/worker-results.md) for the return contract,
and [agents/](agents/README.md) for ready-to-use role definitions.

## Artifact Chain

```text
.features/[group/.../]####-name/
├── brief.md          Brief     → WHY (full only: motivation, vision, Q&A record)
├── spec.md           Design    → WHAT (full) / Spec (lite)
├── research.md       Research  → WHERE (full only: codebase map, affected files, patterns)
├── plan.md           Plan      → HOW (full only: architecture, vertical slices)
├── tasks.md          Plan      → DO (full) / Spec → Implement (lite Approach + tasks)
├── review.md         Review    → VERIFY (AC validation, code quality)
└── scratchpad.md     Support   → working memory (throughout)
```

### Derived Artifacts

Hooks and scripts generate these alongside the canonical chain:

| File | Managed by | Purpose |
|:-----|:-----------|:--------|
| `summary.md` | PostToolUse hook | Full feature briefing (phase, progress, rules) |
| `summary-compact.md` | PostToolUse hook | Minimal 10-15 line briefing for compaction recovery |
| `trace.json` | `sdd trace` | Typed provenance graph (artifacts → tasks → files) |
| `continuity.md` | PreCompact hook | Pre-compaction snapshot for resumption |
| `knowledge.md` | Close phase | Graduated findings from scratchpad |
| `workers/` | SubagentStart/Stop | Dispatch/result JSON sidecars (when delegating) |
| `.features/INDEX.md` | `sdd index` | Feature registry at the `.features/` root |

Do not edit derived artifacts directly. Regenerate via the owning command.

Feature identity is the basename ID (`####-name`). Feature path is the storage path relative to `.features`; grouped features store that path in `.features/.active` and expose it through additive JSON fields such as `feature_path`, `feature_dir`, and `feature_group`. Flat features keep `feature_path == feature`. Group folders are containers only, `wp-*` folders are work-package children only, and root epic v1 remains `.features/EPIC.md`.

## Phase Detection

Determine the current phase by checking which files exist:

| Condition | Phase |
|:----------|:------|
| `profile: full`; no `brief.md` | **Brief** |
| `profile: full`; `brief.md` exists, no `spec.md` | **Design** |
| `profile: full`; `spec.md` exists, no `research.md` | **Research** |
| `profile: full`; `research.md` exists, no `plan.md` | **Plan** (strategy) |
| `profile: full`; `plan.md` exists, no `tasks.md` | **Plan** (task breakdown) |
| `profile: lite`; `spec.md` or `tasks.md` not ready | **Spec** |
| `tasks.md` has unchecked items | **Implement** |
| All tasks done, no passing `review.md` | **Review** |
| `review.md` with `verdict: pass` | **Close** |

### Phase Enforcement

After detecting the current phase, enforce it actively:

- **Brief phase** (no spec.md): Only Q&A and brief.md updates. If asked to write code or design: "We're in the Brief phase — I need to understand the motivation first. Let me ask a few questions before we define requirements."
- **Research phase** (spec.md exists, research.md empty/template): Only codebase exploration and research.md population. If asked to write code: "We're in the Research phase — mapping affected files and patterns. No code until the plan is in place."
- **Review phase** (review.md exists, verdict pending): Only AC validation. If a bug is found: "We're in Review. I'll record this finding in review.md. To fix it, we need to return to Implement explicitly."
- **Close phase** (verdict pass): Only knowledge promotion and finalization. If asked to add scope: "This feature is closed. A new feature request should go through `sdd init`."

### Task Execution Gates

Before starting any task, `sdd task start` enforces two gates:

- **Dependency gate**: blocks if any `Depends-on:` prerequisite task is incomplete. Resolve by completing the prerequisite, or — for legitimate out-of-order work — pass `--force` and record the reason in the scratchpad.
- **Trace suspect gate**: blocks if the task or its upstream artifacts are marked `suspect` (upstream changed after derivation). Resolve with `sdd trace acknowledge <feature> --confirmed` after verifying the upstream change is incorporated. Refresh re-evaluates trace.json but does not clear suspect; acknowledge restamps `based_on` and clears suspect. Do not reach for `--force` on the suspect gate — re-ground first.

`sdd task next` respects the dependency graph and only surfaces ready tasks.

### Goal Transformation

Translate imperative requests into verifiable goals before executing:

| Imperative | Verifiable Goal |
|:-----------|:----------------|
| "Add validation" | Write tests for invalid inputs; make them pass |
| "Fix the bug" | Write a test that reproduces it; make it pass |
| "Refactor X" | Tests pass before and after; no new failures |

Strong success criteria let implementation loop to completion without re-prompting. Weak criteria ("make it work") require clarification mid-flight.

### Validation Loop

Before marking the final task of a phase complete, run `sdd check all <feature>` (dependencies, trace coverage, and the rubric advisor (`sdd advise`)). Fix violations before progressing; do not defer validation to Review.

### Review Discipline

- Read the spec BEFORE reading the code (form expectations, then verify)
- Do not trust completion claims without running verification
- Do not skip review because "the code is simple"
- Evidence means: ran it, saw the output, can cite the result
- Flag unrequested work, overbuilding, and missing evidence explicitly
- "Review can wait" is the #1 red flag for drift

### Approval Boundaries

Present to user and get explicit confirmation at these transition points:
- After spec/design → before research
- After plan/tasks → before implement
- After review verdict: pass → before close

## Phase Methodology

Each phase has a detailed guide with process steps, strategy hints, and exit criteria.
Load the relevant guide when entering a phase:

| Phase | Guide | Load when... |
|:------|:------|:-------------|
| Brief | [brief.md](references/phases/brief.md) | Starting new feature, conducting Q&A for brief.md |
| Design | [design.md](references/phases/design.md) | Writing requirements and ACs in spec.md |
| Research | [research.md](references/phases/research.md) | Mapping codebase — use Explore subagent for parallel scanning |
| Plan | [plan.md](references/phases/plan.md) | Writing architecture decisions, deriving tasks |
| Implement | [implement.md](references/phases/implement.md) | Building tasks — one at a time, TDD when applicable |
| Review | [review.md](references/phases/review.md) | Validating acceptance criteria with evidence |
| Close | [close.md](references/phases/close.md) | Graduating knowledge, finalizing artifacts |

The main `spec-driven-development` skill remains the router and enforcement
anchor for all phases. Phase skills are additive, phase-local guidance loaded
when the active phase needs sharper procedure:

Fact claims do not create a new phase, `.facts` workflow, facts CLI dependency,
semantic sidecar, or enforcement subsystem. They are artifact-local evidence
labels; the main router, phase skills, CLI scripts, hooks, trace/task/review
gates, and Knowledge workflow remain authoritative.

| Phase/profile | Phase skill |
|:--------------|:------------|
| Full Brief | `/sdd-brief` |
| Full Design / lite Spec | `/sdd-spec` |
| Full Research | `/sdd-research` |
| Full Plan | `/sdd-plan` |
| Full or lite Implement | `/sdd-implement` |
| Full or lite Review | `/sdd-review` |
| Full or lite Close | `/sdd-close` |

Review routes to `/sdd-review`, never `/sdd-research`. These phase skills do
not replace phase detection, hard gates, artifact contracts, approval
boundaries, or plugin-level hooks.

Phase skills are guidance wrappers, and invoking the required one is also a
protected-action routing latch. Before editing the active phase artifact or
running a protected SDD boundary command, invoke the required phase skill for
the current phase. For the latch, direct reads of `SKILL.md`, phase reference markdown, or artifact files do not satisfy the latch; only an observed phase-skill
invocation does. The latch proves routing through the right phase guidance, not
artifact correctness. Existing SDD gates, checks, hooks, and review evidence
still validate correctness.

Each phase skill declares `when_to_use` trigger guidance and carries the same
compact contract: Phase Goal & Context, Relevant Commands, Preconditions, First
Actions, Output Contract, and Return / Failure Protocol. The command list is a
short phase-local shortlist, not a replacement for the CLI reference.

Close finalizes artifacts. The close commit and SHA recording are explicit agent steps; see [close.md](references/phases/close.md) and [git-commits.md](references/git-commits.md) for the commit + `sdd record-close` flow.

The SessionStart hook automatically injects the current phase guide into context.
These files are also available for on-demand reference during any phase.

Each phase guide opens with an iron law that captures the load-bearing rule for that phase (e.g., `NO TASK COMPLETE WITHOUT THE VERIFICATION COMMAND PASSING` for Implement, `NO REVIEW VERDICT WITHOUT READING SPEC BEFORE CODE` for Review). The full mandates and corollaries live in the phase guides themselves; the table above is the entry point.

## Work Packages

For features with 15+ tasks or independent subsystems, use work packages (WP mode).
WP mode activates by convention: create `wp-NN-name/` subdirectories inside the feature.
See the Work Packages section in [artifacts.md](references/artifacts.md) for the full guide.

## Epic

For large initiatives that span multiple normal SDD features, use the epic layer: create `.features/EPIC.md` with `sdd epic init`, add entries, then scaffold or link features from those entries. Epics provide bounded program context, derived progress, and trace-backed drift review without changing the normal feature lifecycle; see [epic.md](references/epic.md) for schema, commands, slicing rules, and drift handling.

## Supporting Artifacts

- `scratchpad.md` is working memory throughout the feature lifecycle.
- Record observations there during execution and graduate durable findings at Close.
- Promote non-obvious discoveries to `KNOWLEDGE.md`.

## Project Customization

Use `sdd customize init` to create `.sdd/customization.yaml` (project-level, committed) with 15 scope-keyed `notes` lists. Each key holds guidance bullets for a context: `global` (always), the 7 phases (`brief/design/research/plan/implement/review/close`), the 6 subagent roles (`research-scout/plan-drafter/implementer/spec-reviewer/quality-reviewer/archivist`), and `learned` (discoveries Claude captures mid-feature). Edit the YAML directly in any text editor. Run `sdd customize check .sdd/customization.yaml` to validate schema conformance: per-bullet ≤280 chars, per-key ≤50 bullets, file ≤8 KB, and known scope keys. Unknown `{{...}}` tokens warn non-fatally. Variable interpolation supports 4 tokens at render time: `{{FEATURE}}` (active feature ID), `{{FEATURE_ID}}` (numeric prefix), `{{PHASE}}` (phase name), `{{DATE}}` (UTC date YYYY-MM-DD). Optional feature-level customization at `.features/<id>/customization.yaml` (gitignored by default) uses the same schema and merges with project bullets. Plugin injects relevant scope slices into SessionStart context, subagent dispatch packets, and persists `notes.learned` across compaction via continuity.md recovery.

## Session Continuity

Session state survives compaction and handoff via hook-managed artifacts. Do not reconstruct state by re-reading every artifact — the derived briefings exist for this purpose.

- **PostCompact recovery**: read `summary-compact.md` first (smallest, most durable), then `continuity.md`, then `state.json` only if deeper context is needed.
- **Handoff**: `sdd handoff <feature>` produces a structured transfer payload for resumption in a new session.
- **Failure recovery**: the PostToolUseFailure hook captures the last failed tool; surface the failure reason before retrying (Behavioral Core: reason through failures before retrying).

## Cross-Reference System

| Prefix | Artifact | Example |
|:-------|:---------|:--------|
| BRIEF-NNNN | brief.md | BRIEF-0001 (artifact ID) |
| SPEC-NNNN | spec.md | SPEC-0001 (artifact ID) |
| RESEARCH-NNNN | research.md | RESEARCH-0001 (artifact ID) |
| PLAN-NNNN | plan.md | PLAN-0001 (artifact ID) |
| TASKS-NNNN | tasks.md | TASKS-0001 (artifact ID) |
| REVIEW-NNNN | review.md | REVIEW-0001 (artifact ID) |
| US-xx | spec.md | US-01 (user story) |
| FR-xxx | spec.md | FR-001 (functional requirement) |
| AC-xxx | spec.md | AC-001 (acceptance criterion) |
| AD-xxx | plan.md | AD-001 (architectural decision) |
| PH-xx | plan.md | PH-01 (implementation phase) |
| T-xxx | tasks.md | T-001 (task) |

**Traceability:**
```text
BRIEF → FR-001 (spec) → PH-01 (plan) → T-001 (tasks) → [files] (research) → AC-001: PASS (review)
```

## Templates

Templates live in `${CLAUDE_SKILL_DIR}/templates/`.
Scripts copy templates and replace `{{PLACEHOLDER}}` values during scaffolding.
See that directory for artifact-specific structure.

## Automation Scripts

```bash
sdd <command> [args]
```

| Command | Purpose | Phase Transition |
|:--------|:--------|:-----------------|
| `sdd init <name> [--group <path>] [--mode lite\|full] [desc]` | Create feature folder | → Brief (full) / Spec (lite) |
| `sdd select [feature]` | Pin active feature (auto-detect fallback) | anytime |
| `sdd customize init` | Scaffold `.sdd/customization.yaml` with 15 scope-keyed empty lists and inline docs | anytime |
| `sdd customize check` | Validate YAML schema, bullet length, scope keys, and interpolation tokens | anytime |
| `sdd spec <feature>` | Scaffold spec.md | Brief → Design |
| `sdd research <feature>` | Scaffold research.md | Design → Research |
| `sdd plan create <feature>` | Scaffold plan.md | Research → Plan |
| `sdd plan create-tasks <feature>` | Scaffold tasks.md | Plan → Implement |
| `sdd review <feature>` | Scaffold review.md (auto-imports ACs) | Implement → Review |
| `sdd close <feature>` | Finalize feature | Review → Close |
| `sdd reopen <feature>` | Reopen closed feature | Close → Implement |
| `sdd status [feature]` | Dashboard | anytime |
| `sdd phase [feature]` | Detect current phase (authoritative) | anytime |
| `sdd summary <feature>` | Regenerate summary briefings | anytime |
| `sdd check [tasks\|trace\|all] <feature>` | Validate dependencies, trace coverage | anytime |
| `sdd task next <feature>` | Next dependency-ready task | Implement |
| `sdd task start <f> <T-xxx>` | Mark task in-progress (blocks on deps/suspect) | Implement |
| `sdd task scope-refresh <f> <T-xxx>` | Refresh task-scope.txt from current Files without resetting status | Implement |
| `sdd task complete <f> <T-xxx>` | Mark task completed | Implement |
| `sdd task list <feature>` | List all tasks | Plan/Implement |
| `sdd task graph <feature>` | Dependency DAG as JSON | Plan/Implement |
| `sdd advise <artifact> <feature>` | Run the rubric advisor on demand | anytime |
| `sdd trace refresh\|doctor\|coverage <f>` | Provenance graph management | anytime |
| `sdd handoff <feature>` | Session transfer artifact | anytime |
| `sdd archive <feature>` | Generate README.md + DOCS.md | Close |
| `sdd index [rebuild\|display]` | Manage `.features/INDEX.md` | anytime |
| `sdd wp init <feature> <name>` | Create work package | Implement |
| `sdd wp list <feature>` | List WPs with status | Implement |
| `sdd setup` | Bootstrap SDD into a project | one-time |

### Typical Session

```bash
sdd init user-auth "Reduce signup friction"       # Brief
# ... Q&A conversation, fill brief.md ...
sdd spec 0001-user-auth                           # Design
# ... write requirements in spec.md ...
sdd research 0001-user-auth                       # Research
# ... explore codebase, fill research.md ...
sdd plan create 0001-user-auth                    # Plan
# ... write strategy in plan.md ...
sdd plan create-tasks 0001-user-auth              # Tasks
# ... break into tasks in tasks.md ...
sdd task start 0001-user-auth T-001               # Implement
# ... build ...
sdd task complete 0001-user-auth T-001
sdd review 0001-user-auth                         # Review
# ... validate ACs, set verdict ...
```

### Agent-First CLI

All commands support a deterministic machine mode:

- `--json` — emit structured JSON on stdout; human guidance goes to stderr
- `--feature auto` — resolve feature from active pin or sole active feature (errors if ambiguous)
- `--non-interactive` — never prompt; exit with status code instead
- `--field <path>` / `--jq '<expr>'` — read-only selectors on `status`, `phase`, `check`, `summary`

Exit codes: `0` success · `2` usage · `3` not found · `4` gate/readiness failure · `5` conflict · `6` manual decision required · `7` internal. Full contract in [docs/cli-contract.md](docs/cli-contract.md).

## References

| Topic | File | Load when... |
|:------|:-----|:-------------|
| Phase guides | [references/phases/](references/phases/) | Entering or enforcing a phase |
| Artifact formats | [artifacts.md](references/artifacts.md) | Need format spec, WP mode, or ID conventions |
| Behavioral core | [steering-core.md](references/steering-core.md) | Writing new surfaces that must cite the six rules |
| Autonomous halts | [autonomous-halts.md](references/autonomous-halts.md) | Running an autonomous feature or resolving an autonomous halt |
| Worker dispatch | [workers.md](references/workers.md) | Dispatching subagent workers |
| Worker results | [worker-results.md](references/worker-results.md) | Processing worker returns |
| Trace rules | [trace-rules.json](references/trace-rules.json) | Evaluating trace.json coverage |
| Agent roles | [agents/](agents/README.md) | Selecting or configuring worker roles |
| Full docs | [docs/](docs/) | Deep-dive on CLI contract, artifacts, steering, subagents, plugin arch, evals |
