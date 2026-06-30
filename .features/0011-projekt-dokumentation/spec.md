---
id: SPEC-0010
feature: "0010-projekt-dokumentation"
title: "Projekt Dokumentation"
type: spec
schema_version: 2
profile: lite
status: completed
phase: spec
created: 2026-06-29
updated: 2026-06-29
related:
  tasks: TASKS-0010
  review: REVIEW-0010
tags: []
---

# Spec: Projekt Dokumentation

## Problem

Das Spiel hat keine Verlinkung auf die SDD-Projektdokumentation. Spieler und Entwickler sehen nicht, wie das Spiel selbst mit SDD entwickelt wurde.

## Solution

Ein Python-Script `generate_docs.py` liest alle .features/0001-0009/ Artefakte und generiert `dokumentation.html`. Die Abschlussseite des Spiels erhält einen erklärenden Text zu SDD-Artefakten und eine Einladung, `dokumentation.html` zu öffnen.

## Functional Requirements

- FR-001: `generate_docs.py` liest alle 9 Features und generiert `dokumentation.html`.
- FR-002: `dokumentation.html` enthält pro Feature: Titel, Beschreibung, Spec-ACs und Review-Verdict.
- FR-003: `show_summary()` zeigt nach dem Score-Panel einen Text zu SDD-Artefakten und den Dateinamen `dokumentation.html`.

## Acceptance Criteria

- [ ] AC-001: `generate_docs.py` existiert und ist ausführbar — `py generate_docs.py` erzeugt `dokumentation.html`.
- [ ] AC-002: `dokumentation.html` enthält mindestens 9 Feature-Namen.
- [ ] AC-003: `inspect.getsource(show_summary)` enthält "dokumentation.html".

## Constraints

- Python 3 stdlib only (kein Markdown-Parser — direkte Text-Extraktion).
- Nur `game.py` und neue Datei `generate_docs.py` werden erstellt/geändert.
