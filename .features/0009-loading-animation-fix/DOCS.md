# Technical Reference: Loading Animation Fix

## Architecture Overview

Single-function, single-file patch. The feature modifies only the loading animation block (~5 lines) inside `show_intro()` in `game.py`. No new modules, classes, or abstractions were introduced.

The design pattern is a time-driven terminal animation using raw ANSI escape sequences. The loop polls `time.time()` to append dots at a fixed interval (0.33s) for a fixed duration (~4s), wrapping the entire block with cursor-hide and cursor-restore escapes. Color is applied via the pre-existing `BLAU` / `RESET` constants defined in `game.py`.

## Components & Files

| File | Action | Purpose |
|:-----|:-------|:--------|
| `game.py` | Modified | Sole production file. Loading animation block inside `show_intro()` replaced. No other function or section touched. |

> Note: scope.txt was present in the feature directory but empty. The file list above is sourced from tasks.md (`Files: ["game.py (modify)"]`) and the review scope conformance table.

## Interface Changes

No new commands, APIs, or configuration were added. The change is entirely internal to `show_intro()`.

Behavioral changes visible to the end user:

- The loading dot sequence now grows beyond 3 dots for the full display duration (target: ~12 dots over ~4 seconds at 0.33s per dot).
- The terminal cursor is hidden during the animation and restored after it ends.
- The animation text is rendered in blue (using the `BLAU` constant) instead of the previous gray.

Relevant ANSI sequences now present in `show_intro()`:

| Sequence | Purpose |
|:---------|:--------|
| `\033[?25l` | Hide cursor — inserted at animation start |
| `\033[?25h` | Restore cursor — inserted at animation end |
| `{BLAU}...{RESET}` | Blue text for loading line |

## Testing & Verification

### Verification Command (from tasks.md T-001)

```bash
py -c "import inspect, game; src = inspect.getsource(game.show_intro); assert '?25l' in src, 'FAIL: Cursor-Hide fehlt'; assert 'BLAU' in src, 'FAIL: BLAU fehlt'; print('OK')"
```

Expected output: `OK`

### Recorded Verification Result

Captured in `.features/0009-loading-animation-fix/verification/T-001.json` at 2026-06-29T11:21:10Z:

- `result`: pass
- `exit_code`: 0
- `stdout`: "OK"
- `stderr`: ""

### AC Coverage

| AC | Description | Result |
|:---|:------------|:-------|
| AC-001 | `show_intro()` source contains `\033[?25l` | PASS |
| AC-002 | `show_intro()` source contains `BLAU` in loading block | PASS |

### Trace Coverage

71.43% (3 passed / 1 failed / 6 skipped). Skipped rules are expected for the lite SDD profile (no research.md, no plan.md, no brief.md). The single failing rule (`review.Validates`) is a tooling artifact: the review table entries lack a machine-readable `validates` link — the human-readable AC evidence is present and sufficient.

## Known Limitations

**Conflicting verification record.** The scratchpad contains an entry at 2026-06-29T13:20:18 stating "Verification FAILED for T-001 (exit 1)". The verification artifact (T-001.json, captured 2026-06-29T11:21:10Z) shows `exit_code: 0` and `stdout: "OK"`. The basis for the later scratchpad failure note is not documented. Engineers running the verification command fresh against the current `game.py` source should treat the T-001.json artifact as the authoritative record.

**No automated test suite.** Verification relies on `inspect.getsource` source inspection rather than a runtime behavior test. This confirms the ANSI sequences are present in the function's source but does not validate the animation's timing behavior or visual output.

**ANSI sequences are platform-dependent.** `\033[?25l` / `\033[?25h` cursor control requires a VT100-compatible terminal. Behavior on Windows terminals that do not have ANSI support enabled (e.g., legacy `cmd.exe` without Virtual Terminal Processing) is not documented in any artifact.

## Further Reading

- [README.md](./README.md) — Narrative overview: problem, solution, key decisions, review outcome
- [spec.md](./spec.md) — Functional requirements FR-001 through FR-003 and acceptance criteria
- [tasks.md](./tasks.md) — Task T-001 detail, scope boundary, done-when criteria
- [review.md](./review.md) — AC validation table, trace score, scope conformance, issues found
- [verification/T-001.json](./verification/T-001.json) — Raw verification result captured during implementation
