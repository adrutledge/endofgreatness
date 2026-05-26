# Implementation Status

Generated: 3025-05-26 (updated per commit 9b74e4c)
Plan: `ai/plan.md`

---

## Phase 0: Foundation & Tooling — COMPLETE

### P0.1 — Project Scaffold
- [x] `project.godot` (Godot 4.6)
- [x] Directory structure: src/{core,strategic,operational,tactical,ui,data,systems,utils}, assets/{fonts,themes,icons}, tests, addons
- [x] Makefile with build/run/test/lint/export/clean targets
- [x] Autoloads: GameState, EventBus, TimeManager, DataManager

### P0.2 — Data Formats & Resource System
- [x] Resource classes: TacticalUnit, Component, ComponentLocation, Faction, Contract, Personnel, OperationalUnit, OrganizationalUnit, StrategicUnit, Trait, enums
- [x] Enums: Quality (F-A), ComponentStatus, UnitType (INFANTRY/VEHICLE/MECH)
- [x] MegaMekParser: parse_mtf() and parse_blk()
- [x] DataManager: loads all data at _ready()

### P0.3 — Theme & i18n
- [x] Dark/light theme .tres files
- [x] en.po translation file
- [x] ThemeManager autoload with toggle + theme_changed signal
- [x] tr() usage throughout all UI files (~120 translatable strings)
- [~] en.po translation file with all keys
- [~] Only English locale exists (ready for additional locales)

### P0.4 — Event Bus
- [x] EventBus autoload with 20 signals (added month_started, inventory_changed, dispatch_completed, auto_reorder_triggered, funds_low_for_reorder)
- [x] All systems communicate through events

---

## Phase 1: Core Systems — COMPLETE (minor gaps)

### P1.1 — Time System
- [x] Calendar starting 3025-01-01, day/month/year with leap year
- [x] _process-driven time_tick, pause/resume
- [x] Tactical mode (pauses strategic time, TacticalRound counter)
- [x] Timeline event checking on matching dates

### P1.2 — Economy System
- [x] C-Bill balance (StrategicUnit.current_balance)
- [x] buy_item/sell_item
- [x] PlanetaryMarket with faction inventory, refresh, price variation
- [x] InterstellarOrderManager: 30ly jumps, 2-jump range, spectral recharge
- [x] PendingDelivery queue, delivery_arrived event
- [x] Contract settlement: payout, salvage (exchange + items), battle loss reimbursement
- [x] track_battle_loss, track_ammo_expended, record_ammo_expended (end-of-engagement)
- [x] track_enemy_loss with CO quality/condition/recovery_chance
- [x] process_salvage_after_engagement — per-engagement salvage with recovery rolls
- [x] salvage_type="items" — physical components to player_inventory
- [x] Damaged salvage prefix "Damaged " in inventory, repairable through normal queue
- [x] Daily burn rate breakdown (salaries, maintenance, berthing, overhead)
- [x] Monthly bills, base_coverage during contracts
- [~] buy_item missing faction parameter from plan
- [x] Transport cost line item in daily burn rate (zero default — no Dropship/Jumpship ownership)
- [x] UnitTransportManager with CO abstract unit transport costs (5,000 CSB/ton DropShip, 10,000 CSB/ton/jump JumpShip)
- [x] Unit transport cost methods: single unit, fleet, one-way, round-trip, between named systems
- [x] Logistics panel UI with deliveries, local/remote market, unit purchasing
- [x] Flat per-jump transport cost (5,000 CSB/jump) for remote orders, config toggle
- [x] spares_config.json with auto-reorder, per-unit inventory, transport cost toggles
- [x] Reorder-to-minimum: dispatches from global stores first, then local market, then remote
- [x] Berthing fees waived by design (no player dropship/jumpship ownership in this version)

### P1.3 — Reputation System
- [x] global_reputation + faction_reputation
- [x] Tiers: Dirty/Controversial/Reliable/Honored/Elite
- [x] modify_reputation with faction/rebel/pirate/civilian handling
- [x] Reputation threshold gating

