# End of Greatness — AI Build Plan

## Phase 0: Foundation & Tooling

### P0.1 — Project Scaffold
- Godot 4 project with `project.godot`, directory structure, `Makefile`
- Autoloads: GameState, EventBus, TimeManager, DataManager, ThemeManager
- Systems: EconomySystem, ReputationSystem, PersonnelManager, RefitManager, UnitTransportManager, InventoryManager

### P0.2 — Data Formats & Resource System
- Resource classes: TacticalUnit, Component, ComponentLocation, Faction, Contract, Personnel, OperationalUnit, OrganizationalUnit, StrategicUnit, enums
- MegaMekParser: parse_mtf(), parse_blk()
- DataManager: loads factions, components, units, starmap, timeline

### P0.3 — Theme & i18n
- Dark/light theme resources, ThemeManager autoload
- All UI strings use `tr()` (~120 keys, en.po current)

### P0.4 — Event Bus
- EventBus autoload with signals for all system communication

---

## Phase 1: Core Systems

### P1.1 — Time System
- Calendar starting 3025-01-01, day/month/year, pause/resume, tactical mode
- Timeline event checking
- `month_started` signal for monthly refresh triggers

### P1.2 — Economy System
- C-Bill balance, buy/sell, planetary market with scarcity tiers (armor/ammo abundant → engines/gyros rare)
- Interstellar orders (30ly jumps, 2-jump range, spectral recharge)
- PendingDelivery queue, contract settlement, salvage (exchange + items), battle loss reimbursement
- Ammunition tracking (end-of-engagement net calculation)
- Daily burn rate, monthly bills, base_coverage during contracts
- Per-jump transport cost, UnitTransportManager
- Auto-reorder timer (per-tick, gated by config)
- In-transit tracking, dispatch/recover inventory system
- Galatea market initializes at startup, repopulates monthly via lazy refresh
- Salvage processed per engagement with CO recovery rolls
- Contract payouts calculated per month
- Upfront payment percentage (configurable)

### P1.3 — Reputation System
- Global reputation (MRB) + faction reputation
- Tiers, thresholds gating contracts and market access

### P1.4 — Personnel System
- AToW attributes, skills, traits, roles (HR, LOGISTICAL, MEDIC, TECHNICIAN, etc.)
- Assign technicians/doctors/crew, abstract crew for vehicles/infantry
- Hire/fire/promote/demote, candidate generation with hiring hall bonuses
- Aging, death rolls, injury/heal with admin skill modifiers
- Relationships: typed bonds with valence, CRUD operations

---

## Phase 2: Data & Configuration

### P2.1 — Faction Data
- 12 JSON files with short_code, color, home_worlds, reputation gates, contracts, allies/enemies, rebel/pirate/civilian flags

### P2.2 — Component & Unit Data
- 263 component JSONs, hundreds of .mtf/.blk unit files, 12 RAT JSONs
- Fixed critical_slots: gyro (4), all engines (6), cockpit (1)

### P2.3 — Star Map Data
- 47 systems with coordinates, spectral class, planets, USILR, HPG, owner_faction

### P2.4 — Lore Timeline
- timeline_events.json, checked on matching dates

---

## Phase 3: Strategic Layer

### P3.1 — Strategic Map UI
- StarMap with pan/zoom, systems colored by faction, jump route lines

### P3.2 — Strategic Actions UI
- Sidebar with all screens, auto-pop-out on cursor proximity

### P3.3 — Contract Generation
- 6 activity types, duration scaling, payment, command rights, min unit counts
- Contract duration by type (garrison/cadre ~year, assault/pirate hunting 1-6mo, raids vary, emergency days-weeks)
- Contract chains (future — advanced narrative): multi-part story arcs with branching, NPC persistence, major lore event participation (4th Succession War, etc.)

### P3.4 — Organization Management
- Hierarchy validation, deployment checks, min unit counts

