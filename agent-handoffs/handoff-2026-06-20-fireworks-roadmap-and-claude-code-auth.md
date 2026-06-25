# Handoff — Fireworks Roadmap Pivot + Claude Code Auth Blocker

Date: 2026-06-20
Branch: `combat-feel-restart`
Repo: `D:/Claude/Mech Bags`

## 1. User Decision

Xuanyue reframed the first playable target.

The immediate playable is **not** a balanced gauntlet/shop/run loop. It is a **First Cinematic Combat Sandbox / Fireworks Build**:

```text
choose / assemble two mech weapon combinations
→ press Fight
→ deterministic fight log is generated
→ choreographer stages it
→ hybrid director films it
→ the result reads as a Gundam fight
```

Doctrine:

```text
Fireworks first. Balance later.
```

Balance, hearts, shop economy, recipes, long-term progression, pilot-fit/sync, and PvP fairness are deferred until the generated fights prove they can deliver spectacle worth building around.

## 2. Taste / Product Direction

The target is explicitly **Gundam fight readability**, not a generic effects reel.

The generated fights should make matchup shape and archetype readable:

- rifle/missile pressure: oppressive, spatial, frequent ranged pressure;
- buster artillery: slower, heavier, dangerous when it commits;
- saber/booster aggression: predatory, close-range, evasive;
- shield/tank attrition: defensive, hard to finish, slower pressure;
- mixed arsenal duel: pitched battle, escalation, reversals.

Different match shapes are valid and should render differently:

- one-sided stomp;
- difficult pitched battle;
- comeback;
- attrition;
- artillery execution;
- melee chase;
- ranged pressure;
- mixed arsenal duel.

The exact fight structure can be tuned later. The tracking system must support these distinctions now.

## 3. Baseline Judgment

`godot_director_spike/data/fight_log_everything.json` is the authored fireworks baseline.

Measured profile:

```text
Duration: 23.1s
Total events: 101
Attack events: 50
Advance events: 48
Boost advances: 10
Weapon mix:
- 17 beam
- 19 burst
- 8 missiles
- 6 buster
Actors:
- A fires 25 times
- B fires 25 times
Longest attack gap: 0.8s
Average attack gap: 0.44s
Lethal: A fire_buster at 22.8s
Destroyed: B at 23.1s
```

Verdict:

- Good fireworks / spectacle-density benchmark.
- Good proof the viewer and hybrid director can carry dense anime combat.
- Not a final iconic Gundam duel benchmark.
- Too metronomic, too symmetric, weak on defensive/reversal beats, no melee, fake/repeated HP values.

Use it as the minimum fireworks floor, not as the final mold.

## 4. Canonical Pipeline

Correct order:

```text
build / weapon combination
→ deterministic build-vs-build sim
→ combat-truth event log
→ choreographer
→ staged fight log
→ hybrid director grammar
→ Godot rendering/frontend
```

Ownership rule:

```text
Truth decides what happened.
Choreographer decides where it happened.
Director decides how to see it.
Renderer makes it visible.
```

Do not let the director infer staging. Do not let the choreographer change combat truth.

## 5. Files Created / Changed By Ada

### Created

`docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md`

Purpose: focused slice spec for the new first-playable target.

Key contents:

- Fireworks-first decision.
- Gundam fight readability north star.
- `fight_log_everything.json` as baseline.
- Pipeline and ownership split.
- Fight Log Tracking / Spectacle Profile requirements.
- Required archetype set.
- Acceptance criteria.
- Immediate implementation order.
- Deferred systems.
- Known choreographer blocker.

### Created

`agent-handoffs/brief-2026-06-20-opus-fireworks-roadmap.md`

Purpose: original Claude Code Opus dispatch brief. Includes Xuanyue's added direction about fight-log tracking, Gundam target, stomps vs pitched battles, and archetype-specific rendering.

### Created

`agent-handoffs/handoff-2026-06-20-fireworks-roadmap-and-claude-code-auth.md`

Purpose: this handoff.

## 6. Claude Code Dispatch Attempt / Blocker

User asked to dispatch the brief to Opus Claude Code and check its work.

Claude Code binary exists:

```text
/c/Users/Yanjie/.local/bin/claude
2.1.183 (Claude Code)
```

But Hermes shell cannot authenticate Claude Code.

Smoke tests:

```bash
claude -p --model opus --output-format json 'Reply exactly: CLAUDE_READY'
```

Result: hung until timeout.

Bare mode:

```bash
claude --bare -p --model opus --output-format json 'Reply exactly: CLAUDE_READY'
```

Result:

```json
"result": "Not logged in · Please run /login"
```

Auth-related environment variables visible to this shell: none.

Conclusion: Claude Code is installed but not usable from the Hermes Git Bash/MSYS terminal until login/API auth is available in that environment.

User asked whether Ada could run `claude /login`. Response: Ada cannot safely complete the credential-bearing interactive login flow; Xuanyue needs to run it manually in a normal terminal if Claude Code dispatch is needed.

## 7. Known Choreographer Bug To Fix Before Landing

Ada reviewed `agent-handoffs/handoff-2026-06-20-combat-choreographer-pure-staging.md` and verified the claimed test command:

```bash
cd '/d/Claude/Mech Bags/godot_director_spike'
godot --headless --path . --script res://tests/choreographer_check.gd
```

Result was 39 PASS / `---- ALL PASS`.

But Ada found an untested same-tick precedence bug:

- If a reactive evade/stagger starts on the same tick as an ambient stride, both `advance` events are emitted.
- `_eval_layered()` / `_active_advance()` and director event order can pick ambient rather than higher-priority reactive.
- The current tests avoid stride-boundary reactive windows, so the green suite misses this.

Required before landing choreographer:

1. Add a regression fixture with reactive beat on stride boundary.
2. Ensure same actor/same tick emits one unambiguous winning beat, or active lookup honors priority.
3. Rerun `choreographer_check.gd`.

## 8. Fight Log Tracking Requirements

Every authored or generated candidate fight needs a spectacle profile, not just raw JSON.

Track:

- log id;
- authored/generated;
- seed;
- build archetype A;
- build archetype B;
- matchup shape: stomp, pitched battle, comeback, attrition, artillery execution, melee chase, ranged pressure, mixed arsenal duel;
- fight duration;
- event count and attack density;
- longest dead-air gap;
- weapon mix;
- heavy-beat count;
- defensive/reversal beats: block, evade, miss, stagger recovery, shield catch, interrupted charge;
- movement profile: advance count, boost count, stagger count, range-state changes;
- director beat availability: opening hero beat, mid escalation, melee cut, bullet-time/finisher, aftermath hold;
- finisher quality;
- human taste verdict.

Minimum comparison report:

```text
baseline: fight_log_everything.json
candidate: <generated-log-id>
result: passes/fails fireworks floor
notes: what reads differently and whether that difference matches the archetypes
```

## 9. Immediate Implementation Order

1. Fix choreographer same-tick precedence bug.
2. Build fight-log spectacle profiler for `fight_log_everything.json`.
3. Add generated-log comparison report.
4. Build minimal deterministic weapon-combination build-vs-build sim.
5. Wire sim → choreographer → hybrid director, using a temporary v2-to-v1 adapter if faster than full director migration.
6. Add crude build picker / fight launcher UI.
7. Generate and judge at least three archetype fights:
   - Rifle + Missiles vs Mixed Arsenal;
   - Buster + Shield vs Rifle Pressure;
   - Saber + Booster vs Artillery.
8. Only after the fireworks sandbox works: return to gauntlet/shop/balance.

## 10. Verification Still Needed

Because Claude Code failed auth and Ada was interrupted while writing docs, the next operator should verify:

```bash
cd '/d/Claude/Mech Bags'
python -m json.tool roadmap.json >/tmp/roadmap.validated.json
git diff -- Roadmap.md roadmap.json Kanban.md docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md agent-handoffs/brief-2026-06-20-opus-fireworks-roadmap.md
```

Roadmap integration is not complete until `Roadmap.md`, `roadmap.json`, and `Kanban.md` are updated to reference `CF-FIREWORKS` as the immediate first playable route.

Current completed artifact is the slice spec; roadmap files still need final sync.
