# End of Greatness

## Overview

This is an application to play a BattleTech campaign

## Source materials

- Catalyst Game Labs
  - _Total Warfare_
  - _A Time of War_
  - _Campaign Operations_
  - _TechManual_

## Definitions

- Component:
  - An individual piece of equipment on a tactical unit such as:
    - A weapon
    - Ammunition storage to supply a weapon during tactical layer play
    - An intrinsic part of a given tactical unit type such as engine, mobility equipment, cockpit
    - Other equipment such as cargo space, electronic warfare, etc
    - Armor
    - Internal structure
  - Can be damaged or destroyed as documented in "Total Warfare"
  - Can be repaired as documented in "Campaign Operations"
  - Can be removed or added to a tactical unit based on tactical unit construction rules as documented in "TechManual"
  - Exist in a discrete location on a tactical unit
  - Components do not have HP
  - Components have a quality rating from F for the worst to A for the best that affects how easily they are repaired but not their effectiveness
  - Components may be repairable, destroyed, or undamaged
  - Factory new can be C, B, or A depending on manufacturer quality
- Tactical Unit:
  - The smallest maneuver element on the tactical layer. These may be:
    - An infantry platoon
    - A single hovercraft
    - A single wheeled vehicle
    - A single tracked vehicle
    - A single BattleMech
    - A single VTOL
  - Each requires a number of crew based on the type of vehicle and its configuration
  - Components exist in discrete locations on the unit such as an arm on a mech or the turret on a hovercraft
  - Different types of tactical units have different locations with some being optional on a specific type
  - Designed based on construction rules documented in "TechManual"
  - Units do not have: damage applies to components
  - No tactical units may be a member of multiple operational units
  - Tactical units have a quality rating from A for the worst to F for the best that represents how easily they are repaired but does not affect their effectiveness
  - Factory new tactical units may be C, D, or F depending on their quality of manufacture
- Operational Unit
  - Made up of tactical units
  - operational units may be assigned different deployment roles within a contract
  - No operational units may be a member of multiple organizational units
- Organizational Unit:
  - Composed of multiple tactical or operational units
  - Organizational units may nest in a hierarchy
  - Deployed to fulfill contracts on a specified planet
  - No organizational unit may have more than one parent
- Strategic Unit: The player, composed of multiple organizational units
- Faction: a discrete interest within the setting, be it a state, corporation, other mercenary band, etc
  - Not all factions represent a coherent group, such as rebels, rioters, pirates, etc
  - Factions represent groups that can be encountered during a contract
  - Factions may issue contracts and be the target of contracts
  - Factions have goals, strategies, and tactical units based on lore
  - Factions may have access to unique tactical unit types and components to offer the player as rewards or via market if reputation is sufficiently high
  - Examples:
    - Federated Suns
    - Draconis Combine
    - ComStar
    - Wolf's Dragoons
    - Interstellar Explorations
  - Factions do not have strategic, organizational, operational, or tactical units themselves
- Contract: An agreement between a faction and the player
  - Requires the deployment of a specific number of tactical units of specific types to a planet for a specified duration
  - The duration may be based on a number of days or accomplishment of certain goals
  - Contracts specify:
    - Salvage privileges
    - C-Bill compensation upon success
    - Issuing faction
    - Target faction
    - Activity type: Garrison, Cadre, Planetary Assault, Riot Duty, Raid, etc
    - Percentage of transport costs to/from planet covered by employer
    - Percentage of base costs covered, representing employer coverage of salaries and similar
- Resources:
  - C-Bills: Money. Utilized to:
    - Pay personnel
    - Hire personnel
    - Maintain equipment
    - Acquire transport to/from a star system
    - Purchase components to replace damaged components on tactical units
    - Purchase tactical units
  - Reputation
    - Overall notoriety, a global reputation
    - With each faction, positive or negative
- Personnel:
  - Administrators: Handle the HR, logistical, negotiation, and administrative duties of the strategic unit
  - Medics: Provide medical services for injured personnel
    - Each medic can handle a specific number of patients
  - Technicians: Maintain and repair tactical units, perform salvage operations, assigned to zero, one, or more tactical units
    - Technicians have a time budget per day that they can perform work
  - Crew: Operate the tactical units, assigned to exactly one tactical unit
  - Have names, ranks, stats, traits, skills, and experience as specified in "A Time of War" published by Catalyst Game Labs
  - Can have relationships with other personnel within the strategic unit
  - Can have children, age, and die of old age
  - Can be injured during combat or through events and healed by medics
- Inner Sphere:
  - A collection of star systems centered around the Terra (Earth) system roughly a thousand light years in diameter
  - Is where the strategic layer takes place
