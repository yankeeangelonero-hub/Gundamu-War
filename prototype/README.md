# Mech Bags 0.1 — Prototype

Browser prototype for a Backpack Battles-style autobattler with five mech body-part bags.

## How to play

Open `prototype/index.html` directly in a browser. No server required.

## Controls

- **Buy items** — click a shop card (bottom bar) to purchase if you have enough gold
- **Place items** — after buying, click the item in your Hand, then click a grid cell to place it
- **Rotate** — press `R` or click the Rotate button while an item is selected
- **Pick up** — click a placed item on the board to return it to your Hand
- **Sell** — click the `$n` sell button next to any Hand item
- **Reroll** — click Reroll (1 gold) to shuffle shop offers
- **Battle** — click `Battle!` when ready
- **Skip Battle** — instantly resolves the battle without animation
- **Escape** — deselects the current item

## Files

| File | Purpose |
|---|---|
| `index.html` | Entry point — open this in browser |
| `styles.css` | All styling |
| `game-core.js` | Data, simulation, placement logic — no DOM |
| `app.js` | DOM controller, shop/battle/run state |
| `tests/core-tests.js` | Node.js test suite |

## Running tests

```
node prototype/tests/core-tests.js
```

All 66 tests pass (rotation, placement, adjacency, HP, deterministic simulation, enemy build validity, run thresholds).

## Rules

- Five bags: Head, Torso, Back, Left Arm, Right Arm
- Items can go in **any bag** — no anatomy restrictions
- Placement fails only for geometry (overlap or out-of-bounds)
- Body expansion cards add 1 row to the named bag only
- Same-bag adjacency bonuses show with a green glow
- Run ends at **5 wins** or **3 losses**
- Economy: start 10g | win +6g | loss +4g | reroll 1g | sell floor(cost/2)
