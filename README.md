# OpenBot Activity — Omarchy Shell Plugin

A live OpenBot activity indicator for the Omarchy bar. It reads the local OpenBot
SQLite projection read-only, so it never changes agent state.

The indicator sits next to the clock (`centerBegin`) as plain bar text: no capsule,
no border. It stays compact while idle and lights up with live animation when an
agent is working.

## What It Shows

| State | Bar (horizontal) | Bar (vertical) | Panel |
| --- | --- | --- | --- |
| Idle / standby | Robot glyph `󰚩` | Square slot `󰚩` | "Idle — no agent is working" |
| OpenBot not running | Dimmed robot glyph | Dimmed square slot | "OpenBot is not running" |
| Working (one agent) | Spinning `󰑐` + shimmering name + elapsed time | Rotating `󰑐` | PlushBot avatar, model, steps, current step |
| Working (several agents) | Spinning `󰑐` + primary name `+N` + elapsed time | Rotating `󰑐` + dot badge | One row per agent with individual status |
| Silent turn | `󰔟` + name + "silent <time>" | `󰔟` | Marked silent with quiet duration |
| Question (`ask_user`) | Pulsing `󰘥` + bold name + "needs you" | Pulsing `󰘥` | Question card with prompt text and age |
| Waiting on a teammate | Clock `󰥔` + name + "waiting" | Clock `󰥔` | Wait card with dependency note |
| Just finished | Check `󰗠` + name + "done" (14s flash) | Check `󰗠` | "Just finished" row with duration |

Questions always take top visual priority.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`).
- OpenBot desktop app installed and running at least once, so its database exists:
  `$XDG_CONFIG_HOME/OpenBot/openbot.db` (default `~/.config/OpenBot/openbot.db`).
- `sqlite3` command line tool.
- A Nerd Font for the status glyphs.

## Install

```bash
omarchy plugin add https://github.com/danyakmallun9999/omarchy-openbot.git --enable --yes
```

The widget is placed in `centerBegin`, just left of the clock. To move it elsewhere:

```bash
omarchy bar move danyakmallun.openbot --section right
```

To remove it:

```bash
omarchy plugin remove danyakmallun.openbot --yes
```

## Configuration

Settings live on the widget in `~/.config/omarchy/shell.json` and can be changed with
`omarchy bar set`:

```bash
omarchy bar set danyakmallun.openbot refreshIntervalSec 5
```

| Key | Default | Meaning |
| --- | --- | --- |
| `refreshIntervalSec` | `3` | Database read interval while idle (1s while an agent is active). |
| `doneFlashSec` | `14` | How long a finished turn keeps showing a check. |
| `stalledAfterSec` | `240` | A turn with no new step for this long is shown as silent. |

The database location can be overridden with the `OPENBOT_DB` environment variable,
useful for custom OpenBot installs.

## Behavior

- **Multi-agent (horizontal):** when 2+ agents run concurrently, the bar shows the
  primary agent with `+N` (for example `󰑐  Omarch +1  45s`) to avoid clutter. The
  panel lists every agent in full detail.
- **Vertical bar:** automatically collapses to a single square slot with the animated
  glyph, plus a dot when several agents are running.
- **Hover tooltip:** a contextual 1–3 line summary with the active step, age, and
  interaction hints.
- **Avatars:** each agent is drawn with its OpenBot hue and bot eyes, or its uploaded
  avatar image when one is set.

## Shortcuts & Controls

- **Left click**: open / close the panel.
- **Right click / Middle click**: force an immediate database re-read.
- **Inside the panel**: `Esc` closes, `Enter` / `o` brings OpenBot forward, `r` refreshes,
  `Tab` switches to a neighbouring bar panel.

To get a keyboard shortcut, add a Hyprland binding in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + O", "OpenBot Activity", "omarchy-shell danyakmallun.openbot.ui toggle")
```

## IPC

```bash
omarchy-shell danyakmallun.openbot.ui open
omarchy-shell danyakmallun.openbot.ui close
omarchy-shell danyakmallun.openbot.ui toggle
omarchy-shell danyakmallun.openbot.ui refresh
omarchy-shell danyakmallun.openbot.ui status
```

`status` prints JSON, for example:
`{"phase":"working","running":1,"questions":0,"waits":0,"readAt":1795463473335}`.

## Layout

```
manifest.json       Plugin metadata, entry point, and settings schema
BarWidget.qml       WidgetButton container: icon animation, shimmer, vertical mode, click routing
Panel.qml           KeyboardPanel: hero, NEEDS YOU cards, WORKING rows, WAITING, JUST FINISHED
OpenBotPoller.qml   Adaptive SQLite poller (1s active / configurable idle), snapshot cache, live clock
AgentAvatar.qml     Procedural PlushBot avatar or custom image
Model.js            Parsers, formatters, glyphs, and tooltip text
scripts/state.sh    Read-only SQLite snapshot; prints structured JSON
assets/             OpenBot mark
```

All dynamic text is rendered as plain text, so wording coming from an agent is never
interpreted as markup. Database access is read-only (`sqlite3 -readonly`).

## License

MIT
