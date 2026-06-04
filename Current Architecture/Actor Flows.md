---
project: mech-bags
doc_type: actor-flows
version: "0.1"
status: draft
updated: 2026-06-04
---

# Actor Flows — Mech Bags Version 0.1

Describes how the primary actors interact with the system's major components. See `Current Architecture.md` for component details.

---

## Actor: Player

### Flow 1 — Build and shop phase

```
Player opens browser
    → Browser loads single HTML file
    → Run initialised: round 1, starting gold, empty bags

Player sees build board (five bags) and shop row
    → Shop generates item offers + possible expansion card
    → Player inspects item card (tooltip shows stats, shape)

Player buys item
    → Gold deducted
    → Item added to staging area / hand

Player drags item to a bag grid
    → Build Board validates geometry only (overlap, bounds)
    → If valid: item placed, adjacency bonuses recalculated and shown
    → If invalid: placement rejected with visual feedback (no anatomy message)

Player buys bag expansion card (e.g. "Head Expansion")
    → Gold deducted
    → Head bag grid grows by the specified number of cells
    → Other four bags unchanged (BEH-002)

Player clicks "Battle / Ready"
    → Run Loop hands builds to Battle Simulator
```

### Flow 2 — Battle phase

```
Battle Simulator receives player build + enemy build + seed
    → Computes full ATB event list deterministically
    → Returns event list + winner + final HP

2D Battle Viewer loads event list
    → Renders player sprite (left) and enemy sprite (right)
    → Advances display time to first event
    → Pauses display time
    → Plays weapon animation anchored to bag origin
    → Updates HP bar + appends to combat log
    → Resumes display time
    → Repeats until all events consumed or HP = 0

Battle result screen shown
    → Win/loss banner
    → Short reason summary (e.g. "Your Head Beam Rifle dealt the most damage")
    → Key events listed
    → "Continue" button → advances to next shop round
```

### Flow 3 — Run end

```
If wins ≥ threshold (e.g. 5): Run Win screen shown
If losses ≥ threshold (e.g. 3): Run Loss screen shown
    → Either screen offers "Start new run" → resets run state
```

---

## Actor: Opponent Build Pool

### Flow — Build retrieval

```
Run Loop requests enemy build for round N
    → Enemy Build Pool returns pool[N % pool.length]
    → Build is a static data object (same schema as player build)
    → No network call, no randomness beyond seed (ARC-002)
```

---

## Actor: Battle Simulator

### Flow — Simulation execution

```
Receives: playerBuild, enemyBuild, seed
    → Initialises ATB timers for all attack items in both builds
    → Enters simulation loop:
        1. Find minimum next-ready time across all timers
        2. Advance simulation clock to that time
        3. Emit attack event: { time, attackerSide, bag, itemId, damage, effects }
        4. Apply damage to target HP
        5. Reset timer for fired item
        6. If either HP ≤ 0: exit loop
    → Returns: { events: [...], winner: 'player'|'enemy', finalPlayerHP, finalEnemyHP }

Determinism guarantee:
    → Same playerBuild + enemyBuild + seed → identical event list every call
    → No DOM, no Date.now(), no Math.random() inside simulator
    → Seed-based pseudo-random for any stochastic effects
```

---

## Actor: Design Reviewer

### Flow — Design review

```
Design Reviewer opens browser prototype (after M1 is complete)
    → Plays two or more runs
    → Checks against requirements in agent-handoffs/claude-design-ui-requirements.md
    → Notes discrepancies: bag readability, expansion clarity, ATB animation timing, build weirdness

Design Reviewer documents feedback
    → Feedback feeds into M2 tuning work
    → Does not require source access; uses the running prototype
```

---

## Cross-actor interaction summary

```
Player  ──buy item──────────────────────►  Shop / Run Loop
Player  ──place item────────────────────►  Build Board
Player  ──buy expansion─────────────────►  Shop / Run Loop ──expand bag──► Build Board
Player  ──click Battle──────────────────►  Run Loop

Run Loop  ──request enemy build──────────►  Enemy Build Pool
Run Loop  ──builds + seed────────────────►  Battle Simulator
Battle Simulator  ──event list───────────►  2D Battle Viewer

2D Battle Viewer  ──result + key events──►  Player (result screen)
Player  ──continue──────────────────────►  Run Loop (next round)
```
