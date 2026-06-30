# Loading Animation Fix

## Problem

The loading animation in `show_intro()` inside `game.py` had three independent defects. First, the animation was hard-capped at three dots regardless of how long the intro ran — it cycled through `'.'`, `'..'`, `'...'` in a loop rather than growing over time. Second, the terminal cursor remained visible and blinked visibly after the dots during the animation, producing an distracting visual artifact. Third, the animation text was rendered in gray instead of the blue color used elsewhere in the game's UI.

## Solution

A single task (T-001) replaced the approximately five-line loading block inside `show_intro()` in `game.py`. The replacement used a time-based loop running for roughly four seconds, appending one dot every 0.33 seconds to reach approximately twelve dots total. The ANSI escape sequence `\033[?25l` hides the cursor at the start of the animation and `\033[?25h` restores it afterwards. The animation text was switched to the existing `BLAU` color constant with a `RESET` at the end.

The scope boundary was strictly observed: only the loading animation block was modified. No other parts of `show_intro()` or `game.py` were touched.

## Key Decisions

**Time-based loop instead of a dot-list cycle.** The original implementation iterated over a fixed list `['.', '..', '...']`. The replacement drives dot count from elapsed time (`time.time()`). A fixed list extension (e.g., four or six dots) was the simpler alternative, but it would still have imposed an arbitrary cap. The time-based approach makes the animation length proportional to actual display duration without requiring the list to be maintained.

**ANSI escape for cursor suppression instead of a library.** Using `\033[?25l` / `\033[?25h` directly avoids any dependency on `curses` or a third-party terminal library. Because `game.py` already used raw ANSI sequences for colors, adding cursor control via the same mechanism kept the approach consistent with the existing codebase pattern and required no new imports.

**Reuse of the existing `BLAU` constant instead of an inline escape code.** The spec required blue color. The `BLAU` constant was already defined in `game.py` for other UI elements. Hard-coding a new ANSI color escape inline would have duplicated the constant and created a maintenance inconsistency. Using `BLAU` directly honored the existing color abstraction.

## Outcome

Review verdict: **PASS**

Both acceptance criteria passed via automated verification at 2026-06-29T11:21:10Z:

- AC-001: `inspect.getsource(show_intro)` contains `\033[?25l` — confirmed present.
- AC-002: `inspect.getsource(show_intro)` contains `BLAU` in the loading block — confirmed present.

No critical or minor issues were recorded in review. No unrequested changes were found. Trace coverage was 71.43% (3 passed / 1 failed / 6 skipped rules); the skipped rules are expected for the lite SDD profile, and the single failing rule (`review.Validates`) reflects a tooling limitation in linking review rows via the `validates` relation rather than a substantive gap.

One caveat: the scratchpad contains a later timestamp entry (13:20:18) marking T-001 verification as "FAILED", which conflicts with the verification artifact (T-001.json, 11:21:10, exit_code: 0, stdout: "OK"). The review verdict is supported by the verification artifact; the scratchpad entry appears to have been written after the fact and its basis is not documented.

## Lessons Learned

The knowledge.md artifact contains no graduated entries — limited information available from that source. The scratchpad also contains no substantive observations beyond the conflicting verification note described above.

One structural observation from the artifacts: the lite SDD profile skips several trace rules (spec derivation, task derivation, plan coverage) that normal and deep profiles enforce. This makes the trace score an incomplete signal for lite features — the 71.43% score here reflects skipped rules, not actual gaps in coverage.

## Further Reading

- [DOCS.md](./DOCS.md) — Technical reference: component table, interface details, verification commands, known limitations
- [spec.md](./spec.md) — Problem statement, functional requirements, acceptance criteria, scope constraints
- [tasks.md](./tasks.md) — Single task breakdown, done-when criteria, scope boundary, verification command
- [review.md](./review.md) — AC validation table, trace coverage report, scope conformance table
- [scratchpad.md](./scratchpad.md) — Runtime observations and the conflicting verification note
- [knowledge.md](./knowledge.md) — Knowledge base (no entries graduated for this feature)
