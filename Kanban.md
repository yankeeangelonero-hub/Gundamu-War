---
project: kitbash-mecha
repo: gundamu-war
doc_type: kanban
status: active
updated: 2026-06-14
---

# Kanban — Kitbash Mecha

Slice-level status. The active direction is v0.1 (backpack engineering gauntlet over the
proven combat) after the 2026-06-14 version-line reboot. The authoritative v0.1 design is
docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md; the root contract is
docs/pilot-and-war-front-high-level-spec-and-work-map.md (rescoped header). The pilot-fit work
is deferred to v0.2+. Backlog items use KM- work-map IDs.

## Backlog (v0.1) — the backpack engineering gauntlet

### [KM-CORE-PORT] Build-driven deterministic sim (M0)
Port the pure deterministic core so a `{build, seed}` resolves to the event stream the combat
viewer already renders, replacing the authored fight logs. Same build + seed → identical
fight (BEH-D01); headless re-sim parity. The follow-up that makes M1 builds fight — sequenced
after M1 (which is standalone-testable), not before it.

### [KM-SYNERGY] Adjacency synergy + scaling vectors (M2)
Support items that *transform* the weapon they touch (fork/chain/multishot, visible in the
fight), multipliers and defensive HP scaling, and the three independent vectors (go-tall /
go-wide / tank) tuned so none is a trap. Open rule to pin: multi-edge support contact counts
once vs scales with contact length.

### [KM-GRID-MECH] Bag expansions + recipes (M2)
Expansion container items that grant their own cells (and can buff what they hold), plus
recipe/merge fusion resolved at the round transition, with item locking to keep an adjacent
synergy pair from fusing. Both authentic to Backpack Battles; recipes are data.

### [KM-OPP] Opponent-build source
The injected interface that supplies the ghost opponent each round; seeded ghost builds now,
network-shaped for later. Provenance never leaks into the sim or renderer.

### [KM-GAUNTLET] The gauntlet run (M3)
The first full playable: shop phase (buy/sell/reroll/combine/expand) then a deterministic
auto-battle vs a ghost; a few hearts, a loss costs one, end at zero or a win threshold; no
persistence. The pilot is the Backpack-Battles hero — a starting signature item and a small
unique-item pool — the toehold the v0.2 persistent pilot grows from.

---

## In Progress

### [KM-BACKPACK-GRID] Grid + power build editor (M1) — design done
The first slice and the central system (reshapes the old KM-ENG "lean Layer-1 budget"): a 5×4
grid, shaped builder/spender/support placement, the power battery economy (builders give
pool/regen, spenders cost power), support value-modifier adjacency (added/increased/more with
multiplicative cost multipliers), and the preferred-mount + fallback cascade that puts each
slotted weapon on the shared 3D mech. Design committed
(docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md). Next: build-screen
UI design (owner, in Claude design) → implementation plan → build. No code until the plan is
approved.

---

## Done

### Combat viewer / director spike — proven and locked
The Godot 4.6 director spike confirmed the engine and produced the combat viewer: procedural
block-out mechs, the full weapon arsenal (beam/burst/missiles/buster/melee), destructible
city, and the director grammars (cinematic, witness, broadcast, blend, iso, hybrid). The
hybrid grammar (iso base + cinematic intercut) is the chosen production direction. The locked
v0.1 gameplay-battles guide is `fight_log_everything` + `--director=hybrid`, with tuned boost
and kill cam. This also stands in for what was KM-WATCH. Art exploration (cel shading,
textured Gundam viewer) lives on branch spike/art-experiments; the prototype branch is the
block-out build. Look direction: realistic PBR.

---

## Deferred (v0.2+) — the pilot layer

Carried from the superseded v0.4 plan, to return on top of the v0.1 engineering core:

- [KM-PILOT] Persistent bonded pilot record + growth (no fresh-run reset).
- [KM-PILOT-FIT] Pilot-machine fit + the in-fight sync / breakthrough meter (re-enters as
  item behaviour). The wishlist's star, deliberately deferred.
- [KM-SALVAGE] Salvage acquisition — strip items off mechs you beat; ties the homecoming loop.
- [KM-DEPLOY] The deploy gamble (push for a breakthrough vs a safe fit) — a pilot-fit feature,
  deferred with the sync meter.
- [KM-WORKSHOP] / [KM-HOME] / [KM-THEATRE] — the loop screens around the pilot layer.
- Pilot-milestone grid expansion (grow the grid by growing the pilot, replacing shop-bought
  expansions).

---

## Done (historical — superseded browser prototypes)

Prototype 0.1 (bag-packing browser autobattler, all 7 slices), 0.2 (single-canvas theatre),
and 0.3 (recursive kitbash socket tree). The deterministic simulator and the
sim-versus-animation separation carry forward; the spatial surfaces (five bags, then the part
tree) were dropped or reshaped into the v0.1 single grid.

---

## Blocked / On Hold

<!-- Nothing blocked -->
