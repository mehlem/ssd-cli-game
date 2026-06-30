# Artifact Format Reference

All artifacts share a consistent structure: YAML frontmatter for machine-readable metadata, followed by markdown content with cross-reference IDs.

---

## Universal Frontmatter

Every artifact in `.features/<feature_path>/` includes this frontmatter. The default `feature_path` is the flat feature ID (`####-name`); grouped features store artifacts under a safe relative path such as `.features/platform/search/0008-index-refresh/`.

```yaml
---
id: TYPE-NNNN                      # Unique artifact ID (e.g., SPEC-0001, PLAN-0001)
feature: "####-feature-name"       # Feature basename identity
title: "Feature Title"             # Human-readable title
type: brief | spec | research | plan | tasks | review # Artifact type
status: draft | active | completed # Lifecycle state
phase: brief | design | research | plan | implement | review | close
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: TYPE-NNNN                  # Primary upstream artifact (plan→spec, tasks→plan, etc.)
related:                           # Full sibling link map
  brief: BRIEF-NNNN
  spec: SPEC-NNNN
  research: RESEARCH-NNNN
  plan: PLAN-NNNN
  tasks: TASKS-NNNN
  review: REVIEW-NNNN
  scratchpad: SCRATCH-NNNN
  continuity: CONT-NNNN
  knowledge: KB-NNNN
tags: []                           # Optional categorization
---
```

### Artifact ID Convention

| Type | ID Format | Example |
|:-----|:----------|:--------|
| Brief | BRIEF-NNNN | BRIEF-0001 |
| Spec | SPEC-NNNN | SPEC-0001 |
| Research | RESEARCH-NNNN | RESEARCH-0001 |
| Plan | PLAN-NNNN | PLAN-0001 |
| Tasks | TASKS-NNNN | TASKS-0001 |
| Review | REVIEW-NNNN | REVIEW-0001 |
| Scratchpad | SCRATCH-NNNN | SCRATCH-0001 |
| Continuity | CONT-NNNN | CONT-0001 |
| Knowledge | KB-NNNN | KB-0001 |

The NNNN matches the feature number. IDs are globally unique across the project. The frontmatter `feature:` value remains the basename feature ID even when the directory is grouped; path-aware command output carries the storage path as `feature_path`.

### Feature Directories, Groups, and Sidecars

SDD supports two feature directory layouts:

```text
.features/0001-user-auth/                         # flat default
.features/platform/search/0008-index-refresh/     # optional grouped layout
```

Group folders are markerless containers, not features. A directory is discovered as a feature only when its basename is a numeric feature ID and it has feature artifacts or sidecars. `wp-*` directories are direct children of a resolved feature directory and are never discovered as features.

Generated sidecars live next to canonical artifacts in the resolved feature directory. `sdd setup` ignores these for both flat and nested features:

- `.features/**/summary.md`
- `.features/**/summary-compact.md`
- `.features/**/changes.log`
- `.features/**/customization.yaml`

Root epic v1 is not part of grouped feature discovery: `.features/EPIC.md` remains the single project-level epic registry.

### Dependency Chain (via `source` field)

```
BRIEF-0001 ← SPEC-0001 ← RESEARCH-0001 ← PLAN-0001 ← TASKS-0001
                 ↑
            REVIEW-0001 (validates SPEC)
```

### Status Lifecycle

`draft` → `active` → `completed`
- `draft`: being written, not yet ready for use
- `active`: current, being worked against
- `completed`: done, all obligations met

Frontmatter `status:` is the artifact's lifecycle/readiness state, not the
feature's active execution phase. Phase-transition scaffold commands may mark a
predecessor artifact `completed` when they consume it. For example, creating
`research.md` can complete a draft `spec.md`, and creating `plan.md` can
complete a draft `research.md`. When this happens, the command reports the
status update in text output and JSON `data.status_updates`.

Frontmatter `phase:` is the artifact's owning SDD phase. It answers "which
phase produced this artifact?" A `spec.md` keeps `phase: design` after the
feature has moved into Research, Plan, Implement, or Review.

