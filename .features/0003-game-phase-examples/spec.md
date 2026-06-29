---
id: SPEC-0003
feature: "0003-game-phase-examples"
title: "Game Phase Examples"
type: spec
schema_version: 2
status: completed
phase: design
created: 2026-06-29
updated: 2026-06-29
source: BRIEF-0003
links: {"derived_from":["BRIEF-0003"],"informed_by":[],"supersedes":[]}
based_on: {"BRIEF-0003":"sha256:1f4da451b07b2a2a22605af98dca91783df392f6ae25df45b60cb880efc6d856"}
related:
  brief: BRIEF-0003
  research: RESEARCH-0003
  plan: PLAN-0003
  tasks: TASKS-0003
  review: REVIEW-0003
  scratchpad: SCRATCH-0003
  continuity: CONT-0003
  knowledge: KB-0003
tags: []
---

# Spec: Game Phase Examples

## Problem

Ein Spieler der das SDD-Lernspiel durchspielt versteht die Prinzipien jeder Phase — aber nicht das konkrete Handwerk. Nach dem Feedback einer Phase fehlt die Brücke zur Praxis: Welchen Befehl tippe ich? Was tut Claude Code automatisch? Welche Datei liegt danach auf der Festplatte? Diese Lücke verhindert, dass Spieler das SDD-Plugin direkt nach dem Spiel eigenständig einsetzen können.

## Solution

Nach dem Feedback jeder Phase erscheint automatisch ein Beispiel-Panel mit vier Zeilen (🧑 Product Owner / 👤 Entwickler / 🤖 Claude Code / 📄 Artefakt), das zeigt wie diese Phase in einer echten SDD-Session aussieht. Das Panel erscheint vor der Frage der Phase. Der Zurück-Mechanismus (z-Taste) wird entfernt, da er mit dem neuen Panel-Layout mehrdeutig würde. Die Beispielinhalte für alle 7 Phasen sind in brief.md Q3 vollständig dokumentiert und abgenommen.

## User Stories

- US-01: Als SDD-Einsteiger möchte ich nach dem Feedback jeder Phase ein konkretes Praxisbeispiel sehen, damit ich nach dem Spiel sofort weiß wie ich SDD im Terminal anwende.
- US-02: Als Spieler möchte ich das Beispiel-Panel vor der Phasenfrage sehen, damit ich mit Kontext in die Frage starte.
- US-03: Als Spieler möchte ich, dass der Product Owner in jedem Phase-Panel sichtbar ist — mit seiner aktiven Rolle oder dem expliziten Hinweis, dass er in dieser Phase keine Aufgabe hat.

## Functional Requirements

- FR-001: Das Spiel zeigt in jeder Phase ein Beispiel-Panel mit genau vier Feldern: 🧑 Product Owner, 👤 Entwickler, 🤖 Claude Code, 📄 Artefakt.
- FR-002: Das Beispiel-Panel erscheint automatisch vor der Phasenfrage, ohne Extra-Tastendruck.
- FR-003: In Phasen ohne PO-Beteiligung zeigt das PO-Feld explizit "Keine Aufgabe in dieser Phase" plus eine kurze Begründung.
- FR-004: Der Zurück-Mechanismus (z-Taste) wird aus dem Spiel entfernt.
- FR-005: Die Beispielinhalte entsprechen den in brief.md Q3 abgenommenen Texten für alle 7 Phasen.
- FR-006: Das Beispiel-Panel ist kompakt genug, um zusammen mit der Phasenfrage auf einen Bildschirm zu passen.

## Acceptance Criteria

- [ ] AC-001: Gegeben eine laufende Spielsession, wenn der Spieler das Feedback einer Phase bestätigt, dann erscheint das Beispiel-Panel automatisch vor der nächsten Phasenfrage — ohne zusätzlichen Tastendruck.
- [ ] AC-002: Gegeben Phase 1 (Brief), wenn das Beispiel-Panel angezeigt wird, dann enthält es alle vier Felder (🧑 PO, 👤 Entwickler, 🤖 Claude Code, 📄 Artefakt) mit den abgenommenen Inhalten aus brief.md Q3.
- [ ] AC-003: Gegeben Phase 3 (Research), wenn das Beispiel-Panel angezeigt wird, dann enthält das PO-Feld den Text "Keine Aufgabe in dieser Phase" mit Begründung.
- [ ] AC-004: Gegeben eine laufende Spielsession, wenn der Spieler eine Antwort bestätigt, dann ist die z-Taste deaktiviert und hat keine Wirkung.
- [ ] AC-005: Gegeben alle 7 Phasen, wenn die Beispiel-Panels angezeigt werden, dann stimmen die angezeigten Texte exakt mit den in brief.md Q3 abgenommenen Inhalten überein.
- [ ] AC-006: Gegeben ein Terminal mit 80 Zeichen Breite, wenn das Beispiel-Panel angezeigt wird, dann passt es zusammen mit der Phasenfrage auf einen Bildschirm ohne Scrollen.

## Non-Goals

- Kein interaktiver Hilfe-Screen zur Erklärung des Unterschieds zwischen CLI-Befehlen (`sdd spec`) und Skills (`/sdd-spec`) — wird als separates Feature behandelt.
- Keine Änderung der Spiellogik oder Frageninhalte aus 0001/0002.
- Keine neuen Python-Abhängigkeiten.
- Keine Mehrsprachigkeit der Beispielinhalte.

## Constraints

- Erweitert `game.py` aus 0001/0002 — kein Neuschreiben.
- Python 3 stdlib only.
- Linearer Spielablauf: kein Zurück-Mechanismus nach Entfernung der z-Taste.
- 7 Phasen × 4 Felder = 28 Beispieltexte — alle in brief.md Q3 abgenommen.

## Open Questions

<!-- Keine offenen Fragen — alle Intent-Entscheidungen in Brief Q&A dokumentiert. -->
