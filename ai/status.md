# Implementation Status

Generated: 3025-05-26 (updated per commit 6a95f9a)
Plan: `ai/plan.md`

---

## Phase 0: Foundation & Tooling — COMPLETE

- Godot 4 project, directory structure, Makefile, autoloads
- Resource classes, MegaMekParser, DataManager
- Dark/light themes, ThemeManager, tr() throughout UI (~120 keys)
- EventBus with 20 signals

## Phase 1: Core Systems — COMPLETE (minor gaps)

- Time: calendar, pause/resume, tactical mode, timeline events, month_started signal
- Economy: C-Bills, market, interstellar orders, contracts, salvage, ammo tracking, burn rate, auto-reorder, dispatch/recover, Galatea market, scarcity tiers, per-month payouts, upfront payment
- Reputation: global + faction, tiers, threshold gating
- Personnel: AToW attributes, roles, assign/crew, hire/fire, aging, injury/heal, relationships

Gaps: pilot abilities, passive XP, preferred_gender, children/education — post-v1

## Phase 2: Data & Configuration — COMPLETE (minor gaps)

- 12 faction JSONs, 263 component JSONs, hundreds of .mtf/.blk files, 12 RATs
- Fixed critical_slots: gyro (4), all engines (6), cockpit (1)
- 47 starmap systems, timeline events

Gaps: USILR/HPG gameplay, faction_destroyed events, TM construction fields — post-v1

## Phase 3: Strategic Layer — MOSTLY COMPLETE

- StarMap, sidebar, contract generator, org management, strategic events
- MechLab with paper doll, refit, customization
- Initial unit generator (12 mechs, personnel, inventory)
- InventoryManager, dispatch, auto-reorder, in-transit tracking

Gaps: deploy-time allocation UI, auto-allocate defaults, fund gate badge — post-v1

## Phase 4: Operational Layer — NOT STARTED
Planetary hex map, operational actions, faction presence on planet, deploy-time UI

## Phase 5: Rules Engine — NOT STARTED
Combat rules engine per Total Warfare

## Phase 6: Tactical Layer — NOT STARTED (MegaMekParser only)
Hex combat map, unit representation, combat flow, tactical AI

## Future Work (post-v1)
Aerospace (interdiction, opposed landings), advanced narrative (contract chains, bounties, lostech, pirates), advanced contracting (breaches), advanced market (black market, factory-direct), advanced tech (XL/XXL engines, advanced gyros, lostech), non-mech units (vehicles/infantry), pilot abilities, passive XP, advanced politics, save/load, UI polish, data gaps

---

## Tests: 37 total (13 MTF parser + 22 market + 2 strategic gen), all passing
