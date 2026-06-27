---
name: opencode-debugger
description: >-
  Inspect and control a running End of Greatness game instance via TCP
  socket (port 12075). All commands are JSON-line based. Read-only by
  default; write commands available for test setup.
---

## Connection

The game listens on `127.0.0.1:12075` when launched with `--opencode-debug`.
Connect via netcat or Python:

```bash
# Send one command and read response
echo '{"cmd":"probe"}' | nc -q1 127.0.0.1 12075

# Interactive session
nc 127.0.0.1 12075
{"cmd":"get_state"}
{"cmd":"dump_org"}
```

Python persistent connection:
```python
import socket, json
s = socket.create_connection(("127.0.0.1", 12075))
def cmd(c):
    s.sendall((json.dumps(c) + "\n").encode())
    return json.loads(s.recv(65536).decode())
print(cmd({"cmd":"get_state"}))
```

## Always start with probe

```bash
echo '{"cmd":"probe"}' | nc -q1 127.0.0.1 12075
```

Returns UI state + game state + autoload health in one response.
If this fails, the game isn't running or the port is wrong.

## Read-only investigation workflow

For most bugs, use these commands in order:

1. `probe` — health check + high-level state
2. `get_state` — date, funds, contracts, personnel, inventory, time state
3. `dump_org` — organizational tree, deployed units, contract IDs
4. `get_ui` — visible panels, modal stack, control states
5. `get_log` — last N debug log entries (default 50)

## Log file

The game writes structured JSONL to:
```
~/.local/share/godot/app_userdata/End of Greatness/opencode_debug.jsonl
```

This file contains all debug entries (not just TCP responses) and persists
between sessions. Tail it for a chronological view:

```bash
tail -30 ~/.local/share/godot/app_userdata/End\ of\ Greatness/opencode_debug.jsonl
```

## Write commands (for test setup)

These modify game state. Use sparingly and document what you changed.

| Command | Example | Effect |
|---|---|---|
| `advance` | `{"cmd":"advance","days":30}` | Advance N days (capped at 365) |
| `pause` | `{"cmd":"pause"}` | Pause time |
| `unpause` | `{"cmd":"unpause"}` | Unpause time |
| `set_speed` | `{"cmd":"set_speed","interval":0.2}` | Set tick interval in seconds |
| `add_funds` | `{"cmd":"add_funds","amount":100000}` | Add C-Bills |
| `set_funds` | `{"cmd":"set_funds","amount":50000}` | Set C-Bills to exact amount |
| `add_item` | `{"cmd":"add_item","name":"Medium Laser","quantity":2}` | Add inventory items |
| `remove_item` | `{"cmd":"remove_item","name":"Medium Laser","quantity":1}` | Remove inventory items |
| `add_personnel` | `{"cmd":"add_personnel","name":"Jane Doe","role":"mechwarrior"}` | Add personnel with optional skills |
| `remove_personnel` | `{"cmd":"remove_personnel","name":"Jane Doe"}` | Remove personnel by name |
| `add_unit` | `{"cmd":"add_unit","chassis":"Marauder","variant":"MAD-3R"}` | Add a mech to the org tree |
| `remove_unit` | `{"cmd":"remove_unit","id":"..."}` | Remove a unit by its unit_id |
| `save` | `{"cmd":"save","name":"debug_checkpoint"}` | Save game |
| `load` | `{"cmd":"load","path":"user://saves/..."}` | Load save file |
| `quit` | `{"cmd":"quit"}` | Shut down the game gracefully |

## Common debugging sequences

### "Units not on planetary map"

```
probe
get_state  → check active_contracts has the deployed contract
dump_org   → check contract_id on the deployed org unit
```

Likely cause: `contract_id` set to `str(contract.get_instance_id())` on one
side but compared differently on the other. Both sides must match.

### "Contract not completing"

```
get_state  → check salvage_percentage_used < salvage_rate
get_ui     → check which panels are open
probe      → check autoload health
```

If salvage_percentage_used is stuck, the contract's cumulative salvage
counter may not have been updated after the last engagement.

### "Blank UI panel"

```
get_ui     → dump visible panel tree
probe      → check all autoloads responsive
```

Often caused by a script parse error that prevented the panel's scene
from loading. Run `make check` to verify all scripts compile.

## Rules

1. Start with `probe` to confirm the game is alive
2. Use read-only commands (`get_state`, `dump_org`, `get_ui`, `get_log`) for initial investigation
3. Only use write commands (`add_funds`, `advance`, etc.) to set up test conditions — document what changed
4. Report findings in natural language with the relevant JSON values
5. If TCP is unresponsive, check that the game was launched with `--opencode-debug`
