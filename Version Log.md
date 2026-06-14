---
project: kitbash-mecha
repo: gundamu-war
doc_type: version-log
status: active
updated: 2026-06-14
---

# Version Log — Kitbash Mecha

Tracks released and in-progress versions. Newest first. Append a new entry when a version is
completed or substantially changed.

The version line was rebooted on 2026-06-14 for the Godot build. The proven 3D combat plus
the backpack engineering system is v0.1 of the real game. The browser prototypes further down
were numbered 0.1–0.3 in the prototype era and are kept as pre-history; the earlier unbuilt
v0.4 "pilot-fit" plan is superseded by this reboot, and its pilot layer is now targeted for
v0.2+. The wishlist (r2) vision is unchanged — what moved is the build order, not the destination.

---

## Version 0.1 — Backpack engineering + proven combat (Godot)

**Status:** In progress — the combat viewer is proven and locked; the backpack engineering
system is to build.
**Started:** 2026-06-14 (reboot)

**Goal:** Prove that the mech *engineering* is fun on its own, by building the proven
Backpack-Battles loop on top of the combat we already have. The build is one unified,
expandable spatial grid — a backpack — and whatever you slot appears on the 3D mech you watch
fight. The engineering tension lives entirely in the grid: a single power battery economy
(builders give pool/regen, spenders cost power to fire, multipliers amplify), adjacency
synergy where supports *transform* the weapon they touch (fork, chain, multishot), bag
expansions that are themselves placed items, and recipes that fuse items at the next round
transition. Power scales three independent ways — go-tall, go-wide, tank — with no
rock-paper-scissors counters, which keeps the later async-PvP fair.

A run is a gauntlet: a shop phase (buy, sell, reroll, combine, buy expansions) then a
deterministic auto-battle against a ghost opponent through the existing injected
opponent source. A few hearts; a loss costs one; the run ends at zero or at a win threshold.
No persistence between runs. The pilot is the Backpack-Battles "hero" — she gives a starting
signature item and a small unique-item pool — and is the toehold the v0.2 persistent pilot
grows from.

The 3D combat is proven and frozen as-is: the locked battle showcase is
`fight_log_everything` under `--director=hybrid` (the hybrid grammar — iso base with
cinematic intercut), with the full weapon arsenal, tuned boost, and a tuned kill cam. That
showcase is the v0.1 gameplay-battles guide.

**Build target:** Godot 4.6 + GDScript. Steam PC first, mobile-app compatible second; web
export optional.

**Design record:** docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md
(the authoritative v0.1 engineering design); docs/wishlist/wishlist.md (r2, vision unchanged);
docs/pilot-and-war-front-high-level-spec-and-work-map.md (root contract, rescoped header).

**Known gap to close:** the combat is proven as a *viewer* that plays authored fight logs.
The deterministic sim that turns a backpack build into a fight (the ported core, KM-CORE-PORT)
is the real prerequisite the gauntlet depends on and is not built yet.

---

## Version 0.2+ — The pilot layer returns (planned)

**Status:** Deferred / planned

**Goal:** Bring back the wishlist's pilot-fit star on top of the v0.1 engineering core: the
in-fight sync / breakthrough meter (re-entering as item behaviour — a signature item that
powers up mid-fight), a persistent bonded pilot with no fresh-run reset, salvage acquisition
(strip items off mechs you beat), and grid expansion through pilot milestones rather than
shop purchase. This is where the superseded v0.4 pilot-fit direction lands.

---

## Superseded — Version 0.4 (Godot pilot-fit plan, unbuilt)

**Status:** Superseded by the 2026-06-14 v0.1 reboot; never built.

It planned to lead with the pilot-fit / deploy-gamble star (KM-DEPLOY). The reboot inverts
that order — prove the engineering grid first, defer the pilot layer to v0.2+ — because the
3D combat got proven independently and the engineering loop is the cheaper thing to test for
fun next. The pilot-fit design and its work-map contracts are retained for v0.2+, not discarded.

---

## Prototype era (browser, pre-reboot)

These predate the version-line reboot. The deterministic-sim and sim-versus-animation
separation established here carry forward; the spatial surfaces were dropped or reshaped.

**Prototype 0.3 — Kitbash Mecha (recursive socket tree).** Replaced bag/canvas packing with
a typed tree of snap-together parts, resolved by a pure deterministic sim. Lives under
prototype/ (game-core.js, app.js). The v0.1 reboot replaces this part-*tree* build model with
the single spatial grid, but keeps the pure deterministic core as the thing to port.

**Prototype 0.2 — Single-canvas theatre.** Battles scaled by simulated battle time; an
intermediate step between the bag prototype and the kitbash pivot.

**Prototype 0.1 — Browser "Mech Bags".** A Backpack Battles-style autobattler with shaped
parts across five body-part bags, a shop/expansion loop, a deterministic ATB simulator, and
2D sprite playback. All 7 slices built and verified. The v0.1 reboot returns to this
backpack lineage — one grid instead of five bags — now with the proven 3D combat behind it.

---

<!-- Add new version entries above the "Version 0.2+" planned entry, newest first -->
