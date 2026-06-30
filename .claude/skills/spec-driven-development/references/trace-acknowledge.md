# Trace Acknowledge

`sdd trace acknowledge <feature> [ARTIFACT-ID...]` is the canonical clearing path for the suspect gate. It restamps `based_on` hashes in suspect artifact frontmatter, records a structured audit entry, auto-runs `sdd trace refresh`, and is the only escape that preserves an audit trail of operator verification.

This reference documents the command surface, the `--confirmed` guard, the `--reason` annotation, the changes.log entry shape, and the contrast with `--force`.

## When You Need It

The trace graph marks a downstream artifact `suspect: true` when an upstream artifact's revision hash drifts from the `based_on` hash recorded in the downstream's frontmatter. Concretely: you edit `spec.md` after `research.md` has already been derived from it. The trace flags `research.md`, `plan.md`, and `tasks.md` as suspect. `sdd task start` then refuses to begin work — protection against silent execution of stale-derived work.

You need a clearing path because:

- `sdd trace refresh` only re-evaluates the graph against current artifact hashes — it does **not** modify `based_on` in the downstream frontmatter, so the suspect flags persist after refresh.
- Re-scaffolding (`sdd spec --on-exists overwrite`) destroys hand-authored content. It is strictly worse than the suspect bug.
- `sdd task start --force` works but leaves no record of what the operator verified. Useful for one-off urgent overrides; abusive at scale.

`sdd trace acknowledge` is the operator's "I have read the upstream change and verified that the downstream artifact already incorporates it" signal, recorded persistently.

## Command Syntax

```bash
sdd trace acknowledge <feature> --confirmed
sdd trace acknowledge <feature> [ARTIFACT-ID...] --confirmed [--reason <text>]
sdd trace acknowledge <feature> --feature auto --confirmed
```

- **No `ARTIFACT-ID`** → all currently-suspect artifacts in the feature are acknowledged.
- **One or more `ARTIFACT-ID`s** → only the named artifacts are acknowledged. IDs that aren't currently suspect are skipped with a notice on stderr (no failure).
- **`--confirmed`** is required for any write. Without it, the command runs in dry-run shape and exits 4 (precondition).
- **`--reason <text>`** is optional but strongly recommended — it is recorded in `changes.log` and is the audit trail's most useful field.
- **`--feature auto`** resolves the feature via the active pin or sole-active heuristic.

Exit codes follow the standard machine contract: `0` on successful write, `2` on usage error, `3` on missing feature, `4` on precondition (e.g., missing `--confirmed`), `7` on internal failure (e.g., artifact resolution mismatch).

## The `--confirmed` Guard

Without `--confirmed`, the command prints what **would** be restamped and exits non-zero. This is a deliberate two-step pattern: the operator first inspects the proposed changes, then re-runs with `--confirmed` to commit.

Dry-run output:

```
Would restamp RESEARCH-0049: based_on.SPEC-0049 sha256:older… -> sha256:newer…
Would restamp PLAN-0049: based_on.SPEC-0049 sha256:older… -> sha256:newer…
Would restamp PLAN-0049: based_on.RESEARCH-0049 sha256:older… -> sha256:newer…
Would restamp TASKS-0049: based_on.PLAN-0049 sha256:older… -> sha256:newer…
```

The dry-run shape lets you confirm the diff is what you expect before writing it. Each line shows `target → upstream` with the old and new hashes.

## The `--reason` Annotation

`--reason "<text>"` writes a free-text rationale into the `changes.log` entry. The text is preserved verbatim. Examples that age well:

- `--reason "spec.md FR-008 wording clarification — research.md affected files map already covers the new wording"`
- `--reason "added FR-015 mid-flight; T-014 task added in same commit; tasks.md already implements FR-015"`

Examples that age poorly:

- `--reason "fixed"` — gives a future investigator nothing.
- `--reason "approved"` — what was approved, by whom, against what evidence?

Treat the reason field as a comment on a commit: the future reader is the audience.

## changes.log Entry Format

`changes.log` is an append-only NDJSON (one JSON entry per line, prefixed with timestamp and event tag). Each `trace acknowledge` invocation appends one line:

```
2026-04-28T16:32:03Z | trace_acknowledge | {"timestamp":"2026-04-28T16:32:03Z","event":"trace_acknowledge","acknowledged":["RESEARCH-0049","PLAN-0049","TASKS-0049"],"upstreams":["BRIEF-0049","SPEC-0049","RESEARCH-0049","PLAN-0049"],"reason":"...operator-supplied text..."}
```

Fields:

| Field | Meaning |
|:------|:--------|
| `timestamp` | UTC ISO 8601 timestamp of the acknowledgement |
| `event` | always `trace_acknowledge` |
| `acknowledged` | array of artifact IDs whose `based_on` was restamped this invocation |
| `upstreams` | union of upstream IDs referenced by the acknowledged artifacts |
| `reason` | the `--reason <text>` value, or empty string if omitted |

The log is purely additive — entries are never overwritten or removed. To replay an acknowledgement decision, grep `changes.log` for `trace_acknowledge` events and read the `reason` field.

## What the Command Does (Order of Operations)

1. **Resolve feature** via positional arg, `--feature auto`, or active pin.
2. **Refresh trace** (the same logic as `sdd trace refresh`) so the suspect set is computed from current artifact hashes, not a stale graph.
3. **Identify targets**: all suspect artifacts (default) or only the explicitly listed `ARTIFACT-ID`s. Non-suspect IDs are skipped with notice.
4. **Dry-run print** if `--confirmed` is absent → exit 4.
5. **For each target**: read upstream IDs from the artifact's existing `based_on` map, compute each upstream's current revision hash from `trace.json`, and write the new `based_on` map back into the artifact's frontmatter via `sdd_stamp_based_on`.
6. **Append** a `trace_acknowledge` entry to `.features/<feature>/changes.log`.
7. **Auto-run `sdd trace refresh`** so the operator immediately sees the updated graph (typically `cleared = N` previously-suspect nodes).
8. **Print** a summary: `acknowledged N artifact(s); cleared M suspect node(s)`.

The atomic boundary is per-artifact frontmatter write; the changes.log entry and the auto-refresh happen after all writes succeed.

## Contrast with `--force`

`sdd task start --force <feature> <T-xxx>` bypasses the suspect gate without modifying any artifact. It exists for legitimate one-off cases (urgent fix, the operator knows the staleness is benign, the cost of acknowledging exceeds the value).

When to prefer `--force`:

- The suspect is on a single task and you know the upstream change is irrelevant to that task's scope.
- You're mid-investigation and just want to read a verification command's output once.

When to prefer `acknowledge`:

- You've actually verified the downstream incorporates the upstream change. Record it.
- You're going to run `sdd task start` more than once on this feature this session.
- The audit trail will matter to a future investigator (closed feature, regulated context, multi-operator workflow).

A feature audit that shows `--force` 13 times is much harder to interpret than one that shows three `trace_acknowledge` entries with reasons.

## Related

- `references/trace-coverage.md` — evaluates the trace against rules; orthogonal concern.
- `docs/artifacts-and-state.md` — Trace Graph & Provenance section for the underlying suspect propagation model.
- `sdd-plugin/skills/spec-driven-development/scripts/sdd-trace.sh` — `cmd_acknowledge` is the implementation; consult when the contract documented here is unclear.
