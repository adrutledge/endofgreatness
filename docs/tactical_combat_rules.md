# Tactical Combat Rules Reference

**Last updated:** 3025-06-04
**Plan reference:** `ai/plan.md` — Phase 4 (Operational), Phase 5 (Rules Engine), Phase 6 (Tactical Layer)

---

## Initiative
One initiative roll per player (allied units count as separate players). The commander's tactics skill is a modifier to initiative. Certain mech quirks and special pilot abilities may further modify the initiative bonus.

## Phase Flow

1. **Initiative** — both sides roll 2d6. Loser moves/fires first, alternating. Winner guaranteed at least one unit last.
2. **Movement** — alternating rounds per initiative order. Uneven numbers of units multi-move per round. Movement type declared before moving.
3a. **Declare fire** — alternating, same per-round pattern. Torso twists and turret directions declared here.
3b. **Resolve fire** — back-and-forth resolution. All damage *simultaneous* — a component damaged this phase still fires if declared.
3c. **PSRs from damage** — resolved at end of phase with cumulative modifier accrued this phase.
4a. **Declare physical attacks** — torso twist from firing phase applies.
4b. **Resolve physical attacks** — same damage and PSR rules as fire phase.

## Critical Hits

### Trigger
Any internal structure damage triggers a crit confirmation — whether from armor overflow, through-armor crits, ammo explosions, or any other source.

### Confirmation Roll (2d6)
- **8–9**: 1 crit
- **10–11**: 2 crits
- **12**: limb blown off (arm/leg) or 3 crits (torso/head)

### Dice Convention
Almost every roll in BattleTech uses d6. Slot tables are resolved with cascading d6 rolls: for a 12-slot location, roll 1d6 — 1–3 selects the first six slots, 4–6 selects the second six — then another 1d6 selects the specific slot within that half.

### Slot Allocation
Roll on the location's slot table (1d6 for 6-slot locations, cascading 2d6 for 12-slot). Reroll on:
- Empty slot
- Slot-tax component (Endo Steel, Ferro-Fibrous — `is_flexible: true`)
- Slot already critted in a previous phase

If **zero** crittable slots exist before the first crit is allocated → all crits transfer inward.
If crittable slots exist → crits stay in this location; overflow past available unfilled slots is wasted.

### Transfer Chain
- Arm/leg → same-side torso
- Side torso → center torso
- Head → center torso
- Center torso → dead (mech destroyed)

If a leg's damage transfers to a side torso that is **already destroyed**, it continues to center torso.

### Slot Sizes
- Arms: 12 slots
- Legs: 6 slots
- Head: 6 slots
- Torsos: 12 slots

### Quad Mechs
Hit location tables same as bipeds except front legs substitute for arms.
- Left front leg → left torso, right front leg → right torso
- Rear legs also chain to same-side torso (matching biped legs)
- **Front leg** is blown off when its side torso is destroyed (like an arm)
- **Rear leg** stays attached when its side torso is destroyed (like a biped leg)
- Partial cover horizontal: all four legs covered. Vertical: only matching side covered. CT always visible in any partial cover.

### Blown-Off Locations
Location and all components left intact on the hex where the unit was standing.
- Tracked as `blown_off: true` on the ComponentLocation with hex position.
- During **movement phase**, a unit in the same hex may spend MP to pick up a blown-off limb.
- Club usable in subsequent **physical attack phase**.
- Damage/to-hit depend on wielding mech's stats, not source mech's.
- Picking up a club precludes DFA/charge that phase.
- Post-combat: blown-off components recoverable for salvage or limb reattachment.

### Per-Component Crit Effects (data-driven)
Each component JSON defines:
- `crit_effect_type`: `"weapon"`, `"ammo"`, `"actuator"`, `"gyro"`, `"engine"`, `"heat_sink"`, `"none"`
- `explodes_on_crit`: bool (Gauss ammo = no, Gauss rifle = yes)
- `explosion_damage`: int (override for custom explosion yield)
- `crit_effect_data`: dict (per-type: heat_per_hit, psr_modifier, actuator_type, etc.)

**CritEffectRegistry** maps `crit_effect_type` strings to handler classes. Handlers return `{heat_delta, psr_modifier, explosion, disabled, messages}`.

| Type | First hit | Second | Third | Tracks |
|------|-----------|--------|-------|--------|
| Weapon | Disabled | — | — | `crit_hits` per slot |
| Ammo | May explode | — | — | `crit_hits` per slot |
| Actuator | Apply penalties | — | — | `disabled` |
| Gyro | +PSR modifier for phase | Destroyed | — | `crit_hits` per slot |
| Engine | +5 heat | +10 (+15 total) | Mech disabled | `crit_hits` per slot |
| Heat sink | Disabled | — | — | `crit_hits` per slot |

### PSRs from Crits
Not resolved immediately. Each adds its modifier to the phase's accrued PSR total. All PSRs (damage, movement, gyro, leg actuator) resolved at end of phase with cumulative modifier.

## Ammo Explosions
- Damage skips armor — applies directly to internal structure
- Triggers a new crit confirmation at that location
- Cascading is expected and intended
- Data-driven per component (Gauss ammo = no explosion, Gauss rifle = 20 damage)

## Ammo Tracking

### Weapon Ammo Group
Each weapon defines its ammo group in its component JSON (e.g., `"ammo_group": "SRM"`). The group links the weapon to compatible ammo bins.

| Convention | Examples |
|------------|----------|
| Same group, multiple launcher sizes | SRM-2/4/6 → `"SRM"`, LRM-5/10/15/20 → `"LRM"`, SRT-2/4/6 → `"SRT"`, LRT-5/10/15/20 → `"LRT"` |
| Same group, sharing with standard AC | Light AC/2 → `"AC2"` (shares with standard AC/2), Light AC/5 → `"AC5"` (shares with standard AC/5) |
| Own group per size | Ultra AC/2/5/10/20 each have their own group (UAC/2 ammo ≠ UAC/5 ammo). LB-X AC each have their own group. Rotary AC/2/5 each have their own group. |
| Own group per ammunition type | Machine gun, vehicle flamer, etc. |

