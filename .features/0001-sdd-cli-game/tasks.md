---
id: TASKS-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: tasks
schema_version: 2
status: completed
phase: implement
created: 2026-06-26
updated: 2026-06-26
source: PLAN-0001
links: {"derived_from":["PLAN-0001"],"informed_by":[],"supersedes":[]}
based_on: {"PLAN-0001":"sha256:135084aaa68c6683af8c7ff0ffc1f433924cb30d8c8828ae5dd18ac4ef282cc8"}
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Tasks: Sdd Cli Game

## Approach

- Einzelne Datei `game.py` — kein Package, maximale Portabilität (AD-001).
- ANSI-Konstanten am Dateianfang, `print()`/`input()` als einzige I/O-Mechanismen (AD-002, AD-003).
- Phasendaten als `PHASES`-Liste von Dicts, kein Klassen-Boilerplate (AD-004).
- Skip-Intro via `.sdd_game_seen`-Marker-Datei relativ zu `__file__` (AD-005).

---

## T-001: Spielgerüst mit ANSI-Basis und Terminal-Hilfsfunktionen anlegen

> Status: completed
> Phase: PH-01
> Implements: ["FR-007", "FR-008"]
> Files: ["game.py (create)"]

### Description

`game.py` neu erstellen mit ANSI-Farbkonstanten, den vier Terminal-Hilfsfunktionen (`clear_screen`, `pause`, `print_centered`, `print_box`) und einem leeren `main()`-Skelett. Das Spiel startet und beendet sich ohne Inhalt sauber.

### Done When

- `game.py` existiert im Projektroot
- ANSI-Konstanten `GRÜN`, `ROT`, `GELB`, `FETT`, `RESET` sind definiert
- Funktionen `clear_screen()`, `pause()`, `print_centered()`, `print_box()` sind implementiert
- `main()` ist vorhanden und aufrufbar
- `py -m py_compile game.py` läuft fehlerfrei durch

### Non-Goals

- Noch kein Spielinhalt (Intro, Phasen, Zusammenfassung)

### Scope Boundary

- In scope: `game.py` (neu anlegen)
- Out of scope: `README.md`, `.features/`-Verzeichnis, alle anderen Dateien

### Steps

1. `game.py` anlegen mit Modul-Docstring und ANSI-Konstanten-Block
2. `clear_screen()` implementieren (`os.system('cls' if os.name == 'nt' else 'clear')`)
3. `pause(msg)` implementieren (`input(msg)`)
4. `print_centered(text, width)` implementieren (`shutil.get_terminal_size()` + `str.center()`)
5. `print_box(lines)` implementieren (Rahmen aus `─`, `│`, `┌`, `┐`, `└`, `┘`)
6. Leeres `main()` anlegen mit `if __name__ == '__main__': main()`

### Acceptance Criteria

- [x] `py -m py_compile game.py` gibt keinen Fehler aus
- [x] Alle vier Hilfsfunktionen sind per `import game` erreichbar

### Verification

```bash
py -c "import game; assert callable(game.clear_screen); assert callable(game.pause); assert callable(game.print_centered); assert callable(game.print_box); assert callable(game.main); print('T-001 OK')"
```

---

## T-002: Narrative Einleitung mit PTA-Geschichte und ASCII-Grafiken implementieren

