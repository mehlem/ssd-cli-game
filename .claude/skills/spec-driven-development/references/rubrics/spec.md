# Spec Semantic Rubric

Score each dimension from 0-20. Total score determines the verdict.

## Dimensions

- **Problem grounding** (0-20): Does the spec clearly explain what problem is being solved and why the requirements exist?
  - 0-5: Problem section is missing, generic, or placeholder-like.
  - 6-12: Problem exists but is vague or disconnected from the requirements.
  - 13-20: Problem is concrete, user-facing, and clearly motivates the requirements.

- **FR clarity and smallest viable scope** (0-20): Are functional requirements concrete, implementation-agnostic, and limited to the requested behavior?
  - 0-5: FRs are placeholders, slogans, speculative extras, or hidden implementation steps.
  - 6-12: FRs exist but some are vague, compound multiple behaviors, or overreach beyond the stated problem.
  - 13-20: FRs are clear, atomic enough, and express the smallest viable required behavior.

- **AC testability and evidence quality** (0-20): Are acceptance criteria observable and testable?
  - 0-5: ACs are placeholders or not testable.
  - 6-12: Some ACs are testable, but others are ambiguous or weak on evidence.
  - 13-20: ACs are concrete and collectively define done in observable terms.

- **Scope discipline** (0-20): Does the spec stay in WHAT, not HOW?
  - 0-5: The spec is mostly implementation or task planning.
  - 6-12: Some design leakage exists, but intent is still recoverable.
  - 13-20: The spec stays focused on user-facing requirements and boundaries.

- **Ambiguity resolution** (0-20): Have key open questions been resolved enough to research safely?
  - 0-5: Major ambiguities remain hidden or unresolved.
  - 6-12: Some ambiguity remains, but the next phase can proceed only cautiously.
  - 13-20: Major ambiguities are resolved or explicitly bounded before research.

## Verdict

- **0-30**: HOLD — not ready for research.
- **31-69**: HOLD — requirements exist, but they are too weak or ambiguous.
- **70-100**: GO — strong enough to enter research.

## Output Contract

The semantic evaluator should return:

- `score`
- `verdict` (`GO` or `HOLD`)
- `reason` — 1-3 sentences grounded in the rubric
- `artifact_sha256`
- `evaluated_at`
