---
id: TASKS-0002
feature: "0002-sdd-cli-game-interactive"
title: "Sdd Cli Game Interactive"
type: tasks
schema_version: 2
status: completed
phase: implement
created: 2026-06-26
updated: 2026-06-26
source: PLAN-0002
links: {"derived_from":["PLAN-0002"],"informed_by":[],"supersedes":[]}
based_on: {"PLAN-0002":"sha256:e571e8878943b11889b151b5936eef35dde7020e2d00beb90a4063550f128b6e"}
related:
  brief: BRIEF-0002
  spec: SPEC-0002
  research: RESEARCH-0002
  plan: PLAN-0002
  review: REVIEW-0002
  scratchpad: SCRATCH-0002
  continuity: CONT-0002
  knowledge: KB-0002
tags: []
---

# Tasks: Sdd Cli Game Interactive

## Approach

- `ask_question(q)` als neue, typ-dispatched Funktion in `game.py` (AD-002).
- `interaktion`-Feld in jeden PHASES-Dict einfügen (AD-001, AD-003).
- `run_phase()` → gibt `int` zurück; `show_summary(score, total)` → zeigt Score; `main()` akkumuliert (AD-004).
- Interaktionsinhalte phase-weise befüllen — jede Phase hat genau eine Frage mit SDD-Prinzip im Feedback.

---

## T-001: ask_question()-Infrastruktur und PHASES-Schema anlegen

> Status: completed
> Phase: PH-01
> Implements: ["FR-009", "FR-010", "FR-011"]
> Files: ["game.py (modify)"]

### Description

`ask_question(q)` implementieren (Retry-Loop, Feedback mit SDD-Prinzip, gibt 0/1 zurück). Alle 7 PHASES-Dicts um ein Skeleton-`interaktion`-Dict ergänzen. `run_phase()`, `show_summary()` und `main()` auf Score-Tracking anpassen.

### Done When

- `ask_question` ist aufrufbar und gibt `int` zurück
- Alle 7 `PHASES`-Dicts haben den Schlüssel `interaktion` mit den 6 Pflichtfeldern (`typ`, `frage`, `optionen`, `richtig`, `feedback_richtig`, `feedback_falsch`)
- `run_phase()` gibt `int` zurück
- `show_summary(score, total)` zeigt Score-Zeile
- `main()` akkumuliert Score

### Non-Goals

- Noch keine inhaltlichen Fragen (kommen in T-002–T-004)

### Scope Boundary

- In scope: `ask_question()`, `PHASES`-Schema, `run_phase()`, `show_summary()`, `main()`
- Out of scope: Inhalte der `interaktion`-Dicts

### Steps

1. `ask_question(q)` mit Retry-Loop, MC-Auswertung, Feedback implementieren
2. Alle 7 PHASES-Dicts um `interaktion`-Skeleton-Dict ergänzen (Platzhalter-Texte)
3. `run_phase(phase)` → gibt `ask_question(phase['interaktion'])` zurück
4. `show_summary(score, total)` → fügt Score-Zeile hinzu
5. `main()` → `score = 0`, `score += run_phase(phase)`, `show_summary(score, 7)`

### Acceptance Criteria

- [x] `ask_question` ist callable
- [x] Alle 7 PHASES-Dicts haben `interaktion` mit 6 Feldern
- [x] `run_phase()` gibt `int` zurück (prüfbar per `isinstance`)
- [x] `show_summary` akzeptiert 2 Parameter

### Verification

```bash
py -c "import game, inspect; assert callable(game.ask_question); assert all('interaktion' in p for p in game.PHASES); assert all(all(k in p['interaktion'] for k in ['typ','frage','optionen','richtig','feedback_richtig','feedback_falsch']) for p in game.PHASES); src = inspect.getsource(game.run_phase); assert 'ask_question' in src; assert 'score' in inspect.getsource(game.show_summary); print('T-001 OK')"
```

---

## T-002: Interaktionsdaten Brief-Phase (brief.md-Abschnitte)

