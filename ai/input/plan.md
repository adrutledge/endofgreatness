# End of Greatness

## Overview

This is an application to play a BattleTech campaign

## Features

- Computer GM
- Random events in strategic and planetary layers
- Contract generation
- Strategic unit (mercenary organization), operational unit (regiments, battalions, companies, lances), and tactical unit (individual maneuver units, 1 vehicle)
- Strategic units are made up of a hierarchy of operational units defined by the user
  - A strategic unit has multiple operational units
  - An operational unit has multiple smaller operational units and/or tactical units
  - No operational unit or tactical unit may exist in multiple units higher in the hierarchy
  - Each operational unit has a commander, in the case an operational unit does not directly include tactical units, the highest ranked member of any tactical unit subordinate to the operational unit is designed as the commander
- Implements "Campaign Operations" rules as published by Catalyst Game Labs
- Battles are handled using "BattleMech Manual" as published by Catalyst Game Labs
- All types of unit personnel from rules are handled: combatants, technicians, administrators, medics, other misc non-combatants
- Three layers: strategic map of the Inner Sphere as published in the BattleTech setting, map of the planet contracted to operate on, tactical combat map
- Multiple contract types: garrison, cadre, raid, assault, etc
- A contract comprises multiple tactical combats on one planet, building towards achieving the overarching goal of the contract
- The player should be able to distribute operational units to different roles on the planetary map:
  - Patrol: operational unit assigned to scouting
  - Manuever: operational unit assigned to rapid response
  - Frontline: operational unit assigned for main battle
  - Training: operational unit assigned for its commander to train subordinates included in the unit
  - Auxillary: operational units assigned as dedicated reinforcements
  - None: operational units not elgibile for tactical play
- When a contract begins, an on-planet base is assigned or decided by the player depending on the contract type and terms
- Planetary maps are hexes with travel time based on number of hexes from on-planet base to deployment locations
- Deployments of operational units to planetary locations takes some number of days during which they may encounter enemy forces or random events
- Primary strategic resource is money denominated in C-Bills
- Secondary strategic resource is reputation. Reputation is tracked for:
  - The Mercenary Review Board organization
  - Each major political faction in the setting
- Contracts earn C-Bills for completion
- C-Bills can be used for:
  - Purchasing ammunition and components
  - Purchasing tactical units
  - Strategic unit upkeep such as personnel salaries and other items as specified in Campaign Operations
  - Tactical unit maintenance
  - Abstractly renting jumpships and dropships for transport to/from a contract
- Reputation is increased with the faction that issued the contract and decreased with the faction the contract targeted
  - Some targets (rebels, pirates, civilians) do not track reputation
- Positive or negative reputation with a faction may allow different events to generate or additional options in events
- The only resources gathered on a planet are the result of battles or random events

## Tech Stack

- Frontend: React/TypeScript
- Backend: Golang
- Database: Postgres
- Metrics: Prometheus
- Connectivity: WebSockets

## Technical Requirements

- Server side persistence
- Stub authentication and authorization
- Metrics
- Database migrations
- Dark and light UI themes
- Internationalization

## Design notes

- Operations on both the strategic and planetary layers operate in single day ticks advancing automatically unless paused
- Player may pause the strategic/planetary ticks at any time
- Tactical layer is turn based, pausing planetary/strategic ticks until fully resolved
- Dropships and jumpships can be rented using abstract costs for transit as documented in Campaign Operations if the strategic unit does not own them
- Tactical units may not be repaired or resupplied during combat scenarios

## Setting lore accuracy

- Events from lore should occur at the appropriate dates: Planetary ownership changes, faction creation, etc
- The game should start 1 January 3025
- Transit between star systems utilizies jumpships as in BattleTech lore
- Transit within a star system utilizes dropships with distances consistent to published lore from jump point to planet
- The strategic unit does not have a planet it is based on or owns
- Support component and tactical combat unit type definitions loading using existing MegaMek format files
- A tactical unit is a mech, vehicle, or other piece of combat equipment and its crew. Each unit has multiple components as defined in the BattleTech setting
  - Replacements for components can be purchased and are used as defined in BattleTech rules to replace damaged equipment
  - Some weapons such as autocannons, machine guns, and missiles require ammunition which is tracked at the operational level to replace used ammo on the tactical level

## Additional Notes

- Create a detailed plan from which AI agents can build this application
- Single player initially
- Battlefield salvage is handled and contracts can specify what percentage or in what form (salvaged equipment versus the value of the salvage)
- Strategic and planetary layers are per day on an actual calendar
- This is only utilizing the BattleTech setting as published by Catalyst Game Labs
