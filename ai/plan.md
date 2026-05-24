# End of Greatness — AI Build Plan

## Phase 0: Foundation & Tooling

### P0.1 — Project Scaffold

- Create Godot 4 project with `project.godot`
- Set up directory structure:

  ```
  src/
    core/          # Singletons, autoloads, global state
    strategic/     # Star map, contracts, factions
    operational/   # Planetary hex map, deployment
    tactical/      # Hex combat, rules engine, MegaMek parsing
    ui/            # All UI scenes, themes, HUD
    data/          # Data classes, resource files, enums
    systems/       # Economy, personnel, repair, reputation
    utils/         # Helpers, grid math, random gen
  assets/
    fonts/
    themes/
    icons/
  tests/
  ```

- Create `addons/` for plugins (if any)
- Configure `autoload` singletons: `GameState`, `EventBus`, `TimeManager`, `DataManager`

### P0.2 — Data Formats & Resource System

- Supported tactical unit types: infantry, vehicle, and mech
- Define `.gd` resource classes for all domain entities:
  - `TacticalUnit.gd` (maps to/from MegaMek `.mtf` format)
  - `Component.gd`, `ComponentLocation.gd`
  - `Faction.gd`, `Contract.gd` — includes `minimum_tactical_unit_counts: Dictionary<String, int>` mapping `UnitType` enum values to minimum count required
  - `Personnel.gd` (with stats/traits/skills per A Time of War)
  - `OperationalUnit.gd`, `OrganizationalUnit.gd`
  - `StrategicUnit.gd` (player entity)
- Define `Quality` enum (F->A), `ComponentStatus` enum (Undamaged, Damaged, Destroyed), `UnitType` enum
- Import/export MegaMek `.mtf` files: parse `TacticalUnit` from `.mtf` text format
- Create `DataManager` autoload: loads all factions, units, components from JSON/CFG at startup

### P0.3 — Theme & i18n

- Create light/dark `Theme` resources in `assets/themes/`
- Set up i18n using Godot's `TranslationServer` + `.po`/`.csv` files in `assets/translations/`
- Create a `ThemeManager` autoload that toggles between themes and emits `theme_changed`
- All UI strings use `tr()` for i18n

### P0.4 — Event Bus

- Implement `EventBus` autoload using `Signal` bus pattern
- Define events: `contract_accepted`, `combat_started`, `time_tick`, `unit_damaged`, `reputation_changed`, `personnel_hired`, `theme_changed`, etc.
- Systems communicate through events; no direct coupling between layers

---

## Phase 1: Core Systems

### P1.1 — Time System (`TimeManager` autoload)

- Tracks in-game date starting 1 Jan 3025
- Strategic/Operational layers: `time_tick` emitted every N real seconds (configurable, auto-advance unless paused)
- `is_paused: bool`, `pause()` / `resume()` methods
- Tactical layer: pauses strategic time, uses `TacticalRound` counter instead
- Calendar: day/month/year, with support for BT lore dates (events trigger on specific dates)

### P1.2 — Economy System (`EconomySystem` autoload)

- Player's C-Bill balance (`current_balance`)
- `buy_item(resource, quantity, faction)` — if item is in local planetary inventory, purchase is instant; otherwise can be ordered from surrounding systems (within 1-2 jumps) with delivery time based on distance
- `sell_item(resource, quantity)` — instant sale to local market
- Tracks costs: personnel salaries (per day), maintenance (per component per day), transport costs
- Contract payments: `Contract.payout` per tick/day, salvage percentage; `salvage_type` determines form — `"exchange"` converts salvage share to C-Bills at contract-end; `"items"` grants the actual salvaged units/components as physical inventory; on contract completion, tally battle loss reimbursement — sum of C-Bill value of all tactical units and components destroyed during contract, plus ammunition expended, multiplied by `battle_loss_reimbursement_rate`, paid as lump sum alongside final payout
- `track_battle_loss(unit_or_component, c_bill_value)` called during tactical resolution to log destroyed units/components against the active contract; `track_ammo_expended(ammo_component, shots_fired, c_bill_per_shot)` called each time a weapon fires to accumulate expended-ammo cost for reimbursement
- Planetary market: sources inventory from factions present on the planet excluding target faction
- Market refresh logic per strategic tick, limited supply, price variation
- **Interstellar orders**: when buying equipment not available locally, the system searches friendly/neutral systems within jump range (max 30 ly per jump, up to 2 jumps), calculates travel time (jump recharge + transit), creates a `PendingDelivery` entry; player pays upfront, item arrives after delivery delay
- `PendingDelivery` queue: each entry has item, quantity, source_system, destination, eta_tick, completed flag; on each strategic tick, check if eta reached and transfer to player inventory; emit `delivery_arrived` event
- UI: market screen shows local stock and a "Surrounding Systems" tab with orderable items, delivery ETA, and price markup (surcharge for transport); active deliveries shown in a logistics panel with countdown timers
- **Peacetime expenses**: every strategic tick when no active contract is running (or when planet-side but outside contract coverage), automatically deduct:
  - Full personnel salaries (all roles: administrators, medics, technicians, crew)
  - Full component maintenance costs (all tactical units)
  - Berthing/docking fees for dropships and jumpships (if owned)
  - Daily overhead (supplies, rent, utilities — a flat per-tick cost scaling with organizational unit size)