- Jumpship:
  - Craft that can travel between star systems no more than 30 light-years distance between each other
  - A jumpship may make multiple jumps, requiring an amount of time specified by the type of star in the system it is in between jumps
  - Each jumpship can carry a specific number of dropships
- Dropship:
  - Craft that travels between a star system's jump point and a planet. Each dropship can carry a specific number of tactical units of a given type

## Features

- Computer GM
- Contract generation
- Implements "Campaign Operations" rules as published by Catalyst Game Labs
- Battles are handled using "Total Warfare" as published by Catalyst Game Labs
- Planetary maps are hexes with travel time based on number of hexes from on-planet base to deployment locations
- Deployments of organizational units to planetary locations takes some number of days during which they may encounter enemy forces or random events
- Reputation is increased with the faction that issued the contract and decreased with the faction the contract targeted
  - Some factions (rebels, pirates, civilians) do not track reputation
- Positive or negative reputation with a faction may allow different events to generate or additional options in events
- Whether salvage may be taken and what percentage of total salvage may be taken is determined by the contract
- The strategic layer map should not utilize hexes - it is a star map of star systems arranged in a 2d map based on distances from BattleTech lore

## Tech Stack

- Godot
- GDScript

## Technical Requirements

- Dark and light UI themes
- Internationalization
- Combat rules for tactical layer combats should be handled by a flexible rules engine to allow for ease of updates and flexibility in providing house rule options
- Tactical unts should be stored in the MegaMek format

## Layers

- Strategic:
  - Takes place on the star map
  - Global time ticks advance unless paused.
  - Player may:
    - Hire, fire, promote, or demote personnel
    - Purchase or sell components, ammunition, armor
    - Purchase or sell tactical units
    - Reorganize units within their organizational unit hierarchy
    - Repair or modify tactical units
    - Deploy organizational units to fulfill contracts on a planet
    - Encounter strategic random events
    - Interact with factions: purchase faction units, buy faction equipment, etc
- Operational Layer: Operates on strategic ticks, covers operations on a single planet
  - Global time ticks advance unless paused
  - Occurs on a hex grid representing the operational area on the planet
  - Each hex on the operational layer has a single type of terrain
  - Hexes represent an abstract region consisting of primarily a single type of terrain faction specific equipment from
  - A subset of factions have a presence on this layer
    - The target is always present in this layer
    - The issuer may be present in this layer depending on the contract terms
    - Unexpected third party factions may be present, such as other mercenaries, corporations, pirates, etc
  - Player may:
    - Hire personnel from the planetary market
    - Purchase components, ammunition, armor from the planetary market
    - Purchase tactical units from the planetary market
    - Repair or modify tactical units
    - Deploy operational units to planetary map hexes
    - Encounter operational random events
    - The planetary market is sourced from equipment available to any faction present on the planet with the exception of the target
- Tactical Layer
  - Global time ticks are paused.
  - Occurs on a hex grid contained fully within a single hex of the operational layer
  - Map generation takes into account the type of terrain in the operational layer hex the tactical engagement is contained within
  - Is made up of a number of tactical rounds as documented in "Total Warfare" from Catalyst Game Labs
  - Within the tactical layer map, each hex represents 30m in diameter. A tactical layer map is generally made up of thirty to sixty hexes on a side
  - All turns on the tactical layer take place fully within a single tick
  - Player may:
    - Engage in combat

## Design notes

- Operations on both the strategic and planetary layers operate in single day ticks affecting the same calendar advancing automatically unless paused
- Player may pause the strategic/planetary ticks at any time
- Tactical layer is turn based on a hex grid, pausing planetary/strategic ticks until fully resolved
- Dropships and jumpships can be rented using abstract costs for transit as documented in Campaign Operations if the strategic unit does not own them
- Tactical units may not be repaired or resupplied during tactical layer scenarios
- Each tactical layer map is made up of terrain contained within a single operational layer map hex
- Resources are not found on the operational layer
- An entire tactical layer encounter consisting of multiple tactical turns occurs within a single tick
- The tactical layer map is entirely contained within one operational layer hex

## Setting lore accuracy

- Events from lore should occur at the appropriate dates: Planetary ownership changes, faction creation, etc
- The game should start 1 January 3025
- Transit between star systems utilizies jumpships as in BattleTech lore
- Transit within a star system utilizes dropships with distances consistent to published lore from jump point to planet
- The player does not represent a major player in the timeline. They are one of many mercenary groups that must react to the changes over time rather than driving them

## Additional Notes

- Create a detailed plan from which AI agents can build this application
- Single player
- This is solely utilizing the BattleTech setting as published by Catalyst Game Labs
