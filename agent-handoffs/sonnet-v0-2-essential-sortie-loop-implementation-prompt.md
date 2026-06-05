# Sonnet Task — Implement Mech Bags V0.2 essential sortie loop

You are Claude Code Sonnet running inside `D:/Claude/Mech Bags`.

Xuanyue approved Hermes' recommendation and asked to orchestrate amendments to the spec, then implement with Sonnet.

Hermes has already amended the V0.2 draft spec with the approved direction:

- fixed pool of exactly 10 enemy mechs;
- full 10-fight batch resolves quickly/deterministically in background;
- retreat claims the completed batch result, not a partial result;
- spectate shows one representative fight or rolling highlight/summary; spectate is flavor/evidence, not result authority.

Your task: implement the V0.2 essential sortie loop in the existing static prototype.

## Ground rules

- Do not commit, push, reset, clean, or delete unrelated files/screenshots/handoffs.
- This repo is dirty from previous approved prototype/design/V0.2 planning work. Inspect `git status --short` first; preserve existing changes.
- Do not implement the broader warfront map, authored mission board, gear surface, backend, accounts, real async PVP, multiple pilots, titles, seasonal skins, live LLM narration, or deep loot economy.
- Keep the project a static browser prototype with no build step and no runtime backend.
- Preserve Version 0.1 invariants:
  - five independent body-part bags: Head, Torso, Back, Left Arm, Right Arm;
  - unrestricted item placement by anatomy; Beam Rifle in Head remains valid if geometry permits;
  - placement validation remains geometry/overlap/out-of-bounds only;
  - existing shop/placement/rotation/adjacency/battle behavior should not regress;
  - deterministic simulator remains separable from animation/view.
- Mobile/touch placement changes from previous workers must not regress.

## Required reading before editing

Read at least:
- `Readme.md`
- `Kanban.md`
- `prototype/README.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- `prototype/tests/core-tests.js`
- `Project Version/Version 0.2/Version 0_2 Project Specifications.md`
- `Research/User Journeys.md` — Journey 12 and Journey 13
- `Research/Research Documents/concept-handoff-2026-06-05-v0-2-essential-sortie-loop.md`
- `Research/Research Documents/concept-handoff-2026-06-05-pilot-skill-xp-layer.md`
- recent reports if useful: `agent-handoffs/claude-mobile-placement-ux-v2-report.md`, `agent-handoffs/opus-user-journey-vision-fix-report.md`

## Required implementation loop

Implement the smallest playable V0.2 loop:

```text
Customize mech
→ deploy to war
→ fight against a fixed pool of 10 enemy mechs
→ fights resolve quickly/deterministically in background
→ user may spectate or leave spectate at any time
→ user retreats mech
→ loot drop + pilot XP/skill progress + pilot condition summary
→ modify mech
→ fight again
```

### Functional requirements

1. **Theatre pool of 10 enemy mechs**
   - Add a fixed deterministic pool of 10 valid enemy builds.
   - They must be valid under current placement rules.
   - Reuse/extend existing enemy-build data where practical.

2. **Deterministic sortie resolver**
   - Given same player build, enemy pool, and seed, sortie output must be repeatable.
   - Resolve the full 10-fight batch quickly in background.
   - Expose enough facts for report/reward/XP: wins/losses, damage/highlights if available, notable enemies, pilot condition cause, loot seed/result.

3. **Deploy state**
   - From workshop/build state, player can click/tap a clear Deploy/Sortie button.
   - Deploying starts/creates the deterministic 10-fight sortie batch.

4. **Optional spectate / leave**
   - Player can choose to spectate one representative fight or a rolling highlight/summary over the resolved batch.
   - Player can leave spectate at any time without losing sortie state.
   - Spectator view must not be the authority for sortie results; it is a view over resolved/resolving facts.

5. **Retreat result**
   - Player can retreat after the batch has resolved / result is available.
   - Retreat returns to workshop/build state.
   - Retreat summary shows:
     - fights resolved;
     - record vs 10 enemies;
     - loot gained;
     - pilot XP gained;
     - pilot condition;
     - any skill progress;
     - at least one learning signal explaining what to modify before redeploying.

6. **Loot + pilot XP/skill**
   - Keep it deliberately small.
   - Implement one pilot with visible Level/XP and one or two simple skill tracks.
   - XP should be deterministic and readable from sortie participation/survival/performance.
   - Loot can be either simple currency/salvage or a small actionable item/drop signal — choose the smallest form that gives player a reason to modify/redeploy.
   - Pilot skills must not overpower mech buildcraft; they are career identity/progress, not the primary agency.

7. **Modify and redeploy**
   - After retreat, the player must be able to modify the mech and deploy again.
   - The second sortie should use the modified build.

## UI/UX expectations

- Keep current Armored Maintenance Bay visual language.
- Add clear but compact UI surfaces for pilot status, sortie controls, and retreat summary.
- Avoid burying the core build/shop board under too much new chrome.
- Keep mobile usable.
- Make copy concrete: "Deploy", "Spectate", "Leave Spectate", "Retreat", "Loot", "Pilot XP".

## Testing / verification required

Run:

```bash
node prototype/tests/core-tests.js
```

Add or update tests if practical for the deterministic sortie resolver and pilot XP/loot rules. Do not weaken existing tests.

Also perform browser smoke checks. If Playwright/Chrome tools are available, use them; otherwise use the strongest available fallback and document the limitation.

Required manual/browser smoke path:
1. load prototype;
2. buy/place at least one item;
3. deploy;
4. verify 10-fight sortie result exists and is deterministic;
5. spectate or view representative/highlight flow;
6. leave spectate without losing state;
7. retreat;
8. verify loot + pilot XP/condition/skill summary;
9. modify mech;
10. redeploy;
11. verify no browser console errors.

If screenshots are captured, place them under:

`agent-handoffs/v0-2-essential-sortie-loop-screenshots/`

## Required report

Write:

`agent-handoffs/sonnet-v0-2-essential-sortie-loop-implementation-report.md`

Report structure:
1. Summary verdict.
2. Files changed.
3. What was implemented for each V0.2 requirement.
4. Determinism evidence and test command output.
5. Browser/manual smoke evidence.
6. Any deviations from the spec and why.
7. Remaining risks / recommended next pass.

## Success criteria

- Existing 66 core tests still pass, or updated tests pass with no weakened coverage.
- Player can complete customize → deploy → optional spectate/leave → retreat → loot+XP → modify → redeploy.
- Sortie batch resolves deterministically against 10 enemy mechs.
- Spectate is optional and non-authoritative.
- Pilot growth/condition is visible but not bloated.
- No regression to V0.1 placement, mobile editing, adjacency, or battle behavior.
