# Claude Code Brief — Reframe Roadmap Toward Fireworks/Cinematic Combat Sandbox

You are Claude Code Opus working in `D:/Claude/Mech Bags` on branch `combat-feel-restart`.

## User Direction

Xuanyue likes the new direction: first playable should mean a **cinematic combat sandbox**, not a balanced gauntlet. The goal is: build combinations of mechs/weapons and have them fight; the cinematic hybrid camera should deliver anime/Gundam fireworks. Balance, shop economy, hearts, run structure, and long-term gauntlet progression come later.

Ada's current taste/strategy call:

- `fight_log_everything.json` is a useful **fireworks baseline**: 23.1s, 101 events, 50 attacks, 48 advances, 10 boosts, full arsenal, lethal buster finish.
- It is not a perfect iconic Gundam duel: too metronomic, too symmetric, weak reversal/defensive beats, no melee, fake repeated HP values.
- Use it as a parity benchmark for spectacle density and director usability, then make generated fights exceed it structurally.

Canonical pipeline:

```text
build / weapon combination
→ deterministic build-vs-build sim
→ combat-truth event log
→ choreographer
→ staged fight log
→ hybrid director grammar
→ Godot rendering/frontend
```

Rule:

```text
Truth decides what happened.
Choreographer decides where it happened.
Director decides how to see it.
Renderer makes it visible.
```

## Objective

Update the project roadmap/docs so the immediate v0.1 route targets a **First Cinematic Combat Sandbox / Fireworks Build** before the balanced gauntlet.

This is not just wording. Reorder the roadmap so the next build path is:

1. Fix/land choreographer.
2. Build a `fight_log_everything.json` comparative profiler / spectacle report.
3. Build minimal deterministic weapon-combination build-vs-build sim.
4. Wire sim → choreographer → hybrid director, with a temporary v2→v1 adapter if that is the shortest path.
5. Add a crude build picker / fight launcher UI.
6. Generate at least three different build-vs-build fights that are deterministic, visibly different, and compare against the fireworks baseline.
7. Defer balanced gauntlet/shop/hearts/progression until after the fireworks sandbox proves the fights slap.

## Required File Targets

Edit only documentation/roadmap files unless you find a tiny schema consistency edit is unavoidable. Preferred targets:

- `Roadmap.md`
- `roadmap.json`
- `Kanban.md`

Optional if useful:

- create a focused slice spec under `docs/slices/` or `docs/superpowers/specs/`, e.g. `docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md`.

Do **not** edit unrelated untracked prototype/history files. Do **not** commit. Do **not** run `git add`.

## Additional User Direction To Incorporate

Xuanyue added: update how fight logs are tracked. Be explicit that the target is a **Gundam fight**, not a generic effects reel. The exact structure can be tuned later, but the tracking must support different archetype outcomes:

- one-sided stomps should render differently from difficult pitched battles;
- rifle/missile pressure, buster artillery, saber/booster aggression, shield/tank attrition, and mixed arsenal duels should each produce distinct logs and distinct camera/staging reads;
- fight-log tracking should record the intended archetype / matchup shape and spectacle profile, not only raw event counts;
- generated logs should be compared against `fight_log_everything.json` for fireworks baseline, but not forced to mimic its metronomic structure.

Add this doctrine cleanly wherever the roadmap/log-tracking notes belong:

```text
Target: Gundam fight readability. Different archetypes and match shapes must render differently: stomp, pitched duel, ranged pressure, melee chase, artillery finish, shield attrition.
```

If you create a slice spec, include a section for **Fight Log Tracking / Spectacle Profile** with fields such as:

- log id / seed / generated or authored;
- build archetypes for A and B;
- matchup shape: stomp / pitched battle / comeback / attrition / artillery execution / melee chase;
- fight duration, event density, dead-air gaps;
- weapon mix and heavy-beat count;
- defensive/reversal beats;
- movement/boost/stagger profile;
- director beat availability;
- aftermath/finisher quality;
- human taste verdict.

## Required Content Changes

### Roadmap.md

Reframe the v0.1 immediate goal from “backpack engineering gauntlet first” to:

- **First Cinematic Combat Sandbox / Fireworks Build** first.
- Player can assemble/choose weapon combinations for two mechs, press fight, and watch deterministic anime combat through the hybrid director.
- Balance and gauntlet loop are explicitly later.

Add/adjust milestones/slices:

- `CF-FIREWORKS` or equivalent: baseline profiler + generated fight parity against `fight_log_everything.json`.
- `M0-SANDBOX-SIM` or equivalent: minimal deterministic weapon-combination sim for build-vs-build fights.
- `BUILD-PICKER` or equivalent: crude UI to choose/build loadouts and launch fights.
- Gauntlet/shop/hearts should move later/deferred behind sandbox proof.

Include acceptance criteria for fireworks build:

- Same builds + seed reproduce identical event log.
- Generated fight has no dead-air failure compared to baseline.
- Generated fight offers director-usable beats: first hero/opening beat, mid escalation, heavy/finisher, aftermath.
- At least three build archetypes produce visibly different spectacle profiles: e.g. rifle+missiles, buster+shield, saber+booster.
- Comparison report exists against `fight_log_everything.json`.

### roadmap.json

Update node ordering/states/goals to match the new immediate route. Add nodes if needed. Keep valid JSON.

Current relevant nodes include:

- `cf-viewer` shipped
- `cf-feel-core` shipped
- `m1-grid-editor` ready
- `cf-choreographer` ready but implementation exists uncommitted and has a known same-tick precedence bug Ada found
- `m0-sim` blocked
- `cf-feel-consumers` blocked
- `m3-gauntlet` blocked

Need new/updated nodes reflecting:

- Fireworks parity/profiler slice.
- Minimal cinematic sandbox sim.
- Build picker/fight launcher.
- Gauntlet becomes later than sandbox.

### Kanban.md

Update In Progress / Backlog to reflect current priority:

1. choreographer bug/finalize
2. fireworks baseline profiler/parity report
3. deterministic weapon-combination sim
4. v2→director adapter/cutover
5. crude build picker/launcher
6. defer shop/gauntlet balance

## Known Bug To Mention, Not Necessarily Fix

Ada found a choreographer same-tick precedence bug:

- If reactive evade/stagger starts on the same tick as ambient stride, both `advance` events are emitted.
- `_eval_layered()` / `_active_advance()` and director event order may pick ambient rather than higher-priority reactive.
- Tests avoid stride-boundary reactive windows, so current 39 PASS misses it.
- Roadmap should require fixing this before landing choreographer.

Do not fix code unless the roadmap/doc update naturally requires a tiny note. Your task is roadmap/docs first.

## Voice / Style

Use concise product-roadmap language. Do not bury the decision in vague prose. State the pivot cleanly:

```text
Fireworks first. Balance later.
```

Avoid overpromising “Gundam-perfect”; say “UC-legible / anime combat / cinematic fireworks” as a build target.

## Verification Required

Before final response:

1. Run a JSON validation on `roadmap.json`.
2. Show `git diff -- Roadmap.md roadmap.json Kanban.md docs/slices/...`.
3. Summarize changed files and exact next implementation order.

Final response must include:

- changed files
- validation command/result
- any blockers or docs you intentionally left untouched
- no commit claim