- During an active contract, the employer's `base_coverage` percentage reduces these costs (e.g., 80% coverage means player pays 20% of salaries and maintenance)
- `get_daily_burn_rate() -> Dictionary` — returns breakdown of current per-tick costs (salaries, maintenance, berthing, overhead) and total; displayed in HUD so player always sees their cash drain rate
- Expenses are tallied and deducted in a single batch per tick; if balance goes negative, emit `funds_depleted` event triggering warnings and eventually forced liquidation events

### P1.3 — Reputation System (`ReputationSystem` autoload)

- `global_reputation: int` (Dirty/Controversial/Reliable/Honored/Elite)
- `faction_reputation: Dictionary<String, int>` per faction
- `modify_reputation(faction, delta, reason)` — emits `reputation_changed`
- Rebels/pirates/civilians track global only, not faction-specific
- Reputation thresholds gate: contract offers, market access, faction-unique equipment, event outcomes

### P1.4 — Personnel System (`PersonnelManager` autoload)

- `Personnel` resource: name, rank, stats (Body/Mind/Reflexes/etc), traits, skills, experience, role (Administrator/Medic/Technician/Crew)
- Relationships graph: `personnel_relationships: Dictionary<String, Array<Relation>>`
- Assign technicians to tactical units (time budget per day for repairs)
- Assign medics (patient capacity)
- Assign crew to exactly one tactical unit
- Hire/fire/promote/demote methods
- Personnel market generated per planet the player is on — pool of available candidates refreshed per strategic tick, drawn from planet population and local faction presence
- Hiring halls (planet facility) multiply candidate pool: if planet has a hiring hall, generate additional candidates per tick; hiring hall tier (local/regional/imperial) increases candidate count and quality (higher skills, rarer roles)
- Aging: birthdays tracked, death at old age (random roll past ~65)
- Injury tracking: `injure(personnel, severity)`, `heal(personnel, medic, time)` — medics heal over time

---

## Phase 2: Data & Configuration

### P2.1 — Faction Data

- `data/factions/` — JSON files per faction
- Fields: name, short_code, color, home_worlds, unique_units[], unique_components[], reputation_levels_gates, contracts_offered[]
- Faction relationships: `allies: [], enemies: []`
- Flag `is_rebel / is_pirate / is_civilian` for reputation tracking exclusions

### P2.2 — Component & Unit Data

- `data/components/` — JSON per component: name, tonnage, critical_slots, cost, tech_base, quality_range, repair_difficulty
- `data/units/` — MegaMek `.mtf` files for all stock units
- `data/unit_lists/` — faction-specific unit availability lists (era-appropriate, 3025 start)

### P2.3 — Star Map Data

- `data/starmap.json` — array of systems:
  - name, coordinates (x, y for 2D map), spectral_class (O, B, A, F, G, K, M, or custom for lore systems), planet list (name, gravity, atmosphere, temperature, population, industry_type, usilr_code: five per-attribute ratings (regressed/F/D/C/B/A, worst to best) — tech_sophistication, industrial_development, raw_material_dependence, industrial_output, agricultural_dependence (encoded per canonical USILR system), hpg_class: none/A/B/C/D, relay_station: bool, land_percent: 0–100 representing percentage of planet surface that is land; drives planetary hex map water hex generation)
