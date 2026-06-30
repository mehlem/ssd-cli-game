# SDD Profiles

SDD has three user-facing profile tiers: `lite`, `normal`, and `deep`. They share the same behavioral core, task gate, scope discipline, review verdict gate, scratchpad/continuity recovery, and AC-to-review validation. They differ in artifact ceremony, phase shape, and evidence expectations.

`normal` is the user-facing label for the historical `full` profile. The persisted `state.json.profile` value remains `full` for backward compatibility.

## Profile Selection

Pick the profile at `sdd init` time and announce it in one short line.

Use `lite` when the request is clearly one of:

- Bug fix.
- Single-area improvement.
- Refactor without behavior change.
- Performance tweak.
- Documentation or configuration update.
- Small addition to a well-trod path.

Use `normal` when the request includes any of:

- Net-new user-facing behavior.
- Multi-component change.
- Data model change or migration.
- Auth, billing, payments, or similarly sensitive paths.
- Work likely to span more than two days or multiple sessions.

Use `deep` when the work is high-complexity or high-risk and needs the normal seven-phase chain plus stronger contracts, such as:

- Multiple independent research domains.
- Architecture or migration decisions with high blast radius.
- Parallel worker exploration before planning.
- Must-have end-state guarantees that should gate implementation.
- Plan-check and dual-reviewer evidence before close.

Ask before scaffolding when the signals conflict or the risk/scope is ambiguous.

## Command Contract

```bash
sdd init <name> --mode lite "description"
sdd init <name> --mode normal "description"
sdd init <name> --mode default "description"  # synonym for normal
sdd init <name> --mode full "description"     # legacy synonym for normal
sdd init <name> --mode deep "description"
sdd init <name> "description"                 # defaults to normal/full
```

CLI input accepts `lite`, `normal`, `default`, `full`, and `deep`.

Persisted `state.json.profile` accepts only:

| Input | Persisted value | Display label |
|:------|:----------------|:--------------|
| `lite` | `lite` | `lite` |
| `normal` | `full` | `normal` |
| `default` | `full` | `normal` |
| `full` | `full` | `normal` |
| omitted | `full` | `normal` |
| `deep` | `deep` | `deep` |

Missing or unrecognized persisted `profile` values continue to resolve as `full` through `sdd_profile`.

## Artifact Sets

| Artifact | Normal (`full`) | Deep | Lite | Notes |
|:---------|:----------------|:-----|:-----|:------|
| `brief.md` | yes | yes | no | Lite captures problem context in `spec.md`. |
| `spec.md` | yes | yes | yes | Lite uses `templates/spec-lite.md`. |
| `research.md` | yes | yes | no | Deep requires explicit research depth and scout summary evidence. |
| `plan.md` | yes | yes | no | Deep requires must-haves and an architectural-decision register. |
| `tasks.md` | yes | yes | yes | Deep requires worker strategy and files-in-scope per task. |
| `review.md` | yes | yes | yes | Deep requires plan-check and dual-reviewer evidence before pass. |
| `scratchpad.md` | yes | yes | yes | Same recovery behavior. |
| `continuity.md` | yes | yes | yes | Same compaction/handoff behavior. |
| `knowledge.md` | yes | yes | yes | Same close-phase graduation target. |
| `scope.txt` / `task-scope.txt` | yes | yes | yes | Same scope-drift discipline. |
| `trace.json` | yes | yes | no | Deep receives at least normal trace-rule coverage. |
| Archive output | yes | yes | no | `sdd archive` refuses lite features. |

## Phase Shape

| Profile | Phases |
|:--------|:-------|
| Normal (`full`) | Brief -> Design -> Research -> Plan -> Implement -> Review -> Close |
| Deep | Brief -> Design -> Research -> Plan -> Implement -> Review -> Close |
| Lite | Spec -> Implement -> Review -> Close |

Deep mode does not add, remove, or reorder phases. It strengthens readiness and review evidence inside the same seven-phase lifecycle.

Lite remains in Spec until:

- `spec.md` has at least one real `FR-NNN` and one real `AC-NNN`.
- `tasks.md` has non-placeholder `## Approach` content.
- `tasks.md` has at least one concrete `## T-NNN` task.

Then the existing implement/review/close gates apply.

## Script Behavior

- `sdd check all` checks profile-specific required artifacts.
- `sdd close` uses the same readiness gate for all profiles, plus deep-only review evidence checks for deep features.
- `sdd spec`, `sdd research`, and `sdd plan` are normal/deep-only and refuse lite features.
- `sdd archive` is normal/deep-only and refuses lite features.
- `sdd status`, `sdd handoff`, and SessionStart context render `full` as `normal`.
- `sdd init --mode deep` is the only deep-mode entry point in v1.

## Deep Contracts

Deep mode extends normal-mode gates; it does not replace them.

- Research must record a `research_depth` marker and a parallel-scout summary.
- Plan must record observable must-haves and architectural decisions.
- Tasks must record worker strategy and files in scope per task.
- Review must record plan-check evidence and both `sdd-spec-reviewer` and `sdd-quality-reviewer` evidence before `verdict: pass`.
- Review steering names both reviewers for deep features regardless of normal-mode size thresholds.

Controller sessions own phase transitions, canonical artifact mutations, and subagent orchestration. Subagents do not dispatch other subagents.

## Compatibility

Existing features are not migrated. A feature with `state.json.profile: "full"` remains persisted as `full`, while user-facing output renders `normal`.

`INDEX.md` does not display profile in v1. The active profile is exposed through `sdd status`, `sdd handoff`, and SessionStart context.

There is no `sdd profile upgrade` command in v1. To use deep mode, scaffold a new feature with `sdd init --mode deep`.