### Status Fields

Two different status enums exist on purpose:

- Frontmatter `status:` tracks the lifecycle of the artifact itself: `draft | active | completed`
- Frontmatter `phase:` tracks artifact ownership: `brief | design | research | plan | implement | review | close`
- Task body `> Status:` tracks the execution state of a task inside `tasks.md`: `pending | in-progress | completed | blocked`

These fields are not interchangeable. A `tasks.md` artifact can have `status: draft` while individual tasks inside it are `pending` or `completed`.
Likewise, an artifact can have `status: completed` while its `phase:` still names the phase that owns it, not the currently active execution phase.

### Machine Queries

```bash
# All artifacts for a flat feature
grep -l "feature: \"0001" .features/0001-*/*.md

# All artifacts for a nested feature
find .features -maxdepth 6 -path '*/0008-index-refresh/*.md'

# All active artifacts across all features
grep -rl "^status: active" .features/

# Find an artifact's upstream dependency
grep "^source:" .features/0001-auth/plan.md

# List all sibling references
grep -A8 "^related:" .features/0001-auth/spec.md

# All specs across all features
grep -rl "^type: spec" .features/
```

---

## brief.md

The WHY. Captures user intent through structured Q&A before any engineering artifacts are written. Scaffolded by `sdd init`. The lightest artifact — a captured conversation, not a formal document.

```markdown
---
id: BRIEF-0001
feature: "0001-feature-name"
title: "Feature Name"
type: brief
status: draft
phase: brief
created: YYYY-MM-DD
updated: YYYY-MM-DD
related:
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Brief: [Feature Title]

## Motivation
[WHY this needs to exist]

## Problem
[WHO has this problem, what's their experience]

## Vision
[What success looks like]

## Context
- Stakeholders: [who]
- Urgency: [why now]
- Prior attempts: [what's been tried]

## Constraints
[Non-negotiables]

## Q&A Record

### Q1: [Question]
**Recommended**: [Claude's suggestion]
**Answer**: [User's answer]
```

**Machine-readable patterns:**
- Q&A entries: headings matching `^### Q[0-9]+:`
- Recommended answers: lines matching `^\*\*Recommended\*\*:`
- User answers: lines matching `^\*\*Answer\*\*:`

---

## spec.md

The single source of truth for WHAT to build and WHY. Combines product (PRD) and engineering (spec) perspectives. Scaffolded by `sdd spec`.

```markdown
---
id: SPEC-0001
feature: "0001-feature-name"
title: "Feature Name"
type: spec
status: draft
phase: design
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: BRIEF-0001
related:
  brief: BRIEF-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Spec: [Feature Title]

## Problem

[What problem is being solved and why now. Written from the user's perspective.]

## Solution

[High-level solution approach. Not implementation details — those go in plan.md.]

## User Stories

- US-01: As a [user type], I want [goal], so that [benefit]
- US-02: As a [user type], I want [goal], so that [benefit]

## Functional Requirements

- FR-001: [Requirement — clear, testable statement]
- FR-002: [Requirement]
- FR-003: [Requirement]

## Acceptance Criteria

- [ ] AC-001: Given [context], when [action], then [expected result]
- [ ] AC-002: Given [context], when [action], then [expected result]
- [ ] AC-003: Given [context], when [action], then [expected result]

## Non-Goals

- [What is explicitly out of scope]

## Constraints

- [Technical, security, compliance, or timeline constraints]

## Open Questions

- [ ] OQ-001: [Question — resolved when checked]
```

**Machine-readable patterns:**
- Requirements: lines matching `^- FR-\d{3}: `
- Acceptance criteria: lines matching `^- \[[ x]\] AC-\d{3}: `
- Open questions: lines matching `^- \[[ x]\] OQ-\d{3}: `

---

## research.md

The WHERE. Maps the implementation landscape — which files, what patterns, what dependencies. Language-agnostic. Scaffolded by `sdd research`.