- Jump distances: max 30 ly per jump
- Travel time: based on spectral class recharge time (standard for G-type: ~175 hours; hotter stars like A/B recharge faster, cooler K/M recharge slower)
- Systems owned by factions at game start, with change events per lore timeline
- Gameplay: HPG class and relay_station presence affect communication lag — higher HPG class means faster contract negotiation, event reporting, and reputation updates; planets with no HPG have multi-week communication delays; relay stations extend HPG network range to otherwise unreachable systems
- USILR code affects market availability (higher codes offer rarer/higher-tech components, units, and equipment), contract payment rates (higher codes pay more C-Bills), and salvage quality (lower codes yield less advanced salvage)

### P2.4 — Lore Timeline

- `data/timeline_events.json` — array of `{date: "3025-01-01", type: "ownership_change"|"faction_created"|"faction_destroyed"|"event", ...}`
- Loaded at init; `TimeManager` checks and fires events on matching dates

---

## Phase 3: Strategic Layer

### P3.1 — Strategic Map UI

- `ui/strategic/StarMap.tscn` — 2D node displaying star systems
- Pan and zoom (camera2D)
- Systems drawn as circles, colored by owner faction, with size/icon indicating spectral class
- Click system to show info panel: name, spectral_class, planets, current factions present, if player has units there
- Lines between systems for jump routes
- `StrategicMap.gd` controller

### P3.2 — Strategic Actions UI

- Sidebar or panel for:
  - Personnel management screen
  - Unit roster / repair bay screen
  - Market / shopping screen
  - Contract board
  - Organization tree view
  - Event log
- Each screen is a separate scene loaded into a `PanelContainer` content area

### P3.3 — Contract Generation

- `ContractGenerator.gd` singleton or utility
- Generates contracts based on:
  - Current date (era-appropriate activity types)
  - Region of space (border worlds = assault, interior = garrison)
  - Issuer faction needs
  - Player reputation tier
- Contract fields: issuer, target, planet, activity_type, duration, salvage_rate, salvage_type ("exchange" | "items"), c_bill_payment, transport_coverage, base_coverage, command_rights (independent/liaison/house/integrated), battle_loss_reimbursement_rate (percentage of C-Bill value of units/components destroyed during contract that employer will pay, e.g. 0–100), minimum_tonnage, minimum_tactical_unit_counts: Dictionary<String, int> (e.g., `{"Mech": 4, "Vehicle": 2}`) — the minimum number of each tactical unit type the player must deploy
- Generation logic: command_rights determined by employer faction military doctrine and contract urgency — desperate employers offer Independent; rigid militaries (House units) mandate House or Integrated; Liaison is the default for most contracts. Higher reputation may unlock better command rights from the same employer
- Gameplay effects of command_rights:
  - **Independent**: player has full operational freedom — deploy units anywhere on the planetary map, choose engagement timing, full salvage control per contract terms
  - **Liaison**: periodic event popups require player to "request approval" from employer liaison before major actions (planet-side deployment, accepting side contracts); liaison may refuse, forcing alternative plans; refusal chance decreases with higher reputation
  - **House**: employer AI controls operational-layer deployment of player units (assigns hexes); player retains tactical combat control; salvage and payout are predetermined; some employer units may accompany player forces
  - **Integrated**: player units become part of employer's formation — employer controls both operational deployment and can influence tactical objectives (e.g., "hold this hex for 3 turns"); player can still give move/fire orders but must comply with employer's battle plan or face contract penalties
- Generation logic: battle_loss_reimbursement_rate inversely correlated with c_bill_payment and salvage_rate — high-pay/high-salvage contracts offer less reimbursement; desperate employers (e.g., planetary assault against superior force) may offer full reimbursement
- Contracts appear on a "contract board" and expire after N ticks if not accepted

### P3.4 — Organization Management

- Tree view of player's Strategic -> Organizational -> Operational -> Tactical units
- Drag/drop or button-based reassignment
- Validation: no unit in multiple parents, unique paths
- Deployment: select organizational unit, select contract, assign to planet hex in operational layer
- Validation: before deploying, check that the selected organizational unit's tactical units meet the contract's `minimum_tactical_unit_counts` (by type) — reject deployment with an error listing shortfalls if not met
- Player may deploy more units than the minimum, but never fewer than any single type count
- Track which units are on which planet, which are in transit

