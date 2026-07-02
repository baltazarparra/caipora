# Caipora

> A Brazilian folk horror roguelike built with Godot 4.6.  
> Play it in the browser on [itch.io](https://itch.io) (link coming soon).

---

## What is caipora?

**caipora** is a 2D pixel-art roguelike set in the dark heart of Brazilian folklore.

You play as the **Caipora** — guardian of the forest, spirit of whistles, traps, and vengeance — awakening in a corrupted woodland where ancient pacts have been shattered. Every step on the grid is a choice. Every encounter can become hunt, punishment, flight, or enchantment.

The core mechanic is **timing-based combat** inspired by *Legend of Dragoon* and *Clair Obscur*:
- Press **Space** at the right moment to land a **critical hit** (2x–3x damage).
- Press **Space** at the right moment to **perfect dodge** an attack and **counter-attack**.

Every strike, dodge, and death is packed with visceral feedback: screen shake, blood particles, hit-stop frames, and brutal sound effects.

**Tone:** GORE / TERROR / SANGRENTO

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Engine | Godot 4.6.3 |
| Language | GDScript |
| Art | Pixel art — CC0 (Kenney) |
| Audio | `.wav` SFX (jsfxr / sfxr) — no music in MVP |
| Platform | Browser-first (HTML5 / itch.io) |
| AI Agent | Claude Code / Kimi Code / Cursor + Godot MCP |

---

## Project Structure

```
caipora/
├── assets/          — Sprites (CC0/Kenney), SFX, fonts, licenses
├── scenes/          — Godot scenes (UI, exploration, arena, shared)
├── scripts/         — GDScript source code
│   ├── core/        — Autoloads (GameState, SignalBus, MetaProgression)
│   ├── systems/     — TimingSystem, CombatSystem, FeedbackSystem
│   ├── entities/    — Caipora, Criatura
│   ├── exploration/ — Grid logic, TurnManager
│   ├── arena/       — ArenaManager, attack patterns
│   └── utils/       — Helpers, constants
├── tests/           — GUT unit tests
├── docs/            — Design documents
├── PLAN.md          — Full product & technical specification
├── AGENTS.md        — AI agent harness instructions
└── .kimi-code/mcp.json — Kimi Code MCP configuration
```

---

## Running Locally

```bash
# Requires Godot 4.6+ installed at ~/.local/bin/godot
# Display :0 must be available (WSLg on Windows, native X11 on Linux)

~/.local/bin/godot --path .
```

### Running Tests

All harness commands live in the `Makefile`. Override the binary with `make test GODOT=/path/to/godot`.

```bash
make smoke    # headless smoke test
make test     # GUT regression gate
make export   # reproducible HTML5 build
make gate     # smoke + test (run before commit)
```

---

## MCP (Model Context Protocol)

This project uses the **Godot MCP Server** (`@coding-solo/godot-mcp`) so AI agents can interact directly with the Godot editor and runtime.

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `create_scene` | Create a new `.tscn` file |
| `add_node` | Add a node to an existing scene |
| `save_scene` | Save changes to a scene |
| `run_project` | Run the game and capture output |
| `get_debug_output` | Read stdout/stderr from the running game |
| `stop_project` | Stop the running game |
| `launch_editor` | Open the Godot editor |

### Configuration

- **Kimi Code CLI:** `.kimi-code/mcp.json`
- **Cursor:** `.cursor/mcp.json`
- **Wrapper script:** `scripts/mcp-wrapper.sh` (sets `GODOT_PATH`)

---

## Development Harness

This project follows **Harness Engineering** principles:

- **Feedforward:** `AGENTS.md` (root + per-folder) and `PLAN.md` guide the agent before it acts. `CLAUDE.md` is a symlink to `AGENTS.md`, so every agent (Claude Code, Kimi, Cursor) reads the same source of truth.
- **Feedback:** Verification commands are codified in the `Makefile` (`make smoke`/`test`/`export`/`gate`) — not buried in prose — so they are stable and discoverable.
- **Memory:** Git commits, milestone tracking in `PLAN.md` (incl. a Known Issues section), and evolving `AGENTS.md`.
- **Tools:** Godot MCP, configured once in `.mcp.json` (canonical); `.cursor/` and `.kimi-code/` configs are symlinks to it.

Read `AGENTS.md` before contributing (human or agent).

---

## Milestones

| Phase | Goal | Status |
|-------|------|--------|
| 1 | Grid + Caipora movement | ✅ Complete |
| 2 | Arena + Timing system | ✅ Complete |
| 3 | Criatura + Boss | ✅ Complete |
| 4 | Meta-progression + Polish | ✅ Complete |
| 5 | Export HTML5 (reproducible CLI build) | ✅ Complete |
| 6 | Grid roguelike — enemies on map, turn system, 3-room map | 🚧 In progress |

See `PLAN.md` for full milestone details.

---

## License

MIT
