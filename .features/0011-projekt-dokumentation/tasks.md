---
id: TASKS-0011
feature: "0011-projekt-dokumentation"
title: "Projekt Dokumentation"
type: tasks
schema_version: 2
profile: lite
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0011
  review: REVIEW-0011
tags: []
---

# Tasks: Projekt Dokumentation

## Approach

- T-001: `generate_docs.py` erstellen + `dokumentation.html` generieren.
- T-002: `show_summary()` um SDD-Dokumentationstext erweitern.

## T-001: generate_docs.py erstellen und dokumentation.html generieren

> Status: completed
> Phase: PH-01
> Implements: ["FR-001", "FR-002"]
> Files: ["generate_docs.py (create)"]

### Description

Python-Script das alle 9 .features/-Verzeichnisse liest und eine gestylte dokumentation.html generiert.

### Done When

- `generate_docs.py` existiert.
- `py generate_docs.py` erzeugt `dokumentation.html` mit mindestens 9 Feature-Namen.

### Scope Boundary

- In scope: neue Datei `generate_docs.py`.
- Out of scope: game.py.

### Acceptance Criteria

- [x] AC-001: `py generate_docs.py` läuft ohne Fehler und erzeugt `dokumentation.html`.
- [x] AC-002: `dokumentation.html` enthält mindestens 9 Feature-Namen.

### Verification

```bash
cd "C:\Users\mehlem\OneDrive - PTA-Gruppe\Lerning\KI\Claude-Code\SDD\SSD-Beispielprojekt" && py generate_docs.py && py -c "content = open('dokumentation.html', encoding='utf-8').read(); count = sum(1 for f in ['0001','0002','0003','0004','0005','0006','0007','0008','0009'] if f in content); assert count >= 9, f'Nur {count}/9 Features'; print(f'OK - {count}/9 Features in dokumentation.html')"
```

---

## T-002: Abschlussseite um Dokumentationshinweis erweitern

> Status: completed
> Phase: PH-02
> Implements: ["FR-003"]
> Depends-on: ["T-001"]
> Files: ["game.py (modify)"]

### Description

`show_summary()` erhält nach dem Score-Panel einen Abschnitt mit SDD-Erklärung und Hinweis auf `dokumentation.html`.

### Done When

- Abschlussseite zeigt Text zu SDD-Artefakten und `dokumentation.html`.

### Scope Boundary

- In scope: `show_summary()` in game.py.
- Out of scope: alles andere.

### Acceptance Criteria

- [x] AC-003: `inspect.getsource(show_summary)` enthält "dokumentation.html".

### Verification

```bash
py -c "import inspect, game; src = inspect.getsource(game.show_summary); assert 'dokumentation.html' in src, 'FAIL'; print('OK')"
```
