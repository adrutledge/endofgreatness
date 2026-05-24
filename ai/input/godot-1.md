# Project Plan: End of Greatness (BattleTech Simulation)

## I. Core Game Architecture Overview

The game is a grand strategy simulation that blends resource management, political negotiation, and tactical combat. The core loop operates on a cycle of **Strategy $\rightarrow$ Logistics $\rightarrow$ Action $\rightarrow$ Combat $\rightarrow$ Reset**.

### A. Game State Management (The Singleton)

All systems must interact through a centralized `GameStateManager` (or a similar Singleton pattern). This manager tracks time (Calendar Date, Day), resources, unit locations, and the status of all active contracts.

**Global State Variables:**

- `CurrentDate`: (Year, Month, Day) - Starts 1 January 3025.
- `ActiveContracts`: List of active contracts.
- `StarSystemState`: Dictionary of all known star systems (ownership, infrastructure, reputation, local events).
- `Factions`: Dictionary of all major factions (reputation, goals, history).
- `PlayerState`: Current C-Bills, Global Reputation, Inventory.
- `OperationalUnitLocations`: Dictionary mapping operational units to their current star system/planet.

### B. Simulation Layers

1. **Strategic Layer (Global):** Handles interstellar travel, contract negotiation, resource transfer (C-Bills), and high-level political/reputation changes. (Map: Star System Nodes).
2. **Logistics Layer (System/Operational):** Handles jumpship rentals, dropship deployment, movement time calculation, and unit maintenance/repair (at base). (Map: Star Systems and Planets).
3. **Planetary Layer (Operational/Tactical):** Handles in-system movement, encounter generation, combat deployment, and mission progress. (Map: Hex Grid).
4. **Tactical Layer (Combat):** Handles unit combat resolution. (Map: Detailed Hex Grid/Grid Map).

---

## II. Data Structure Design (The Schemas)

Before any module is built, the canonical data structures must be finalized.

| Entity              | Key Properties                                                                                             | Relationships                                        | Notes                                             |
| :------------------ | :--------------------------------------------------------------------------------------------------------- | :--------------------------------------------------- | :------------------------------------------------ |
| **Time**            | `Date`, `DayTick`, `IsPaused`                                                                              | N/A                                                  | Time advances automatically unless paused.        |
| **Location**        | `StarSystemID`, `PlanetID`, `Coordinates`                                                                  | Parent/Child (Planet $\rightarrow$ Operational Unit) | Determines travel time and logistics.             |
| **Faction**         | `ID`, `Name`, `GovType`, `ReputationCurve`, `Goals[]`                                                      | Tracks `Reputation` with Player.                     | Reputation is a number (e.g., -100 to +100).      |
| **TacticalUnit**    | `Type`, `ID`, `CrewCount`, `Components[]`, `CurrentStatus`                                                 | Belongs to `OperationalUnit`.                        | _No HP._                                          |
| **Component**       | `Name`, `Type` (Weapon/Armor/Engine), `LocationOnUnit`, `Condition` (Operational/Damaged)                  | Belongs to `TacticalUnit`.                           | Can be damaged/repaired.                          |
| **OperationalUnit** | `ID`, `Units[]`, `DeploymentRole`, `CurrentPlanet`, `ContractID`                                           | Belongs to `StrategicUnit`.                          | The core mobile unit group.                       |
| **Contract**        | `ID`, `Issuer`, `Target`, `ActivityType`, `Duration`, `GoalMetrics[]`, `RewardCBills`, `SalvagePrivileges` | Links `OperationalUnit` to Mission.                  | Drives the core mission flow.                     |
| **Personnel**       | `Name`, `Role`, `Rank`, `Stats`, `RelationshipMap`                                                         | Assigned to `OperationalUnit`.                       | Handles administrative and logistical complexity. |

---

## III. Module Breakdown and Agent Specialization

The project should be divided into six major, semi-independent modules, each assigned to a specialized AI agent team.

### 🛠 Module 1: Simulation & Game State (Core Logic Agent)

