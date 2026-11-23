# OpenBot Activity — Omarchy shell plugin

A live activity indicator for OpenBot in the Omarchy bar. It reads the local OpenBot
SQLite projection read-only, so it never alters agent state.

The indicator sits just left of the clock (`centerBegin`) as plain bar text:
no capsule, no border. It is compact and quiet when idle, and expands with live
animation only while an agent is active:

| State | Bar (Horizontal) | Bar (Vertical) | Panel |
| --- | --- | --- | --- |
| Idle / Standby | OpenBot robot badge `󰚩` | Square slot `󰚩` | "Idle — no agent is working" |
| App Closed | Dimmed robot badge | Dimmed square slot | "Aplikasi belum berjalan" |
| Working (1 agent) | Spinning `󰑐` + glistening name + elapsed time | Rotating `󰑐` | Agent PlushBot avatar badge, model, steps, current step text |
| Working (>1 agents) | Spinning `󰑐` + primary name `+N` + elapsed time | Rotating `󰑐` + dot badge | Full list of active agents with individual status |
| Silent turn | `󰔟` + name + "silent <time>" | `󰔟` | Marked silent with quiet duration |
| Question (`ask_user`) | Pulsing `󰘥` + bold name + "needs you" | Pulsing `󰘥` | Question card with prompt text and age |
| Waiting on teammate | Clock `󰥔` + name + "waiting" | Clock `󰥔` | Wait card with dependency note |
| Just finished | Check `󰗠` + name + "done" (14s flash) | Check `󰗠` | "Just finished" row with duration |

Questions always take top visual priority.

## Multi-Agent & Vertical Bar Behavior

- **Multi-Agent (Horizontal):** When 2+ agents run concurrently, the bar displays the most recently updated agent with `+N` (e.g. `󰑐  Omarch +1  45s`), preventing bar clutter. The panel lists every agent in full detail.
- **Vertical Bar:** Automatically adapts when the bar is positioned on the screen edge (`left` / `right`). Disables wide horizontal text labels and collapses to a clean single square slot with the animated glyph, plus an indicator dot when multiple agents are running.
- **Hover Tooltip:** Provides a contextual 1–3 line summary showing the active agent's current step, age, and quick interaction hints.

## Shortcuts & Controls

- **`Super + Shift + O`** or **`Super + Shift + A`**: Toggle the OpenBot bar panel (registered in Hyprland).
- **Left click**: Open / close the panel.
- **Right click / Middle click**: Force an immediate database re-read.
- **Keyboard navigation inside panel**:
  - `Esc`: Close panel.
  - `Enter` / `o`: Bring the OpenBot window forward (`gtk-launch openbot`).
  - `r`: Refresh state.
  - `Tab`: Switch to neighboring bar panel.

## IPC

```bash
omarchy-shell danyakmallun.openbot.ui open
omarchy-shell danyakmallun.openbot.ui close
omarchy-shell danyakmallun.openbot.ui toggle
omarchy-shell danyakmallun.openbot.ui refresh
omarchy-shell danyakmallun.openbot.ui status
```

`status` outputs JSON: `{"phase": "working", "running": 1, "questions": 0, "waits": 0, "readAt": 1795463473335}`.

## Layout & Architecture

```
AgentAvatar.qml    Native plush bot avatar: procedural squircle with bot eyes & signature hue, or custom avatar image
BarWidget.qml      WidgetButton container: icon animation, glistening text, vertical adaptation, click routing
OpenBotPoller.qml   Adaptive SQLite poller (1s active, 3s idle), snapshot caching, monotonic second clock
Panel.qml          KeyboardPanel: hero, NEEDS YOU cards, WORKING rows, WAITING, JUST FINISHED, OpenBot action
Model.js           Parsers, formatting, glyphs, and contextual tooltip generator
scripts/state.sh   Read-only SQLite query with busy timeout; outputs structured JSON
assets/            OpenBot mark icon
```
