# Plugin Architecture & Codebase

The SDD plugin is a distributable Claude Code extension that encapsulates the Spec-Driven Development lifecycle as a reusable skill with integrated hooks and CLI tools. It evolved from a single embedded skill to a production-hardened plugin through three coordinated features: plugin conversion (0004), codebase hardening (0017), and progressive disclosure refactoring (0018).

## Plugin Conversion

The SDD skill was originally embedded in `.claude/skills/spec-driven-development/` with hooks registered directly in `.claude/settings.json`. This design prevented sharing across projects and made version control difficult. Feature 0004 restructured the skill as a Claude Code plugin—a self-contained distribution package that can be installed via `claude plugin install sdd` and shared between projects.

The plugin wraps the skill directory in a standard Claude Code plugin scaffold:

```
sdd-plugin/
├── .claude-plugin/
│   └── plugin.json          # Manifest: name, version, description, agents
├── hooks/
│   └── hooks.json           # Hook registrations with feature-0017 hardening
├── bin/
│   └── sdd                  # CLI entry point: dispatches to scripts/sdd.sh
└── skills/
    └── spec-driven-development/
        ├── SKILL.md         # Slim skill definition (feature 0018)
        ├── README.md        # Installation and usage guide
        ├── scripts/         # Bash automation for all lifecycle phases
        ├── templates/       # Scaffolding for .features/ artifacts
        ├── references/      # Phase guides, operating rules, worker documentation
        ├── agents/          # Specialized subagents for each phase
        └── docs/            # Consolidated documentation
```

The plugin preserves all script path resolution unchanged by using `${CLAUDE_PLUGIN_ROOT}` in hook commands. This ensures that production scripts continue to reference `../templates/`, sibling scripts, and `.features/` data without modification. The `bin/sdd` executable makes the SDD CLI available on PATH when the plugin is enabled, allowing `sdd <command>` syntax for status, init, task, close, and other operations.

## Hook Registration Model

Feature 0017 systematized hook registration across twelve Claude Code lifecycle events. The hooks are declared in `hooks.json` and fire on specific matchers to inject SDD context, refresh caches, validate state transitions, and detect scope drift.

**SessionStart** (matcher: `startup|resume|compact`)
- Fires when a session begins, resumes, or context compacts
- Runs `sdd-hook.sh` to load active feature metadata, phase state, and task summary
- Injects behavioral guardrails (Hard Gates, Non-Negotiable Boundaries, Red Flags) into the session

**UserPromptSubmit**
- Fires on every user input
- Runs `sdd-hook.sh` to refresh context cache and detect phase transitions
- Ensures Claude stays aware of current feature state between tool executions

**PreToolUse** (matcher: `Edit|Write`)
- Fires before Edit or Write tool execution
- Runs `sdd-scope-drift.sh` to warn if Claude is editing files outside the current task's scope
- Blocks out-of-scope edits when task boundaries are violated (feature 0017)

**PostToolUse** (matcher: `Bash|Edit|Write`)
- Fires after Bash, Edit, or Write execution completes
- Runs `sdd-cache-refresh.sh` asynchronously to update feature artifacts cache
- Tracks file modifications for inclusion in the next summary refresh

**PostToolUseFailure** (matcher: `Bash|Edit|Write`)
- Fires when a tool execution fails
- Runs `sdd-posttool-failure.sh` to capture failure context and prevent state corruption
- Logs failure details for debugging and failure recovery

**PreCompact**
- Fires before context window compaction
- Runs `sdd-precompact.sh` to snapshot feature state, refresh state.json, and generate a session summary
- Ensures all in-flight changes are persisted before the session is compressed

**PostCompact**
- Fires after context compaction
- Runs `sdd-postcompact.sh` to restore SDD context in the new session window
- Reloads active feature metadata and phase state for continuity

**InstructionsLoaded** (matcher: `compact`)
- Fires when instructions reload after compaction
- Runs `sdd-instructions-loaded.sh` to track instruction reload counts
- Used for debugging context window management

**SubagentStart** & **SubagentStop**
- Fire when dispatching to or returning from specialized subagents (implementer, spec-reviewer, quality-reviewer, research-scout, plan-drafter)
- Start hook injects the dispatch packet (feature state + task assignment)
- Stop hook validates the worker result before integration

**SessionEnd** (previously called "Stop" in older versions)
- Fires when a session is about to exit
- Runs `sdd-stop-gate.sh` to enforce completion gates: prevents exiting with in-progress tasks unless explicitly cleared
- Ensures unfinished work cannot be abandoned

All hook commands use `${CLAUDE_PLUGIN_ROOT}` for reliable path resolution across different installation paths and projects.

### Self-Gating Architecture (0046)

