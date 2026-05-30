# End of Greatness — AI Build Plan

## Core Gameplay Loop (v1)
Form a unit → take a contract → deploy to the contract planet → explore the planetary hex map → engage in tactical combat(s) as objectives are encountered → complete the contract → repeat. Everything in Phases 0-6 serves this loop. Features that don't directly feed this loop are deferred to post-v1.

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

## Phase 4 — Operational Layer
- Procedurally generated planetary hex map: player explores the contract planet, moving units across hexes
- Exploration reveals objectives, enemies, salvage, and leads into tactical engagements
- Multiple tactical combats may be necessary to complete a single contract
- Faction presence on planet
- Deploy-time allocation UI, auto-allocate defaults

## Phase 5 — Rules Engine
- Flexible combat rules engine per Total Warfare

## Phase 6 — Tactical Layer
- Procedurally generated hex combat map, unit representation, combat flow
- Tactical mission types: convoy defense, convoy ambush, assault, infiltration, recon in force, raid, breakthrough, holding action, extraction, objective assault, assassination, assassination defense
- Tactical AI with strategy patterns per side: non-combatant, convoy, aggressive, defensive, ambush, ambushed, pursuit, withdrawal, objective-guard

## Future Work (post-v1)

### Aerospace
- Aerospace assets (owned DropShips, fighters), interdiction of supply lines
- Opposed planetary landings, escort/convoy mechanics

### Advanced Narrative (P3.3 expansion)

- Contract chains with branching, NPC persistence, major lore events
- Organic narrative cluster: bounty board, bounties on player, pirate interference, LosTech rumor tracking
- Mech gladiatorial games (Solaris VII): non-contract mech duels and team battles with prize money, reputation gains, and unique NPC rivals; separate career tracking from mercenary contracts
- Star League Survey Corps (SLSC) discovery: SLSC systems are hidden from the starmap (prefix filtering) but can be discovered through lostech rumor tracking; each SLSC system contains a Star League-era research outpost, cache, or facility with rare components, unique units, or lore data; discovery requires rumors, navigation data (coordinates decoded from SLSC designation), and a deep-periphery expedition outside normal jump routes

### Advanced Contracting

- Breach system (employer + employee, severity levels, MRB sanctions)
- Contract types expanded with emergency/duration variance
- **Disputed and contested systems** (future — depends on Advanced Market & Logistics): planets with contested ownership (D(DC/LC), etc.) or those in the process of changing hands have reduced market supplies and skewed contract generation (assault, raid, defense, garrison with restrictive command rights or urgent/emergency contracts); different timeline eras have different disputed systems; contested status may be permanent (hardcoded D(...) codes) or ephemeral — systems near a timeline ownership change are treated as contested for the duration of the event only (e.g., the Fourth Succession War causes contested status across entire border regions for its duration, then resolves to the post-war ownership); if too few hardcoded D(...) systems exist in a given era, systems near a recent ownership change (within ~5 years) are treated as contested, ensuring a minimum number of active conflict zones at any date
- **Side-taking in conflicts** (future): the player does not automatically take a side simply by being active during a conflict; a side is only taken by participating in conflict-specific contract chains; switching sides between contracts while off-planet is merely frowned upon (minor reputation hit), but switching sides during an active exclusivity period from a multi-contract chain is a significant breach (worse than quitting a chain early); if the player's reputation with a faction drops below a threshold (through any means before or during the conflict), that faction and its allies will not offer contracts; conversely, unreliable units may be shut out of major conflict contracts entirely — only emergency contracts remain available, reflecting the employer's desperation; emergency contracts serve as a high-risk path to dig out of a bad reputation — they pay well and provide reputation gains on completion, but carry wider difficulty variance and a higher chance of mission failure; faction reputation gates which contracts are offered and which markets are accessible, with opposing-faction access revoked for the event duration
- **Contract pool by influence range** (future): the pool of available contracts is populated by interests within influence range of the player's current planet; during active conflicts, local belligerents generate contracts directly; outside of conflicts (except disputed worlds), contracts come from interests within a moderate radius; contract type affects range — garrison, cadre, and riot duty are most likely close to or within a state's borders, assault extends further, raid extends furthest with the longest drop-off; each X points of influence (based on faction size, proximity, reputation) generates one contract, rounded down — sufficiently distant interests get zero. Certain factions have different or broader ranges: ComStar operates everywhere regardless of borders, pirates appear in any system with low owner control, and mercenary brokers may offer contracts from any faction with sufficient reputation, reflecting their unconventional reach

### Advanced Market & Logistics

- Black markets, factory-direct purchases via reputation
- Logistics personnel daily check limits

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
- Medals and decorations (fruit salad): personnel earn medals for notable accomplishments — X kills in a single mission, surviving Y damage in one engagement, participating in a major lore conflict (Fourth Succession War, etc.), serving as an instructor (Training skill for their lance over Z months), extracting from a losing battle, or disabling a superior foe without destroying it; each medal grants a permanent buff (stat/skill bonus, trait, or ability unlock) and is displayed as a ribbon/medal icon on the personnel sheet; thresholds are mission-level (e.g., "3+ kills in one mission") not aggregate, rewarding exceptional moments; MRB may issue standard medals, while faction-specific decorations unlock with reputation; a character's medal rack ("fruit salad") is visible in their detail view, providing at-a-glance history

### Advanced Politics

- War crimes tracking, MRB sanctions, bounty hunters
- Faction border shifts, economic spheres, ComStar intrigue

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

### Timeline System Data
- Replace monolithic `timeline_events.json` with a directory `data/events/YYYY/` — one JSON file per year, each a small array of events for that year; DataManager loads and merges all files at startup; keeps diffs readable and allows per-year manual additions
- Add `hidden_dates` array to each system in starmap data: list of `[start_year, end_year]` ranges during which the system is uninhabited, undiscovered, or otherwise hidden from the map
- When TimeManager date advances, systems whose current date falls within a `hidden_dates` range are filtered out of the starmap display (same as abandoned/unmapped)
- This enables systems that are founded later (e.g., Periphery colonies established after 3025) or abandoned temporarily (e.g., during Succession Wars) to appear/disappear dynamically
- Parser updates: `hidden_dates` can be derived from SUCKIT ownership data — if a system has `U` (uninhabited) in a year range, that range becomes a `hidden_dates` entry
- **Edge case — stranded forces**: if a player has forces on a system entering a `hidden_dates` range, use the lazy refresh signal pattern (`month_started`) to emit a `stranded_forces_warning` signal with the affected unit names and system; the HUD warning badge picks this up (following the same pattern as `funds_low_for_reorder`); the player has until the next month tick to evacuate via transit or contract — after that, the system is hidden but forces remain accessible only via the unit roster (marked with a "STRANDED" badge); forces cannot be deployed on contracts from a hidden system; an evacuation order generates an emergency transit event

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

Autosaves default to the last day of each month (configurable interval). Multiple rotating slots with metadata (date, contract, location).

### Save File Self-Containment (constraint)

A save file must restore all player campaign state on a fresh install (balance, inventory, units, personnel, contract chain progress). Invariant game data shipped with every install (component defs, faction data, RAT tables, timeline events, NPC archetypes) is assumed identical and does NOT need to be duplicated in the save. NPC persistence uses archetype reference + seed + limited flags (relationship, alive/dead, hostility), keeping saves lightweight while remaining self-contained for campaign state.
