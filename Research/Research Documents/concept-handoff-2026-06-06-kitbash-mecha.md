---
project: mech-bags (proposed pivot)
working_title: Kitbash Mecha (codename — final name TBD, must avoid licensed Gundam IP)
doc_type: design-spec
status: draft — awaiting owner review
created: 2026-06-06
revised: 2026-06-06 (review round 2: node/combatant identity, inventory identity, target semantics, ATB tie-breaks)
supersedes: nothing yet (proposed Version 0.3 direction; does not amend v0.1/v0.2 canon until adopted)
---

# Design Spec — Kitbash Mecha (proposed pivot from Mech Bags)

## 1. What this is

A browser autobattler where you **kitbash a humanoid mech from a tree of snap-together
parts**, then watch the *exact machine you built* fight in animated 2.5D. It reuses Mech
Bags' good bones — the deterministic ATB simulator, the sim⊥animation separation, the
data-driven parts, the shop/run loop — and replaces the Backpack-Battles spatial-packing
core with **recursive socket assembly**.

This is a genuine direction change, not a reskin. It should be treated as a new version
(Version 0.3 / possibly a renamed project), not a patch to the existing grid game.

### Relationship to existing Mech Bags

| Carries over (keep) | Replaced (retire) |
|---|---|
| Deterministic ATB sim: same build + seed → identical event sequence | Spatial grid / Tetris-style part packing |
| Sim ⊥ animation separation (ARC-001) | "No anatomy police" (BEH-001) — anatomy is now the point |
| Data-driven part definitions (ARC-004) | Five fixed body-part bags |
| One-primary-attack-animation-at-a-time playback (BEH-004) — see §6 | Grid-adjacency synergy (BEH-003) → tree synergy |
| Shop / gold / round / win-loss run loop (FEAT-004) | Single 8×8 canvas of v0.2 |
| Game-term UI copy, not engineering claims (ARC-005) | — |
| No backend in prototype (ARC-002) | — |

> IP note: per CLAUDE.md, no licensed Gundam names, factions, or lore. In-product copy and
> all artifact names use generic terms — "model kits," "kitbash," "frames," "parts." Do not
> reintroduce trademarked genre labels even internally.

## 2. The keystone: one attachment tree, read three ways

A build is a **tree of part instances**. The root is the inner frame; every other instance is
socketed into a hardpoint exposed by its parent. The same tree is the build the player edits,
the stat structure the simulator reads, and the bone hierarchy the renderer mounts. Zero
duplication across the three.

Crucially this is an **instance tree, not a definition list**: the same part *definition* can
appear many times (two Micro-Missiles in one rack), so every mounted instance needs a stable
identity distinct from its definition id. See §2.2.

### 2.1 Part definition schema (data-driven, ARC-004)

A *definition* is the catalog entry. It is referenced by `defId` from instances in the tree.

```
PartDef {
  defId         : string              // catalog id (NOT an instance id)
  name          : string              // display
  socketTypeIn  : string              // this part's connector ("hand-grip", "hardpoint-S", ...)
  hardpoints    : [                   // child sockets this part exposes (may be empty)
    { hpId, type, schematicPos:[x,y], view:"front"|"rear"|"both", rigPivot:[x,y] }
  ]
  // --- build-UI (schematic) presentation ---
  schematicToken: ref                 // cheap icon/footprint for the wireframe build UI
  mountView     : "inherit"|"front"|"rear"|"both"  // default "inherit"; see precedence rule below
  // --- combat (rig) presentation ---
  rigSprite     : ref                 // 3/4 combat sprite
  rigPivot      : [x,y]               // where this part pins to its PARENT's hardpoint
  depthPlane    : int                 // base draw order in the rig (e.g. backpack < torso < near-arm)
  zSwapRules    : [ {clip, depthPlane} ]?  // optional per-clip overrides (near arm to front on "fire")
  // --- sim ---
  stats         : { damage, speed, accuracy, hp, weight, ... }
  synergyRules  : [ ... ]             // local effects, incl. "buffs my children"
  isAdapter     : bool                // bridges mismatched connector types
  cost          : int                 // shop price (gold)
  tags          : [ ... ]             // kit-line, weapon class, etc.
}
```

