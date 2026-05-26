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
- Create `Makefile` with targets: `build`, `run`, `test`, `lint`, `export` for common development and automation tasks

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
- Contract payments: `Contract.payout` per tick/day, salvage percentage; `salvage_type` determines form — `"exchange"` converts salvage share to C-Bills per engagement; `"items"` grants the actual salvaged units/components as physical inventory per engagement; on contract completion, tally battle loss reimbursement — sum of C-Bill value of all tactical units and components destroyed during contract, plus ammunition expended, multiplied by `battle_loss_reimbursement_rate`, paid as lump sum alongside final payout
- **Salvage per engagement**: after each tactical engagement, `process_salvage_after_engagement(contract)` is called to salvage from the contract's `salvage_pool` (populated by `track_enemy_loss()` during combat); two branches:
  - **"exchange"**: total C-Bill value of eligible salvage × `salvage_rate`, paid as cash
  - **"items"**: player receives physical components into `GameState.player_inventory`; each component entry has `quality` (F–A) and `condition` (undamaged/damaged) per CO; damaged components are prefixed with `"Damaged "` in inventory and require repair (P3.6.4) before use
- **Per CO salvage mechanics** (see also P3.6.4):
  - `track_enemy_loss(component_name, c_bill_value, tonnage, difficulty, quality, is_destroyed, source_unit, location_blown_off)` called during tactical resolution for each destroyed enemy component
  - Components from a destroyed location (`is_destroyed = true`) are irrecoverable, with one exception: `location_blown_off = true` applies when a **limb** (arm or leg) is blown off by a critical hit, OR when an arm is blown off because its attached side torso lost all internal structure; components in that limb are scattered on the field and ARE recoverable even if the mech leaves
  - Surviving components get a random condition: ~66% damaged, ~33% undamaged
  - `recovery_chance = tech_skill_factor × difficulty_modifier × quality_factor × condition_modifier` — using Regular (skill 4) as baseline for auto-calculation; per CO, each component rolls independently; failed rolls leave no salvage
  - `recovery_hours = max(0.5, component_tonnage × 0.5)` × difficulty multiplier × 1.5 if damaged; consumed from available tech hours (all unassigned techs + astech pool × 4 hours)
  - `salvage_rate` limits total C-Bill value recoverable per engagement; highest-value items are prioritized
  - Unrecovered (skipped or failed-roll) items remain in the salvage pool for future engagements; successfully recovered items are removed
  - Emits `salvage_processed` event with per-engagement result for UI display
- `track_battle_loss(unit_or_component, c_bill_value)` called during tactical resolution to log destroyed player units/components against the active contract for reimbursement
- **Ammunition expended tracking**: ammunition usage is calculated at **end of engagement** rather than per-shot during combat to avoid double-counting:
  - The tactical layer records each unit's starting ammo per ammo type at engagement start
  - **Surviving units**: `shots_fired = starting_shots - remaining_shots` → reimbursed for shots actually fired
  - **Destroyed units**: all ammo on a destroyed unit is reimbursed as a total loss (the full `starting_shots` count, treating all of it as expended); the employer compensates for the lost ammunition
  - **Blown-off limbs are not reimbursed**: ammo or components in a limb blown off by a critical hit are NOT reimbursed — they enter the contract's salvage pool as recoverable physical items instead; no component is ever double-counted (reimbursed AND salvaged)
  - The tactical layer calls `record_ammo_expended(contract_id, ammo_type, shots_fired, c_bill_per_shot)` once per ammo type per engagement with the net figure: surviving units' expended + destroyed units' total, minus any ammo in blown-off limbs (which is not reimbursed)
- Planetary market: sources inventory from factions present on the planet excluding target faction
- Market refresh logic per strategic tick, limited supply, price variation
- **Interstellar orders**: when buying equipment not available locally, the system searches friendly/neutral systems within jump range (max 30 ly per jump, up to 2 jumps), calculates travel time (jump recharge + transit), creates a `PendingDelivery` entry; player pays upfront, item arrives after delivery delay
  - **Flat per-jump transport cost**: shipping small items uses commercial cargo shipping (shared DropShip manifest on scheduled runs), not a dedicated vessel; cost is a flat `TRANSPORT_COST_PER_JUMP` (default 5,000 C-Bills) per jump, added to the component's base cost — significantly cheaper than unit transport because no dedicated JumpShip or DropShip is required; `cost_per_unit = base_component_cost + TRANSPORT_COST_PER_JUMP × jumps_needed`
  - `remote_transport_cost_enabled: bool` (default true) — when false, remote orders are priced at base component cost with no transport surcharge; configuration in `spares_config.json` under `data/config/`
- `PendingDelivery` queue: each entry has item, quantity, source_system, destination, eta_tick, completed flag; on each strategic tick, check if eta reached and transfer to player inventory; emit `delivery_arrived` event
- UI: market screen shows local stock and a "Surrounding Systems" tab with orderable items, delivery ETA, and price markup (surcharge for transport); active deliveries shown in a logistics panel with countdown timers
- **Aerospace interdiction** (future): when aerospace assets (owned DropShips, escort fighters, or hired naval protection) are implemented, off-world orders during appropriate contract types (assault, raid, pirate hunting) may come under attack en route; player must decide whether to escorts convoys or risk losing shipments; interception chance, convoy strength, and attacker composition determined by contract difficulty, employer commitment, and local faction naval presence; lost shipments emit a `shipment_destroyed` event with partial insurance recovery (configurable percentage); adds a strategic layer to logistics — shipping through hostile space requires calculation of risk vs. just-in-time supply
- **Opposed planetary insertion** (future): when aerospace assets are implemented, the initial landing on a contract planet may be contested; for assault, raid, and similar high-intensity contract types, the player's DropShips may face defensive fire or fighter interception during approach; outcome depends on orbital superiority, DropShip armor/point-defense, escort fighter screen, and the contract's threat level; a failed or costly insertion could damage or destroy carried units and personnel before they reach the surface, delay deployment, or force a landing at a less advantageous LZ; the employer may provide covering fire or a diversion (reducing opposition) depending on commitment level and command rights; adds pre-battle stakes to the operational layer and rewards investment in aerospace protection even in a ground-centric command
- **Campaign toggles for complexity** (design note): provide campaign-level toggles to disable each domain independently (`aerospace_enabled: bool`, `vehicles_enabled: bool`, `infantry_enabled: bool` in `spares_config.json`); when disabled: no contract will require that unit type, no aerospace interdiction/insertion events fire, and the game treats the player's force as mech-only or mech+the enabled types; this allows players who dislike managing aerospace assets, vehicle crews, or infantry platoons to opt out without missing content; **current version defaults**: all three to `false` to keep scope manageable (mech-only campaign)
- **Lazy refresh pattern** (architectural note): for any system that needs periodic full refreshes (market inventory, personnel candidate pool, contract board), use a `mark_for_rebuild()` + `_ensure_fresh()` dirty-flag pattern rather than rebuilding synchronously on a timer; the system marks itself dirty on the trigger event (e.g., first-of-month tick), and the actual rebuild happens lazily when the data is next accessed; this avoids frame-time spikes during tick processing and means refreshes are free if the player never opens the relevant UI; implement `_ensure_fresh()` as a guard at the top of every public data-access method
- **Peacetime expenses**: every strategic tick when no active contract is running (or when planet-side but outside contract coverage), automatically deduct:
  - Full personnel salaries (all roles: administrators, medics, technicians, crew)
  - Full component maintenance costs (all tactical units)
  - Berthing/docking fees for dropships and jumpships (if owned)
  - Daily overhead (supplies, rent, utilities — a flat per-tick cost scaling with organizational unit size)
