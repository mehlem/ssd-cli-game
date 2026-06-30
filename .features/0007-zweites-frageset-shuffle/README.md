# Zweites Frageset Shuffle

## Problem

Das SDD-Lernspiel stellte pro Phase genau eine Frage mit vier Antworten in unveränderlicher Reihenfolge. Wer das Spiel ein zweites Mal spielte, konnte die richtige Antwort positionsbasiert abrufen ("Phase 1 immer Antwort 1") ohne die zugrundeliegenden SDD-Prinzipien verstanden zu haben. Positionslernen ersetzte inhaltliches Verstehen, und der Lernwert des Spiels verfiel nach dem ersten Durchlauf vollständig.

## Solution

Jede der 7 Phasen erhielt ein zweites, inhaltlich abgenommenes alternatives Fragenset (7 neue Fragen, documented und genehmigt in brief.md Q3). Beim Spielstart wird für jede Phase zufällig eine der zwei Fragen ausgewählt. Die Antwortoptionen jeder Frage werden bei jedem Spielstart in zufälliger Reihenfolge angezeigt. Die Auswertungslogik in `ask_question()` blieb unverändert — die Shuffle-Verantwortung liegt vollständig in `run_phase()`.

Der Review ergab: alle 5 Acceptance Criteria PASS. Keine kritischen Issues. Verdict: **pass**.

## Key Decisions

**AD-001: `fragen`-Liste statt `interaktion2`-Feld**
Die zweite Frage wird in einer Liste `fragen` pro Phase-Dict gespeichert, nicht als paralleles Feld `interaktion2`. Eine Liste ist auf N Fragen erweiterbar ohne Strukturänderung. Das parallele Feld-Muster wurde als inkonsistent und nicht erweiterbar abgelehnt. In der endgültigen Implementierung enthält `fragen` jedoch nur das zweite interaktion-Dict (1 Element); `run_phase()` kombiniert `[phase["interaktion"]] + phase["fragen"]`. Die vollständige Migration (`interaktion` → `fragen[0]`) wurde aufgeschoben (siehe Lessons Learned).

**AD-002: Shuffle-Logik in `run_phase()`, `ask_question()` bleibt unverändert**
Die Zufallsauswahl und das Mischen der Optionen wurden in `run_phase()` eingebaut. `ask_question()` empfängt ein bereits fertiges, gemischtes interaktion-Dict. Die Alternative — `ask_question()` für Antworttext-Vergleich statt Positions-Index-Vergleich zu refaktorieren — wurde abgelehnt, weil sie einen größeren Eingriff ohne Scope-Nutzen darstellte.

**AD-003: Positions-Update nach Shuffle via Textsuche**
`richtig` ist in `game.py` ein 1-basierter Positions-String ("1"–"4"), kein Antworttext. Nach dem Mischen der Optionen würde ein unverändertes `richtig` auf die falsche Antwort zeigen. Die gewählte Lösung: den korrekten Antworttext vor dem Shuffle merken (`correct_text = optionen[int(richtig)-1]`), nach dem Shuffle die neue Position suchen (`str(shuffled.index(correct_text) + 1)`). Index-Tracking beim Shuffle wurde als komplexer und fehleranfälliger abgelehnt.

**Datenabnahme der neuen Fragen vor der Implementierung (brief.md Q3)**
Die 7 inhaltlich neuen Fragen wurden bereits in der Brief-Phase vollständig formuliert, tabellarisch dokumentiert und vom Nutzer inhaltlich abgenommen. Das verhinderte nachträgliche Korrekturen an Fragen-Inhalten während der Implementierungsphase.

**Zweistufige Implementierung (T-001 vor T-002)**
T-001 fügte die `fragen`-Daten ein ohne `run_phase()` zu berühren; T-002 stellte die Logik um. Diese Aufteilung hielt das alte `interaktion`-Feld während T-001 als funktionsfähige Fallback-Basis und minimierte Regressionsgefahr.

## Outcome

