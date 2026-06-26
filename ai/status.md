# Implementation Status

Generated: 3025-06-02 (final)
Plan: `ai/plan.md`

---

## Phase 0: Foundation & Tooling — COMPLETE
Godot 4 project, Makefile (suckit, lint before test, data-driven skills JSON), autoloads, resource classes, MegaMekParser, DataManager, themes, tr() throughout UI (130+ keys), EventBus with 20+ signals (day_started, week_started, month_started). Debug output to stderr via Helpers.debug_print.

## Phase 1: Core Systems — COMPLETE
Time (calendar, pause, tactical, day/week/month_started signals), Economy (market with scarcity tiers, data-driven contract config, distance-based pool, min 5/month, pirate hunting, low-rep restrictions, Periphery bias, emergency contracts, auto-reorder weekly, dispatch/recover, per-month payouts, upfront payment), Reputation (global + faction, tiers), Personnel (AToW attributes, MECHWARRIOR/VEHICLE_CREW role separation, officer rank titles, role-specific skills, 1% LAM pilot, hire/fire, aging, injury/heal with healing days display, relationships, data-driven skills from data/skills.json)

## Phase 2: Data & Configuration — COMPLETE
32 faction JSONs (is_periphery, hidden_on_map flags), 263 component JSONs, hundreds of .mtf/.blk files, 12 RATs, 3174 systems from SUCKIT CSVs, 9670 ISO-format timeline events, 169 data-driven skills in data/skills.json, contract config in data/config/contract_generation.json, critical_slots fixes, reputation_levels_gates fix

## Phase 3: Strategic Layer — MOSTLY COMPLETE
StarMap (3174 systems, faction territory/disputed stripes via Voronoi grid, A* pathfinding, collision-free labels, hidden waypoints, 720 LY cutoff, Clan/abandoned/SLSC/hidden/UNM filtering, zoom 0.3-5.0, centered on home), sidebar (UnitRoster removed — folded into MechLab repair + Personnel), contract generator (data-driven config, distance-based pool), org management, strategic events, MechLab (incl. per-component repair with queue, skill checks, spare parts consumption), unit generator, InventoryManager, PersonnelManagement (personnel/medbay tabs), Helpers.fmt_money/fmt_number

## Save System — COMPLETE
SaveManager autoload with versioned JSON serialization + forward-compatible migration system. Full save/load UI: in-game SaveDialog (name input, compression toggle, overwrite detection, existing saves list), LoadDialog (metadata display, delete), main menu SaveLoadMenu. Auto-save triggers on month_started (configurable interval: daily/weekly/monthly) and on contract deploy. Configurable rotation count (default 5) and optional gzip compression. Serializes all campaign state: player, time, contracts, inventory, personnel (with relationship/patient refs), economy (bills, salvage, deliveries), reputation, refits/repairs, in-transit items. Refit/repair unit references resolved on load. Market re-initialized on player's planet after load. Save directory: `user://saves/`.

## Phases 4-6: Operational/Rules/Tactical — MOSTLY COMPLETE
## Phase 4 (Operational): Pending
## Phase 5 (Rules Engine) / Phase 6 (Tactical):
##   - data/rules/terrain_types.json: terrain definitions with per-mode costs and effect tags
##   - data/rules/terrain_effects.json: effect tag reference documentation
##   - data/rules/terrain_movement.json: global movement constants
##   - data/rules/psr_triggers.json: v1.1 with movement-specific PSR trigger definitions
##   - src/tactical/EffectRegistry.gd: terrain effect handler registry with PSR trigger data integration
##   - src/tactical/MovementCostResolver.gd: refactored to read from JSON
##   - src/tactical/TacticalMovementResolver.gd: Dial's bucket over (hex,facing,height) state space
##   - src/data/TacticalStructure.gd: runtime structure class with mutable CF and damage tracking
##   - src/tactical/AIEvaluator.gd: updated to use Dial's bucket instead of stub BFS
##   - src/ui/tactical/TacticalMap.gd + .tscn: interactive hex grid with reachable overlay, move execution, collapse/PSR warnings

## Future Work (post-v1)
Aerospace, advanced narrative (contract chains, data-driven contract definitions, event-only contracts, bounty/lostech/pirates, Solaris VII, SLSC discovery), advanced contracting (breaches, disputed/contested systems, side-taking, emergency rep recovery, influence-range pool), advanced market (black market, factory-direct, logistics check limits), event system (journal, rolling window, narrative anchors, diffs, display modes, era-gated skills, faction-aware hiding, event-only contracts), advanced tech (XL/XXL engines, advanced gyros, lostech), non-mech units, data-driven personnel types with correlation rules, pilot abilities, passive XP, preferred_gender/children/education, advanced politics, UI polish (deploy-time allocation, fund gate badge, auto-allocate defaults, HUD badges, color blind), data gaps (USILR/HPG, TM construction fields, data-driven traits, faction_destroyed events), data-driven medals/injuries, data validation system

---

## Mod System — COMPLETE
ModManager autoload scans `res://mods/` and `user://mods/` at startup. Each mod is a self-contained directory with `mod.json` (metadata) and `strings.json` (keyed localization). `ModManager.tr_content(key)` merges all mod strings (later mods override earlier by `load_priority`) and falls back to `tr()` for UI chrome. Data files reference strings by key (`title_key`, `desc_key`, etc.) instead of embedding display text. `get_mod_data_paths(type)` returns mod subdirectories for DataManager integration. Example mod at `mods/example_chain/`. Example event data references `title_key: "example_chain.event.pirate_rising.title"` resolved via `tr_content()`.

## Tests: 148 total, all passing
- 13 MTF parser — MTF/BLK unit parsing and validation
- 22 market population — planetary market generation and scarcity
- 2 strategic unit generator — starting force generation
- 5 starmap cache — territory computation and caching
- 25 planetary map generator — map gen, objectives, biomes, OpFor, regions, RAT fallback, contract defs, canonical fallthrough
- 48 data formats (+10: terrain_types, terrain_effects, terrain_movement structure + negative cases)
- 9 save system — file I/O, compression modes, autosave rotation, error handling
- 9 mod system — mod detection, strings loading, override order, data paths, version checking
- 6 tactical integration — GATOR, cluster hits, hit location, attack flow, PSR, phase manager
- 9 AI evaluator — threat targeting, cover/flank preference, heat budget, weapon affinity, blocked LOS, ammo conservation

## Infrastructure
- `TimeManager.date_changed` removed — all systems use `EventBus.day_started` (Signal Down pattern)
- `make bootstrap` generates `.godot` script class cache for headless runs; auto-runs before `make test`
- `make clean` removes `.godot/` cache
