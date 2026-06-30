# Trace Coverage

`sdd trace coverage <feature>` evaluates the feature's `trace.json` against the rules manifest at `references/trace-rules.json` and reports per-rule PASS / FAIL / SKIP, an overall score, and the specific gaps that caused any failure. This reference describes the rule taxonomy, the score calculation, the output shape, and how to read a gap line.

## When to use

- After scaffolding a downstream artifact (`sdd plan create`, `sdd plan create-tasks`, `sdd review`) — confirms the new artifact links upstream as expected.
- Before transitioning phases — `sdd check all <feature>` runs coverage as part of the phase-readiness gate.
- During review — coverage gaps frequently surface "FR-007 has no implementing task" or "AC-014 has no review row" findings before the human reviewer would catch them.
- When auditing a closed feature — coverage on a finished feature is a quick proof that the trace is complete.

## Command Surface

```bash
sdd trace coverage <feature>              # human-readable text output
sdd trace coverage --json <feature>       # machine-readable JSON
sdd trace coverage --feature auto         # resolve via active pin
sdd trace coverage --field score <feature># single-field selector
```

The command refreshes the trace before evaluating (no separate `sdd trace refresh` needed). Exit codes follow the standard machine contract: `0` on success regardless of rule outcomes (a 60% score is still success — the report is the value); `3` if the feature is not found; `4` if the feature has no trace data yet.

## Rule Taxonomy

Two rule families are defined in `references/trace-rules.json`:

### artifact_links rules

One rule per (artifact_type, link_type) pair. Each rule asserts that the artifact's frontmatter `links:` object contains the required typed parents.

Examples (drawn from current `trace-rules.json`):

| Rule | Asserts |
|:-----|:--------|
| `artifact.spec.derived_from` | Every `spec.md` has exactly one `derived_from: BRIEF-*` |
| `artifact.research.derived_from` | Every `research.md` has exactly one `derived_from: SPEC-*` |
| `artifact.plan.derived_from` | Every `plan.md` has at least one `derived_from: SPEC-*` or `RESEARCH-*` |
| `artifact.tasks.derived_from` | Every `tasks.md` has exactly one `derived_from: PLAN-*` |
| `artifact.review.derived_from` | Every `review.md` has exactly one `derived_from: SPEC-*` |

Each rule has `min` and (optionally) `max` constraints — a `min: 1` rule fails if zero links are present; a `max: 1` rule fails if more than one is present.

### body_fields rules

One rule per body-content relationship. Each rule asserts that body text in one artifact maps to body text in another via a typed mapping (`Implements`, `Addresses`, `Validates`, `Acceptance`).

Examples:

| Rule | Asserts |
|:-----|:--------|
| `plan.Addresses` | Every `FR-xxx` in spec.md has at least one PH-xx in plan.md mapping it via `Addresses:` |
| `plan.Acceptance` | Every `AC-xxx` in spec.md has at least one PH-xx in plan.md mapping it via `Acceptance:` |
| `task.Implements` | Every `T-xxx` in tasks.md declares at least one `Implements: ["FR-xxx"]` or `["AC-xxx"]` |
| `task.Depends-on` | If a task declares `Depends-on:`, the referenced T-xxx exists and the chain has no cycles |
| `review.Validates` | Every `AC-xxx` in spec.md has at least one validation row in `review.md` |

## Score Calculation

The score is the percentage of **applicable checks** that passed:

```
score = (checks_passed / applicable_checks) * 100
```

Where:

- An **applicable check** is one rule instance evaluated against one body item (e.g., the `task.Implements` rule generates one check per task — 13 tasks → 13 checks).
- A **check passes** if the rule's constraint is satisfied for that item.
- A rule is **SKIP** (and excluded from the score's denominator) if it doesn't apply to the current phase — e.g., `review.Validates` is SKIP until a `review.md` exists.

A rule with multiple item-level checks reports both an aggregate status (PASS / FAIL) and a `passed/applicable` count. The aggregate is FAIL if any check fails.

Threshold: there is no hard cutoff baked into v1. `sdd check all` reports the score and lists FAIL rules but does not block phase transitions on a low score (informational warning only). Operators decide what bar to enforce per project.

## Output Shape

### Text mode

```
Trace coverage for 0049-sdd-docs-sync
score: 87% (62/71 checks, 7 passed, 2 failed, 2 skipped rules)
PASS artifact.spec.derived_from (1/1)
PASS artifact.research.derived_from (1/1)
PASS artifact.plan.derived_from (1/1)
PASS artifact.tasks.derived_from (1/1)
SKIP artifact.review.derived_from (review artifact not yet present)
PASS plan.Addresses (13/14)
FAIL plan.Acceptance (14/15)
PASS task.Implements (13/13)
SKIP review.Validates (review.md not yet authored)
PASS task.Depends-on (1/1)
  - plan.Acceptance: AC-015 has 0 plan acceptance mapping(s) via validates (expected >= 1)
```

The first line is the score and rollup. Each rule prints one line. After the rule list, every gap from FAIL rules is printed indented as `  - <rule_id>: <gap_text>`.

### JSON mode

```json
{
  "action": "coverage",
  "trace_path": ".features/0049-sdd-docs-sync/trace.json",
  "rules_path": "references/trace-rules.json",
  "refreshed": true,
  "coverage": {
    "present": true,
    "score": 87,
    "summary": {
      "applicable_checks": 71,
      "checks_passed": 62,
      "rules_passed": 7,
      "rules_failed": 2,
      "rules_skipped": 2
    },
    "rules": [
      {
        "id": "plan.Acceptance",
        "status": "FAIL",
        "applicable": 15,
        "passed": 14,
        "gaps": [
          "AC-015 has 0 plan acceptance mapping(s) via validates (expected >= 1)"
        ]
      }
    ]
  }
}
```

The JSON shape is stable: each rule object always carries `id`, `status`, `applicable`, `passed`, and `gaps`. SKIP rules carry a `note` field explaining why (e.g., "review artifact not yet present").

## Reading Gap Output

A gap line has the form:

```
<rule_id>: <subject> has <actual_count> <relationship> via <field> (expected <constraint>)
```

Example: `plan.Acceptance: AC-015 has 0 plan acceptance mapping(s) via validates (expected >= 1)` reads as: "rule `plan.Acceptance` failed because `AC-015` (defined in spec.md) has zero PH-xx phases in plan.md that map it via `validates:`". The fix is to add `Acceptance: AC-015` to the relevant phase block in plan.md (or update the rule if the AC is intentionally reviewer-only).

For unresolved-reference gaps (e.g., `Unresolved reference: FR-001`), the most common cause is that a body-field mapping cites an ID that does not exist in the upstream artifact — usually a typo or a stale reference left after the upstream was edited. Re-grep the spec for the ID to confirm whether it exists.

## Integration

- `sdd check all <feature>` runs `sdd trace coverage` as one of three sub-checks (the others are `sdd check tasks` and the rubric advisor).
- `sdd review <feature>` auto-imports a "Trace Coverage" snapshot into the scaffolded `review.md` so reviewers see the current score and gaps without re-running the command.
- The hook system does not run coverage on every prompt — it runs on demand. Use `sdd trace coverage` interactively or as part of CI gates.

## Related

- `references/trace-rules.json` — the rules manifest itself
- `references/trace-acknowledge.md` — clearing suspect flags after upstream changes (different concern, same trace surface)
- `docs/artifacts-and-state.md` — Trace Graph & Provenance section for the underlying graph model