Presentation must not invent hidden state: front/rear placement and combat layering
(`depthPlane`, `zSwapRules`) are **explicit data**, not derived by the renderer.

**Blueprint-view precedence (P3 resolution):** `hardpoint.view` is authoritative — it decides
which blueprint view(s) a socket renders on. A mounted part normally appears on the same view as
the hardpoint it fills; `mountView` defaults to `"inherit"` to express exactly that. A part may
override with `mountView: "front"|"rear"|"both"` for the rare case where the part should show on
a different/both view than its socket (e.g. a backpack that also needs a front token).
Effective view = `mountView` unless `"inherit"`, in which case the parent `hardpoint.view`.

Data-integrity rule (must hold): an instance's logical socket binding drives **both** its
`schematicPos` on the wireframe **and** its `rigPivot` in combat. A part shown on the head in
the blueprint must mount at the head bone in the fight. Same logical socket, two projections.

### 2.2 Build Tree node + node identity (P1 fix)

The build is a tree of **nodes**, each wrapping a definition:

```
BuildNode {
  nodeId        : string   // STABLE INSTANCE IDENTITY — canonical path (see below)
  defId         : string   // → PartDef
  parentHpId    : string   // the hardpoint id on the parent this node fills (null for frame)
  children      : { hpId → BuildNode }   // one child per filled hardpoint
}
```

**`nodeId` is the canonical tree path** — purely a chain of **hardpoint ids** from the root,
never definition names. Grammar: `frame` then one `/<hpId>` per level, e.g.
`frame/hand.R/p0/warhead` (frame's `hand.R` hardpoint → rack's `p0` hardpoint → missile's
`warhead` hardpoint). The `defId` of the part at each node is stored on the node, separately,
not encoded in the path. Because every hardpoint holds at most one child, this path is **unique
and stable by construction** — which also makes it **deterministic**: the same build always
yields the same set of nodeIds, so the same build + seed yields the same event stream. A short
interned alias may be used in payloads for compactness, but the canonical path is the source of
truth and the debugging handle.

`nodeId` is unique **within a single build only.** Player and enemy can both contain
`frame/hand.R`, so any context that spans both combatants — combat events, targeting, the rig
renderer — must pair `nodeId` with a `side` (`"player"|"enemy"`); see §6. Within one build,
`nodeId` alone suffices. All such references use `nodeId` (+ `side` where cross-build), never
`defId`, when they mean "this specific mounted part."

`nodeId` is **not inventory identity**. It is the mounted address of a part inside the current
tree and may change when a part/subtree is detached, moved, drafted, or re-attached elsewhere.
Owned parts therefore carry a separate stable ownership id:

```
OwnedPart {
  ownedInstanceId : string   // stable while in the player's inventory/run
  defId           : string   // → PartDef
  children?       : { hpId → OwnedPart }   // only if subtree salvage is enabled
}
```

Inventory, shop purchase, salvage, save state, and owned-parts pool mutations use
`ownedInstanceId`. Build Tree attach consumes or references an `ownedInstanceId` and then
generates mounted `nodeId` paths from the current socket location. Detach converts mounted nodes
back into owned inventory entries, preserving `ownedInstanceId`s when the subtree belongs to the
player and minting new ones when enemy salvage is drafted.

### 2.3 The root frame

The inner frame is the tree root (`nodeId = "frame"`) and exposes a fixed base hardpoint set:

`head, torso, shoulder.L, shoulder.R, forearm.L, forearm.R, hand.L, hand.R, leg.L, leg.R,
backpack` (exact list tunable in data).

### 2.4 Recursion (the kitbash mechanic)

Hardpoints nest arbitrarily deep, bounded by typing and a depth cap (default cap: 4 levels
below frame; tunable). Worked example from the owner, with nodeIds shown:

```
frame/hand.R                                   (hardpoint, type "hand-grip")
└─ Missile Rack   node frame/hand.R            (exposes 2 hardpoints type "missile": p0, p1)
   ├─ Micro-Missile  node frame/hand.R/p0
   │  └─ HE Warhead   node frame/hand.R/p0/warhead
   └─ Micro-Missile  node frame/hand.R/p1
      └─ EMP Warhead  node frame/hand.R/p1/warhead
```

