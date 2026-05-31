# Implementation Status

Generated: 3025-05-31 (updated per commit HEAD)
Plan: `ai/plan.md`

---

## Phase 0: Foundation & Tooling — COMPLETE
Godot 4 project, Makefile (suckit, lint before test), autoloads, resource classes, MegaMekParser, DataManager, themes, tr() throughout UI (130+ keys), EventBus with 20 signals. Debug output to stderr via Helpers.debug_print.

## Phase 1: Core Systems — COMPLETE (minor gaps)
Time (calendar, pause, tactical, month_started signal), Economy (market with scarcity tiers, interstellar orders, contracts, salvage, ammo tracking, auto-reorder weekly, dispatch/recover, per-month payouts, upfront payment), Reputation (global + faction, tiers), Personnel (AToW attributes, MECHWARRIOR/VEHICLE_CREW etc. role separation, officer rank titles, role-specific skills, 1% LAM pilot chance, hire/fire, aging, injury/heal, relationships)
Gaps: pilot abilities, passive XP, preferred_gender, children/education — post-v1

## Phase 2: Data & Configuration — COMPLETE
32 faction JSONs (added 21 minor/periphery/disputed factions, is_periphery flag), 263 component JSONs, hundreds of .mtf/.blk files, 12 RATs, 3174 systems from SUCKIT CSVs, 9670 timeline events, critical_slots fixes (gyro 4, engines 6, cockpit 1), reputation_levels_gates type fix
Gaps: USILR/HPG gameplay, TM construction fields — post-v1

## Phase 3: Strategic Layer — MOSTLY COMPLETE
StarMap (3174 systems, faction territory borders, disputed stripes, A* pathfinding, collision-free labels, hidden waypoints, 720 LY cutoff, Clan/abandoned/SLSC/Chainelane/UNM filtering, zoom 0.3-5.0, centered on home), sidebar, contract generator (distance-based pool, min 5/month, pirate hunting, low-rep restrictions, Periphery bias, emergency contracts), org management, strategic events, MechLab, unit generator, InventoryManager, Helpers.fmt_money/fmt_number for all large numbers
Gaps: deploy-time allocation UI, auto-allocate defaults, fund gate badge — post-v1

## Phases 4-6: Operational/Rules/Tactical — NOT STARTED (MegaMekParser only)

## Future Work (post-v1)
Aerospace, advanced narrative (contract chains, bounties, lostech/pirates, Solaris VII, SLSC discovery), advanced contracting (breaches, disputed systems, side-taking, emergency rep recovery), advanced market (black market, factory-direct, logistics check limits), event system (journal, rolling window, narrative anchors, diffs, display modes, era-gated skills), advanced tech (XL/XXL engines, advanced gyros, lostech), non-mech units, pilot abilities, passive XP, advanced politics, save/load, UI polish, data gaps, data-driven personnel types with correlation rules

---

## Tests: 37 total (13 MTF parser + 22 market + 2 strategic gen), all passing
