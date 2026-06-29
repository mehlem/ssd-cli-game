<!-- sdd-setup:begin sdd-setup-version:4 -->
## Spec-Driven Development

This project uses SDD, a 7-phase artifact-first workflow.
`WHY -> WHAT -> WHERE -> HOW -> DO -> VERIFY -> DONE`

**Before any feature work:**
1. Run `sdd status` to check active features and phases
2. Run `sdd init <name> [--mode lite|normal|deep]` to start a feature with the right profile (`default` and `full` are accepted synonyms for `normal`)
3. Follow the phase gates: Brief → Design → Research → Plan → Implement → Review → Close

**Key commands:**
- `sdd status` — current feature dashboard
- `sdd init <name> [--mode lite|normal|deep]` — create normal/deep features or lite fixes
- `sdd task list <feature>` — pending tasks
- `sdd task start <feature> <T-xxx>` — begin a task
- `sdd task complete <feature> <T-xxx>` — finish a task
- `sdd autonomy {on|off|status}` — manage per-feature autonomous execution
- `sdd customize init` — scaffold project-level SDD guidance
- `sdd epic init` — coordinate multi-feature initiatives; details live in `references/epic.md`
- `sdd advise <artifact> <feature>` — run the rubric advisor on demand
- `sdd handoff` — session handoff summary

**Behavioral core:**
- Surface ambiguity before choosing an interpretation.
- Read files before making claims about the codebase.
- Prefer the smallest viable change that solves the current task.
- Keep edits surgical and avoid drive-by cleanup.
- Treat done as verified evidence, not asserted completion.
- If a command fails or a precondition blocks you, inspect the evidence before retrying.

**Artifact chain:** `.features/<id>/brief.md → spec.md → research.md → plan.md → tasks.md → review.md`

Do not write production code until `tasks.md` is populated. Do not close without review passing.

**5th Non-Negotiable Boundary:** non-trivial work needs independent review before close; implementer self-review is not enough.

**Backup path:** user-edit backups land at `<project>/.sdd-local-patches/<UTC-ts>/`. Older installs may have backups under `.claude/.sdd-local-patches/`; those remain in place — setup never moves or removes them.

**Meta-development of the SDD plugin itself:** when editing files under `sdd-plugin/`, launch Claude with `claude --plugin-dir ./sdd-plugin`. This routes hooks through canonical source — without it, hooks run from the consumer copy at `.claude/skills/spec-driven-development/` and will not see your edits until `sdd setup` is re-run.
<!-- sdd-setup:end -->
