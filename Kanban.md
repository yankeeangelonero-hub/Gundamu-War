---
project: kitbash-mecha
repo: gundamu-war
doc_type: kanban
status: active
updated: 2026-06-06
---

# Kanban — Kitbash Mecha

Slice-level status. The active direction is v0.4 (pilot-fit on Godot). Backlog items use the
work-map artifact IDs (KM-) from
docs/pilot-and-war-front-high-level-spec-and-work-map.md. None enter implementation planning
until the per-slice gates in the work map (§11) pass.

## Backlog (v0.4)

### [KM-STACK-SPIKE] Godot 4.6 + GDScript confirmation spike
Cutout rig from existing part sprites, runtime part-swap, one authored clip + one FX strip,
seeded deterministic sim, headless re-sim diff, Windows/Steam-PC smoke, mobile-compatibility
smoke, optional web export. Confirms the stack ADR.

### [KM-CORE-PORT] Port the deterministic core to GDScript
Tree, resolve, simulate, seeded PCG — the pure renderer-agnostic core, ported from
prototype/game-core.js.

### [KM-PILOT] Pilot record + growth
Identity, XP/level, skills, sync ceiling, growth history; outcome transitions only.

### [KM-PILOT-FIT] Pilot-machine fit + sync (the star)
Capacity-vs-demand, the fit readout, in-fight sync climbing to a breakthrough; deterministic.

### [KM-ENG] Machine engineering budget (lean)
Power/heat/armor/weight; feeds fit demand.

### [KM-GATE] Skill↔part mutual gating
Inert-state semantics; already prototyped as ability chips.

### [KM-OPP] Opponent-build source interface
Injected; seeded ghost builds now, network-shaped for later.

### [KM-DEPLOY] Deploy-decision test version (next slice)
The tiny editable-parts workshop + deploy gamble + legible watched fight + growth readout. The
first v0.4 playable test; includes 2–3 editable part choices because kitbashing must be playable.

### [KM-WORKSHOP] / [KM-WATCH] / [KM-HOME] / [KM-THEATRE]
The loop screens around the test, sequenced after KM-DEPLOY per the work map.

---

## In Progress

### [spike] Director / combat-viewer visual track (godot_director_spike)
Exploratory render + camera spike, separate from the v0.4 slices. The real Gundam Mk-II mesh
(~20 m, textured) is now viewable in PBR and cel through the `--gundam` viewer with turntable,
pedestrian, and hero-crane framings. Look decision made: realistic PBR over cel. Next is the
mech animation set — see agent-handoffs/handoff-2026-06-14-km-mech-minimum-animation-set.md for
the minimum pose/clip list and the Blender retarget plan.

---

## Done (historical — superseded prototypes)

Version 0.1 (bag-packing browser prototype) shipped all seven slices: static five-bag board,
item placement and rotation, shop and expansion cards, data-driven items and adjacency,
deterministic ATB simulator, 2D battle viewer with paused playback, and the short run loop
with a prebuilt enemy pool. Versions 0.2 (single-canvas theatre) and 0.3 (kitbash socket
tree) followed. The deterministic simulator and the sim-versus-animation separation from
these carry forward into v0.4; the bag/canvas spatial surfaces were dropped in the pivot.

---

## Blocked / On Hold

<!-- Nothing blocked -->
