# SDD CLI Game — Interaktives Terminal-Lernspiel für SDD-Einsteiger

## Problem

SDD-Einsteiger starteten direkt mit echten Features und begingen dabei typische Phasenfehler: Brief zu kurz, Design übersprungen, Implement ohne Tasks. Das Plugin bot keinen geführten Einstieg — Dokumentation lesen vermittelt das Denkmuster nicht. Eine sichere Lernumgebung fehlte vollständig.

## Solution

Ein interaktives CLI-Spiel in Python 3, das den Spieler durch eine vollständig simulierte SDD-Reise führt. Das Spiel beginnt mit einer fiktiven Einleitung — ein PTA-Berater rettet ein durch Vibe-Coding gefährdetes KI-Projekt mit Hilfe von SDD — und führt danach sequenziell durch alle 7 Phasen (Brief → Design → Research → Plan → Implement → Review → Close). Jede Phase erklärt ihren Zweck, ihre Kernfrage und präsentiert einen simulierten Prompt. Das Spiel läuft standalone, ohne installiertes SDD-Plugin, ohne externe Pakete, und endet mit einer Zusammenfassung aller durchlaufenen Phasen. Der Review stellte sicher, dass alle 7 Acceptance Criteria den Status PASS erreichten.

## Key Decisions

**Einzelne Datei `game.py` statt Package-Struktur (AD-001)**
Ein Trainer kann das Spiel per E-Mail weitergeben. Ein `sdd_game/`-Package mit separaten Modulen pro Phase wurde abgelehnt — bei einem linearen Demo-Spiel ohne interne Wiederverwendung wäre das overhead ohne Nutzen gewesen.

**ANSI-Escape-Codes als benannte Konstanten, kein externes Paket (AD-002)**
Farben und Formatierung wurden als Modul-Konstanten (`GRÜN`, `ROT`, `GELB`, `FETT`, `RESET`) am Dateianfang definiert. `colorama` (das naheliegendste externe Paket) war verboten laut Spec. Rohe `\033[...]`-Strings direkt im Code wären unleserlich und schwer zu deaktivieren gewesen. Mit benannten Konstanten lassen sich alle Farben mit einem einzigen Leerzeichen-Austausch abschalten.

**`input()` als einziges Interaktionsmodell (AD-003)**
Plattformspezifisches Keyboard-Handling (`msvcrt.getch()` auf Windows, `tty`+`termios` auf Unix) wurde vollständig abgelehnt. `input()` ist 100% cross-platform und reicht für ein narratives Spiel, das nur Enter-Bestätigungen benötigt.

**Phase-Daten als Liste von Dicts (`PHASES`-Konstante) (AD-004)**
Statt Dataclasses oder separater Klassen wurden die 7 Phasen als einfache `PHASES`-Liste mit Dicts definiert. Dataclasses hätten mehr Typsicherheit geboten, wären aber für 7 statische Einträge überdimensioniert gewesen. Die Dict-Struktur macht die Phasendaten direkt verifizierbar (`len(game.PHASES) == 7`).

**Skip-Intro via `.sdd_game_seen`-Marker-Datei (AD-005)**
Ein `--skip-intro`-Kommandozeilenargument wurde abgelehnt, da der Nutzer sich den Flag merken müsste. Die Marker-Datei wird automatisch nach dem ersten vollständigen Intro angelegt und ist relativ zu `__file__` verankert, nicht zum CWD — was zuverlässiges Verhalten bei verschiedenen Aufrufpfaden sichert.

## Outcome

Der Review durchlief zwei Runden. Im ersten Durchlauf identifizierte der Quality-Reviewer zwei kritische Findings: F-001 (ANSI-Bytes verfälschten die Padding-Berechnung in `print_box()`, was den Box-Rahmen visuell verschob) und F-002 (fehlender UTF-8-Guard führte zu `UnicodeEncodeError` auf cp1252-Terminals — auf der Entwicklungsmaschine bestätigt). Nach chirurgischen Fixes — `_visible_len()` mit ANSI-Stripping und `sys.stdout.reconfigure(encoding='utf-8', errors='replace')` in `main()` — bestand der Re-Review mit Verdict PASS. Alle 7 Acceptance Criteria wurden erfüllt.

Drei Minor-Issues wurden dokumentiert: eine tote Variable (`clean`), ein ungenutzter `import sys` (durch F-002-Fix anschließend genutzt) und `.sdd_game_seen` fehlte in `.gitignore`.

## Lessons Learned

`curses` ist unter Windows Python 3.14.3 nicht verfügbar (`ModuleNotFoundError: No module named '_curses'`). Cross-Platform Terminal-Spiele in Python müssen ANSI-Escape-Codes oder externe Bibliotheken wie `blessed` oder `rich` verwenden. Das war ein bestätigter Befund aus der Research-Phase und kein Laufzeit-Überraschung.

ANSI-Escape-Codes verfälschen `len()`: `len("\033[32mText\033[0m")` gibt die Byte-Länge inklusive Steuerzeichen zurück, nicht die sichtbare Zeichenbreite. Für Padding-Berechnungen muss `re.sub(r'\x1b\[[0-9;]*m', '', s)` vor `len()` angewendet werden. Dieser Bug wurde erst im Review entdeckt, nicht während der Implementierung.

Windows-Systeme mit cp1252-Standardcodierung (CMD, ältere Terminal-Emulatoren) werfen beim `print()` von Unicode-Box-Zeichen wie `─` oder `│` einen `UnicodeEncodeError`. Der Fix `sys.stdout.reconfigure(encoding='utf-8', errors='replace')` als erste Zeile in `main()` verhindert den Crash auf allen Terminals.

Der SDD-Scope-Tracker feuert eine Warnung wenn eine Datei zwar in `tasks.md` gelistet ist, aber noch nicht in `task-scope.txt` steht. Das ist informativ — der Edit geht durch. Fix: `sdd task scope-refresh <feature> <T-xxx>`.

## Further Reading

- [DOCS.md](DOCS.md) — Technische Referenz: Komponentenübersicht, Dateitabelle, Verifikationsbefehle, bekannte Einschränkungen
- [brief.md](brief.md) — Problemstellung, Motivation, Vision und Q&A-Record
- [spec.md](spec.md) — Funktionale Anforderungen, Acceptance Criteria, Non-Goals, Constraints
- [research.md](research.md) — Laufzeitumgebung, bestätigte Fakten, Risiken, Confidence-Score
- [plan.md](plan.md) — Architekturentscheidungen (AD-001 bis AD-005), Implementierungsphasen
- [tasks.md](tasks.md) — Die 7 Tasks mit Done-When-Kriterien und Verifikationsbefehlen
- [review.md](review.md) — AC-Validierungstabelle, gefundene Issues, Verified-Clean-Bereiche, Verdict
- [scratchpad.md](scratchpad.md) — Beobachtungen, Annahmen und Erkenntnisse während der Implementierung
- [knowledge.md](knowledge.md) — Dauerhaft wiederverwendbare Erkenntnisse (K-001 bis K-004)
