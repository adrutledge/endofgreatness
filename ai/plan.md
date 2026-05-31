# End of Greatness — AI Build Plan

## Core Gameplay Loop
Form a unit → take a contract → deploy to the contract planet → explore the planetary hex map → engage in tactical combat(s) as objectives are encountered → complete the contract → repeat. Everything in Phases 0-6 serves this loop.

## Version Targets

### V1 — Basic Gameplay Loop
Establish unit, take contract, deploy to planet, explore hex map, perform tactical engagements, complete contract, repeat. All systems data-driven where feasible. Lore-based planets, factions, components, units (3025 static).

### V2 — Event System + Timeline Advancement
Both random and scripted events — basic set to be expanded over time. EventJournal with atomic diffs, rolling window, narrative anchors, configurable display modes (popup/toast/log/hide).
Date advances trigger timeline events (ownership changes, system renames, faction shifts). Helm Memory Core discovered (3028) — lostech becomes available. Inner Sphere responds to technological recovery.

### V3 — Advanced Personnel
Pilot abilities, passive XP, medals, data-driven personnel types with correlation rules, era-gated skills, rank systems, role-specific skill trees.

### V4 — Expanded Unit Types

### V5 — Advanced Contracting
Breach system, disputed/contested systems, side-taking in conflicts, influence-range contract pool, emergency contracts as reputation recovery path, faction alignment enforcement.

### V6 — Aerospace
Aerospace assets (owned DropShips, fighters), supply line interdiction, opposed planetary landings, escort/convoy mechanics.

### V7 — Scripted Content Push
Major push for authored content — event chains, lore-accurate missions, canon character appearances, timeline-specific scenarios across multiple eras.

