---
id: SPEC-0009
feature: "0009-loading-animation-fix"
title: "Loading Animation Fix"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-29
updated: 2026-06-29
related:
  tasks: TASKS-0009
  review: REVIEW-0009
tags: []
---

# Spec: Loading Animation Fix

## Problem

Die Loading-Animation zeigt maximal 3 Punkte (loop durch '.', '..', '...') unabhängig von der Anzeigedauer. Der Cursor blinkt sichtbar nach den Punkten. Die Farbe ist grau statt blau.

## Solution

Die Animation läuft zeitbasiert (~4 Sekunden) mit einem Punkt der sich pro 0,33s verlängert — ergibt ~12 Punkte. Der Cursor wird während der Animation ausgeblendet. Die Schrift ist blau (BLAU-Konstante).

## Functional Requirements

- FR-001: Punkte wachsen kontinuierlich über 3 hinaus für die gesamte Anzeigedauer.
- FR-002: Kein Cursor sichtbar während der Animation.
- FR-003: Animationstext ist blau gefärbt.

## Acceptance Criteria

- [ ] AC-001: `inspect.getsource(show_intro)` enthält `\033[?25l` (Cursor verbergen).
- [ ] AC-002: `inspect.getsource(show_intro)` enthält `BLAU` im Loading-Block.

## Constraints

- Nur `game.py`, nur der Loading-Animation-Block in `show_intro()`.
