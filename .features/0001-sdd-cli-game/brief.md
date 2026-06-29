---
id: BRIEF-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: brief
schema_version: 2
status: completed
phase: brief
created: 2026-06-26
updated: 2026-06-26
related:
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Brief: Sdd Cli Game

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

Grafisches CLI-Spiel das die SDD-Phasen spielerisch demonstriert

## Long Description

Ein interaktives Terminal-Spiel, das neue SDD-Nutzer durch eine fiktive Feature-Reise führt. Der Spieler erlebt alle 7 SDD-Phasen (Brief → Design → Research → Plan → Implement → Review → Close) als narrative Abenteuer-Sequenz — ohne echtes Plugin, ohne Risiko, ohne Vorwissen.

Das Spiel beginnt mit einer Kurzanleitung in Form einer fiktiven Geschichte: Ein PTA-Berater steckt in einem KI-gestützten Kundenprojekt, das durch Vibe-Coding-Tendenzen zu scheitern droht. Die Geschichte dient als emotionaler Einstieg und erklärt spielerisch, warum strukturiertes Vorgehen (SDD) dem chaotischen "einfach drauf loscoden mit KI" überlegen ist. ASCII-Grafiken begleiten die Erzählung. Die konkrete Story, die Grafiken und die Spielstruktur werden in der Design-Phase ausgearbeitet.

## Motivation

Neue Teammitglieder, die SDD adoptieren sollen, verstehen den Workflow am schnellsten durch aktives Erleben. Das Spiel macht Onboarding greifbar: Statt Dokumentation zu lesen, spielt man sich durch eine vollständige Feature-Reise und verinnerlicht dabei die Phasenlogik, die Gates und das Denkmuster hinter SDD.

## Problem

SDD-Einsteiger starten heute direkt mit echten Features und machen dabei typische Phasenfehler (Design überspringen, Brief zu kurz, Implement ohne Tasks). Eine niedrigschwellige, sichere Lernumgebung fehlt — wer das Plugin zum ersten Mal sieht, hat keinen geführten Einstieg.

<!-- inferred from Feature-Beschreibung + INDEX.md (kein bestehendes Onboarding-Feature) -->

## Vision

Ein neues Teammitglied startet das Spiel, spielt eine vollständige SDD-Runde in 10–15 Minuten durch und verlässt es mit einem konkreten mentalen Modell aller 7 Phasen. Das Spiel läuft ohne installiertes Plugin, standalone im Terminal, und kann als Demo-Artefakt weitergegeben werden.

## Context

- **Stakeholders**: SDD-Einsteiger, Teams die SDD adoptieren; sekundär: Plugin-Autor als Showcase-Werkzeug <!-- inferred from Feature-Beschreibung -->
- **Urgency**: Plugin frisch installiert, Demo-Erfahrung fehlt; Onboarding-Lücke ist sofort spürbar <!-- inferred from INDEX.md — keine Features, Neuinstallation -->
- **Prior attempts**: Keine — erstes Feature in diesem Projekt <!-- inferred from INDEX.md -->
- **Related work**: SDD-Plugin selbst (die 7 Phasen sind der Lerngegenstand); CLAUDE.md-Phasenbeschreibung als Referenz

## Constraints

- Rein CLI-basiert, kein Browser- oder UI-Framework <!-- inferred from Feature-Beschreibung "grafisches CLI" -->
- Standalone: läuft ohne installiertes SDD-Plugin und ohne externe Abhängigkeiten
- Vollständig simulierte Spielwelt — keine echten `sdd`-Befehle werden ausgeführt
- Zielplattform: Windows-Terminal + Unix-kompatibel (Cross-Platform)

## Q&A Record

### Q1: Was ist der primäre Einsatzkontext — Onboarding neuer Teammitglieder oder eigene Lernexploration?

**Recommended**: Onboarding — das Spiel wird von jemandem gespielt, der SDD noch nicht kennt, und führt ihn Schritt für Schritt durch eine fiktive Feature-Reise.
**Answer**: Onboarding

### Q2: Soll das Spiel die echten `sdd`-Befehle ausführen (Live-Demo mit realem Plugin) oder eine vollständig simulierte Spielwelt sein?

**Recommended**: Simulierte Spielwelt — so kann man es gefahrlos und ohne installiertes Plugin spielen, und es läuft auch als Standalone-Demo.
**Answer**: Simulierte Spielwelt
