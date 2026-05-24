# End of Greatness: Technical Development Plan

This document outlines the comprehensive technical architecture and development plan required to build a single-player, grand-scale grand strategy wargame utilizing the BattleTech universe. Given the complexity and the multiple interlocking rulesets, the design emphasizes **modularity, data-driven design, and a robust rules engine**.

---

## 1. Project Goal and Scope Definition

**Goal:** To create a turn-based, layered simulation game that models the economic, logistical, political, and military operations of a mercenary group (The Strategic Unit) within the Inner Sphere, governed by established Catalyst Game Labs rules (BattleTech, Total Warfare, etc.).

**Complexity Rating:** Extremely High. Requires sophisticated state management and interconnected subsystems.

**Target Platform:** Godot Engine (Desktop focus).

**Core Design Philosophy:** The game must operate as a simulation first, and a game second. All core systems (combat, logistics, economy) must function deterministically according to the source materials.

## 2. Technical Architecture and Stack

### 2.1. Architectural Pattern: Layered Engine Design

The entire application will be structured around a **State Machine** to manage the active game layer (Strategic $\rightarrow$ Operational $\rightarrow$ Tactical) and the passage of global time.

### 2.2. Core Systems Breakdown

| System                     | Role                                                                                                                                                                                                                                | Technical Implementation Focus                                                                                                                                        |
| :------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Time/Simulation Engine** | Controls the passage of the global calendar (Year/Month/Day). Manages the transition logic between layers and ticks.                                                                                                                | Central singleton/Global State Manager.                                                                                                                               |
| **Rules Engine (Crucial)** | Does not contain logic; merely executes rules. It must be designed to accept inputs (e.g., "Fire Weapon A from Unit B against Target C with Damage X") and return outputs (e.g., "Damage applied to Component Y, Status: Damaged"). | **Rule Set Database (JSON/XML)** fed into procedural scripts. This allows easy updating of house rules or minor rule adjustments without recompiling the core engine. |
| **Data Management System** | Handles all persistent game data (Lore, Units, Components, Factions, Resources, History).                                                                                                                                           | **SQLite Database** (for rapid access and structured storage) backed by structured Godot/GDScript classes (for runtime interaction).                                  |
| **UI Management**          | Handles presentation logic, data visualization, and user input.                                                                                                                                                                     | Modular Godot Scenes (separate screens for each layer/function).                                                                                                      |

### 2.3. Data Model: The MegaMek/Unit Structure

Since the `MegaMek` format is required for units, all units, regardless of type (BattleMech, APC, Infantry Platoon), must conform to a standardized data dictionary structure.

**Unit/Component Data Dictionary (Standardized):**

1. **Unit ID:** Unique identifier.
2. **Type:** (e.g., 'BattleMech', 'APC', 'Infantry Platoon').
3. **Quality Rating:** (A-F).
4. **Components List:** (Reference IDs to the Component Database).
5. **Movement/Stats:** (Speed, Crew Capacity, etc.).
6. **Status:** (Functional, Damaged, Destroyed).
7. **Inventory:** (Ammunition, Supplies).

**Component Data Dictionary:**

1. **Component ID:** Unique identifier.
2. **Parent Unit Type:** (e.g., 'BattleMech Arm', 'Hovercraft Turret').
3. **Component Type:** (Weapon, Armor, Engine, Cargo).
4. **Quality Rating:** (A-F).
5. **Stats:** (Damage/Range/AP, Armor Value, etc.).
6. **Current Condition:** (Intact, Damaged, Destroyed).

## 3. Feature Implementation Breakdown (Layer by Layer)

### 3.1. Strategic Layer (The "Meta" Layer)

**Purpose:** Macro-level management, economics, and political maneuvering.
**Core Mechanics:**

1. **Star Map Navigation:** Display a 2D map of star systems.
2. **Time Tracking:** Global time ticker. Must handle jumping time costs.
3. **Personnel Management:** Inventory management system for Administrators, Medics, and Technicians.
   - _Logic:_ Technicians' time budget must be accounted for when calculating repair time.
   - _Logic:_ Injury tracking and healing (Medics).
4. **Economic Loop (C-Bills/Reputation):**
   - **Input:** Income (Contracts/Salvage/Taxes).
   - **Output:** Expense tracking (Personnel wages, upkeep, transport costs).
5. **Contract System:**
   - A dedicated interface for browsing available contracts.
   - **Calculation:** Determines required units, duration, expected compensation, and resource expenditure (Transport/Personnel).
6. **Lore & Event Generation:** Random event pool tied to the current date/location (e.g., "Planetary Ownership Change," "Faction Conflict").

### 3.2. Operational Layer (The Campaign Layer)

**Purpose:** Detailed logistics, deployment, and movement within a single planet.
**Core Mechanics:**

1. **Planetary Map:** A hex grid overlay. Must accurately depict terrain types and travel time modifiers.
2. **Deployment Phases:**
   - Units must transition from the transport (Dropship) and arrive at a specific hex.
   - Deployment takes time (days) and can be interrupted by combat or random encounters.
