# Hook Architecture

The SDD plugin registers all of its hook handlers at the plugin level (in `sdd-plugin/hooks/hooks.json`) and uses early self-gating to stay silent in non-SDD sessions. This reference documents the architecture decision (why plugin-level rather than skill-frontmatter), the `sdd_has_active_feature` predicate that gates each handler, and the convention every new hook script must follow.

## The Decision: Plugin-Level + Self-Gating

**Decision.** All hook handlers live in `sdd-plugin/hooks/hooks.json`. None are moved to `SKILL.md` frontmatter `hooks:` blocks or to project-level `.claude/hooks/`.

**Why not skill-frontmatter `hooks:`?** Two issues found by feature 0046's research phase:

1. **Confirmed bug [GH#40630](https://github.com/anthropics/claude-code/issues/40630)** — skill-frontmatter `hooks:` are NOT forwarded to forked subagents. Behavior with `skills:`-preloaded subagents is undocumented.
2. **Compaction-survival** of skill-frontmatter hooks is undocumented.

SDD subagents (`sdd-implementer`, `sdd-spec-reviewer`, etc.) routinely author canonical artifacts (`spec.md`, `research.md`, `plan.md`, `tasks.md`, `review.md`). If authoring-related hooks (scope drift, advisor pre-boundary, advisor post-authoring, stop gate) ran on the controller but not on subagents, coverage would silently drop on the very surfaces SDD steers most. The risk was deemed unacceptable.

**Why not project `.claude/hooks/`?** That path is for users to add their own hooks per project. The SDD plugin ships handlers as part of its installable surface; bundling them with the plugin keeps `sdd setup` idempotent and avoids leaking SDD machinery into a project's user-controlled config.

**The cost of staying plugin-level.** ~2 extra microsecond-process-spawns per relevant lifecycle event in non-SDD sessions (one per matched handler). The cost is debug-log noise, not user-facing. The early self-gate eliminates substantive work before any meaningful processing happens.

## The `sdd_has_active_feature` Predicate

Defined in `sdd-plugin/skills/spec-driven-development/scripts/sdd-lib.sh`. The contract:

```bash
sdd_has_active_feature
# returns 0 (true) if any feature in .features/ is "active";
# returns 1 (false) otherwise (no .features/ dir, no features, all closed/abandoned/etc.)
```

A feature is **active** iff:

1. The feature directory exists under `.features/`, AND
2. The feature is not inactive per `sdd_feature_is_inactive` — i.e., its `continuity.md` frontmatter `status` is not in `{completed, abandoned, superseded}`. Missing `continuity.md` or missing `status` field is treated as active by default, AND
3. The feature's phase (read from `state.json` via `sdd_feature_phase`) is not `close`.

The predicate scans `.features/*/`. Returns `0` on the first match — short-circuits, so cost stays flat at "first active feature found" regardless of repo size. Returns `1` only if every feature directory is non-active.

**Edge case the predicate fixes**: prior to feature 0046, a feature with `state.json.phase = design` but `continuity.md.status = superseded` was reported as "active" by some hook checks. The composed predicate excludes this case correctly — both signals must point to "active" for the feature to count.

### Consumers

- Every plugin hook handler calls `sdd_has_active_feature` near its top and exits 0 silently when it returns false.
- CLI commands that need to know whether SDD is "live" in this repo also use it (e.g., `sdd status` for the no-argument rollup).
- The SubagentStart hook uses it to decide whether to inject the SDD context block into a subagent's dispatch packet.

Do not duplicate the composition. New hook scripts must call `sdd_has_active_feature` rather than re-implementing the two-signal rule.

## The Two-Signal Rule

A feature's "active-ness" is determined by combining two independent signals:

| Signal | Source | Valid "active" values |
|:-------|:-------|:----------------------|
| Phase | `state.json.phase` (or detected from disk via `sdd-phase.sh`) | anything except `close` |
| Lifecycle status | `continuity.md` frontmatter `status` field | unset, `active`, or any value not in `{completed, abandoned, superseded}` |

Both signals must agree on "active" for the feature to count. Phase alone is insufficient because a feature may be force-closed mid-implement (status set to `abandoned` while phase remains `implement`). Status alone is insufficient because a feature may be in `close` phase with no terminal status set yet.

The two-signal rule explicitly tolerates missing data: a brand-new feature with no `continuity.md` is active by default; a feature with `continuity.md` but no `status` field is active by default. Inactivity is a positive assertion.

## Self-Gating Convention

Every new plugin hook script must:

1. Source `sdd-lib.sh` to import the predicate.
2. Call `sdd_has_active_feature` near the top of the script.
3. Exit 0 silently when the predicate returns false.

Skeleton:

```bash
#!/usr/bin/env bash
# Plugin hook handler — gates on active feature presence.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sdd-lib.sh
. "$SCRIPT_DIR/sdd-lib.sh"

# Self-gate: silent in non-SDD sessions
sdd_has_active_feature || exit 0

# … handler-specific work below …
```

Do not check for `.features/` existence directly; do not parse `state.json` inline; do not call `sdd_feature_status` and `sdd_feature_phase` separately. The predicate is the contract; consumers depend on its semantics, not on the underlying composition.

## Hook Registration (`hooks.json`)

`sdd-plugin/hooks/hooks.json` registers handlers against Claude Code lifecycle events. Each entry names the event, optionally a matcher (e.g., `Edit|Write` for tool-use events), and the script to run with `${CLAUDE_PLUGIN_ROOT}` substitution.

Lifecycle events currently covered:

- `SessionStart` (`startup|resume|compact`) — context injection via `sdd-hook.sh`
- `UserPromptSubmit` — heartbeat refresh
- `PreToolUse` (`Edit|Write`) — scope drift detection
- `PostToolUse` (`Bash|Edit|Write`) — cache refresh
- `PostToolUseFailure` (`Bash|Edit|Write`) — failure capture
- `PreCompact` / `PostCompact` — continuity snapshot and recovery
- `SubagentStart` / `SubagentStop` — dispatch packet injection and result validation
- `SessionEnd` — completion gate via `sdd-stop-gate.sh`
- Advisor hooks (pre-boundary, post-authoring) — rubric advisor invocations

The total handler count is fixed (no handlers are conditionally registered). All scoping is done via the self-gate, not via hook-config conditionals. This keeps `hooks.json` declarative and makes "is this hook active?" a question answerable from the script body, not from cross-referencing config.

## Why Not Conditional Hook Registration?

Claude Code's hook system supports `if:` predicates on registrations. We considered using them to disable handlers when no active feature exists. We chose not to because:

- The predicate logic (`sdd_has_active_feature`) is already in bash, in `sdd-lib.sh`. Duplicating it in JSON `if:` expressions creates two sources of truth.
- Some hooks (the SubagentStart packet injection in particular) need to read feature state to do their work — they were going to source `sdd-lib.sh` anyway. Adding the gate at the top costs nothing extra.
- Self-gating keeps the script standalone-runnable for testing: `bash hooks/some-hook.sh < input.json` works whether or not SDD is "live", which is useful for regression tests.

## Related

- `sdd-plugin/skills/spec-driven-development/scripts/sdd-lib.sh` — the predicate's implementation (search for `sdd_has_active_feature`)
- `docs/plugin-architecture.md` (Self-Gating Architecture section) — the user-facing summary of this decision
- `.features/0046-sdd-skill-scoped-hooks/` — the feature that introduced the predicate and the architecture decision record