### Shots Per Ton
Each weapon component defines its base `shots_per_ton` for standard ammunition (SRM-2 = 50, SRM-4 = 25, SRM-6 = ~16, MG = 200, etc.).

Each ammo component (by sub_type) defines a `shots_multiplier` against the weapon's base:
- Standard ammo: `"shots_multiplier": 1.0`
- Inferno SRM: `"shots_multiplier": 1.0` (same as standard)
- Tandem-charge SRM: `"shots_multiplier": 0.5` (half as many shots per ton)
- Caseless AC/5: `"shots_multiplier": 2.0` (twice as many shots per ton, pending confirmation)

Effective shots per ton for a given weapon + ammo combination = `weapon.shots_per_ton × ammo.shots_multiplier`. **Flag for confirmation:** rounding convention — likely ceil (round up), not floor or nearest.

Machine gun half-ton ammo is handled by the ammo component's `"tonnage": 0.5` — the bin holds half the effective shots.

### Ammo Pooling (Supply Only)
When ammo pooling is enabled (`pool_group` in ammo component JSON), pooling applies **only to supply and purchasing** — not to in-combat feeding. An SRM-2 ammo bin cannot feed an SRM-4 launcher during combat. Pooling affects how ammo is bought, stored, and tracked in inventory, but combat consumption remains per-bin.

### Consumption
Each shot fired from a weapon deducts one shot from its assigned ammo bin. Weapons are linked to specific bins at the start of combat (or assigned during declaration). When a bin is empty, weapons fed from it cannot fire. Machine gun ammo comes in full-ton (200 shots) and half-ton (100 shots) variants. Slot count = `ceil(tonnage)` (0.5t = 1 slot, 1.0t = 1 slot, 1.5t = 2 slots, 2.5t = 3 slots, etc.).

**Flag for rules verification:** When a weapon has access to multiple ammo bins of different sub_types (e.g., two SRM-4s with one bin of inferno and one bin of standard), can each weapon select which sub_type to fire per round? How does allocation work across multiple weapons sharing bins of mixed subtypes? The inference is per-weapon per-round selection, but the exact rules need confirmation.
- Upcoming edition changes handled via edition overlay system (per-entry `edition` field in component JSONs)

## Line of Sight

### Hex Scale
- Tactical hex: 30m diameter
- Mech: ~10–15m tall, exactly 2 height levels for all game mechanics
- Two mechs cannot occupy the same hex tactically

### LOS Rules
- LOS is always **symmetrical**: if A can see B, B can see A
- **Edge bias**: when LOS falls exactly on the line between two hexes, the defender gets the advantage. The resolver computes two slightly offset paths (epsilon 0.05 hex widths on either side) and unions the hex sets. If either path would block LOS, LOS is blocked — the defender gets the more favourable result. No per-pair state needed.
- **Mechs do not block LOS** — a mech does not fill the hex it occupies (30m hex, ~10–15m mech). Intervening mechs are not obstacles.
- Edge bias is automatic, implicit, and requires no per-pair storage or phase-level state. The LOS resolver handles it transparently.
- **LOS cache**: results are cached per round (`LOSResolver.clear_cache()` at round start). Because LOS is symmetric, resolving `LOS(A, B)` also caches `LOS(B, A)` for free — the cache key is sorted by hex coordinates so both lookups hit the same entry.
- **Per-engagement instances**: every tactical engagement creates its own set of resolver objects (LOSResolver, CombatResolver, CritResolver, PSRResolver) as instances, not singletons. They connect to each other directly rather than through EventBus, avoiding data conflicts when multiple engagements are active simultaneously. No engagement ID filtering needed.

### Partial Cover
- **Horizontal** (low wall, rubble): lower-level locations covered. Quad: all four legs covered.
- **Vertical** (building corner, rock spire): only matching-side locations covered. Center torso always visible in any partial cover.

### PSR Triggers (data-driven, with failure effects)
PSR trigger definitions in `data/rules/psr_triggers.json`. Each entry:
```json
{
  "id": "skid_paved_turn",
  "condition": "run_after_turn_on_paved",
  "modifier": 1,
  "tags": ["skid"],
  "on_failure": {"ends_movement": true}
}
```

| Field | Purpose |
|-------|---------|
| `id` | Unique identifier |
| `condition` | Evaluated by the PSR resolver. Maps to a condition function or string key |
| `modifier` | PSR target number modifier added when this trigger fires |
| `tags` | Classification tags — `["skid"]`, `["jump"]`, `["gravity"]`, etc. |
| `on_failure` | Effects on a failed PSR (optional): `{"ends_movement": true}`, `{"damage_per_leg": 1}` (applies internal structure damage to each leg, triggering crit confirmations), etc. |

PSR failures that cause the mech to **fall down** (skid, jump with damaged actuators, run with damaged hip) end movement. Failing a roll to stand up does **not** end movement (you are already not moving; you are attempting to stand).

Players can toggle entire tag categories on/off at campaign start (e.g., "no skidding rules"). The PSR resolver filters the active trigger list by enabled tags before evaluating conditions. New triggers can be added by mods as JSON entries — no code changes.

**Examples of movement PSR triggers:**
1. Jumping with damaged leg actuators — PSR on landing, failure applies effect but does not end movement
2. Using run movement, turning on a paved hex, then continuing to move — PSR for skid, `ends_movement: true`
3. Using more MP than the 1g rating allows when in below-1g gravity — PSR on landing, `on_failure.damage_per_leg: 1` (1 IS damage to each leg, triggering crit confirmation rolls for each)

## Terrain & Movement

