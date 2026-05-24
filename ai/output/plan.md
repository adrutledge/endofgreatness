# Project Plan: End of Greatness BattleTech Simulation

## I. Core Vision and Objectives

**Goal:** To create a full-fidelity, turn-based grand strategy/tactical simulation game engine mimicking the rulesets and lore of BattleTech (Inner Sphere setting, starting 1
January 3025).

**Scope Management:** The initial phase will be **Single Player Only (SP)**, focusing on stability and the core gameplay loop (Strategic $\rightarrow$ Planetary $\rightarrow$
Tactical).

**System Design Principle:** All operations must be handled via discrete, verifiable **Game Ticks** (Day/Turn). State changes must be atomic and tracked by the database.

## II. Architecture Design

We will utilize a Microservice-oriented architecture built around the specified stack to ensure scalability and separation of complex simulation logic.

### A. Backend Services (Golang)

The backend will be responsible for all complex simulation, state persistence, and calculation.

1. **Core Simulation Engine Service (CSE):**
   _**Function:** The heartbeat of the game. Manages the game tick flow (Strategy $\rightarrow$ Planet $\rightarrow$ Tactics). Executes rule checks (e.g., movement costs, upkeep
   calculations, initiative resolution).
   _ **Key Modules:**
   _`TickManager`: Controls the flow of time, handles advancing time, and pausing/unpausing layers.
   _ `EventResolver`: Processes random events (planetary/strategic).
   _`ConflictResolver`: Executes the rules for Combat (BattleMech Manual).
   _ `ResourceCalculator`: Handles all resource expenditure and gain (C-Bills, Ammo, Salvage Value, Reputation).

