# OpenCodeDebugger — AI-Driven Debug Harness

## Overview

`OpenCodeDebugger` is an autoload module that transforms *End of Greatness* into an
AI-inspectable, AI-controllable system. It provides structured state output,
a live TCP command socket, and headless campaign mode — all designed for
opencode (or any external tool) to consume.

Activated by the `--opencode-debug` CLI flag.

## Architecture

```mermaid
graph TB
    subgraph "Godot Process"
        OCD[OpenCodeDebugger<br/>Autoload]
        DL[DebugLogger]
        HP[Helpers.debug_print<br/>debug_warn]
        JSONL[JSONL File<br/>user://opencode_debug.jsonl]
        TCP[TCP Server<br/>127.0.0.1:12075]
        STDOUT[Stdout Pipe]

        DL --> OCD
        HP --> OCD
        OCD --> JSONL
        OCD --> TCP
        OCD -- --opencode-pipe --> STDOUT
    end

    subgraph "opencode / External Tool"
        CLI[Shell/CLI]
        PIPE[Stdout Reader]
        SOCK[TCP Client]
    end

    CLI -- launches --> Godot
    PIPE -- reads --> STDOUT
    JSONL --> PIPE
    PIPE -- or tails --> JSONL
    SOCK -- JSON commands --> TCP
    TCP -- JSON responses --> SOCK

    style OCD fill:#4a9,color:#fff,stroke:#fff
    style Godot fill:#2b5,color:#fff
    style "opencode / External Tool" fill:#35a,color:#fff
```

## Data Flow

```mermaid
flowchart LR
    E[Game Event] --> DL[DebugLogger]
    H[Human debug_print] --> HP
    HP --> OCD{OpenCodeDebugger}
    DL --> OCD
    OCD --> ERR[stderr: [LEVEL][cat] msg]
    OCD --> J[JSONL File]
    OCD -- if --opencode-pipe --> OUT[stdout JSON]
    F6[F6 Keybind] --> S[Snapshot]
    S --> J
    S --> OUT

    style OCD fill:#4a9,color:#fff
```

## CLI Flags

| Flag | Effect |
|------|--------|
| `--opencode-debug` | Activates OpenCodeDebugger (TCP, JSONL file, probes, keybinds) |
| `--opencode-pipe` | Also writes structured JSON to stdout (implies `--opencode-debug`) |
| `--opencode-headless` | Headless mode: no window, auto-start campaign |
| `--opencode-port=N` | TCP port for command socket (default `12075`, `0` = disabled) |
| `--load-save=<path>` | Save file to load in headless mode (if absent, starts new campaign) |
| `--debug` / `-d` | Human debug mode: enables `Helpers.debug_print`/`debug_warn` |

### Flag Combinations

| Use case | Command |
|----------|---------|
| Human debugging | `godot --path . -- --debug` |
| AI interactive (file + pipe) | `godot --path . -- --opencode-debug --opencode-pipe` |
| AI headless (file only) | `godot --path . --headless -- --opencode-debug --opencode-headless` |
| AI headless with pipe | `godot --path . --headless -- --opencode-debug --opencode-headless --opencode-pipe` |
| AI headless loading a save | `godot --path . --headless -- --opencode-debug --opencode-headless --load-save=user://saves/autosave_000.json.zst` |

### Makefile Targets

| Target | Effect |
|--------|--------|
| `make rund` | Human debug (`--debug`) |
| `make runoc` | OpenCode interactive with pipe |
| `make runoc-headless` | Headless, file output |
| `make runoc-headless-pipe` | Headless with pipe |
| `make runoc-load` | Headless loading autosave |

## Outputs

### 1. JSONL File (`user://opencode_debug.jsonl`)

One JSON object per line. Compatible with `tail -f` for live streaming.

