---
id: TASKS-0006
feature: "0006-projekt-rename"
title: "Projekt Rename"
type: tasks
schema_version: 2
profile: lite
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0006
  review: REVIEW-0006
tags: []
---

# Tasks: Projekt Rename

## Approach

- Alle 6 Vorkommen von SmartFlow/smart-flow in game.py durch PromptAndPray/promptandpray ersetzen (replace_all).

## T-001: SmartFlow durch PromptAndPray ersetzen

> Status: completed
> Phase: PH-01
> Implements: ["FR-001"]
> Files: ["game.py (modify)"]

### Description

6 Textstellen in `game.py` ersetzen: "SmartFlow-Projekt" → "PromptAndPray-Projekt", "SmartFlow-Login" → "PromptAndPray-Login", "smart-flow-login" → "promptandpray-login".

### Done When

- Kein "SmartFlow" oder "smart-flow" mehr in game.py.
- Mindestens 6 "PromptAndPray"-Treffer in game.py.

### Non-Goals

- Zeile 219 ("PromptAndPray good vibes 2.0") bleibt unverändert.

### Scope Boundary

- In scope: die 6 SmartFlow-Textstellen in game.py.
- Out of scope: alles andere.

### Acceptance Criteria

- [x] AC-001: `grep -i "smartflow\|smart-flow" game.py` → 0 Treffer.
- [x] AC-002: `grep -i "promptandpray" game.py` → mind. 6 Treffer.

### Verification

```bash
cd "C:\Users\mehlem\OneDrive - PTA-Gruppe\Lerning\KI\Claude-Code\SDD\SSD-Beispielprojekt" && python -c "
import re
txt = open('game.py', encoding='utf-8').read()
hits_old = len(re.findall(r'(?i)smartflow|smart-flow', txt))
hits_new = len(re.findall(r'(?i)promptandpray', txt))
assert hits_old == 0, f'FAIL: noch {hits_old} SmartFlow-Treffer'
assert hits_new >= 6, f'FAIL: nur {hits_new} PromptAndPray-Treffer'
print(f'OK - 0 SmartFlow, {hits_new} PromptAndPray')
"
```