The two Micro-Missiles share a `defId` but have distinct `nodeId`s (`…/p0`, `…/p1`), so combat
can say unambiguously which one fired. Because the bone hierarchy IS this tree, when
`frame/hand.R` animates the whole rack → missiles → warheads subtree rides along, no extra code.

## 3. Attach rules — typed ports + adapters

- Every hardpoint has a `type`; every part has a `socketTypeIn`. A part fits a hardpoint only
  when the types match (and the depth cap is not exceeded).
- In the build UI, holding a part **highlights compatible hardpoints** and dims the rest.
- **Adapters** are real, ownable parts with one `socketTypeIn` and one or more differently
  typed hardpoints. They bridge mismatches (e.g. mount a rifle on a leg) at a cost — weight, a
  shop/inventory slot, sometimes a stat penalty. Coherent by default, chaos available for a price.

## 4. Build interaction — wireframe blueprint

The build screen is a **front + rear silhouette wireframe** of the frame with socket nodes
marked (`hardpoint.view` decides which view a socket shows on; see §2.1 precedence). A single 3/4 view cannot show
backpack, rear thrusters, and chest hardpoints at once; front + rear shows **every socket
unambiguously** and is cheap and perfectly consistent to author.

- Click a part from inventory → compatible hardpoints glow on the wireframe (front and/or rear)
  → click a hardpoint to socket it.
- **Drill-in:** selecting a socketed instance reveals *its* hardpoints (its own local wireframe
  region), so nesting is navigable without clutter.
- **Active synergy readout:** while building, the UI shows which **subtree/tag synergies are
  currently active** and which instances cause them (the readability promise that replaces
  grid-adjacency — see §5, acceptance §11).
- **Weight / balance meter:** every part adds weight to its branch. Mass concentrated on one
  limb slows that limb's clip playback and raises stagger vulnerability; balanced builds move
  cleanly. *Where* mass sits matters. (Replaces grid packing as the strategic tension.)
- Remove/replace is non-destructive: detaching a node returns its whole subtree to inventory.

## 5. Stats & synergy resolution

Pure functions over the tree (live in the no-DOM core module).

- **Aggregation:** stats roll up the tree (leaf → … → frame → mech totals). A warhead's stats
  fold into its missile, missiles into the rack, rack into the arm, arm into the mech.
- **Subtree synergy** (replaces grid-adjacency, preserves "readable from placement"): rules
  scope to a node's own subtree, e.g. *"Missile Rack Mk.II: missiles attached to this fire +30%
  faster."* Active synergies are attributed to specific `nodeId`s so the build UI can show them.
- **Weight → mobility:** per-branch weight maps to that branch's action speed / stagger
  threshold via a documented formula (tunable). This is the only "global" derived stat.

## 6. Combat — every part shows

- The **simulator stays pure and deterministic**: takes player tree + enemy tree + seed, emits
  an ordered event list. No DOM, no `Math.random()` inside `simulate()`. Same inputs → byte-equal
  events (ARC-001). Event payload uses node identities:

  ```
  Event { t, source:{side,nodeId}, target:{side,nodeId}, clip, damage, effects }
          // side ∈ "player"|"enemy"; nodeId is build-local (§2.2)
  ```

  Each event end is a **combatant-namespaced reference** `{side, nodeId}`. Because `nodeId` is
  unique only within one build, the `side` disambiguates the two combatants (both may hold
  `frame/hand.R`); together they pinpoint exactly which bone fires and which is struck, even with
  duplicate definitions on the same side.
  `target.nodeId` is a deterministic **hit anchor for animation and effect attribution** in the
  first build of this direction; damage still applies to the target combatant's total mech HP.
  It does not introduce limb HP, part durability, or damageable subcomponents unless a later
  version explicitly adopts those systems.
- **Same-time ATB tie-breaks are deterministic:** events are sorted by `t`; if multiple actions
  become ready at the same simulation time, order by higher resolved initiative/speed, then by a
  seeded stable rank derived from `{seed, side, nodeId}`, then by lexical `{side, nodeId}` as the
  final fallback. No `Math.random()` and no DOM/display timing may affect this ordering.
- The **rig** is assembled live from **both** build trees: each node = a bone parented at its
  parent's hardpoint pivot, drawn at its `depthPlane`, addressed by `(side, nodeId)`. The viewer
  reads the event list and plays the named **clip** (`idle`, `walk`, `fire`, `melee`, `boost`,
  `hit`, `guard`) on the bone named by the event's `source` `(side, nodeId)`.