```jsonl
{"type":"ready","version":"1.0.0"}
{"type":"log","entry":{"time":"3025-01-15 12:00:00","level":"INFO","category":"economy","message":"Bills paid: 42.5K CSB"}}
{"type":"snapshot","reason":"keybind_F6","timestamp":"...","game_time":{"year":3025,"month":1,"day":15,"total_days":15,"paused":false},"ui":{"..."},"state":{"..."]}}
```

Entry types:
- `ready` — emitted on startup
- `log` — routed log entry from DebugLogger or Helpers.debug_print
- `snapshot` — full UI + state probe triggered by F6 or TCP `probe` command

### 2. Stdout Pipe (with `--opencode-pipe`)

Same JSON lines as the file, written to stdout. Godot's `print()` goes to stdout,
so the pipe carries only structured JSON. Stderr (`printerr`) carries human-readable
console output.

### 3. Stderr Console

All logging also goes to stderr in the traditional format:
```
[INFO][economy] Bills paid: 42.5K CSB
[DBG][mechlab] Unit loaded: Atlas AS7-D
```

## TCP Protocol

Connect to `127.0.0.1:12075`. All messages are newline-delimited JSON.

### Request Format

```json
{"cmd":"<command>", "param1": value1, "param2": value2, ...}
```

### Response Format

```json
{"ok": true, ...}   // success
{"ok": false, "error": "..."}  // failure
```

### Full Command Reference

| Command | Parameters | Description | Response fields |
|---------|-----------|-------------|-----------------|
| **Probing** | | | |
| `probe` | — | Full UI + state snapshot | `snapshot.ui`, `snapshot.state` |
| `get_log` | `count` (int, opt, default 50) | Recent log entries | `entries` |
| `get_state` | — | State probe only | `state` |
| `get_ui` | — | UI probe only | `ui` |
| `dump_org` | — | Org tree with unit IDs | `org_tree` |
| **Simulation** | | | |
| `advance` | `days` (int, 1-365) | Advance game clock N days | `days_advanced`, `current_date` |
| `pause` | — | Pause game clock | `paused` |
| `unpause` | — | Unpause game clock | `paused` |
| `set_speed` | `interval` (float, opt), `paused` (bool, opt) | Set tick rate / pause | `interval`, `paused` |
| **Save/Load** | | | |
| `save` | `name` (str) | Manual save | `path`, `filename` |
| `load` | `path` (str) | Load save file | `date`, `error` |
| **Resources** | | | |
| `add_funds` | `amount` (int) | Add C-Bills | `new_balance` |
| `set_funds` | `amount` (int) | Set absolute balance | `new_balance` |
| `add_item` | `name` (str), `quantity` (int) | Add inventory item | `new_total` |
| `remove_item` | `name` (str), `quantity` (int) | Remove inventory item | `new_total` |
| `add_personnel` | `role` (str, opt), `name` (str, opt), `skills` (dict, opt) | Create and hire a person | `personnel_name` |
| `remove_personnel` | `name` (str) | Fire a person by name | — |
| `add_unit` | `chassis` (str), `variant` (str, opt), `org_unit` (str, opt) | Add unit from template | `unit_id`, `unit_name` |
| `remove_unit` | `id` (str) | Remove unit by ID | — |
| **System** | | | |
| `quit` | — | Graceful shutdown | — |

### Example Session

