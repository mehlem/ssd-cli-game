---
name: sdd-setup
description: Bootstrap Spec-Driven Development into this project. Installs the consumer skill copy, agents, hooks, CLI, manifest, gitignore entries, and CLAUDE.md instructions from the canonical plugin.
disable-model-invocation: true
argument-hint: "[--dry-run] [--force] [--install-shim] [--canonical <path>] [--json|--format text|json]"
allowed-tools:
  - Bash(bash *)
  - Read
  - Glob
  - Grep
---

# SDD Setup - Bootstrap Spec-Driven Development

Install SDD into the current project as a standalone consumer copy that works without keeping the plugin loaded.

## What gets installed

| Component | Location | Purpose |
|-----------|----------|---------|
| SDD consumer skill | `.claude/skills/spec-driven-development/` | SKILL.md, scripts, templates, references, docs, hooks support files, and current methodology surface |
| 6 agents | `.claude/agents/sdd-*.md` | Implementer, spec reviewer, quality reviewer, research scout, plan drafter, and role-pack support |
| Help skill | `.claude/skills/sdd-help/` | `/sdd-help` Q&A skill for routing SDD questions to the right docs |
| Setup skill | `.claude/skills/sdd-setup/` | `/sdd-setup` bootstrap skill for rerunning or upgrading the consumer install |
| Phase skills | `.claude/skills/sdd-{brief,spec,research,plan,implement,review,close}/` | Focused phase-local guidance chained from the main SDD router |
| Lifecycle hooks | `.claude/settings.json` | Context injection, advisor pre-boundary checks, advisor post-authoring checks, scope drift, agent guard, epic refresh, precompact, postcompact, stop gate, and session-end finalize |
| CLI shim | `.claude/bin/sdd` | Project-local `sdd` command |
| Feature scaffold | `.features/` and `.features/INDEX.md` | Feature workspace and regenerated index |
| Install manifest | `.claude/.sdd-manifest.json` and `.claude/.sdd-version` | File hashes and installed plugin version for safe upgrades |
| Git ignore entries | `.gitignore` | SDD-managed transient files: active logs, feature customizations, epic state, changes logs, and generated summaries |
| Project instructions | `CLAUDE.md` | Managed SDD block with current commands, gates, and plugin meta-development guidance |

## Steps

1. Run the setup command:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/sdd" setup $ARGUMENTS
```

2. Verify the installation by checking all components exist:

```bash
echo "=== Verification ==="
test -d .claude/agents && echo "Agents: $(ls .claude/agents/sdd-*.md 2>/dev/null | wc -l | tr -d ' ') installed" || echo "Agents: MISSING"
test -f .claude/skills/spec-driven-development/SKILL.md && echo "Skill: OK" || echo "Skill: MISSING"
test -f .claude/skills/sdd-help/SKILL.md && echo "Help skill: OK" || echo "Help skill: MISSING"
test -f .claude/skills/sdd-setup/SKILL.md && echo "Setup skill: OK" || echo "Setup skill: MISSING"
for skill in sdd-brief sdd-spec sdd-research sdd-plan sdd-implement sdd-review sdd-close; do
  test -f ".claude/skills/$skill/SKILL.md" && echo "$skill: OK" || echo "$skill: MISSING"
done
test -x .claude/bin/sdd && echo "CLI: OK" || echo "CLI: MISSING"
grep -q "sdd-setup:begin" CLAUDE.md 2>/dev/null && echo "CLAUDE.md: OK" || echo "CLAUDE.md: MISSING"
test -f .claude/settings.json && echo "Hooks: $(jq '.hooks | keys | length' .claude/settings.json 2>/dev/null) events" || echo "Hooks: MISSING"
test -d .features && echo ".features/: OK" || echo ".features/: MISSING"
test -f .features/INDEX.md && echo "INDEX.md: OK" || echo "INDEX.md: MISSING"
test -f .claude/.sdd-manifest.json && echo "Manifest: OK ($(jq '.files | keys | length' .claude/.sdd-manifest.json 2>/dev/null) files)" || echo "Manifest: MISSING"
test -f .claude/.sdd-version && echo "Version: OK" || echo "Version: MISSING"
test -f .claude/skills/spec-driven-development/scripts/sdd-record-close.sh && echo "record-close: OK" || echo "record-close: MISSING"
test -f .claude/skills/spec-driven-development/scripts/sdd-epic.sh && echo "epic: OK" || echo "epic: MISSING"
test -f .claude/skills/spec-driven-development/scripts/sdd-advise.sh && echo "advise: OK" || echo "advise: MISSING"
test -f .claude/skills/spec-driven-development/scripts/sdd-continuity-refresh.sh && echo "continuity-refresh: OK" || echo "continuity-refresh: MISSING"
```

3. If any checks fail, read setup output for the exact failed component and fix that cause before retrying.

## Flags

- `--dry-run` - Show what would be installed without writing files.
- `--force` - Overwrite user-modified files without backup.
- `--install-shim` - Install an opt-in user PATH shim that resolves the nearest project `.claude/bin/sdd`.
- `--canonical <path>` - Use an explicit canonical SDD plugin root, useful when recovering a partial consumer copy.
- `--json` / `--format text|json` - Emit machine-readable setup results or force text output.

## Next steps

- `sdd init <name> [--mode lite|full]` - Start a full feature or lite fix with the right artifact chain.
- `sdd status` - Inspect active feature, phase, tasks, trace state, and review status.
- `sdd customize init` - Create `.sdd/customization.yaml` for project-level guidance.
- `sdd autonomy {on|off|status}` - Manage autonomous execution for the active feature.
- `sdd epic init` - Coordinate migrations, rewrites, or initiatives that span multiple SDD features.
- `sdd advise <artifact> <feature>` - Run the rubric advisor on demand.
- `sdd record-close` - Record close evidence after review passes and close artifacts are finalized.

## Project customization

After setup completes, you can optionally initialize project-level customization:

```bash
sdd customize init
```

This creates `.sdd/customization.yaml` with 15 scope-keyed lists for shared guidance bullets: `global`, the 7 phases, the 6 subagent roles, and `learned`. Edit directly to add bullets. Run `sdd customize check .sdd/customization.yaml` to validate schema after edits.

## Upgrading

Running `/sdd-setup` again after a plugin update safely upgrades the installation because this skill invokes the canonical plugin entrypoint (`${CLAUDE_PLUGIN_ROOT}/bin/sdd`). For major setup-surface changes, do not rely on an old project-local `.claude/bin/sdd setup` command unless its shim already honors `CLAUDE_PLUGIN_ROOT`; invoke `/sdd-setup`, `bash "${CLAUDE_PLUGIN_ROOT}/bin/sdd" setup`, or pass through the updated canonical plugin. User-modified files are backed up to `.sdd-local-patches/` before overwriting unless `--force` is passed. Setup also prunes and refreshes SDD-owned hook entries, regenerates `.features/INDEX.md`, and updates the managed CLAUDE.md block when its version changes.