- Each hex costs 1 base day for speed-4 mech, scaled by slowest mech's walk MP × terrain multiplier
- Roads reduce cost to 1 day regardless
- Terrain multipliers: PLAINS/DESERT=1×, FOREST/ROUGH=1.5×, MOUNTAIN/URBAN=3×, WATER=impassable
- Movement uses A* pathfinding with terrain-weighted costs
- Per-type terrain effects deferred (mechs moderate everywhere, vehicles restricted by motive type, infantry have different costs)
- Terrain heights: woods extend 2 height levels, mechs are 2 height levels
- `movement_mp` stores base MP; terrain cost multipliers reduce effective MP per hex
- Motive damage from vehicle crits reduces effective MP directly

### Walk vs Run MP
- Walk MP is the base stat stored on `TacticalUnit.movement_mp`
- Run MP is derived: `run_mp = ceil(walk_mp * 1.5)`
- Any modifier to movement speed (damaged actuators, heat penalties, gravity multipliers, etc.) adjusts **walk MP** directly; run MP is recalculated from the adjusted value
- Jump MP is tracked separately and is not derived from walk MP

### Declaration
Movement type (walk/cruise, run/flank, jump) must be declared **before** any movement occurs. The declaration applies for the entire movement phase — a mech cannot change movement type mid-phase.

### Map Scale
The **planetary map** and the **tactical map** have entirely different movement rules. A planetary map hex is an abstract space that can encompass an entire battlefield. A tactical hex is exactly 30m in diameter. The entire tactical grid fits within a single planetary map hex. Movement rules documented in this file apply to the **tactical map** only.

### Jump Jets
- Jump rating = number of jump jets installed, cannot exceed walk MP (TM validation: jump jets > walk MP is an invalid design)
- If a jump jet's crit slot is hit, jump MP is reduced accordingly
- Heat-based movement reductions do **not** affect jump MP
- **Heat cost:** max(hexes_jumped, 3) heat added to the mech's heat scale per jump
- **Movement:** always 1 MP per hex regardless of terrain. Must take the shortest path between origin and destination
- **Height:** can cross terrain height differences up to their jump MP rating
- **PSR on landing:** certain situations (damaged leg actuators, missing legs, different gravity, etc.) trigger a Piloting Skill Roll on landing, resolved with the phase's cumulative PSR modifier

## To-Hit Resolution (GATOR)

**G** — Gunnery skill of the firing pilot (default 4).
**A** — Attacker movement: walk/cruise = +1, run/flank = +2, jump = +3. Stationary = 0.
**T** — Target movement (hexes moved): 1–2 = 0, 3–4 = +1, 5–6 = +2, 7–9 = +3, 10+ = +4 (rare, confirm). If target jumped, additional +1.

A mech that expended MP but did not leave its hex is **not** stationary — it is assumed to be shifting within the hex. Only truly **immobile** mechs (engine shut down, engine destroyed, pilot knocked out) receive a −4 to-hit penalty (applied as a negative modifier, effectively reducing the TN).
**O** — Other modifiers, cumulative:

| Situation | Mod |
|-----------|-----|
| Target in partial cover (including level-1 water) | +1 |
| Target in light woods | +1 |
| Target in heavy woods | +2 |
| Per light woods hex *between* attacker and target | +1 |
| Per heavy woods hex *between* attacker and target | +2 |
| Intervening woods total ≥ +3 | Shot impossible |
| Attacker firing pulse lasers | −2 |
| Attacker is prone | +1 |
| Target is prone, attacker adjacent | −2 |
| Target is prone, attacker not adjacent | +1 |
Note: target-in-woods modifier and intervening woods modifier are **separate and cumulative**. Only intervening woods count toward the +3 blocking limit. Prone can be voluntary or from a failed PSR. A prone mech counts as 1 height level tall — behind what would normally be partial cover (level-1 height), a prone mech is instead completely out of LOS.

**R** — Range bracket plus minimum range penalty:

| Situation | Mod |
|-----------|-----|
| Short range | 0 |
| Medium range | +2 |
| Long range | +4 |
| Extreme range | +6 (optional, confirm) |
| At exactly minimum range of weapon | +1 |
| Per hex below minimum range (beyond the first) | +1 each |

Ranges start at 1 (adjacent hex). Range 0 (same hex) is not a valid firing range for most weapons — they cannot fire at a target in their own hex.

Minimum range example: PPC (min range 3) at range 2 (one hex below min) = +2, at range 1 (two hexes below min) = +3. Total is summed **into the R value**, not O.

**Target number** = sum of G+A+T+O+R. Roll 2d6; ≥ TN = hit.

- If TN > 12, the shot is **impossible** (no roll made).
- If TN ≤ 2, the shot is an **automatic hit** (no roll made).
- Certain special situations (e.g., attacking a building from an adjacent hex) also produce automatic hits. When such an automatic hit applies, it also causes **all cluster sub-munitions to hit** and **ignores minimum range penalties**. These special situations are defined per case in the relevant rules.

## Minimum Range
Weapons with minimum range (PPC, LRM, etc.) apply a +1 penalty at exactly minimum range, and an additional +1 per hex below that. Example: PPC (min range 3) at range 2 = +1, at range 1 = +2, at range 0 = +3.

## Weapon Damage (standard BattleTech)
Standard values apply. Optional rules (e.g., increased AC damage) are edition-gated. Damage per weapon type to be catalogued as part of weapon data.

## Cluster Hits
Needs full cluster hit table from the rulebook. Example: for a cluster weapon with 2 sub-munitions (e.g., some SRM counts), 2–7 = 1 hit, 8–12 = 2 hits. Full table pending review.

## Heat Tracking

