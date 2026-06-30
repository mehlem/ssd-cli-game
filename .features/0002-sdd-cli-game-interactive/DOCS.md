# Technical Reference: SDD CLI Game — Interactive Learning Mode

## Architecture Overview

The feature extends `game.py` from Feature 0001 by adding a single new function (`ask_question`) and one new data field per phase (`interaktion`). The design pattern is data-driven dispatch: all question content lives in the PHASES data structure; the runtime function reads a `typ` field and routes to the appropriate interaction mechanic. No new modules, no new files.

Control flow:

```
main()
  for phase in PHASES:
    score += run_phase(phase)       # run_phase now returns int (was None)
      ask_question(phase['interaktion'])
        retry loop until valid input
        display feedback with SDD principle
        return 0 or 1
  show_summary(score, 7)            # show_summary now accepts (score, total)
```

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | modified | Sole implementation file. Added `ask_question()`, extended all 7 PHASES dicts with `interaktion` field, changed `run_phase()` return type, added `score`/`total` parameters to `show_summary()`, added score accumulation to `main()`. |

No new files were created. All helper functions from 0001 (`clear_screen`, `pause`, `print_box`, `print_centered`, `_visible_len`, `show_intro`) remain untouched.

## Interface Changes

### `ask_question(q: dict) -> int` (new function)

Accepts an interaction dict from `PHASES[n]['interaktion']`. Displays the question, runs a retry loop on `input()` until a valid choice is entered, displays feedback, and returns `1` (correct) or `0` (incorrect).

### `run_phase(phase: dict) -> int` (signature changed)

Previously returned `None`. Now returns the result of `ask_question(phase['interaktion'])` — either `0` or `1`. Called only from `main()`.

### `show_summary(score: int, total: int) -> None` (signature changed)

Previously accepted no parameters. Now requires `score` (int) and `total` (int). Displays `"Dein Score: {score} von {total} Fragen richtig"` (verified at `show_summary:482`).

### PHASES dict schema (extended)

Each of the 7 dicts in `PHASES` gained a fifth key:

```python
'interaktion': {
    'typ':              str,   # "mc" | "passfail" | "order"
    'frage':            str,   # question text shown to player
    'optionen':         list,  # list of answer strings
    'richtig':          str,   # value of correct option (e.g. "1")
    'feedback_richtig': str,   # shown on correct answer; starts with "In SDD gilt:"
    'feedback_falsch':  str,   # shown on wrong answer; starts with "In SDD gilt:"
}
```

`richtig` is a string that matches one of the option identifiers (e.g., `"1"`, `"2"`) to allow direct comparison with `input().strip()` output.

### Interaction content per phase

| Phase | Index | FR | Question focus |
|:------|:------|:---|:---------------|
| Brief | `PHASES[0]` | FR-001 | Which sections belong in brief.md? (MC) |
| Design | `PHASES[1]` | FR-002 | Why does SDD use Markdown instead of JSON/XML/YAML? (MC) |
| Research | `PHASES[2]` | FR-004 | Which of 3 statements is a confirmed fact with file reference? (MC) |
| Plan | `PHASES[3]` | FR-005 | Order 3 tasks by dependency sequence (MC) |
| Implement | `PHASES[4]` | FR-006 | Verification command fails — what do you do? (MC) |
| Review | `PHASES[5]` | FR-007 | Given AC + code description — PASS or FAIL? (PASS/FAIL) |
| Close | `PHASES[6]` | FR-008 | Which of 3 items belongs in knowledge.md? (MC) |

Note: FR-003 (AC judgment question) is addressed in the Review phase (`PHASES[5]`), not the Design phase. The spec permitted either placement; no acceptance criterion enforced the phase assignment. This was adjudicated as informal in review.

## Testing & Verification

No test framework. Verification uses `py -c` invocations that import `game` and assert structural properties.

### Full schema check (all 7 phases)

