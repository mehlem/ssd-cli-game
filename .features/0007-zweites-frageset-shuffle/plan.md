---
id: PLAN-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: plan
schema_version: 2
status: completed
phase: plan
created: 2026-06-29
updated: 2026-06-29
source: RESEARCH-0007
links: {"derived_from":["RESEARCH-0007"],"informed_by":[],"supersedes":[]}
based_on: {"RESEARCH-0007":"sha256:05d79a6ec81fb5bb552199a9e51386ce5ea9c28b4cd2bf8b3eaa9902283f4742","SPEC-0007":"sha256:bfef0839dfa4db9a42a41dea6f42bcaf0a4d9be967e17f8ea65925a957d25cd3"}
related:
  brief: BRIEF-0007
  spec: SPEC-0007
  research: RESEARCH-0007
  tasks: TASKS-0007
  review: REVIEW-0007
  scratchpad: SCRATCH-0007
  continuity: CONT-0007
  knowledge: KB-0007
tags: []
---

# Plan: Zweites Frageset Shuffle

## Research Findings

- `PHASES`-Liste: 7 Dicts, jedes mit genau einem `interaktion`-Feld (game.py:330–602).
- `ask_question(q)` nutzt `q["richtig"]` als 1-basierten Positions-String — nicht als Antworttext. Beide Verwendungen (Auswertung game.py:313, Fehlertext game.py:319) sind positions-basiert.
- `random` bereits importiert (game.py:12). `run_phase()` ist die einzige Stelle die `phase["interaktion"]` aufruft (game.py:627).
- Kritisches Risiko: Shuffle muss `richtig` nach dem Mischen neu berechnen, sonst falsche Auswertung ohne Fehlermeldung.

## Architectural Decisions

- AD-001: Zweites Frageset als `fragen`-Liste in PHASES-Dicts speichern
  - **Decision**: Jedes PHASES-Dict erhält ein neues Feld `fragen: [interaktion_dict_1, interaktion_dict_2]`. Das alte `interaktion`-Feld wird entfernt sobald `run_phase()` auf `fragen` umgestellt ist.
  - **Rationale**: Eine Liste macht die Erweiterbarkeit auf N Fragen trivial, ohne neue Felder zu erfinden. Konsistenter als `interaktion2`.
  - **Alternatives considered**: Neues Feld `interaktion2` — abgelehnt, weil inkonsistent und nicht erweiterbar.

- AD-002: Shuffle-Logik in `run_phase()`, `ask_question()` bleibt unverändert
  - **Decision**: `run_phase()` wählt zufällig eine Frage aus `phase["fragen"]`, erstellt eine Kopie des Dicts mit gemischten `optionen` und aktualisiertem `richtig`, übergibt die Kopie an `ask_question()`.
  - **Rationale**: `ask_question()` ist eine reine Darstellungs-/Eingabefunktion ohne Wissen über Datenherkunft — sie muss nicht geändert werden. Shuffle-Logik gehört zur Phase-Steuerung in `run_phase()`.
  - **Alternatives considered**: `ask_question()` refaktorieren für Antworttext-Vergleich — abgelehnt, weil größerer Eingriff und keine Vorteile bei aktuellem Scope.

- AD-003: Positions-Update nach Shuffle via Textsuche
  - **Decision**: Korrekte Antwort vor dem Shuffle als Text merken (`correct_text = optionen[int(richtig)-1]`), nach dem Shuffle neue Position suchen (`str(shuffled.index(correct_text) + 1)`).
  - **Rationale**: Einfach, korrekt, kein Edge-Case-Risiko solange Antworttexte eindeutig sind (was sie in allen 14 Fragen sind).
  - **Alternatives considered**: Index-Tracking beim Shuffle — abgelehnt, komplexer und fehleranfälliger.

## Implementation Phases

### PH-01: Zweite Fragensets in PHASES-Struktur eintragen
Fügt `fragen`-Liste mit zwei interaktion-Dicts in alle 7 PHASES-Dicts ein. Das alte `interaktion`-Feld bleibt vorerst bestehen (kein Breaking Change).
- **Delivers**: FR-001
- **ACs covered**: AC-005
- **Demo**: `py -c "from game import PHASES; assert all(len(p['fragen'])==2 for p in PHASES); print('OK')"`

### PH-02: run_phase() auf fragen-Liste umstellen + Shuffle einbauen
Entfernt `phase["interaktion"]`-Zugriff, wählt zufällig aus `phase["fragen"]`, mischt optionen, aktualisiert richtig.
- **Delivers**: FR-002, FR-003, FR-004, FR-005, FR-006
- **ACs covered**: AC-001, AC-002, AC-003, AC-004

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|:-----|:-----------|:-------|:-----------|
| Positions-Update nach Shuffle fehlerhaft | mittel | hoch | AC-002/003 prüfen richtige und falsche Auswertung explizit; Verifikationsbefehl testet beide Pfade |
| Duplizierter Antworttext in einer Frage | niedrig | mittel | Alle 7 neuen Fragen haben eindeutige Antworttexte (brief.md Q3 geprüft) |