### Heat Accumulation
- Each weapon fired adds its heat value to the mech's heat scale
- Engine crits add +5 per hit (first = +5, second = +10 cumulative, third = mech dead)
- Heat sinks dissipate heat each turn based on type and count
- Standard heat sink: dissipates 1 per turn. Double heat sink: dissipates 2 per turn.
- Every mech must have at least 10 heat sinks of whatever type they are equipped with
- A mech **cannot mix** heat sink types — all must be standard or all must be double
- Standard heat table goes from 0 to 30

### Heat Effects
Escalating penalties as heat increases: to-hit modifiers, movement penalties, and at certain thresholds:
- **Ammo explosion checks:** made only when **crossing a threshold**, not for simply being above it (flag for later review)
- **Shutdown:** automatic at heat 30. Mech powers down.
- **Shutdown recovery:** heat sinks continue functioning while shut down. Heat tracks downward normally. When heat drops below 30, the mech rolls to restart (using the worst shutdown threshold's target number). When heat drops below all shutdown thresholds, the mech restarts automatically.
- Optional rule to extend the heat table exists (flag for later).

---

## Movement Display (tabletop convention → UI)

Each mech on the tactical map shows a colored square with a number:
- **Color** = movement type used this phase (walk, run, jump, stationary)
- **Number** = TMM + target's terrain modifier. If the mech is immobile (shut down, destroyed engine, KO'd pilot), the -4 is included in the number.

This replaces the tabletop convention of a color-coded die where 6 pips stood for 0 (a constraint of dice faces, not needed in digital).

## Tactical Engagement UI — Threat & Decision Support

### Exposure Heatmap
Candidate hexes are colour-coded by threat level from the enemy's perspective:
- **Green** — minimal enemy return fire (low probability of being hit)
- **Yellow** — moderate exposure (some enemies have viable shots)
- **Red** — open to multiple enemies with high-probability shots

The heatmap incorporates each enemy's TN against that hex — accounting for their weapons' ranges, their pilot gunnery, intervening terrain/LOS — not just a raw count of who has LOS. This is the same calculation the AI uses to evaluate position safety.

### Movement Heat Warnings
Movement heat cost is locked in at declaration. Before the player confirms movement, a warning is shown if the selected movement type would push heat over a threshold (shutdown check, ammo explosion roll, movement penalty). The same warning appears during fire declaration when selecting weapons.

### Facing Arc Display
After clicking a candidate destination to consider it, a transparent wedge overlay shows the unit's front/side/rear facing arcs relative to the hex grid. Each enemy unit falls into one arc, making it clear which facing would be exposed. The arc only appears after a click (not on hover) to minimise map clutter. Armor status per facing is available separately (paper doll, not on the map).

## Tactical Engagement UI — Targeting Display

When an attacker is selected and considering fire declarations, the UI should eliminate "scratch and sniff" targeting (manually checking each target):

- **TN displayed on/near each potential target** — calculated from GATOR using the selected weapon's range. Shows the player at a glance whether a shot is viable.
- **No-LOS targets clearly marked** — hexes or units without line of sight are visually distinct (greyed out, no TN shown, or a blocked icon).
- **Weapon arc visualization** — when a weapon is selected, its firing arc and range brackets (short/medium/long) are overlaid on the tactical map, so the player can see which hexes fall in which bracket without counting hexes.

This applies to both the attacker's units (showing what they can see and hit) and when the AI is declaring (same calculations, AI just evaluates the same data the UI would show).

## Tactical Engagement UI — Movement Display

When a unit is selected and a movement type is being considered (declaration only happens when movement selection is complete):

- **Reachable hexes highlighted** — precomputed in one BFS pass from the unit's origin, constrained by the selected movement type's available MP.
- **LOS coverage from each destination** — any hex outside LOS from a given destination is greyed out (tinted, not removed) on that destination's display, so the player can see what targets would be visible from each potential position. Computed as part of the same pass: for each reachable hex, LOS to each known enemy is checked. With a run of 8 (~200 hexes) and ~12 enemies, that's ~2400 LOS checks — under a frame with a well-optimized LOS resolver.
- **Weapon range overlay during movement** — a weapon can be selected during movement consideration. The range overlay is shown only for the currently **hovered destination hex**, not all reachable hexes at once, to keep the map readable. As the player moves the cursor over candidate hexes, the overlay updates to show range bands from that hex. Combined with LOS greying, the player sees at a glance: "from this hex I can see two enemies, one in short range for my AC/5." A walk of 4 only considers hexes within 4 hexes; a run of 8 within 8 hexes. This keeps the search space small regardless of map size.
- **TMM bands** — each reachable hex shows the TMM the unit would have after reaching it, based on path length from origin. Drawn as colour bands or numeric labels on the hex.
- **Intrinsic terrain modifier** — hexes with intrinsic modifiers (woods, partial cover) highlight those modifiers separately, so the player knows both the TMM and defensive terrain bonus for each destination.
- **PSR warnings** — not precomputed per hex. Shown when the player clicks a candidate destination to consider it. A separate **confirm button** shows a prompt: "PSRs of X, Y, and Z with failure consequences of W" listing each trigger that fires along the path, its modifier, and what happens on failure (movement ends, damage per leg, etc.). The player can review the risks before committing.
- **Interaction flow:** hover previews range and LOS; click sets the considered destination and displays PSR details + a transparent arc wedge overlay showing the unit's front/side/rear facings relative to the hex grid; confirm button commits the movement. The arc wedge only appears after a click (not on hover) to keep the map clean.
- **Exposure heatmap** — candidate hexes are colour-coded by threat: green = minimal enemy return fire, yellow = moderate exposure, red = open to multiple enemies. The heatmap incorporates each enemy's TN against that hex (accounting for their weapons' range, their pilot gunnery, and intervening terrain/LOS), not just a count of who can see it.
- **Heat-overload warnings** — shown at movement declaration (movement heat is locked in after declaration) and again at fire declaration when selecting weapons. Warns if the total heat would cross a threshold causing a shutdown check, ammo explosion roll, or movement penalty.
- **The AI** uses the same resolver and pathfinder. When evaluating a path, it considers whether a PSR risk is worth taking based on the pilot's skill, the consequence of failure (fall = movement ends, possible damage), and the tactical value of the destination.

