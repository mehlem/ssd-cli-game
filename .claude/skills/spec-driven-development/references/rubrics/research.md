# Research Semantic Rubric

Score each dimension from 0-20. Total score determines the verdict.

## Dimensions

- **File-map adequacy and scope discipline** (0-20): Do the affected files plausibly cover the work implied by the spec without drifting into unrelated areas?
  - 0-5: File map is empty, placeholder-like, or obviously incomplete.
  - 6-12: File map covers part of the work, but gaps or suspicious extra surface remain.
  - 13-20: File map plausibly covers the implementation surface and stays scoped to the feature.

- **Evidence grounding** (0-20): Does the research distinguish inspected fact claims from hypotheses?
  - 0-5: Claims are ungrounded, generic, or clearly based on memory.
  - 6-12: Some evidence exists, but facts, interpretations, and unknowns still blur together.
  - 13-20: Findings are grounded in inspected files and clearly separate confirmed fact claims, hypotheses, and unknowns.

- **Dependency coverage** (0-20): Are internal/external dependencies mapped?
  - 0-5: Dependencies are absent or guessed.
  - 6-12: Key dependencies are partially mapped.
  - 13-20: Dependencies and important interactions are explicit.

- **Failure and ambiguity awareness** (0-20): Are key failure modes, unknowns, or edge cases surfaced?
  - 0-5: Risks, unknowns, and edge cases are missing.
  - 6-12: Some common cases are identified, but notable uncertainty remains implicit.
  - 13-20: Important edge cases and open ambiguity are surfaced clearly enough for planning.

- **Planning readiness** (0-20): Is the research detailed enough to support the smallest viable plan slices?
  - 0-5: Planning would still be guesswork.
  - 6-12: Planning is possible, but risky due to missing context.
  - 13-20: Planning can proceed from concrete research fact claims without speculative leaps.

- **Parallel scout coverage** (0-20): Does deep-mode research summarize independent scout findings across the relevant domains?
  applies-to: deep
  - 0-5: Scout coverage is absent, single-threaded, or not tied to domains.
  - 6-12: Scout findings exist, but coverage gaps or synthesis gaps remain.
  - 13-20: Parallel scout results are summarized, reconciled, and mapped to planning decisions.

- **Research depth marker present** (0-20): Does deep-mode research explicitly mark and justify `research_depth: deep`?
  applies-to: deep
  - 0-5: The marker is missing or purely decorative.
  - 6-12: The marker exists, but the depth rationale is weak.
  - 13-20: The marker and rationale clearly explain why deep-mode evidence requirements are satisfied.

## Verdict

- **0-30**: HOLD — not ready for planning.
- **31-69**: HOLD — research exists, but it is too shallow or incomplete.
- **70-100**: GO — strong enough to enter planning.

## Output Contract

The semantic evaluator should return:

- `score`
- `verdict` (`GO` or `HOLD`)
- `reason` — 1-3 sentences grounded in the rubric
- `artifact_sha256`
- `evaluated_at`
