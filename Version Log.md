---
project: kitbash-mecha
repo: gundamu-war
doc_type: version-log
status: active
updated: 2026-06-06
---

# Version Log — Kitbash Mecha

Tracks released and in-progress versions. Newest first. Append a new entry when a version is
completed or substantially changed.

---

## Version 0.4 — Pilot-fit and War-front direction

**Status:** In planning (no build yet)
**Started:** 2026-06-06

**Goal:** Reframe the game around a persistent pilot and a living war. The player is the
partner engineer who fits a mech out for one bonded pilot, weighs a deploy gamble, and
watches the duel; the experience is a positive power loop building toward an ace, and the
defining endgame is async PvP against other real players' stored builds. The build is
governed by a three-layer constraint model (machine engineering, pilot-machine fit, pilot
behavior) with pilot-fit as the star, expressed in combat as sync climbing toward a
breakthrough rather than stress toward a breakdown.

**Build target:** Godot 4.6 + GDScript (provisional; see the stack ADR). The earlier
plain-web prototype is a reference to port.

**Design record:** docs/wishlist/wishlist.md (r2), docs/wishlist/flows/,
docs/pilot-and-war-front-high-level-spec-and-work-map.md (r2),
docs/adrs/2026-06-06-build-stack-decision.md, agent-handoffs/Kitbash - Mechanics Handoff.md.

**Next test version:** the deploy-decision prototype (KM-DEPLOY) — the choice of pushing the
pilot for a breakthrough versus a safe fit, with a legible watched fight and a growth readout.

---

## Version 0.3 — Kitbash Mecha prototype

**Status:** Built (prototype), superseded by the v0.4 direction
**Goal:** Replace the bag/canvas spatial packing with recursive socket assembly — a typed
tree of snap-together parts edited by the player, resolved by a pure deterministic sim, and
rendered as the combat rig. Lives under prototype/ (game-core.js, app.js). Introduced the
canonical nodeId paths, ownedInstanceId inventory identity, {side,nodeId} combat events, and
the front/rear blueprint build UI. The pure deterministic core carries forward as the thing
to port into the Godot build.

---

## Version 0.2 — Single-canvas theatre prototype

**Status:** Built (prototype), superseded
**Goal:** A single-canvas theatre loop with battles scaled by simulated battle time — an
intermediate step between the bag prototype and the kitbash pivot.

---

## Version 0.1 — Browser prototype ("Mech Bags")

**Status:** Built (prototype, all 7 slices complete), superseded
**Goal:** A Backpack Battles-style autobattler with shaped parts across five body-part bags,
a shop/expansion loop, a deterministic ATB simulator, and 2D sprite playback against a
prebuilt enemy pool. The deterministic-sim and sim-versus-animation separation established
here carry forward; the spatial bag-packing surface was dropped in the pivot. Slices 01–07
were all built and verified (see Kanban history).

---

<!-- Add new version entries above this line, newest first -->
