---
project: mech-bags
doc_type: handoff-report
agent: claude-sonnet-4-6 (frontend design pass)
date: 2026-06-04
---

# Frontend Design Implementation Report — Mech Bags 0.1

## Design Direction

**"Armored Maintenance Bay — Diagnostic Terminal meets Die-Cast Mech Kit"**

Industrial, chunky, readable. The UI should feel like arranging physical mech modules on a maintenance workbench before a combat test. Five body-part bags are distinct module bays, not generic boxes.

Key choices:
- **Orbitron** (700/900) for game titles — `MECH BAGS`, `DEFEAT!`, `RUN CLEAR!`. Bold retro-future. Falls back to Courier New offline.
- **Rajdhani** (400/600/700) for all tactical UI text — bag labels, stats, buttons. Military-clean, readable at small sizes. Falls back to Arial Narrow.
- **Share Tech Mono** for combat readouts and logs. Raw data feel. Falls back to Courier New.
- **Amber** (`#f5c518`) is the dominant accent — kept from the original.
- **Per-bag color identity**: HEAD=blue, TORSO=amber, BACK=orange, LEFT ARM=green, RIGHT ARM=green. Each bag panel has a colored top border and matching label color.
- **Workshop floor** — the `#main` area has a very subtle 40px CSS grid texture making the dead space feel like a schematic table surface.
- **Schematic grid** inside mech sprites — diagnostic/blueprint aesthetic.

---

## Files Changed

| File | Change type |
|---|---|
| `prototype/styles.css` | Complete redesign — all CSS variables, typography, layout, animations |
| `prototype/index.html` | Google Fonts link, favicon data-URI, inline style cleanup, `id="board-wrapper"` |
| `prototype/app.js` | C2 bugfix only — `renderHeader()` before `showRunEnd()` calls |

---

## Behavior Preserved

- All 66 core tests pass: `node prototype/tests/core-tests.js` → `66 passed, 0 failed`
- BEH-001 confirmed: Beam Rifle placed in Head bag with no anatomy restriction, no error styling
- BEH-002 confirmed: body expansion adds 1 row to the named bag only
- BEH-003 confirmed: adjacency bonuses still render with `.has-bonus` glow
- Battle flow confirmed: buy → place → battle → result → continue → round 2
- Skip Battle, run-over (3 losses), run-clear (5 wins) screens all render correctly
- No gameplay rules changed

---

## Specific Visual Improvements

### Build board
- **Per-bag color accent**: `border-top: 3px solid var(--bag-accent)` + matching label color — HEAD blue, TORSO amber, BACK orange, ARMS green
- **Cell contrast**: `--bg-cell: #1c1e30` is clearly lighter than `--bg-panel: #111220`, making empty grids readable as a grid rather than a dark blob
- **Cell borders**: `--border-mid: #2c3050` — visible but not distracting
- Valid/invalid drop states have `box-shadow` glows in addition to background tint

### Header
- `MECH BAGS` in Orbitron 900 with amber text-shadow glow
- Diagonal warning stripe pseudo-element (very subtle, 2% opacity)
- Run stats use semantic colors (`#stat-wins` green, `#stat-losses` red, `#gold-display` amber)

### Side panel
- Selected hand item animates: `handPulse` — slow amber border glow cycle
- Item info in Rajdhani, bonus tags in Share Tech Mono

### Shop
- Cards lift 2px on hover (`transform: translateY(-2px)`) with amber glow shadow
- Subtle gradient gloss `::before` pseudo-element

### Battle screen
- **Fully opaque** background (`background: #07080f`) — no build board bleed-through (fixes Opus S2)
- Mech sprites have a schematic `::before` grid (16px cells at 35% opacity) for "diagnostic readout" feel
- HP bars: gradient green → animated red pulse at critical
- Event banner uses Rajdhani 700 for the weapon-fires text
- Combat log in Share Tech Mono — distinctly data-terminal
- `battleEnter` fade animation on battle screen activation

