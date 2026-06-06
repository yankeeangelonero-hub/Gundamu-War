---
project: kitbash-mecha
repo: gundamu-war
spec_id: KM-DEPLOY
version: "0.4"
doc_type: slice-spec
status: draft
created: 2026-06-06
updated: 2026-06-06
parent_spec: docs/pilot-and-war-front-high-level-spec-and-work-map.md
stack_prerequisite: docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md
owner_decision: "First playable slice must include some editable parts because kitbashing is the main mechanic to play."
---

# KM-DEPLOY — First Playable Deploy Slice

## 0. Parent change proposals

None. This draft clarifies KM-DEPLOY's playable scope: it is still tiny, but it must include a small editable-part workshop because kitbashing is the main thing the player should play with before choosing safe fit vs push.

## 1. What this slice is

KM-DEPLOY is the first real v0.4 game-feel slice after the Godot platform spike. The player is the engineer. They make a small but real edit to one pilot's mech, read how that edit changes pilot-machine fit, choose a safe deployment or a pushed breakthrough attempt, watch one deterministic duel, and see the pilot return with a clear growth result.

The slice should answer one product question: does editing the machine and then deciding whether to push the pilot feel meaningful? It should not try to answer whether the full war endgame, backend, multiple-pilot roster, or complete workshop economy works.

## 2. Vocabulary

- **Editable part set** — the tiny set of parts that the player can swap in this slice. It is not the full inventory.
- **Fit demand** — the demand a mech build places on the pilot. More aggressive parts raise demand.
- **Safe fit** — a deployment setup where demand stays comfortably under the pilot's current capacity.
- **Push fit** — a deployment setup where demand stretches the pilot for a possible breakthrough.
- **Breakthrough progress** — positive growth progress earned by surviving or performing under a stretch fit. No permanent harm.

## 3. Behaviour

1. The player starts with one pilot and one base mech.
2. The workshop panel offers a very small editable part set: two or three swappable choices, enough to change demand and combat output.
3. Editing a part immediately changes visible build stats and fit forecast.
4. The forecast tells the player whether the build is safe, stretched, or over-demanding for the pilot.
5. The player chooses one deployment posture:
   - **Safe Fit**: lower risk, stable sync, modest growth.
   - **Push for Breakthrough**: higher demand, harder fight, larger sync/growth upside.
6. The duel plays without direct player control.
7. The duel shows sync climbing and key events in a legible event log or UI readout.
8. The result screen shows win/loss, sync gained, growth gained, and breakthrough progress if relevant.
9. Underperformance is explained through fit/sync, not unexplained luck.
10. The pilot is never permanently harmed.

## 4. Surfaces and controls

### Workshop / fit panel

Required controls:

- 2–3 editable part choices. Recommended minimum:
  - weapon: light rifle vs heavy cannon/saber;
  - mobility or booster: stable thruster vs high-output booster;
  - optional armor/shield: light plating vs heavy shield.
- A visible fit forecast that updates when parts change.
- A short explanation line: e.g. `Safe fit: pilot can handle this cleanly` or `Push fit: breakthrough possible, fight gets harder`.

### Deploy panel

Required controls:

- `Deploy Safe` button.
- `Push for Breakthrough` button.
- Clear projected consequence text for both buttons.

### Duel-watch panel

Required controls/signals:

- Start / watch duel.
- One primary attack animation at a time.
- Sync meter or sync log.
- Event log with deterministic events.

### Homecoming/result panel

Required signals:

- Win/loss.
- Sync gained.
- XP/growth gained.
- Breakthrough progress or breakthrough earned.
- Positive-valence copy: no injury, no permanent damage to the pilot.

## 5. Data and integration notes

The slice may use hardcoded local data if that keeps it small, but the data shape should point toward future data-driven definitions.

Minimum data:

- One pilot record:
  - id/name;
  - capacity;
  - sync ceiling;
  - xp/growth;
  - breakthrough progress.
- One base mech build.
- 4–6 candidate parts total, with at least:
  - demand modifier;
  - combat modifier;
  - label/description;
  - slot/type.
