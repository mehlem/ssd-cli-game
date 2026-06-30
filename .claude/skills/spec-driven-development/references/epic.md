# Epic Layer

`.features/EPIC.md` is the project-level home for one large initiative: a migration, rewrite, integration, or other program that spans multiple SDD features. It keeps program context near the feature registry, lets operators scaffold features from stable entries, and feeds bounded epic context into hooks and worker dispatch packets.

The epic layer is not a feature profile. It has no brief -> spec -> research -> plan -> tasks -> review -> close chain. It sits above normal features and links to them through a single optional `epic_entry: E-NN` field in each linked feature's epic anchor artifact: `brief.md` for full/deep features, `spec.md` for lite features.

## Schema

Epic v1 uses one markdown file at `.features/EPIC.md`.

Required frontmatter:

```yaml
id: EPIC-<title-or-slug>
title: "<title>"
schema_version: 1
created: YYYY-MM-DD
updated: YYYY-MM-DD
```

Required body headings:

```md
# Epic: <title>

## Goal

## Entries
```

Optional program sections may appear as H2 headings:

- `## Background`
- `## Strategy`
- `## Architecture`
- `## Constraints`
- `## Decisions`
- `## Glossary`
- `## Risks`
- `## Out-of-Scope` or `## Out of Scope`
- `## References`

Entries live under `## Entries` as H3 blocks. Optional H2 group headings under `## Entries` group the following entries for status display; entries before a group render under `Ungrouped`.

```md
### E-01: Cut sessions over to JWT
> Slug: jwt-cutover
> Status: planned
> Mode: full
> Feature:
> Depends-on: ["E-00"]

#### Motivation
#### Problem
#### Vision
#### Context
#### Constraints
#### Notes
```

Entry IDs must match `E-NN` with at least two digits. `> Mode:` is `lite`, `full`, or `deep`. `> Depends-on:` uses canonical JSON-array syntax. `> Feature:` is empty until `sdd epic scaffold` or `sdd epic link` writes the linked feature reference. Flat features keep the legacy feature ID value; nested features store the canonical path relative to `.features/`, such as `client/auth/0042-session-cutover`.

## Lifecycle

Epic mode is active only when `.features/EPIC.md` exists. Create it explicitly with `sdd epic init`; there is no convention-only activation.

Entry status is displayed as one of:

- `planned`
- `in-progress`
- `done`
- `deferred`
- `cancelled`

Status derivation rules:

- Empty `> Feature:` means the operator-written `> Status:` is canonical, defaulting to `planned`.
- A linked open feature derives `in-progress`.
- A linked feature in close phase derives `done`.
- `deferred` and `cancelled` are sticky operator states that override `in-progress`, but never override `done`.
- Dangling feature links warn during `sdd epic check` but do not fail validation.

Soft dependencies do not block scaffolding. `sdd epic check` treats cycles, self-dependencies, malformed IDs, and missing dependency targets as hard precondition failures.

## CLI Commands

```bash
sdd epic init "Auth Rewrite"
sdd epic add jwt-cutover "Cut sessions over to JWT" --mode full --depends-on E-01,E-02
sdd epic check
sdd epic status
sdd epic scaffold E-04
sdd epic link E-04 0042-existing-feature
```

Command behavior:

- `init` creates `.features/EPIC.md` from `templates/epic.md`. Existing-file conflicts follow `--on-exists fail|overwrite|skip`.
- `add` appends a new entry at the end of `## Entries`, assigns the next monotonic `E-NN`, and writes empty brief-shape H4 sections.
- `check` validates the epic schema and dependency graph. JSON mode returns `data.findings`.
- `status` renders grouped entry tables and JSON `data.entries`; explicit `sdd epic status` and the no-arg dashboard rebuild `.features/.epic-state.json` from current linked feature state even when `EPIC.md` itself is unchanged. Linked nested entries preserve `feature` as the stored reference and add nullable `feature_id` / `feature_path` fields when the reference resolves.
- `scaffold` supports `lite`, `full`, and `deep` entries, calls normal `sdd init` as a black box, links `> Feature:`, stamps `epic_entry: E-NN`, stamps the epic hash in `based_on`, and restores the previous `.features/.active` pin when one existed. Full/deep scaffold copies entry H4 bodies into the new `brief.md`; lite scaffold copies compatible bodies into `spec.md` (`Problem`, `Vision` -> `Solution`, `Constraints`) and does not create `brief.md`.
- `link` backfills an existing feature. It accepts the same feature refs as normal feature commands, resolves them through the feature resolver, links `> Feature:` with the canonical flat ID or nested path, stamps `epic_entry: E-NN`, stamps the epic hash in `based_on`, and uses sibling rollback files so either the EPIC link and anchor provenance are written together or neither persists.