### P3.5 — Strategic Events

- `StrategicEventGenerator.gd` — random events per tick
- Weighted by: location, faction relationships, reputation, current contracts
- Events presented as popup with choices and outcomes
- Examples: pirate raid on base, supply shipment delayed, faction requests assistance, personnel dispute

---

## Phase 4: Operational Layer

### P4.1 — Planetary Hex Map

- `ui/operational/PlanetaryMap.tscn` — hex grid (axial coordinates, `HexCell` scene per hex)
- `HexTile.gd` resource: terrain_type, faction_presence[], buildings[], player_units[]
- Terrain types: plains, forest, mountain, urban, water, desert, etc.
- Map size: configurable per contract (e.g., 20x20 hexes)
- Water hex count proportional to `land_percent` of the planet — `land_percent`% of hexes are land, `(100 - land_percent)`% are water; water hexes distributed as contiguous bodies (oceans, seas, lakes) using noise-based placement
- Fog of war: unexplored hexes hidden
- Travel time: moving organizational units across hexes costs days based on distance and terrain

### P4.2 — Operational Actions

- Unit deployment: select operational unit, deploy to hex (takes days, shown as progress bar)
- Encounter system: moving units may trigger enemy encounter or random event per hex
- Planetary market (same as strategic but limited to factions present)
- Repair facilities on planet (if available): repair units in friendly-controlled hexes
- Planetary event generation (similar to strategic but at operational scale)

### P4.3 — Faction Presence on Planet

- Target faction always present
- Issuer faction may have presence (per contract terms)
- Third-party factions (pirates, other mercenaries, corporations, rebels)
- Each faction controls certain hexes; control changes through combat deployment
- Visibility of faction units based on recon/scouting

---

## Phase 5: Flexible Rules Engine (Core)

### P5.1 — Rules Engine Architecture

- `rules/` directory with `.gd` rule files
- Each rule extends `RuleBase.gd`: `condition(context) -> bool`, `apply(context) -> void`
- `RulesEngine.gd` autoload: maintains lists of rules, evaluates all matching rules for a context
- Rule examples (for Total Warfare):
  - `ToHitCalculationRule.gd` — calculates target number based on range, movement, terrain, piloting
  - `DamageResolutionRule.gd` — applies damage to hit location table
  - `HeatRule.gd` — heat generation, dissipation, shutdown checks
  - `CriticalHitRule.gd` — critical hit determination and effects
  - `LineOfSightRule.gd` — LOS determination through hex terrain
  - `MovementRule.gd` — MP cost per terrain type, movement modifiers

### P5.2 — Rule Configuration

- `house_rules.json` — enable/disable rules, adjust parameters (e.g., "use floating crits: true", "heat scale: standard/quick")
- UI: `ui/settings/RulesConfig.tscn` — checkboxes and sliders for house rules
- Rules are hot-reloadable for development

### P5.3 — CombatContext

- `CombatContext.gd` — passed to rules: contains attacker, defender, weapon, range, terrain, modifiers, random seed
- Rules read from and write to context
- Context provides deterministic random for reproducibility (RNG seeded per battle)

---

## Phase 6: Tactical Layer

### P6.1 — Tactical Map

- `ui/tactical/TacticalMap.tscn` — hex grid, each hex = 30m diameter
- 30-60 hexes per side, configurable
- Terrain from operational layer hex (the hex that contained the encounter)
- Map features: elevations, woods (light/heavy), water (depth levels), buildings, rubble, pavement
- `TacticalMap.gd` — manages hex grid, unit placement, fog of war, terrain effects

### P6.2 — Unit Representation

- Tactical units placed on map as sprites/icons
- `TacticalUnitNode.gd` — state: facing, movement points remaining, heat, damage status, ammo remaining
- Unit info panel: component status diagram (paper doll), weapon list, heat scale
- Movement: click-to-move with path preview (cost per hex highlighted)
- Facing: units have a facing direction, torso twist for mechs

### P6.3 — Combat Flow

- Initiative phase: `InitiativeRule` evaluates
- Movement phase: alternating unit movement per BT rules
- Weapon attack phase: select weapon, select target, `ToHitCalculationRule -> DamageResolutionRule -> CriticalHitRule`
- Physical attack phase: punches, kicks, charges, DFA
- Heat phase: `HeatRule` applied
- End phase: ammo tracking, component status updates
- Repeat until one side is destroyed, retreats, or objective is met