```markdown
---
id: RESEARCH-0001
feature: "0001-feature-name"
title: "Feature Name"
type: research
status: draft
phase: research
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: SPEC-0001
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Research: [Feature Title]

## Summary
[Key findings, scope assessment]

## Affected Files
| File | Action | Module | Impact | Relates To |
|:-----|:-------|:-------|:-------|:-----------|
| [path] | create | [module] | local | FR-001 |

## Code Context
### Entry Points
| Entry Point | File | Signature | Change |
|:------------|:-----|:----------|:-------|

### Types & Contracts
| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|

### Patterns & Conventions
- [pattern description]

## Dependencies
### Internal
| From | To | Type |
|:-----|:---|:-----|

### External
| Package/Service | Version | Purpose | New? |
|:----------------|:--------|:--------|:-----|

## Data Changes (if applicable)
| Entity | Location | Change | Reversible |
|:-------|:---------|:-------|:-----------|

## Configuration (if applicable)
| Config | Location | Change | Required By |
|:-------|:---------|:-------|:------------|

## Test Landscape
## Prior Art
## System Context (ASCII diagram)
## Risks & Concerns
```

**Machine-readable patterns:**
- Affected files: table rows with Action enum `create | modify | delete | review`
- Impact levels: `local | module | cross-module | breaking`
- Entry points: table rows matching `^| .* | .*:\d+ |`
- Dependencies: table rows in Internal/External sections

**Script examples:**
```bash
# Count affected files for a feature
grep -c '^| ' .features/0001-auth/research.md

# Find all features touching a specific file
grep "packages/auth/src/login.ts" .features/*/research.md

# Find all breaking changes across features
grep "| breaking |" .features/*/research.md

# Find all new external dependencies
grep "| yes |" .features/*/research.md
```

---

## plan.md

The HOW. Translates requirements into architectural decisions and vertical implementation slices. Uses research.md as foundation. Scaffolded by `sdd plan plan`.

```markdown
---
id: PLAN-0001
feature: "0001-feature-name"
title: "Feature Name"
type: plan
status: draft
phase: plan
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: RESEARCH-0001
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Plan: [Feature Title]

## Research Findings

[What was learned from codebase exploration and external research.
Include: existing patterns discovered, relevant code locations, external best practices.]

## Architectural Decisions

- AD-001: [Decision title]
  - **Decision**: [What was decided]
  - **Rationale**: [Why this over alternatives]
  - **Alternatives considered**: [What was rejected and why]

- AD-002: [Decision title]
  - **Decision**: [What was decided]
  - **Rationale**: [Why]

## Phases

### PH-01: [Phase title]

> Addresses: FR-001, FR-002
> Acceptance: AC-001

[Description of this vertical slice. What end-to-end behavior it delivers.
Each phase should be independently demoable or verifiable.]

### PH-02: [Phase title]

> Addresses: FR-003
> Acceptance: AC-002, AC-003

[Description of this vertical slice.]

## Risks & Mitigations

| Risk | Impact | Mitigation |
|:-----|:-------|:-----------|
| [Risk] | [Impact] | [Mitigation] |

## Open Questions

- [ ] OQ-001: [Resolved from spec or new — checked when resolved]
```

**Machine-readable patterns:**
- Architectural decisions: sections matching `^- AD-\d{3}: `
- Phases: headings matching `^### PH-\d{2}: `
- Phase references: lines matching `^> Addresses: FR-`

---

## tasks.md

The DO. Atomic, ordered tasks derived from plan.md phases. Each task has machine-readable status and file references from research.md. Scaffolded by `sdd plan tasks`.

For WP-mode features, root `tasks.md` is optional and normally omitted. The execution contract lives in `wp-*/tasks.md`; aggregate lifecycle commands read those WP task files instead of requiring a root tasks.md stub.