Pathfinding is a single BFS/Dijkstra pass from the origin, capped by max movement MP. On a 30×30 map with a run of 8, this is ~200 hexes evaluated, not 900 — a trivial per-frame cost regardless of how many units move.

## AI Decision Layer

AI tactical decisions combine four weighted factors, driven by a data-defined personality per unit or faction. The AI evaluates all four for each candidate action (move to hex X, fire weapon Y at target Z) and picks the highest-scoring option. The per-unit calculation is capped by the reachable hex range (max movement MP) and weapons in range. A unit's full weapon list is filtered to only those that can reach a given target (range bracket + LOS), so a Warhammer WHM-6R might have 8 weapons but only 3 in range of a distant target. Typical evaluation: ~200 hexes × 12 targets × 3 in-range weapons ≈ 7,200 checks. Encounters may have a battalion (36+) on a side and more than two sides — in those cases the evaluation scales linearly with enemies present, but each check is a trivial arithmetic operation on precomputed data. The AI evaluates all visible enemies, not just those on a single opposing side (multi-sided engagements: treat each non-allied unit as a potential target or threat).

### Multi-Side & Ally Handling
- Allied units (same side, employer forces in support) are excluded from target/threat lists
- Non-allied units in multi-side engagements are all potential targets
- `ally_support_weight` influences positioning near allies

### Physical Threat Component
Each enemy's threat score includes a physical attack risk term:
- Adjacent enemies with high melee damage potential (tonnage, hatchet/sword capable) get a threat bonus
- Enemies within charge/DFA range (requires movement to reach the target) are flagged as a setup risk — the threat applies in the *next* turn, not the current one, since the attacker must move into position before charging
- Prone enemies contribute zero physical threat
- This biases the AI toward knocking down or destroying close-range threats before they can act
- The term is O(1) per enemy — a single arithmetic weight on the existing threat score

### Focus Fire & Overkill Avoidance
Focus fire emerges naturally without central coordination:
- Each unit independently evaluates threat scores
- `focus_fire_weight` pulls units toward the same high-threat target
- `kill_potential` drops as a target accumulates damage (remaining armor/structure decreases), so overkill is naturally avoided — ally B sees low kill_potential on a target ally A is already likely to destroy and shifts targets
- A single shared threat value per enemy (updated as damage is declared) ensures all units read the same state

### Damage Allocation (hit location)
Hit location is 2d6:
| Roll | Location |
|------|----------|
| 2 | Center torso (possible crit) |
| 3–4 | Right arm |
| 5 | Right leg |
| 6 | Right torso |
| 7 | Center torso |
| 8 | Left torso |
| 9 | Left leg |
| 10–11 | Left arm |
| 12 | Head |

Rear shots use the same table but damage applies to rear armor (effectively less armor per location). Partial cover: leg hits are absorbed by the cover. Quad mechs have roughly double the chance of a leg hit (four legs instead of two).

The AI estimates kill_potential by integrating over the hit table: expected damage to center torso kills the mech, expected damage to a side torso risks transfer to CT, expected damage to legs risks knockdown. Integrated as a weighted sum per target.

### Spotter Coordination
A spotter must declare spotting **before** the indirect-fire shot may be declared. This creates an ordering constraint: the AI must decide "should this unit spot this round?" for each potential spotter before the LRM carrier evaluates its shots. The AI handles this by evaluating spotter candidates in the same pass as movement — a unit that can both spot and fire directly decides which is more valuable based on its weapons and position. With LOS cached, the spotter check is O(friendlies) per LRM target per potential spotter — a table lookup.

**Flag for rules verification:** A spotter may still fire its own weapons while spotting, but the unit being spotted for takes a penalty when the spotter also fires. Confirm whether this penalty applies and what its value is.

**Flag for rules verification:** A single spotter declaration can serve multiple indirect-fire units. Confirm this is correct — one spotter, many indirect fire shots benefiting from the same declared spot.

### Posture Transitions
Posture is evaluated each round per unit:
- Time pressure (enemy approaching objective completion) → shift toward aggressive
- Exposed high-value enemy target → opportunistic aggression
- Allies routing → defensive posture or aggressive cover (personality-dependent)
- Situation hopeless → forced withdrawal in good order (better skill tiers maintain firing lines while retreating)
- Evaluated O(1) per round per unit

### Forced Withdrawal
A per-unit binary state triggered by specific game rule conditions (flag for user to provide rules — example: 1 engine hit + 1 gyro hit at the same time, or any two torso locations without front armor). When forced withdrawal is active, the unit must proceed toward the nearest map edge each turn but may still fire. May path around environmental hazards (water with depleted leg armor → choose different route or pick a different edge). Better skill commanders exploit forced withdrawal — maintaining cover and firing lines while retreating rather than routing. Player is notified when forced withdrawal triggers for any unit (ally or enemy).

### AI Personality (data-driven)

`data/ai/personalities.json`:
```json
{
  "id": "aggressive_brawler",
  "name": "Aggressive Brawler",
  "aggression": 2,
  "heat_threshold": 0.7,
  "ammo_conservation": 0.2,
  "cover_preference": 0.3,
  "flank_preference": 0.6,
  "focus_fire_weight": 1.5,
  "retreat_health": 0.2
}
```

