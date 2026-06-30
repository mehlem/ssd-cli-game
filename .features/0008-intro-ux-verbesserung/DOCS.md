# Technical Reference: Intro UX Verbesserung

## Architecture Overview

Das Feature greift an zwei Punkten in `game.py` ein:

- `show_intro()` — Intro-Sequenz beim Spielstart; enthält Banner-Anzeige und anschließenden Warteblock
- `pause()` — zentrale Pause-Funktion; wird von der Titelseite und allen anderen Stellen im Spiel aufgerufen

Beide Funktionen bleiben eigenständig. Die Verbindung zwischen ihnen ist, dass `show_intro()` am Ende `pause()` mit einem überschriebenen `msg`-Parameter aufruft, um den titelseiten-spezifischen Text zu erzeugen. Die allgemeine Beendigungslogik (`sys.exit`) sitzt ausschließlich in `pause()` und wirkt damit an allen Stellen, ohne jeden Aufrufer zu modifizieren.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | Modified | Einzige geänderte Datei; enthält `show_intro()` (Banner + Loading-Animation) und `pause()` (Beenden-Option) |

Kein research.md vorhanden (lite-Profil); die genauen geänderten Zeilen laut tasks.md: `show_intro()` Zeile 203 (Animations-Loop), `pause()` Zeile 78 (Exit-Logik), Titelseiten-`pause()`-Aufruf Zeile 213.

## Interface Changes

### `show_intro()` — geändert

- Ersetzt: `time.sleep(4)` (einzelner Schlaf-Aufruf)
- Durch: Animations-Loop mit Schritten "loading." / "loading.." / "loading..." über ~4 Sekunden Gesamtdauer
- Kein Signatur-Change; keine neuen Parameter

### `pause()` — geändert

- Standard-`msg` enthält jetzt "[x für Ende]"
- Neu: Eingabe "x" löst `sys.exit(0)` aus
- Titelseiten-Aufruf: `pause(msg="[ Enter drücken um zu starten ] [x für Ende]")` (Parameterübergabe, keine neue Funktion)
- Imports: `sys` muss importiert sein (stdlib, kein neuer Dependency)

## Testing & Verification

Alle Checks nutzen `inspect.getsource()` und laufen direkt über die Python-Laufzeit ohne separates Test-Framework.

**T-001 — Loading-Animation:**
```bash
py -c "import inspect, game; src = inspect.getsource(game.show_intro); assert 'loading' in src, 'FAIL: loading-Animation fehlt'; print('OK')"
```

**T-002 — Exit-Option und Titelseiten-Text (kombiniert):**
```bash
py -c "
import inspect, game
src_pause = inspect.getsource(game.pause)
src_intro = inspect.getsource(game.show_intro)
assert 'x für Ende' in src_pause, 'FAIL: x für Ende fehlt in pause()'
assert 'sys.exit' in src_pause, 'FAIL: sys.exit fehlt in pause()'
assert 'zu starten' in src_intro, 'FAIL: zu starten fehlt in show_intro()'
print('OK')
"
```

Alle vier AC-Checks liefen im Review durch und wurden als PASS dokumentiert.

## Known Limitations

- Die Code-Quality-Matrix im Review (Correctness, Tests, Security, Performance, Readability, Smallest viable solution, Unrequested work, Scope discipline) wurde nicht ausgefüllt — alle Felder zeigen "—". Eine formale Bewertung dieser Kategorien fehlt im Artefakt.
- Das lite-Profil enthielt kein research.md und kein plan.md. Die Scope-Conformance-Tabelle im Review konnte daher keinen Datei-Vergleich gegen einen Baseline durchführen; der Eintrag lautet "(no research.md found)".
- Die Files-Changed-Tabelle im Review enthält einen Platzhalter `[path]` statt des konkreten Dateipfads — eine direkte Zeilen-Diff-Zählung (+20, -5) ist angegeben, aber nicht gegen einen tatsächlichen Commit verifiziert.
- scratchpad.md und knowledge.md wurden initialisiert, aber nicht mit Beobachtungen oder wiederverwendbaren Erkenntnissen befüllt.

## Further Reading

- [README.md](README.md) — Narrativer Überblick: Problem, Entscheidungsrationale, Outcome
- [spec.md](spec.md) — Vollständige Anforderungsdefinition mit FR und AC
- [tasks.md](tasks.md) — Aufgabendetails, Scope Boundaries, Verifikationsbefehle
- [review.md](review.md) — AC-Validierungstabelle, Verdict PASS