- During an active contract, the employer's `base_coverage` percentage reduces these costs (e.g., 80% coverage means player pays 20% of salaries and maintenance)
- `get_daily_burn_rate() -> Dictionary` — returns breakdown of current per-tick costs (salaries, maintenance, berthing, overhead) and total; displayed in HUD so player always sees their cash drain rate
- Expenses are tallied and deducted in a single batch per tick; if balance goes negative, emit `funds_depleted` event triggering warnings and eventually forced liquidation events

### P1.3 — Reputation System (`ReputationSystem` autoload)

- `global_reputation: int` (Dirty/Controversial/Reliable/Honored/Elite) — represents standing with the **Mercenary Review Board (MRB)**, the Inner Sphere's central mercenary regulatory body
- `faction_reputation: Dictionary<String, int>` per faction
- `modify_reputation(faction, delta, reason)` — emits `reputation_changed`
- Rebels/pirates/civilians track global only, not faction-specific
- Reputation thresholds gate: contract offers, market access, faction-unique equipment, event outcomes
- **MRB fees**: the Mercenary Review Board takes a percentage cut of all above-the-board contract payments (standard rate 5–10%, configurable); this is deducted automatically at contract settlement and represents the cost of MRB oversight, dispute resolution, and bond certification
- **Off-the-books operations** (future advanced missions development): some employers may offer contracts outside MRB oversight (no MRB fee, no reputation impact, but no dispute resolution if the employer stiffs the player); uncontracted actions (raiding a planet without a contract, piracy) are always off-the-books and risk MRB sanctions if discovered; this ties into the war crimes and politics system
- In later versions under advanced politics, global reputation may also account for war crimes committed (civilian casualties, use of prohibited weapons, attacks on medical facilities, etc.) as reported to the MRB, triggering sanctions, bounty hunters, or faction-wide hostility

### P1.4 — Personnel System (`PersonnelManager` autoload)

- `Personnel` resource: name, rank, stats (Body/Mind/Reflexes/etc), traits, skills, experience, role (Administrator/Medic/Technician/Crew)
- Relationships graph: `personnel_relationships: Dictionary<String, Array<Relation>>`
  - Relationships have a type (Marriage, Lover, Wingman, Dislike, Rival, Sibling, Parent/Child, etc.) and a valence (positive/negative)
  - **Wingman**: preferred partner to accompany in combat; when wingmen fight in the same unit or adjacent hexes, both receive a small gunnery/piloting bonus; if one is killed, the survivor takes a morale penalty for a duration
  - **Marriage / Lover**: positive bond; if one is killed or injured, the other takes a larger and longer morale penalty; married couples may have children (see reproduction — version 2)
  - **Dislike / Rival**: negative bond; personnel with negative relationships suffer small penalties when assigned to the same unit, and events may trigger conflict between them
  - **Hidden flags** on each `Personnel` resource, not visible to the player:
    - `interested_in_relationship: bool` — whether the character is open to forming new romantic relationships
    - `interested_in_children: bool` — whether the character is open to having children
    - `biological_role: String` — `"father"` or `"mother"` independent of the character's displayed/apparent gender; determines which character carries a pregnancy when a couple has children; this is a hidden stat that may differ from visible presentation
    - `preferred_gender: String` — `"male"`, `"female"`, `"both"`, or `""` (empty); indicates which visible gender the character is attracted to; empty means neither (asexual/aromantic), `"both"` means attracted to either; this is a hidden flag that influences relationship generation and event outcomes; may change over time through events
  - **Procreation, children, and family relationships** (version 2 — advanced character tracking):
    - Children are generated as new `Personnel` with `CHILD` role, age 0, born to the couple after a configurable gestation period; they age and can eventually be recruited as crew or other roles when they come of age
    - **External relationships**: during deployment on a contract planet or during interstellar travel, a character may take a lover from outside the unit (generated as a one-off event); the new partner joins the unit as a non-combatant `CIVILIAN` and travels with the unit thereafter
    - **Children accompany the unit**: any children of unit personnel (whether born into the unit or from prior relationships) travel with the unit as `CHILD`-role personnel; they do not take up crew slots, require no salary, and age normally
    - **Education** (version 2): when education is implemented, `CHILD`-role characters may be placed in educational tracks (local schooling on Galatea, remote tutoring, apprentice programs) that influence what skills and traits they develop as they age into adult roles
    - **Family relationships**: children start with positive relationships with parents and siblings (Parent/Child, Sibling); rarely (small random chance) a negative sibling relationship may generate at birth, representing an innate rivalry
    - **Relationship evolution**: family relationships can grow or change in response to events — shared positive events strengthen bonds, while separation, conflict, or traumatic events may strain them
    - **Deployment strain**: a parent repeatedly deployed while the child remains on Galatea (or vice versa) increases the chance of the relationship turning negative over time; extended together-time (parent and child both with the unit) has the opposite effect
  - Relationships are initially empty at game start; they develop through events, shared combat, and shared assignments over time
  - Each `Personnel` resource additionally tracks: `originating_faction: String` (the faction the character originally came from), `home_system: String`, and `home_planet: String` — these may differ from the player's current faction/planet and are used for event generation, loyalty checks, and background flavor
- Assign technicians to tactical units (time budget per day for repairs)
- Assign doctors (patient capacity, configurable per doctor, default 20)
- Assign crew to exactly one tactical unit; where a vehicle or infantry unit requires multiple crew, handle all crew beyond the first (pilot/driver) as an abstract count rather than individual tracked personnel
- Hire/fire/promote/demote methods
- Personnel market generated per planet the player is on — pool of available candidates refreshed per strategic tick, drawn from planet population and local faction presence
- Hiring halls (planet facility) multiply candidate pool: if planet has a hiring hall, generate additional candidates per tick; hiring hall tier (local/regional/imperial) increases candidate count and quality (higher skills, rarer roles)
- Aging: birthdays tracked, death at old age (random roll past ~65)
- Injury tracking: `injure(personnel, severity)`, `heal(personnel, medic, time)` — medics heal over time
- **Battlefield injury generation** (version 1 — abstract): when a unit takes damage in combat, crew may be injured with a probability proportional to damage taken; injury severity is a simple integer (1–5) representing mild to critical, with no per-type tracking; healing time = `severity × BASE_DAYS` modified by doctor skill and facility quality
- **Battlefield injury generation** (version 2 — detailed): injury type is determined by crew role and damage source:
  - Mech pilot (cockpit hit, ammo explosion, fall from destroyed leg): concussion, spinal injury, burns, fractures
  - Vehicle crew (vehicle destroyed, motive hit): blunt trauma, burns, shrapnel wounds
  - Infantry (direct fire, area effect): shrapnel, gunshot wounds, blast injuries
  - Any crew (unit destroyed while occupied): critical injuries, long-term disability chance
