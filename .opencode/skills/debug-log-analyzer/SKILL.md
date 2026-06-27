---
name: debug-log-analyzer
description: >-
  Scrape and filter the game's debug output log file to find engine errors,
  script errors, and parse errors that the TCP debugger doesn't capture.
---

## Log file location

`debug_output.log` in the project root. Created each time `make runoc` is used.
Populated via `tee` — every line of stderr and stdout goes here in real time.

## Useful commands

### Find all script errors from the most recent session

```bash
python3 -c "
import re
with open('debug_output.log') as f:
    lines = f.readlines()
last = max(i for i, l in enumerate(lines) if 'OpenCodeDebugger ready' in l)
for l in lines[last:]:
    t = l.strip()
    if 'SCRIPT ERROR' in t or 'Parse Error' in t or t.startswith('ERROR:'):
        print(t)
"
```

### Count errors by type

```bash
grep -c "SCRIPT ERROR" debug_output.log   # GDScript runtime errors
grep -c "Parse Error" debug_output.log    # Scene / script parse failures
grep -c "^ERROR:" debug_output.log        # Engine-level errors
```

### Show the last N lines (recent activity during a play session)

```bash
tail -30 debug_output.log
```

### Show all warnings (non-critical but useful context)

```bash
grep "WARNING:" debug_output.log | tail -20
```

## Workflow

1. Ask the user to check the terminal or confirm a log was captured
2. Run the most specific query first (SCRIPT ERRORs from last session)
3. If nothing found, broaden to `tail -50` for recent activity
4. Report findings + the specific file:line of each issue
