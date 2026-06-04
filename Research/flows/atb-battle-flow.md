---
project: mech-bags
doc_type: flow-diagram
subject: atb-battle-playback
status: draft
updated: 2026-06-04
---

# ATB Battle Flow — Mech Bags Version 0.1

The ATB (Active Time Battle) system has two separate phases: **simulation** (deterministic event computation) and **playback** (animation driven by the event list). These must remain architecturally separable (ARC-001).

---

## Phase 1 — ATB Simulation (no rendering)

```mermaid
flowchart TD
    SIM_START([Simulator receives: playerBuild, enemyBuild, seed])
    SIM_START --> INIT_TIMERS[Initialise ATB timers\n for every attack item in both builds\n nextFire = speed value per item]

    INIT_TIMERS --> SIM_LOOP{Any side HP > 0?}
    SIM_LOOP -->|No| SIM_DONE

    SIM_LOOP -->|Yes| FIND_NEXT[Find item with minimum nextFire time\n across all attack items]
    FIND_NEXT --> ADVANCE_CLOCK[Advance simulation clock to that time]
    ADVANCE_CLOCK --> COMPUTE_HIT[Resolve hit/miss/effects\n using seed-based RNG]
    COMPUTE_HIT --> EMIT_EVENT[Emit event:\n time, attackerSide, bag, itemId, damage, effects]
    EMIT_EVENT --> APPLY_DAMAGE[Apply damage to target HP]
    APPLY_DAMAGE --> RESET_TIMER[Reset fired item timer:\n nextFire += speed]
    RESET_TIMER --> CHECK_HP{Target HP ≤ 0?}
    CHECK_HP -->|Yes| SIM_DONE
    CHECK_HP -->|No| SIM_LOOP

    SIM_DONE([Return: events list, winner, finalPlayerHP, finalEnemyHP])
```

**Determinism guarantee:**
- Same `playerBuild + enemyBuild + seed` → identical events list every run.
- No `Date.now()`, no `Math.random()` inside the simulator.
- Seed-based PRNG used for all stochastic effects (hit/miss, crit, etc.).

---

## Phase 2 — ATB Battle Viewer (animation playback)

```mermaid
flowchart TD
    VIEW_START([Viewer receives: events list from simulator])
    VIEW_START --> RENDER_INIT[Render initial state\n Player sprite left, Enemy sprite right\n HP bars at full, combat log empty]

    RENDER_INIT --> EVENT_LOOP{More events in list?}
    EVENT_LOOP -->|No| SHOW_FINAL[Show final HP state\n Show battle result screen]
    SHOW_FINAL --> VIEW_DONE([Viewer done])

    EVENT_LOOP -->|Yes| NEXT_EVENT[Pop next event from list]
    NEXT_EVENT --> ADVANCE_DISPLAY[Animate display time advancing\n to event.time\n e.g. visual ATB bar fill]

    ADVANCE_DISPLAY --> PAUSE_TIME[Pause display time]
    PAUSE_TIME --> SHOW_BANNER[Show event banner:\n bag source + item name\n e.g. 'Head Beam Rifle fires!']

    SHOW_BANNER --> PLAY_ANIM[Play weapon animation\n Anchored to attacking bag region\n Projectile or flash toward target]

    PLAY_ANIM --> ANIM_DONE{Animation complete?}
    ANIM_DONE -->|No| PLAY_ANIM
    ANIM_DONE -->|Yes| RESOLVE_EFFECTS[Apply effects:\n Update HP bars\n Show damage number\n Append event to combat log]

    RESOLVE_EFFECTS --> RESUME_TIME[Resume display time]
    RESUME_TIME --> EVENT_LOOP
```

**BEH-004 enforcement:**
- Only one `PLAY_ANIM` block runs at a time.
- Display time is paused during `PLAY_ANIM`.
- The next event is not dequeued until the current animation is fully resolved.

---

## Animation anchors by bag

Each attack animation originates from the attacking bag's region on the mech sprite:

| Bag | Animation origin |
|---|---|
| Head | Top / head/camera area |
| Torso | Centre / chest area |
| Back | Over-shoulder / backpack area |
| Left Arm | Left side of mech |
| Right Arm | Right side of mech |

Items can be in any bag. The animation origin follows the **bag**, not the item's real-world anatomy. A beam rifle placed in the Head bag fires from the head area. This is intentional and should be visually readable (ARC-005).

---

## Notes

- **Skip/speed controls** (if scoped in Slice 06): fast-forward collapses the `ADVANCE_DISPLAY` time. Skip-to-result uses the simulator's already-computed result without playing the viewer at all.
- The viewer must never call back into the simulator during playback. It reads from the frozen event list only.
