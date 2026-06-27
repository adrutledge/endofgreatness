# AGENTS.md — AI Behavioral Rules & Conventions

## Enforced Architecture Patterns
These are documented in full in the source files noted; the AI must follow them.

- **Data-Driven First** (`ai/plan.md`) — prefer JSON over hardcoded logic; config files define behavior that would otherwise require code changes
- **Signal Down, Call Up** (`ai/plan.md` / `ai/context.md`) — systems emit signals to listeners; UI/reactors call methods on systems
- **Lazy Refresh Pattern** (`ai/plan.md`) — `mark_for_rebuild()` + `_ensure_fresh()` dirty-flag for periodic refreshes; avoids frame spikes during tick processing
- **Signal Lifecycle** (`ai/context.md`) — connect signals in `_ready()`, disconnect in `_exit_tree()`; prevents signals firing into freed nodes when scenes unload
- **Edition-gated entries** (`ai/context.md`) — optional `"edition": {"from": "a", "to": "b"}` on any JSON entry
- **tr() for UI / tr_content() for content** (`ai/context.md`) — all user-facing strings use `tr()`; content strings use `tr_content()` via ModManager
- **NPC Persistence** (`ai/context.md`) — archetype reference + seed + limited flags in saves, not full data duplication
- **Save Forward Compatibility** (`ai/plan.md`) — versioned JSON with sequential `_upgrade_to_v<N>()` functions; one atomic change per version

## File Editing Rules
- **One change per file edit** — keep edits focused. If fixing a typo in one file and adding a feature in another, do them separately. Reduces AI confusion from mixed-context diffs.
- **Flag prefixes** — use consistently for deferred work: `Flag for rules verification:`, `Flag for later:`, `Deferred:`. Keeps them searchable and prevents treating them as implemented.
- **Save migration markers** — when adding a new field to a Resource class (Personnel, TacticalUnit, etc.), add a `# TODO: save migration` comment. Prevents shipping features that silently break save compatibility.

## Defensive Programming
- **Assertions at boundaries** — use `assert()` at public function entry points to catch programmer errors early (wrong type, null where disallowed, impossible state). Fail fast, not silent.
- **Null-guard public functions** — check parameters and autoload references at public function boundaries with clear error messages (`printerr` or `push_error`), not silent default returns.

## Testing Requirements
- **Data file constraint** — creating a new data file type or changing the format of an existing one requires:
  1. Positive + negative tests in `test_data_formats.gd` covering structure and edge cases
  2. A table entry or note in `docs/tactical_combat_rules.md` (or the appropriate docs file)
  3. An update to the data directory map in `ai/context.md`
  This ensures the data-driven system stays tested and documented as it grows.
- **Save migrations** — every `_upgrade_to_v<N>()` function must have corresponding positive and negative tests in `tests/test_save_system.gd`. Positive test: save at version N-1 loads and produces expected shape at version N. Negative test: corrupt data at N-1 is handled gracefully.
- **Data validation modes** — three gating levels: `--opencode-debug` (startup + debug menu button), `--opencode-validate-data` (standalone CI mode), `--opencode-validate-in-game` (live modder mode, F5 keybind). All run `validate_data()` on all loaded data files.

## Commit & Push Workflow
- Commit after each major line item once `make test` passes with 0 failures, then push
- Keeps history granular and prevents drift
- Write commit messages as descriptive imperative sentences — the first line becomes the release note entry

## File Maintenance Rules
- **AGENTS.md** — AI behavioral rules and conventions. Update when a rule or convention changes.
- **`ai/plan.md`** — source of truth for design decisions, version targets, architecture notes. Update when a decision is made.
- **`ai/status.md`** — source of truth for implementation state. Update when something is completed or a phase advances.
- **`ai/context.md`** — session bootstrap cache. Keep concise — point to plan/status for depth rather than duplicating. Add a decision here only when it's critical for the AI to know at session start.

## System & Installation Policy
- Do not install anything without explicit instructions. This includes pip, dnf, or any other tool that would perform an installation, or any script that utilizes any such tool to install something.

## Internet & External Actions
- Never post anything on the internet on my behalf in any mode.
- Exception: in build mode, you may push code to the GitHub repo for this project.
