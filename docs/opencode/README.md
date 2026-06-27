# OpenCode Integration

This directory documents how the [OpenCode](https://opencode.ai) AI coding agent
interacts with the End of Greatness project.

## Overview

The project has first-class OpenCode support for AI-assisted development.
All infrastructure is designed for zero-install setup — the AI reads
`ai/context.md` at session start, loads project-specific skills on demand,
and communicates with the running game via TCP for live debugging.

## Key Files

| Path | Purpose |
|---|---|
| `ai/context.md` | Session bootstrap — loaded automatically every session |
| `ai/plan.md` | Design decisions, version targets, architecture notes |
| `ai/status.md` | Implementation state per phase |
| `.opencode/skills/opencode-debugger/SKILL.md` | TCP debugger workflow — loaded via `load opencode-debugger` |
| `docs/opencode/debugger.md` | User documentation for the debug harness |

## Components

- **OpenCodeDebugger** (`src/core/OpenCodeDebugger.gd`) — Autoload providing TCP socket + JSONL log for live game introspection
- **DebugLogger** (`src/core/DebugLogger.gd`) — Structured stderr logging, subscribes to EventBus signals
- **NotificationManager** (`src/core/NotificationManager.gd`) — Toast/popup dispatch for in-game events
- **Makefile targets** — `make runoc`, `make runoc-headless`, `make runoc-load` for launching with debugger active

## Workflow

1. Start the game with `make runoc` (or `make runoc-headless`)
2. The AI loads context.md and discovers available skills
3. For live debugging: `load opencode-debugger` → connect to TCP port 12075
4. Investigate with read-only commands (`probe`, `get_state`, `dump_org`, `get_ui`)
5. Fix issues, run `make check` + `make test`, commit