All hook handlers remain **plugin-level** in `sdd-plugin/hooks/hooks.json` — none are moved to skill-frontmatter `hooks:` blocks or to project-level `.claude/hooks/`. The architectural decision is anchored in confirmed [GH#40630](https://github.com/anthropics/claude-code/issues/40630): skill-frontmatter `hooks:` are not forwarded to forked subagents, and behavior with `skills:`-preloaded subagents is undocumented. SDD work routinely involves subagents authoring artifacts (spec.md, research.md, plan.md, tasks.md, review.md) — moving any authoring-related hook to skill frontmatter would silently drop coverage on the very surfaces SDD steers most.

The "skill-scoping" goal — silent in non-SDD sessions, fully active during SDD work — is achieved instead by **early self-gating**. Every hook script calls a shared `sdd_has_active_feature` helper near the top and exits 0 immediately when no active feature exists. The helper composes `sdd_feature_status`, `sdd_feature_is_inactive`, and `sdd_auto_feature_candidates` into a single predicate that excludes features in close phase, features with `continuity.md` `status ∈ {completed, abandoned, superseded}`, and treats missing/unset status as active by default. The user-visible outcome is identical to a frontmatter approach without the subagent-propagation or compaction-survival edge cases. For the helper contract and the full decision record, see `references/hook-architecture.md`.

## Codebase Hardening

Feature 0017 systematically addressed 26 issues that accumulated in the SDD codebase:

**Wiring Dead Code**: The `sdd-scope-drift.sh` script was implemented but never registered in hooks.json. Feature 0017 added the PreToolUse hook entry with proper feature-targeting fixes. Maintenance hints output is now wired into SessionStart context via the `sdd_maintenance_hints()` function.

**Removing Dead Code**: Four orphaned functions removed from `sdd-lib.sh` (`sdd_is_wp_mode`, `sdd_detect_active_wp`, `sdd_confirm_overwrite`) that had no callers. The `write_cache()` function and `sdd-status.txt` cache file references were removed from `sdd-hook.sh`.

**Data Consistency**: Scripts that mutate feature state now refresh `state.json` immediately. `sdd-task.sh` calls `sdd-status.sh --json` after start/complete/block/reset operations. `sdd-close.sh` and `sdd-reopen.sh` refresh state after artifact mutations. This ensures hooks and summaries always see fresh data.

**Error Handling**: jq calls in `sdd-hook.sh` and `sdd-stop-gate.sh` that parse stdin are guarded with `2>/dev/null || true` to handle malformed JSON gracefully (no crashes). Field separator (`IFS=$'\t'`) is set before `read` commands that consume jq `@tsv` output, fixing parsing of file paths with spaces. Nudge counter arithmetic is protected against corrupted or missing counter files.

**Wiring Gaps**: Cache refresh logic now correctly updates both `REFRESH_FEATURE` and `FEATURE` when they differ. The PreCompact hook refreshes `state.json` before calling summary.sh to ensure accurate state snapshots during compaction.

### Bash Safety Hardening (0027)

A second hardening pass (feature 0027) added defensive patterns across the script suite:

**Safe temp-file writes:** All scripts that mutate artifacts use atomic write-then-move (`write to tmp → mv tmp target`) instead of in-place overwrite, preventing partial-write corruption on crash.

**Parser consolidation:** Duplicated frontmatter and task-status parsing logic was extracted into shared helpers in `sdd-lib.sh`. Callers now source the library rather than re-implementing patterns inline — reducing parser drift between commands.

**Test regression suite:** A set of regression tests was added under `scripts/tests/` covering known edge cases: malformed frontmatter, empty artifacts, concurrent writes, and feature-folder name collisions. Run with:
```bash
bash scripts/tests/sdd-regression-test.sh
```

**Diagnostics:** All scripts support `SDD_DEBUG=1` for file-by-file trace output. The quality gate (`sdd-quality-gate-test.sh`) runs both `bash -n` syntax checks and ShellCheck across the full script suite.

## Progressive Disclosure Architecture

Feature 0018 restructured SKILL.md from 514 lines to under 350, eliminating context bloat while preserving all behavioral enforcement. The architecture is **Policy → Detection → Routing → Reference**: inline enforcement rules guide Claude's immediate actions, while detailed methodology and reference material are available on-demand.

### What Stays in SKILL.md

The slim SKILL.md (currently ~227 lines) contains the behavioral core:

- **Mandatory First Response Protocol**: Before any action, check for an active feature, detect the current phase, read required artifacts, and announce intent.
- **Hard Gates table**: Conditional guardrails that trigger on specific artifacts or conditions (e.g., "if in Design and Plan is incomplete, block code generation").
- **Non-Negotiable Boundaries**: Rules that cannot be violated (no task switching mid-phase, no artifact deletion).
- **Red Flags table**: Suspicious patterns that require confirmation (e.g., skipping phases, editing work outside scope).
- **Priority Order**: When multiple phases are valid, this matrix determines which action takes precedence.
- **Phase Detection table**: Compact rules for detecting the current phase from disk artifacts.
- **Phase Enforcement prose**: How Claude enforces phase transitions during conversation.
- **Cross-Reference System table**: Backward-mapping from artifacts to related files.
- **Automation Scripts table**: Quick reference for CLI commands (sdd init, sdd task, sdd close, etc.).

### What Moved to References

Phase methodology (Phase 1-7 detailed guides) was moved from SKILL.md to `references/phases/*.md`:
- `brief.md` (Phase 1: Capture intent)
- `design.md` (Phase 2: Clarify requirements)
- `research.md` (Phase 3: 10-step investigation)
- `plan.md` (Phase 4: Design implementation)
- `implement.md` (Phase 5: Code & test)
- `review.md` (Phase 6: Quality validation)
- `close.md` (Phase 7: Handoff & learn)

SKILL.md now contains a progressive disclosure table that tells Claude *when* to load each reference:

| Phase | Reference | When to Load |
|-------|-----------|--------------|
| Brief | references/phases/brief.md | Starting new feature or resuming in Brief |
| Design | references/phases/design.md | Entering Design or clarifying requirements |
| Research | references/phases/research.md | Entering Research or investigating unknowns |
| ... | ... | ... |

Work Packages methodology is in the Work Packages section of `references/artifacts.md`, with a summary in SKILL.md pointing to it. Worker Mode points to `references/workers.md` for the combined dispatch guide.

### How Progressive Disclosure Works

When a user invokes `/spec-driven-development`, Claude loads the slim SKILL.md (300 lines). This loads immediately and costs 300 tokens. If the feature is in Design phase, Claude detects this and decides to load `references/phases/design.md` (150 lines) on-demand, only when needed. This approach reduces cold-load context consumption while keeping all information accessible.

The description field is optimized with broad trigger phrases ("implement feature", "add feature", "start building", "resume work", "what's next") to activate the skill on natural language, not just SDD terminology.

## Hook Lifecycle Timeline

A typical SDD session follows this hook sequence:

1. **SessionStart**: Load active feature context
2. **UserPromptSubmit** (each turn): Refresh cached state
3. **PreToolUse** (on Edit/Write): Check for scope drift
4. **PostToolUse** (after Bash/Edit/Write): Update artifact cache
5. **PreCompact**: Snapshot state and generate summary
6. **PostCompact**: Restore context in new window
7. **SessionEnd**: Validate completion gates before exit

This ensures SDD state remains consistent across tool executions, context compactions, and multi-turn conversations.

## Directory Structure Reference

```
skills/spec-driven-development/
├── SKILL.md                 # Slim skill definition (~227 lines)
├── README.md                # Installation, usage, command reference
├── scripts/                 # 39 Bash scripts for lifecycle automation
│   ├── sdd-hook.sh         # SessionStart/UserPromptSubmit context loader
│   ├── sdd-scope-drift.sh  # PreToolUse scope violation detector
│   ├── sdd-cache-refresh.sh # PostToolUse artifact cache updater
│   ├── sdd-precompact.sh   # PreCompact state snapshotter
│   ├── sdd-stop-gate.sh    # SessionEnd completion validator
│   ├── sdd-task.sh         # Task state mutations (start/complete/block)
│   ├── sdd-close.sh        # Feature closure and result validation
│   └── [14 more scripts]
├── templates/               # Artifact scaffolds for .features/
│   ├── brief.md.template
│   ├── spec.md.template
│   ├── plan.md.template
│   └── [5 more templates]
├── references/              # Phase guides and reference docs
│   ├── phases/             # 7 phase methodology files
│   ├── artifacts.md        # Artifact specifications + work packages
│   ├── workers.md          # Worker dispatch guide + packet schema
│   └── worker-results.md   # Worker result contract + status taxonomy
├── agents/                  # Specialized subagents
│   ├── sdd-implementer.md
│   ├── sdd-spec-reviewer.md
│   └── [3 more agents]
└── docs/                    # Consolidated reference documentation
    └── plugin-architecture.md (this file)
```

### References Consolidation (0029)

The `references/` directory was audited and consolidated in feature 0029: 15 reference files reduced to 10 by merging orphaned topics into their primary documents and moving evaluation fixtures to `evals/`.

Current canonical reference files:
- `artifacts.md` — Artifact format specs + work package schema
- `phases/` — 7 phase-specific guides (one per phase)
- `workers.md` — Worker dispatch guide + packet schema
- `worker-results.md` — Worker result contract + status taxonomy
- `steering-core.md` — Canonical behavioral core (six rules, used by all surfaces)
- `trace-rules.json` — Trace coverage rules manifest
- `advisor-system-prompt.md` — Haiku system prompt for the rubric advisor (used by both pre-boundary and post-authoring hooks)
- `rubrics/` — 6 per-artifact rubric files consumed by `sdd advise` and the advisor hooks
- `customization-template.yaml` — Scaffold for `.sdd/customization.yaml`

Files previously in `references/` that were merged or relocated:
- Orphaned agent docs → merged into `workers.md`
- Evaluation fixtures → moved to `evals/`
- Redundant phase summaries → consolidated into `phases/*.md`

When adding new reference material, prefer extending an existing file over creating a new one. New files in `references/` require a corresponding entry in `SKILL.md`'s progressive disclosure table.

---

**Related Features**: 0004 (plugin conversion), 0017 (codebase hardening), 0018 (progressive disclosure), 0046 (skill-scoped hooks / self-gating architecture)
