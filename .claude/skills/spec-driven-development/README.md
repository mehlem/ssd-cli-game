# Spec-Driven Development

Write it down before you build it. Understand WHY before you define WHAT.

## The Idea

Most bugs and wasted effort come from building the wrong thing. Spec-driven development fixes this by following the **Golden Circle** — start with WHY, then WHAT, then HOW — and making the spec the source of truth throughout.

Every requirement traces to a task, every task traces to code, every review validates against acceptance criteria. The filesystem tracks where you are. Scripts automate the mechanical work.

SDD supports three profiles. `normal` is the default seven-phase chain for substantial features and is persisted as `full` for backward compatibility. `lite` scaffolds `spec.md`, `tasks.md`, and `review.md` for bug fixes and small improvements while preserving task, scope, verification, and review gates. `deep` uses the same seven-phase lifecycle as normal mode, then adds stricter artifact contracts and more deliberate subagent orchestration for high-complexity or high-risk work. Claude chooses the profile at scaffold time using the [Mode Selection](SKILL.md#mode-selection) rubric; deeper details are in [profiles.md](references/profiles.md).

## The Golden Circle

```
WHY    →  WHAT    →  WHERE      →  HOW      →  DO       →  VERIFY    →  DONE
brief.md  spec.md  research.md  plan.md    tasks.md   review.md    close
(Brief)  (Design)  (Research)   (Plan)    (Implement) (Review)    (Close)
```

7 phases. 6 core artifacts. All in one feature folder: `.features/####-feature-name/` by default, or `.features/<group>/####-feature-name/` when created explicitly with `sdd init --group <path>`.

## Behavioral Steering Core

SDD reuses the same behavioral core across hooks, CLI guidance, templates, worker prompts, summaries, setup output, and evals:

- **Surface ambiguity** instead of guessing silently.
- **Investigate before claiming.**
- **Prefer the smallest viable solution.**
- **Change surgically** within scope.
- **Treat done as verified evidence.**
- **Reason through failures before retrying.**

## Quick Start

```bash
SDD="bash .claude/skills/spec-driven-development/scripts/sdd.sh"

# 1. Brief — capture WHY
$SDD init user-auth "Reduce signup friction"
# ... Q&A conversation to fill brief.md ...

# Optional grouped layout for larger programs
$SDD init search-index --group platform/search "Refresh search index lifecycle"

# 2. Design — define WHAT
$SDD spec 0001-user-auth
# ... write requirements and ACs in spec.md ...

# 3. Research — map WHERE
$SDD research 0001-user-auth
# ... explore codebase, fill affected files, patterns ...

# 4. Plan — decide HOW
$SDD plan create 0001-user-auth
# ... architecture decisions, vertical slices ...
$SDD plan create-tasks 0001-user-auth
# ... author Approach plus concrete atomic tasks ...

# 5. Implement — DO it after tasks.md is execution-ready
$SDD task next 0001-user-auth
$SDD task start 0001-user-auth T-001
# ... build ...
$SDD task complete 0001-user-auth T-001

# 6. Review — VERIFY it
$SDD review 0001-user-auth
# ... validate ACs, check quality, set verdict ...

# 7. Close — DONE
# ... graduate knowledge, finalize artifacts ...

# Anytime
$SDD status                    # all features overview
$SDD status 0001-user-auth     # specific feature dashboard

# Optional: Project customization
$SDD customize init            # scaffold .sdd/customization.yaml
# ... edit to add project-level guidance bullets ...
$SDD customize check .sdd/customization.yaml  # validate schema
```

## Phases

### 1. Brief — WHY

Lean intent-extraction phase that captures user intent before writing any engineering artifacts. Posture: gather context first (CLAUDE.md, INDEX, related features, scoped repo files), propose ideas or draft inferable sections, and ask only intent-level questions. Soft cap ~3 questions, each paired with a `**Recommended**:` line. Forbidden question types: research/plan-phase questions, code-logic questions, anything answerable by inspection. All 5 sections (Motivation, Problem, Vision, Context, Constraints) remain required, but Problem/Context/Constraints are usually filled by interpretation with `<!-- inferred from <source> -->` labels.

**Produces:** `brief.md` — motivation, problem, vision, constraints, Q&A record.

### 2. Design — WHAT

Translate the brief into engineering requirements: functional requirements (FR-xxx), acceptance criteria (AC-xxx), user stories, scope boundaries. Surface competing interpretations instead of silently choosing one that changes scope or verification.

**Produces:** `spec.md` — the single source of truth for what to build.

### 3. Research — WHERE

Map the implementation landscape: which files to touch, what patterns to follow, what dependencies exist, what could go wrong. Ground claims in opened files and separate facts from hypotheses when certainty is incomplete.

Fact claims do not create a new phase, `.facts` workflow, facts CLI dependency,
semantic sidecar, or enforcement subsystem. They are artifact-local evidence
labels that keep Research facts, hypotheses, unknowns, and durable knowledge
boundaries clear while existing SDD gates remain authoritative.

**Produces:** `research.md` — affected files, entry points, types, dependencies, risks.

### 4. Plan — HOW

Make architectural decisions informed by research. Break work into vertical slices (tracer bullets), each independently demoable. Prefer the smallest viable design that satisfies today's requirements, then derive atomic tasks.

**Produces:** `plan.md` (strategy) + execution-ready `tasks.md`
(`## Approach` plus concrete task headings).

### 5. Implement — DO

Execute tasks one at a time after `tasks.md` is execution-ready. TDD when
applicable. Read scoped files first, keep diffs surgical, update task status via
scripts, keep scratchpad current, and update research.md if new files/patterns
are discovered.

**Updates:** `tasks.md` status changes.

### 6. Review — VERIFY

Validate every acceptance criterion from spec.md. Compare actual changes against research.md file map. Check code quality, flag unrequested work or overbuilding, and set verdict from evidence.

**Produces:** `review.md` — AC validation, quality check, files changed, verdict.

### 7. Close — DONE

Verify all artifacts completed. Graduate scratchpad findings to KNOWLEDGE.md. Finalize.

## Phase Skills

The main `spec-driven-development` skill remains the router, gatekeeper, and artifact contract for every phase. Phase-local skills provide concise procedure for the active phase and are installed by setup alongside the main skill:

| Phase/profile | Skill |
|:--------------|:------|
| Full Brief | `/sdd-brief` |
| Full Design / lite Spec | `/sdd-spec` |
| Full Research | `/sdd-research` |
| Full Plan | `/sdd-plan` |
| Full or lite Implement | `/sdd-implement` |
| Full or lite Review | `/sdd-review` |
| Full or lite Close | `/sdd-close` |

Review-specific work routes to `/sdd-review`, never `/sdd-research`.

These are phase skill guidance wrappers, and invoking the required one is now a
narrow routing latch for protected phase actions. Before editing the active
phase artifact or running a protected SDD boundary command, invoke the required
phase skill for the current phase. For the latch, direct reads of `SKILL.md`, phase reference markdown, or artifact files do not satisfy the latch; only an observed
phase-skill invocation does. The latch proves routing through the right phase
guidance, not artifact correctness. Artifact checks, hooks, CLI gates, and
review evidence remain authoritative for correctness.

Plan-owned `tasks.md` authoring uses `/sdd-plan`; Implement-owned task
execution uses `/sdd-implement`. A scaffolded or placeholder-only `tasks.md`
stays in Plan until it has substantive `## Approach` content and concrete task
headings.

Each skill includes `when_to_use`, Phase Goal & Context, Relevant Commands,
Preconditions, First Actions, Output Contract, and Return / Failure Protocol.
Relevant Commands is a phase-local shortlist with one-line purpose notes, not a
broad CLI catalog or a bypass surface.

## Phase Detection

No configuration. The filesystem is the state machine:

| Files present | Phase |
|:--------------|:------|
| Nothing or no brief.md | Brief |
| brief.md, no spec.md | Design |
| spec.md, no research.md | Research |
| research.md, no plan.md | Plan |
| plan.md, no execution-ready tasks.md | Plan (tasks) |
| execution-ready tasks.md with unchecked items | Implement |
| All tasks done, no review.md | Review |
| review.md with verdict: pass | Close |

## Artifacts

### The Chain

```
.sdd/
├── customization.yaml                  project-level guidance (committed)

.features/
├── INDEX.md                         overview table of all features
├── 0001-user-auth/
    ├── brief.md          BRIEF-0001      WHY — intent, motivation, Q&A
    ├── spec.md           SPEC-0001       WHAT — requirements, ACs
    ├── research.md       RESEARCH-0001   WHERE — files, patterns, dependencies
    ├── plan.md           PLAN-0001       HOW — architecture, vertical slices
    ├── tasks.md          TASKS-0001      DO — atomic tasks with verification
    ├── review.md         REVIEW-0001     VERIFY — AC validation, quality check
    ├── scratchpad.md     SCRATCH-0001    working memory (throughout)
    ├── customization.yaml               feature-level guidance (gitignored by default)
    ├── summary.md                        derived briefing (phase + progress + rules)
    ├── trace.json                        typed provenance graph (artifacts → tasks → code)
    └── [README.md + DOCS.md]            auto-generated archive docs (after close)
└── platform/search/0008-search-index/   optional grouped feature folder
```

### Frontmatter

Every artifact shares consistent YAML metadata:

```yaml
id: SPEC-0001                # Globally unique (TYPE-NNNN)
feature: "0001-user-auth"    # Feature folder
title: "User Auth"           # Human-readable
type: spec                   # brief|spec|research|plan|tasks|review|scratchpad
status: draft                # draft → active → completed
phase: design                # Owning phase
source: BRIEF-0001           # Upstream dependency
related:                     # Sibling link map
  brief: BRIEF-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  ...
tags: []
```

### Cross-Reference IDs

| Prefix | Artifact | Traceability |
|:-------|:---------|:-------------|
| FR-xxx | spec.md | requirement → plan phase → task → files → review |
| AC-xxx | spec.md | acceptance criterion → review validation |
| AD-xxx | plan.md | architectural decision |
| PH-xx | plan.md | implementation phase (vertical slice) |
| T-xxx | tasks.md | task → phase, requirements, files |

**Full chain:** `BRIEF → FR-001 (spec) → PH-01 (plan) → T-001 (tasks) → [files] (research) → AC-001: PASS (review)`

## Documentation

The `docs/` directory contains detailed guides covering eight aspects of the SDD methodology:

- **workflow-lifecycle.md** — Core workflow lifecycle: agent harness, work packages, feature selection. Covers how to initialize features, track phases, and structure multi-phase work.

- **cli-contract.md** — Agent-first CLI contract: common flags, JSON envelopes, semantic exit codes, selectors, command matrix, status payload shapes, canonical aliases, and compatibility guarantees for script-driven use.

- **agent-steering.md** — Agent steering and context injection: phase constraints, methodology injection via hooks, delta-only cache refresh, and CLI guidance for steering agent behavior toward methodology compliance.

- **subagent-delegation.md** — Subagent dispatch and worker contracts: how to delegate feature work to Claude Code subagents, dispatch packet format, authority boundaries, and result validation.

- **codex-delegation.md** — Codex provider delegation: SDD-owned prompt templates, custom task insertion, phase permissions, preflight, result import, and review-support evidence semantics.

- **artifacts-and-state.md** — Artifact design and state management: markdown reliability, summary generation, confidence scoring, continuity across context compaction, and review rigor validation.

- **eval-framework.md** — Evaluation framework: behavioral evals keyed to workflow phases, fixture hardening, trigger-based testing, and LLM grader patterns.

- **plugin-architecture.md** — Plugin architecture and hardening: conversion from skill to plugin, codebase robustness (error handling, dead code removal, data consistency), and progressive disclosure via phase guides.

Each document is 200-400 lines and includes concrete examples, decision rationale, and references to implementation details. Start with `workflow-lifecycle.md` for foundational concepts, then dive into specific docs as needed.

## Scripts

```bash
SDD="bash .claude/skills/spec-driven-development/scripts/sdd.sh"
```

| Command | Purpose | Phase |
|:--------|:--------|:------|
| `sdd init <name> [--group <path>] [desc]` | Create feature folder | → Brief |
| `sdd spec <feature>` | Scaffold spec.md | Brief → Design |
| `sdd research <feature>` | Scaffold research.md | Design → Research |
| `sdd plan create <feature>` | Scaffold plan.md (`plan plan` still works) | Research → Plan |
| `sdd plan create-tasks <feature>` | Scaffold tasks.md (`plan tasks` still works) | Plan task authoring |
| `sdd task {next\|start\|scope-refresh\|complete} ...` | Task lifecycle | Implement |
| `sdd task {list\|block\|add} ...` | Task management | Implement |
| `sdd worker {dispatch\|status\|import-result} ...` | Provider-aware worker dispatch/result ledger, including Codex | Research/Plan/Implement/Review |
| `sdd review <feature>` | Scaffold review.md (auto-imports ACs) | Implement → Review |
| `sdd close <feature>` | Finalize and generate archive docs | Review → Close |
| `sdd customize init` | Scaffold `.sdd/customization.yaml` with 15 scope keys | anytime |
| `sdd customize check` | Validate customization YAML schema and constraints | anytime |
| `sdd select [feature]` | Pin active feature (auto-detect fallback) | anytime |
| `sdd archive <feature>` | Generate README.md + DOCS.md for closed feature | Close |
| `sdd trace refresh <feature>` | Rebuild trace.json provenance graph | anytime |
| `sdd trace coverage <feature>` | Per-rule PASS/FAIL/SKIP coverage report against `references/trace-rules.json` | anytime |
| `sdd trace acknowledge <feature> --confirmed [--reason <text>]` | Clear suspect flags after verified upstream change; appends to `changes.log` | Implement |
| `sdd advise <artifact> <feature>` | Run the rubric advisor on demand (Haiku-backed; non-blocking suggestions). Set `SDD_ADVISOR_DISABLED=1` to suppress advisor hooks for the session | anytime |
| `sdd index` | Rebuild `.features/INDEX.md` overview | anytime |
| `sdd setup` | Bootstrap SDD into current project | one-time |
| `sdd status [feature]` | Dashboard | anytime |
| `sdd phase [feature]` | Detect current phase | anytime |

Full script suite contains 40+ scripts including lifecycle commands (`sdd-init.sh`, `sdd-spec.sh`, `sdd-plan.sh`, `sdd-task.sh`, `sdd-review.sh`, `sdd-close.sh`), state management (`sdd-status.sh`, `sdd-cache-refresh.sh`), hook infrastructure (`sdd-hook.sh`, `sdd-stop-gate.sh`, `sdd-scope-drift.sh`, `sdd-precompact.sh`, `sdd-postcompact.sh`), subagent dispatch/validation (`sdd-subagent-start.sh`, `sdd-subagent-stop.sh`), the rubric advisor (`sdd-advise.sh`, `sdd-advisor-preboundary.sh`, `sdd-advisor-postauthoring.sh`), customization (`sdd-customize.sh`), trace management (`sdd-trace.sh` for refresh/coverage/acknowledge/doctor), evaluation runners, and validation utilities.

### Agent-First CLI

The CLI now supports a deterministic machine path for Bash-driven agents:

- Common flags: `--help`, `--feature <id|auto>`, `--format text|json`, `--json`, `--non-interactive`, `--on-exists fail|overwrite|skip`
- Feature refs may be exact nested paths, flat IDs, unambiguous basenames, or unambiguous numeric prefixes; ambiguous selectors fail instead of guessing
- Path-aware JSON fields such as `feature_path`, `feature_dir`, and `feature_group` are additive; legacy `feature` / `resolved_feature` remain the basename ID
- Status-specific single-feature shortcut: `sdd status --current` or `sdd status current`
- Read selectors: `--field <path>` and `--jq '<expr>'` on `status`, `phase`, `check`, `handoff`, `summary`, and `select`
- Machine mode rule: JSON mode writes only JSON to stdout; human guidance stays in text mode
- Canonical aliases: `sdd plan create`, `sdd plan create-tasks`
- Compatibility note: `sdd plan create-all` and legacy `sdd plan both` are recognized, but blocked under semantic gates; run `create` and `create-tasks` separately
- Self-description: `sdd help --json` and `sdd <command> --help --json`
- Compatibility: default `sdd phase` text output is preserved for hook consumers, and single-feature `sdd status --json` still exposes the legacy top-level payload fields
- Detailed command-family notes, status payload shapes, and compatibility shims live in `docs/cli-contract.md`

Semantic exit classes:

- `0` success
- `2` usage / parse error
- `3` target not found
- `4` precondition / readiness / gate failure
- `5` conflict / would-prompt / overwrite-policy failure
- `6` blocked / manual decision required
- `7` internal / verification / unexpected runtime failure

Examples:

```bash
$SDD status --json
$SDD status --current --json
$SDD status --current --json --field phase
$SDD status --json --feature auto --field phase
$SDD spec --json --feature auto --non-interactive --on-exists overwrite
$SDD help --json
```

### Bash Validation

Use the built-in quality gate before large refactors or plugin releases:

```bash
bash sdd-plugin/skills/spec-driven-development/scripts/tests/sdd-quality-gate-test.sh
```

What it does:

- Always runs `bash -n` across every `.sh` file under `scripts/` and `scripts/tests/`
- Runs `shellcheck -S warning -x -s bash -e SC1090,SC1091,SC2034` when ShellCheck is installed
- Prints a warning and still succeeds when ShellCheck is unavailable, as long as syntax checks pass

`SC2034` is excluded intentionally because `sdd-lib.sh` is a sourceable shared library and exports state via variables that ShellCheck cannot always see as consumed across sourcing boundaries.
- Supports `SDD_DEBUG=1` for file-by-file trace output during validation

## Templates

Templates in `templates/` define artifact structure. Scripts copy them and replace `{{PLACEHOLDER}}` values:

| Placeholder | Example |
|:------------|:--------|
| `{{FEATURE_ID}}` | 0001-user-auth |
| `{{FEATURE_NUM}}` | 0001 |
| `{{FEATURE_TITLE}}` | User Auth |
| `{{DATE}}` | 2026-03-31 |

## For AI Coding Agents

### Session Start

```bash
sdd status                           # where am I?
cat .features/0001-auth/brief.md     # WHY are we building this?
cat .features/0001-auth/research.md  # WHERE in the codebase?
cat .features/0001-auth/tasks.md     # WHAT to do next?
```

Four reads = full context. No re-exploration needed.

### Key Principles

- **Follow the Golden Circle.** Start with WHY. Never skip to implementation.
- **Use the behavioral steering core.** Surface ambiguity, investigate before claiming, prefer the smallest viable solution, change surgically, treat done as verified evidence, and reason through failures before retrying.
- **Use the scripts.** `sdd task complete` is safer than manual edits.
- **Prefer explicit targeting in machine paths.** `--feature auto` and `--json` make Bash results deterministic.
- **Follow the IDs.** When implementing T-003, check which FR it implements and which files it touches.
- **Update research.md.** When you discover new files/patterns during implementation.
- **Update the scratchpad.** It survives context compaction.
- **Present plans before executing.** Always get user confirmation.

## File Structure

```
spec-driven-development/
├── SKILL.md                 Methodology — 7 phases, Golden Circle
├── README.md                This file
├── agents/                  Claude Code agent role pack
│   ├── README.md            Routing guidance and adoption instructions
│   ├── sdd-implementer.md   Task implementer (mutable, foreground)
│   ├── sdd-spec-reviewer.md Spec compliance reviewer (read-only)
│   ├── sdd-quality-reviewer.md Code quality reviewer (read-only + Bash)
│   ├── sdd-research-scout.md Codebase explorer (background + worktree)
│   └── sdd-plan-drafter.md  Architecture planner (read-only)
├── docs/                    Feature documentation
│   ├── workflow-lifecycle.md Core workflow: phases, agent harness, work packages
│   ├── cli-contract.md      Agent-first CLI contract: flags, JSON, exits, selectors, command matrix
│   ├── agent-steering.md    Context injection, phase constraints, hook infrastructure
│   ├── subagent-delegation.md Dispatch packets, worker contracts, validation
│   ├── codex-delegation.md  Codex provider dispatch, prompt templates, import, review support
│   ├── artifacts-and-state.md Artifact design, summaries, continuity, review rigor
│   ├── eval-framework.md    Behavioral evals, fixture hardening, trigger testing
│   └── plugin-architecture.md Plugin design, codebase hardening, progressive disclosure
├── references/              Design guides and specifications
│   ├── artifacts.md         Artifact format specifications + work packages
│   ├── phases/              Phase-specific guides (7 files)
│   ├── workers.md           Worker dispatch guide + packet schema
│   └── worker-results.md    Worker result contract + status taxonomy
├── templates/               Canonical artifact structure (7 templates)
│   ├── codex/               SDD-owned Codex prompt templates
│   ├── brief.md
│   ├── spec.md
│   ├── research.md
│   ├── plan.md
│   ├── tasks.md
│   ├── review.md
│   └── scratchpad.md
└── scripts/                 Automation CLI (40+ scripts)
    ├── sdd.sh               Dispatcher
    ├── sdd-init.sh           Create feature (Brief)
    ├── sdd-spec.sh           Scaffold spec (Design)
    ├── sdd-research.sh       Scaffold research (Research)
    ├── sdd-plan.sh           Scaffold plan/tasks (Plan)
    ├── sdd-task.sh           Task CRUD and lifecycle
    ├── sdd-review.sh         Scaffold review (Review)
    ├── sdd-close.sh          Finalize and close (Close)
    ├── sdd-status.sh         Feature dashboard
    ├── sdd-phase.sh          Detect current phase
    ├── sdd-lib.sh            Shared utilities + sdd_has_active_feature predicate
    ├── sdd-hook.sh           Context injection hook
    ├── sdd-cache-refresh.sh  State refresh
    ├── sdd-scope-drift.sh    Scope validation
    ├── sdd-trace.sh          Trace graph: refresh / coverage / acknowledge / doctor
    ├── sdd-customize.sh      Project customization init/check
    ├── sdd-advise.sh         Rubric advisor (on-demand)
    ├── sdd-autonomy.sh       Autonomous mode toggle (per-feature)
    └── [... additional hooks, validators, and lifecycle helpers ...]
```

State and audit files (per feature):

```
.features/
├── .active                  Active feature pin (single line)
├── .active.log              Append-only NDJSON ledger of every active-pin change
├── INDEX.md                 Overview table of all features
└── 0001-feature-name/
    ├── changes.log          NDJSON audit log (trace_acknowledge, etc.)
    ├── state.json           Derived feature state cache
    ├── scope.txt            Files in current task scope
    ├── trace.json           Typed provenance graph
    ├── summary.md           Full briefing
    └── summary-compact.md   Compaction-recovery briefing
```

`.features/.active` stores the canonical feature path. For flat features that is the legacy ID; for grouped features it is a path such as `platform/search/0008-search-index`. Group folders are containers only. Work packages remain direct `wp-*` children of the resolved feature directory and are not discovered as features. Root epic v1 remains `.features/EPIC.md`.

## Agent Role Pack

The `agents/` directory defines five Claude Code worker roles registered automatically by the SDD plugin via `plugin.json`. No manual file copying is required — install the plugin and the roles are available immediately.

Phase skills and worker agents serve different jobs. Phase skills guide the
current phase in the controller session; worker agents execute bounded delegated
work. For example, `/sdd-research` explains Research phase procedure, while
`sdd-research-scout` performs a scoped read-only exploration assignment.

**Invoke a role directly:**
```bash
claude --agent sdd-research-scout    # background codebase exploration
claude --agent sdd-plan-drafter      # architecture decisions
claude --agent sdd-implementer       # task execution
claude --agent sdd-spec-reviewer     # spec compliance review
claude --agent sdd-quality-reviewer  # code quality review
```

**Or dispatch from within a session** via `Ctrl+B` and select the role by name.

| Phase | Role to dispatch | Agent name |
|:------|:----------------|:-----------|
| Research | Codebase exploration | `sdd-research-scout` |
| Plan | Architecture decisions | `sdd-plan-drafter` |
| Implement | Task execution | `sdd-implementer` |
| Review | Spec compliance | `sdd-spec-reviewer` |
| Review | Code quality | `sdd-quality-reviewer` |

See `agents/README.md` for the full routing guide and authority model.

## Development History

SDD has been iteratively refined through 46+ spec-driven features since initial release:

- **Workflow foundations** (0001-0006): Core phase lifecycle, artifact chain, feature initialization, phase detection, multi-phase coordination, feature selection via `sdd select`.
- **Artifacts & continuity** (0003, 0007, 0012-0014): Markdown reliability, summary generation, confidence scoring, context preservation across compaction, review rigor validation.
- **Evaluation framework** (0008-0009, 0015): Behavioral evals, fixture hardening, trigger-based testing, LLM grader patterns.
- **Subagent workers** (0010-0011, 0020, 0023, 0036): Claude Code subagent integration, typed worker contracts, dispatch packets, result validation hooks, orchestration hardening (bounded SubagentStop revalidation, result normalisation, batched validation failure reporting).
- **Agent steering** (0005, 0016, 0019, 0021, 0035, 0037-0038): Phase-aware hook infrastructure, context injection, 25+ lifecycle event coverage, brief-phase interview tracking with per-turn cues, stderr guidance in JSON mode, coherent behavioral steering across all surfaces.
- **Agent-first CLI** (0022): Deterministic machine path with `--json`, `--feature auto`, `--non-interactive`, semantic exit codes (0/2/3/4/5/6/7), and read selectors.
- **Quality gates** (0024-0025): Semantic phase gates (content-aware readiness checks), evidence-backed review adjudication with machine-checkable verdict.
- **Task management** (0026): Dependency graph with cycle detection; `sdd task next` respects execution order constraints.
- **Feature lifecycle** (0028, 0031, 0032, 0034): Auto-generated archive docs per closed feature, persistent INDEX.md at `.features/`, canonical description metadata, `sdd setup` command to bootstrap SDD into any project.
- **Trace & provenance** (0030, 0033, 0043): `trace.json` typed dependency graph linking artifacts → requirements → tasks → code; suspect propagation on upstream changes; coverage rules manifest with PASS/FAIL/SKIP rule taxonomy; `sdd trace acknowledge --confirmed [--reason <text>]` clears suspect flags via auditable `changes.log` entries (replaces `--force` on the suspect gate).
- **Indexing performance** (0041): `sdd_task_summary_cheap` removes graph-storm from hot hook paths; `sdd index rebuild` reduced from ~66s to <5s on 40+ feature repos.
- **Rubric advisor** (0040): Haiku-backed pre-boundary and post-authoring hooks surface grounded rubric suggestions non-blockingly; on-demand via `sdd advise <artifact> <feature>`; `SDD_ADVISOR_DISABLED=1` kill switch; legacy `sdd semantic` infrastructure retired.
- **Windows compatibility** (0042): CRLF normalisation, flat install layout, Defender-retry on `sdd setup`, opt-in `--install-shim` walk-up wrapper, Windows CI coverage.
- **State stability & active-feature guard** (0039, 0044, 0046): Semantic auto-refresh; `.features/.active.log` append-only audit ledger of every active-pin change; cache-vs-`.active` freshness gating; named public predicate `sdd_has_active_feature` (composes phase ≠ close + continuity status ∉ {completed, abandoned, superseded}); skill-scoped hook self-gating keeps the plugin silent in non-SDD sessions while staying plugin-level (architecture decision: GH#40630 forwarding bug rules out skill-frontmatter `hooks:`).
- **Project customization** (0045): `.sdd/customization.yaml` + `.features/<id>/customization.yaml` inject phase- and agent-scoped guidance bullets into hook emissions and dispatch packets; 15 known scope keys, 4 interpolation tokens, `sdd customize init` / `sdd customize check`.
- **Codebase hardening** (0004, 0017-0018, 0027, 0029): Plugin architecture, error handling, dead code removal, data consistency, progressive disclosure, Bash safety hardening, references reorganization.

This history reflects continuous hardening: 38 completed features have tested edge cases, refined hook infrastructure, strengthened validation, and optimized the agent steering model. The result is a production-grade methodology engine.

## Installation

**As a plugin (recommended):**
```bash
claude plugin install sdd-plugin/
```

**For local development (load from disk):**
```bash
claude --plugin-dir ./sdd-plugin
```

**Standalone via `sdd setup` (no plugin required after setup):**

With the plugin loaded, invoke the setup skill:
```
/sdd-setup
```
Or via CLI:
```bash
sdd setup           # install into current project
sdd setup --dry-run # preview without writing files
sdd setup --force   # overwrite user-modified files
```
Copies agents, skill, scripts, hooks, CLI, and CLAUDE.md instructions into `.claude/`. Re-running after a plugin update upgrades safely — user-modified files are backed up to `.sdd-local-patches/` first.

**Manual copy (legacy):**
```bash
cp -r sdd-plugin/skills/spec-driven-development .claude/skills/
chmod +x .claude/skills/spec-driven-development/scripts/*.sh
# Then manually register hooks from sdd-plugin/hooks/hooks.json into .claude/settings.json
```
