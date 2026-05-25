# Implementation Status

Generated: 3025-05-25 (updated per commit 13f4b10)
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
- [~] tr() usage in UI — limited, many hardcoded strings remain
- [~] Only English locale exists

### P0.4 — Event Bus
- [x] EventBus autoload with 15 signals
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
- [~] No transport cost line item
- [~] No logistics panel UI for pending deliveries
- [~] Berthing fees always 0 (no dropship/jumpship tracking)

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
- [~] personnel_relationships declared but no Relation resource or population
- [~] Candidate generation not auto-refreshed per tick
- [~] Healing is instant, not time-progression

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
- [~] Missing TechManual construction fields on component JSONs (engine_rating_required, gyro_compatible, etc.)

### P2.3 — Star Map Data
- [x] starmap.json with systems, coordinates, spectral class, planets, USILR, HPG, land_percent
- [~] No owner_faction field on systems (derived from Faction home_worlds)
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
- [x] Sidebar with screens: PersonnelManagement, UnitRoster, MarketUI, ContractBoard, OrganizationManagement, EventLog

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
- [x] P3.6.5: MechLab UI with Refit/Design/Repair tabs
- [/] P3.6.6: Campaign Operations customization rules (planned in plan, not implemented)

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

### P3.8 — Operational Unit Inventory Assignment (planned, not implemented)
- [ ] Allocation UI with per-component pickers
- [ ] Auto-allocate defaults
- [ ] spares_config.json
- [ ] Auto-reorder with fund gate
- [ ] Deduction/Recovery/In-transit tracking

---

## Phase 4-10: NOT STARTED or PARTIAL

### Phase 4 — Operational Layer (not started)
### Phase 5 — Rules Engine (not started)
### Phase 6 — Tactical Layer (P6.4 MegaMekParser only)
### Phase 7 — UI & UX (P7.1 MainMenu only)
### Phase 8 — Save/Load (not started)
### Phase 9 — Integration & Polish (partial)
### Phase 10 — Testing & QA (MTF parser tests + generator tests)

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
- EconomySystem, ReputationSystem, PersonnelManager

Key next work items by phase:
- P3.8: Implement inventory allocation UI and auto-reorder
- P4: Planetary hex map and operational actions
- P5: Rules engine architecture
- P6.1-3,6.5: Tactical map, combat flow, AI
- P8: Save/load system
