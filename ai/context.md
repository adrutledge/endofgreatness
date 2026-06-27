# End of Greatness — AI Session Context

## Project
BattleTech grand strategy simulation in Godot 4.6.2 (GDScript).

## Quick Reference
- **Plan:** `ai/plan.md` — versions, phases, design notes
- **Status:** `ai/status.md` — what's done vs not started
- **Combat rules:** `docs/tactical_combat_rules.md`
- **Makefile:** `make test` (full suite), `make test-unit` (fast), `make test-integration` (slow)

## Project Structure

```
src/
  core/          — Autoloads: GameState, EventBus, TimeManager, DataManager, ThemeManager,
                   StarmapCacheGenerator, SaveManager, ModManager
  data/          — Resource classes: TacticalUnit, Component, Personnel, Contract, Faction,
                   Strategic/Organizational/OperationalUnit, HexMap, etc.
  data/validators/ — TM validation per unit type (MechValidator, VehicleValidator, UnitValidator base)
  systems/       — EconomySystem, ReputationSystem, PersonnelManager, RefitManager,
                   InventoryManager, UnitTransportManager, InterstellarOrderManager, PlanetaryMarket
  strategic/     — ContractGenerator, PlanetaryMapGenerator, StrategicUnitGenerator, RATParser,
                   EventPopupHandler, StrategicEventGenerator
   tactical/      — CombatResolver, PSRResolver, LOSResolver, AIEvaluator, PhaseManager (stubs),
                    CritResolver, MegaMekParser, MovementCostResolver, ClusterHitsResolver,
                    FacingResolver, AerospaceMovementResolver, ControlCheckResolver,
                    TacticalMovementResolver (Dial's bucket over hex/facing/height),
                    EffectRegistry (terrain effect handler registry with PSR data)
  operational/   — OrganizationManager
  ui/            — CampaignView, HUD, StarMap, MechLab (~1900 lines), LogisticsPanel (~1350 lines),
                   PersonnelManagement, ContractBoard, PanelManager, ModalLayer, etc.
  utils/         — Helpers (fmt_money, fmt_number, debug_print)
tests/           — 10 suites, 138 tests
mods/            — Self-contained mod directories with strings.json keyed localization
data/            — factions/, components/, units/, starmap (3174 systems), timeline (9670 events),
                    skills (169), rat/, rules/ (hit_locations, heat_table, cluster_hits,
                    physical_attacks, psr_triggers, forced_withdrawal, suspension_factors, combat_config,
                    terrain_types, terrain_effects, terrain_movement),
                    config/ (contract_generation, spares_config), unit_types/, traits/, planetary/
docs/            — tactical_combat_rules.md
```

## Architecture & Conventions
- **Autoloads (15):** GameState, EventBus, TimeManager, DataManager, ThemeManager, StarmapCacheGenerator, EconomySystem, ReputationSystem, PersonnelManager, RefitManager, UnitTransportManager, InventoryManager, PanelManager, SaveManager, ModManager, **OpenCodeDebugger**
- **Resource classes** — all data classes extend Resource with class_name (TacticalUnit, Component, Personnel, Contract, Faction, etc.)
- **Signal Down, Call Up** — systems emit signals, UI calls methods on systems
- **Signal lifecycle** — connect signals in `_ready()`, disconnect in `_exit_tree()`. Prevents signals firing into freed nodes when scenes unload.
- **Lazy Refresh** — `mark_for_rebuild()` + `_ensure_fresh()` dirty-flag pattern
- **Data-driven first** — JSON over hardcoded logic; component defs, AI personalities, PSR triggers all data
- **Edition-gated entries** — optional `"edition": {"from": "a", "to": "b"}` on any JSON entry
- **tr() for UI** — all user-facing strings use `tr()`; content strings use `tr_content()` via ModManager
- **Zstd compression** — all saves use `.json.zst` with zstd compression
- **Semver** — MAJOR = V number; exact major+minor match for mod compatibility
- **EventBus signals (20+):** day_started, week_started, month_started, contract_accepted/completed, etc.
- **Save forward compatibility** — versioned JSON with sequential `_upgrade_to_v<N>()` functions (one atomic change per version). Saves are self-contained (no invariant game data duplicated).
- **Mod data in saves** — saves record `mod_versions` (mod_id → version at save time) and `mod_extras` (per-mod opaque data). On load: restore mod_extras, run mod migrations (only if saved version ≠ current version), then restore core state. Mod migrations receive the mod's own extra data and return transformed data — they cannot modify core save fields. Mods access persistent data via `SaveManager.get_mod_data(mod_id)` / `set_mod_data(mod_id, data)`. Register migrations via `ModManager.register_migration(mod_id, callable, from_version, to_version)`.
- **NPC persistence** — archetype reference + seed + limited flags in saves, not full data duplication
- **MegaMekParser** — parses .mtf and .blk unit files into TacticalUnit resources
- **TM validation** — per-type validators (MechValidator, VehicleValidator) registered in TacticalUnitValidator. Extensible for aerospace/dropship/warship via register_validator().
- **Crit effects** — data-driven per component: crit_effect_type (weapon/ammo/actuator/gyro/engine/heat_sink), explodes_on_crit, crit_effect_data. Handlers registered in CritEffectRegistry.
- **UI stack** — PanelManager manages overlay panels (personnel, event_log, mech_lab, logistics, contract_board, org_mgmt). ModalLayer handles dialogs FIFO with pause support.
- **Deferred bugs:** HUD BillsLabel not found via $TopBar/Finances/BillsLabel — use two-step get_node.