### P1.4 — Personnel System
- [x] Personnel resource with AToW attributes, skills, traits
- [x] Roles: HR, LOGISTICAL, TRANSPORT, COMMAND, MEDIC, DOCTOR, TECHNICIAN, ASTECH, CREW
- [x] Assign technicians, doctors (with patient capacity), crew
- [x] Abstract crew count for vehicles/infantry
- [x] Hire/fire/promote/demote
- [x] Candidate generation with hiring hall bonuses
- [x] Aging (birthdays) and death rolls (past 65)
- [x] injure/heal personnel
- [x] PersonnelRelation resource with typed relationships, valence, strength
- [x] Relationship CRUD: add_relationship, get_relationships, get_relationship_with, has_relationship, remove_relationship
- [x] Starting relationship generation in StrategicUnitGenerator (FRIENDSHIP, WINGMAN, LOVER, DISLIKE, RIVAL)
- [x] Candidate generation auto-refreshed per tick (cached pool, _refresh_candidates on date_changed)
- [x] Healing is time-progression based (healing_days_remaining, tick-based, admin-modified)
- [x] Secondary role support on Personnel (secondary_role, get_effective_skill halves secondary skill)
- [x] Administration skill time efficiency: doctors reduce healing time (admin * 2 days off), techs get more repair hours (base 8 + admin * 2)
- [x] Originating faction, home system, home planet on Personnel
- [x] Hidden relationship flags: interested_in_relationship, interested_in_children, biological_role
- [ ] Pilot abilities (terrain, mech affinity, weapon spec, conditional bonuses) — planned
- [ ] Skill-level gating for ability generation — planned
- [ ] Gender preference flag (preferred_gender) for relationship generation — planned
- [ ] External lovers from deployment/travel, children accompany unit — planned
- [ ] Education system for child characters (version 2) — planned
- [ ] Passive XP gain from assigned roles — planned

---

## Phase 2: Data & Configuration — COMPLETE (minor gaps)

### P2.1 — Faction Data
- [x] 12 JSON files in data/factions/
- [x] Fields: name, short_code, color, home_worlds, unique_units/components, reputation gates, contracts, allies/enemies, rebel/pirate/civilian flags

### P2.2 — Component & Unit Data
- [x] 263 component JSON files in data/components/
- [x] Hundreds of .mtf/.blk unit files in data/units/
- [x] 12 RAT JSON files in data/rat/
- [x] RATParser.gd for parsing and rolling
- [x] Fixed critical_slots in gyro.json (2→4) and 78 engine_*.json (3→6) to match BT conventions
- [~] Missing TechManual construction fields on component JSONs (engine_rating_required, gyro_compatible, etc.)

### P2.3 — Star Map Data
- [x] starmap.json with systems, coordinates, spectral class, planets, USILR, HPG, land_percent
- [x] owner_faction field on all 47 starmap systems
- [x] ComStar faction with Terra ownership
- [x] DataManager.load_starmap reads owner_faction; all faction derivation uses owner_faction first, falls back to home_worlds
- [~] HPG class and USILR gameplay effects not implemented

### P2.4 — Lore Timeline
- [x] timeline_events.json with ownership_change, faction_created, event types
- [x] Loaded at init, fired by TimeManager on matching dates
- [~] faction_destroyed type not present in data

---

## Phase 3: Strategic Layer — MOSTLY COMPLETE

### P3.1 — Strategic Map UI
- [x] StarMap.tscn with pan/zoom camera
- [x] Systems drawn colored by faction, sized by spectral class
- [x] Click system → info panel
- [x] Jump route lines (30ly)

### P3.2 — Strategic Actions UI
- [x] Sidebar with screens: PersonnelManagement, UnitRoster, LogisticsPanel, ContractBoard, OrganizationManagement, EventLog, MechLab
- [x] Sidebar auto-pop-out on cursor proximity (30px edge margin), 300px wide, 0.15s slide animation

### P3.3 — Contract Generation
- [x] ContractGenerator.gd with 6 activity types, duration, payment scaling, command rights, min unit counts

### P3.4 — Organization Management
- [x] OrganizationManager.gd: hierarchy validation, deployment checks, min unit counts

### P3.5 — Strategic Events
- [x] StrategicEventGenerator.gd with 7 event types, cooldowns, weighted selection

### P3.6 — TechManual Construction, Refit & Validation
- [x] P3.6.1: validate_tm() on TacticalUnit (weight, slots, armor, engine, gyro, heat sinks, ammo)
- [x] P3.6.2: RefitManager with B-E classification, cost/labor, parts sourcing
- [x] P3.6.3: MechLab Designer (component grid, TM validation, component browser)
- [x] P3.6.4: Repair/maintenance/salvage per Campaign Operations; inventory item repair
- [x] P3.6.5: MechLab UI with Paper Doll (color-coded crit slots, multi-slot borders, rear-facing (R) display), Components (filtered by type/location/tech, engine calculator), Refit, and Customize tabs
- [x] MTF parser: dedup with smart splitting, splittable weapons (AC/20), rear-facing detection, validation warnings
- [x] MTF parser refactored: extracted _populate_component_from_def, _set_component_defaults, _finalize_slot_splitting helpers; removed dead code (_load_suspension_factors, _get_jump_jet_weight, _is_engine_component_name)
- [x] P3.6.6: Campaign Operations customization rules (per-component B-E class, CO time/cost/TN, single avg TN skill roll, facility gating, quality mismatch, customization log)
- [x] Customization workflow: MechLab Customize tab with change list, risk assessment, facility check, apply with single skill roll; failure extends time by 50%, no part destruction
- [x] Refit-in-progress guard: prevents starting refit or customization while unit already has active work