- **Healing time extrapolation** (version 2 — detailed): base healing time derived from injury severity and type, extrapolated from modern trauma recovery with future-tech adjustments:
  - BattleTech medical tech (3025 era) is roughly modern-to-advanced: severe injuries take weeks to months, minor injuries take days to weeks
  - Higher-tech planetary medical facilities (USILR code) reduce healing time: each tier above baseline shaves a percentage off recovery time, representing access to advanced diagnostics, myomer therapy, and enhanced pharmaceuticals
  - Doctor's `Administration` and `surgery_general` skills further modify recovery time
  - A dedicated medical bay on a DropShip or planetary base provides a flat reduction vs field medicine
  - **Advanced prosthetics**: permanently injured limbs or organs may be replaced with advanced prosthetics (myomer-enhanced limbs, synthetic organs, cybernetic eyes); prosthetics restore functionality but may impose small skill penalties or bonuses depending on quality; high-quality prosthetics (Clan, Star League lostech) can match or exceed natural capability; cost and availability scale with planetary tech level (USILR code) and faction relationship
- **Secondary roles**: personnel may hold a primary and secondary role (e.g., a doctor with secondary HR); the secondary role's duties are performed at reduced efficiency (e.g., half the `Administration` skill contribution when acting as secondary HR, or half patient capacity when a doctor is secondary)
- **Administration skill affects time efficiency**: `Administration` skill for doctors reduces healing time (per-point percentage reduction); for technicians, reduces repair/refit/salvage time (same mechanic); the skill is checked against the complexity of the work — simple tasks get full benefit, complex/experimental tasks get reduced benefit
- **Passive XP gain**: characters build experience points through practice at their assigned roles passively each tick, in addition to active use (combat, skill checks, events); a pilot assigned to a mech gains passive `gunnery`/`piloting` XP, a technician gains `tech_*` XP, a doctor gains `surgery` XP, etc.; passive gain is slower than active use but provides a steady baseline for character growth over time
- **Pilot abilities** (per A Time of War traits and special pilot abilities):
  - Abilities grant conditional modifiers to gunnery, piloting, or other rolls in specific contexts
  - **Terrain-specialist** abilities: reduce or ignore movement/accuracy penalties in specific terrain types (woods, water, rough, urban, etc.)
  - **Mech affinity**: pilot gains bonuses when piloting a specific chassis or weight class (e.g., "Jenner Ace" or "Heavy Mech Specialist")
  - **Weapon specialization**: reduced to-hit penalties or heat benefits with specific weapon classes (PPCs, autocannons, missiles, lasers, pulse, etc.)
  - **Conditional combat abilities**: bonuses during specific tactical situations — ambush, flanking, called shots, indirect fire, etc.
  - **Non-combat abilities**: bonuses to repair speed, salvage recovery, negotiation, or logistics when assigned to non-combat roles
  - Each ability has a `condition` (expression or function evaluated against combat context) and a `modifier` (flat or percentage bonus/penalty)
  - Stored on the `Personnel` resource as an `Array[PilotAbility]` (new resource class); abilities are assigned at generation (weighted by faction/background) and occasionally through events or promotion
  - Combined with existing `Traits` system: some traits gate which abilities a pilot can learn, and abilities may grant additional trait-like effects outside combat
  - **Skill-level gating**: a character's skill levels (gunnery, piloting, tactics, etc.) also gate which abilities may generate — e.g., a pilot with gunnery 4+ cannot generate "Sharpshooter" (requires gunnery 3+); a medic with low `Administration` cannot generate "Efficient Triage" (requires Admin 4+); this prevents low-skill characters from rolling high-tier abilities at generation

---

## Phase 2: Data & Configuration

### P2.1 — Faction Data

- `data/factions/` — JSON files per faction
- Fields: name, short_code, color, home_worlds, unique_units[], unique_components[], reputation_levels_gates, contracts_offered[]
- Faction relationships: `allies: [], enemies: []`
- Flag `is_rebel / is_pirate / is_civilian` for reputation tracking exclusions

### P2.2 — Component & Unit Data

- `data/components/` — JSON per component: name, tonnage, critical_slots, cost, tech_base, quality_range, repair_difficulty, heat_generated, ammo_type, allowed_locations[], minimum_tech_rating
- Component JSON extended with fields needed for TechManual construction: `engine_rating_required`, `gyro_compatible`, `structure_type`, `armor_points_per_ton`, `suspension_factor_override`
- `data/units/` — MegaMek `.mtf` files for all stock units
- `data/rat/` — Xotl d1000 Random Assignment Tables (RATs) for mech selection by faction/era (3025); Inner Sphere houses (FedSuns, Lyran, FWL, DC, Capellan), Periphery states (Magistracy, Taurian, Outworlds, Marian), Inner Sphere General, and Mercenary; faction-specific unit lists omitted — no faction-unique units in 3025
  - **TODO**: Manually enter the correct Xotl RAT data from the official 3028-3057 PDF (sourced from bg.battletech.com forums); the auto-generated data on disk has been stripped of post-3025 mechs but the d1000 distributions and 'Salvage:' entries need manual verification against the PDF tables to ensure accuracy; cross-reference with Faction Lists in the PDF for correct Availability ratings per faction

### P2.3 — Star Map Data

- `data/starmap.json` — array of systems:
  - name, coordinates (x, y for 2D map), spectral_class (O, B, A, F, G, K, M, or custom for lore systems), planet list (name, gravity, atmosphere, temperature, population, industry_type, usilr_code: five per-attribute ratings (regressed/F/D/C/B/A, worst to best) — tech_sophistication, industrial_development, raw_material_dependence, industrial_output, agricultural_dependence (encoded per canonical USILR system), hpg_class: none/A/B/C/D, relay_station: bool, land_percent: 0–100 representing percentage of planet surface that is land; drives planetary hex map water hex generation)
  - `owner_faction: String` — the faction that controls this system at game start; drives map coloration, market faction presence, and contract generation context