> Status: completed
> Phase: PH-02
> Implements: ["FR-001", "FR-002"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-001"]

### Description

`show_intro()` in `game.py` implementieren: fiktive Geschichte eines PTA-Beraters in einem KI-Projekt das durch Vibe-Coding zu scheitern droht, mit mindestens einer ASCII-Grafik. Die Geschichte vermittelt den Kontrast Vibe-Coding vs. SDD explizit.

### Done When

- `show_intro()` ist implementiert und per `import game` erreichbar
- Die Funktion enthält mindestens eine ASCII-Grafik
- Der Begriff "PTA" und thematisch "Vibe-Coding" vs. "SDD" erscheinen im Quelltext
- `py -m py_compile game.py` läuft fehlerfrei durch

### Non-Goals

- Noch keine Skip-Intro-Logik (kommt in T-003)
- `main()` ruft `show_intro()` noch nicht auf

### Scope Boundary

- In scope: `show_intro()` Funktion in `game.py`
- Out of scope: Skip-Marker, `main()`-Dispatch, Phasen-Content

### Steps

1. Geschichte entwerfen: PTA-Berater "Max Muster" steckt in Chaos-Projekt, KI schreibt wilden Code ohne Struktur, Deadline naht
2. Kontrast-Szene: ein Kollege zeigt SDD — strukturiert, ruhig, kontrolliert
3. ASCII-Grafiken für beide Szenen einbauen (Chaos-Szene und SDD-Szene)
4. `show_intro()` mit `pause()`-Aufrufen zwischen Abschnitten fertigstellen

### Acceptance Criteria

- [x] `import game; game.show_intro` ist aufrufbar
- [x] Quelltext enthält "PTA" (Firmenreferenz in Story)
- [x] Quelltext enthält "Vibe" oder "vibe" (Vibe-Coding-Kontrast)

### Verification

```bash
py -c "import game; src = open('game.py', encoding='utf-8').read(); assert callable(game.show_intro), 'show_intro fehlt'; assert 'PTA' in src, 'PTA fehlt'; assert 'ibe' in src, 'Vibe-Coding-Kontrast fehlt'; print('T-002 OK')"
```

---

## T-003: Skip-Intro-Logik mit `.sdd_game_seen`-Marker implementieren

> Status: completed
> Phase: PH-02
> Implements: ["FR-009"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-002"]

### Description

`main()` prüft beim Start ob eine `.sdd_game_seen`-Datei im selben Verzeichnis wie `game.py` existiert. Falls ja, wird dem Spieler angeboten die Einleitung zu überspringen. Nach dem ersten vollständigen Intro-Durchlauf wird die Marker-Datei angelegt.

### Done When

- `main()` enthält die Marker-Prüflogik
- Marker-Pfad ist relativ zu `__file__` (nicht CWD)
- `sdd_game_seen` erscheint im Quelltext

### Non-Goals

- Kein vollständiger Spielablauf in `main()` (kommt in T-006)

### Scope Boundary

- In scope: `main()`-Funktion in `game.py`, Marker-Logik
- Out of scope: Phasen-Content, Zusammenfassung

### Steps

1. Marker-Pfad berechnen: `os.path.join(os.path.dirname(__file__), '.sdd_game_seen')`
2. In `main()`: wenn Marker existiert, `input("Intro überspringen? [j/n]: ")` abfragen
3. Nach `show_intro()`-Aufruf: Marker-Datei anlegen wenn noch nicht vorhanden

### Acceptance Criteria

- [x] `sdd_game_seen` erscheint im Quelltext von `game.py`
- [x] Marker-Pfad ist über `__file__` verankert (kein hartcodierter Pfad)

### Verification

```bash
py -c "src = open('game.py', encoding='utf-8').read(); assert 'sdd_game_seen' in src, 'Marker-Name fehlt'; assert '__file__' in src, '__file__ Verankerung fehlt'; print('T-003 OK')"
```

---

## T-004: PHASES-Datenstruktur mit allen 7 SDD-Phasen definieren

> Status: completed
> Phase: PH-03
> Implements: ["FR-003", "FR-004"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-001"]

### Description

Modul-Konstante `PHASES` als Liste von 7 Dicts definieren — je eine für Brief, Design, Research, Plan, Implement, Review, Close. Jeder Eintrag enthält `name`, `zweck`, `kernfrage` und `prompt` (simulierte Nutzereingabe).

### Done When

- `PHASES` ist eine Liste mit genau 7 Einträgen
- Jeder Eintrag hat die Schlüssel `name`, `zweck`, `kernfrage`, `prompt`
- Alle 7 SDD-Phasennamen (Brief, Design, Research, Plan, Implement, Review, Close) sind enthalten

### Non-Goals

- Noch keine `run_phase()`-Funktion (kommt in T-005)

### Scope Boundary

- In scope: `PHASES`-Konstante in `game.py`
- Out of scope: `run_phase()`, `main()`-Dispatch

### Steps

1. `PHASES`-Liste nach `show_intro()` in `game.py` einfügen
2. Für jede der 7 Phasen einen Dict mit `name`, `zweck`, `kernfrage`, `prompt` befüllen
3. Inhalte an das SDD-Methodenwissen aus `brief.md`/`spec.md` anlehnen

### Acceptance Criteria

- [x] `len(game.PHASES) == 7`
- [x] Alle 4 Schlüssel in jedem Dict vorhanden

### Verification

```bash
py -c "import game; assert len(game.PHASES) == 7, f'Erwartet 7, gefunden {len(game.PHASES)}'; assert all(all(k in p for k in ['name','zweck','kernfrage','prompt']) for p in game.PHASES), 'Fehlende Schlüssel'; print('T-004 OK')"
```

---

## T-005: run_phase() Funktion implementieren

> Status: completed
> Phase: PH-03
> Implements: ["FR-003", "FR-004", "FR-005"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-004"]

### Description

`run_phase(phase)` implementieren: zeigt Phasenname, Zweck und Kernfrage formatiert an, präsentiert einen simulierten Prompt und wartet auf Enter. Keine echten `sdd`-Befehle werden ausgeführt.

### Done When

- `run_phase()` ist aufrufbar und verarbeitet einen Phase-Dict
- Funktion führt keine Subprozesse oder `os.system('sdd ...')`-Aufrufe aus
- `py -m py_compile game.py` läuft fehlerfrei

### Non-Goals

- Noch kein vollständiger Spielablauf in `main()` (kommt in T-006)

### Scope Boundary

- In scope: `run_phase()` Funktion in `game.py`
- Out of scope: `main()`-Schleife, `show_summary()`

### Steps

1. `run_phase(phase)` definieren
2. Phasenkopf mit `print_box()` rendern (`phase['name']`)
3. Zweck und Kernfrage ausgeben
4. Simulierten Prompt mit `pause()` anzeigen
5. Sicherstellen: kein `subprocess`, kein `os.system('sdd')` in der Funktion

### Acceptance Criteria

- [x] `callable(game.run_phase)` ist True
- [x] Kein `subprocess` oder `os.system` Aufruf mit `sdd` in `run_phase`

### Verification

```bash
py -c "import game, inspect; assert callable(game.run_phase), 'run_phase fehlt'; src = inspect.getsource(game.run_phase); assert 'subprocess' not in src and \"os.system('sdd\" not in src, 'echte sdd-Befehle gefunden'; print('T-005 OK')"
```

---

## T-006: show_summary() implementieren und main() vollständig verdrahten

> Status: completed
> Phase: PH-04
> Implements: ["FR-006", "FR-010"]
> Files: ["game.py (modify)"]
> Depends-on: ["T-003", "T-005"]

### Description

`show_summary()` implementieren (listet alle 7 durchlaufenen Phasen auf). `main()` zu einem vollständigen Spielablauf verdrahten: Intro → 7 Phasen → Zusammenfassung. Spielbarer End-to-End-Durchlauf.

### Done When

- `show_summary()` ist implementiert und ruft alle 7 Phasennamen aus `PHASES` ab
- `main()` ruft in dieser Reihenfolge auf: Skip-Check → `show_intro()` → je `run_phase()` für alle 7 Phasen → `show_summary()`
- `py -m py_compile game.py` läuft fehlerfrei

### Non-Goals

- Kein README (kommt in T-007)

### Scope Boundary

- In scope: `show_summary()` und `main()` in `game.py`
- Out of scope: `README.md`, neue Phasendaten

### Steps

1. `show_summary(phases)` implementieren: Abschluss-Bannner + Auflistung aller 7 Phasennamen
2. `main()` verdrahten: Skip-Logik → `show_intro()` → `for phase in PHASES: run_phase(phase)` → `show_summary(PHASES)`
3. Sicherstellen dass Marker-Datei nach `show_intro()` angelegt wird

### Acceptance Criteria

- [x] `callable(game.show_summary)` ist True
- [x] `main()` Quelltext enthält Aufrufe zu `show_intro`, `run_phase` und `show_summary`

### Verification

```bash
py -c "import game, inspect; assert callable(game.show_summary), 'show_summary fehlt'; src = inspect.getsource(game.main); assert 'show_intro' in src, 'show_intro fehlt in main'; assert 'run_phase' in src, 'run_phase fehlt in main'; assert 'show_summary' in src, 'show_summary fehlt in main'; print('T-006 OK')"
```

---

## T-007: README.md mit Startanleitung erstellen

> Status: completed
> Phase: PH-04
> Implements: ["FR-007", "FR-008"]
> Files: ["README.md (create)"]
> Depends-on: ["T-006"]

### Description

`README.md` im Projektroot anlegen mit Kurzbeschreibung des Spiels, Voraussetzungen (Python 3.x) und Startanleitung für Windows (`py game.py`) und Unix (`python3 game.py`). Hinweis auf Windows Terminal als Zielplattform für ANSI-Farben.

### Done When

- `README.md` existiert im Projektroot
- Enthält `py game.py` (Windows-Aufruf)
- Enthält `python3 game.py` oder `python game.py` (Unix-Aufruf)
- Enthält Hinweis auf Windows Terminal

### Non-Goals

- Keine API-Dokumentation, keine Entwicklerdoku

### Scope Boundary

- In scope: `README.md` (neu anlegen)
- Out of scope: `game.py`

### Steps

1. `README.md` anlegen mit Titel und Kurzbeschreibung
2. Abschnitt "Voraussetzungen": Python 3.8+
3. Abschnitt "Starten": Windows (`py game.py`) und Unix (`python3 game.py`)
4. Hinweis: Windows Terminal empfohlen für Farben

### Acceptance Criteria

- [x] `README.md` existiert im Projektroot
- [x] Datei enthält `py game.py`
- [x] Datei enthält Hinweis auf Windows Terminal

### Verification

```bash
py -c "import os; content = open('README.md').read(); assert os.path.exists('README.md'), 'README fehlt'; assert 'py game.py' in content, 'Windows-Aufruf fehlt'; assert 'Windows Terminal' in content or 'windows terminal' in content.lower(), 'Windows Terminal Hinweis fehlt'; print('T-007 OK')"
```
