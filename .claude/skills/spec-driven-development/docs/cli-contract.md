# SDD CLI Contract

The SDD CLI is designed for two consumers:

1. humans working in a terminal
2. agents/scripts calling `bash .../scripts/sdd.sh <command>`

Text mode remains the default for humans. JSON mode is the deterministic machine path.

## Compatibility Guarantees

- Default `sdd phase` text output remains hook-compatible:
  - `feature: ...`
  - `phase: ...`
  - `source: ...`
  - `wp: ...` and related WP lines when present
- Single-feature `sdd status --json` keeps the legacy top-level payload fields so existing jq consumers do not break.
- Legacy verbs remain valid:
  - `sdd plan plan`
  - `sdd plan tasks`
  - `sdd plan both` (recognized but blocked with a precondition failure)

Canonical aliases are preferred for new callers:

- `sdd plan create`
- `sdd plan create-tasks`

`sdd plan create-all` remains a compatibility alias, but it is blocked with a precondition failure. Callers should use `sdd plan create` and then `sdd plan create-tasks` as separate steps.

## Common Flags

Available across the user-facing CLI:

- `--help`
- `--feature <id|auto>`
- `--format text|json`
- `--json`
- `--non-interactive`
- `--on-exists fail|overwrite|skip`

`sdd status` also supports explicit single-feature targeting without repeating `--feature auto`:

- `--current`
- positional alias: `sdd status current`

Read-oriented commands also support selectors:

- `--field <path>`
- `--jq '<expr>'`

Selectors operate on the full JSON envelope. Scalars print raw. Objects and arrays print JSON.

For `sdd status`, feature-scoped selectors such as `--field phase` require a single-feature target via `--feature <id|auto>` or `--current`. Overview mode remains available through plain `sdd status --json`.

## Feature Resolution

When a command targets a feature, resolution uses this precedence:

1. explicit positional feature or `--feature <id>`
2. selected feature from `.features/.active`
3. auto-detect from open, non-closed features

Commands report:

- `resolved_feature`
- `feature_path` / `data.feature_path` on path-aware commands
- `feature_dir` / `data.feature_dir` on path-aware commands
- `resolution_source`: `arg | selected | auto | none`

For mutating commands in machine mode, ambiguous auto-resolution fails instead of guessing.

Feature identity and feature storage are deliberately separate:

- `resolved_feature` and legacy `feature` fields remain the basename ID, for example `0008-index-refresh`.
- `feature_path` is the path relative to `.features`, for example `platform/search/0008-index-refresh`.
- `feature_dir` is the filesystem path, for example `.features/platform/search/0008-index-refresh`.
- `feature_group` is the containing group path or `null` / empty for flat features.

Selectors may be an exact nested path, a flat feature ID, an unambiguous basename, or an unambiguous numeric prefix. If a basename or prefix matches multiple features, commands return a blocked/ambiguous resolution instead of choosing one. Unsafe refs are rejected: absolute paths, traversal (`..`), hidden segments, empty `//` segments, backslashes, `wp-*` paths, and grouped-init segments that look like feature IDs.

Grouped creation is explicit:

```bash
sdd init index-refresh --group platform/search "Refresh search index lifecycle"
```

Normal `<feature-name>` remains slash-free kebab-case. The `--group` path is a safe relative container under `.features`; it does not create a separate feature or epic.

## Machine Mode

Machine mode is any of:

- `--json`
- `--format json`
- `--field ...`
- `--jq ...`
- `--non-interactive`

Rules:

- JSON mode writes only JSON to stdout
- prose guidance is encoded under `guidance`
- ANSI color is disabled
- prompt-driven overwrite paths must not block

Conflict policy in machine mode defaults to `fail` unless `--on-exists` is supplied explicitly.

#### Machine-Mode Behavioral Rules

When `--json` or `--non-interactive` is active:
- Commands **never prompt** — any situation that would require user input instead exits with the appropriate code
- Mutating commands (`init`, `spec`, `task start`, etc.) require an explicit `--feature <id>` or `--feature auto`; `auto` is only safe when exactly one feature is active
- Selector precondition errors (`--field` path not found, `--jq` expression fails) exit `7` with a JSON error envelope
- All human-readable guidance is emitted to **stderr**; stdout contains only the JSON payload

### Stderr Guidance in JSON Mode

When `--json` is active, the CLI emits the same instructional guidance (boundaries, gates, pitfalls) that text mode would show — but to **stderr** instead of stdout. This allows `jq` pipelines on stdout while Claude still receives behavioral steering:

