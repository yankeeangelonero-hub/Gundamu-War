---
project: kitbash-mecha
repo: gundamu-war
doc_type: roadmap
status: active
updated: 2026-06-14
---

# Roadmap — Kitbash Mecha

The active direction is v0.1 of the Godot build: the backpack engineering system over the
proven 3D combat (see Version Log.md and
docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md). The version line was
rebooted on 2026-06-14; the earlier v0.4 pilot-fit plan is deferred to v0.2+. The browser
prototypes (0.1–0.3) are superseded pre-history whose deterministic-sim foundation carries
forward.

## Track: v0.1 — Backpack engineering gauntlet

Goal: prove the backpack *engineering* is fun before any bespoke pilot meta is grafted on, by
building the proven Backpack-Battles loop — a unified spatial grid, a power battery economy,
adjacency-transforming supports, recipes, bag expansions, three scaling vectors — on top of
the combat we already have. Steam-first, mobile-compatible, Godot 4.6 / GDScript.

The combat viewer is already proven and locked: `fight_log_everything` under
`--director=hybrid` is the gameplay-battles guide everything is built to feed.

Build order note: the milestone numbers are identities, not strict sequence. The grid build
editor (M1) is built first because it is standalone-testable without a fight; the build-driven
sim (M0) follows to wire builds into the fight. So the real order is M1 → M0 → M2 → M3.

---

### M1 — Grid + power build editor (first slice)

**Status:** Designed — spec committed 2026-06-14
(docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md). Next: the
build-screen UI design (in Claude design), then an implementation plan, then build.

**Goal:** The build editor. A 5×4 grid; place shaped builder/spender/support items; a single
power battery economy (pool + regen); supports apply value modifiers (added/increased/more) by
adjacency to the weapons in their slots, with multiplicative power-cost multipliers. Per-item
numbers on the grid, and the slotted weapons mount on the shared 3D mech via the
preferred-mount + fallback cascade. No live fight in this slice — that is M0.

**Done when:** a player can place builders, weapons, and supports; see each weapon's effective
damage and power-per-shot change as supports cover it; read the build's total pool and regen;
and see the weapons mount on the 3D mech. Resolver and grid are pure and unit-tested.

---

### M0 — Build-driven deterministic sim (follow-up to M1)

**Status:** Not started. Numbered as the foundational sim, but sequenced after M1 since the
editor is testable on its own.

**Goal:** Turn a backpack build into the fight the viewer already renders. Today the viewer
plays authored `fight_log_*.json` files; M0 ports the pure deterministic core so a
`{build, seed}` pair produces the event stream the director and garnish consume. Same build +
seed must produce the identical fight (BEH-D01), and a headless re-sim must reproduce it. This
is what makes the M1 economy legible in motion — a power-starved mech visibly goes quiet.

**Done when:** an M1 build resolves to a deterministic event stream that drives the existing
combat viewer, and a headless re-run is byte-identical.

---

### M2 — Synergy, scaling, and grid mechanics

**Status:** Not started (needs M1 for the build, M0 to show transforms in the fight).

**Goal:** The depth that makes placement a craft. Adjacency-transforming supports (fork,
chain, multishot — visible in the fight), multipliers and defensive HP scaling, the three
independent vectors (go-tall / go-wide / tank) tuned so none is a trap, bag-expansion
container items, and recipe/merge fusion resolved at the round transition with item locking.

**Done when:** tall, wide, and tank builds are each viable, support placement visibly changes
the weapon in the fight, and expansions + recipes work end to end.

---

### M3 — The gauntlet run

**Status:** Not started (blocked on M2).

**Goal:** The first full playable run. A shop phase (buy, sell, reroll, combine, buy
expansions) then a deterministic auto-battle against a ghost opponent through the injected
opponent source; a few hearts, a loss costs one, the run ends at zero or at a win threshold;
no persistence. The pilot is the Backpack-Battles hero — a starting signature item and a
small unique-item pool the shop can offer.

**Done when:** a tester can play a full escalating gauntlet — shop, build, fight, win or lose
a heart — and the engineering decisions feel like the fun, with the pilot-as-item-source
toehold in place for v0.2.

---

## Future (v0.2+ — not planned in detail)

The pilot layer returns on top of the v0.1 engineering core: the in-fight sync / breakthrough
meter (re-entering as item behaviour), a persistent bonded pilot with no fresh-run reset,
salvage acquisition (strip items off mechs you beat), and grid expansion through pilot
milestones rather than purchase. This is where the deferred v0.4 pilot-fit direction lands.

Further out, no dates: the networked backend for real-player ghosts and async-PvP; the
two-faction GM-steered live war; a stable of multiple pilots; the opt-in pilot-behaviour rule
layer; grunts in the field; research as a second use for salvage.