### P6.4 — MegaMek Unit Integration

- Parser: `MegaMekParser.gd` — parses `.mtf` format
- Maps MegaMek data to `TacticalUnit` resource
- Preload stock units from `.mtf` files in `data/units/`
- Custom units: save edited units back to `.mtf` format for persistence

### P6.5 — AI Opponent

- `TacticalAI.gd` — simple AI for enemy units
- Priority: attack weakest target, focus fire, use terrain cover, retreat when damaged
- Can be expanded with strategy patterns (aggressive, defensive, cautious)

---

## Phase 7: UI & UX

### P7.1 — Main Menu

- `ui/menus/MainMenu.tscn`
  - New Game (select start date, difficulty)
  - Load Game
  - Settings (theme toggle, language, house rules, audio)
  - Credits

### P7.2 — HUD

- `ui/hud/HUD.tscn` — persistent overlay
  - Date/time display
  - C-Bill balance
  - Pause/play button
  - Current layer indicator (Strategic/Operational/Tactical)
  - Alert notifications (event popups)

### P7.3 — Modal System

- `ui/common/Modal.tscn` — reusable modal dialog
  - Configurable: title, body text, choices, outcome display
  - Used for events, combat prompts, confirmation dialogs
  - History log of past modals

### P7.4 — Information Panels

- Unit info panel: paper doll, weapon list, stats, crew assignment, quality
- Personnel panel: stats, skills, traits, assignment, relationships
- Contract panel: terms, duration, rewards, minimum_tonnage, minimum_tactical_unit_counts (displayed as a list e.g., "4 Mechs, 2 Vehicles required"), with a compliance indicator showing whether the currently selected organizational unit meets each requirement
- Faction panel: reputation, available units/market, relationships

---

## Phase 8: Persistence & Save/Load

### P8.1 — Save System

- `SaveManager.gd` autoload
- `save_game(slot_name)` — serialize game state to file using Godot's `ResourceSaver` with binary serialization (`.res` with compression); avoid plain JSON for large payloads
- `load_game(slot_name)` — deserialize using `ResourceLoader` with threaded loading option for large saves
- **Efficiency strategies**:
  - Split save data into hot (frequently changed: balance, date, active contract state, unit positions) and cold (rarely changed: faction data, starmap, unit templates, personnel relationships) — hot data saved every time, cold data saved only when dirty or via periodic full save
  - Use Godot's `ConfigFile` or `Resource` format with `ResourceFormatSaver` for binary size; compress with Deflate
  - Lazy deserialization: load hot data immediately on game start; defer cold data (e.g., full starmap, faction histories, personnel records) to background loading after main menu
  - Prune transient tactical state: tactical map grids and per-hex terrain are regenerated from the operational hex seed, not saved — only save the seed, unit damage state, and position within the tactical map
  - Event log: cap at N entries (e.g., 500), oldest pruned; archived to cold file
  - Personnel records: batch-save as array of resource references rather than inline objects to share template data
  - Save file size target: < 5 MB for a 50-hour campaign; benchmark and profile if exceeded
  - **Multiple autosaves on configurable schedule**: autosave creates a new slot on a rotating basis — user configures slot count (default 5) and interval (real-time minutes or in-game days); oldest slot is overwritten when all slots are filled; slot names follow a pattern (`autosave_1`, `autosave_2`, ...) with timestamp and current contract/location in metadata; autosaves are listed in the load menu alongside manual saves and are distinguishable by an "Autosave" badge
- Save data includes: date, all units (with damage state), all personnel, contracts active, reputation, balance, operational map seeds, RNG state, command_rights state for active contracts

### P8.2 — Save UI

- `ui/menus/SaveLoadMenu.tscn` — list of save slots with date, play time, preview info; autosave entries shown with an "Autosave" badge and the autosave schedule metadata (slot number, interval)
- Load game: confirm dialog, load state, reset all systems
- Autosave configuration accessible from settings screen: slot count spinner (1–20), interval selector (every N real-time minutes or every N in-game days)

---

## Phase 9: Integration & Polish

### P9.1 — Layer Transitions

