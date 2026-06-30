# Close Phase Guide

**Goal:** Wrap up cleanly — capture knowledge, finalize artifacts, leave no loose ends.
**Updates:** `.features/{{FEATURE}}/` all artifacts | **Gate:** No new scope; reopen requires `sdd reopen`.

## Phase Entry Contract

Invoke `/sdd-close` before running protected Close boundary commands or editing
Close-owned finalization state. Direct reads of this phase reference,
`SKILL.md`, or Close artifacts do not satisfy the routing latch. The latch
proves the agent routed through Close guidance; it does not prove close
correctness.

## The Iron Law of Close

**NO CLOSE WITHOUT VERDICT PASS AND AT LEAST ONE KNOWLEDGE GRADUATION (OR EXPLICIT EMPTY-KNOWLEDGE OPT-OUT).**

A feature closed without a passing review verdict skips the only independent quality gate. A feature closed with an empty `knowledge.md` wastes every non-obvious discovery from implementation — future contributors will rediscover the same gotchas from scratch. The escape hatch exists deliberately: when there genuinely is nothing to preserve, set `closed_with_empty_knowledge: true` in `continuity.md` frontmatter and proceed.

If you find yourself running `sdd close` before review.md shows `verdict: pass`, that's a sign the review hasn't actually finished — return to Review and validate each AC with evidence. If knowledge.md is empty and you made any non-obvious discovery, that's a sign the discovery is about to be lost — graduate it before close, or declare the explicit opt-out.

## Process

1. Verify `review.md` has `verdict: pass` — do not proceed without it.
2. Verify all tasks in `tasks.md` have `status: completed`.
3. Read `.features/{{FEATURE}}/scratchpad.md` — identify all findings worth preserving.
4. Graduate each durable fact from scratchpad → `KNOWLEDGE.md` (non-obvious discoveries, gotchas, decisions).
5. Before close, `.features/<id>/knowledge.md` must have at least one K-entry per non-obvious finding from research or implementation, OR `.features/<id>/continuity.md` frontmatter must declare `closed_with_empty_knowledge: true`.
6. Update all artifact statuses to `completed` in their frontmatter.
7. Confirm `.features/{{FEATURE}}/` artifacts are final and consistent.
8. Run `sdd close {{FEATURE}}` to finalize.
9. Ask the user before committing the close. If approved, create the close commit using `references/git-commits.md`.
10. Run `sdd record-close {{FEATURE}}` to write the close commit SHA and author date into `review.md`.
11. Ask whether to commit the record update now; if approved, run `sdd record-close --commit --sha <close-sha> {{FEATURE}}`.

## What belongs in KNOWLEDGE.md

Graduate findings that are:
- Non-obvious (would surprise a new contributor)
- Durable (still true next month)
- Reusable (applies to future features, not just this one)

Do not graduate: ephemeral notes, "I tried X and it failed", task-specific details.
Do not graduate task status, review verdicts, feature-local progress, or
anything that is not task status-independent durable fact knowledge.

## Scope gate

If user asks to add scope during Close:
> "This feature is closed. A new feature request should go through `sdd init`."

If user insists a fix is needed:
> "If this is a bug, it needs its own feature. Run `sdd init` with a bug description."

To reopen legitimately: `sdd reopen {{FEATURE}}` — this transitions back to Implement.

## Strategy

- Close is about knowledge transfer, not more building.
- A feature is only truly closed when future contributors can understand WHY decisions were made.
- If scratchpad has "→ KNOWLEDGE" prefixes, those are pre-identified graduation candidates.

## Artifacts to read

- `.features/{{FEATURE}}/scratchpad.md` — findings to graduate.
- `.features/{{FEATURE}}/review.md` — confirm verdict: pass.
- `.features/{{FEATURE}}/tasks.md` — confirm all completed.

## Maintenance

- Update frontmatter `status: completed` in brief.md, spec.md, research.md, plan.md, tasks.md, review.md.
- Write graduated findings to `KNOWLEDGE.md` with feature reference.
- Check `.features/<id>/knowledge.md` and `.features/<id>/continuity.md` before `sdd close`; use `closed_with_empty_knowledge: true` only when there are intentionally no knowledge entries to preserve.
- Record `close_commit:` and `closed_at:` in `review.md` via `sdd record-close {{FEATURE}}` after the user-approved close commit exists.

## Edge cases

- Not a git repo: `sdd close {{FEATURE}}` can still finalize artifacts, but `sdd record-close {{FEATURE}}` will fail until the feature is in a git work tree.
- Pre-commit hook failure: inspect and resolve the hook output, then retry the close commit and rerun `sdd record-close {{FEATURE}}`.
- Reopen then re-close: rerun the same flow. `sdd record-close` overwrites `close_commit:` and `closed_at:` with the new close commit values.

## Post-Close: Archive

After closing, generate archival documentation for future reference:

```
sdd archive {{FEATURE}}
```

This dispatches the `sdd-archivist` subagent to read all canonical artifacts and generate:
- **README.md** — narrative overview: what was built, why, key decisions, lessons learned
- **DOCS.md** — technical reference: architecture, file inventory, interface changes, known limitations

Archive is optional but recommended — it makes closed features useful as reference material instead of dead artifacts.

## Exit criteria

All artifacts have `status: completed`. KNOWLEDGE.md updated with graduated findings. Feature is finalized.