### V8 — Organic Narrative
Bounty board, bounties on player, pirate interference, LosTech rumor tracking, SLSC discovery, Solaris VII gladiatorial games, boss NPCs with unique abilities and Edge pools. Emergent storytelling driven by the event system and player actions.

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
- Timeline event checking (MVP: date advances but timeline events — ownership changes, lore events — are not processed; Inner Sphere remains static at 3025)
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
- Data-driven contract config (`data/config/contract_generation.json`) controls ranges, minimums, and weights per type

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
- Data-driven contract definitions (future expansion): contract types defined in JSON with per-type range weights, opposing force strength, tactical engagement types, facilities, weighted terms; event-only contracts with exact opfor/map/victory conditions
- Organic narrative cluster: bounty board, bounties on player, pirate interference, LosTech rumor tracking
- Boss NPCs: notable enemy pilots and major characters with their own Edge pool, unique abilities, and persistent narrative presence; boss Edge used at AI's discretion to create tension in pivotal encounters; boss defeat may yield unique salvage, reputation gains, or narrative progression
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
- Rank systems: each faction defines its own rank structure in its JSON file (enlisted and officer tracks, with internal codes like E1–E9, O1–O10, WO1–WO5) and display names per rank; players can define custom rank systems mapped over the internal codes; a personnel's rank is stored as a code (e.g., "O3") and displayed using the active rank system's name for that code
- Data-driven personnel types: each role defined in `data/personnel_types/*.json` — fields: `faction_availability` with date ranges (Clan battle armor from 2850, IS from 3050), `primary_skills`/`secondary_skills` with weights, `attribute_requirements` (mechwarrior: reflexes 4–10), `rank_track`, `age_range`, `skill_ranges` with era gates (3025 caps at 6, 3050+ higher), `vehicle_type_mapping`, `cross_training_max`, `required/forbidden_traits`, `salary_multiplier`, `pool_weight`
- **Skill correlation rules** (JSON-based expression language): each personnel type file can include a `correlations` array of rules — `{"condition": {"skill_sum": ["strategy", "tactics"], "min": 10}, "effect": {"boost": "piloting_mech", "amount": 2}}` or `{"if": "avg(strategy, tactics) >= 4", "then": "piloting_mech += 1"}`; rules are evaluated after base stat generation, before final clamping; operators include `skill_sum`, `skill_avg`, `attr_min`/`attr_max`, `faction_is`, `era_is`; this replaces the hardcoded `_pilot_skill_correlation` function with data-driven rules that modders can extend without touching code; performance is negligible (a few dozen rules evaluated per character)
- Current version generates only MECHWARRIOR (mechs only until vehicles/infantry enabled)
- Era-gated skills: certain skills only appear in specific eras — e.g., Clan technology skills only after 3049, Star League lostech skills only before 2780 or after 3040, Word of Blake affiliations only 3057–3075; skill and trait generation checks the current game date against the skill's era range; this prevents anachronistic skills (a Clan-tech specialist in 3025) while enabling period-accurate character generation
- Medals and decorations (fruit salad): personnel earn medals for notable accomplishments — X kills in a single mission, surviving Y damage in one engagement, participating in a major lore conflict (Fourth Succession War, etc.), serving as an instructor (Training skill for their lance over Z months), extracting from a losing battle, or disabling a superior foe without destroying it; each medal grants a permanent buff (stat/skill bonus, trait, or ability unlock) and is displayed as a ribbon/medal icon on the personnel sheet; thresholds are mission-level (e.g., "3+ kills in one mission") not aggregate, rewarding exceptional moments; MRB may issue standard medals, while faction-specific decorations unlock with reputation; a character's medal rack ("fruit salad") is visible in their detail view, providing at-a-glance history
- **Edge points**: each character can earn Edge from medals (one per medal) or purchase it with XP (configurable cost, default 5 XP per point). Edge is a one-time use resource — spend a point to force a reroll on any die roll (to-hit, damage, critical hit location, piloting skill check, etc.). The reroll result must be kept regardless of outcome. Edge does not refresh automatically (it's earned, not per-session). A settings UI lets players configure automatic Edge spending triggers with sane defaults: "spend on through-armor criticals," "spend on head hits," "spend on ammo explosion checks."
- **Data-driven skills**: skill definitions moved from `Enums.get_all_skills()` to `data/skills.json` — each skill has `name`, `display_name` (tr() key), `attribute` (BOD/DEX/RFL/etc), `description`, `max_rating` (default 10, lower in earlier eras), `era_gates`, and whether it's a primary/secondary/trained-only skill; the Personnel resource already stores skills as a Dictionary keyed by name, so no resource changes needed — just load the skill list from data and validate against it; modders can add new skills without touching code
- **Data-driven medals**: medal definitions in `data/medals/*.json` — each medal specifies trigger conditions (kill count in single mission, damage threshold, event participation, contract chain completion), stat buffs or trait unlocks, display name and description (tr() keys), icon reference, and whether it's MRB-standard or faction-specific; the medal check system evaluates data conditions at mission end rather than hardcoded logic
- **Data-driven injury system**: injury types defined in `data/injuries/*.json` with trigger conditions (personnel role, damage type dealt, weapon category that caused the hit), base healing time in days, difficulty modifier for the medic's skill check, which skills the medic rolls against, healing environment modifiers (medbay vs field, facility level), and whether the injury can leave permanent effects; during combat resolution, when a personnel takes damage, the system evaluates injury type conditions and assigns matching injuries; injuries heal over time (weekly ticks via `month_started` signal for progress updates) — each week, a healing check is rolled against the injury's difficulty using the assigned medic's relevant skill, and on success the remaining healing time is reduced by the week's progress (modified by skill, facility, and injury severity); the Medbay tab reflects current injury status and healing estimates

### Advanced Politics

- War crimes tracking, MRB sanctions, bounty hunters
- Faction border shifts, economic spheres, ComStar intrigue

### UI Polish

- HUD status badges (funds low, auto-reorder suspended, injured unattended)
- Color blind accessibility palette
- Deploy-time allocation UI, auto-allocate defaults
- Operation progress feedback: status labels and/or progress bars for long-running operations (unit generation, contract generation, map generation, data parsing) so the UI doesn't appear frozen; use `call_deferred` or threading where feasible to keep the interface responsive; each phase of generation prints a status line (e.g., "Generating mechs...", "Building personnel...", "Creating organization...") updated via the existing lazy refresh signal pattern

### Save/Load

- Autosave rotation, manual saves, save metadata

### Data Gaps
- USILR/HPG gameplay effects
- faction_destroyed timeline events
- TM construction fields on component JSONs
- Starmap index: lightweight `data/systems_index.json` with `name`, `x`, `y`, `owner_faction`, `spectral_class`, `file` — loaded at startup for map display (~190 KB for 3,174 systems); per-system detail files (`data/systems/<name>.json`) loaded on click or when game logic queries the system; split via parser update
- Canonical map layouts: systems and their settled bodies can store `canonical_planetary_map: String` (single reference to a pre-authored planetary exploration map) and `canonical_tactical_maps: Array[String]` (list of pre-authored tactical map references for specific locations on the body); tactical maps reference files in `data/maps/canonical/tactical/`; when a tactical engagement occurs on a body, if a canonical tactical map exists for the engagement's location context, it is used; otherwise procedural generation fills in — even canonically mapped planets have unmapped terrain that needs procedural generation; enables lore-accurate battlefields (Hesperus II canyon, Brinton city on Galatea) alongside procedurally generated wilderness

### Timeline System Data
- Replace monolithic `timeline_events.json` with scriptable event files in `data/events/` — one file per event chain (e.g., `4th_succession_war.json`, `war_of_3039.json`); each file contains rules for what date(s) to fire on (single date, date range, or `{"start": "3028", "end": "3030", "check": "monthly"}`), the events themselves (ownership changes, system renames, faction alignments, etc.), and optional data overrides for situations that cannot be derived organically from the SUCKIT data (custom event text, faction breakouts, special mercenary contracts, lore-specific force compositions); DataManager loads and merges all files at startup; keeps diffs readable, allows modders to add event chains without touching auto-generated data
- The same file format covers organic narrative events (bounties, lostech rumors, pirate activity) in addition to timeline events; organic events use trigger rules instead of dates — `{"trigger": "on_contract_completed", "conditions": {"faction": "PIR", "kills": 5}}` or `{"trigger": "on_event", "event_id": "bounty_intro"}` for chaining; events may offer multiple player choices with branching outcomes; third-party actors (bounty hunters, pirates) can be specified as event participants that influence resolution or appear as tactical encounters; this unifies all event types under a single data-driven system
- **Event context and state boundaries**: each event receives a defined `EventContext` object containing read-only state (date, player planet, faction reputations, active contracts, system data) and a write-capable `EventEffects` object through which events apply changes; allowed effects are: ownership transfer, system visibility toggle, faction reputation modification, player fund adjustment, contract force-completion or cancellation, event flag set/clear, and ECMAScript-compatible data patches to starmap properties; events cannot directly modify personnel, units, or inventory — those changes must go through the existing system APIs; this provides clear boundaries for what events can and cannot do, making the system auditable and safe for modder content
- **Event application** (see Design Notes — Central Journal with Atomic Diffs): each event produces a `DiffPacket` describing its effects; packets are queued in FIFO order by `EventJournal` and applied sequentially per tick; sub-events triggered by an event are pushed to the back of the queue for the next tick; every journal entry stores tick number, source event ID, and the diff for full auditability and save/load serialization
- **Event display and player preferences**: each `DiffPacket` includes a `display` field with the event's text (`title` and `description` as `tr()` keys), icon reference, a `display_mode` key (e.g., `"event_lore_major"`, `"event_ownership_change"`, `"event_bounty"`), and a `narrative: bool` flag; events with `narrative: true` (character births/deaths, unit foundings, major battles, lostech finds) are preserved indefinitely in the journal under the rolling window policy; player-configured preferences map each display_mode to one of: `popup_and_pause` (modal with game pause), `popup` (modal without pause), `toast` (non-blocking notification), `log` (event log entry only), or `hide` (silently applied); event text is always logged to the event log regardless of display mode; players can change preferences per mode at any time through settings
- System hide/unhide is entirely event-driven: an event of type `system_hide` or `system_unhide` toggles a system's visibility; no `hidden_dates` static data on systems — visibility is determined solely by processed events; parser generates `system_hide` events from SUCKIT ownership data (periods where a system is `U`/uninhabited); event chains can additionally reveal or conceal systems dynamically (e.g., a lostech rumor chain uncovers a hidden SLSC facility, or a pirate crackdown removes pirate safe havens); when TimeManager date advances, the event system processes `system_hide`/`system_unhide` events whose date range covers the current date
- **Faction-aware hiding**: `hidden_on_map` should consider player faction and date ranges — e.g., Clan homeworlds are hidden from Inner Sphere players until 3050 but visible to Clan players; a `hidden_on_map` field on faction JSON can specify `{"factions": ["IS"], "until": "3050-01-01"}` to hide systems owned by that faction from specific player factions until a given date; use `from`/`to` fields on systems (ISO YYYY-MM-DD) for per-system hidden ranges
- **Date format standard**: all dates in code and data files use ISO 8601 `YYYY-MM-DD` format; year-only values are expanded to `YYYY-01-01` for comparison; the parser outputs timeline events with full YYYY-MM-DD dates; `TimeManager` stores dates as `{"year": Y, "month": M, "day": D}` internally but all serialized/exported dates use the ISO string format

**Starmap territory recomputation**: faction territory is computed from `systems_index.json` via Voronoi and cached to `user://cache/starmap_territory.json` (keyed by file mtime). When timeline events change system ownership mid-campaign, the territory must be recomputed against *current* (post-event) ownership rather than static data. Approach: after applying ownership-change events, call `_compute_faction_territory()` to regenerate from scratch (sub-second with cache warm) or re-Voronoi only the affected grid region. The save file stores `territory_cache_stale: true` flag or the last-territory-recompute tick so that on load the territory is regenerated if needed. Territory data itself is ~4-5 MB and stays out of the save — it always derives from current ownership, never serialized.
- **Edge case — stranded forces**: if a player has forces on a system entering a `hidden_dates` range, use the lazy refresh signal pattern (`month_started`) to emit a `stranded_forces_warning` signal with the affected unit names and system; the HUD warning badge picks this up (following the same pattern as `funds_low_for_reorder`); the player has until the next month tick to evacuate via transit or contract — after that, the system is hidden but forces remain accessible only via the unit roster (marked with a "STRANDED" badge); forces cannot be deployed on contracts from a hidden system; an evacuation order generates an emergency transit event

---

## Design Notes & Architectural Patterns

### Data-Driven First
Prefer data-driven systems over hardcoded logic wherever feasible. Configuration files (personnel types, faction data, contract generation weights, skill correlation rules) should define behavior that would otherwise require code changes. This enables modding, reduces compilation errors from misplaced indentation, and keeps the engine code focused on interpretation rather than domain logic.

### Data Validation and Debugging
Every data-driven system should include runtime validation that mod developers can invoke — a `validate_data()` method that checks all loaded JSON files for required fields, type correctness, cross-references (e.g., every RAT entry points to an existing MTF file), and range bounds. These validators are exposed as an in-game "Validate Data" button (debug menu or settings) and also run automatically on game launch in debug mode (`--opencode-debug` or `OPENCODE_DEBUG=true`), printing results to stderr via `printerr()`. Each invalid entry reports the file, field, and expected vs actual value. This catches mod errors immediately rather than causing silent failures mid-campaign. Test coverage for data-driven systems should include the validation logic itself, and each data file should have a corresponding test fixture where feasible.

### Event-Driven Unique Content
Unique contracts (event-only types), special personnel (canon NPCs, ephemeral characters), custom injuries, system state changes, and other bespoke content should be event-driven rather than hardcoded. The event system has full access to: generating event-only contracts with exact opfor/map/victory conditions, spawning NPCs (either full Personnel resources with complete stats, or ephemeral references with name/archetype seed/faction/flags), toggling system ownership and visibility, modifying faction reputation, and patching any data-driven system. This avoids special-case code for every unique piece of content and keeps the event pipeline as the single path for all non-procedural state changes. Canonical characters (Victor Steiner-Davion, Hanse Davion, etc.) are generated by events at their lore-correct dates — use full Personnel for those who may join the player's force, ephemeral references for those who merely appear in narrative text.

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

### Central Journal with Atomic Diffs (future — timeline events)

Each event produces a `DiffPacket` (Dictionary of effects: `{"system_hide": [...], "rep_change": {...}}`). An `EventJournal` singleton queues packets in FIFO order and applies them sequentially per tick. If an event triggers a sub-event, its diff is pushed to the back of the queue for the next tick. Every journal entry stores tick number, source event ID, and the full diff — providing auditability, determinism, and a serialization-ready record for save/load. No multi-threading needed; ordering guarantees come from the queue discipline, not locks.

**Rolling window with narrative anchors**: rather than condensing the oldest entries universally, use a time-window approach — keep full detail for the last N years (default 10, configurable). For periods older than the window, entries with `narrative: true` are preserved individually; all other entries (ownership changes, routine contracts, market transactions, personnel movements) are condensed into per-year summary entries (`"year_summary": true`). A year summary records aggregate stats (contracts completed by type, systems visited, total earnings, personnel changes) but drops individual diff granularity. Events declare `narrative: true` in their event definition when they represent a campaign-significant moment — character births/deaths, unit foundings, major battles, lostech discoveries, arena championships, or any point the designer considers story-relevant. This keeps the narrative thread intact across centuries while aggressively compacting routine data. The downsample threshold from the condensing approach is replaced by the rolling window size — history outside the window is always condensed into year summaries, making journal size predictable regardless of campaign length.
- **Journal filtering**: the event log UI provides filter controls — by date range, event type (contract, personnel, combat, narrative), faction involved, system, and free-text search; filters apply to both full-detail entries and year summaries (for summaries, matching the year shows the summary card with a "view details unavailable" note); filter state persists per session and can be saved as presets

### Save System Pattern (future)

Autosaves default to the last day of each month (configurable interval). Multiple rotating slots with metadata (date, contract, location).

### Save Forward Compatibility (constraint)

Save files from older versions load on newer versions via sequential migration functions. Each save stores a `save_version: int`. On load, if the save version is behind the current game version, migration functions are applied in order — each a small transform (add field, rename key, recompute derived value) that upgrades the save dict from version N to N+1. Saves are always written at the current version, so loading only upgrades forward. This parallels rolling database migrations: each migration is self-contained, idempotent where possible, and indexed by version. A save from V1 remains loadable in V9 after all intervening migrations have run.

### Save File Self-Containment (constraint)

A save file must restore all player campaign state on a fresh install (balance, inventory, units, personnel, contract chain progress). Invariant game data shipped with every install (component defs, faction data, RAT tables, timeline events, NPC archetypes) is assumed identical and does NOT need to be duplicated in the save. NPC persistence uses archetype reference + seed + limited flags (relationship, alive/dead, hostility), keeping saves lightweight while remaining self-contained for campaign state.

### Modal Event Dialog Pattern

Events show dialogs via `CampaignView.show_modal(dialog)`. The dialog is any `Control` — the ModalLayer (layer 4) queues it FIFO and centers it above a dimmed background. The standard event dialog layout:

```
EventDialog (Panel, ~600×400)
├── TextureRect (optional image, left column)
├── VBox (right column / below image)
│   ├── Title (Label)
│   ├── Description (RichTextLabel, BBCode)
│   ├── CustomContent (Control — empty placeholder, for future expansion)
│   └── Options (HBoxContainer)
│       ├── OptionButton 1 → effect callbacks
│       └── OptionButton 2 → effect callbacks
```

The event system constructs the dialog, wires each option to its `EventEffects` method (rep change, fund adjustment, contract force-complete, etc.), then calls `CampaignView.show_modal(dialog)`. When an option is clicked, the effect runs and `CampaignView.dismiss_modal()` is called to advance the FIFO queue. Options can also push additional modals (for branching chains). Without an explicit event system, scripts can call `CampaignView.show_modal(AcceptDialog.new(...))` directly for one-off notifications.

### UI Polish — Loading Feedback

During game launch, `DataManager.load_all_data()` runs synchronously in `_ready()` and can take several seconds (loading 3171 systems, parsing hundreds of MTF unit files, loading 260+ component JSONs, 12+ faction files, timeline events). The main menu appears frozen during this period. Future improvement: add a loading screen or progress bar using `call_deferred` or a separate `LoadingScreen` scene that renders immediately while data loads in chunks. Each loading phase should print a status line (parsing mechs..., loading components..., building starmap...). The `StarmapCacheGenerator` autoload also runs deferred territory computation in the background — a subtle indicator during the main menu would communicate that startup caching is still active.

### UI Polish — Badge Display

Status badges (funds low, injured personnel, reorder suspended, etc.) should be icons rather than text labels, displayed either as a strip below the HUD top bar or stacked along the right edge of the screen. If the number of active badges exceeds the available display area, use a scrollable drawer (toggle-able) or collapse into a count badge ("3 issues") that expands on hover/click. Badge icons should be color-coded by severity (red=critical, amber=warning, blue=info). This is visual-only polish — the badge data model and signal triggers are already in place.

### Deferred Bugs
- **HUD `BillsLabel` not found**: `$TopBar/Finances/BillsLabel` fails despite the node existing in the scene tree as a sibling of `BalanceLabel` (which resolves fine). Two-step `get_node("Finances").get_node("BillsLabel")` also fails. Likely a Godot scene cache or node naming issue — revisit after a full editor restart or .tscn rebuild.

### Future — Terrain & Movement System

Each unit type has different terrain interaction rules, defined in its `data/unit_types/*.json`:

- **Mechs**: no terrain restrictions. Movement cost varies by terrain type (clear=1, forest=2, rough=2, water=MP/hex). Certain terrain or maneuvers (entering water, taking 20+ damage in a phase) trigger a Piloting Skill Roll (PSR) — 2d6 >= piloting skill or the mech falls. Taking 20+ damage in a single phase triggers a PSR *and* applies a +1 cumulative modifier to all PSRs in that phase (+1 per 20 damage, common house rule, configurable in `combat_config.json`). Additional PSR triggers: leg/gyro damage, sudden movement changes (DFA, charge), and certain terrain (depth 1+ water, rubble).
- **Aerospace/VTOL/Conventional aircraft**: no ground terrain restrictions but operate at height levels. Control checks (analogous to PSRs) are required when entering certain height bands, taking threshold damage, or attempting specific maneuvers. Failure outcomes differ: stall, spin, altitude loss, or terrain collision rather than falling. Terrain has height — e.g., woods extend 2 height levels: a unit at height level 1 inside woods is at ground level, but the woods themselves occupy levels 1-2. A VTOL at level 2 or below is inside the woods and risks collision. Terrain height data per hex will be part of the tactical map generation.
- **Unit height**: mechs also extend 2 height levels (cockpit at level 2, legs at level 1). This affects line of sight — a mech standing behind level 1 woods can see over them (its cockpit at level 2 is above the terrain), but level 2 terrain (hill, building) blocks LOS. Aerospace units have height as their operational altitude. LOS calculation compares the highest point of attacker and target against the height of intervening terrain hexes.
- **Ground vehicles** (tracked, wheeled, hover, vtol, wi ge): restricted by motive type — hover needs water/flat, wheeled needs roads/flat/light forest, tracked handles most terrain but has higher costs in rough. Each motive type's forbidden terrain and cost multipliers stored in `data/rules/terrain_movement.json`.
- **Aerospace**: no ground terrain restrictions; ignores terrain for movement and line of sight.

Pilot Skill Rolls use the unit's pilot skill as the target number with modifiers from terrain/velocity/damage. Aerospace uses `gunnery_air`/`piloting_air` skills; vehicles use `gunnery_ground_vehicle`/`piloting_ground_vehicle`; mechs use `gunnery_mech`/`piloting_mech`.

The `movement_mp` field on `TacticalUnit` stores base MP; terrain cost multipliers reduce effective MP per hex entered. Motive damage from vehicle crits reduces effective MP directly (already implemented in CombatResolver).

### Combat Phase Flow (stable)

Tactical combat proceeds in phases. Each phase has declaration then resolution. The order is fixed; additional phases (artillery declaration) may be inserted as rules coverage expands.

1. **Initiative**: both sides roll 2d6. Loser goes first, winner goes second, alternating. Winner is guaranteed to move/fire at least one unit last.
2. **Movement**: alternating rounds between initiative loser and initiative winner. A side with significantly more units moves multiple per round. PSRs/control checks processed as they occur (skid ends movement; failing to stand does not if MP remains). Movement type must be specified before declaring movement.
3a. **Declare fire**: alternating, same per-round rules as movement. Torso twists and turret direction declared here.
3b. **Resolve fire**: back-and-forth resolution but all damage applied *simultaneously* — a component damaged during this phase still fires if it was declared.
3c. **PSRs from damage**: one roll per trigger, all at the cumulative modifier accrued this phase. Damage thresholds are per-phase (movement, fire, physical).
4a. **Declare physical attacks**: torso twist from firing phase applies (e.g., a mech may punch its rear arc if it twisted there during declaration).
4b. **Resolve physical attacks**: same damage and PSR rules as fire phase.
