# Hermes controller verification — v0.3 Kitbash Mecha playable slice

Date: 2026-06-06

## Scope

Controller QA after Codex implementation of the provisional Version 0.3 Kitbash Mecha vertical slice.

## Commands run

```bash
git status --short
node --check prototype/app.js
node prototype/tests/core-tests.js
```

Result: `node --check` passed and `node prototype/tests/core-tests.js` reported `81 passed, 0 failed`.

## Browser smoke

Opened directly:

```text
file:///D:/Claude/Mech%20Bags/prototype/index.html
```

Verified in browser:

- Page title is `Kitbash Mecha v0.3`.
- `window.MechBags` is present.
- Dynamic panels populate instead of blank shell:
  - Front sockets: 12 rows at initial load.
  - Inventory: 12 owned parts at initial load.
  - Buttons present: 80 at initial load.
- Selecting an inventory `Shoulder Cannon` shows compatible/incompatible socket reasons and an eligible `frame/shoulder.R` socket.
- Attaching that shoulder cannon through the eligible socket reduces inventory from 12 to 11 and increases mounted tree from 10 to 11 nodes.
- Running a duel loads events: banner `Rack Line Test Frame loaded. Step through 12 events.`
- Stepping one event updates combat state: banner `t72: player Micro Missile deals 24`, enemy HP changed from `158 / 158` to `134 / 158`, and source/target rig highlights appeared.
- Browser console after the smoke had zero messages and zero JavaScript errors.

Screenshot evidence captured via Hermes browser: `C:\Users\Yanjie\AppData\Local\hermes\cache\screenshots\browser_screenshot_4fdf2be8070a4ca4851dee55b62212f7.png`.

## Interpretation

The playable slice is implemented and smoke-verified. It is not formally a closed Vouse slice: Version 0.3 remains `draft-proposed`, pending lifecycle reconciliation and owner adoption decision.

## Remaining caveats

- UI is dense and prototype-grade; mobile/responsive play was not deeply tested.
- Combat rig is a token/tree visualization, not production skeletal art.
- Shop/salvage economy is a proof of flow and not balanced.
- Damage applies to total mech HP; target node IDs are visual/effect anchors, as intended for this slice.
