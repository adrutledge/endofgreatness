# OpenCode Debug Harness

The `OpenCodeDebugger` autoload (`src/core/OpenCodeDebugger.gd`) provides
live game state introspection for AI-driven debugging. It is activated by
the `--opencode-debug` CLI flag.

## CLI Flags

| Flag | Effect |
|---|---|
| `--debug` / `-d` | Human debug mode: enables `Helpers.debug_print`/`debug_warn` |
| `--opencode-debug` | Activates OpenCodeDebugger (probe, pipe, headless, TCP) |
| `--opencode-pipe` | Also emit structured JSON to stdout |
| `--opencode-headless` | Headless mode: no window, auto-start campaign |
| `--opencode-port=N` | TCP port for command socket (default 12075, 0 = disable) |
| `--load-save=<path>` | Save file to load in headless mode (else start new campaign) |

## Makefile Targets

| Command | Effect |
|---|---|
| `make rund` | Human debug (`--debug`) |
| `make runoc` | OpenCode interactive with pipe |
| `make runoc-headless` | Headless, auto campaign, file output |
| `make runoc-headless-pipe` | Headless with pipe |
| `make runoc-load` | Headless loading autosave |

## TCP Protocol

When `--opencode-debug` is set, the game listens on `127.0.0.1:12075` (or
`--opencode-port=N`). The protocol is JSON-line: send one JSON object per
line, receive one JSON object per line.

### Read-Only Commands

| Command | Parameters | Response |
|---|---|---|
| `probe` | — | Full UI + state snapshot (health check) |
| `get_state` | — | Game date, funds, contracts, personnel, inventory, time state |
| `get_ui` | — | Visible panel tree (type, text, disabled state, children) |
| `dump_org` | — | Organizational unit tree with tactical units |
| `get_log` | `count` (default 50) | Last N log entries |

### Write Commands (test setup)

| Command | Parameters |
|---|---|
| `advance` | `days` (1-365) |
| `pause` | — |
| `unpause` | — |
| `set_speed` | `interval` (float seconds per tick), `paused` (bool) |
| `save` | `name` (string) |
| `load` | `path` (string) |
| `add_funds` | `amount` (int) |
| `set_funds` | `amount` (int) |
| `add_item` | `name` (string), `quantity` (int) |
| `remove_item` | `name` (string), `quantity` (int) |
| `add_personnel` | `name` (string), `role` (string), `skills` (dict) |
| `remove_personnel` | `name` (string) |
| `add_unit` | `chassis` (string), `variant` (string, optional), `org_unit` (string, optional) |
| `remove_unit` | `id` (string) |
| `quit` | — |

### Example Session

```bash
$ echo '{"cmd":"probe"}' | nc -q1 127.0.0.1 12075
{"ok":true,"snapshot":{"ui":{...},"state":{"funds":1000000,"date":{...},...}}}

$ echo '{"cmd":"get_state"}' | nc -q1 127.0.0.1 12075
{"ok":true,"state":{"funds":1000000,"org_unit_count":1,"tactical_unit_count":12,...}}
```

## JSONL Log File

The game writes structured JSONL to `user://opencode_debug.jsonl`. On
Linux this resolves to:

```
~/.local/share/godot/app_userdata/End of Greatness/opencode_debug.jsonl
```

Every debug log entry, TCP response, and F6 snapshot is written here.
The file is flushed per-entry, so it can be tailed in real time.

## F6 Keybind

When `--opencode-debug` is active, pressing F6 in the game window
triggers a probe snapshot — writes current UI + state to the JSONL log
file. Useful for capturing state at a specific moment during manual testing.

## Data Validation Modes

Three CLI flags run `validate_data()` on all loaded data files:

| Flag | Effect |
|---|---|
| `--opencode-debug` | Runs at startup + enables debug menu button |
| `--opencode-validate-data` | Standalone CI mode — validates and exits |
| `--opencode-validate-in-game` | Live modder mode — F5 keybind triggers revalidation |