```
→ {"cmd":"probe"}
← {"ok":true,"snapshot":{"ui":{},"state":{"date":{"year":3025,"month":1,"day":1,"total_days":0,"paused":true},"funds":10000000}}}

→ {"cmd":"add_unit","chassis":"Atlas","org_unit":"Alpha Lance"}
← {"ok":true,"unit_id":"tu_a3f8c91e","unit_name":"Atlas AS7-D"}

→ {"cmd":"add_personnel","role":"mechwarrior","name":"Jane Doe","skills":{"gunnery_mech":3,"piloting_mech":4}}
← {"ok":true,"personnel_name":"Jane Doe"}

→ {"cmd":"advance","days":30}
← {"ok":true,"days_advanced":30,"current_date":{"year":3025,"month":2,"day":1,"total_days":30,"paused":false}}

→ {"cmd":"dump_org"}
← {"ok":true,"org_tree":[{"name":"Debug Battalion","type":"OrganizationalUnit","sub_units":[{"name":"Alpha Lance","type":"OperationalUnit","tactical_units":[{"id":"tu_a3f8c91e","name":"Atlas AS7-D","chassis":"Atlas","model":"AS7-D","tonnage":100.0,"type":"MECH"}]}]}]}

→ {"cmd":"save","name":"checkpoint_30"}
← {"ok":true,"path":"user://saves/checkpoint_30_3025-02-01.json.zst","filename":"checkpoint_30_3025-02-01.json.zst"}

→ {"cmd":"quit"}
← {"ok":true}
```

### Role Strings (for `add_personnel`)

Case-insensitive. Accepted values and their `PersonnelRole` mapping:

| String | Role |
|--------|------|
| `civilian` | CIVILIAN (default) |
| `mechwarrior`, `pilot`, `mech_warrior` | MECHWARRIOR |
| `tech`, `technician` | TECHNICIAN |
| `doctor`, `medical` | DOCTOR |
| `medic` | MEDIC |
| `crew`, `vehicle_crew` | CREW |
| `hr` | HR |
| `logistics`, `logistical` | LOGISTICAL |
| `transport` | TRANSPORT |
| `command` | COMMAND |
| `infantry` | INFANTRY |
| `aero_pilot`, `aerospace_pilot` | AEROSPACE_PILOT |
| `vtol_pilot` | VTOL_PILOT |

## Headless Mode

### Campaign Start

With `--opencode-headless`:

1. If `--load-save=<path>` is provided, the game loads that save file
2. Otherwise, a new campaign is generated via `StrategicUnitGenerator` with default parameters (Davion, 3025)
3. The main menu is skipped entirely — game transitions directly to `CampaignView`
4. The window is minimized (or uses Godot's headless DisplayServer)

### Autosave Isolation

Headless autosaves use the prefix `headless_autosave` instead of the standard
`autosave`. This keeps them in a separate namespace — they never displace the
player's manual saves or standard autosaves.

Files are stored at `user://saves/headless_autosave_000.json.zst` with the
same rotation logic (5 slots) as standard autosaves.

### Time Control

In headless mode, time starts paused. Use `unpause` and `set_speed` to control
simulation speed:
- Normal: `{"cmd":"set_speed","interval":1.0,"paused":false}`
- Fast: `{"cmd":"set_speed","interval":0.1,"paused":false}`
- Single-step: `{"cmd":"advance","days":7}`

## Unit IDs

Every `TacticalUnit` now has a `unit_id` field (format `tu_XXXXXXXX`,
8 hex digits). The ID is auto-generated in `TacticalUnit._init()` on creation
and persists through save/load cycles.

- New units created via `add_unit` get a unique ID
- Units generated by `StrategicUnitGenerator` also get one (via `_init()`)
- Old saves without `unit_id` get fresh IDs on load (the `_init()` fallback)

The `dump_org` command returns these IDs. Use them with `remove_unit`.

## Configuration Defaults

| Setting | Default |
|---------|---------|
| TCP port | 12075 |
| JSONL file | `user://opencode_debug.jsonl` |
| Probe depth | 3 (Control tree levels) |
| Log buffer | 1000 entries |
| Auto-save prefix (headless) | `headless_autosave` |

## Running Tests

```bash
make test                     # Full suite
godot --headless --script tests/test_opencode_debugger.gd 2>&1 | grep -E "PASS|FAIL|Results"
```

The test suite covers all command handlers with both positive and negative cases:
30 tests across 5 categories: pure logic, resource commands, personnel commands,
unit commands, and probes.
