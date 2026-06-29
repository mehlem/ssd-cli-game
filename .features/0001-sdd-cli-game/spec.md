---
id: SPEC-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: spec
schema_version: 2
status: completed
phase: design
created: 2026-06-26
updated: 2026-06-26
source: BRIEF-0001
links: {"derived_from":["BRIEF-0001"],"informed_by":[],"supersedes":[]}
based_on: {"BRIEF-0001":"sha256:7ec73a7c7bf5ff85f0a4b1bf72554af95d2c478902ab8c559b3133913b8849a1"}
related:
  brief: BRIEF-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Spec: Sdd Cli Game

## Problem

Neue SDD-Nutzer starten heute direkt mit echten Features und begehen dabei typische Phasenfehler: Brief zu kurz, Design übersprungen, Implement ohne Tasks. Wer das Plugin zum ersten Mal sieht, hat keinen geführten Einstieg — Dokumentation lesen vermittelt das Denkmuster nicht. Eine sichere, spielerische Lernumgebung fehlt.

## Solution

Ein interaktives CLI-Spiel, das den Spieler durch eine vollständig simulierte SDD-Reise führt. Das Spiel beginnt mit einer Kurzanleitung als fiktive Geschichte (PTA-Berater in einem KI-Projekt, das durch Vibe-Coding zu scheitern droht, rettet das Projekt mit SDD) und führt danach durch alle 7 Phasen als narrative Sequenz. Keine echten `sdd`-Befehle, keine externen Abhängigkeiten — läuft standalone im Terminal.

## User Stories

- US-01: Als neues Teammitglied möchte ich alle 7 SDD-Phasen spielerisch erleben, damit ich ein konkretes mentales Modell habe, bevor ich an echten Features arbeite.
- US-02: Als Trainer oder Onboarder möchte ich ein Standalone-Demo weitergeben können, damit ich für eine SDD-Einführung kein installiertes Plugin brauche.
- US-03: Als Spieler möchte ich eine narrative Einleitung sehen, die erklärt warum SDD wichtig ist, damit ich die Motivation verstehe bevor ich die Mechanik erlebe.
- US-04: Als Spieler möchte ich am Ende eine Zusammenfassung meiner Reise sehen, damit ich die durchlaufenen Phasen reflektieren kann.

## Functional Requirements

- FR-001: Das Spiel zeigt beim Start eine narrative Kurzanleitung: eine fiktive Geschichte mit ASCII-Grafiken über einen PTA-Berater in einem KI-Projekt, das durch Vibe-Coding-Tendenzen zu scheitern droht.
- FR-002: Die Geschichte vermittelt explizit den Kontrast zwischen Vibe-Coding (chaotisch, riskant) und SDD (strukturiert, sicher), bevor das eigentliche Spiel beginnt.
- FR-003: Das Spiel führt den Spieler sequenziell durch alle 7 SDD-Phasen: Brief → Design → Research → Plan → Implement → Review → Close.
- FR-004: Jede Phase erklärt ihren Zweck, ihre Kernfrage und präsentiert eine simulierte Entscheidung oder ein simuliertes Artefakt zum Mitspielen.
- FR-005: Das Spiel führt keine echten `sdd`-Befehle aus, legt keine `.features/`-Verzeichnisse an und verändert keine Projektdateien.
- FR-006: Das Spiel ist in ca. 10–15 Minuten durchspielbar.
- FR-007: Das Spiel läuft ohne externe Abhängigkeiten standalone im Terminal — nur die Standardbibliothek der gewählten Sprache ist erlaubt.
- FR-008: Das Spiel ist auf Windows-Terminal und Unix-kompatiblen Terminals lauffähig (Cross-Platform).
- FR-009: Der Spieler kann die narrative Einleitung beim zweiten Start überspringen.
- FR-010: Das Spiel endet mit einer Abschluss-Zusammenfassung aller durchlaufenen Phasen.

## Acceptance Criteria

- [ ] AC-001: Gegeben ein frisches Terminal, wenn der Spieler das Spiel startet, dann erscheint die narrative Einleitung mit mindestens einer ASCII-Grafik vor jeglichem Phasen-Inhalt.
- [ ] AC-002: Gegeben die Einleitung ist abgeschlossen, wenn der Spieler fortfährt, dann wird Phase 1 (Brief) mit Zweck-Erklärung und simuliertem Prompt angezeigt.
- [ ] AC-003: Gegeben ein Spieler schließt alle 7 Phasen ab, wenn die letzte Phase endet, dann erscheint eine Zusammenfassung die alle 7 Phasen namentlich auflistet.
- [ ] AC-004: Gegeben das Spiel läuft vollständig durch, wenn es endet, dann wurden keine echten `sdd`-Befehle ausgeführt und keine `.features/`-Verzeichnisse erzeugt oder verändert.
- [ ] AC-005: Gegeben ein Windows-Terminal und ein Unix-Terminal, wenn das Spiel auf beiden gestartet wird, dann läuft es fehlerfrei durch und zeigt alle Inhalte korrekt an.
- [ ] AC-006: Gegeben ein Spieler der die Einleitung bereits gesehen hat, wenn er das Spiel erneut startet, dann wird ihm eine Option angeboten die Einleitung zu überspringen.
- [ ] AC-007: Gegeben das Spiel wird gestartet, wenn es läuft, dann ist keine Installation zusätzlicher Pakete erforderlich.

## Non-Goals

- Keine Integration mit dem echten SDD-Plugin oder Ausführung echter `sdd`-Befehle
- Kein persistenter Spielstand (Speichern/Laden)
- Kein Mehrspielermodus
- Kein grafisches UI außer ASCII-Art im Terminal
- Kein Punkte- oder Achievement-System (in dieser Version)
- Keine verzweigenden Storylines — linearer Durchlauf durch die Phasen
- Keine automatisierten Tests für das Spiel selbst (Scope: Demo-Artefakt)

## Constraints

- CLI-only, kein Browser- oder UI-Framework
- Implementierungssprache: Python 3 (Standardbibliothek only, keine externen Pakete)
- Vollständig simulierte Spielwelt — keine echten `sdd`-Befehle
- Cross-Platform: Windows Terminal + Unix-kompatibel

## Open Questions

- [x] OQ-001: Programmiersprache → **Python 3** (Standardbibliothek, kein Build-Schritt, Cross-Platform vorinstalliert)