### Result overlay
- `DEFEAT!` / `VICTORY!` in Orbitron 900 with colored text-shadow glow (green/red)
- `boxSlideUp` spring animation (`cubic-bezier(0.34, 1.56, 0.64, 1)`) — the box pops in
- Stats in Share Tech Mono

### Run end screen
- `RUN CLEAR!` / `RUN OVER` in Orbitron 900 at 60px
- `RUN CLEAR!` pulses with `titleGlow` animation (amber glow cycling)
- Dashed amber tape line across the screen via `::before` — industrial warning-tape feel

---

## Bug Fixes Applied

| Bug | Fix |
|---|---|
| **C2** (Opus report) — Header wins counter lags by one on run-clearing victory | Added `renderHeader()` call before both `showRunEnd()` branches in `onResultContinue()` in `app.js` |
| **S2** (Opus report) — Battle overlay semi-transparent, build board bleeds through | Changed `#battle-screen` to `background: #07080f` (fully opaque) |
| **S3** (Opus report) — `favicon.ico` 404 console error | Added `<link rel="icon" href="data:,">` to `<head>` |

---

## Verification Results

### Core test suite
```
node prototype/tests/core-tests.js
Results: 66 passed, 0 failed
All tests passed.
```

### Browser smoke (Playwright, localhost:8474)

- **01-build-screen.png** — Initial state: Orbitron title, per-bag color identity (HEAD blue, TORSO amber, BACK orange, ARMS green), visible empty cells, workshop floor grid texture, readable shop cards
- **02-item-bought.png** — After buying Beam Rifle: hand panel with amber-pulsing selected item, item info with stats and bonus tag, gold updated 10g → 6g
- **03-item-placed.png** — Placement validation: red invalid-drop cells (3-tall rifle won't fit in 2-row head without rotation) — correct geometry enforcement
- **04-beam-in-head.png** — BEH-001 confirmed: Beam Rifle placed horizontally in Head bag after R key rotation — blue tile in HEAD, hand empty
- **05-battle-screen.png** — DEFEAT! result overlay: Orbitron red glow, monospace stats, amber Continue button — result box slide-up animation visible
- **06-battle-mid.png** — Mid-battle capture: amber event banner "TORSO BEAM SABER FIRES!", colored combat log (blue player / orange enemy), floating -16 damage number, HP bars in correct states, fully opaque background
- **07-run-end.png** — RUN OVER screen: red Orbitron text, dashed amber tape line, monospace stats, amber Start New Run button

All screenshots are in `agent-handoffs/design-screenshots/`.

---

## Remaining Issues / Recommended Next Pass

### Layout dead space (medium priority)
The board still floats center-top in the `#main` flex area, leaving ~30% empty workspace below the board at 1440×900. The workshop floor grid texture makes this feel somewhat intentional, but the vertical gap between board and shop is still large. 

Options for next pass:
- Increase `--cell-size` from 42px to 52px+ to make the board fill more of the viewport
- Vertically center the board+sidepanel in `#main` (`align-items: center`)
- Add a secondary info area below the board (round history, adjacency summary)

### Mech sprites are still placeholders (low priority for 0.1)
The CSS-only sprites (head box, torso rectangle, arm bars) are much more polished than before (schematic grid, blue head glow, reactor dot) but are not recognizable as mechs without context. For 0.2: SVG silhouettes per body part would transform this.

### Fonts require internet connection on first load
Google Fonts are loaded from CDN. The page degrades acceptably (Arial Narrow / Courier New) but the premium feel requires a connection. For production: self-host the font files in `prototype/fonts/`.

### No shop consumption (Opus C1 — not a design issue)
Shop cards don't disappear after purchase. This is a gameplay design decision flagged by Opus. Not addressed in this design pass — it's a game mechanic issue, not a visual one.

### `--cell-size` as a single token
All bag grid sizes derive from `--cell-size`. This means changing one CSS variable resizes all bags uniformly. This is a strength for consistency but may need per-bag overrides if bags gain different cell sizes later.