### V1 Design — Home Base & Logistics
- [x] Player home base is **Galatea** (mercenary hub, full tech facilities)
- [x] Global inventory (`GameState.player_inventory`) is physically on Galatea
- [x] Units not deployed to a contract are stationed at Galatea
- [x] `home_base` field on `StrategicUnit` (default "Galatea")
- [x] Starting `current_planet` set to Galatea regardless of faction origin
- [x] Deployed units can buy from local market of their contract planet (planet selector in LogisticsPanel market tab)
- [x] Galatea market populated at startup with all non-MRB/CS factions; repopulates monthly via month_started signal
- [x] Market scarcity tiers: armor/ammo=abundant, heat sinks/actuators/jump jets=easy, ACs/missiles/MGs/flamers=medium, lasers/PPCs=slightly hard, engines/gyros/cockpit/electronics=rare
- [x] Lazy rebuild pattern (mark_for_rebuild / _ensure_fresh) for market and contract board
- [ ] Remote sourcing (InterstellarOrderManager) searches from Galatea
- [ ] Tech facility level on Galatea = "advanced" (no facility gating for repairs/refits)
- [ ] Deployed units' `current_planet` tracks their contract planet

### P3.7 — Initial Strategic Unit Generator
- [x] StrategicUnitGenerator.gd
- [x] RATParser.gd
- [x] Starting float 20d6×1M (floor 10M)
- [x] 12 mechs via RAT, quality F-C, minor damage variation
- [x] Full personnel: pilots, commander/XO/lance commanders, admin, doctor, techs, astechs, medics, crew
- [x] Starting inventory: ammo, armor, spares
- [x] Organization: Strategic → Org → Operational(lance)
- [x] NewGameDialog.tscn with faction picker
- [x] Tests: test_strategic_unit_generator.gd

### P3.8 — Operational Unit Inventory Assignment (mostly complete)
- [x] spares_config.json with all settings (data/config/spares_config.json)
- [x] Dispatch UI in logistics panel (sends from global stores to unit cache)
- [x] Reorder-to-minimum dispatches from global first, then buys/orders
- [x] InventoryManager autoload: dispatch_to_unit, recover_from_unit, recover_all_from_unit, track_in_transit
- [x] deployment_cache as @export var on OperationalUnit (replaced dynamic set/get)
- [x] Auto-reorder timer (per-tick check in InventoryManager, gated by auto_reorder_enabled config)
- [x] In-transit tracking (pending dispatch arrivals)
- [x] Operational logistics difficulty: config-gated (logistics_difficulty_enabled), check via has_logistics_difficulty()
- [x] Independent command market check: can_access_employer_market(), disabled by default
- [x] month_started signal decouples monthly refresh triggers from tick handlers
- [x] Lazy refresh pattern documented in plan for all periodic rebuilds
- [x] Campaign toggles: aerospace/vehicles/infantry disabled by default
- [x] Tests: test_market_population.gd (22 tests: scarcity tiers, Galatea population, lazy rebuild)
- [ ] Allocation UI with per-component pickers at deploy time (UI deferred)
- [ ] Auto-allocate defaults button (UI deferred)
- [ ] Fund gate badge on HUD (signal emitted, badge UI deferred)

---

## Phase 4-10: NOT STARTED or PARTIAL

### Phase 4 — Operational Layer (not started)
### Phase 5 — Rules Engine (not started)
### Phase 6 — Tactical Layer (P6.4 MegaMekParser only)
### Phase 7 — UI & UX (P7.1 MainMenu + P7.2 HUD/status badges planned)
### Phase 8 — Save/Load (not started)
### Phase 9 — Integration & Polish (partial)
### Phase 10 — Testing & QA (MTF parser tests + generator tests + market tests)

---

## Tracking for Future Sessions

When resuming, run these commands to check current state:
```
# Check latest commits
git log --oneline -5

# Run tests
make test

# Check for unstaged changes
git status
```

Key autoloads (defined in project.godot):
- GameState, EventBus, TimeManager, DataManager, ThemeManager
- EconomySystem, ReputationSystem, PersonnelManager, RefitManager, UnitTransportManager, InventoryManager

Key next work items by phase:
- P3.8: Deploy-time allocation UI, auto-allocate defaults (UI deferred)
- P4: Planetary hex map and operational actions
- P5: Rules engine architecture
- P6.1-3,6.5: Tactical map, combat flow, AI
- P7.2: HUD status badges (funds_low_for_reorder signal ready, badge UI deferred)
- P8: Save/load system