- **Function:** Manages the passage of time, unit movement logic, and overarching state consistency.
- **Key Functions:**
  - `AdvanceTime(days)`: Increments the date, resolves any day-dependent events.
  - `CalculateTravelTime(origin, destination, transport)`: Utilizes lore-consistent jump/dropship time costs.
  - `CheckDeploymentFeasibility(unit, planet, contract)`: Ensures all logistics requirements are met (C-Bills, transport availability).
  - `ResolveTickEnd(actions)`: Processes all unit movements and status changes at the end of a single day tick.

### 🛡 Module 2: Combat Resolution (Rules Engine Agent)

- **Function:** Implements _Total Warfare_ rules for all combat scenarios (Tactical and Operational).
- **Inputs:** Unit positions, unit configurations, threat declaration.
- **Outputs:** Damage report (Component damage, Crew casualties), Unit Status change.
- **Key Functions:**
  - `ResolveTacticalCombat(Map, Units, Actions)`: Turn-based combat loop, handling weapons fire, armor penetration, etc. (Requires random dice/roll generation).
  - `HandleCrewCasualty(Unit, InjurySource)`: Updates crew status and determines if the unit is deactivated.

### 💰 Module 3: Economy & Logistics (Financial Agent)

- **Function:** Manages money flow (C-Bills), resources, and deployment logistics.
- **Key Functions:**
  - `PayMaintenance(operational_units)`: Deducts upkeep costs from Player C-Bills.
  - `ProcessSalvage(contract, total_damage)`: Calculates and allocates salvage rewards based on contract terms.
  - `RentTransport(type, origin, destination)`: Handles the abstract cost model for hiring jumpships/dropships.
  - `PurchaseComponents(unit, component_type, count)`: Deducts costs and updates unit component inventory.

### 📜 Module 4: Contract & Diplomacy (Narrative Agent)

- **Function:** Handles the political and mission-based elements.
- **Key Functions:**
  - `GenerateContract(player_reputation, potential_targets)`: Uses algorithms based on player reputation and active faction goals to propose contracts.
  - `UpdateReputation(contract, success, failure, faction)`: Adjusts player reputation with both issuing and target factions.
  - `DetermineMissionOutcome(metrics, success_checks)`: Checks if contract objectives (e.g., salvaging enough material, defeating target forces) are met.

### 📰 Module 5: Event Generation (Random Agent)

- **Function:** Inject narrative variability into the simulation.
- **Key Functions:**
  - `GenerateStrategicEvent(system, faction_reputation)`: High-level events (e.g., system conflict, political treaty, resource discovery).
  - `GeneratePlanetaryEncounter(location, enemy_strength)`: Encounter on a planet before deployment (e.g., ambush, resource skirmish).
  - `GeneratePlayerEvent(player_state)`: Personal events (e.g., personnel illness, diplomatic opportunity).

### 💻 Module 6: User Interface & Presentation (UI/UX Agent)

- **Function:** The presentation layer; handles all user interaction and visualization across different map types.
- **Key Components:**
  - **Star Map UI:** Visualization of star systems, jump routes, and player assets.
  - **Planetary Map UI:** Hex grid map, displaying movement time and active unit positions.
  - **Tactical Map UI:** Turn-based grid, displaying detailed unit components and line-of-sight.
  - **Logistics UI:** Dedicated panel for personnel, inventory, and C-Bill transactions.

---

## IV. Phased Development Plan (Milestones)

This development plan assumes the AI agents work in tandem, building upon completed API contracts between modules.

### Phase 1: Core Simulation Backbone (Minimum Viable Product - MVP)

- **Goal:** Allow a simple unit to travel between two systems and end combat successfully.
- **Focus:** Modules 1, 2, 3 (Core Logic & Basic Combat/Economy).
- **Deliverables:**
  1. Basic `GameStateManager` initialized with dates, simple location data, and unit schematics.
  2. Stubbed Combat Module (Module 2): Ability to resolve a simplified "Hit/No-Hit" combat encounter.
  3. Basic Movement Logic (Module 1): Calculating travel time between two points and deducting base C-Bills for transport.
  4. Basic UI (Module 6): Displaying the star map, unit status, and C-Bill balance.
