# Codex handoff — Build Kitbash Mecha v0.3 playable vertical slice

You are Codex working in `D:/Claude/Mech Bags`. Implement a playable local browser prototype slice using plain HTML/CSS/JavaScript. Do not use Claude. Do not install dependencies. Do not commit. Avoid licensed Gundam names/lore/assets; use generic kit/model/mecha terminology.

## Read first

1. `CLAUDE.md`
2. `Project Version/Version 0.3/Version 0_3 Project Specifications.md`
3. `Research/Research Documents/concept-handoff-2026-06-06-kitbash-mecha.md`
4. Existing prototype files under `prototype/`, especially `game-core.js`, `app.js`, `index.html`, `styles.css`, and `tests/core-tests.js`.

## Task

Build a playable Kitbash Mecha vertical slice that may replace the current v0.2 canvas/theatre UI inside the existing `prototype/` plain-browser app. Keep it no-build-step and no-backend. Preserve a pure core module usable from Node tests.

## Must-have acceptance

1. Build tree has root `frame`, typed hardpoints, recursive nesting to at least hand → rack → missile → warhead.
2. Two mounted instances with the same `defId` have distinct canonical `nodeId`s (`frame/.../p0`, `frame/.../p1`, etc.).
3. Inventory uses stable `ownedInstanceId`s distinct from mounted `nodeId`; detach returns mounted subtree parts to inventory.
4. Incompatible attachments and depth-cap violations are rejected with readable UI feedback.
5. Build UI shows front/rear blueprint sockets or equivalent front/rear socket panels, compatible highlighting/eligible socket list, selected node drill-in, active synergies with causing `nodeId`s, and branch weight/balance.
6. `resolve(tree)` and `simulate(playerTree, enemyTree, seed)` are pure and deterministic; no DOM and no unseeded randomness inside simulation.
7. Same-time ATB tie-breaks are deterministic: by time, higher resolved speed/initiative, seeded stable rank from `{seed, side, nodeId}`, then lexical fallback.
8. Event payloads use `{side,nodeId}` for source and target. `target.nodeId` is a visual/effect anchor only; damage applies to total mech HP.
9. Combat view/rig shows the actual mounted parts and plays one primary attack event at a time. Swapping a mounted part should visibly change the silhouette/token tree and event source.
10. Browser slice runs by opening `prototype/index.html`; tests run with `node prototype/tests/core-tests.js`.

## Implementation guidance

- It is acceptable to rewrite the prototype substantially for the pivot, but keep files simple.
- Keep data-driven part definitions: `defId`, `socketTypeIn`, `hardpoints`, stats, tags, weight, view/depth metadata if useful.
- Implement `OwnedPart`, `BuildNode`, inventory attach/detach, canonical path nodeIds.
- Minimal catalog suggestion: frame, missile rack, two micro-missiles, HE warhead, EMP warhead, shoulder cannon, backpack thruster, hand adapter, armor plate.
- Minimal enemy: one static enemy tree plus maybe a second if easy.
- UI can be pragmatic: socket buttons/cards are fine if they clearly represent front/rear blueprint and nested hardpoints. Do not spend time on production art.
- Add tests covering node identity, duplicate defIds, owned identity detach, invalid attachment/depth cap, deterministic resolve/simulate, tie-breaks, and event payload source/target shape.
- Update `prototype/README.md` to describe the new controls and test command.
- Write an implementation report to `agent-handoffs/codex-v0-3-kitbash-playable-slice-report.md` with: files changed, what was built, tests run and result, known caveats, and any pitfalls/edge cases discovered.

## Non-goals

No backend, no accounts, no real networking, no 3D, no production art, no limb HP/part durability, no heat/ammo economy, no pilot/campaign system, no licensed IP.
