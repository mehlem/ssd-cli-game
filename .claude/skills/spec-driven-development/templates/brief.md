---
id: BRIEF-{{FEATURE_NUM}}
feature: "{{FEATURE_ID}}"
title: "{{FEATURE_TITLE}}"
type: brief
schema_version: 2
status: draft
phase: brief
created: {{DATE}}
updated: {{DATE}}
related:
  spec: SPEC-{{FEATURE_NUM}}
  research: RESEARCH-{{FEATURE_NUM}}
  plan: PLAN-{{FEATURE_NUM}}
  tasks: TASKS-{{FEATURE_NUM}}
  review: REVIEW-{{FEATURE_NUM}}
  scratchpad: SCRATCH-{{FEATURE_NUM}}
  continuity: CONT-{{FEATURE_NUM}}
  knowledge: KB-{{FEATURE_NUM}}
tags: []
---

# Brief: {{FEATURE_TITLE}}

<!-- =====================================================================
LEAN BRIEF INSTRUCTIONS (read before filling)

Posture: intent-extraction, not interview.
1. Gather context FIRST — read CLAUDE.md, .features/INDEX.md, recent feature briefs,
   and 1–2 scoped repo files relevant to this feature. Don't ask before inspecting.
2. Propose ideas or draft inferable sections (Problem, Context, Constraints) from
   inference. Label inferred content with source: <!-- inferred from CLAUDE.md -->
3. Ask only intent-level questions (Motivation, Vision). Soft cap ~3 questions total.
4. Forbidden question types:
   - Research/plan-phase questions (what files to touch, what data flows look like)
   - Code-logic questions (how to implement)
   - Anything answerable by inspecting CLAUDE.md / INDEX.md / scoped repo files
5. Every question MUST come paired with a **Recommended**: line carrying a proposed
   answer or idea — the user should be able to confirm/redirect quickly.
6. All 5 sections below are required, but Problem / Context / Constraints are usually
   fillable by interpretation. Don't ask one question per section.
===================================================================== -->

## Short Description

<!-- One sentence reused by INDEX.md, status, handoff, and archive context. Prefer <= 200 chars. -->

## Long Description

<!-- Optional 1-3 paragraph reusable description. Use when the short description is not enough. -->

## Motivation

<!-- WHY does this need to exist? What's the driving force? What happens if we don't build this?
     Intent-level — usually requires a question to the user. -->

## Problem

<!-- WHO has this problem? What's their current experience? What pain are they feeling?
     Often inferable from Motivation + repo. If inferred, label with source:
     <!-- inferred from CLAUDE.md / .features/INDEX.md / etc. --> -->

## Vision

<!-- What does success look like? How will we know it worked? What changes for the user?
     Intent-level — usually requires a question to the user. -->

## Context

- **Stakeholders**: <!-- who cares — usually inferable from CLAUDE.md or feature topic; label inferred -->
- **Urgency**: <!-- why now, what's the trigger — usually inferable from project state; label inferred -->
- **Prior attempts**: <!-- what's been tried before — usually inferable from .features/ history; label inferred -->
- **Related work**: <!-- other features, systems, or initiatives this connects to — inferable from INDEX.md -->

## Constraints

<!-- Non-negotiables: technical limits, timeline, budget, compliance, dependencies.
     Usually inferable from CLAUDE.md + repo conventions. Label inferred content. -->

## Q&A Record

<!-- Each entry: the question, Claude's recommended answer, and the user's actual answer.
     Soft cap ~3 questions. Every question MUST include a **Recommended**: line.
     Skip questions that are answerable by inspection — don't pad the record. -->

### Q1: [Intent-level question, e.g. "What is the primary motivation for X?"]

**Recommended**: [Claude's proposed answer based on CLAUDE.md / INDEX / scoped repo inspection — be specific, not generic]
**Answer**: [User's actual answer — confirm, modify, or redirect the recommendation]

<!-- Add Q2 / Q3 only if needed. Most briefs will not need more than 1–3 questions. -->