- Because clips animate **bones, not pixels**, any build animates correctly with **no per-build
  authoring.**
- **ATB playback invariant (carries over from BEH-004):** playback shows **one primary attack
  animation at a time**; display/simulation-playback time **pauses** while that animation plays,
  then resumes to the next ready event. A single source event may bundle its own sub-FX (a salvo
  from a rack counts as one primary animation). Concurrent competing attack animations must not
  occur.
- **2.5D** is faked: layered parallax across `depthPlane`s, per-pose z-order swaps via
  `zSwapRules` (near arm over torso when firing, behind when guarding), subtle bone
  rotation/scale on lunge/hit. Commit to one 3/4 facing; the mech does not rotate to camera.
- **FX** (thruster flames, beam muzzle flashes) are frame-by-frame sprite sequences layered on
  bone positions.
- Skippable/replayable from the same build+seed without re-simulating (ARC-001).

## 7. Run / economy loop

- **Shop** between rounds sells individual parts and adapters for **gold** (existing economy
  knobs carry over).
- **Salvage draft:** on a **win**, the defeated enemy's mounted nodes are converted into a
  **salvage pool** of draftable `OwnedPart` entries; the player **drafts N** to keep (default
  N = 2; tunable). Enemy *builds* therefore double as loot tables — no separate drop authoring.
  Salvage may include parts, adapters, and rare nested sub-parts. A drafted enemy node mints new
  player-owned `ownedInstanceId`s; its old enemy `nodeId` is never preserved as inventory identity.
  Whether a drafted node brings its subtree or is flattened to a single part is a tunable rule.
- **Loss:** no salvage (tunable). Round/gold/win-loss thresholds reuse existing run logic.

## 8. Art pipeline — generate-to-template, rig-by-construction

The runtime engine is the easy part; producing **consistent, riggable parts** is the real,
ongoing cost. The pipeline is designed to make that cost small and AI-friendly.

- **Generate-to-template:** the front/rear wireframe doubles as a **generation jig.** Each
  socket defines a fixed sprite canvas with a *known* anchor (e.g. a forearm sprite is always
  64×96 with the elbow pivot at (32, 8)). Parts are drawn/generated *inside those lines*, so
  **the pivot is known by construction — no rig-detection step.** Parts are born rigged.
- **AI roles (realistic, early 2026):** cutout/background removal — reliable, near-automatic;
  anchor + connector/hardpoint metadata — AI proposes, human confirms (fast); style/scale
  consistency — enforced by the template + a reference/LoRA + QC, not hoped for.
- **Animation is authored once**, by hand or tool (DragonBones / Spine), on the reference
  skeleton — **not per part.** AI does not animate parts.
- **Honest residual:** a short human QC pass per part (confirm anchor, fix joint-overlap/seam
  pieces, check scale) — minutes per part. Fully hands-off AI rigging at production joint
  precision is *not* reliable yet; template-constrained + AI-assisted is.
- Avoid the "decompose a finished hero render into parts" path — author parts as parts.

## 9. Architecture & subsystem boundaries

Sits on Mech Bags' three-layer split (data / simulation / presentation). Each unit has one
purpose, a defined interface, and is independently testable.