```markdown
---
id: TASKS-0001
feature: "0001-feature-name"
title: "Feature Name"
type: tasks
status: draft
phase: implement
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: PLAN-0001
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Tasks: [Feature Title]

## T-001: [Task title]

> Status: pending | in-progress | completed | blocked
> Phase: PH-01
> Implements: FR-001

### Description

[Atomic outcome — one clear thing to accomplish]

### Steps

1. [Concrete action]
2. [Concrete action]

### Acceptance Criteria

- [ ] [Testable criterion]
- [ ] [Testable criterion]

### Verification

```bash
[runnable command to verify this task]
```

***

## T-002: [Task title]

> Status: pending
> Phase: PH-01
> Implements: FR-001, FR-002
> Files: src/auth/oauth.ts (create), src/auth/types.ts (modify)
> Depends-on: T-001

### Description

[Atomic outcome]

### Steps

1. [Action]

### Acceptance Criteria

- [ ] [Criterion]

### Verification

```bash
[command]
```
```

**Machine-readable patterns:**
- Task headers: `^## T-\d{3}: `
- Status: `^> Status: (pending|in-progress|completed|blocked)`
- Phase link: `^> Phase: PH-\d{2}`
- FR link: `^> Implements: FR-`
- Dependencies: `^> Depends-on: T-`
- Checkboxes: `^- \[[ x]\] `

**Script examples:**
```bash
# Count pending tasks
grep -c "^> Status: pending" .features/####-name/tasks.md

# Mark task T-001 as in-progress
bash .claude/skills/spec-driven-development/scripts/sdd-task.sh start ####-name T-001

# List all tasks for a phase
grep -A1 "^## T-" .features/####-name/tasks.md | grep "Phase: PH-01"

# List every WP task with WP attribution
sdd task list --all ####-name
```

---

## review.md

The VERIFY. Validates the completed feature against spec.md acceptance criteria and code quality standards. Compares actual changes against research.md file map. Scaffolded by `sdd review` (auto-populates AC table from spec.md).

```markdown
---
id: REVIEW-0001
feature: "0001-feature-name"
title: "Feature Name"
type: review
status: draft
phase: review
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: SPEC-0001
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
verdict: pending
tags: []
---

# Review: [Feature Title]

> **Review Protocol — Verified-Only**
> Every finding must be verified against actual code before it is reported. Unverified claims must be dropped.
> Cite `file:line` for every finding. Banned language: "consider adding", "ensure that", "might cause", "could lead to", "should probably".

## Acceptance Criteria Validation

| AC | Description | Status | Evidence |
|:---|:------------|:-------|:---------|
| AC-001 | [from spec.md] | PASS / FAIL | [file:line or test output] |
| AC-002 | [from spec.md] | PASS / FAIL | [file:line or test output] |
| AC-003 | [from spec.md] | PASS / FAIL | [file:line or test output] |

## Code Quality

| Category | Status | Notes |
|:---------|:-------|:------|
| Correctness | PASS / FAIL | [notes] |
| Tests | PASS / FAIL | [test count, coverage] |
| Security | PASS / FAIL | [notes] |
| Performance | PASS / FAIL | [notes] |
| Readability | PASS / FAIL | [notes] |

## Scope Conformance

| File | Expected | Actually Changed | Status | Notes |
|:-----|:---------|:----------------|:-------|:------|
| [scope-from-research] | — | — | — | — |

## Test Results

```bash
[output of test suite run]
```

## Issues Found

### Critical (must fix before close)

| Issue | Location | Evidence |
|:------|:---------|:---------|
| (none) | — | — |

### Minor (noted, can proceed)

| Issue | Location | Evidence |
|:------|:---------|:---------|
| (none) | — | — |

## Verified Clean

| Area | Method | Result |
|:-----|:-------|:-------|
| Hardcoded secrets | Grepped for password, secret, key, token | None found |
| [area] | [how checked] | [result] |
```

**Machine-readable patterns:**
- Verdict in frontmatter: `^verdict:` is the canonical verdict source
- AC table rows: `| AC-\d{3} |`
- Critical issues: table under Critical heading (| Issue | Location | Evidence |)
- Quality table: parseable markdown table
- Scope Conformance table: cross-checks actual vs research.md
- Verified Clean table: explicitly confirmed clean areas