- Jump distances: max 30 ly per jump
- Travel time: based on spectral class recharge time (standard for G-type: ~175 hours; hotter stars like A/B recharge faster, cooler K/M recharge slower)
- Systems owned by factions at game start, with change events per lore timeline
- Faction home worlds are tracked by the `home_worlds` field on each Faction; ownership changes are handled by the lore timeline; advanced faction politics (alliances, border shifts, economic spheres of influence) is a future version feature, not part of this phase
- USILR code affects market availability (higher codes offer rarer/higher-tech components, units, and equipment), contract payment rates (higher codes pay more C-Bills), and salvage quality (lower codes yield less advanced salvage)
- HPG class and relay_station gameplay (communication lag, contract negotiation speed, reputation update delays) is slated for a future advanced communications phase; this version treats all systems as having baseline communication for simplicity

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
- **Upfront payment**: a configurable percentage of total `c_bill_payment` is paid on contract acceptance; `upfront_payment_pct: float` (0.0–1.0, default 0.25) in `spares_config.json`; the remainder is paid per tick and on completion per existing payout logic; this represents hiring fees, advance supply funds, and bond costs per source material; expose as a difficulty setting in the UI later (higher % = easier start on a new contract, lower % = harder financial management)
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
- **LosTech rumor tracking** (future advanced organic narrative development):
  - Rumors of Star League lostech caches, forgotten facilities, and functional relics circulate through the Inner Sphere
  - Players may encounter rumors through events (drunken pilot in a bar, ancient map fragment, captured enemy intelligence, ComStar interdiction rumors)
  - Each rumor tracks: location (system/planet), expected tech type (weapon, component, facility, intact mech), reliability (vague whisper → verified coordinates), and source
  - Players may choose to investigate rumors by deploying to the rumored location (non-contract deployment) — this may lead to exploration, combat with rival seekers, or triggering multi-stage event chains
  - Uncovering lostech yields rare components, unique units, or permanent facility upgrades; this is the primary method of acquiring lostech when it is added to the game
  - Rumor reliability decays over time if not investigated; competing factions may also follow the same rumors, creating race-against-time scenarios

### P3.6 — TechManual Construction, Refit & Validation

#### P3.6.1 — Construction Rules Engine (`TechManualRules.gd`)

- TechManual is the authoritative source for all construction validation rules
- Autoload singleton implementing all core BT construction rules per the TechManual
- **Tonnage validation**: total component tonnage must not exceed unit tonnage + 0.5t buffer; engine tonnage derived from rating × weight class multiplier per TM engine table
- **Critical slot limits per location**: per TM rules — Center Torso 12, Side Torso 10/12, Arms 12 (6 per arm), Legs 6, Head 3/6; vehicle locations differ (turret, front, sides, rear, body)
- **Armor point limits**: max armor per location = internal structure × 2 (mech); total armor points must not exceed `ceil(tonnage × armor_points_per_ton)` where Standard=16, Ferro-Fibrous=32, Light Ferro=28, Heavy Ferro=21, etc.
- **Engine rating constraints**: engine_rating must be multiple of 5; for mechs, engine_rating = walk_mp × tonnage (mapped through standard engine rating table); engine type (Standard/Light/XL/XXL/Compact) affects critical slots, weight, and cost per TM
- **Gyro compatibility**: gyro mass = `ceil(engine_rating / 100) × multiplier`; gyro type (Standard/XL/Compact/Heavy/None) determines critical slots and mass
- **Heat sink adequacy**: base 10 free heat sinks from engine; each additional heat sink weighs 1t; total dissipation must cover alpha-strike heat (weapon heat + jump heat); excess heat sink count above dissipation capacity flagged as warning
- **Internal structure type**: Standard/Endo Steel/Reinforced/Composite each have distinct weight multipliers and critical slot costs
- **Armor type**: Standard/Ferro-Fibrous/Light Ferro/Heavy Ferro/Reflective/Reactive/etc. each with distinct weight per point and critical slot costs
- **Tech base & level consistency**: validates all components share compatible tech_base (Inner Sphere / Clan) and tech_rating (Introductory/Standard/Advanced/Experimental); mixed-tech builds flagged with appropriate penalties per TM optional rules
- **Unit type-specific constraints**:
  - Mechs: require gyro, cockpit, engine, internal structure, armor; jump jet weight varies by weight class (0.5t ≤55t, 1t 56-85t, 2t >85t); max jump MP = `floor(engine_rating / tonnage)`
  - Vehicles: require engine, structure, armor, control systems; power amplifier adds 10% of energy weapon tonnage (min 0.5t); suspension factor in engine rating per TM table (Tracked=0, Wheeled=20, Hover/VTOL/WiGE vary by tonnage)
  - Infantry: squad/platoon size limits per TM, armor kit types per TacOps
  - Battle Armor: BA-specific construction rules (manipulator mounts, AP weapons mount, mission pod)
- **Weapon & ammo constraints**: ammo must match weapon type (LRM20 → Ammo LRM20); each weapon needs at least one ton of compatible ammo; CASE required for explosive ammo in torso on XL/XXL-engine mechs (per optional rule)
- **Heat & movement correlation**: walk/run MP capped per engine rating table; jump MP limited by weight class (max 8 for assault, 10 for heavy, 12 for medium, 14 for light)
- **Power budget**: vehicles track power consumption vs. engine output; energy weapons, active probes, ECM all consume power; insufficient power = weapon cannot fire

#### P3.6.2 — Refit System (`RefitManager` autoload)

- Campaign Operations is the authoritative source for all refit rules, including classification (B–E class determination), time, cost, and labor
- **Refit** = changing a unit from one variant to another on the same chassis (e.g. MAD-3R → MAD-3D)
- Per-unit `chassis_name` and `model_name` fields on `TacticalUnit`, populated by MTF/BLK parsers
- `DataManager.get_variants_for_chassis(chassis)` returns all known variants of a given chassis
- Component diff calculation: compare current unit's components vs target variant's components by name → list of components to remove and add
- **TechManual refit classification** (B → E):
  - **Class B (Standard)**: same location, same tech base, tonnage diff < 0.5t — e.g., swapping Medium Laser for Medium Laser of same type
  - **Class C (Complex)**: same tech base, different location OR tonnage diff ≥ 0.5t — e.g., moving a weapon from arm to torso
  - **Class D (Major)**: different tech base — e.g., swapping Standard armor for Ferro-Fibrous, or swapping IS for Clan weapon
  - **Class E (Chassis)**: changing chassis-defining components (engine, internal structure, gyro, cockpit) — complete rebuild preserving only chassis name
- Refit cost per TM: `component_base_cost × CLASS_COST_PCT[class]` where B=5%, C=10%, D=20%, E=30%; plus 50% markup for remote-sourced parts
- Refit labor per TM: `tonnage × CLASS_HOURS[class]` per component added + 0.5 × tonnage per component removed; B=1.0h/t, C=2.0h/t, D=5.0h/t, E=50.0h/t; minimum 4 hours
- Consumes daily from the unit's assigned technician pool (`PersonnelManager.get_unit_repair_budget()`)
- **Refit kits**: instead of sourcing each component individually, a refit is ordered as a single **refit kit** — a pre-packaged bundle containing all components, wiring harnesses, and instructions needed for the conversion; the kit cost is the sum of all component costs at a discounted rate (configurable, default 90% of individual component total); a single purchase transaction and a single delivery ETA apply; the refit kit provides a TN bonus per its class (B=-2, C=-1, D/E=0) representing the benefit of pre-assembled and tested parts
- **Refit target game rule** (config `refit_canon_only: int`, default 1):
  - **1** (canon only): refits can only target canon variants (those from `.mtf`/`.blk` files in `data/units/`); custom variants saved by the player (in `data/units/custom/`) are excluded from the refit target list
  - **0** (allow all): custom variants are also available as refit targets, allowing the player to refit to any previously designed custom variant
  - **-1** (first-time customization): the first time a given custom variant is applied to a unit, it must be done as a customization (P3.6.6) — individual component changes with the customization workflow; after that first successful implementation, the variant design is recorded (stored with its component list in `data/units/custom/`) and future instances of the same custom variant may be refit to using the standard refit workflow (with a refit kit and the refit skill roll)
  - The reasoning: refit kits are only canonically produced for canon variants; setting -1 represents the in-universe process of developing a "field refit kit" for a custom design after proving it works on the first unit