| Field | Range | Effect |
|-------|-------|--------|
| `aggression` | 0–2 | 0 = defensive (hold, safe shots), 1 = balanced, 2 = aggressive (close range, risky shots, push exposed) |
| `heat_threshold` | 0–1 | Fraction of heat scale before the AI holds fire or switches to cooler weapons. Heat penalises walk speed and adds to **O** in GATOR at higher levels |
| `ammo_conservation` | 0–1 | Probability weight of conserving ammo vs firing (1 = never waste ammo on low-odds shots) |
| `cover_preference` | 0–1 | Weight given to moving to cover vs moving toward objective/enemy |
| `flank_preference` | 0–1 | Weight given to flanking vs frontal positioning |
| `focus_fire_weight` | 0–2 | Multiplier on threat score when multiple units target the same enemy (1.0 = no focus) |
| `pilot_skill` | −1–6 | See pilot skill table below. Affects gunnery, piloting, heat management, physical attacks, personal engagement decisions |
| `command_skill` | −1–6 | See command skill table below. Affects focus fire coordination, initiative sinking, forward planning, posture transitions, ally support, and forced withdrawal tactics. Defaults to `pilot_skill` if no commander is present |

**Pilot skill levels:**

| Lvl | Name | Gunnery | Piloting | Heat management | Ammo | Role | Physical | Terrain | Target priority |
|-----|------|---------|----------|----------------|------|------|----------|---------|----------------|
| −1 | Unskilled | 7+ | 7+ | Unaware — fires everything, overheats, shuts down | Fires until empty | No concept | Doesn't plan physical attacks | Walks through hazard terrain unknowingly | Shoots nearest enemy |
| 0 | Ultra-green | 6 | 6+ | Knows heat is bad but not how to manage it | Only notices empty bins | Vague — knows some mechs are bigger | Will punch if adjacent, no setup | Avoids obvious hazards | Shoots whatever is in front |
| 1 | Green | 5 | 5 | Understands dissipation; avoids shutdown but will overheat regularly | Notices low ammo, won't change behaviour | Knows brawler vs sniper in theory | Sets up kicks (easy, high damage) | Uses partial cover if convenient | Prefers damaged targets |
| 2 | Regular | 4 | 5 | Manages heat to stay below penalties most of the time | Holds fire when below ~25% | Recognises role correctly most of the time | Punches when arms are free | Prefers cover over open | Basic threat assessment |
| 3 | Veteran | 3 | 4 | Understands delivered heat risk (inferno); budgets heat capacity for expected incoming | Estimates engagement length from opfor count | Positions by role consistently | Kicks knocked-down enemies, follows up physical chains | Uses height advantage actively | Focuses high-threat targets |
| 4 | Elite | 2 | 3 | Manages heat curve — fires hot deliberately, plans the cooldown turn to waste minimal heat sink capacity | Plans ammo usage across full engagement, not just current bin | Switches roles as battlefield changes | Combines physical with movement for positioning | Routes through cover, plans cover-to-cover moves | Priority targets by mission impact |
| 5 | Legendary | 1 | 2 | Predicts own heat curve 2+ turns ahead; coordinates heat with team (e.g., staggered cooldowns) | Allocates ammo across multiple targets; saves insurance shots | Role is fluid — adapts to team composition gaps | Uses physical attacks to create space, not just damage | Predicts enemy movement to cut off routes | Targets command / C3 / spotters first |
| 6 | Heroic | 0 | 1 | Perfect heat knowledge — always within 1 heat of optimal dissipation; exploits enemy overheating | Never wastes a shot; knows when not to fire | Role is instinctive — creates new roles as needed (pseudo-spotter, decoy) | Physical attacks are deliberate fight-enders | Terrain is a weapon, not just cover | Targets enemy morale and cohesion |

**Command skill levels:**

| Lvl | Name | Description | `strategic_depth` | Focus fire | Initiative sinking | Forced withdrawal | Ally support |
|-----|------|-------------|-------------------|------------|-------------------|-------------------|--------------|
| −1 | Unskilled | No coordination | 0 | None — every unit for itself | None — random declaration order | No concept — units fight until destroyed | None |
| 0 | Ultra-green | Barely understands coordination | 0 | Minimal — units occasionally shoot same target by luck | Basic — slower units move first some of the time | No concept — same as unskilled | None |
| 1 | Green | Surface understanding | 0 | Units with same weapon type prefer same target | Slow units usually move first | Knows withdrawal exists but executes poorly (exposes back, drops cover) | Doesn't hinder allies but won't help |
| 2 | Regular | Basic coordination — baseline | 0 | Consistent focus fire on damaged targets | Consistent: slow/cheap first, valuable last | Executes basic withdrawal toward nearest edge | Avoids blocking ally fire lanes |
| 3 | Veteran | Understands unit types and roles | 1 | Focus fire on highest-threat; adapts when overkill is likely | Orders by unit_value / survivability; accounts for range | Withdraws in good order — maintains cover while retreating | Positions to cover ally retreat or flank |
| 4 | Elite | Thorough grasp of combined arms | 1 | Coordinates multi-unit firing solutions (breaching, bracketing) | Considers enemy initiative order when sinking | Exploits withdrawal — uses retreating units as bait or rearguard | Dedicates units to ally escort / screening |
| 5 | Legendary | Outplans most opponents; handles large forces | 2 | Pre-planned target assignments before contact | Predicts opponent's declaration order and counters | Creates false withdrawal to lure enemies into traps | Integrated ally support — screen, spot, ECM cover |
| 6 | Heroic | Coordinates entire regiments mid-battle | 2 | Effortless — all units act as one without explicit commands | Instinctive — always has the right unit at the right phase | Withdrawal is a weapon — kiting, channeling, ambush | Ally force multiplies everything |

**Strategic depth by command skill** is included in the command skill table above. `strategic_depth: 1` (Veteran+) enables single-turn lookahead: positions for next turn's shot. `strategic_depth: 2` (Elite+) enables two-turn lookahead: flanking, charge setup, positioning chains. Regular and below react to current board state only.

Units without an explicit personality inherit the faction default. Canon characters (notable pilots, commanders) can have unique personalities.

### AI Evaluation

