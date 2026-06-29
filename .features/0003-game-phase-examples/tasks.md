---
id: TASKS-0003
feature: "0003-game-phase-examples"
title: "Game Phase Examples"
type: tasks
schema_version: 2
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
source: PLAN-0003
links: {"derived_from":["PLAN-0003"],"informed_by":[],"supersedes":[]}
based_on: {"PLAN-0003":"sha256:fa6c5ab5fdb199307ca50f24200ba80eb5d4f1693e0d3042132c46d892480ab3"}
related:
  brief: BRIEF-0003
  spec: SPEC-0003
  research: RESEARCH-0003
  plan: PLAN-0003
  review: REVIEW-0003
  scratchpad: SCRATCH-0003
  continuity: CONT-0003
  knowledge: KB-0003
tags: []
---

# Tasks: Game Phase Examples

## Approach

- `PHASES`-Dicts erhalten ein neues `beispiel`-Feld mit den 4 abgenommenen Texten (T-001).
- `run_phase()` rendert das Panel via `print_box()` vor `ask_question()` (T-002).
- Zurück-Mechanismus (`can_go_back`, z-Taste, `phase_scores`) wird chirurgisch entfernt (T-003).

## T-001: beispiel-Daten in alle 7 PHASES-Dicts eintragen

> Status: completed
> Phase: PH-01
> Implements: ["FR-001", "FR-003", "FR-005"]
> Files: ["game.py (modify)"]

### Description

Jedes der 7 Dicts in der `PHASES`-Liste erhält ein neues Feld `beispiel` mit den 4 Strings `po`, `entwickler`, `claude`, `artefakt` — Inhalte gemäß brief.md Q3.

### Done When

- Alle 7 PHASES-Dicts haben ein `beispiel`-Feld mit den 4 Schlüsseln.
- Die Texte stimmen mit den in brief.md Q3 abgenommenen Inhalten überein.

### Non-Goals

- Kein Rendering — nur Dateneintrag.
- Keine Änderung an `run_phase()` oder `main()`.

### Scope Boundary

- In scope: `PHASES`-Liste in `game.py` (Zeilen 330–560), ausschließlich das neue `beispiel`-Feld.
- Out of scope: alle anderen Felder der Dicts, `run_phase()`, `main()`.

### Steps

1. Brief.md Q3-Tabelle lesen und die 28 Texte (7 × 4) entnehmen.
2. Jedem der 7 Dicts in `PHASES` das Feld `beispiel` mit den 4 Schlüsseln hinzufügen.

### Acceptance Criteria

- [x] Alle 7 Dicts haben `beispiel` mit Schlüsseln `po`, `entwickler`, `claude`, `artefakt`.
- [x] Phase-3-Dict (Research): `po`-Wert enthält "Keine Aufgabe".

### Verification

```bash
py -c "from game import PHASES; errs=[p['name'] for p in PHASES if not all(k in p.get('beispiel',{}) for k in ['po','entwickler','claude','artefakt'])]; print('FAIL:',errs) if errs else print('OK - alle 7 beispiel-Felder vorhanden'); assert not errs"
```

---

## T-002: Beispiel-Panel in run_phase() rendern

> Status: completed
> Phase: PH-02
> Implements: ["FR-002", "FR-006"]
> Depends-on: ["T-001"]
> Files: ["game.py (modify)"]

### Description

`run_phase()` ruft `print_box()` mit den 4 Beispiel-Zeilen auf — nach der Kernfrage-Ausgabe und vor `ask_question()`.

### Done When

- Das Beispiel-Panel erscheint automatisch vor der Phasenfrage.
- Das Panel zeigt alle 4 Felder (🧑, 👤, 🤖, 📄) der aktuellen Phase.

### Non-Goals

- Kein Entfernen des Zurück-Mechanismus — das ist T-003.
- Keine neue Hilfsfunktion — `print_box()` wird direkt aufgerufen.

### Scope Boundary

- In scope: `run_phase()` in `game.py` (Zeilen 567–588), Einfügestelle zwischen Z. 577 und Z. 578.
- Out of scope: `ask_question()`, `main()`, `PHASES`-Daten.

### Steps

1. In `run_phase()` nach der Kernfrage-Ausgabe (Z. 577) einen `print_box()`-Aufruf einfügen.
2. Panel-Inhalt: 4 Zeilen mit Emoji-Präfix aus `phase["beispiel"]`.

### Acceptance Criteria

- [x] `py game.py` starten — Beispiel-Panel erscheint vor der Frage jeder Phase.
- [x] Panel zeigt alle 4 Felder ohne zusätzlichen Tastendruck.

### Verification

```bash
py -c "
import io, sys
sys.stdout = io.StringIO()
from game import run_phase, PHASES
try:
    run_phase(PHASES[0])
except (EOFError, SystemExit):
    pass
out = sys.stdout.getvalue()
sys.stdout = sys.__stdout__
assert '🧑' in out or 'po' in out.lower() or 'Product Owner' in out, 'Beispiel-Panel fehlt'
print('OK - Beispiel-Panel wird gerendert')
"
```

---

## T-003: Zurück-Mechanismus entfernen

> Status: completed
> Phase: PH-03
> Implements: ["FR-004"]
> Depends-on: ["T-002"]
> Files: ["game.py (modify)"]

### Description

Entfernt `can_go_back`-Parameter aus `run_phase()`, z-Taste-Abfrage, `phase_scores`-Dict und Zurück-Logik aus `main()`. Score-Akkumulation wird vereinfacht.

### Done When

- `run_phase()` hat keinen `can_go_back`-Parameter mehr.
- `main()` verwendet keine `phase_scores`-Variable und keine `if result is None:`-Logik mehr.
- Das Spiel läuft linear durch alle 7 Phasen.

### Non-Goals

- Keine funktionalen Änderungen am Spielablauf außer dem Entfernen der Zurück-Navigation.

### Scope Boundary

- In scope: `run_phase()` Signatur und Navigation-Block (`game.py:567, 580–587`); `main()` Loop (`game.py:651–668`).
- Out of scope: `PHASES`-Daten, `ask_question()`, `show_summary()`.

### Steps

1. `can_go_back=False`-Parameter aus `run_phase()`-Signatur entfernen.
2. `if can_go_back:` Block entfernen, `else: pause()` durch `pause()` ersetzen.
3. In `main()`: `phase_scores`-Dict, `can_go_back=(i > 0)`-Argument und `if result is None:`-Block entfernen.
4. Score-Akkumulation vereinfachen: `score += result` direkt nach `run_phase()`-Aufruf.

### Acceptance Criteria

- [x] `py -c "import inspect, game; src = inspect.getsource(game.run_phase); assert 'can_go_back' not in src"` läuft ohne Fehler.
- [x] `py game.py` — z-Taste hat keine Wirkung, Spiel läuft linear.

### Verification

```bash
py -c "import inspect, game; src = inspect.getsource(game.run_phase); assert 'can_go_back' not in src, 'can_go_back noch vorhanden'; assert 'phase_scores' not in inspect.getsource(game.main), 'phase_scores noch vorhanden'; print('OK - Zurück-Mechanismus entfernt')"
```