- Strategic -> Operational: when organizational unit is deployed to a contract planet, switch to Operational layer view
- Operational -> Tactical: when deployed unit encounters enemy force in a hex, generate tactical map from hex terrain, position units, start combat
- Tactical -> Operational: after combat resolution, apply damage/repair state, return to operational map
- Operational -> Strategic: when contract concluded or player exits

### P9.2 — Event System Integration

- Strategic events: random per tick, weighted by context
- Operational events: triggered by unit movement across hexes, faction AI actions
- Tactical events: triggered by combat (head hits, ammo explosions, pilot injuries)
- All events piped through `EventBus` for UI updates

### P9.3 — Lore Accuracy

- Timeline events checked every tick
- Faction ownership of systems changes per lore schedule
- Faction creation/destruction at correct dates
- `LoreChecker.gd` — validates and enforces lore constraints

---

## Phase 10: Testing & QA

### P10.1 — Unit Tests

- Test rules engine: `RulesEngineTest.gd` — verify rule evaluation and chaining
- Test MegaMek parser: parse known `.mtf`, verify component locations and stats match
- Test economy: buying/selling balance, contract payout math
- Test reputation: verify threshold gating
- Test combat: deterministic seed testing for hit resolution

### P10.2 — Integration Tests

- Full contract flow: generate -> accept -> deploy -> fight -> resolve -> payout
- Save/load roundtrip: save mid-combat, load, verify state
- Theme toggle: ensure no un-themed elements

### P10.3 — Manual Testing Checklist

- Each UI screen: displays data, accepts input, updates state
- Layer transitions: smooth, no state leaks
- Event popups: correct choices trigger correct outcomes
- Edge cases: 0 C-Bills, empty roster, no contracts available

---

## Implementation Order Recommendation

### For AI Agent Teams

**Agent Team A — Phase 0 + 1 (Foundation)**
Build scaffold, resource classes, autoloads, event bus, theme/i18n, time system, economy, reputation, personnel manager.

**Agent Team B — Phase 2 + 3 (Data + Strategic)**
Build all data files, star map, strategic UI, contract generation, organization management, strategic events.

**Agent Team C — Phase 4 + 5 (Operational + Rules Engine)**
Build planetary hex map, operational actions, faction presence on planet, flexible rules engine with Total Warfare rules.

**Agent Team D — Phase 6 (Tactical)**
Build tactical map, unit representation, combat flow, MegaMek parser, AI opponent.

**Agent Team E — Phase 7 + 8 (UI + Save)**
Build main menu, HUD, modals, info panels, save/load system, settings.

**Agent Team F — Phase 9 + 10 (Integration + QA)**
Wire layers together, event system, lore accuracy, tests, polish.

---

## Key Files Summary

| File                               | Purpose                          |
| ---------------------------------- | -------------------------------- |
| `src/core/GameState.gd`            | Central game state resource      |
| `src/core/EventBus.gd`             | Signal-based event communication |
| `src/core/TimeManager.gd`          | Calendar, ticks, pause           |
| `src/systems/EconomySystem.gd`     | C-Bills, market, costs           |
| `src/systems/ReputationSystem.gd`  | Global + faction reputation      |
| `src/systems/PersonnelManager.gd`  | Hire/fire/injure/heal            |
| `src/systems/RulesEngine.gd`       | Flexible combat rules engine     |
| `src/systems/MegaMekParser.gd`     | Parse .mtf files                 |
| `src/systems/ContractGenerator.gd` | Generate contracts               |
| `src/systems/TacticalAI.gd`        | Enemy tactical AI                |
| `src/systems/SaveManager.gd`       | Save/load serialization          |
| `src/data/*.gd`                    | Resource class definitions       |
| `src/strategic/StarMap.gd`         | Strategic layer controller       |
| `src/operational/PlanetaryMap.gd`  | Operational layer controller     |
| `src/tactical/TacticalMap.gd`      | Tactical layer controller        |
| `src/ui/`                          | All UI scenes and scripts        |
| `data/factions/*.json`             | Faction definitions              |
| `data/units/*.mtf`                 | MegaMek unit files               |
| `data/starmap.json`                | Star system coordinates          |
| `data/timeline_events.json`        | Lore timeline                    |
| `house_rules.json`                 | Configurable rule toggles        |