- Refit work flow:
  1. Player selects a Mech and a target variant in the MechLab UI
  2. System calculates component diff, classifies the refit per TM rules, and determines refit kit cost and availability
  3. Player reviews the kit pricing, TM refit class badge, cost estimate, labor estimate, and refit kit TN bonus
  4. Player confirms → single payment deducted for the refit kit; delivery ETA for the kit
  5. Kit delivery phase: waiting for the kit to arrive (single delivery ETA)
  6. Labor phase: once the kit is on-hand, assigned technicians consume their daily hour budget against the refit
  7. When hours reach 0: single skill roll (highest TN + kit bonus + facility modifiers); on success the variant swap is applied; on failure hours extend by 50% and the roll is retried

#### P3.6.3 — Custom Design / Construction (MechLab Designer)

- **Custom variant designer**: player creates a custom unit by modifying components on an existing chassis or building from a blank chassis template
- UI: per-location component grid (head, CT, LT, RT, LA, RA, LL, RL for mechs; turret/front/sides/rear/body for vehicles), drag-and-drop or button to add/remove/replace components
- **Real-time TM validation**: as player adds/removes components, `TacticalUnit.validate_tm()` runs continuously, displaying live errors and warnings (overweight, slot overflow per location, missing engine, incompatible tech base, heat deficit, armor over limit, ammo without matching weapon)
- **Construction restrictions per TechManual**:
  - Available components filtered by tech_base, tech_rating, unit type compatibility, and current planet's tech level (USILR code)
  - Critical slot usage per location shown with progress bars (e.g., "CT: 8/12 slots used"); slot overflow = red error
  - Tonnage meter showing used/free tonnage; free tonnage for armor shown separately
  - Armor allocation: player assigns armor points per location using sliders (front/back for torso, separated per arm/leg); total, used, and maximum shown; layout follows TM armor distribution rules
  - Heat budget: current heat dissipation vs alpha-strike heat generation; deficit shown in red
  - Ammo tracking: auto-assigns one ton of matching ammo per weapon; player can add extra ammo tons; orphan ammo (no matching weapon) shown as warning
- **Component browser**: searchable/filterable list of all known components from `DataManager.component_defs`; filters by type (weapon/ammo/armor/engine/gyro/structure/electronics), tech base, tech rating, weight class, allowed locations
- **Cost tracking**: real-time C-Bill cost of current design using `TacticalUnit.calculate_tm_cost()` (chassis cost + component costs × 1.05 markup); compared against current balance
- **Save custom variant**: custom variants saved as `.mtf`-compatible data in `data/units/custom/` directory; available in the refit UI for future refits; includes metadata: designer name, date created, custom tag
- **Construction prerequisites**: custom construction requires appropriate facility level (repair bay + mech bay at minimum, advanced tech requires advanced facility); higher-tech components (Clan, Experimental) require higher planetary tech level or faction relationship

#### P3.6.4 — Campaign Operations Repair, Maintenance & Salvage

- Campaign Operations is the authoritative source for all repair, maintenance, and salvage rules; overrides TM values wherever they conflict
- **Repair difficulty**: each component has `repair_difficulty` field (Simple/Standard/Advanced/Elite/Experimental) in component JSON per CO classification, mapping to hourly cost multipliers and base target numbers
- **Repair times per CO**: base time per component = `component_tonnage × hours_per_difficulty_level`; repairing damaged components at 1x time, replacing destroyed components at 1.5x time; base time modified by facility quality (repair bay level), parts availability (in-stock vs ordered), and component quality (A–F)
- **Technician skill effects per CO**: repair time and success chance determined by technician skill roll against component difficulty target number; `base_time × (10.0 / (skill + 5))` so higher skill = faster repair; minimum 0.5x with elite techs; failed roll doubles time, critical failure destroys component
- **Facility quality modifiers per CO**: facility level (field/repair bay/mech bay/advanced facility) applies a flat percentage bonus or penalty to repair time; higher-level facilities reduce time and allow higher-difficulty repairs
- **Component quality effects per CO**: quality rating A–F affects repair time multiplier (A=0.5x, B=0.75x, C=1.0x, D=1.25x, E=1.5x, F=2.0x) — worse quality takes longer to repair
- **Maintenance per CO**: each unit requires monthly maintenance = `component_count × 0.25` technician-hours per month; annual overhaul requires 10× monthly hours and replacement of all normal-wear items (actuators, filters, lubricants); neglected maintenance tracked as `maintenance_debt` — when debt exceeds threshold, triggers strategic events per CO failure tables (component failures, jams, ammo explosions, motive system damage for vehicles)
- **Salvage per CO**: salvage operations recover components from destroyed enemy units after tactical combat; per-component recovery chance = `tech_skill_roll × component_difficulty_modifier × quality_factor`; easier/simpler components more likely to survive; quality of recovered component determined by damage that destroyed the original unit; damaged components require repair before use; salvage time = `component_tonnage × 0.5` hours per component plus facility modifier
- **Repair queue**: player queues components for repair/replacement on each unit; priority order; total hours summed and consumed from technician budget; ETA shown with per-CO modifier breakdown
- **Inventory item repair**: damaged components in `GameState.player_inventory` (prefixed `"Damaged "`) may be repaired through the same repair queue; the player selects a damaged inventory item and assigns a technician — the same CO time, skill roll, facility, and quality rules apply; upon successful repair, the `"Damaged "` prefix is removed from the inventory entry, making the component usable as a standard replacement part
- Integrated with `PersonnelManager`: technicians assigned to units provide daily hour budgets for all work types (repair + maintenance + refit); `PersonnelManager.get_unit_repair_budget()` returns available hours per tick

#### P3.6.5 — MechLab UI (`MechLab.gd`/`.tscn`)