- **Testing Focus:** State integrity and fundamental resource deductions.

### Phase 2: Operational Layer & Interaction (Contract Focus)

- **Goal:** Introduce missions, goals, and the full logistics chain.
- **Focus:** Modules 1, 4, 3 (Contract Generation, Logistics, Mission Rules).
- **Deliverables:**
  1. Functional Contract Generation (Module 4): Defining the start and end conditions of a contract.
  2. Planetary Deployment Logic (Module 1): Operational units move onto a hex grid and occupy an active `Contract` state.
  3. Advanced Logistics (Module 3): Implementing repair costs, personnel assignments, and component purchase/replacement.
  4. Core UI Enhancement (Module 6): Displaying the hex map, mission objectives tracker, and repair/resupply menus.
- **Testing Focus:** Does unit movement respect travel time? Are contract rewards correctly calculated upon completion?

### Phase 3: Depth and Variation (Narrative Focus)

- **Goal:** Build complexity through uncertainty, politics, and advanced rules.
- **Focus:** Modules 5, 4, 2 (Random Events, Diplomacy, Advanced Combat).
- **Deliverables:**
  1. Operational Event Engine (Module 5): Implementing random encounters during deployment/transit.
  2. Reputation System Integration (Module 4): Connecting contract success/failure directly to faction reputation changes and triggering related events.
  3. Advanced Combat (Module 2): Fully implementing _Total Warfare_ damage, armor, and weapon statistics, requiring detailed input from unit schematics.
  4. Personnel System Integration (Module 1/6): Handling injury tracking, and personnel assignments.
- **Testing Focus:** Stability and variety. Do the random events make logical sense? Is the reputation system causing believable political outcomes?

### Phase 4: Polish, Polish, Polish (The Final Product)

- **Goal:** Polish the user experience, optimize performance, and implement secondary lore mechanics.
- **Focus:** Modules 6 (UI/UX), and integrating remaining lore specifics.
- **Deliverables:**
  1. Implementation of Dark/Light Themes and Internationalization (Localization framework).
  2. Advanced UI Flow: Streamlining the handoff between Strategic $\rightarrow$ Planetary $\rightarrow$ Tactical views.
  3. Lore Event Hooks: Implementing historical event triggers (e.g., "Planet X ownership changes hands").
  4. Balance and Tuning Pass: Adjusting costs, repair rates, and combat parameters to ensure balanced gameplay.

---

## V. Technical Stack & Implementation Notes (Godot Specific)

### A. Architecture Pattern

- **Singleton/Service Locator:** Use a Singleton pattern for the `GameStateManager` and `CombatEngine` to ensure all modules access the single source of truth.
- **Signal/Observer Pattern:** Use Godot Signals extensively. When the `GameStateManager` changes (e.g., `date_advanced`), it must emit a signal that the UI, Combat Engine, and Event Generator modules listen for and react to.

### B. UI/UX Implementation

- **UI Framework:** Utilize Godot's Control Nodes for a flexible, modular interface.
- **Thematic Switching:** Implement a global variable (`ThemeMode: Dark/Light`) that triggers a UI redraw/asset swap, ensuring consistency.
- **Input Handling:** A centralized `InputManager` handles the complex input flow (e.g., clicking a unit on the star map vs. clicking a component on the tactical map).

### C. Data Management

- **Persistent Data:** Use JSON or Godot's native resource system (`.tres`) for storing static data (Unit Schematics, Faction Profiles, Map Data).
- **Runtime Data:** All dynamic game state (C-Bills, Unit locations, Inventory) must reside in the live `GameStateManager`.

### D. Scripting Best Practices

- **Code Separation:** Strictly adhere to the Single Responsibility Principle. The Combat Module _calculates_ combat; the UI Module _displays_ combat results.
- **Error Handling:** Implement robust logging and state rollback mechanisms to handle complex chains of simulation events (e.g., if a contract goal fails due to an unexpected random event, the state must revert correctly).