### P3.5 — Strategic Events
- Random events per tick weighted by location/faction/reputation/contracts

### P3.6 — TechManual Construction, Refit & Validation
- P3.6.1: validate_tm() on TacticalUnit (weight, slots, armor, engine, gyro, heat sinks, ammo)
- P3.6.2: RefitManager with B-E classification, cost/labor, parts sourcing, refit kits
- P3.6.3: MechLab Designer with real-time TM validation, component browser
- P3.6.4: Repair/maintenance/salvage per Campaign Operations, inventory item repair
- P3.6.5: MechLab UI with paper doll, components, refit, customize tabs
- P3.6.6: Customization per CO rules (per-component class, time/cost/TN, facility gating)

### P3.7 — Initial Strategic Unit Generator
- 20d6×1M starting float (floor 10M), 12 mechs via RAT, full personnel, tests

### P3.8 — Operational Unit Inventory Assignment
- spares_config.json, InventoryManager autoload, deployment_cache on OperationalUnit
- Dispatch UI, auto-reorder timer, in-transit tracking
- Logistics difficulty gating (config), independent command market restriction (disabled)

---

## Future Work (post-v1)

### Advanced Narrative (P3.3 expansion)
- Contract chains with branching, NPC persistence, major lore events
- Organic narrative cluster: bounty board, bounties on player, pirate interference, LosTech rumor tracking

### Advanced Contracting
- Breach system (employer + employee, severity levels, MRB sanctions)
- Contract types expanded with emergency/duration variance

### Advanced Market & Logistics
- Black markets, factory-direct purchases via reputation
- Logistics personnel daily check limits

### Aerospace & Opposed Insertion
- Aerospace assets (owned DropShips, fighters), interdiction of supply lines
- Opposed planetary landings, escort/convoy mechanics

### Advanced Tech (post-3025/Lostech)
- XL/XXL/Compact/Light engine slot placement (per side torso)
- Advanced gyros (XL=6, Compact=2, Heavy=3) with weight multipliers
- Ferro-fibrous, Endo Steel, double heat sinks, Clan tech
- Lostech acquisition via rumor tracking

### Non-Mech Units (Vehicles, Infantry, Aerospace)
- Full vehicle/infantry/aerospace support (gated by campaign toggles, all off by default)
- Per-type construction rules, crew, transport

### Advanced Personnel
- Pilot abilities (terrain, mech affinity, weapon spec)
- Passive XP gain from assigned roles
- Preferred gender flag, external lovers, children, education

### Advanced Politics
- War crimes tracking, MRB sanctions, bounty hunters
- Faction border shifts, economic spheres, ComStar intrigue

### Tactical & Rules Engine
- Total Warfare combat rules, hex map, line of sight, heat, ammo
- Tactical AI with strategy patterns

### UI Polish
- HUD status badges (funds low, auto-reorder suspended, injured unattended)
- Color blind accessibility palette
- Deploy-time allocation UI, auto-allocate defaults

### Save/Load
- Autosave rotation, manual saves, save metadata

### Data Gaps
- USILR/HPG gameplay effects
- faction_destroyed timeline events
- TM construction fields on component JSONs

---

## Design Notes & Architectural Patterns

### Signal Down, Call Up
Systems emit signals downward (to listeners); UI/reactors call methods upward on systems.

### Lazy Refresh Pattern
`mark_for_rebuild()` + `_ensure_fresh()` dirty-flag for periodic refreshes (market, contracts, personnel pool). Avoids frame spikes during tick processing.

### Campaign Toggles
`aerospace_enabled`, `vehicles_enabled`, `infantry_enabled` in `spares_config.json`. Current defaults: all false (mech-only).

### Logistics Personnel Check Limits (future)
Each LOGISTICAL-role personnel gets limited checks/day; large units need multiple staff.

### Color Blind Accessibility (future)
Color blind friendly palette option for paper doll and HUD.

### Save System Pattern (future)
Multiple autosaves on rotating schedule with metadata.