---

## scratchpad.md

Working memory throughout the feature lifecycle. Auto-created by `sdd init` during Brief phase.

```markdown
---
id: SCRATCH-0001
feature: "0001-feature-name"
title: "Feature Name"
type: scratchpad
status: active
created: YYYY-MM-DD
updated: YYYY-MM-DD
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Scratchpad: [Feature Title]

## Observations

[Append-only timestamped notes]
- [YYYY-MM-DD HH:MM] [observation]

## Progress Notes

[Informal tracking alongside formal tasks.md]

## Ideas & Alternatives

[Approaches considered, design alternatives, what-ifs]

## Findings → Knowledge

[Facts worth graduating to KNOWLEDGE.md. Prefix with → KNOWLEDGE when ready.]
- → KNOWLEDGE: [finding description]

## Open Questions

- [ ] [Quick-capture questions during work]
```

---

---

## Work Packages

Work packages (WPs) are an optional decomposition layer for large or multi-subsystem features. They are purely additive — features without WP directories behave identically to before.

### When to Use WPs

Use WPs when a feature has 15+ tasks, touches independent subsystems, or needs intermediate stopping points. For features under 15 tasks, the flat model is simpler and preferred.

### How WP Mode Activates

WP mode is convention-based: creating a `wp-NN-name/` subdirectory inside a feature directory automatically enables WP behavior. No flags or config needed.

### Filesystem Layout

```
.features/####-name/
├── brief.md, spec.md, research.md, plan.md   (feature-level — unchanged)
├── tasks.md                                   (feature-level — root tasks.md; omit when WPs exist)
├── wp-01-auth-layer/
│   ├── tasks.md          (required)
│   ├── review.md         (added at review time)
│   └── scratchpad.md     (optional, auto-created by wp init)
├── wp-02-data-layer/
│   └── tasks.md
└── review.md             (feature-level — created after all WP reviews pass)
```

### WP Lifecycle

Each WP follows its own mini-cycle: **scaffold → implement → review → done**

- `scaffold` — directory exists, no tasks.md yet
- `implement` — tasks.md has pending or in-progress tasks
- `review` — all tasks done; waiting for `sdd review --wp <wp-id> <feature>`
- `done` — review.md exists with `verdict: pass`

Feature-level review (`sdd review <feature>`) is blocked until all WPs reach `done`.

### Commands

```bash
sdd wp init <feature> <name>      # Create wp-NN-name/ with tasks.md + scratchpad.md
sdd wp list <feature>             # Show all WPs with phase and task progress
sdd task list --all <feature>     # Show every WP task with WP-NN/T-xxx attribution
sdd review --wp <wp-id> <feature> # Scaffold a WP-scoped review.md
```

WP names must be kebab-case (e.g., `auth-layer`, `data-pipeline`). WPs are auto-numbered (`wp-01-`, `wp-02-`, ...). `sdd wp init` may emit a non-blocking warning / alignment warning when `plan.md` contains phase or WP-like decomposition lines but none match the requested name; creation still succeeds.

### WP-Aware Behavior

When WP directories exist, these commands automatically scope to the active WP:

- `sdd task next/start/complete/list` — operates on the active WP's tasks.md; `sdd task list --all` is the explicit cross-WP inventory
- `sdd phase` — appends `wp:`, `wp_phase:`, `wp_count:`, `wp_done:`, `wp_active:`, `wp_pending:` fields and exposes raw phase versus effective phase / execution phase
- `sdd status` — adds a Work Packages breakdown section and aggregates task totals into `task_source.mode=work_packages`
- Stop gate — allows stopping at WP boundaries (active WP complete), blocks mid-WP
- `sdd check all` / `sdd close` — validate aggregate WP tasks, WP reviews, and then feature-level review without requiring root `tasks.md`

The **active WP** is determined by: first WP with in-progress tasks → first with pending tasks → first without a passing review.