Review-Verdict: **pass**. Alle 5 Acceptance Criteria wurden durch den Spec-Reviewer mit `file:line`-Belegen verifiziert.

- AC-001 (Varianz zwischen Spielstarts): PASS — `random.choice` + `random.shuffle` in `run_phase()` bei `game.py:793,796`.
- AC-002 (richtige Antwort nach Shuffle korrekt ausgewertet): PASS — `richtig`-Index wird nach jedem Shuffle neu berechnet.
- AC-003 (falsche Antwort korrekt ausgewertet): PASS — `feedback_falsch` in allen `fragen`-Einträgen vorhanden.
- AC-004 (Score 7 bei 7 richtigen Antworten): PASS — Score-Akkumulation unverändert.
- AC-005 (2 Fragensets pro Phase importierbar): PASS — `[p['interaktion']] + p['fragen']` ergibt 2 für alle Phasen.

Ein Trace-Score von 42.86% wurde dokumentiert (3 von 10 Trace-Regeln schlugen fehl). Diese Failures betrafen fehlende formale `addresses`/`validates`-Metadaten-Links in plan.md und review.md, nicht die Implementierungsqualität — sie sind Artefakt-Vollständigkeitslücken, keine funktionalen Mängel.

Caveat: Das alte `interaktion`-Feld verbleibt in allen PHASES-Dicts. Die vollständige Migration zu einer reinen `fragen`-Liste wurde als Future-Cleanup aufgeschoben (dokumentiert in scratchpad.md).

## Lessons Learned

**Die Positions-String-Invariante in `ask_question()` ist der kritischste Fallstrick.** `richtig` ist kein Antworttext sondern ein 1-basierter Positions-String. Ein Shuffle der `optionen` ohne gleichzeitiges Update von `richtig` führt zu systematisch falschen Auswertungen ohne Fehlermeldung — das Spiel lauft weiter, wertet aber falsch aus. Die Lösung (Textsuche nach Shuffle) funktioniert, solange alle Antworttexte innerhalb einer Frage eindeutig sind, was für alle 14 Fragen in 0007 zutrifft.

**AD-001 wurde nur teilweise umgesetzt.** Plan.md sah vor, `interaktion` vollständig durch `fragen[0]` zu ersetzen. Die Implementierung ließ `interaktion` in allen PHASES-Dicts bestehen und nutzt `[phase["interaktion"]] + phase["fragen"]` in `run_phase()`. Das Verhalten ist korrekt, aber die Datenstruktur ist inkonsistenter als geplant. Ein Folge-Feature kann diesen Cleanup ohne Verhaltensänderung nachholen.

**Verifikation T-002 schlug initial fehl** (dokumentiert in scratchpad.md Open Questions). Das Verification-Script für T-002 wurde mit `exit 1` abgebrochen, bevor die endgültige Implementierung stabil war. Die spätere Review-Verifikation bestätigte dann PASS — das initiale Failure spiegelt einen Zwischenstand während der Implementierung wider.

## Further Reading

- [DOCS.md](./DOCS.md) — Technische Referenz: Komponentenstruktur, Interface-Details, Verifikationsbefehle, bekannte Limitations
- [brief.md](./brief.md) — Problemstellung, Q&A-Protokoll mit abgenommenen Fragen (Q3-Tabelle)
- [spec.md](./spec.md) — Funktionale Requirements, Acceptance Criteria, Non-Goals
- [research.md](./research.md) — Code-Analyse von `game.py`, kritische Positions-String-Befund, Affected Files
- [plan.md](./plan.md) — Architekturentscheidungen AD-001 bis AD-003, Implementierungsphasen
- [tasks.md](./tasks.md) — T-001 und T-002 mit Verifikationsbefehlen
- [review.md](./review.md) — AC-Verifikation mit `file:line`-Belegen, Adjudication-Protokoll
- [scratchpad.md](./scratchpad.md) — Laufende Notizen, Future-Cleanup-Hinweis, T-002-Verification-Failure
