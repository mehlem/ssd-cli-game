# Frage Headline — Kontextüberschrift in der Fragen-Box

## Problem

Die Fragen-Box in jeder Phase des SDD-Lernspiels zeigte dem Spieler sofort den Fragetext, ohne einleitenden Kontext. Es fehlte jede visuelle oder inhaltliche Markierung, dass es sich um eine Verständnisfrage handelt. Spieler konnten nicht auf den ersten Blick einordnen, was von ihnen erwartet wird.

## Solution

Die Funktion `ask_question()` in `game.py` wurde so angepasst, dass die Fragen-Box als erste Zeile die Überschrift "Hier eine Verständnisfrage zur Arbeit mit SDD" ausgibt, gefolgt von einer Leerzeile und dem eigentlichen Fragetext. Alle anderen Elemente der Box (Antwortoptionen, Feedback) blieben unverändert.

Der einzige Eingriffspunkt war der `print_box()`-Aufruf in `ask_question()`: Der bisherige Aufruf mit `[q["frage"]]` wurde zu `["Hier eine Verständnisfrage zur Arbeit mit SDD", "", q["frage"]]` erweitert.

## Key Decisions

**Einziger Änderungspunkt: `ask_question()` in `game.py`**
Alternativ hätte man die Headline in den Datendateien der Phasen hinterlegen oder als separaten `print()`-Aufruf vor `print_box()` ausgeben können. Der direkte Einbau in den `print_box()`-Aufruf wurde gewählt, weil er die visuelle Einheit der Box erhält und keine Datenstruktur-Änderungen erfordert.

**Keine neuen Abhängigkeiten**
Eine externe Konstante oder Konfigurationsvariable für den Headline-Text wurde abgelehnt, da der Text nicht mehrsprachig oder konfigurierbar sein muss. Der Literal-String direkt im Aufruf ist die kleinste viable Lösung.

**Leerzeile als Trenner**
Statt einem fixen Abstand über Layout-Parameter wurde eine leere Zeichenkette `""` als zweites Listenelement in `print_box()` verwendet, konsistent mit dem bestehenden Muster der Funktion.

## Outcome

Review-Verdict: **PASS**

AC-001 wurde vollständig erfüllt. Die Verifikation (`T-001.json`, exit_code 0, stdout "OK") bestätigte, dass die Headline in der Ausgabe von `ask_question()` enthalten ist. Der Nachweis im Review zeigt `game.py:302` mit dem geänderten `print_box()`-Aufruf. Keine kritischen oder minoren Issues wurden gefunden. Hardcoded Secrets wurden geprüft und sind nicht vorhanden.

## Lessons Learned

Das Scratchpad und die Knowledge-Base dieses Features enthalten keine eingetragenen Beobachtungen — die Änderung war trivial genug, dass keine Überraschungen oder Kurskorekturen aufgetreten sind. Das lite-Profil (ohne brief/research/plan) erwies sich als angemessen: Ein einzelner Funktionsaufruf mit einem geänderten Listenargument rechtfertigt keinen vollständigen Artifact-Chain-Durchlauf.

## Further Reading

- [DOCS.md](./DOCS.md) — Technische Referenz: betroffene Datei, Interface-Änderung, Verifikationsbefehl
- [spec.md](./spec.md) — Problem, Solution, Acceptance Criteria, Non-Goals, Constraints
- [tasks.md](./tasks.md) — Aufgabenbeschreibung T-001 mit Steps und Verifikationsbefehl
- [review.md](./review.md) — AC-Validierungstabelle, Scope Conformance, Issues
- [scratchpad.md](./scratchpad.md) — Arbeitsnotizen (keine Einträge für dieses Feature)
- [knowledge.md](./knowledge.md) — Dauerhafte Erkenntnisse (keine Einträge für dieses Feature)