---

## Work Package Artifacts

Work packages (WPs) are optional subdirectories within a feature folder that decompose complex features into semi-independent implementation units. WP mode activates by convention — the presence of any `wp-NN-name/` directory signals WP mode for that feature.

For grouped features, WPs are still direct children of the resolved feature path:

```text
.features/platform/search/0008-index-refresh/wp-01-core/
```

They are scoped children, not nested features.

### Directory Naming Convention

```
.features/####-feature-name/
├── brief.md              (feature-level, inherited by all WPs)
├── spec.md               (feature-level, inherited by all WPs)
├── research.md           (feature-level)
├── plan.md               (feature-level)
├── scratchpad.md         (feature-level)
├── wp-01-first-chunk/    (WP directory — NN is zero-padded two digits)
│   ├── tasks.md          (required)
│   ├── scratchpad.md     (auto-created by sdd wp init)
│   ├── review.md         (created at review time)
│   ├── research.md       (optional, v2)
│   └── plan.md           (optional, v2)
└── wp-02-second-chunk/
    └── tasks.md
```

**Naming rules:**
- Format: `wp-NN-name` where `NN` is zero-padded (01–99) and `name` is kebab-case
- Auto-assigned by `sdd wp init` — do not manually set numbers
- Maximum 99 WPs per feature
- No renumbering after creation — new WPs always append at the end

### WP Frontmatter Fields

WP artifacts extend the universal frontmatter with WP-specific fields:

```yaml
---
id: WP-TASKS-NNNN-wp-NN-name     # WP artifact ID
feature: "####-feature-name"      # Parent feature folder
work_package: "wp-NN-name"        # This WP's directory name
parent: TASKS-NNNN                # Feature-level tasks artifact
depends_on: []                    # WP-level: other WP IDs that must complete first
addresses: []                     # Which FRs / PH-xx slices this WP implements
title: "WP Title"
type: tasks
status: draft
phase: implement
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: PLAN-NNNN
links: {"derived_from":["PLAN-NNNN"],"informed_by":[],"supersedes":[]}
related:
  brief: BRIEF-NNNN
  spec: SPEC-NNNN
  research: RESEARCH-NNNN
  plan: PLAN-NNNN
  tasks: TASKS-NNNN
  review: WP-REVIEW-NNNN-wp-NN-name
  scratchpad: WP-SCRATCH-NNNN-wp-NN-name
  continuity: CONT-NNNN
  knowledge: KB-NNNN
tags: []
---
```

**WP review frontmatter:**

```yaml
---
id: WP-REVIEW-NNNN-wp-NN-name
feature: "####-feature-name"
work_package: "wp-NN-name"
parent: REVIEW-NNNN
title: "WP Title"
type: review
status: draft
phase: review
created: YYYY-MM-DD
updated: YYYY-MM-DD
source: SPEC-NNNN
links: {"derived_from":["SPEC-NNNN"],"informed_by":[],"supersedes":[]}
related:
  brief: BRIEF-NNNN
  spec: SPEC-NNNN
  research: RESEARCH-NNNN
  plan: PLAN-NNNN
  tasks: WP-TASKS-NNNN-wp-NN-name
  review: REVIEW-NNNN
  scratchpad: WP-SCRATCH-NNNN-wp-NN-name
  continuity: CONT-NNNN
  knowledge: KB-NNNN
verdict: pending | pass | fail
tags: []
---
```

### WP Artifact IDs

| Type | ID Format | Example |
|:-----|:----------|:--------|
| WP Tasks | WP-TASKS-NNNN-wp-NN-name | WP-TASKS-0002-wp-01-auth-layer |
| WP Review | WP-REVIEW-NNNN-wp-NN-name | WP-REVIEW-0002-wp-01-auth-layer |
| WP Scratchpad | WP-SCRATCH-NNNN-wp-NN-name | WP-SCRATCH-0002-wp-01-auth-layer |

The NNNN matches the parent feature number.

### Task ID Scoping

