---
id: SPEC-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: spec
schema_version: 2
status: completed
phase: design
created: 2026-06-29
updated: 2026-06-29
source: BRIEF-0007
links: {"derived_from":["BRIEF-0007"],"informed_by":[],"supersedes":[]}
based_on: {"BRIEF-0007":"sha256:3e18ade2784354fb78e389b4facf83d2adb86fffa9650f0278b43c0079467e93"}
related:
  brief: BRIEF-0007
  research: RESEARCH-0007
  plan: PLAN-0007
  tasks: TASKS-0007
  review: REVIEW-0007
  scratchpad: SCRATCH-0007
  continuity: CONT-0007
  knowledge: KB-0007
tags: []
---

# Spec: Zweites Frageset Shuffle

## Problem

Das SDD-Lernspiel hat pro Phase genau eine Frage mit vier Antworten in fester Reihenfolge. Nach dem ersten Durchlauf kennen Spieler die richtige Antwortnummer auswendig. Der Lerneffekt geht verloren, weil Positionslernen das inhaltliche Verstehen ersetzt.

## Solution

Jede Phase erhält ein zweites alternatives Fragenset. Beim Spielstart wird für jede Phase zufällig eine der zwei Fragen ausgewählt. Die Antwortoptionen werden bei jeder Frage in zufälliger Reihenfolge angezeigt. Das Spiel behält die korrekte Auswertung bei, unabhängig von der gemischten Reihenfolge. Die 7 neuen Fragen sind in brief.md Q3 dokumentiert und abgenommen.

## User Stories

- US-01: Als Spieler der das Spiel wiederholt möchte ich bei jedem Durchlauf andere Fragen und Antwort-Reihenfolgen sehen, damit ich wirklich verstehen muss und nicht auswendig lernen kann.
- US-02: Als Spieler möchte ich weiterhin sofort Feedback bekommen ob meine Antwort richtig oder falsch war, auch wenn die Optionen gemischt sind.

## Functional Requirements

- FR-001: Jede der 7 Phasen hat zwei alternative Fragensets, die gleichwertig das SDD-Prinzip der jeweiligen Phase testen.
- FR-002: Beim Spielstart wird für jede Phase zufällig (gleichverteilt) eines der zwei Fragensets gewählt.
- FR-003: Die Antwortoptionen jeder Frage werden bei jedem Spielstart in zufälliger Reihenfolge angezeigt.
- FR-004: Die Auswertung (richtig/falsch) funktioniert korrekt unabhängig von der gemischten Antwort-Reihenfolge.
- FR-005: Feedback-Texte (richtig und falsch) bleiben inhaltlich zur gewählten Frage passend.
- FR-006: Der Score wird weiterhin korrekt akkumuliert (1 Punkt pro richtiger Antwort, 7 Punkte maximal).

## Acceptance Criteria

- [ ] AC-001: Gegeben zwei Spielstarts hintereinander, wenn beide Male Phase 1 gespielt wird, dann erscheint mindestens einmal eine andere Frage oder eine andere Antwort-Reihenfolge (statistisch: bei 10 Starts ist die Wahrscheinlichkeit identischer Sequenz < 0,1%).
- [ ] AC-002: Gegeben eine beliebige Phase, wenn die richtige Antwort gewählt wird (auch nach dem Mischen), dann zeigt das Spiel "✓ Richtig!" und den korrekten feedback_richtig-Text.
- [ ] AC-003: Gegeben eine beliebige Phase, wenn eine falsche Antwort gewählt wird, dann zeigt das Spiel "✗ Nicht ganz." und den korrekten feedback_falsch-Text der gewählten Frage.
- [ ] AC-004: Gegeben ein kompletter Durchlauf mit 7 richtigen Antworten, dann ist der Score 7.
- [ ] AC-005: Gegeben ein Import von `game.PHASES`, dann hat jede Phase genau 2 Einträge in einer Fragensets-Liste (verifizierbar per Python-Assertion).

## Non-Goals

- Kein drittes oder weiteres Frageset.
- Keine Änderung an den Feedback-Texten der bestehenden (ersten) Fragen.
- Keine Persistierung welche Fragen bereits gespielt wurden (kein Session-Tracking).
- Keine Änderung am Spielablauf, Intro, Beispiel-Panels oder Abschluss-Zusammenfassung.

## Constraints

- Nur `game.py` wird geändert.
- Python 3 `random`-Modul (stdlib) für Zufallsauswahl und Mischen.
- Keine neuen Abhängigkeiten.
- Die 7 neuen Fragen sind in brief.md Q3 inhaltlich abgenommen.
