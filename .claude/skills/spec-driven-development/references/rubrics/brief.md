# Brief Semantic Rubric

Score each dimension from 0-20. Total score determines the verdict.

## Dimensions

- **Intent clarity** (0-20): Is the motivating intent explicit and concrete?
  - 0-5: The brief names a topic, not an intent.
  - 6-12: Intent exists but is generic or underspecified.
  - 13-20: Intent is specific, concrete, and tied to a real problem.

- **Problem grounding** (0-20): Is the problem described in concrete, user-facing terms rather than slogans?
  - 0-5: The problem is absent, generic, or purely implementation-framed.
  - 6-12: The problem is stated, but impact, evidence, or urgency is still fuzzy.
  - 13-20: The problem is concrete, user-facing, and grounded enough to justify the feature.

- **Constraint and scope discipline** (0-20): Are boundaries explicit enough to keep later phases out of speculative scope?
  - 0-5: Constraints are absent or the brief quietly invites solution sprawl.
  - 6-12: Some constraints exist, but important boundaries or non-goals are still implied.
  - 13-20: Constraints meaningfully bound the solution space and discourage silent scope expansion.

- **Success signal** (0-20): Does the brief make success observable?
  - 0-5: Success is not defined.
  - 6-12: Success is implied, but hard to verify.
  - 13-20: Success is concrete enough to guide the next phase.

- **Ambiguity resolution** (0-20): Does the Q&A and inferred content resolve the main uncertainties without over-asking?
  - 0-5: Q&A is absent, placeholder-only, hides major ambiguity, OR the brief asks code-logic / research-phase / inspectable questions instead of intent-level ones. Inferred Problem/Context/Constraints are unlabeled or missing.
  - 6-12: Q&A exists with intent-level questions but leaves important scope or intent unresolved; recommendations may be missing on some questions; inferred sections present but inconsistently labeled with source.
  - 13-20: Q&A is intent-only (no code/research/inspectable questions), each question carries a `**Recommended**:` line, the question count is restrained (~3 or fewer), and inferred Problem/Context/Constraints are clearly labeled with source (e.g., `<!-- inferred from CLAUDE.md -->`). Together the Q&A + inferred content materially sharpen scope and intent.

## Verdict

- **0-30**: HOLD — too thin to enter Design.
- **31-69**: HOLD — partially formed; clarify before Design.
- **70-100**: GO — strong enough to scaffold and fill spec.md.

## Output Contract

The semantic evaluator should return:

- `score`
- `verdict` (`GO` or `HOLD`)
- `reason` — 1-3 sentences grounded in the rubric
- `artifact_sha256`
- `evaluated_at`