- Three tabs: **Refit** (variant swapping), **Design** (custom construction), **Repair** (component-level repair queue)
- Left panel: list of player's Mechs/Vehicles with active refit/parts/repair status badges; filterable by unit type, refit status, chassis name
- Right panel:
  - **Refit tab**: current variant info card (tonnage, armor, heat sinks, engine, movement), available variants list for selected chassis, component diff display (green = added, red = removed, gray = unchanged), TechManual refit class badge (B/C/D/E with color coding), parts sourcing plan table with per-component cost and source, total cost + labor estimate, Start Refit button (disabled if TM validation of result fails)
  - **Design tab**: per-location component grid (paper-doll layout), component browser panel with search/filter, drag-and-drop to place components, real-time TM validation panel (error list with rule references, warning list), armor slider per location, heat budget bar, tonnage meter, C-Bill total, Save Custom Variant button
  - **Repair tab**: component list grouped by unit with status icons (undamaged/damaged/destroyed), repair cost and time estimates, priority queue ordering (drag to reorder), assign/reassign technician dropdown, total ETA for all queued repairs
- Active refits shown in unit list with sub-status: "Delivering parts (3 days)", "Refitting (12 hours remaining)"
- Validation results displayed inline: green checkmark badge for valid, red X badge with expandable error list for invalid; tooltip on hover shows specific TM rule violated and the offending value

#### P3.6.6 — Campaign Operations Mech Customization

- **Customization** = modifying individual components on an existing unit (e.g., swapping a Medium Laser for a Large Laser, upgrading heat sinks, replacing armor type) without changing the variant designation; distinct from refit (variant-to-variant) and custom design (from scratch)
- Campaign Operations is the authoritative source for all customization rules governing time, cost, labor, skill checks, and facility requirements
- **Customization classification per CO**: each individual component change is classified independently using the same B–E scheme as refits (P3.6.2), but evaluated at the component level rather than the aggregate variant level:
  - **Class B (Standard)**: same location, same tech base, same slot count — e.g., swapping a Standard Medium Laser for an ER Medium Laser of the same tech base
  - **Class C (Complex)**: same tech base, different location OR different slot count — e.g., moving ammo from side torso to leg
  - **Class D (Major)**: different tech base — e.g., swapping Inner Sphere Ferro-Fibrous for Clan Ferro-Fibrous
  - **Class E (Chassis)**: changing engine, gyro, internal structure, or cockpit — complete rebuild
- **Customization workflow**:
  1. Player enters the MechLab Design tab (P3.6.5) on an existing owned unit
  2. Player adds/removes/replaces components in the paper-doll grid; real-time TM validation (P3.6.3) runs continuously
  3. When the player exits the editor or clicks "Apply Customization", the system evaluates each changed component per CO classification
  4. For each changed component, calculate:
     - **CO time**: `component_tonnage × CLASS_HOURS[class]` where B=1.0h/t, C=2.0h/t, D=5.0h/t, E=50.0h/t; minimum 4 hours per change
     - **CO cost**: `component_base_cost × CLASS_COST_PCT[class]` where B=5%, C=10%, D=20%, E=30%
     - **CO target number**: base TN from component `repair_difficulty` per CO table (Simple=4, Standard=6, Advanced=8, Elite=10, Experimental=12); modified by component quality (A=-2, B=-1, C=0, D=+1, E=+2, F=+4), facility level (field=+2, repair bay=0, mech bay=-1, advanced=-2), and parts availability (in-stock=0, ordered=+1)
  5. Player reviews the customization plan: per-component class badge, individual time/cost/TN, total time, total cost, and a "risk summary" showing which changes have high failure probabilities (TN > tech skill + 3)
  6. Player confirms → funds deducted immediately; parts not in local stock are sourced via `InterstellarOrderManager` (P1.2) with delivery ETA
- **Skill resolution per CO**: once all parts are on-hand and the assigned technician has available hours:
  - A single skill roll is made for the entire refit/customization job: `tech_skill_roll >= TN`
  - TN is the highest of all per-component TNs across all changes in the job (the hardest single change determines the difficulty of the whole job)
  - Refit kit bonus (refits only): a refit kit provides a flat TN reduction (e.g., -1 or -2 depending on kit quality); this bonus does NOT apply to customizations (which lack a pre-assembled kit)
  - On success: all changes are applied; time consumed = calculated CO time (modified by `base_time × (10.0 / (skill + 5))` per P3.6.4)
  - On failure: no changes are applied; the job extends by 50% of the original estimated hours and the player may retry (the roll is re-made when the extended time elapses)
  - No component destruction on failure — failure represents the tech encountering unexpected complications, not breaking parts
  - Multiple changes on the same unit in the same session are all applied or all retried as a single job
- **Facility gating per CO classification**: certain classes require minimum facility levels:
  - Class B: field or better
  - Class C: repair bay or better
  - Class D: mech bay or better
  - Class E: advanced facility or better
  - If the current planet's facility is below the requirement, the player is warned and a flat +4 TN penalty is applied (field-expedient modifier per CO)
- **Parts quality interaction**: if the replacement component's quality rating is lower than the original, the base TN increases by `(original_quality - new_quality) × 1` (CO quality mismatch penalty); the player can mitigate by first repairing the replacement part to a higher quality (time cost per P3.6.4)
- **Customization log**: all completed customizations are recorded on the unit's metadata (`customization_history: Array[Dictionary]`) with timestamp, components changed, technician who performed the work, and skill roll results; visible in the MechLab info card

---

### P3.7 — Initial Strategic Unit Generator

- **`StrategicUnitGenerator.gd`** in `src/strategic/` — generates the player's starting force on New Game
- **Starting C-Bill float**: `Nd6 × 1,000,000` CSB where `N` is configurable (default 20); roll per new game; configurable floor — if the roll would go below the floor, use the floor instead; `dice_count: int` and `floor: int` in settings
- **Initial mech stable**: configurable count (default 12 — a company), generated via Xotl's d1000 Random Assignment Tables (RATs) for the selected originating faction and era (3025); `data/rat/` directory holds faction-specific RAT JSON files parsed by `RATParser.gd`; mechs generated as `TacticalUnit` resources with random `Quality` (F–C distribution) and minor random variation in component condition
- **Pilot skill correlation**: crew with higher `Leadership`, `Tactics`, or `Strategy` skills should also have better `piloting`+`gunnery` on average (command ability and combat ability are positively correlated); command ability also correlates positively with `Training` skill, but more weakly than with combat skills
- **Faction handling**: player picks an originating faction at New Game (affects RAT mech selection); after generation the unit's faction type is set to `MERC` regardless of origin
- **Initial personnel** (all starting personnel flagged with `is_founder: bool = true`, making them less likely to quit when a morale and retention system is added later):
  - **Commander** — the best pilot among the initial crew, flagged via `is_commander: bool`; selected by highest `Leadership`, then highest `Strategy`, then highest `Tactics`, then highest sum of gunnery+piloting skill
  - **Executive Officer (XO)** — the second-best pilot, flagged via `is_xo: bool` on the same resource
  - **Lance commanders** — for each lance beyond the first (every 4 mechs after mechs 1–4), flag the best remaining pilot via `is_lance_commander: bool`; selected by highest `Tactics`, then highest gunnery+piloting
  - Administrative staff (four roles), generated with sufficient skill to cover unit needs:
    - **HR** (`HR` role) — covers individually-tracked staff (crew + technicians + doctor + admins); each point of `Administration` skill covers 10 employees; astechs and medics (abstract) excluded; generate additional HR if one insufficient
    - **Logistics** (`LOGISTICAL` role) — manages supply chain, parts ordering, inventory
    - **Command** (`COMMAND` role) — the commander's administrative assistant (scheduling, comms, paperwork)
    - **Transport** (`TRANSPORT` role) — manages unit transport (DropShip/JumpShip booking, convoy movement)
  - 1 Doctor (`DOCTOR` role)
  - Technicians (`TECHNICIAN` role) — 1 per mech, tracked as individual characters
  - Astechs (`ASTECH` role) — 2 per technician, tracked as abstract pool (count only, no stats/skills/relationships)
  - Medics (`MEDIC` role) — tracked as abstract pool (count only), 6 per doctor
  - Crew (`CREW` role) — 1 per mech (pilots), plus 1 spare pilot per 4 mechs, tracked as individual characters
