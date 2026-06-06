---
project: mech-bags
working_title: Kitbash Mecha
codename_note: "Avoid licensed Gundam IP in all product/code/docs copy."
doc_type: version-spec
version: "0.3"
status: draft-proposed
created: 2026-06-06
updated: 2026-06-06
lifecycle_note: "Proposed/provisional pivot pending formal Version 0.1 close and reconciliation of the draft-proposed Version 0.2 line. Xuanyue explicitly authorized a playable prototype slice before the formal Vouse close/open ceremony."
slices:
  - SLICE-01
---

# Version 0.3 Project Specifications — Kitbash Mecha Vertical Slice

## Version goal

Validate the proposed pivot from spatial bag/canvas packing to recursive socket assembly: the player kitbashes a humanoid mech from a typed tree of snap-together parts, sees active subtree synergies and branch weight, then watches the exact mounted parts fight in a deterministic one-at-a-time ATB duel.

This is a core direction change, not a patch to Version 0.2. It supersedes the single-canvas Version 0.2 design only if Xuanyue adopts it after playtest.

## Scope boundary

Version 0.3 is still a local browser prototype. No backend, accounts, networking, 3D renderer, real licensed IP, limb HP, part durability, painting/decals, pilots, campaign, or production art pipeline is included.

## In scope

| Feature | Notes |
|---|---|
| Recursive typed build tree | Root frame exposes hardpoints; mounted nodes get canonical path `nodeId`s. |
| Owned inventory identity | Inventory/shop/detach use `ownedInstanceId`, not mounted paths. |
| Front/rear blueprint build UI | Type-aware socket highlighting, drill-in/select mounted node, attach/detach. |
| Subtree synergy readout | Active synergies name the mounted `nodeId`s causing them. |
| Weight/balance readout | Branch weight visibly affects branch/action speed. |
| Deterministic ATB duel | `simulate(playerTree, enemyTree, seed)` emits stable `{side,nodeId}` source/target events. |
| Exact-build rig view | Combat display mounts every built node as a simple 2.5D bone/token tree. |
| One primary attack at a time | Playback pauses on each primary attack animation/event before advancing. |
| Minimal shop/salvage loop | Shop can buy parts/adapters; win can draft salvage into inventory if time permits. |

## Behaviour invariants proposed for this direction

- **BEH-015 — Build anatomy is socket identity:** Placement legality is governed by typed hardpoints and adapters, not grid geometry.
- **BEH-016 — Same tree drives build, sim, and rig:** A mounted part's logical socket binding must drive both blueprint position and combat mount position.
- **BEH-017 — Mounted identity is path identity:** Mounted references use canonical `nodeId` paths and cross-combat references pair them with `side`.
- **BEH-018 — Inventory identity is separate:** Shop, owned pool, detach, and salvage use `ownedInstanceId`, never stale mounted paths.
- **BEH-019 — Tree consequences are readable:** Subtree synergies and branch weight must be visible while building.
- **BEH-004 reaffirmed — One attack animation at a time:** Combat playback shows one primary ready attack animation at a time.

## Architecture constraints proposed for this direction

- **ARC-011 — Typed instance-tree core:** Part registry, inventory, build tree, stat resolver, and simulator are pure/data modules with no DOM dependency.
- **ARC-012 — Canonical path nodeIds:** `nodeId` is `frame` plus a slash-separated chain of hardpoint ids; definitions are not encoded in paths.
- **ARC-013 — Combat references are combatant-namespaced:** Events identify mounted parts as `{side,nodeId}`.
- **ARC-014 — Target nodes are visual anchors first:** First build damage applies to total mech HP; `target.nodeId` is a hit/effect anchor, not limb HP.
- **ARC-009 reaffirmed — Local prototype only:** All state lives in browser/local files; no backend dependency.

## Slices

| # | Title | Kind | Evidence signal |
|---|---|---|---|
| 01 | Kitbash tree duel vertical slice | Feature | Player can attach nested parts to typed sockets, read active synergies/weight, run a deterministic duel, and see the built parts animate as source/target nodes. |

### Slice 01 — Kitbash tree duel vertical slice

Build a playable browser slice that proves the central promise: one attachment tree is edited by the player, resolved by pure sim code, and rendered as the combat rig. The slice may replace the current prototype UI rather than preserving Version 0.2's canvas theatre loop.

Acceptance shape:

1. Build tree has root `frame`, typed hardpoints, recursive nesting to at least hand → rack → missile → warhead.
2. Two mounted instances with the same `defId` have distinct canonical `nodeId`s.
3. Inventory uses stable `ownedInstanceId`s, and detach returns mounted subtrees to inventory without relying on `nodeId` as ownership identity.
4. Incompatible attachments and depth-cap violations are rejected with readable UI feedback.
5. Build UI shows front/rear blueprint sockets, compatible highlighting/eligible socket list, selected node drill-in, active synergies with causing `nodeId`s, and branch weight/balance.
6. `resolve(tree)` and `simulate(playerTree, enemyTree, seed)` are pure and deterministic.
7. Equal-ready ATB tie-breaks are deterministic and documented in code/tests.
8. Event payloads use `{side,nodeId}` for source and target; target node is visual/effect anchor while damage applies to total mech HP.
9. Combat rig/view shows the actual mounted parts and plays one primary attack event at a time.
10. The prototype runs end-to-end in the browser with no build step and no backend.

## What this version does not include

- Real Gundam names, factions, lore, or assets.
- 3D camera rotation or production art.
- Limb HP, part durability, ammo/heat economies, adapter crafting, or pilot systems.
- Full run economy beyond a minimal shop/salvage proof if time permits.

## Research and journey references

- `Research/Research Documents/concept-handoff-2026-06-06-kitbash-mecha.md`

## Lifecycle note

This is a draft-proposed/provisional implementation target. Do not mark the slice or version Done until the formal Vouse lifecycle is reconciled and owner approval is recorded.
