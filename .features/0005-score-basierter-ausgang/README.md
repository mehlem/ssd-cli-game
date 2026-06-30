# Score-basierter Ausgang

## Problem

`show_summary()` in `game.py` zeigte unabhaengig vom erzielten Score immer denselben Erfolgstext ("Du hast das SmartFlow-Projekt gerettet."). Bei einem niedrigen Score war diese Aussage inhaltlich falsch und gab dem Spieler keinen Anreiz, das Spiel erneut zu versuchen.

## Solution

Die Funktion `show_summary()` wurde um eine score-abhaengige Verzweigung erweitert. Bei mehr als 6 richtigen Antworten erscheint weiterhin der bisherige Erfolgstext. Bei 6 oder weniger richtigen Antworten erscheint ein ermutigender Text, der das SmartFlow-Projekt explizit nennt und zur Wiederholung einlaedt. Score-Anzeige und Phasenliste bleiben in beiden Ausgabepfaden unveraendert erhalten.

## Key Decisions

**Schwellwert score > 6 statt score == 7**
Der Schwellwert wurde als `score > 6` formuliert (entspricht bei 7 Fragen faktisch score=7). Eine Pruefung auf `score == 7` haette dieselbe Wirkung erzielt, ist aber weniger robustgegenueber einer kuenftigen Aenderung der Gesamtfragenzahl. Dennoch legt die Spec fest, dass der Schwellwert nicht geaendert werden soll; eine dynamische Berechnung (z.B. `score == total`) wurde explizit als Non-Goal ausgeklammert.

**Nur zwei Kategorien**
Eine dritte Score-Kategorie (z.B. "mittlerer" Erfolg) wurde als Non-Goal abgelehnt, um die Aenderung minimal zu halten und den Entscheidungsbaum einfach zu lassen.

**Aenderung ausschliesslich in show_summary()**
Alle anderen Funktionen, die Sterne-Anzeige und die Phasenliste wurden nicht angefasst. Eine breitere Umstrukturierung der Ausgabe-Logik wurde bewusst verworfen.

**Ermutigungstext mit SmartFlow-Referenz**
Der alternative Text muss das Wort "SmartFlow" enthalten (AC-002, AC-003), damit die thematische Kohaerenz des Spiels gewahrt bleibt. Ein generischer Text ohne Spielbezug wurde abgelehnt.

## Outcome

Review-Verdict: **PASS**

Alle vier Acceptance Criteria wurden durch automatisierte Verifikation bestanden:

| AC | Ergebnis |
|:---|:---------|
| AC-001: score=7 zeigt Erfolgstext | PASS |
| AC-002: score=6 zeigt Ermutigungstext mit "SmartFlow", kein "gerettet" | PASS |
| AC-003: score=0 zeigt Ermutigungstext mit "SmartFlow" | PASS |
| AC-004: Beide Pfade enthalten "von 7" | PASS |

Keine kritischen oder minor Issues wurden im Review erfasst.

## Lessons Learned

Die scratchpad.md und knowledge.md dieses Features wurden als Stubs ohne inhaltliche Eintragungen geschlossen. Die gesamte relevante Entscheidungsgrundlage ist in spec.md und tasks.md dokumentiert. Fuer kuenftige lite-Profile empfiehlt es sich, Beobachtungen waehrend der Implementierung aktiv in den Scratchpad einzutragen, auch wenn der Umfang klein ist.

## Further Reading

- [DOCS.md](DOCS.md) — Technische Referenz: Komponenten, Verifikationskommando, bekannte Grenzen
- [spec.md](spec.md) — Problem, Solution, Functional Requirements, Acceptance Criteria, Non-Goals
- [tasks.md](tasks.md) — Implementierungsansatz, Schritte, Verifikationsskript fuer T-001
- [review.md](review.md) — AC-Validierungstabelle, Scope-Conformance, Review-Verdict
- [scratchpad.md](scratchpad.md) — Laufendes Arbeitsprotokoll (hier: Stub ohne Eintraege)
- [knowledge.md](knowledge.md) — Wiederverwendbare Erkenntnisse (hier: Stub ohne Eintraege)
