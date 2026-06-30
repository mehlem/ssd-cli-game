# Codex Delegation

SDD can treat Codex as an optional worker provider while keeping SDD artifacts,
phase policy, worker ledgers, prompt templates, and review authority as the
source of truth. Codex is a runtime behind the SDD worker contract, not a
replacement for the SDD lifecycle.

## Command Surface

Use `sdd worker dispatch` to create provider-aware dispatch records:

```bash
sdd worker dispatch 0085-sdd-codex-delegation \
  --provider codex \
  --role research-scout \
  --dispatch-id codex-research-001 \
  --task-text "Inspect the Codex prompt template flow" \
  --json
```

Use `sdd-codex.sh render` to render the SDD-owned prompt without executing
Codex:

```bash
.claude/skills/spec-driven-development/scripts/sdd-codex.sh render \
  0085-sdd-codex-delegation \
  --role research-scout \
  --dispatch-id codex-research-001 \
  --template research \
  --task-text "Inspect the Codex prompt template flow" \
  --json
```

The rendered prompt includes:

- the SDD dispatch packet and `## Machine Dispatch Record`
- phase, role, feature, permission, scope, validation, output, and stop rules
- a dedicated `<custom_task>` section containing the operator request
- instructions to return a `## Machine Result Record`

Custom operator text must be inserted inside `<custom_task>`. It must not
replace SDD constraints, scope, validation, output format, or stop rules.

## Phase Policy

Codex dispatch follows SDD phase ownership before any provider run:
Brief and Close are controller-owned and are refused.

| Phase | Default policy |
|:------|:---------------|
| Brief | refused; controller owns intent capture |
| Research | read-only |
| Plan | read-only |
| Implement | read-only by default; write mode requires active task and explicit file scope |
| Review | read-only support evidence |
| Close | refused; controller owns closeout |

Write-capable Implement dispatch requires both:

- an active SDD task in `tasks.md`
- explicit file scope in the dispatch packet

Missing Codex tooling is reported as `provider_unavailable` before a successful
dispatch/result record is written.

## Result Import

Import raw Codex output only through the worker command:

```bash
sdd worker import-result 0085-sdd-codex-delegation \
  --provider codex \
  --dispatch-id codex-research-001 \
  --file codex-output.md \
  --json
```

The raw output must contain exactly one `## Machine Result Record` JSON block
with `schema_version: "sdd-result-v1"`. SDD validates dispatch identity,
provider, role, status, changed files, notes, and recommendations before
persisting `.features/<feature>/workers/result-<dispatch-id>.json`.

Rejected imports do not corrupt existing worker records.

## Review Support

Codex review output is support evidence. Imported Codex reviewer-shaped records
are tagged `support_only: true` and surfaced in review adjudication under
support evidence, but they do not satisfy the required `spec-reviewer` or
`quality-reviewer` roles and cannot determine the review verdict by themselves.

The SDD review artifact remains authoritative. It still needs AC-by-AC evidence
and the normal Review verdict discipline.

## Setup And Mirrors

Canonical development happens in `sdd-plugin/skills/spec-driven-development/`.
Running `sdd setup` copies runtime Codex assets into the consumer skill:

- `scripts/sdd-worker.sh`
- `scripts/sdd-codex.sh`
- `templates/codex/*.md`
- `docs/codex-delegation.md`

Development tests under `scripts/tests/` stay canonical-only and are not copied
into the consumer skill. SDD does not vendor unrelated local Codex plugin
internals such as `/codex:task` commands or Codex companion JavaScript modules.
