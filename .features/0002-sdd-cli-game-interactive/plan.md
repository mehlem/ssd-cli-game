---
id: PLAN-0002
feature: "0002-sdd-cli-game-interactive"
title: "Sdd Cli Game Interactive"
type: plan
schema_version: 2
status: completed
phase: plan
created: 2026-06-26
updated: 2026-06-26
source: RESEARCH-0002
links: {"derived_from":["RESEARCH-0002"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0002":"sha256:43494389d026bf276c7fe5bc24db5cc1b828e89fea29b48acb3d77d218345176","RESEARCH-0002":"sha256:cc6a5f2e0eb96f76dd3547bd2c9de5f07a5f832580b3393c53baeb782b758a09"}
related:
  brief: BRIEF-0002
  spec: SPEC-0002
  research: RESEARCH-0002
  tasks: TASKS-0002
  review: REVIEW-0002
  scratchpad: SCRATCH-0002
  continuity: CONT-0002
  knowledge: KB-0002
tags: []
---

# Plan: Sdd Cli Game Interactive

## Research Findings

- FC-001: `PHASES` hat 4 Schlüssel pro Dict (`game.py:179-222`) — `interaktion` als 5. Schlüssel ergänzen.
- FC-002: `run_phase()` gibt `None` zurück (`game.py:229`) — Signatur → `int` für Score.
- FC-003: `show_summary()` hat keine Parameter (`game.py:248`) — Signatur → `(score, total)`.
- FC-004/FC-005: `input().strip().lower()` Pattern bereits etabliert (`game.py:293`) — direkt übertragen.
- RISK-003: Interaktionsinhalte sind inhaltlich anspruchsvoll — Schema-Verifikation aller 7 Dicts als Pflicht.

## Architectural Decisions

- AD-001: `interaktion`-Feld direkt im PHASES-Dict (nicht separate Liste)
  - **Decision**: Jeder Phase-Dict erhält einen fünften Schlüssel `interaktion: dict` mit Frage, Optionen, Antwort und Feedback-Texten.
  - **Rationale**: Hält Phase-Daten und Interaktion zusammen — konsistent mit dem bestehenden Muster.
  - **Alternatives considered**: Separate `INTERACTIONS`-Liste — abgelehnt, paralleles Indexing fehleranfällig.

- AD-002: Neue Funktion `ask_question(q)` — typ-dispatched
  - **Decision**: `ask_question(q)` nimmt ein Interaktions-Dict, erkennt `q['typ']` (`"mc"`, `"passfail"`, `"order"`) und führt die passende Mechanik aus. Gibt `1` (richtig) oder `0` (falsch) zurück.
  - **Rationale**: Single responsibility, unabhängig testbar, erweiterbar ohne `run_phase()` anzufassen.
  - **Alternatives considered**: Inline in `run_phase()` — abgelehnt, run_phase würde zu groß.

- AD-003: `interaktion`-Dict-Schema
  - **Decision**: `{"typ": str, "frage": str, "optionen": list[str], "richtig": str, "feedback_richtig": str, "feedback_falsch": str}` — alle Felder als Strings, `richtig` ist der Wert der richtigen Option (z.B. `"1"`).
  - **Rationale**: Einfach, kein Boilerplate, direkt per `q['richtig'] == antwort` auswertbar.
  - **Alternatives considered**: Numerischer Index als `richtig` — abgelehnt, Strings robuster bei `input().strip()`.

- AD-004: `run_phase()` gibt `int` zurück, `main()` akkumuliert Score
  - **Decision**: `run_phase(phase)` ruft `ask_question(phase['interaktion'])` auf und gibt dessen Rückgabe zurück. `main()` akkumuliert: `score += run_phase(phase)`.
  - **Rationale**: Minimale Änderung, Score-Logik bleibt in `main()`.
  - **Alternatives considered**: Score-Objekt — abgelehnt, Overkill für 7 Runden.

- AD-005: Markdown-Frage in der Design-Phase (FR-002)
  - **Decision**: Die Frage über Markdown vs. JSON/XML/YAML landet in Phase 2 (Design), weil dort Artefakt-Formate thematisch passen — Design definiert WHAT, also auch WIE Anforderungen dokumentiert werden.
  - **Rationale**: Brief = WHY; Design = WHAT inkl. Artefaktformat. Passt besser zu Design.
  - **Alternatives considered**: Brief-Phase — dort geht es um Problemdefinition, nicht Artefakt-Format.

## Phases

### PH-01: Interaktions-Infrastruktur

> Addresses: FR-009, FR-010, FR-011
> Acceptance: AC-003, AC-006, AC-007, AC-008

`ask_question()` anlegen, `PHASES`-Dicts um leeres `interaktion`-Skeleton erweitern, `run_phase()` + `show_summary()` + `main()` anpassen. Nach diesem Slice ist das Gerüst testbar — alle Signaturen stimmen, Score wird gezählt.

### PH-02: Interaktionsinhalte Phase 1–4

> Addresses: FR-001, FR-002, FR-003, FR-004
> Acceptance: AC-001, AC-002

Interaktionsdaten für Brief (brief.md-Abschnitte), Design (Markdown-Frage + AC-Urteil), Research (Fakt/Hypothese/Unbekanntes) und Plan (Task-Reihenfolge) befüllen.

### PH-03: Interaktionsinhalte Phase 5–7

> Addresses: FR-005, FR-006, FR-007, FR-008
> Acceptance: AC-004, AC-005

Interaktionsdaten für Implement (Verifikation schlägt fehl), Review (PASS/FAIL-Urteil) und Close (knowledge.md-Inhalt) befüllen. Danach ist das Spiel vollständig interaktiv spielbar.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|:-----|:-------|:-----------|
| Falsche Interaktionsdaten in einem Dict (RISK-003) | Phase bricht visuell | Verifikationskommando prüft Schema aller 7 Dicts; `richtig` muss in `optionen` vorkommen |
| Ungültige `input()`-Eingabe (z.B. "5" statt "1-4") | Endlosschleife oder Crash | `ask_question()` enthält Retry-Loop bis gültige Eingabe |

## Open Questions

- (keine)