Task IDs (`T-xxx`) are **locally scoped** within each WP. The same `T-001` can appear in `wp-01-auth-layer/tasks.md` and `wp-02-task-routing/tasks.md` without conflict.

**Cross-WP references** use the `WP-NN/T-xxx` notation:

| Context | Format | Example |
|:--------|:-------|:--------|
| Local WP reference | `T-xxx` | `T-001` (within same WP) |
| Cross-WP reference | `WP-NN/T-xxx` | `WP-02/T-003` (from another WP) |
| Feature-level reference | `TASKS-NNNN` | `TASKS-0002` (feature tasks artifact) |

**`Depends-on` in WP tasks.md:**

```markdown
> Depends-on: WP-01/T-003   ← task in another WP
> Depends-on: T-002          ← task in same WP
```

### WP Lifecycle

Each WP follows a mini-SDD lifecycle within the parent feature:

```
sdd wp init → tasks.md (scaffold) → implement → sdd review --wp → review.md → verdict: pass
```

Phase detection within a WP mirrors the feature-level rules, checking files within the WP directory. Generated WP artifacts participate in trace provenance: WP `tasks.md` uses `source: PLAN-NNNN` plus `links.derived_from=["PLAN-NNNN"]`, and WP `review.md` uses `source: SPEC-NNNN` plus `links.derived_from=["SPEC-NNNN"]`.

**Active WP resolution** (used by `sdd task` commands and hooks):
1. First WP with `> Status: in-progress` tasks
2. If none, first WP with `> Status: pending` tasks (numeric order)
3. If none, first WP without `verdict: pass` in review.md

### Machine Queries

```bash
# List all WP directories for a feature
ls -d .features/0002-*/wp-*/

# Check if a feature is in WP mode
ls -d .features/0002-sdd-work-packages/wp-*/ 2>/dev/null | head -1

# Find active WP (first with pending tasks)
grep -rl '^> Status: pending' .features/0002-sdd-work-packages/wp-*/tasks.md 2>/dev/null | sort | head -1

# Count WP completion
grep -l '^verdict: pass' .features/0002-sdd-work-packages/wp-*/review.md 2>/dev/null | wc -l

# All WP reviews with verdict
grep '^verdict:' .features/0002-sdd-work-packages/wp-*/review.md 2>/dev/null

# Cross-WP task inventory with local ID disambiguation
sdd task list --all 0002-sdd-work-packages
```

---

## ID Convention Summary

### Artifact IDs

| Type | ID Format | Example |
|:-----|:----------|:--------|
| Brief | BRIEF-NNNN | BRIEF-0001 |
| Spec | SPEC-NNNN | SPEC-0001 |
| Research | RESEARCH-NNNN | RESEARCH-0001 |
| Plan | PLAN-NNNN | PLAN-0001 |
| Tasks | TASKS-NNNN | TASKS-0001 |
| Review | REVIEW-NNNN | REVIEW-0001 |
| Scratchpad | SCRATCH-NNNN | SCRATCH-0001 |

### Content IDs

| Prefix | Source | Purpose |
|:-------|:-------|:--------|
| US-xx | spec.md | User Stories |
| FR-xxx | spec.md | Functional Requirements |
| AC-xxx | spec.md | Acceptance Criteria |
| OQ-xxx | spec.md, plan.md | Open Questions |
| AD-xxx | plan.md | Architectural Decisions |
| PH-xx | plan.md | Implementation Phases |
| T-xxx | tasks.md | Tasks |

### Traceability Chain

```
BRIEF (why) → FR-001 (spec) → PH-01 (plan) → T-001 (tasks) → [files] (research) → AC-001: PASS (review)
```

Every downstream artifact references upstream IDs. This enables:
- Forward tracing: "Which tasks implement FR-001?"
- Backward tracing: "Why does T-003 exist?" → "Implements FR-002, part of PH-01"
- Coverage analysis: "Are all FRs addressed by tasks?"
- Validation: "Do all ACs have a PASS/FAIL in review?"