3. **Market System:**
   - The planetary market must aggregate equipment available from _all_ present factions (except the target).
   - The interface must allow purchasing components, units, and supplies.
4. **Movement & Line of Sight:** Standard hex-grid movement rules must be enforced, factoring in terrain penalties.
5. **Combat Trigger:** When units occupy the same hex and combat is triggered, the layer _pauses_ and transitions to the Tactical Layer.

### 3.3. Tactical Layer (The Combat Layer)

**Purpose:** Turn-based resolution of combat using the Total Warfare system.
**Core Mechanics:**

1. **Map Generation:** Takes the current Operational Layer hex and generates a smaller, contained tactical hex grid (e.g., 30-60 hexes per side).
2. **Turn Resolution:** This must be a sequential loop (Unit A fires, Unit B moves, Unit A fires, etc.).
3. **The Rules Engine in Action:** Every combat action (Attack, Move, Repair, Cargo drop) must pass through the engine.
   - _Damage Logic:_ Calculate damage $\rightarrow$ Identify Component $\rightarrow$ Reduce component HP/Structure $\rightarrow$ Check for destruction $\rightarrow$ Apply penalties.
   - _Movement Logic:_ Apply movement rules based on terrain and remaining mobility components.
4. **Simulation End:** The layer only resolves when all units are immobilized, destroyed, or the combat duration (TT rules) is complete.
5. **Post-Combat Phase:** Calculate salvage (if permitted by contract), repair possibilities (using Technicians and resources), and map unit statuses.

## 4. Development Milestones (Phased Approach)

The project must be broken down into logical phases to ensure iterative testing and prevent "analysis paralysis."

### Phase 1: Core Simulation & Data Backbone (Focus: Data Model, Time, Basic Movement)

- **Goal:** Implement the ability to track units and move them across layers without complex combat resolution.
- **Deliverables:**
  - Operational Database and Unit/Component Data Model fully established.
  - Global Time Ticker and State Machine built (Strategic $\leftrightarrow$ Operational $\leftrightarrow$ Tactical).
  - Basic UI scaffolding (Dark/Light themes, i18n structure).
  - Implementation of basic unit movement across the hex grid (Operational Layer).
  - Basic resource tracking (C-Bills).

### Phase 2: Strategic & Operational Depth (Focus: Economics, Logistics, Scale)

- **Goal:** Make the game playable from a macro perspective.
- **Deliverables:**
  - Full Strategic Layer implementation (Star Map movement, Jumpship logistics).
  - Personnel and Administrative system (Hiring, wages, skills).
  - Contract Generation system (Input/Output calculation).
  - Planetary Market and Deployment system finalized.
  - Initial Placeholder Combat Trigger: When units meet, the game transitions to a minimal combat state (e.g., simple damage roll, no complex component logic).

### Phase 3: Combat Rules Engine (Focus: Total Warfare Implementation)

- **Goal:** Fully implement the combat simulation.
- **Deliverables:**
  - **The Rules Engine (Beta):** Must handle all mechanics from Total Warfare (Damage rolls, Armor penetration, Component destruction, Status tracking).
  - Operational Layer $\rightarrow$ Tactical Layer transition fully tested.
  - Tactical Layer resolution (Turn-by-turn combat simulation).
  - Salvage calculation and application.

### Phase 4: Polish, Polish, Polish (Focus: Lore, UX, Polish)

- **Goal:** Achieve feature completeness, polish the UI, and integrate remaining lore elements.
- **Deliverables:**
  - Detailed Event System (Scripted narrative encounters tied to lore and date).
  - Refinement of all UI/UX elements across all three layers.
  - Full Internationalization implementation.
  - Balancing passes and stress testing the entire simulation loop (e.g., running a full 5-year campaign).

## 5. Summary of AI Agent Roles

To manage this complexity, the development team (AI agents) should be assigned to specialized modules:

| Module Name                  | Primary Focus                                                               | Dependencies                      | Output                                              |
| :--------------------------- | :-------------------------------------------------------------------------- | :-------------------------------- | :-------------------------------------------------- |
| **Data/Lore Engine Agent**   | Unit, Component, and Faction data definition, database integrity.           | None.                             | Complete, structured data dictionary (JSON/SQLite). |
| **Strategy & Economy Agent** | Strategic Layer logic, Contract generation, C-Bill tracking, Personnel.     | Data/Lore Engine.                 | Functional Strategic Map and UI systems.            |
| **Operational Agent**        | Operational Layer logic, Hex movement, Market mechanics, Deployment timing. | Data/Lore Engine, Strategy Agent. | Operational map rendering and transition system.    |
| **Combat Agent**             | The Rules Engine, Combat math, Component damage/repair cycle.               | Data/Lore Engine (Crucial).       | Robust, testable combat simulation module.          |
| **UI/UX Agent**              | Presentation layer, Cross-platform consistency, State visualization.        | All Agents.                       | Clean, usable, and responsive Godot Scenes.         |
