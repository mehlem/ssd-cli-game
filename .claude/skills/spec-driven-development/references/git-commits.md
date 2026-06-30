# Git Commit Conventions

## Format

Close commits use Conventional Commits with the feature id as the scope and a `(close)` marker:

```text
<type>(<feature-id>): <subject> (close)
```

Use the full feature folder name as `<feature-id>`, for example `0055-close-commit-traceability`.

## Type

Default to `feat` unless the feature is clearly one of the recognized Conventional Commit types:

- `fix` for bug fixes.
- `refactor` for behavior-preserving restructuring.
- `docs` for documentation-only changes.
- `chore` for maintenance-only changes.
- `test` for test-only changes.

If `brief.md` has a frontmatter `type:` value matching one of those recognized types, use it. Otherwise choose the narrowest accurate type from the artifact content, with `feat` as the default.

## Subject

Derive the subject from `spec.md` frontmatter `title:` when present. Keep it imperative or noun-like, lowercase unless a proper noun requires capitalization, and keep the full subject line at 72 characters or less when practical.

If the title is too long, truncate the subject while preserving the feature id scope and `(close)` marker.

## Body

Use this body template for close commits:

```text
Feature: <feature-id>
Verdict: <verdict>
Tasks: <done>/<total>
Refs: .features/<feature-id>/review.md
```

`Verdict` should match `review.md` frontmatter. `Tasks` should summarize completed tasks from `tasks.md`.

## Examples

```text
feat(0055-close-commit-traceability): close commit traceability (close)

Feature: 0055-close-commit-traceability
Verdict: pass
Tasks: 10/10
Refs: .features/0055-close-commit-traceability/review.md
```

```text
fix(0053-lite-steering-alignment): align lite close steering (close)

Feature: 0053-lite-steering-alignment
Verdict: pass
Tasks: 8/8
Refs: .features/0053-lite-steering-alignment/review.md
```

## Record Commit

`sdd record-close --commit <feature>` may create a follow-up commit after the close commit has been recorded in `review.md`:

```text
chore(<feature-id>): record close sha <short-sha>
```

That follow-up commit records the close commit SHA and references `.features/<feature-id>/review.md`. It is opt-in; without `--commit`, `sdd record-close` leaves `review.md` dirty for the user to commit later.