2. **State & Persistence Service (SPS):**

   - **Function:** Handles all database interactions, ensuring transactional integrity. Manages unit state, map state, and campaign progress.
   - **API Focus:** High throughput for reading and updating large quantities of entity data (e.g., updating 50 units' HP after a battle).

3. **Lingo & Lore Service (LLS):**

   - **Function:** A lookup engine for all rules and constants. Loads and interprets external data files (e.g., MegaMek component definitions, Faction details, Rules tables).
   - **Input:** MegaMek/JSON rule sets.
   - **Output:** Structured data usable by the CSE (e.g., "Atlas has 10 tons of firepower and costs X upkeep").

4. **Websocket Gateway:**
   - **Function:** Manages persistent, bi-directional connections between the client and the server, essential for real-time tick advancement and displaying combat updates.

### B. Frontend (React/TypeScript)

The frontend is the UI layer, designed to present the state derived from the backend.

1. **Component Hierarchy:** Needs highly reusable components for maps, unit displays, combat logs, and menus.
2. **State Management:** Must handle the massive, asynchronous state changes originating from the backend (e.g., receiving a battle report and updating dozens of unit status
   indicators instantly).
3. **Design Focus:** Implementing the Dark/Light theme switch and ensuring accessibility for detailed data visualization.
4. **i18n:** Structure all text elements using i18n libraries from the start.

### C. Database (Postgres)

Postgres is ideal for its robust transactional capabilities, JSON/GIS support (for map coordinates), and complex data relationships.

## III. Detailed Data Model (Schema Outline)

The database must be normalized to support the complexity of unit composition and hierarchical relationships.

| Table             | Key Data Stored                                                                                                           | Relationships/Notes                        |
| :---------------- | :------------------------------------------------------------------------------------------------------------------------ | :----------------------------------------- |
| `GameSession`     | `SessionID`, StartDate, CurrentDay, CurrentTick, GameState (Active/Paused), CurrentMapID                                  | **Primary Global Tracker.**                |
| `StrategicUnit`   | `UnitID`, Name, Composition (Reference to `OperationalUnit`), UpkeepRate, CommanderID                                     | Manages the highest level of hierarchy.    |
| `OperationalUnit` | `UnitID`, Name, Composition (Reference to `TacticalUnit`/`OperationalUnit`), CommanderID, Roles (Patrol, Frontline, etc.) | Supports the hierarchical                  |
| structure.        |
| `TacticalUnit`    | `UnitID`, Name, ModelDefinition (MegaMek ID), CurrentLocation (Planetary Hex), Status (Active, Disabled, Destroyed)       | The physical combat element.               |
| `UnitComposition` | `MasterUnitID`, `SubUnitID`, `Relation` (e.g., Parent-Child)                                                              | Handles the entire unit hierarchy mapping. |
| `UnitPersonnel`   | `UnitID`, Role (Combatant, Medic, Admin), Count, Status                                                                   | Tracks non-combatants.                     |
| `UnitCombatStats` | `UnitID`, Components (Mech/Vehicle), AmmoPool (ResourceType: Ammo/Fuel), Integrity (HP/Shields), TechLevel                | Detailed combat tracking (loaded from      |
| MegaMek/input).   |
| `Planet`          | `PlanetID`, Name, Coordinates, HexMapData (Adjacency/Movement Cost)                                                       | The map structure for planetary combat.    |
| `Location`        | `LocationID`, PlanetID, HexCoordinates (X, Y), Type (City, Wilderness, Base)                                              | Specific points of interest on the map.    |
| `Faction`         | `FactionID`, Name, ReputationValue, GoverningLaws, Objectives                                                             | Tracks political context.                  |
| `Contract`        | `ContractID`, FactionIssued, FactionTarget, ContractType (Raid, Garrison), StartDate, GoalState, RewardCBills             | Manages the overarching goal.              |
| `ResourceLog`     | `LogID`, Date, ResourceType (C-Bills, Ammo, Salvage), AmountChange, Source (Battle/Contract/Purchase)                     | Transaction history and auditing.          |

## IV. Development Milestones (Phased Approach)

To manage complexity, the development is broken down into four major phases.

### Phase 1: Minimum Viable Product (MVP) - Static Setup and Core Movement

**Goal:** Establish the full data model and successfully simulate movement and resource tracking across the Strategic and Planetary layers without combat.

- **Focus:** Backend Persistence, Core State Machine.
- **Features:**
  1. Basic User Authentication (Stub).
  2. Database Migration scripts for all core tables.
  3. Strategic Layer: Display of star systems and planets (Static map).
  4. Unit Definition: Manual input of a single Strategic Unit composed of 2 Operational Units, composed of 1 Tactical Unit (e.g., 1 MWMech, 1 Support Vehicle).
  5. Movement Logic: Implement day-tick movement (Jumpship/Dropship) consuming abstract transport costs.
  6. Resource Tracking: Basic C-Bill tracking.
  7. Planetary Layer: Basic hex-based map traversal with travel time calculation.

### Phase 2: Core Campaign Gameplay Loop (Strategic & Planetary)

**Goal:** Implement the primary macro-game loop, including contracts, upkeep, and basic random event resolution.

- **Focus:** Rule Engine, AI/GM Simulation Logic.
- **Features:**
  1. **Contract System:** Create, track, and reward contracts (C-Bills, Reputation gain/loss).
  2. **Unit Upkeep:** Implement monthly/daily salary and maintenance deduction from C-Bills.
  3. **Role Assignment:** Implement logic for distributing Operational Units into Patrol, Maneuver, Frontline, etc., on the planetary map.
  4. **Planetary Events:** Implement basic Random Event generation based on location (e.g., "Bounty Hunters Detected," "Supply Line Disrupted").
  5. **Resource Gathering:** Successful contract completion results in C-Bills and/or Salvage Value added to the resource pool.
  6. **UX:** Implement the day-advance clock and pausing capability.

### Phase 3: Combat Implementation and Fidelity (Tactical)

**Goal:** Integrate complex combat rules and unit interactions, moving from macro-simulation to micro-simulation.

- **Focus:** CSE/ConflictResolver logic, Detailed Component Management.
- **Features:**
  1. **Combat Tick:** Transition the CSE into a turn-based resolution mode, pausing the Strategic/Planetary clock.
  2. **Damage/Damage Mitigation:** Implement HP, Shield, Armor, and component damage tracking.
  3. **BattleMech Combat Resolution:** Implement the core turn structure (Movement $\rightarrow$ Action $\rightarrow$ Advance).
  4. **Weapon System Logic:** Tracking ammo expenditure (at the operational level) and damage calculation (Roll vs. Defense/Armor).
  5. **Personnel & Support:** Incorporate personnel loss and its effect on unit capabilities.
  6. **Salvage:** Post-combat calculation of salvageable equipment and value.
  7. **UI:** Design the tactical combat overlay interface (mini-map, damage indicators, command panel).

### Phase 4: Polish, Advanced Simulation, and Content

**Goal:** Finalize quality of life, expand content, and perfect the simulation experience.

- **Focus:** Polish, UX/UI, Lore Depth.
- **Features:**
  1. **Full Tech Implementation:** Polish UI/UX based on user testing.
  2. **Advanced Events:** Implement reputation-gating events (e.g., "High Reputation allows us to bribe a local militia").
  3. **Component Loading:** Fully integrate the MegaMek format loading for dynamic unit creation.
  4. **Internationalization:** Complete i18n support across all layers.
  5. **Metrics:** Integrate Prometheus metrics endpoints for operational data tracking (e.g., Units Lost/Day, C-Bills Spent/Contract).

## V. Technical Requirements Mapping & Implementation Notes

| Requirement                                                                               | Component/Service | Implementation Detail                                                                                                        | Notes                                                        |
| :---------------------------------------------------------------------------------------- | :---------------- | :--------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------- |
| Server Persistence                                                                        | SPS (Go/Postgres) | Mandatory use of database transactions for all state changes (e.g., Battle resolution must commit all unit damage/movement   |
| simultaneously).                                                                          |
| Stub Auth/Auth                                                                            | SPS (Go)          | Simple JWT implementation for session management.                                                                            | Non-critical for initial MVP, but required architecture.     |
| Metrics                                                                                   | All Services      | Expose `/metrics` endpoints compliant with Prometheus standards.                                                             | Track state changes, resource flow, and computational load.  |
| Database Migrations                                                                       | SPS (Go)          | Use a library (like `golang-migrate`) to manage version control for the schema.                                              | Essential for repeatable development cycles.                 |
| Themes/i18n                                                                               | Frontend (React)  | Use context/provider patterns for theme switching; utilize React i18n library.                                               | Ensures the UI is robust and scalable for different markets. |
| Time Management                                                                           | CSE (Go)          | Implement a robust `TimeService` handling UTC time, day ticks, and the transition between the three distinct layers of time. | Must accurately account                                      |
| for non-linear time progression (e.g., pausing the strategic map during tactical combat). |
| Data Loading                                                                              | LLS (Go)          | Build a robust parser that can ingest standardized external data formats (e.g., JSON, CSV, or custom MegaMek parsers).       | This minimizes hardcoded rule                                |
| definitions.                                                                              |

## VI. Agent Task Breakdown (For AI Implementation)

The AI agents should be organized into specialized teams based on the technical services defined above.

### 🛠️ Agent Team 1: Backend Core Logic (CSE & SPS)

- **Focus:** State Machine Design, Game Rule Implementation.
- **Tasks:**
  1. Design the `GameSession` state flow (Enum/State Machine).
  2. Develop the `TickManager` state machine.
  3. Implement the `ResourceCalculator` with transaction logic.
  4. Develop the complex logic for **BattleMech combat resolution** using the parsed ruleset.
  5. Write CRUD APIs for all entity models.

### 📜 Agent Team 2: Data and Lore Management (LLS)

- **Focus:** Parsing, Modeling, and Lookup.
- **Tasks:**
  1. Develop the data ingest pipeline for MegaMek and other rule sets (e.g., Unit Stats, Weapon Damage Profiles).
  2. Design the hierarchical data structures to represent unit composition.
  3. Implement the `Faction` and `Contract` data models, including reputation scoring rules.
  4. Develop the Random Event generation system (pulling from structured lore files).

### 🌍 Agent Team 3: Simulation Geometry & Movement (SPS & CSE)

- **Focus:** Spatial Math, Graph Theory, Pathfinding.
- **Tasks:**
  1. Implement Hex-based movement and pathfinding algorithms (Dijkstra's or A\*).
  2. Develop the travel time calculation logic (Jumpships vs. Dropships vs. Ground Movement).
  3. Implement the unit deployment role logic (Calculating travel time and combat readiness based on assigned role).

### 🎨 Agent Team 4: Frontend and UX (React/TS)

- **Focus:** User Interface, State Visualization, Interactivity.
- **Tasks:**
  1. Build the multi-panel dashboard (Strategic Map, Planetary Map, Combat Log).
  2. Implement component state management to display real-time changes (e.g., HP bars reducing during a battle).
  3. Build the unit customization/composition interface, utilizing data from the LLS.
  4. Implement the UI logic for theme switching and localization.
