# Plan Semantic Rubric

Score each dimension from 0-20. Total score determines the verdict.

## Dimensions

- **Slice quality and smallest viable progress** (0-20): Do the PH-xx slices represent coherent vertical progress without premature decomposition?
  - 0-5: Slices are absent, purely layer-based, or visibly overbuilt.
  - 6-12: Some slice structure exists, but boundaries are weak or broader than needed.
  - 13-20: Slices are coherent, incremental, demoable, and sized to the smallest viable progress units.

- **Decision rationale and simpler alternatives** (0-20): Are architectural decisions explicit, justified, and compared against simpler options?
  - 0-5: Decisions are missing or purely declarative.
  - 6-12: Decisions exist, but rationale is thin or simpler alternatives are not addressed.
  - 13-20: Decisions are explicit enough to guide implementation and explain why extra complexity is warranted.

- **Research grounding and execution realism** (0-20): Does the plan reflect the actual codebase, fact claim evidence, and constraints?
  - 0-5: Plan ignores known constraints or research findings.
  - 6-12: Plan is plausible, but sequencing, grounding, or scope is optimistic, or fact claim assumptions are not named.
  - 13-20: Plan is realistic, clearly grounded in confirmed Research facts, and marks hypotheses or unknowns explicitly.

- **Task derivation readiness** (0-20): Is the plan concrete enough to derive atomic tasks?
  - 0-5: Task derivation would still be guesswork.
  - 6-12: Some task structure is visible, but more detail is needed.
  - 13-20: Tasks can be derived directly from the plan.

- **Risk and scope discipline** (0-20): Does the plan acknowledge compatibility, rollback, sequencing, and scope risks?
  - 0-5: No practical risks are discussed.
  - 6-12: Some risks are noted, but mitigation or scope boundaries are weak.
  - 13-20: Risks and scope boundaries are surfaced clearly enough for implementation choices.

- **Must-haves observable end-state** (0-20): Does the deep-mode plan define observable must-haves that can gate review?
  applies-to: deep
  - 0-5: Must-haves are missing, vague, or not observable.
  - 6-12: Must-haves exist, but some are hard to verify.
  - 13-20: Must-haves are concrete, testable, and mapped to acceptance evidence.

- **ADR rationale completeness** (0-20): Do deep-mode architectural decisions include enough rationale and alternatives for later review?
  applies-to: deep
  - 0-5: ADR entries are missing or declarative.
  - 6-12: ADRs exist, but tradeoffs or rejected alternatives are thin.
  - 13-20: ADRs clearly explain decisions, alternatives, and why the chosen path is the smallest viable option.

## Verdict

- **0-30**: HOLD — not ready to derive tasks or begin implementation.
- **31-69**: HOLD — planning exists, but it is too weak or risky.
- **70-100**: GO — strong enough to derive tasks and enter implement.

## Output Contract

The semantic evaluator should return:

- `score`
- `verdict` (`GO` or `HOLD`)
- `reason` — 1-3 sentences grounded in the rubric
- `artifact_sha256`
- `evaluated_at`
