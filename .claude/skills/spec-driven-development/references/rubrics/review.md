# Review Semantic Rubric

Score each dimension from 0-20. Total score determines the verdict.

This rubric is additive guidance for review quality. It does not create a new semantic sidecar or hard gate by itself.

## Dimensions

- **Requirement coverage evidence** (0-20): Does the review check the spec requirements and ACs concretely?
  - 0-5: Review is impressionistic, sparse, or detached from the spec.
  - 6-12: Some requirement coverage exists, but important checks are missing or weakly evidenced.
  - 13-20: The review checks requirements concretely enough to support a trustworthy verdict.

- **Grounding** (0-20): Are findings grounded in inspected code, tests, or other explicit evidence?
  - 0-5: Findings are speculative, generic, or unsupported.
  - 6-12: Some evidence exists, but grounding is inconsistent or incomplete.
  - 13-20: Findings clearly distinguish inspected evidence from any remaining uncertainty.

- **Verification rigor** (0-20): Does the review treat done as verified evidence rather than completion claims?
  - 0-5: Verification is missing or based on trust.
  - 6-12: Verification exists, but it is incomplete or only lightly tied to the verdict.
  - 13-20: Verification is strong enough that the verdict rests on evidence rather than optimism.

- **Smallest viable solution check** (0-20): Does the review look for overbuilding or unnecessary complexity?
  - 0-5: Review ignores obvious overbuilding.
  - 6-12: Some complexity concerns are noted, but not treated as part of quality.
  - 13-20: Review explicitly checks whether the solution stayed as small as the requirements allowed.

- **Scope discipline and unrequested work** (0-20): Does the review check for scope drift, drive-by cleanup, or extra features?
  - 0-5: Review does not check for unrequested work.
  - 6-12: Scope drift is mentioned inconsistently.
  - 13-20: Review clearly checks for scope drift and unrequested work alongside correctness.

- **Plan-check evidence cited** (0-20): Does deep-mode review cite plan-check evidence before accepting `verdict: pass`?
  applies-to: deep
  - 0-5: Plan-check evidence is missing.
  - 6-12: Plan-check evidence is present but weakly tied to the verdict.
  - 13-20: Plan-check evidence is concrete and clearly supports the review verdict.

- **Dual-reviewer evidence cited** (0-20): Does deep-mode review cite both `sdd-spec-reviewer` and `sdd-quality-reviewer` results?
  applies-to: deep
  - 0-5: One or both reviewer roles are missing.
  - 6-12: Both roles are mentioned, but evidence is thin.
  - 13-20: Both reviewer results are cited with enough evidence to support close.

## Verdict

- **0-30**: HOLD — review quality is too weak to support close decisions.
- **31-69**: HOLD — review exists, but it is not yet trustworthy enough to close on.
- **70-100**: GO — review quality is strong enough to support close decisions.

## Output Contract

When used by evals or reviewers, return:

- `score`
- `verdict` (`GO` or `HOLD`)
- `reason` — 1-3 sentences grounded in the rubric