| Unit | Purpose | Depends on | Interface |
|---|---|---|---|
| Part Registry (data) | All part definitions + connector-type table | nothing | `getDef(defId)`, `getHardpoints(defId)` |
| Inventory (data) | Owned parts and optional owned subtrees; stable ownership ids across shop/salvage/detach | Part Registry | `addOwned(defId)`, `removeOwned(ownedInstanceId)`, `getOwned(id)` |
| Build Tree (data) | Player's attachment tree; attach/detach with type+depth validation; assigns mounted `nodeId` paths | Part Registry, Inventory | `attach(parentNodeId, hpId, ownedInstanceId)`, `detach(nodeId)`, `validate(tree)` |
| Stat Resolver (sim, pure) | Aggregate stats + subtree synergies (attributed to nodeIds) + weight/balance | Build Tree shape | `resolve(tree) → { derivedStats, activeSynergies }` |
| ATB Simulator (sim, pure) | Deterministic event list (`{side,nodeId}` payloads) with explicit tie-breaks from two resolved builds + seed | Stat Resolver output | `simulate(playerTree, enemyTree, seed) → events` |
| Wireframe Build UI (presentation) | Front/rear blueprint; socket highlight; drill-in; active-synergy readout; weight meter | Build Tree, Part Registry, Stat Resolver | DOM events → Build Tree mutations |
| Rig Renderer (presentation) | Mount both trees as bone hierarchies addressed by `(side,nodeId)`; play clips from events; one-at-a-time playback; 2.5D + FX | events, Part Registry sprites | `loadBuilds({player,enemy})`, `play(events)` |
| Run/Economy (data+flow) | Gold, rounds, shop offers, salvage draft, win/loss | Part Registry, enemy pool | existing loop, extended with salvage |
| Enemy Pool (data) | Static prebuilt enemy trees by round; also the salvage tables | Part Registry | `enemyForRound(n)` |

Determinism boundary holds: Part Registry → Build Tree → Stat Resolver → ATB Simulator are
pure/data; only the two UI units touch the DOM. `simulate()` contains no `Math.random()` and no
rendering, and emits stable node-identity payloads.

## 10. Open knobs, out of scope, YAGNI

**Tunable in data (not decisions to relitigate):** depth cap, salvage draft count, loss-salvage
on/off, drafted-node-brings-subtree vs single-part, weight→mobility formula, same-time ATB
tie-break formula, base hardpoint list, economy numbers.

**Explicitly out of scope for the first build of this direction:**
- Networking, accounts, real matchmaking (ARC-002 holds).
- 3D / true camera rotation (one 3/4 facing only).
- Painting / decals / cosmetic-only customization.
- Pilots, campaign, lore.
- Cross-build trading, persistent ladder.
- Procedural/AI-generated *animation* (clips authored once, by hand/tool).
- Real Gundam IP or licensed assets.

**YAGNI flags:** no part-durability/HP-per-limb system, no heat/ammo economy, no adapter
crafting tree — adapters are just shop/salvage parts. Add only if a later version needs them.

## 11. Acceptance criteria (definition of "this direction works")

1. A build is representable as a typed **instance tree** with stable canonical-path `nodeId`s;
   attaching an incompatible part or exceeding the depth cap is rejected with a readable reason.
2. Two instances of the same `defId` in one build carry distinct `nodeId`s; events name the
   correct instance as `{side, nodeId}`, and identical paths on opposite sides
   (`{player, frame/hand.R}` vs `{enemy, frame/hand.R}`) never collide.
3. Owned parts have stable `ownedInstanceId`s distinct from mounted `nodeId`s; detach/move/salvage
   does not rely on stale tree paths as inventory identity.
4. Recursive nesting works to the example depth (hand → rack → missile → warhead) and the whole
   subtree renders mounted in combat.
5. `resolve(tree)` and `simulate()` are pure: same tree(s) + seed → identical derived stats and
   identical event list (node-identity payloads), with no DOM, `Math.random()`, or other
   unseeded runtime randomness.
6. Equal-ready-time ATB actions resolve in the documented deterministic order, independent of
   display timing.
7. Combat `target.nodeId` is a visual/effect anchor while damage applies to total mech HP; no limb
   HP or part durability is introduced in the first build.
8. The combat rig shows **the parts that were actually built** (swap a part → silhouette changes
   in the fight), animated via clips authored once on the skeleton.
9. **ATB playback invariant holds:** exactly one primary attack animation plays at a time and
   playback time pauses during it (BEH-004 carried over).
10. The build UI is a front/rear wireframe with type-aware socket highlighting, drill-in nesting,
    a live weight/balance meter, **and a readout of currently active subtree/tag synergies with
    the instances causing them.**
11. Run loop: shop purchase with gold + salvage draft on win both mutate the owned-parts pool.
12. One worked vertical slice (a few parts, one enemy) plays end-to-end in the browser with no
    build step and no backend.

---

### Promotion note
If adopted, this graduates into the project's canonical docs (a new `Project Version/Version
0.3/` spec + an updated High Level Project Specifications entry retiring BEH-001 and BEH-003 for
this direction, and re-affirming BEH-004). Until then it lives here as a brainstorm artifact.