```bash
sdd status --json | jq '.phase'          # stdout: clean JSON
                                          # stderr: phase rules and next moves
```

This applies to all commands that produce guidance output: `status`, `phase`, `check`, `review`, `task next`.

## Command Matrix

| Command family | Primary role | JSON mode | Selectors | Conflict policy | Notes |
|:---------------|:-------------|:----------|:----------|:----------------|:------|
| `help` | self-description | yes | yes | n/a | `sdd help --json` and `sdd <command> --help --json` expose the contract to agents |
| `phase` | read | yes | yes | n/a | default text output stays hook-compatible |
| `status` | read | yes | yes | n/a | supports `--current` / `status current` for explicit single-feature mode |
| `check` | read | yes | yes | n/a | text mode keeps operator-oriented readiness output |
| `handoff` | read | yes | yes | n/a | remains read-only; does not call `sdd status` |
| `summary` | derived read | yes | yes | n/a | may regenerate summaries, but JSON is built from local artifact state |
| `select` | selection | yes | yes | n/a | exception to strict targeting because it selects the target |
| `init` | mutate/create | yes | no | n/a | creates and selects a new feature; `--group <path>` creates `.features/<group>/<id>/` explicitly; fails on existing feature path |
| `spec`, `research`, `review` | mutate/scaffold | yes | no | yes | `--non-interactive` and `--on-exists fail|overwrite|skip` apply |
| `plan create`, `plan create-tasks` | mutate/scaffold | yes | no | yes | use these as separate plan boundaries |
| `plan create-all` | compatibility alias | yes | no | n/a | resolves to `plan both`, but returns `precondition` instead of scaffolding both artifacts |
| `task ...` | mutate/workflow | yes | no | n/a | grouped namespace retained for task lifecycle and management; `task list --all <feature>` is the list-only aggregate view for WP tasks |
| `task scope-refresh` | mutate/derived file | yes | yes | n/a | refreshes `task-scope.txt` from an in-progress task's current `Files:` field without changing task status |
| `task graph` | read/dependency | yes | yes | n/a | renders dependency DAG; JSON includes ready and blocked task lists |
| `trace refresh` | mutate/derived | yes | no | n/a | rebuilds trace.json from artifact frontmatter |
| `trace doctor` | read/diagnostics | yes | yes | n/a | reports suspect nodes and broken link chains |
| `trace coverage` | read/diagnostics | yes | yes | n/a | evaluates trace completeness against rules |
| `trace acknowledge` | mutate/audit | yes | no | n/a | clears suspect flags after operator review; requires `--confirmed`; `--reason <text>` recorded to `changes.log`; auto-runs `trace refresh` |
| `advise` | read/derived | yes | yes | n/a | runs the rubric advisor against `<artifact> <feature>`; non-blocking suggestions; set `SDD_ADVISOR_DISABLED=1` to suppress advisor hooks for the session |
| `customize init`, `customize check` | mutate/scaffold + read/diagnostics | yes | no | yes | `init` scaffolds `.sdd/customization.yaml` with 15 scope keys; `check [file]` validates schema (per-bullet ≤280 chars, per-key ≤50 bullets, ≤8 KB, known scope keys) and exits 4 on violation |
| `archive` | mutate/synthesis | yes | no | n/a | generates README.md and DOCS.md for closed features |
| `setup` | mutate/bootstrap | yes | no | n/a | installs SDD into current project; incremental and idempotent |
| `close`, `reopen` | mutate/lifecycle | yes | no | n/a | exit codes distinguish gate failures from conflicts |
| `scope refresh` | mutate/derived file | yes | no | n/a | refreshes `scope.txt` from `research.md` |
| `wp init`, `wp list` | create/read | yes | no | partial | `wp init` is additive only, does not destructively overwrite existing WP dirs, and may emit a non-blocking warning when the requested WP name is absent from plan.md decomposition text |

Selectors operate on the JSON envelope returned by the command. For read commands this is usually what agents want; mutating commands always return the full envelope in machine mode.

## Quality Gate Scopes

Delegated implementation batches should verify newly touched shell files with `sdd-quality-gate-test.sh --since <ref>`, where `<ref>` is the feature branch base chosen by the operator. This checks the batch's committed `.sh` changes and filters deleted files, keeping pre-existing warnings in unrelated files out of the delegated Done-When gate.

The unscoped `sdd-quality-gate-test.sh` invocation remains the operator's pre-merge invariant. It sweeps the full SDD script corpus and can still fail on historical warnings that a delegated batch is not authorized to fix.

## Status Shapes

