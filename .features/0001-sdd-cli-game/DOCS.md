# Technical Reference: SDD CLI Game

## Architecture Overview

Single-file Python script (`game.py`) with a linear, procedural execution flow. No package structure, no classes. The design pattern is a pipeline: `main()` orchestrates four named functions in sequence, each responsible for a distinct phase of the player experience.

```
main()
  └─ skip-check (.sdd_game_seen marker)
  └─ show_intro()        narrative intro + ASCII art
  └─ run_phase() × 7    one call per PHASES entry
  └─ show_summary()      recap of all 7 phases
```

ANSI formatting is encapsulated in module-level constants (`GRÜN`, `ROT`, `GELB`, `FETT`, `RESET`). All user interaction runs through `input()` — no platform-specific keyboard libraries. Terminal width is detected via `shutil.get_terminal_size()`.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | create | Complete game: ANSI constants, terminal helpers, intro narrative, PHASES data, phase runner, summary, main orchestrator |
| `README.md` | create | Player-facing start instructions for Windows (`py game.py`) and Unix (`python3 game.py`), Windows Terminal note |
| `.sdd_game_seen` | generated at runtime | Marker file placed next to `game.py` after first intro completion; triggers skip-intro prompt on subsequent runs |

### Key Functions in `game.py`

| Function | Signature | Role |
|:---------|:----------|:-----|
| `main()` | `def main() -> None` | Entry point; skip-check, UTF-8 guard, orchestration |
| `show_intro()` | `def show_intro() -> None` | Narrative intro with PTA story and ASCII art |
| `run_phase()` | `def run_phase(phase: dict) -> None` | Renders one phase: name box, zweck, kernfrage, simulated prompt |
| `show_summary()` | `def show_summary(phases: list) -> None` | Closing recap listing all 7 phase names |
| `clear_screen()` | `def clear_screen() -> None` | `cls` on Windows, `clear` on Unix |
| `pause()` | `def pause(msg) -> None` | `input()`-based Enter-to-continue |
| `print_centered()` | `def print_centered(text, width) -> None` | Centers text using terminal width from `shutil` |
| `print_box()` | `def print_box(lines) -> None` | Draws Unicode box frame; uses `_visible_len()` for ANSI-safe padding |
| `_visible_len()` | internal | Strips ANSI escape codes before `len()` to compute visible character width |
| `_intro_already_seen()` | internal | Checks `.sdd_game_seen` marker relative to `__file__` |

### Module-Level Data

| Name | Type | Content |
|:-----|:-----|:--------|
| `PHASES` | `list[dict]` | 7 entries, keys: `name`, `zweck`, `kernfrage`, `prompt` — one per SDD phase |
| `GRÜN`, `ROT`, `GELB`, `FETT`, `RESET` | `str` | ANSI escape constants; set to `""` to disable all color output |
| `CHAOS_ASCII`, `SDD_ASCII` | `str` | Multi-line ASCII art blocks for the intro narrative |

## Interface Changes

This feature adds two new files to the project root. No existing code was modified.

**Start the game:**
```
# Windows
py game.py

# Unix
python3 game.py
```

**Requirements:** Python 3.8+ (stdlib only — no `pip install` needed). Windows Terminal recommended for ANSI color rendering; older `cmd.exe` will display colors without errors due to the `RESET`-constant design, but may show degraded visuals.

**Skip-intro behavior:** After the first complete run, `.sdd_game_seen` is created next to `game.py`. On subsequent starts, the player is prompted: `Intro überspringen? [j/n]:`.

## Testing & Verification

No automated test framework (spec Non-Goal). Verification is via Python one-liners that import `game` and assert structural properties.

### Task Verification Commands