**1. Threat score per enemy** = `expected_damage × kill_potential × range_factor × physical_threat`. Expected damage accounts for hit probability (TN vs pilot gunnery). Kill potential is higher for units with exposed structure or already-damaged locations. Range factor decays beyond the weapon's ideal bracket. Focus fire weight multiplies threat when multiple AI units target the same enemy. Physical threat adds weight for adjacent enemies with melee capability (tonnage, hatchet, charge/DFA).

**2. Position advantage** = `sum(TN to each visible enemy) − sum(enemy TN to this hex)`. Net positive = good position (you hit them better than they hit you). The AI evaluates this for each candidate hex and weights it by `cover_preference` and `flank_preference`.

**3. Heat budgeting** — before firing, the AI sums the heat cost of selected weapons. If total heat would exceed `heat_threshold × max_heat`, it evaluates which weapon to drop by **damage per heat** × **relative TN**. The hottest weapon with the worst damage-per-heat ratio is dropped first, not simply the hottest. A PPC at range 7 (short range, 10 damage, 10 heat) may be worth keeping over a medium laser (medium range, 5 damage, 3 heat) because the PPC has better TN and deals more damage per shot. The AI also considers movement heat (locked at declaration) when planning its fire phase.

**Higher skill tiers** evaluate whether enemies are within range to deliver bonus heat (inferno SRMs, flamers, plasma rifles). Rather than avoiding fire entirely, they weigh the **probability × consequence** of incoming heat:
- What is the enemy's TN to hit with heat-delivering weapons?
- What heat threshold would be crossed if they hit? (5 = −1 walk MP, 8 = +1 to-hit in O, etc.)
- The expected heat = `sum(enemy_hit_probability × delivered_heat_per_weapon)`
- If expected heat would push into a penalty tier, the pilot considers whether avoiding that penalty matters more than the damage output they'd give up by cooling their shot
- Green/Regular pilots ignore incoming heat risk entirely

**4. Ammo budgeting** — the AI avoids firing low-probability shots when ammo is low. Better skill tiers estimate engagement length from unit count, type, and weight on the field and plan ammo usage accordingly. A green pilot doesn't think about ammo. A veteran pilot with 12 LRM shots and 20 turns of fighting ahead conserves ammo from turn 1.

### Personality Examples

| Personality | agg | heat | cover | flank | focus | pilot | cmd | posture | Use case |
|-------------|-----|------|-------|-------|-------|-------|-----|---------|----------|
| `cautious_defender` | 0 | 0.5 | 0.9 | 0.2 | 1.0 | 2 | 2 | defensive | Garrison, militia |
| `balanced_line` | 1 | 0.6 | 0.6 | 0.4 | 1.2 | 3 | 3 | balanced | Standard front-line |
| `aggressive_brawler` | 2 | 0.7 | 0.3 | 0.6 | 1.5 | 4 | 3 | aggressive | Clan front-line, pirate leader |
| `sniper` | 0 | 0.4 | 0.8 | 0.5 | 1.0 | 3 | 3 | defensive | Long-range fire support |
| `scout` | 1 | 0.5 | 0.4 | 0.8 | 0.8 | 3 | 3 | aggressive | Fast flanker, spotter |
| `canon_commander` | 2 | 0.6 | 0.5 | 0.5 | 1.8 | 5 | 5 | balanced | Notable character, focus-fire doctrine |
| `green_novice` | 1 | 0.4 | 0.5 | 0.3 | 1.0 | 1 | 1 | balanced | Fresh recruit, poor at everything |
| `ace_pilot_rookie_cmdr` | 1 | 0.5 | 0.5 | 0.4 | 1.0 | 5 | 1 | balanced | Elite pilot, no tactical sense — fights well but positions poorly |

### Initiative Sinking
A unit declared earlier in a phase is an **initiative sink** — its action is committed while more valuable units wait to declare later, potentially forcing the opponent into disadvantageous declarations. Higher skill tier commanders use initiative sinking effectively.

Emergent behavior from this:
- Slower, less valuable units tend to move first (their movement matters less)
- High-damage, fragile, or tactically critical units declare last
- The AI selects declaration order based on: `unit_value / survivability`. Units with low value and high survivability sink initiative.
- This is O(n log n) sort per phase — trivial.

The AI runs all evaluations in a single pass over the candidate space, applying the personality weights to produce one score per action. The highest-scoring move/fire declaration is selected.

## Unit Size Definitions (guideline, can be fudged)

| Unit | Count | Notes |
|------|-------|-------|
| Lance | 4 | Mechs or vehicles. Basic tactical unit |
| Company | 12 | 3 lances |
| Battalion | 36 | 3 companies |
| Regiment | 108 | 3 battalions |

A typical tactical engagement involves 1–2 lances per side (4–8 units). Larger battles (company, 12+) are rare but supported by the AI evaluation (scales linearly with enemy count).

## Data-Driven Combat Files (to be created)

The following rule sets should be defined as data files, not hardcoded, to support edition changes and modding:

| File | Contents |
|------|----------|
| `data/rules/hit_locations.json` | 2d6 hit location tables per unit type (biped, quad, vehicle, aerospace), per arc (front, rear, left flank, right flank), per cover status. Editions may change flank determination. |
| `data/rules/heat_table.json` | Heat scale (standard 0–30, optional 0–60) with penalties per level: walk MP reduction, to-hit modifier, shutdown threshold, ammo explosion threshold. Optional extended table selected at campaign start. |
| `data/rules/cluster_hits.json` | Single 2d6 cluster hit table with columns per number of sub-munitions and rows for each roll (2–12). Current max is 20 (LRM-20); later editions add columns for 40 (HAG/40) and beyond. Not per-weapon — weapons reference the appropriate column by munition count. |
| `data/rules/physical_attacks.json` | Damage formulas, to-hit modifiers, and skill type per attack (punch=0, kick=-2, club=+1, charge=-1, DFA=-2, push=0). All physical attacks use **piloting** skill, not gunnery. Push does no direct damage but moves target 1 hex. DFA and charge also move the target. |
| `data/rules/psr_triggers.json` | PSR trigger definitions: condition, modifier, tags, on_failure effects (ends_movement, fall, damage_per_leg). |
| `data/ai/personalities.json` | AI personality definitions: pilot_skill, command_skill, aggression, heat_threshold, weapon/movement/terrain/physical affinities, posture, ally_support_weight, focus_fire_weight, cover/flank_preference. |
| Component JSONs | Each weapon component should define: damage, heat, range brackets (short/medium/long/extreme in hexes), minimum range, ammo_type, shots_per_ton, cluster_size (if applicable), and token_image (path to PNG with alpha). |