`sdd status` intentionally has two machine-readable shapes.

Overview mode:

```json
{
  "ok": true,
  "command": "status",
  "resolved_feature": null,
  "resolution_source": "none",
  "phase": null,
  "data": {
    "features": [
      {"feature": "0001-user-auth", "phase": "implement"},
      {"feature": "0002-billing", "phase": "review"}
    ],
    "count": 2
  }
}
```

Single-feature mode via `--feature <id|auto>` or `--current`:

```json
{
  "ok": true,
  "command": "status",
  "resolved_feature": "0001-user-auth",
  "feature_path": "0001-user-auth",
  "resolution_source": "selected",
  "phase": "implement",
  "feature": "0001-user-auth",
  "tasks": {
    "completed": 3,
    "in_progress": 1,
    "pending": 2,
    "blocked": 0,
    "total": 6
  },
  "current_task": {
    "id": "T-004",
    "heading": "Refresh summaries"
  },
  "data": {
    "...": "single-feature payload is also nested here"
  }
}
```

Notes:

- Overview mode is for portfolio-style queries such as `--field data.count` or `--jq '.data.features[] | {feature, phase}'`.
- Feature-scoped selectors such as `--field phase`, `--field tasks.pending`, or `--field current_task.id` require `--feature <id|auto>` or `--current`.
- The single-feature form keeps the legacy top-level payload fields (`feature`, `tasks`, `current_task`, `artifact_map`, and related status fields) so older `jq` consumers keep working.
- Path-aware fields such as `feature_id`, `feature_path`, `feature_dir`, and `feature_group` are additive. For flat features, `feature_path == feature`.

WP-mode single-feature status and persisted `state.json` use aggregate task state:

- `tasks` totals aggregate every `wp-*/tasks.md`; `artifact_map.tasks` still reports whether root `tasks.md` exists.
- `task_source.mode` is `work_packages`, and `task_source.work_packages[]` carries per-WP task counts, phase, path, and `tasks_file`.
- `current_task` is selected from the active WP and includes `work_package`, `work_package_path`, `tasks_file`, and a disambiguating `display_ref` such as `WP-02/T-001`.
- `raw_phase` remains the parent artifact phase, while `effective_phase` and `execution_phase` report the WP-aware lifecycle phase used by hooks and operator guidance.
- Feature-local `state.json` mirrors the same WP aggregate fields so hooks do not need to re-run expensive discovery.

## JSON Envelope

Success:

```json
{
  "ok": true,
  "schema_version": 1,
  "command": "spec",
  "resolved_feature": "0001-user-auth",
  "resolution_source": "arg",
  "phase": "design",
  "data": {
    "action": "create",
    "file": ".features/0001-user-auth/spec.md"
  },
  "guidance": {
    "next": "...",
    "gate": "...",
    "pitfall": "..."
  },
  "warnings": []
}
```

Failure:

```json
{
  "ok": false,
  "schema_version": 1,
  "command": "spec",
  "resolved_feature": "0001-user-auth",
  "resolution_source": "arg",
  "phase": null,
  "error": {
    "type": "conflict",
    "message": "spec.md already exists",
    "details": {
      "path": ".features/0001-user-auth/spec.md",
      "policy": "fail"
    }
  },
  "warnings": []
}
```

## Semantic Exit Codes

| Code | Meaning |
|:-----|:--------|
| `0` | success |
| `2` | usage / parse error |
| `3` | target not found |
| `4` | precondition / readiness / gate failure |
| `5` | conflict / would-prompt / overwrite-policy failure |
| `6` | blocked / manual decision required |
| `7` | internal / verification / unexpected runtime failure |

The `error.type` field aligns with the same semantic class.

#### Exit Code Firing Conditions

| Code | Fires when |
|:-----|:-----------|
| `0` | Command completed successfully |
| `2` | Unknown subcommand, missing required argument, invalid flag value |
| `3` | Feature ID not found, artifact file missing when required |
| `4` | Phase precondition not met (e.g. spec attempted before brief exists), readiness gate holds |
| `5` | Artifact already exists and `--on-exists` policy is `fail` |
| `6` | Operation requires manual decision (e.g. unresolvable conflict, suspect trace gate) |
| `7` | Internal script error, unexpected state, verification assertion failed |

## Command Notes

