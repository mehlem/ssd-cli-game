# Tasks Semantic Rubric

Score each dimension from 0-20. Total score determines the verdict.

This rubric is additive guidance for implement-phase quality. It does not create a new semantic sidecar or hard gate by itself.

## Dimensions

- **Scope clarity** (0-20): Does each task make its in-scope outcome and file boundary explicit?
  - 0-5: Scope is vague, placeholder-like, or mixes multiple unrelated outcomes.
  - 6-12: Scope exists, but some tasks still rely on implied boundaries.
  - 13-20: Tasks make the intended outcome and file boundary explicit enough to avoid drift.

- **Smallest viable outcome** (0-20): Is each task sized to the smallest meaningful slice?
  - 0-5: Tasks are mini-projects or bundle unrelated work.
  - 6-12: Some tasks are implementable, but others are broader than necessary.
  - 13-20: Tasks are small, outcome-focused, and avoid speculative scope.

- **Verification strength** (0-20): Does each task tie completion to runnable evidence?
  - 0-5: Verification is missing, placeholder-like, or not runnable.
  - 6-12: Verification exists, but it is weak, ambiguous, or detached from the task outcome.
  - 13-20: Verification is concrete enough that task completion means verified evidence, not just edits.

- **Ambiguity and blocker handling** (0-20): Do tasks surface what is unknown or blocking instead of inviting guessing?
  - 0-5: Ambiguity is hidden and blocker states are absent.
  - 6-12: Some uncertainty is implied, but the safe next move is unclear.
  - 13-20: Tasks expose ambiguity, dependencies, or blockers clearly enough to support disciplined execution.

- **Surgical change boundary** (0-20): Do tasks encourage focused edits instead of drive-by cleanup?
  - 0-5: Tasks invite adjacent cleanup, broad refactors, or unclear file churn.
  - 6-12: Boundaries exist, but some tasks still leave room for speculative cleanup.
  - 13-20: Tasks reinforce focused, traceable changes tied to the named outcome.

## Verdict

- **0-30**: HOLD — task quality is too weak to support disciplined implementation.
- **31-69**: HOLD — tasks exist, but scope, verification, or ambiguity handling is still too soft.
- **70-100**: GO — tasks are strong enough to support implement-phase execution.

## Output Contract

When used by evals or reviewers, return:

- `score`
- `verdict` (`GO` or `HOLD`)
- `reason` — 1-3 sentences grounded in the rubric