**Unit token rendering:** PNG with alpha for specific variants; fallback by unit type and weight class (light/medium/heavy/assault mech, light/medium/heavy vehicle, aerospace, infantry). Image path stored as a data field on the unit variant.

## Chained Falls / Pushes
When a mech is pushed or skids into a hex occupied by another mech, it pushes that mech one hex. This can chain — a congo line of pushes during movement or physical attacks, potentially causing falls at each step. The rules are intricate and the flow chart is complex.

**Implementation implications:**
- Push/charge/DFA resolution must loop: for each hex entered, check occupancy → if occupied, resolve push on occupant → if occupant moves into another occupied hex, repeat
- Each push in the chain can independently trigger a PSR for falling
- This can occur during both movement phase (skid) and physical attack phase (push, charge, DFA)
- **Flag for correctness pass** — the chain resolution order, simultaneous vs sequential handling, and edge cases (edge of map, pushing out of the engagement) all need rulebook verification

## Save System Integration Testing Strategy

### Goal
Verify that the full save/load cycle preserves all game state correctly across all systems (GameState, TimeManager, EconomySystem, ReputationSystem, PersonnelManager, RefitManager, InventoryManager, etc.). This catches regressions where a system adds a new field but forgets to serialise it.

### Architecture

A lightweight **ScenarioRunner** autoload (`src/testing/ScenarioRunner.gd`) is activated by the CLI flag `--test-scenario <path>`. It:

1. Boots the game normally (all autoloads load, DataManager inits)
2. Loads the scenario JSON file
3. Executes each step in sequence
4. Asserts constraints after each step
5. Reports pass/fail and quits

### Scenario File Format

Each scenario is a JSON file in `tests/scenarios/`:

```json
{
  "name": "Save and reload full campaign state",
  "edition": "classic",
  "steps": [
    {
      "action": "new_game",
      "params": {"faction": "merc", "company_name": "Test Unit"}
    },
    {
      "action": "advance_time",
      "params": {"days": 90}
    },
    {
      "action": "assert",
      "constraints": {
        "player.current_balance": {"gt": 0},
        "time_manager.total_days": {"eq": 90},
        "personnel_manager.personnel_roster.size": {"gt": 0}
      }
    },
    {
      "action": "save_game",
      "params": {"name": "integration_test_save"}
    },
    {
      "action": "load_game",
      "params": {"name": "integration_test_save"}
    },
    {
      "action": "assert",
      "constraints": {
        "player.current_balance": {"gt": 0},
        "player.current_planet": {"eq": "Galatea"},
        "time_manager.total_days": {"eq": 90},
        "personnel_manager.personnel_roster.size": {"gt": 0},
        "economy_system.accumulated_expenses": {"ge": 0}
      }
    }
  ]
}
```

### Supported Actions

| Action | Purpose |
|--------|---------|
| `new_game` | Generate a starting force via `StrategicUnitGenerator` |
| `advance_time` | Run `TimeManager.advance_day()` N times |
| `save_game` | Call `SaveManager.manual_save(name)` |
| `load_game` | Call `SaveManager.load_game(path)` |
| `assert` | Check constraints against current state |

### Constraint Language

Constraints are dot-separated paths into the game state, compared against expected values:

| Operator | Meaning |
|----------|---------|
| `eq` | Equals |
| `gt` | Greater than |
| `ge` | Greater than or equal |
| `lt` | Less than |
| `le` | Less than or equal |
| `ne` | Not equal |
| `exists` | Key exists and is not null |
| `type` | Type of value (e.g., `"int"`, `"string"`, `"Dictionary"`) |

### Adding Regression Tests

When a new field is added to any game system:
1. Add the field to the relevant serialiser/deserialiser in `SaveSerializer`
2. Add a constraint to an existing scenario that asserts the field's expected value after load
3. If no existing scenario exercises the field, create a new scenario with steps that populate it

### Running

```bash
godot --path . --test-scenario tests/scenarios/save_full_campaign.json
```

The exit code is 0 on pass, 1 on failure. CI runs all scenarios in `tests/scenarios/` as part of `test-integration`.

## Known Holes (not yet documented)

- Full cluster hit table
- Damage location allocation (2d6 hit location table per unit type)
- Heat dissipation per heat sink type
- Full heat table with all threshold effects
- Ammo consumption rates (shots per ton by weapon type)
- Jump jet movement and heat cost
- Vehicle motive damage and crew effects
- Aerospace altitude and control rolls
- Indirect fire and spotting
- ECM, stealth, and electronic warfare
- Multi-hex units
- Victory conditions for tactical engagements
- Morale and withdrawal
- Specialty munitions (inferno, smoke, precision, etc.)
- DFA, charge, and physical attack damage formulas
- **Flag: PSR modifier accrual across movement phase** — do movement-phase PSR modifiers (skid, standing, leg damage) accumulate across the entire movement phase like fire-phase PSRs do, or is each movement PSR resolved independently? Needs rules confirmation.
- Facing, torso twist, and firing arcs
- Stacking and unit proximity
- TM validation: jump jets > walk MP is an invalid design (MechValidator)
