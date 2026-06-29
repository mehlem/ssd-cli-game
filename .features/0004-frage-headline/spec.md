---
id: SPEC-0004
feature: "0004-frage-headline"
title: "Frage Headline"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-29
updated: 2026-06-29
related:
  tasks: TASKS-0004
  review: REVIEW-0004
  scratchpad: SCRATCH-0004
tags: []
---

# Spec: Frage Headline

## Problem

Die Fragen-Box jeder Phase erscheint ohne Überschrift. Spieler sehen sofort den Fragetext, ohne einen einleitenden Kontext zu haben.

## Solution

Die Fragen-Box jeder Phase erhält als erste Zeile die Überschrift "Hier eine Verständnisfrage zur Arbeit mit SDD", gefolgt von einer Leerzeile und dem eigentlichen Fragetext.

## User Stories

- US-01: Als Spieler möchte ich eine Überschrift über der Frage sehen, damit ich sofort weiß dass es sich um eine Verständnisfrage handelt.

## Functional Requirements

- FR-001: Jede Fragen-Box zeigt als erste Zeile "Hier eine Verständnisfrage zur Arbeit mit SDD", dann eine Leerzeile, dann den Fragetext.

## Acceptance Criteria

- [ ] AC-001: Gegeben eine beliebige Phase, wenn die Fragen-Box angezeigt wird, dann lautet die erste Zeile der Box exakt "Hier eine Verständnisfrage zur Arbeit mit SDD".

## Non-Goals

- Keine Änderung am Fragetext, den Antwortoptionen oder dem Feedback.

## Constraints

- Nur `ask_question()` in `game.py` wird geändert.
- Keine neuen Abhängigkeiten.
