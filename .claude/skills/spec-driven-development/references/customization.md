# Project Customization

`.sdd/customization.yaml` is the project-scoped channel for injecting human guidance into every SDD session. Bullets land in Claude's context at SessionStart, in subagent dispatch packets, and (for the `learned` scope) survive compaction via continuity recovery. Optional feature-level overlays let a single feature add bullets without polluting other features.

This reference documents the schema, the 15 known scope keys, merge semantics for project + feature files, the four supported interpolation tokens, the validation rules enforced by `sdd customize check`, and the dispatch-packet block agents see in practice.

## File Locations

| Path | Scope | Tracked in git? |
|:-----|:------|:----------------|
| `.sdd/customization.yaml` | Project — every feature, every session | Yes (committed; intended as shared team conventions) |
| `.features/<id>/customization.yaml` | Single feature — only when that feature is active | Gitignored by default (feature-local discoveries) |

The project file is created by `sdd customize init`. The feature file has no scaffolder — operators (or Claude) create it manually. Both files share the same schema.

## Schema

```yaml
schema_version: 1

notes:
  global: []
  brief: []
  design: []
  research: []
  plan: []
  implement: []
  review: []
  close: []
  research-scout: []
  plan-drafter: []
  implementer: []
  spec-reviewer: []
  quality-reviewer: []
  archivist: []
  learned: []
```

`schema_version: 1` is required and is currently the only supported version. `notes` holds 15 scope keys; each key's value is a list of strings (each string is one guidance bullet). All 15 keys are recognized; missing keys are treated as empty lists.

## The 15 Scope Keys

Three groups by activation logic:

### Always-on (1)

- **`global`** — Injected into every SessionStart and every subagent dispatch packet, regardless of phase or role. Use for project-wide invariants ("we use bun, not npm"; "production logs are in CloudWatch").

### Phase-scoped (7)

- **`brief`**, **`design`**, **`research`**, **`plan`**, **`implement`**, **`review`**, **`close`** — Injected only when the active feature is in that phase. Use for phase-specific reminders ("during implement, run `bun test:integration` after every code change in the auth module").

### Agent-role-scoped (6)

- **`research-scout`**, **`plan-drafter`**, **`implementer`**, **`spec-reviewer`**, **`quality-reviewer`**, **`archivist`** — Injected only into dispatch packets for that role. Use to give a specific subagent role context it would otherwise lack ("implementer: skip the linter step for `*.generated.ts` files").

### Claude-writable (1)

- **`learned`** — Bullets Claude captures mid-feature when discoveries should outlive the current session but don't yet warrant a knowledge.md entry. Survives compaction via continuity.md recovery. Use literal dates (e.g., `2026-04-28: …`) rather than `{{DATE}}`, since `{{DATE}}` would re-render to today every time the bullet is emitted.

## Merge Semantics

When both `.sdd/customization.yaml` and `.features/<id>/customization.yaml` exist, the active feature's bullets are concatenated onto the project's per-key bullets — feature-level entries appear after project-level entries in the injected text. There is no override semantics; both sets are visible. To remove a project-level bullet for a single feature, the operator must edit the project file (or accept that both bullets appear).

If only the project file exists, only project bullets are injected. If neither exists, the customization layer contributes nothing — agents and sessions behave exactly as without the feature.

## Interpolation Tokens

Four tokens are substituted at injection time (per-call, not per-file-read):

| Token | Substituted with | Example |
|:------|:------------------|:--------|
| `{{FEATURE}}` | active feature ID | `0049-sdd-docs-sync` |
| `{{FEATURE_ID}}` | numeric prefix only | `0049` |
| `{{PHASE}}` | active phase name | `implement` |
| `{{DATE}}` | UTC date as `YYYY-MM-DD` | `2026-04-29` |

A bullet like `When in {{PHASE}}, prefer X over Y` reads correctly to Claude as `When in implement, prefer X over Y`. Unknown `{{...}}` tokens emit a non-fatal warning during `sdd customize check` but do not block validation.

`{{DATE}}` is intentionally unsuitable for `learned` bullets — a `learned` entry preserved across sessions should reference the date it was discovered, not "today" each time it is rendered. Write the literal date.

## Validation Rules (`sdd customize check`)

`sdd customize check [file]` validates schema conformance. Without a path, the command checks both `.sdd/customization.yaml` and (if it exists) the active feature's `customization.yaml`.

Hard rules (exit 4 on any violation):

- `schema_version` must be `1`.
- Each `notes.<key>` must be a list of strings, not an inline string or a map.
- Per-bullet length: ≤ 280 characters.
- Per-key bullet count: ≤ 50 bullets.
- File size: ≤ 8 KB.
- Scope keys must come from the known set of 15. Unknown keys produce an error.

Soft rules (warning, exit 0):

- Unknown interpolation tokens (anything outside `{{FEATURE}}`, `{{FEATURE_ID}}`, `{{PHASE}}`, `{{DATE}}`) emit a stderr warning naming the token and file.
- Empty inline list items (`- ""`) emit an error in v1; reserved for future "always include" semantics.

The 8 KB / 50 bullet / 280 char limits are deliberately tight: customization is for terse, durable guidance — multi-paragraph context belongs in `KNOWLEDGE.md` or a phase guide.

## What Subagents See

Customization reaches subagents only via the dispatch packet — they start with empty conversation context. The packet is augmented at SubagentStart time with a single tagged block:

```
<project_customization>
[notes.global bullets, interpolated]
[notes.<agent_role> bullets, interpolated]
[notes.learned bullets, interpolated]
</project_customization>
```

Three slices appear: `global` (always), the role-specific slice (one of the 6 agent keys), and `learned` (always; this is how Claude's mid-feature discoveries reach a fresh subagent context). Phase-scoped slices are not injected into subagent packets — those are SessionStart-only, since the dispatch packet already carries the phase explicitly.

If neither `.sdd/customization.yaml` nor the feature-level file exists, the `<project_customization>` block is omitted entirely (not emitted as empty). Agents that find the block absent should not assume customization is "off" — they should not behave differently in either case. Project conventions that absolutely must reach subagents go in `global` or the agent-specific key.

## Usage Examples

### Project-wide convention

```yaml
notes:
  global:
    - "Production logs: CloudWatch group /prod/api. Local logs: bun run dev | jq."
    - "We test with vitest. bun test runs the suite; bun test:integration is the slow lane."
```

### Phase-scoped reminder

```yaml
notes:
  implement:
    - "Run bun typecheck before bun test — type errors hide test failures."
  review:
    - "AC tables in review.md must cite file:line, not summary text. Reviewers reject summaries."
```

### Agent-scoped guidance

```yaml
notes:
  research-scout:
    - "Auth code lives in src/auth/, not src/server/auth — the latter is deprecated."
  implementer:
    - "Skip linting for *.generated.ts; the generator owns formatting."
```

### Claude-writable learned bullet

```yaml
notes:
  learned:
    - "2026-04-28: bun test fails on macOS arm64 unless DYLD_FALLBACK_LIBRARY_PATH is set. See scratchpad."
```

## Related

- `references/customization-template.yaml` — the canonical scaffold copied by `sdd customize init`
- `sdd-plugin/skills/spec-driven-development/scripts/sdd-customize.sh` — implementation of init / check
- `docs/workflow-lifecycle.md` (Project Customization section) — usage in the lifecycle context
- `docs/subagent-delegation.md` (Project Customization Injection note) — packet-level injection details
