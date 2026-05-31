# Implementation Status

Generated: 3025-05-26 (updated per commit abc4cb6)
Plan: `ai/plan.md`

---

## Phase 0: Foundation & Tooling — COMPLETE
Godot 4 project, Makefile, autoloads, resource classes, MegaMekParser, DataManager, themes, tr() throughout UI (~120 keys), EventBus with 20 signals

## Phase 1: Core Systems — COMPLETE (minor gaps)
Time (calendar, pause, tactical, month_started signal), Economy (market with scarcity tiers, interstellar orders, contracts, salvage, ammo tracking, auto-reorder, per-month payouts, upfront payment), Reputation (global + faction, tiers), Personnel (AToW attributes, roles, hire/fire, aging, injury/heal, relationships)
Gaps: pilot abilities, passive XP, preferred_gender, children/education — post-v1

## Phase 2: Data & Configuration — COMPLETE
32 faction JSONs (added 21 minor/periphery/disputed factions), 263 component JSONs, hundreds of .mtf/.blk files, 12 RATs, 3174 systems from SUCKIT CSVs, 9670 timeline events, is_periphery flag, reputation_levels_gates type fix, critical_slots fixes
Gaps: USILR/HPG gameplay, TM construction fields — post-v1

## Phase 3: Strategic Layer — MOSTLY COMPLETE
StarMap (3174 systems, faction territory borders, disputed territory stripes, A* pathfinding, collision-free labels, hidden waypoints, 720 LY cutoff, Clan/abandoned/SLSC filtering, zoom 0.3-5.0), sidebar, contract generator (distance-based pool, minimum 5/month, pirate hunting, low-rep restrictions, Periphery bias), org management, strategic events, MechLab, unit generator, InventoryManager
Gaps: deploy-time allocation UI, auto-allocate defaults, fund gate badge — post-v1

## Phase 4: Operational Layer — NOT STARTED
## Phase 5: Rules Engine — NOT STARTED
## Phase 6: Tactical Layer — NOT STARTED (MegaMekParser only)

## Future Work (post-v1)
Aerospace, advanced narrative (contract chains, bounties, lostech/pirates, Solaris VII, SLSC discovery), advanced contracting (breaches, disputed systems, side-taking, emergency rep recovery), advanced market (black market, factory-direct, logistics check limits), event system (journal, rolling window, narrative anchors, diffs, display modes), advanced tech (XL/XXL engines, advanced gyros, lostech), non-mech units, pilot abilities, passive XP, advanced politics, save/load, UI polish, data gaps

---

## Tests: 37 total (13 MTF parser + 22 market + 2 strategic gen), all passing
