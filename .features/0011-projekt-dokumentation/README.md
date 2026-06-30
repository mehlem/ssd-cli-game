# Projekt Dokumentation

## Problem

Das Spiel besaß keine sichtbare Verbindung zu seiner eigenen Entstehungsgeschichte. Spieler und Entwickler konnten nicht nachvollziehen, dass das Spiel mit SDD (Spec-Driven Development) entwickelt wurde und welche Artefakte dabei entstanden sind. Die neun abgeschlossenen Features (0001–0009) lagen als strukturierte Artefakte vor, waren aber nicht zugänglich aufbereitet.

## Solution

Es wurden zwei Dinge gebaut: ein Python-Script `generate_docs.py`, das alle neun Feature-Verzeichnisse unter `.features/` liest und daraus eine gestylte `dokumentation.html` erzeugt, sowie eine Erweiterung von `show_summary()` in `game.py`, die auf der Abschlussseite des Spiels einen erklärenden Text zu SDD-Artefakten und einen Hinweis auf `dokumentation.html` einblendet.

Alle drei Acceptance Criteria wurden mit PASS bewertet. Das Feature ist abgeschlossen (Verdict: pass).

## Key Decisions

**Python stdlib only, kein Markdown-Parser.** Statt einer Abhängigkeit auf einen externen Markdown-Parser (z.B. `markdown` oder `mistune`) wurde direkte Textextraktion aus den Artefakt-Dateien gewählt. Das hält die Ausführungsvoraussetzungen auf Python 3 stdlib beschränkt und vermeidet ein Setup-Problem auf beliebigen Maschinen.

**Separate Generierungsdatei statt eingebettetem Code.** Die HTML-Generierung hätte alternativ direkt in `game.py` integriert werden können (z.B. als Funktion, die beim Spielstart aufgerufen wird). Die Entscheidung fiel auf eine eigenständige Datei `generate_docs.py`, um `game.py` nicht mit Build-Logik zu belasten und das Script unabhängig aufrufbar zu halten.

**Statische HTML-Datei statt Laufzeit-Rendering.** Anstelle einer dynamischen Anzeige im Spiel (etwa als eingebettetes Browser-Fenster oder Terminal-Ausgabe) wird eine statische `dokumentation.html` generiert, die der Nutzer separat öffnet. Das hält den Spielcode schlank und macht die Dokumentation auch außerhalb des Spiels zugänglich.

**Nur Dateinamen-Hinweis in `show_summary()`.** Eine vollständige Einbettung der Feature-Übersicht in die Abschlussseite wäre möglich gewesen, würde aber das Score-Panel optisch überladen. Stattdessen zeigt `show_summary()` nur einen kurzen Text mit dem Dateinamen `dokumentation.html` als Einladung.

## Outcome

Alle drei Acceptance Criteria wurden verifiziert:

- AC-001 (PASS): `py generate_docs.py` läuft fehlerfrei und erzeugt `dokumentation.html`.
- AC-002 (PASS): `dokumentation.html` enthält alle 9 Feature-Namen (0001–0009), verifiziert per String-Suche.
- AC-003 (PASS): `inspect.getsource(game.show_summary)` enthält den String `"dokumentation.html"`.

Keine kritischen oder minoren Issues wurden im Review dokumentiert. Die Prüfung auf hartcodierte Secrets ergab keinen Fund.

## Lessons Learned

Das scratchpad.md und knowledge.md dieses Features sind weitgehend leer — das Feature wurde im lite-Profil mit zwei klar abgegrenzten Tasks umgesetzt, die keine Kurskorrektur oder dokumentationswürdige Beobachtung erforderten. Das ist konsistent mit dem Scope: zwei neue Dateien, minimale Änderung an einer bestehenden Funktion.

Die Verifikationsstrategie per `inspect.getsource()` (AC-003) ist ein nützliches Muster, um das Vorhandensein eines bestimmten Strings in einer Python-Funktion ohne externes Test-Framework zu prüfen.

## Further Reading

- [DOCS.md](DOCS.md) — Technische Referenz: Komponenten, Interface-Änderungen, Verifikationsbefehle
- [spec.md](spec.md) — Problem, Solution, funktionale Anforderungen und Acceptance Criteria
- [tasks.md](tasks.md) — Aufgabenstruktur, Scope Boundaries, Verifikationsbefehle
- [review.md](review.md) — AC-Validierungstabelle, Verdict, Issues-Log
- [scratchpad.md](scratchpad.md) — Arbeitsnotizen (weitgehend leer; lite-Profil)
- [knowledge.md](knowledge.md) — Dauerhafte Erkenntnisse (weitgehend leer; lite-Profil)
