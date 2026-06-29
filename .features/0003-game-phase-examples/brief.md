---
id: BRIEF-0003
feature: "0003-game-phase-examples"
title: "Game Phase Examples"
type: brief
schema_version: 2
status: completed
phase: brief
created: 2026-06-26
updated: 2026-06-26
related:
  spec: SPEC-0003
  research: RESEARCH-0003
  plan: PLAN-0003
  tasks: TASKS-0003
  review: REVIEW-0003
  scratchpad: SCRATCH-0003
  continuity: CONT-0003
  knowledge: KB-0003
tags: []
---

# Brief: Game Phase Examples

<!-- =====================================================================
LEAN BRIEF INSTRUCTIONS (read before filling)

Posture: intent-extraction, not interview.
1. Gather context FIRST — read CLAUDE.md, .features/INDEX.md, recent feature briefs,
   and 1–2 scoped repo files relevant to this feature. Don't ask before inspecting.
2. Propose ideas or draft inferable sections (Problem, Context, Constraints) from
   inference. Label inferred content with source: <!-- inferred from CLAUDE.md -->
3. Ask only intent-level questions (Motivation, Vision). Soft cap ~3 questions total.
4. Forbidden question types:
   - Research/plan-phase questions (what files to touch, what data flows look like)
   - Code-logic questions (how to implement)
   - Anything answerable by inspecting CLAUDE.md / INDEX.md / scoped repo files
5. Every question MUST come paired with a **Recommended**: line carrying a proposed
   answer or idea — the user should be able to confirm/redirect quickly.
6. All 5 sections below are required, but Problem / Context / Constraints are usually
   fillable by interpretation. Don't ask one question per section.
===================================================================== -->

## Short Description

Nach jeder Phasen-Frage ein konkretes Beispiel zeigen: was tut der Entwickler, was tut Claude Code via Plugin, welches Artefakt entsteht

## Long Description

Das Spiel erklärt SDD-Phasen durch Fragen und Feedback. Danach fehlt noch der Schritt zur Praxis: Was sieht der Spieler wenn er das echte Plugin benutzt? Dieses Feature fügt nach dem Feedback jeder Phase ein kompaktes Beispiel-Panel ein — drei Zeilen, die zeigen wie eine Phase in der Realität aussieht.

## Motivation

Abstrakte Feedback-Sätze ("In SDD gilt: ...") vermitteln das Prinzip, aber nicht das Handwerk. Ein Spieler der das Spiel durchgespielt hat sollte wissen: "Ich öffne das Terminal, tippe diesen Befehl, Claude Code legt diese Datei an." Ohne konkretes Beispiel bleibt die Lücke zwischen Spielerlebnis und erster echter SDD-Nutzung.

## Problem

Nach jeder Phasen-Antwort sieht der Spieler aktuell nur das Feedback-Panel und dann die Navigation (Weiter/Zurück). Es fehlt die Brücke zur Realität: Was würde ich jetzt konkret TUN? Was tippt Claude Code? Was liegt danach auf der Festplatte? <!-- inferred aus Spielstruktur game.py + Nutzerwunsch aus Konversation -->

## Vision

Nach dem Feedback jeder Phase erscheint ein kleines dreizeiliges Beispiel-Panel:
- **👤 Entwickler:** konkreter Befehl oder Aktion (z.B. `sdd init login-feature`)
- **🤖 Claude Code / Plugin:** was das Plugin automatisch tut (z.B. "erstellt brief.md, aktiviert Phase-Gates")
- **📄 Artefakt:** welche Datei / welches Dokument entsteht (z.B. `.features/0042-login-feature/brief.md`)

Der Spieler verlässt das Spiel mit dem Gefühl: "Das kann ich jetzt selbst machen."

## Context

- **Stakeholders**: SDD-Einsteiger nach dem Spielen; sie wollen direkt loslegen <!-- inferred aus 0001/0002 brief.md -->
- **Urgency**: Ergänzt 0002 sinnvoll — Lern-Loop nach 0002 fast komplett, 0003 schließt sie <!-- inferred aus Feature-Verlauf -->
- **Prior attempts**: Keine — erstmals in 0003
- **Related work**: Baut auf `run_phase()` und `PHASES`-Datenstruktur aus 0001/0002 auf; `PHASES`-Dicts erhalten ein neues Feld `beispiel`

## Constraints

- Erweitert `game.py` — kein Neuschreiben
- Python 3 stdlib only, keine neuen Abhängigkeiten
- Beispiel-Panel muss kompakt sein (passt nach dem Feedback auf den Bildschirm)
- 7 Phasen × 3 Felder = 21 Beispieltexte — inhaltlich korrekt, kurz und terminal-gerecht
- Linearer Spielablauf — kein Zurück-Mechanismus (z-Taste aus 0002 wird entfernt); mit Beispiel-Panel vor der Frage wäre "Zurück" mehrdeutig und technisch verwirrend

## Q&A Record

### Q1: Soll das Beispiel-Panel automatisch nach dem Feedback erscheinen oder erst nach einer extra Bestätigung?

**Recommended**: Automatisch als Teil des Feedback-Blocks — kein Extra-Enter, fließt direkt an das Feedback an.
**Answer**: Automatisch erscheinen (aus Nutzerwunsch "direkt im Anschluss")