- `sdd help --json` and `sdd <command> --help --json` provide self-description for agents.
- `sdd handoff` remains read-only and does not call `sdd status`.
- `sdd summary` may regenerate `summary.md` and `summary-compact.md`, but its JSON payload is built from local artifact state.
- `sdd init` and `sdd select` are the main exceptions to “strict target resolution” because they create/select the target themselves. `sdd init --group <path>` writes the nested canonical path to `.features/.active`; flat init keeps writing the flat ID.
- The dispatcher compatibility shim `sdd status-json` still maps to `sdd status --json`.
- Legacy `plan plan` and `plan tasks` still work. Legacy `plan both` and alias `plan create-all` remain recognized, but they now return `precondition` because semantic gating requires separate `plan create` and `plan create-tasks` boundaries.
- `wp init` does not support destructive overwrite of an existing work package directory; callers should treat that path as additive-only.
- `wp init` emits an alignment warning, not a blocking error, when `plan.md` has phase/WP-like decomposition lines but none match the requested kebab-case WP name.
- `task list --all <feature>` lists every WP task with WP attribution. Without `--all`, `task list`, `task next`, `task start`, `task scope-refresh`, and `task complete` remain active-WP scoped.

### Task Dependencies

#### Task Dependency Flags

`sdd task start` and `sdd task next` are dependency-aware:

- `sdd task next <feature>` — only returns tasks whose declared `Depends-on:` prerequisites are complete
- `sdd task start <feature> <T-xxx>` — exits `4` if any dependency is incomplete; pass `--force` to override
- `sdd task scope-refresh <feature> <T-xxx>` — requires the task to be `in-progress` and rewrites `task-scope.txt` from its current `Files:` field without resetting status
- `sdd task graph <feature> [--json]` — returns the full dependency DAG; JSON output includes `nodes`, `edges`, and `ready` list
- `sdd check tasks <feature>` — validates for cycles, missing IDs, and self-dependencies; exits `4` on violations

**tasks.md schema version 2** supports array syntax for dependencies:
```
- [ ] T-003 — Description
  - Depends-on: T-001, T-002
```
Legacy inline CSV (`Depends-on: T-001,T-002`) is also accepted. Add `schema_version: 2` to tasks.md frontmatter to opt into strict parsing.

#### archive

Dispatches the `sdd-archivist` subagent to synthesize README.md (500–800 word narrative) and DOCS.md (technical reference) inside the feature folder. Feature must be in Close phase. Pass `--force` to overwrite existing archive docs.

#### setup

Installs agents, skill tree, hooks (`.claude/settings.json`), CLAUDE.md block, and `.features/` directory. Incremental on re-run — existing files are backed up with `.bak` suffix before overwrite. `--dry-run` prints planned actions without writing. JSON output (`--json`) includes `files_written`, `files_skipped`, `files_backed_up`, and `manifest_version`. Setup-managed `.gitignore` entries cover generated sidecars for both flat and nested features, including `.features/**/summary.md`, `.features/**/summary-compact.md`, `.features/**/changes.log`, and `.features/**/customization.yaml`.

## Examples

```bash
SDD="bash .claude/skills/spec-driven-development/scripts/sdd.sh"

$SDD phase --json
$SDD status --json
$SDD status --current --json
$SDD status --current --json --field phase
$SDD status --json --feature auto --field phase
$SDD spec --json --feature auto --non-interactive --on-exists overwrite
$SDD plan create --json --feature auto
$SDD help --json
```

## Additive JSON Fields (0034)

The following fields were added by feature 0034 (Feature Description Metadata). All are additive — existing fields are unchanged.

### `sdd index --json` feature objects

| Field | Type | Added in |
|:------|:-----|:---------|
| `description` | string | 0031 (unchanged) |
| `description_long` | string or null | 0034 |
| `description_source` | string | 0034 |
| `description_long_source` | string or null | 0034 |

### `sdd status <feature> --json`

| Field | Type | Added in |
|:------|:-----|:---------|
| `description.short` | string | 0034 |
| `description.long` | string or null | 0034 |
| `description.short_source` | string | 0034 |
| `description.long_source` | string or null | 0034 |

### `sdd handoff --json`

| Field | Type | Added in |
|:------|:-----|:---------|
| `data.description.short` | string | 0034 |
| `data.description.long` | string or null | 0034 |
| `data.description.short_source` | string | 0034 |
| `data.description.long_source` | string or null | 0034 |

### `sdd archive --json`

| Field | Type | Added in |
|:------|:-----|:---------|
| `data.description_short` | string | 0034 |
| `data.description_long` | string or null | 0034 |

### Allowed `short_source` values

`brief.short_description`, `brief.long_description`, `summary.goal`, `brief.motivation`, `brief.title`, `feature.id`

### Allowed `long_source` values

`brief.long_description`, `brief.motivation_vision`, `null`