- **Starting inventory**: auto-calculated from generated mechs:
  - **Ammo**: 2 tons of matching ammo per ammo-using weapon (scan all generated mechs' components for ammo-fed weapons; add corresponding ammo to inventory)
  - **Armor**: spare armor points equal to 10% of total armor points across all generated mechs (for repair stockpile)
  - **Common spares**: spare components equal to 10% of total component count across all generated mechs, by type (actuators, heat sinks, structure, etc.), minimum 1 of each type that appears in any mech
  - All purchased from starting float at base cost (component/unit `cost` field, not market rate)
- **Starting organizational structure**:
  - Player `StrategicUnit` created
  - One `OrganizationalUnit` (mercenary company name)
  - One `OperationalUnit` per lance (4 mechs), nested under the organizational unit
- **C-Bill expenditure**: purchase the initial mechs and equipment from the float at base cost (component/unit `cost` field); remaining float = `roll − purchase_cost` (subject to floor)
- **Integration**: called by Main Menu `New Game` flow before entering strategic layer; writes generated state into `GameState`
- **Starting relationships**: the generator creates a web of pre-existing relationships among the founding personnel, simulating shared history before unit formation:
  - Pilots who trained together or served in the same unit before going mercenary may have positive bonds (Wingman, Friendship)
  - Rivalries from past disagreements or competition may generate negative bonds (Dislike, Rival)
  - A small chance of romantic relationships (Lover) and a very small chance of Marriage among the founding crew
  - Relationships are weighted by originating faction (same-faction personnel more likely to have history) and role (pilots more likely to know other pilots than admin staff)
  - Each generated character has `originating_faction` set to the player's chosen faction and `home_system`/`home_planet` derived from that faction's home worlds
- **Tests**: `tests/test_strategic_unit_generator.gd` — verify generated force has correct mech count, personnel ratios (HR capacity covers tracked staff, 1 tech per mech, 6 medics per doctor, etc.), commander/XO/lance commander flags, C-Bill float within expected range, and inventory matches mech equipment

---

### P3.8 — Operational Unit Inventory Assignment

- `per_unit_inventory_enabled: bool` (default false) in `spares_config.json` under `data/config/` — master toggle for the entire per-operational-unit inventory assignment system
  - When **false** (default): deployment does not require parts allocation; all `GameState.player_inventory` is treated as a single pool accessible from any deployed unit for repairs and ammo resupply
  - When **true**: the full allocation UI, auto-allocate, deployment cache tracking, and recovery workflows are enabled; the player must assign parts per operational unit at deployment time
  - Settings UI toggle under "Spares & Logistics" section
- When deploying an `OperationalUnit` to a contract, the player must allocate spare parts from `GameState.player_inventory` to that operational unit's deployment cache (if `per_unit_inventory_enabled` is true)
- **Allocation UI**: shows each mech in the operational unit side-by-side with a per-component inventory picker:
  - For each ammo-using weapon on the mech, a spinner to assign tons of matching ammo (sourced from player inventory)
  - A spare armor points slider (in points or half-ton increments, matching the mech's armor type)
  - A spare components browser per component type (actuators, heat sinks, structure, etc.) with quantity picker
  - Running total of allocated tonnage displayed — exceeding a reasonable threshold (configurable, default 10% of total unit tonnage) warns but does not block
- **Automated defaults**: a "Auto-Allocate" button that fills allocation to match standard baseline spares for all mechs in the operational unit:
  - **Ammo**: 2 tons of matching ammo per ammo-using weapon on each mech
  - **Armor**: spare armor points equal to 10% of each mech's total armor points (for field repairs), rounded up to nearest half-ton equivalent
  - **Common spares**: for each component type present on any mech in the operational unit, spare count = `max(1, ceil(total_count_across_lance × 0.1))` — e.g. if the lance has 8 hip actuators across 4 mechs, allocate 1 spare hip actuator
  - Auto-allocation only consumes what is available in `GameState.player_inventory`; if insufficient stock, the shortfall is listed as a warning (player can order from market or deploy anyway)
- **Baseline spares configuration**: the percentages and flat values used in auto-allocation are defined in `spares_config.json` under `data/config/`:
  - `ammo_tons_per_weapon: int` (default 2) — tons of matching ammo per ammo-using weapon
  - `armor_percent_of_total: float` (default 0.10) — spare armor points as fraction of each mech's total armor points
  - `spares_percent_of_total: float` (default 0.10) — spare components as fraction of each component type's total count across the lance
  - `ammo_armor_and_spares_tonnage_warning_threshold: float` (default 0.10) — fraction of total unit tonnage above which the running total warning triggers
  - `auto_reorder_enabled: bool` (default false) — master toggle for automatic reordering
  - `auto_reorder_min_stock: int` (default 0) — minimum quantity threshold per component name in `GameState.player_inventory` that triggers an automatic order; if any component's stock falls below this value, an order is placed to bring it back up to `auto_reorder_target_stock`
  - `auto_reorder_target_stock: int` (default 0) — quantity to reorder up to when below the minimum
  - `auto_reorder_max_cost_per_order: int` (default 500000) — total C-Bill cap per automatic order to prevent bankrupting the player
  - `auto_reorder_min_balance: int` (default 100000) — minimum C-Bill balance; if `GameState.player.current_balance` is below this value, all automatic reordering is suspended regardless of stock levels
  - JSON is hot-reloadable; changes take effect on next auto-allocate
  - Settings UI accessible from the allocation screen and from the Settings menu, under a "Spares & Logistics" section
- **Auto-reorder fund gate**: before processing any auto-orders on a tick, check `GameState.player.current_balance` against `auto_reorder_min_balance`:
  - If balance is below the threshold, skip all auto-orders this tick and emit a `auto_reorder_suspended` event with the current balance and threshold
  - A persistent badge appears in the HUD (e.g., a small warning icon next to the C-Bill display) with tooltip: "Auto-reorder suspended — funds below threshold (X / Y CSB)"
  - The badge auto-dismisses when balance recovers above the threshold on a subsequent tick and auto-ordering resumes
  - Manual ordering from the market is never blocked by this gate — the player can always spend their last C-Bill if they choose
- **Automatic reordering**: when `auto_reorder_enabled` is true and the fund gate is open, on each strategic tick:
  - Scan `GameState.player_inventory` for all component entries
  - For each component where `quantity < auto_reorder_min_stock`, calculate the shortfall: `auto_reorder_target_stock - current_quantity`
  - Query the interstellar order manager for each shortfall component on nearby systems (up to 2 jumps, standard pricing/markup)
  - If a source is found and the total cost of all pending auto-orders this tick would not exceed `auto_reorder_max_cost_per_order`, place the order immediately (deduct funds, create `PendingDelivery`)
  - Multiple shortfall components are batched into a single order per source system where possible, to consolidate shipping
  - If no source is found within range, the system logs a warning and tries again on the next tick
  - Auto-orders are flagged with `auto_order: true` in the delivery metadata so the player can distinguish them from manual orders in the logistics panel
  - The player can temporarily suspend auto-reordering from the allocation UI or Settings without clearing the configuration
- **Deduction on confirm**: when the player confirms deployment, deduct the allocated quantities from `GameState.player_inventory` and store them on the `OperationalUnit` resource as `deployment_cache: Dictionary` (keyed by component name, value = quantity)
- **Recovery on contract completion**: when the contract ends, any unspent deployment cache items are returned to `GameState.player_inventory`; expended items (ammo shot, armor damaged beyond repair) are deducted — tracked via tactical combat resolution
- **In-transit tracking**: if the operational unit is in transit (not yet landed), the deployment cache is not accessible for repairs/refits; once the unit lands on the planet hex, the cache becomes the local repair stockpile for that unit
- **Operational logistics difficulty** (gated by config toggle `operational_logistics_enabled: bool`, default false):
  - When enabled, resupplying deployed units during **Planetary Assault** or **Raid** contracts requires a logistics roll
  - The sourcing player's `LOGISTICAL` personnel skill is checked against a difficulty target number derived from the contract's activity type (assaults harder than raids), enemy resistance, and planetary infrastructure (USILR code)
  - Failed logistics roll means the supplies do not arrive that tick — the unit must rely on its deployment cache or salvage
  - Critical failure may result in supply loss (ammo/parts destroyed in transit)
  - **Independent command rights**: when `operational_logistics_enabled` is true and the contract has `Independent` command rights, the employer does not host a local market on the planet — all supplies must be shipped from Galatea or sourced via InterstellarOrderManager with extended delivery times (no "buy from planet's employer market" option); this reflects the independent operator's lack of employer logistical support
  - The difficulty modifier, supply delay days, and critical failure chance are all configurable in `spares_config.json`

---

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

- **Color blind accessibility** (future version): add a color blind friendly palette option for the paper doll and HUD, using patterns/textures or high-contrast color pairings that are distinguishable for common forms of color blindness (deuteranopia, protanopia, tritanopia); toggleable from settings
- `ui/hud/HUD.tscn` — persistent overlay
  - Date/time display
  - C-Bill balance
  - Pause/play button
  - Current layer indicator (Strategic/Operational/Tactical)
  - Alert notifications (event popups)
  - **Status badges** — persistent warning icons in the HUD for ongoing operational problems; each badge shows an icon and a count, expands to a tooltip on hover, and auto-dismisses when the condition clears:
    - **Auto-reorder suspended badge**: warning icon next to C-Bill display when `auto_reorder_enabled` but balance is below `auto_reorder_min_balance`; tooltip: "Auto-reorder suspended — funds below threshold (X / Y CSB)"
    - **Unattended injured badge**: red cross icon when one or more personnel are injured (`is_injured = true`) but not assigned to a doctor with available capacity, or when no doctor is employed; count shows number of unattended injured; tooltip: "X personnel injured without medical care"
    - **HR shortage badge**: people icon with exclamation when HR staff `Administration` skill capacity (`skill × 10`) is less than the total number of individually-tracked personnel (crew + technicians + doctors + admins; excluding astechs and medics); count shows how many additional HR skill points would be needed; tooltip: "HR understaffed — capacity X, need Y (Z personnel)"
    - **Pending tactical engagements badge**: crossed-swords or warning icon when one or more tactical engagements are awaiting resolution (player's deployed units have encountered enemy forces but the battle has not yet been fought); count shows number of pending engagements; tooltip: "X pending tactical engagement(s) — deploy to resolve"; badge appears on the strategic map sidebar and in the HUD; clicking the badge opens the deployment/engagement view
    - **Low supplies badge**: crate/exclamation icon when any deployed operational unit's deployment cache has any component (ammo, armor, or spare parts) at or below the configured minimum threshold (`auto_reorder_min_stock` in `spares_config.json`); counts the number of distinct component types below minimum across all deployed units; tooltip lists which units and which components are running low; badge auto-dismisses when all deployed units have been re-supplied above the minimum threshold

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
    t- Use Godot's `ConfigFile` or `Resource` format with `ResourceFormatSaver` for binary size; compress with Deflate
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
Build all data files, star map, strategic UI, contract generation, organization management, strategic events, MechLab/Refit UI, TechManual construction rules engine, custom design system, repair & maintenance.

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

| File                               | Purpose                                   |
| ---------------------------------- | ----------------------------------------- |
| `src/core/GameState.gd`            | Central game state resource               |
| `src/core/EventBus.gd`             | Signal-based event communication          |
| `src/core/TimeManager.gd`          | Calendar, ticks, pause                    |
| `src/systems/EconomySystem.gd`     | C-Bills, market, costs                    |
| `src/systems/ReputationSystem.gd`  | Global + faction reputation               |
| `src/systems/PersonnelManager.gd`  | Hire/fire/injure/heal                     |
| `src/systems/TechManualRules.gd`   | TM construction, refit, validation engine |
| `src/systems/RefitManager.gd`      | Active refit order processing             |
| `src/systems/RulesEngine.gd`       | Flexible combat rules engine              |
| `src/systems/MegaMekParser.gd`     | Parse .mtf files                          |
| `src/systems/ContractGenerator.gd` | Generate contracts                        |
| `src/systems/TacticalAI.gd`        | Enemy tactical AI                         |
| `src/systems/SaveManager.gd`       | Save/load serialization                   |
| `src/data/*.gd`                    | Resource class definitions                |
| `src/strategic/StarMap.gd`         | Strategic layer controller                |
| `src/operational/PlanetaryMap.gd`  | Operational layer controller              |
| `src/tactical/TacticalMap.gd`      | Tactical layer controller                 |
| `src/ui/`                          | All UI scenes and scripts                 |
| `data/factions/*.json`             | Faction definitions                       |
| `data/units/*.mtf`                 | MegaMek unit files                        |
| `data/starmap.json`                | Star system coordinates                   |
| `data/timeline_events.json`        | Lore timeline                             |
| `house_rules.json`                 | Configurable rule toggles                 |
