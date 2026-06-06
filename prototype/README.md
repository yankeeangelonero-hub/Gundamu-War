# Kitbash Mecha Prototype v0.3

Local, no-build browser prototype for the recursive socket-tree pivot.

## Run

Open `prototype/index.html` in a browser. No backend, package install, or build step is required.

## Controls

- Select an inventory part to highlight compatible sockets.
- Use the front and rear socket panels to mount parts on the currently selected node.
- Select mounted nodes from the blueprint, mounted tree, or player combat rig to drill into their child sockets.
- Use `Detach` to return the selected mounted subtree to inventory with its owned part IDs preserved.
- Use `Run Duel`, `Step`, and `Auto` to play one deterministic primary attack event at a time.
- Buy parts from the shop and draft salvage after wins.

## Core Model

- Mounted identity is a canonical `nodeId` path such as `frame/hand.R/p0/warhead`.
- Owned inventory identity uses stable `ownedInstanceId` values and never uses mounted paths.
- Attachment legality is governed by hardpoint type, part `socketTypeIn`, occupancy, and the depth cap.
- `resolve(tree)` and `simulate(playerTree, enemyTree, seed)` are pure core functions with no DOM dependency.
- Combat event payloads use `{side,nodeId}` for both source and target; target nodes are visual anchors while damage applies to total mech HP.

## Tests

```bash
node prototype/tests/core-tests.js
```