- One seeded ghost opponent.
- One deterministic seed.

The implementation should keep simulation and presentation separable. If the slice uses Godot UI and animation, the deterministic event/result generation should still be callable without relying on frame delta, physics, or animation timing.

## 6. Acceptance checks

### AC-1 — Editable parts change fit forecast

- **Setup:** Start a fresh slice run with the default pilot and base mech.
- **Action:** Swap at least one editable part from the safe/default option to a higher-demand option.
- **Observable signal:** Fit forecast text and numeric/ordinal demand indicator update on screen; a verification log or screenshot captures before/after.
- **Expected value:** The high-demand part increases fit demand and changes the forecast state or projected outcome.
- **Evidence artifact:** Screenshot pair or logged UI-state dump saved under the slice verification/report folder.

### AC-2 — Safe deployment is available and modest

- **Setup:** Configure the mech into a safe-fit state.
- **Action:** Choose `Deploy Safe` and run the duel to completion.
- **Observable signal:** Result screen and event log.
- **Expected value:** Duel completes deterministically, sync/growth increases modestly, and no permanent harm is recorded.
- **Evidence artifact:** Deterministic event log plus result-state JSON or screenshot.

### AC-3 — Push deployment is available and meaningfully different

- **Setup:** Configure the mech into a pushed-fit state using at least one higher-demand edited part.
- **Action:** Choose `Push for Breakthrough` and run the duel to completion.
- **Observable signal:** Result screen, sync log, and breakthrough progress field.
- **Expected value:** The push path is visibly harder or riskier than safe, but offers larger sync/growth/breakthrough progress if the pilot survives/performs. It is not just a text reskin of safe.
- **Evidence artifact:** Deterministic event log plus result-state JSON or screenshot.

### AC-4 — Same inputs and seed reproduce the same duel

- **Setup:** Use a fixed build, fixed pilot, fixed deployment posture, fixed opponent, and fixed seed.
- **Action:** Run the duel twice, including at least one headless or script-only verification path if Godot supports it in the project.
- **Observable signal:** Event log bytes or normalized JSON events.
- **Expected value:** Event logs are identical.
- **Evidence artifact:** Two logs plus a diff/compare output showing no differences.

### AC-5 — Underperformance is legible and positive-valence

- **Setup:** Configure a deliberately stretched or over-demanding build.
- **Action:** Run a push deployment that produces a weak result or loss.
- **Observable signal:** Result copy and fit/sync explanation.
- **Expected value:** The result explains the outcome through demand/fit/sync and records slower growth or failed breakthrough progress, not permanent pilot harm.
- **Evidence artifact:** Result screenshot or state dump showing explanation and no permanent harm field.

## 7. Out of scope

- Full inventory, shop, economy, salvage, research, or crafting. Future KM-WORKSHOP / KM-HOME.
- Multiple pilots. Deferred.
- Full skill tree or pilot behaviour rules. Future/deferred KM-GATE and KM-DEF-BEHAVIOR.
- Real war map/front selection. Future KM-THEATRE / KM-WAR.
- Real-player opponents, backend, accounts, matchmaking, PvP verification server. Deferred KM-DEF-NET.
- Production art pipeline or final character art. The slice may use placeholder/approved local assets.
- Full mobile app packaging or Steam packaging. The slice only remains compatible with the product target.

## 8. Open questions

Non-blocking for draft:

1. Exact labels/names for the pilot, parts, and breakthrough trait.
2. Whether the first push path can lose, or only earn less progress. Recommendation: allow loss, but make the downside slower growth/no breakthrough, never harm.
3. Whether editable parts should be visual swaps in the first playable slice or stat/UI swaps only if the stack spike says visual swaps are expensive. Recommendation: visual if the stack spike succeeds; stat-only fallback if needed.

Blocking before `ready`:

1. KM-STACK-SPIKE should report whether Godot part swapping and headless determinism are viable enough for this implementation.
2. Decide the exact editable part set: minimum two slots, maximum three slots.
