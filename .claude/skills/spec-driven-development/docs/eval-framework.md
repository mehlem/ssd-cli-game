# Eval & Quality Assurance Framework

## Overview

The SDD eval framework provides automated testing infrastructure for the spec-driven development skill. It measures behavioral compliance with the current scenario suite, validates artifact quality, and quantifies the skill's impact through with-skill vs without-skill comparisons. The framework progresses from core behavioral evaluation (0008) through fixture accuracy hardening (0009) to trigger optimization testing (0015), enabling continuous improvement of the skill's recognition and application.

## What the Evals Test

The eval suite evaluates three distinct aspects of the SDD skill:

**Behavioral scenarios**: Evals check what agents say and do when using the skill—whether they read `.features/` directories, announce current phases, identify pending tasks, and execute workflow transitions. Behavioral assertions are specific: "Agent reads tasks.md to find current task" requires evidence of a Read tool call targeting that file, not just agent text claiming it read something.

**Phase compliance**: Evals verify that agents respect SDD phase gates. For example, when in the Brief phase, agents should ask clarifying questions rather than jump to implementation. Phase gate evals test both positive actions (move to next phase when ready) and negative constraints (refuse actions inappropriate for current phase).

**Trigger accuracy**: The skill description field is tested empirically via trigger evals—~20 queries that should or should not invoke the skill. This identifies gaps where users don't get SDD guidance when needed (false negatives) or receive it for simple tasks where it adds friction (false positives).

**Steering coherence overlays**: Newer evals measure whether the workflow also shapes agent judgment inside the workflow. These checks look for later-phase ambiguity handling, grounded claims outside review, resistance to overbuilding, smallest-viable planning, surgical scope discipline, failure recovery that inspects evidence before retrying, and continuity that preserves the next verification target. This coverage is layered into existing categories instead of introducing a new benchmark category, so historical rollups remain comparable.

## Eval Infrastructure

### Fixture System

Fixtures are isolated project states that make eval prompts contextually valid. Each fixture includes:
- A static playground codebase (`evals/playground/`): minimal Express.js project with ~10 files providing realistic context for prompts like "add JWT auth to the TaskFlow API"
- A `.features/` directory tree at a specific SDD phase and task state
- Isolated git history (each fixture runs `git init && git commit` to create a sandbox root)
- A sandbox `CLAUDE.md` preventing interaction with the real project

The fixture registry defines presets such as:
- `no-active-feature`: empty `.features/`, triggering "no feature found" behavior
- `implement-t003-pending`: Design phase complete, T-003 as next pending task
- `design-phase`: Brief complete, agent in Design phase
- `implement-all-done`: all tasks marked completed, ready for Review

When an eval runs, the runner executes `claude -p` inside the fixture directory, ensuring the agent operates against fixture state, not real project state.

### Eval Execution

The eval runner executes `claude -p` with `--output-format stream-json --verbose` to capture full transcripts. Output includes:
- `transcript.md`: Agent text and reasoning (result field from stream events)
- `tool-calls.json`: Structured inventory of tool calls (extracted from tool_use stream events)
- Timing and metadata for benchmarking

Each eval runs once per configuration (with-skill and without-skill), producing parallel outputs for comparison. Workspace outputs follow the skill-creator convention: `iteration-N/eval-ID/{with_skill,without_skill}/outputs/`.

### Trigger Accuracy Evals (0015)

Unlike behavioral evals (which test what Claude does *after* SDD loads), trigger evals test *whether* SDD loads at all — they are run against the raw skill description, not the methodology.

A separate eval suite measures whether the SDD skill loads at the right moments — not too eagerly (false positives pollute sessions) and not too late (missed triggers mean no methodology guidance).

**trigger-eval.json structure:**

```json
{
  "queries": [
    { "prompt": "add OAuth login to the user service", "should_trigger": true },
    { "prompt": "what does Array.map do?", "should_trigger": false }
  ]
}
```

Each query is a realistic user message. `should_trigger: true` means SDD should load; `false` means it should not.

**Train/test split:** Queries are split 70/30 into train (used to iterate the description) and test (held out for final validation). The optimization loop runs on the train set; final score is measured on the test set to prevent overfitting the description to known queries.

**1024-character limit:** Skill descriptions are truncated at 1024 characters in Claude Code. Optimized descriptions must stay under this limit while maximizing trigger precision and recall.

**Running trigger evals:**

```bash
bash scripts/tests/run-trigger-eval.py    # runs full trigger eval suite
```

Results show per-query pass/fail and aggregate precision/recall. Target: 90%+ precision (few false positives) and 85%+ recall (few missed triggers).

### Grading & Expectations

The SDD Grader agent (defined in `evals/agents/sdd-grader.md`) evaluates expectations against transcripts using these rules:

