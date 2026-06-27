# End of Greatness

A BattleTech grand strategy simulation built with Godot 4.6.

## Quick Start

```bash
godot --path .
```

Requires Godot 4.6.x. See `Makefile` for all commands.

## Project Structure

```
src/
  core/          — Autoloads: GameState, EventBus, TimeManager, DataManager, SaveManager, ModManager
  data/          — Resource classes (TacticalUnit, Component, Personnel, Contract, etc.)
  systems/       — Economy, Reputation, Personnel, Refit, Inventory, Transport managers
  strategic/     — ContractGenerator, PlanetaryMapGenerator, StrategicUnitGenerator
  tactical/      — Combat resolver, movement, LOS, MegaMek parser
  operational/   — Organization manager
  ui/            — Scenes and scripts: MainMenu, CampaignView, StarMap, MechLab, etc.
  utils/         — Helpers (formatting, debug)
data/            — JSON data: factions, components, units, starmap, timeline, skills
mods/            — Self-contained mod directories (see plan.md for mod system docs)
tests/           — SceneTree-based unit tests
ai/              — Build plan (plan.md) and implementation status (status.md)
```

## Build Plan

See `ai/plan.md` for the detailed implementation roadmap (V1–V8, Phases 0–6).

## Make Commands

| Command | Description |
|---------|-------------|
| `make test` | Bootstrap + run all test suites |
| `make lint` | Run GDScript linter (gdlint) |
| `make run` | Launch the game |
| `make rund` | Launch with debug logging (`--opencode-debug`) |
| `make bootstrap` | Generate `.godot` script class cache |
| `make clean` | Remove `.godot/` cache and build artifacts |
| `make suckit` | Regenerate systems + timeline from SUCKIT CSV data |

## Modding

Each mod is a self-contained directory under `mods/<id>/` with `mod.json` (metadata + `compatible_version`) and `strings.json` (keyed localization). See `ai/plan.md` → "Mod System" for the full spec.

## Versioning

Semver with MAJOR = V target (V1 = 1.x, V2 = 2.x, etc.). See `ai/plan.md` → "Versioning Scheme". Current: **1.0.0**.

## Changelog Convention

Release tags follow `v<MAJOR>.<MINOR>.<PATCH>` (e.g., `v1.0.1`). Release notes are auto-generated from commits between tags. Write commit messages as descriptive imperative sentences — the first line becomes the release note entry.