## Current State (V1 — Basic Gameplay Loop)
- **Phases 0-3:** Complete (Foundation, Core Systems, Data, Strategic Layer)
- **Phases 4-6:** Not started (Operational, Rules Engine, Tactical)
- **Save system:** Complete (versioned serialization, migrations, auto-save, full UI)
- **Mod system:** Complete (self-contained mod dirs, keyed localization, version checking)
- **AI/tactical design:** Comprehensive, stubs implemented for CombatResolver, PSRResolver, AIEvaluator, PhaseManager
- **Advanced tech prep:** Component JSON fields documented (slot_flexible, weight_multiplier, etc.), not implemented
- **Tests:** 148 passing across 10 suites: MTF parser (13), market (22), strat unit gen (2), starmap cache (5), plan map gen (25), data formats (48), save system (9), mod system (9), tactical integration (6), AI evaluator (9)
- **Make targets:** test (full), test-unit (100 fast), test-integration (38 slow), lint (gdlint)

## OpenCodeDebugger — AI Debug Harness

Autoload `OpenCodeDebugger` (`src/core/OpenCodeDebugger.gd`) activated by `--opencode-debug`. Provides live state introspection for AI-driven debugging via TCP socket and JSONL file.

### CLI Flags

| Flag | Effect |
|------|--------|
| `--debug` / `-d` | Human debug mode: enables `Helpers.debug_print`/`debug_warn` |
| `--opencode-debug` | Activates OpenCodeDebugger (probe, pipe, headless, TCP) |
| `--opencode-pipe` | Also emit structured JSON to stdout |
| `--opencode-headless` | Headless mode: no window, auto-start campaign |
| `--opencode-port=N` | TCP port for command socket (default 12075, 0 = disable) |
| `--load-save=<path>` | Save file to load in headless mode (else start new campaign) |

### Outputs

| Output | Path | Format |
|--------|------|--------|
| JSONL file | `user://opencode_debug.jsonl` | One JSON object per line, flushed per-entry |
| Stdout pipe | (when `--opencode-pipe`) | Same JSON lines, opencode reads via pipe |
| TCP socket | `127.0.0.1:12075` | Bidirectional JSON-line commands/responses |

### TCP Protocol

Connect on port 12075. Send one JSON command per line, receive one JSON response per line.

Commands: `probe`, `get_log`, `get_state`, `get_ui`, `dump_org`, `advance`, `pause`, `unpause`, `set_speed`, `save`, `load`, `add_funds`, `set_funds`, `add_item`, `remove_item`, `add_personnel`, `remove_personnel`, `add_unit`, `remove_unit`, `quit`.

### Makefile Targets

| Command | Effect |
|---------|--------|
| `make rund` | Human debug (`--debug`) |
| `make runoc` | OpenCode interactive with pipe |
| `make runoc-headless` | Headless, auto campaign, file output |
| `make runoc-headless-pipe` | Headless with pipe |
| `make runoc-load` | Headless loading autosave |

> See **AGENTS.md** for AI behavioral rules, file maintenance conventions, and testing requirements.

## Useful Commands
```bash
make test        # Full test suite
make test-unit   # Fast tests only (100 tests)
make lint        # GDScript style check
make bootstrap   # Regenerate .godot cache
```

