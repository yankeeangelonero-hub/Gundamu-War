# Codex v0.3 Kitbash Playable Slice Report

## Files changed in this focused fix

- `prototype/app.js`
- `prototype/styles.css`
- `agent-handoffs/codex-v0-3-kitbash-playable-slice-report.md`

The worktree already had v0.3 changes in `prototype/game-core.js`, `prototype/index.html`, `prototype/tests/core-tests.js`, and `prototype/README.md`; this pass treated those as the baseline and did not revert them.

## What was fixed

- Replaced the stale v0.2 DOM controller with a v0.3 controller wired to the current `prototype/index.html` IDs and the current `window.MechBags` API.
- Populates inventory, front sockets, rear sockets, mounted tree, selected-node inspector, resolve panels, shop, salvage, player rig, enemy rig, HP bars, and combat event log.
- Supports selecting inventory, showing eligible sockets, attaching to legal sockets, selecting mounted nodes, detaching selected nodes, resetting the run, rerolling shop, buying shop parts, drafting salvage, running a deterministic duel, stepping events, and toggling auto playback.
- Replaced the old v0.2 stylesheet with styles for the current v0.3 markup so the playable slice is laid out and readable when `prototype/index.html` is opened directly.

## Tests and verification

```bash
node --check prototype/app.js
node prototype/tests/core-tests.js
```

Result:

```text
Results: 81 passed, 0 failed
All tests passed.
```

Rendered-DOM harness checks also passed for: panel population, inventory selection, eligible socket attach, detach, shop buy, reroll response, salvage draft, run duel, step event, and auto start/stop.

The in-app Browser QA path could not run because the local Browser automation bridge failed twice at startup with `windows sandbox failed: spawn setup refresh`. No standalone browser runner was available on PATH, so screenshot-based QA remains unverified in this environment.

## Browser-play instructions

Open `prototype/index.html` directly in a browser; no server or build step is required.

1. Select a part in Inventory.
2. Click an enabled row in Eligible Sockets, or click an eligible open socket in Front Sockets or Rear Sockets.
3. Click mounted nodes in the Mounted Tree, socket panels, or player Combat Rig to inspect them.
4. Use Detach to return the selected mounted subtree to Inventory; Reset restores the starter state.
5. Use Shop Buy and Reroll to add new parts. Use Salvage Draft to add salvage parts.
6. Set a Seed, click Run Duel, then use Step for one event at a time or Auto for playback.

## Caveats

- Combat rig visuals are code-native token trees, not production art or true skeletal animation.
- Damage still applies to total mech HP; target `nodeId` is a visual/effect anchor only.
- Shop and salvage are minimal proof-of-flow systems and are not economy-balanced.
- Browser screenshot/console QA is still recommended once the Browser plugin/runtime is healthy.