### Q2: In welcher Reihenfolge sollen Beispiel-Panel und Fragen-Panel innerhalb einer Phase erscheinen?

**Recommended**: Beispiel-Panel zuerst — der Spieler sieht die Praxis, bevor er die Frage beantwortet.
**Answer**: Bestätigt. Reihenfolge pro Phase: Beispiel-Panel → Fragen-Panel → Navigation (Weiter/Zurück).

### Q3: Welche konkreten Beispielinhalte soll das Beispiel-Panel für jede Phase zeigen?

**Recommended**: Vier Felder pro Phase (🧑 Product Owner / 👤 Entwickler / 🤖 Claude Code / 📄 Artefakt); PO-Feld in allen 7 Phasen sichtbar — aktiv wo PO beteiligt ist, sonst explizit "keine Aufgabe".

**Answer**: Bestätigt (gemeinsam durchgearbeitet und abgenommen).

| Phase | 🧑 Product Owner | 👤 Entwickler | 🤖 Claude Code | 📄 Artefakt |
|---|---|---|---|---|
| 1 Brief | "Nutzer brechen beim Signup ab, weil das Formular zu lang ist. Ziel: Registrierung vereinfachen, damit mehr Besucher zu Kunden werden und der Support weniger Rückfragen bekommt." | Leitet daraus Feature-Name und Ziel ab → `sdd init login-feature "Reduce signup friction"` | Erstellt `brief.md`, stellt WHY-Fragen (Motivation, Problem, Vision), aktiviert Brief-Phase-Gates | `.features/0001-login-feature/brief.md` mit Motivation, Problem & Vision |
| 2 Design | "Das Formular soll maximal 3 Pflichtfelder haben. Nach der Eingabe muss ein neuer Nutzer sich sofort einloggen können — ohne E-Mail-Bestätigung im ersten Schritt." | Übersetzt PO-Wunsch in messbare Anforderungen → `sdd spec 0001-login-feature`, schreibt User Stories & Akzeptanzkriterien in `spec.md` | Schlägt funktionale Anforderungen (FR-001 …) und Akzeptanzkriterien (AC-001 …) vor, warnt bei widersprüchlichen oder unvollständigen Anforderungen | `.features/0001-login-feature/spec.md` mit User Stories, FRs und prüfbaren ACs |
| 3 Research | Keine Aufgabe in dieser Phase — die fachlichen Vorgaben aus Brief und Design sind abgeschlossen. Research ist reine Entwicklerarbeit. | `sdd research 0001-login-feature` — gibt den Startschuss, liest danach `research.md` und prüft ob alle betroffenen Dateien gefunden wurden | Durchsucht die Codebase, kartiert betroffene Dateien (`auth.py`, `forms.py` …), identifiziert Abhängigkeiten und Risiken, füllt `research.md` | `.features/0001-login-feature/research.md` mit Dateiliste, Abhängigkeiten und Risiken |
| 4 Plan | Keine Aufgabe in dieser Phase — Architektur und Aufgabenzerlegung sind reine Entwicklerarbeit. | `sdd plan create 0001-login-feature` — trifft Architekturentscheidungen, genehmigt die Task-Liste bevor die Umsetzung startet | Leitet aus `research.md` konkrete Architekturentscheidungen (AD-001 …) ab, zerlegt die Umsetzung in atomare, unabhängig prüfbare Tasks (T-001 …) | `.features/0001-login-feature/plan.md` + `tasks.md` mit abhängigkeitsgeordneten Tasks |
| 5 Implement | Keine Aufgabe in dieser Phase — der Plan ist freigegeben, die Umsetzung läuft. | `sdd task start 0001-login-feature T-001` — startet genau einen Task, prüft das Ergebnis, markiert ihn als erledigt, dann weiter mit T-002 | Implementiert Task für Task, führt nach jedem Task den Verifikationsbefehl aus und markiert erst dann `done` — kein Task gilt als fertig ohne bestandene Prüfung | Geänderte Produktionsdateien (`auth.py`, `forms.py` …) + aktualisierter Task-Status in `tasks.md` |
| 6 Review | Prüft fachlich: "Ist das, was gebaut wurde, das was ich in Brief und Design gemeint habe?" — bestätigt oder meldet Abweichungen vom ursprünglichen Ziel | `sdd review 0001-login-feature` — liest `spec.md` zuerst, prüft dann den Code gegen jeden AC, dokumentiert Befunde in `review.md` | Validiert jeden AC mit Belegen aus dem Code, setzt `verdict: pass` oder `fail` mit Begründung — kein Verdict ohne gelesene Spec | `.features/0001-login-feature/review.md` mit AC-Nachweisen und finalem Verdict |
| 7 Close | Keine Aufgabe in dieser Phase — das Feature ist live, das Ziel ist erreicht. | `sdd close 0001-login-feature` — bestätigt den Abschluss, prüft ob alle Erkenntnisse dokumentiert sind | Promoviert wertvolle Erkenntnisse aus dem Scratchpad in `KNOWLEDGE.md`, finalisiert alle Artefakte, schließt das Feature ab | `.features/0001-login-feature/knowledge.md` + abgeschlossene Feature-Artefakte |