```bash
py -c "import game, inspect; assert callable(game.ask_question); assert all('interaktion' in p for p in game.PHASES); assert all(all(k in p['interaktion'] for k in ['typ','frage','optionen','richtig','feedback_richtig','feedback_falsch']) for p in game.PHASES); src = inspect.getsource(game.run_phase); assert 'ask_question' in src; assert 'score' in inspect.getsource(game.show_summary); print('T-001 OK')"
```

### Brief-phase content check

```bash
py -c "import game; q = game.PHASES[0]['interaktion']; assert 'brief.md' in q['frage']; assert 'In SDD' in q['feedback_richtig'] or 'Das SDD-Plugin' in q['feedback_richtig']; print('T-002 OK')"
```

### Design-phase Markdown question check

```bash
py -c "import game; q = game.PHASES[1]['interaktion']; src = q['frage']; assert 'Markdown' in src and 'JSON' in src; assert 'In SDD' in q['feedback_richtig'] or 'Das SDD-Plugin' in q['feedback_richtig']; print('T-003 OK')"
```

### Research + Plan phase checks

```bash
py -c "import game; r = game.PHASES[2]['interaktion']; p = game.PHASES[3]['interaktion']; assert any(w in r['frage'] for w in ['Fakt','Hypothese','bestätigt','Beweis']); assert any(w in p['frage'] for w in ['Reihenfolge','Abhängigkeit','Task','Sequenz']); assert 'In SDD' in r['feedback_richtig'] or 'Das SDD-Plugin' in r['feedback_richtig']; print('T-004 OK')"
```

### Implement + Review + Close phase checks

```bash
py -c "import game; i=game.PHASES[4]['interaktion']; r=game.PHASES[5]['interaktion']; c=game.PHASES[6]['interaktion']; assert any(w in i['frage'] for w in ['Verifikation','schlägt','fehl','verifizier']); assert any(w in r['frage'] for w in ['PASS','FAIL','AC','Kriterium']); assert any(w in c['frage'] for w in ['knowledge','Wissen','KNOWLEDGE']); print('T-005 OK')"
```

### Manual play

Run `python game.py` and complete a full 7-phase walkthrough. Confirm that: each phase shows a question, invalid input triggers a retry prompt, correct and incorrect answers each produce a feedback line starting with "In SDD gilt:", the final screen shows "X von 7 Fragen richtig".

## Known Limitations

- **FR-003 placement**: The AC judgment question (FR-003, spec.md) was intended for the Design phase but landed in Review. No acceptance criterion was violated; the deviation is informal. A future revision could add a second interaction to Design for strict FR-003 compliance.
- **Single interaction per phase**: Each phase has exactly one question. The spec explicitly scoped this as one question per phase; expanding to multiple questions per phase is a non-goal for this feature.
- **No test framework**: Verification relies on `py -c` structural assertions and manual playthrough. Automated behavioral testing (simulating `input()` responses) is out of scope.
- **No input type variety at runtime**: `ask_question()` handles `"mc"` and `"passfail"` types; `"order"` is defined in the schema but the interaction content for Plan phase uses an MC mechanic in practice. The `typ` field is present for extensibility.
- **Score not persisted**: There is no high-score storage. The score is computed per session and displayed once at the end. This is an explicit non-goal from spec.md.

## Further Reading

- [README.md](README.md) — Narrative story: problem, solution, key decisions, outcome
- [spec.md](spec.md) — Full functional requirements (FR-001 to FR-011) and acceptance criteria (AC-001 to AC-008)
- [research.md](research.md) — Confirmed facts about `game.py` line references, system context diagram, risks
- [plan.md](plan.md) — Architectural decisions AD-001 to AD-005 with rejected alternatives
- [tasks.md](tasks.md) — T-001 to T-005 with per-task verification commands
- [review.md](review.md) — AC validation table with file:line citations, adjudication, final verdict