**Positive expectations** ("Agent reads .features/", "Agent identifies next task") require evidence from tool calls or agent text. A PASS needs specific citation: tool call number, excerpt, or file path.

**Negative expectations** ("Agent does NOT write production code", "Agent does NOT start coding immediately") require exhaustive scanning. The grader searches all tool calls in the transcript, reports total counts, and confirms absence with precision. Evidence must state: "Searched N total tool calls, M Write/Edit found, none outside .features/" for the PASS to be valid.

**Artifact quality checks** validate generated artifacts against format specifications:
- YAML frontmatter valid with required fields (id, feature, title, type, status, phase)
- ID conventions matching TYPE-NNNN format (BRIEF-NNNN, SPEC-NNNN, PLAN-NNNN, etc.)
- Required sections present (Functional Requirements, Acceptance Criteria, etc.)
- Artifact-specific patterns: FRs use FR-xxx identifiers, ACs use AC-xxx with checkbox format

Grading results are saved to `grading.json` with this structure:
```json
{
  "expectations": [
    {"text": "...", "passed": true, "evidence": "..."}
  ],
  "summary": {"passed": 3, "failed": 1, "total": 4, "pass_rate": 0.75},
  "timing": {"grader_duration_seconds": 22.0},
  "eval_feedback": {"suggestions": [], "overall": "..."}
}
```

## Benchmark Aggregation & Results

After grading, `aggregate-sdd-benchmark.py` produces `benchmark.json` with:

**Standard metrics** (viewer-compatible): mean/stddev/min/max pass rates across evals, configuration-level summaries (with-skill vs without-skill), timing statistics.

**Category rollups** (SDD-specific): per-category pass rates matching the 48-scenario taxonomy:
- Natural Triggers: prompt recognition without explicit "use SDD" language
- Anti-Rationalization: refusal to rationalize skipping phases
- Resume Continuity: detection of active features and next-step inference
- WP Aware: working-path interactions and file-system integration
- Phase Gates: enforcement of Brief→Design→Research→Plan→Implement→Review→Close
- Worker Mode: subagent and multi-agent scenarios
- Artifact Quality: generated artifacts meet format and specification

Steering-coherence coverage is intentionally distributed across existing categories:
- Resume continuity now also checks whether the agent preserves the current verification target or blocker state.
- Semantic gate coverage now also checks ambiguity handling, grounded claims, resistance to overbuilding, smallest-viable planning, and recovery behavior after weak artifacts or failed gates.
- Convention / scope-discipline scenarios now also check resistance to drive-by cleanup and other unrequested work.

Each category targets specific pass rates from `eval-scenarios.md` (typically 80–90%), enabling focused improvement when a category lags.

## How Eval Results Drive Improvement

The eval framework creates a feedback loop:

1. **Run evals** against current skill definition with and without SDD skill enabled
2. **Review results** in the skill-creator HTML viewer, which shows pass rates, timing, and per-eval breakdowns
3. **Analyze patterns**: the SDD Analyzer agent identifies non-discriminating assertions (pass with or without skill), flaky evals (inconsistent results), and category-specific weaknesses
4. **Iterate the skill**: refine SKILL.md description for better trigger accuracy (0015), adjust prompts for clearer behavioral guidance, or add hooks for new workflow patterns
5. **Validate improvements**: rerun the same eval set with updated skill to measure delta

For steering hardening work, pay close attention to false-positive passes where the agent reaches the right phase outcome for the wrong reasons. A pass that lacks grounding, ignores ambiguity, or quietly broadens scope is still a regression even if the phase transition itself looks correct.

For trigger optimization (0015), the loop uses the skill-creator's `run_eval.py` and `run_loop.py` tools to generate description candidates, measure improvement on held-out test queries, and validate against the full query set.

## Feature Coverage

- **Feature 0008** (SDD Eval Framework): Fixture system, behavioral eval runner, grader infrastructure, Tier 1 eval set (15 evals covering Anti-Rationalization, Phase Gates, Natural Triggers)
- **Feature 0009** (SDD Eval Hardening): Git-based fixture isolation, stream-json transcript capture, programmatic grader improvements (tool-call-based assertions), fixture accuracy validation
- **Feature 0015** (SDD Description Optimization): Trigger accuracy evals with train/test split, baseline measurement on raw description, automated optimization loop via `run_loop.py`, test-set validation against 1024-character limit

## Related Documentation

- **eval-scenarios.md**: Complete 48-scenario suite taxonomy with pass rate targets
- **evals/evals.json**: Eval definitions with fixtures, prompts, and expectations
- **evals/trigger-eval-slim.json**: Trigger query set for description optimization
- **evals/agents/sdd-grader.md**: Detailed grading protocol with assertion types and evidence rules
- **evals/agents/sdd-analyzer.md**: Pattern analysis for eval quality and skill weaknesses