| Task | Verification Command |
|:-----|:--------------------|
| T-001 | `py -c "import game; assert callable(game.clear_screen); assert callable(game.pause); assert callable(game.print_centered); assert callable(game.print_box); assert callable(game.main); print('T-001 OK')"` |
| T-002 | `py -c "import game; src = open('game.py', encoding='utf-8').read(); assert callable(game.show_intro); assert 'PTA' in src; assert 'ibe' in src; print('T-002 OK')"` |
| T-003 | `py -c "src = open('game.py', encoding='utf-8').read(); assert 'sdd_game_seen' in src; assert '__file__' in src; print('T-003 OK')"` |
| T-004 | `py -c "import game; assert len(game.PHASES) == 7; assert all(all(k in p for k in ['name','zweck','kernfrage','prompt']) for p in game.PHASES); print('T-004 OK')"` |
| T-005 | `py -c "import game, inspect; assert callable(game.run_phase); src = inspect.getsource(game.run_phase); assert 'subprocess' not in src; print('T-005 OK')"` |
| T-006 | `py -c "import game, inspect; assert callable(game.show_summary); src = inspect.getsource(game.main); assert 'show_intro' in src; assert 'run_phase' in src; assert 'show_summary' in src; print('T-006 OK')"` |
| T-007 | `py -c "import os; content = open('README.md', encoding='utf-8').read(); assert os.path.exists('README.md'); assert 'py game.py' in content; assert 'Windows Terminal' in content; print('T-007 OK')"` |

### AC Coverage (from review.md)

| AC | Verified Via | Result |
|:---|:-------------|:-------|
| AC-001 — ASCII intro before phases | `show_intro()` at `game.py:83`; `CHAOS_ASCII`/`SDD_ASCII` printed before phase loop at `game.py:291` | PASS |
| AC-002 — Phase 1 with Zweck and prompt | `PHASES[0]` at `game.py:172`; `run_phase()` at `game.py:221-233` | PASS |
| AC-003 — Summary lists all 7 phases | `show_summary()` iterates `PHASES`; `_visible_len()` strips ANSI before padding | PASS |
| AC-004 — No real `sdd` commands | AST-Walk: no `subprocess`, `os.system` only for `cls`/`clear` at `game.py:29` | PASS |
| AC-005 — Cross-platform | `sys.stdout.reconfigure(encoding='utf-8', errors='replace')` in `main()` | PASS |
| AC-006 — Skip intro on second run | `_intro_already_seen()` at `game.py:267`; skip prompt at `game.py:281-284` | PASS |
| AC-007 — No external packages | Imports: `os`, `sys`, `shutil`, `textwrap` — stdlib only | PASS |

## Known Limitations

**ANSI on legacy `cmd.exe` (RISK-001):** ANSI escape codes work in Windows Terminal but may render as raw escape characters in older `cmd.exe` windows. Mitigation documented in `README.md`. The `GRÜN`/`ROT`/etc. constants can be set to `""` to strip all color output without touching the rest of the code.

**No persistent game state:** `.sdd_game_seen` is the only persistent artifact. There is no save/load, no progress tracking beyond the skip-intro marker.

**Linear play only:** No branching storylines, no choices that affect outcome. A player cannot revisit individual phases without replaying from the start.

**`py` launcher availability (RISK-003):** The `py` launcher is not guaranteed on all Windows systems. Both `py game.py` and `python game.py` are documented in `README.md`.

**`.sdd_game_seen` not in `.gitignore` (F-005):** The marker file is generated at runtime in the project root but was not added to `.gitignore` during implementation. It will appear as an untracked file in git status after the first play-through.

**`rich` / `blessed` deferred:** The scratchpad notes that `rich` would simplify ANSI handling significantly. This was intentionally excluded in v1 (stdlib-only constraint). Any future version adding richer terminal rendering would need to revisit the `GRÜN`/`ROT`/`RESET` constants and `_visible_len()`.

## Further Reading

- [README.md](README.md) — Narrative overview, problem/solution, key decisions, lessons learned
- [research.md](research.md) — Runtime environment facts (FC-001 to FC-006), risks, confidence scoring
- [plan.md](plan.md) — Architectural decisions AD-001 to AD-005 with alternatives considered
- [tasks.md](tasks.md) — Per-task Done-When criteria and complete verification command set
- [review.md](review.md) — Issue details for F-001 through F-005, Verified Clean table, full AC evidence
- [knowledge.md](knowledge.md) — Reusable technical findings: curses unavailability, ANSI `len()` pitfall, cp1252 Unicode crash, scope-refresh workflow