> Status: completed
> Phase: PH-02
> Implements: ["FR-001"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-001"]

### Description

`PHASES[0]['interaktion']` mit einer Multiple-Choice-Frage befüllen, die zeigt was brief.md leisten muss: Spieler wählt welche Kombination der 5 Pflichtabschnitte korrekt ist. Feedback nennt explizit das SDD-Prinzip.

### Done When

- `PHASES[0]['interaktion']['frage']` enthält "brief.md" und mindestens zwei der fünf Abschnittsnamen
- `feedback_richtig` und `feedback_falsch` enthalten "In SDD" oder "Das SDD-Plugin"

### Non-Goals

- Keine anderen Phasen-Dicts verändern

### Scope Boundary

- In scope: `PHASES[0]['interaktion']` in `game.py`
- Out of scope: alle anderen PHASES-Einträge

### Steps

1. Frage formulieren: "Welche Abschnitte gehören zwingend in eine brief.md?"
2. 4 Optionen definieren (nur eine vollständig korrekt)
3. Feedback mit SDD-Prinzip: "In SDD gilt: brief.md beantwortet WHY…"

### Acceptance Criteria

- [x] `PHASES[0]['interaktion']['frage']` enthält "brief.md"
- [x] Feedback enthält "In SDD" oder "Das SDD-Plugin"

### Verification

```bash
py -c "import game; q = game.PHASES[0]['interaktion']; assert 'brief.md' in q['frage'], 'brief.md fehlt in Frage'; assert 'In SDD' in q['feedback_richtig'] or 'Das SDD-Plugin' in q['feedback_richtig'], 'SDD-Prinzip fehlt in feedback_richtig'; print('T-002 OK')"
```

---

## T-003: Interaktionsdaten Design-Phase (Markdown-Frage + AC-Urteil)

> Status: completed
> Phase: PH-02
> Implements: ["FR-002", "FR-003"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-001"]

### Description

`PHASES[1]['interaktion']` befüllen: Frage über Markdown vs. JSON/XML/YAML als SDD-Artefaktformat (FR-002). Alternativ: AC-Urteilsfrage (FR-003) — da beide in Design-Phase, eine Frage pro Phase → Markdown-Frage hat Vorrang (AC-002 prüft explizit Formatnamen).

### Done When

- `PHASES[1]['interaktion']['frage']` enthält "Markdown", "JSON" und mindestens ein weiteres Format
- Feedback enthält SDD-Prinzip-Satz

### Non-Goals

- Keine anderen PHASES-Einträge verändern
- FR-003 (AC-Urteil) wird als eigenständige Frage in T-003 nicht separat implementiert — die Markdown-Frage deckt AC-002 ab; FR-003 ist im Feedback der Frage implizit enthalten

### Scope Boundary

- In scope: `PHASES[1]['interaktion']` in `game.py`
- Out of scope: alle anderen PHASES-Einträge

### Steps

1. Frage: "Warum verwendet SDD Markdown-Dateien statt JSON oder XML für Artefakte?"
2. 4 Optionen — richtige Antwort: menschenlesbar, versionierbar, kein Tool nötig
3. Feedback mit Vergleich: JSON/XML = maschinenoptimiert, Markdown = kollaborativ + versionierbar

### Acceptance Criteria

- [x] `PHASES[1]['interaktion']['frage']` enthält "Markdown" und "JSON"
- [x] Feedback enthält "In SDD" oder "Das SDD-Plugin"

### Verification

```bash
py -c "import game; q = game.PHASES[1]['interaktion']; src = q['frage']; assert 'Markdown' in src and 'JSON' in src, 'Format-Begriffe fehlen'; assert 'In SDD' in q['feedback_richtig'] or 'Das SDD-Plugin' in q['feedback_richtig'], 'SDD-Prinzip fehlt'; print('T-003 OK')"
```

---

## T-004: Interaktionsdaten Research + Plan-Phase

> Status: completed
> Phase: PH-02
> Implements: ["FR-004", "FR-005"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-001"]

### Description

`PHASES[2]['interaktion']` (Research): Fakt/Hypothese/Unbekanntes-Unterscheidung — Evidence-Only-Regel. `PHASES[3]['interaktion']` (Plan): Task-Reihenfolge nach Abhängigkeiten ordnen.

### Done When

- `PHASES[2]['interaktion']['frage']` enthält "Fakt" oder "Hypothese" oder "bestätigt"
- `PHASES[3]['interaktion']['frage']` enthält "Reihenfolge" oder "Abhängigkeit" oder "Task"
- Beide Feedbacks enthalten SDD-Prinzip-Satz

### Non-Goals

- Keine anderen PHASES-Einträge verändern

### Scope Boundary

- In scope: `PHASES[2]['interaktion']` und `PHASES[3]['interaktion']`
- Out of scope: alle anderen PHASES-Einträge

### Steps

1. Research-Frage: 3 Aussagen zeigen — welche ist ein Fakt (mit Dateireferenz)?
2. Plan-Frage: 3 Tasks in falscher Reihenfolge — Spieler wählt korrekte Sequenz

### Acceptance Criteria

- [x] `PHASES[2]['interaktion']['frage']` enthält Begriff für Evidence-Regel
- [x] `PHASES[3]['interaktion']['frage']` enthält Begriff für Task-Abhängigkeit

### Verification

```bash
py -c "import game; r = game.PHASES[2]['interaktion']; p = game.PHASES[3]['interaktion']; assert any(w in r['frage'] for w in ['Fakt','Hypothese','bestätigt','Beweis']), 'Research-Frage unklar'; assert any(w in p['frage'] for w in ['Reihenfolge','Abhängigkeit','Task','Sequenz']), 'Plan-Frage unklar'; assert 'In SDD' in r['feedback_richtig'] or 'Das SDD-Plugin' in r['feedback_richtig']; print('T-004 OK')"
```

---

## T-005: Interaktionsdaten Implement + Review + Close-Phase

> Status: completed
> Phase: PH-03
> Implements: ["FR-006", "FR-007", "FR-008"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-001"]

### Description

`PHASES[4]['interaktion']` (Implement): Verifikationskommando schlägt fehl — was tun? `PHASES[5]['interaktion']` (Review): AC vs. Code — PASS oder FAIL? `PHASES[6]['interaktion']` (Close): Was gehört ins knowledge.md?

### Done When

- `PHASES[4]['interaktion']['frage']` enthält "Verifikation" oder "schlägt fehl"
- `PHASES[5]['interaktion']['frage']` enthält "PASS" oder "FAIL" oder "AC"
- `PHASES[6]['interaktion']['frage']` enthält "knowledge.md" oder "Wissen"
- Alle drei Feedbacks enthalten SDD-Prinzip-Satz

### Non-Goals

- Keine anderen PHASES-Einträge verändern

### Scope Boundary

- In scope: `PHASES[4]`, `PHASES[5]`, `PHASES[6]` `interaktion`-Felder
- Out of scope: alle anderen PHASES-Einträge

### Steps

1. Implement-Frage: Szenario — py -c schlägt fehl, 3 Reaktionen zur Auswahl
2. Review-Frage: AC zeigen + Code-Beschreibung, Spieler urteilt PASS oder FAIL
3. Close-Frage: 3 Optionen — welche gehört in knowledge.md?

### Acceptance Criteria

- [x] `PHASES[4]['interaktion']['frage']` enthält Verifikations-Begriff
- [x] `PHASES[5]['interaktion']['frage']` enthält PASS/FAIL/AC-Begriff
- [x] `PHASES[6]['interaktion']['frage']` enthält knowledge.md-Begriff

### Verification

```bash
py -c "import game; i=game.PHASES[4]['interaktion']; r=game.PHASES[5]['interaktion']; c=game.PHASES[6]['interaktion']; assert any(w in i['frage'] for w in ['Verifikation','schlägt','fehl','verifizier']), 'Implement-Frage unklar'; assert any(w in r['frage'] for w in ['PASS','FAIL','AC','Kriterium']), 'Review-Frage unklar'; assert any(w in c['frage'] for w in ['knowledge','Wissen','KNOWLEDGE']), 'Close-Frage unklar'; print('T-005 OK')"
```