Epic v1 remains one root `.features/EPIC.md` file. Group folders under `.features/` are organizational containers for normal features, not additional epic registries.

For scaffold and link, write order matters: update the upstream `EPIC.md` entry first, then stamp the downstream anchor artifact's `based_on` map. Stamping first captures the old EPIC hash and makes trace-enabled anchors immediately suspect after the link write.

Scaffold recovery is explicit:

- If feature initialization or provenance writes fail, scaffold rolls back the EPIC change and removes the newly initialized feature when it is safe to do so.
- If H4 body copy fails after provenance is established, scaffold leaves the feature linked and recoverable, then exits with a clear recovery message. The operator can inspect the linked feature anchor artifact and continue manually.

## Slicing Rules

Claude never receives the whole epic by default. Context injection emits `<epic_context>` blocks only when both gates pass:

- `.features/EPIC.md` exists.
- The active feature's epic anchor artifact has `epic_entry: E-NN` (`brief.md` for full/deep, `spec.md` for lite).

SessionStart receives:

- epic title
- Goal
- Constraints
- Out-of-Scope
- active entry's dependency neighbors as `<entry-id>: <entry-title> [<status>]`

Phase-transition nudges receive delta slices only:

| Phase | Extra epic sections |
|:------|:--------------------|
| Design | Decisions |
| Research | Architecture, Glossary |
| Plan | Strategy, Decisions, Architecture |
| Implement | none |
| Review | Constraints, Out-of-Scope |

Dispatch packets receive role-scoped slices:

| Role | Extra epic sections |
|:-----|:--------------------|
| `research-scout` | Architecture, Glossary |
| `plan-drafter` | Strategy, Decisions |
| `implementer` | Glossary |
| `spec-reviewer` | Out-of-Scope |
| `quality-reviewer` | Architecture |

Every dispatch role also receives Goal and Constraints. The `<epic_context>` helper reads `EPIC.md` directly, never `.features/.epic-state.json`, to avoid stale hook context. Output is capped at 200 lines; truncated blocks end with `see .features/EPIC.md for full context`.

Two environment toggles control always-on slices:

- `SDD_EPIC_INCLUDE_GOAL=0`
- `SDD_EPIC_INCLUDE_DEPS_NEIGHBORS=0`

The UserPromptSubmit phase-transition path sets both to `0` so only phase-specific deltas are emitted.

## Drift Handling

Scaffolded and manually linked anchor artifacts record the epic's current content hash in frontmatter:

```yaml
based_on: {"EPIC-FOO":"sha256:<hash>"}
epic_entry: E-04
```

Trace refresh treats the epic as an out-of-tree artifact node for trace-enabled linked features. If `EPIC.md` changes after scaffolding or `sdd epic link`, the linked full/deep brief becomes suspect through the existing `based_on` machinery. Lite features do not create `trace.json`, but their `spec.md` still records `epic_entry` and `based_on` provenance. There is no auto-sync from epic to feature artifacts; the linked feature artifact remains operator-canonical after scaffold or link.

Review the epic change, then clear the suspect flag with:

```bash
sdd trace acknowledge 0042-foo --confirmed --reason "epic constraint update reviewed"
sdd trace refresh 0042-foo
```

Any edit to `EPIC.md` can mark linked full/deep feature briefs suspect, even when the operator only added an unrelated entry. That is intentional: hash-based drift detection cannot know whether a program-level change matters to each linked feature. The acknowledge reason records the human review.

## Related

- `templates/epic.md` — starter template copied by `sdd epic init`
- `scripts/sdd-epic.sh` — CLI surface
- `scripts/sdd-epic-lib.sh` — parser and dependency graph helpers
- `scripts/sdd-epic-refresh.sh` — derived status cache builder
- `references/trace-rules.json` — existing trace coverage rules that epic-linked briefs reuse
