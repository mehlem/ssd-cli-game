# Technical Reference: Projekt Dokumentation

## Architecture Overview

Das Feature besteht aus zwei unabhängig nutzbaren Teilen:

1. **Offline-Generator** (`generate_docs.py`): Liest `.features/0001-*/` bis `.features/0009-*/` per stdlib-Dateioperationen und schreibt eine einzelne, selbst enthaltene `dokumentation.html`. Kein Webserver, keine Laufzeit-Abhängigkeit.

2. **In-Game-Hinweis** (`game.py`, Funktion `show_summary()`): Zeigt nach dem Score-Panel einen statischen Text, der den Nutzer auf `dokumentation.html` hinweist. Keine Laufzeitkopplung an den Generator — der HTML-Hinweis ist ein hartcodierter String.

Die beiden Teile sind absichtlich entkoppelt: `generate_docs.py` kann ohne laufendes Spiel ausgeführt werden, und `game.py` referenziert `dokumentation.html` nur namentlich, ohne die Datei zu erzeugen oder zu öffnen.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `generate_docs.py` | Created | Liest alle 9 Feature-Verzeichnisse und schreibt `dokumentation.html`; Python 3 stdlib only |
| `game.py` | Modified | `show_summary()` erweitert um SDD-Erklärungstext und Dateinamen-Hinweis |
| `dokumentation.html` | Generated | Ausgabe von `generate_docs.py`; enthält Titel, Beschreibung, Spec-ACs und Review-Verdict je Feature |

Hinweis: `dokumentation.html` ist ein Artefakt des Generators, keine versionierte Quelldatei.

## Interface Changes

**Neuer Befehl:**
```
py generate_docs.py
```
Erzeugt `dokumentation.html` im Projektverzeichnis. Keine Argumente. Schlägt fehl, wenn `.features/0001-*/` bis `.features/0009-*/` nicht vorhanden sind.

**Geänderte Funktion:**
```
game.show_summary()
```
Zeigt nach dem Score-Panel zusätzlich einen Abschnitt mit SDD-Kontext und dem String `"dokumentation.html"`. Die Funktion hat keine neue Signatur und keine neuen Parameter.

## Testing & Verification

Beide Tasks haben explizite Verifikationsbefehle, die im Review als PASS bestätigt wurden.

**AC-001 + AC-002 — Generator erzeugt vollständige HTML:**
```bash
cd "<projektpfad>" && py generate_docs.py && py -c "content = open('dokumentation.html', encoding='utf-8').read(); count = sum(1 for f in ['0001','0002','0003','0004','0005','0006','0007','0008','0009'] if f in content); assert count >= 9, f'Nur {count}/9 Features'; print(f'OK - {count}/9 Features in dokumentation.html')"
```
Erwartete Ausgabe: `OK - 9/9 Features in dokumentation.html`

**AC-003 — `show_summary()` enthält Dateinamen-Hinweis:**
```bash
py -c "import inspect, game; src = inspect.getsource(game.show_summary); assert 'dokumentation.html' in src, 'FAIL'; print('OK')"
```
Erwartete Ausgabe: `OK`

Kein eigenständiges Test-Framework. Verifikation erfolgt direkt per Python-Einzeiler.

## Known Limitations

- `dokumentation.html` wird nicht automatisch bei Spielstart aktualisiert. Wenn neue Features zu `.features/` hinzukommen, muss `generate_docs.py` manuell neu ausgeführt werden.
- Der Generator ist auf genau 9 Feature-Verzeichnisse (0001–0009) ausgelegt. Erweiterbarkeit auf mehr Features ist nicht spezifiziert.
- Die Code-Quality-Tabelle im review.md ist nicht ausgefüllt (Felder für Correctness, Tests, Security etc. enthalten `—`). Limited information available über die interne Qualitätsbewertung.
- Es existiert kein research.md für dieses Feature (lite-Profil). Die Scope-Conformance-Tabelle im review.md verweist deshalb auf `(no research.md found)`.

## Further Reading

- [README.md](README.md) — Narrative Übersicht: Problem, Entscheidungen, Outcome
- [spec.md](spec.md) — Funktionale Anforderungen (FR-001–003) und Acceptance Criteria (AC-001–003)
- [tasks.md](tasks.md) — Task-Breakdown mit Scope Boundaries und Verifikationsbefehlen
- [review.md](review.md) — AC-Validierungstabelle und Verdict (pass)
