# Sonnet Task — Mech Bags V0.2 real-time theatre loop revision

You are Claude Code Sonnet running inside `D:/Claude/Mech Bags`.

Xuanyue reviewed the current V0.2 implementation and corrected the loop:

> The war theatre should not be instant. Every fight should take between 15–30 seconds and not resolve instantly. The fight should keep looping within the battlefront until the player retreats. Losing gives penalties that prevent the suit from fighting until elapsed (for starters 15 second delay). Victory resupply is faster (5 seconds) between fights. What is lacking is loot drop and pilot level up and skills acquisition.

## Ground rules

- This is a focused iteration on the current V0.2 prototype, not a redesign.
- Preserve V0.1 placement/mobile/editing behavior.
- Preserve unrestricted body-part placement: Beam Rifle in Head remains valid when geometry/rotation permits.
- Do not commit, push, or run destructive git commands.
- Do not add backend, accounts, real async PVP, full warfront map, gear surface, multiple pilots, deep skill tree, live LLM narration, or production art.
- Keep static no-build browser prototype.

## Required reading before editing

Read:
- `Project Version/Version 0.2/Version 0_2 Project Specifications.md`
- `Research/Research Documents/concept-handoff-2026-06-05-real-time-theatre-loop.md`
- `Research/User Journeys.md` Journey 12 and Journey 13
- `agent-handoffs/sonnet-v0-2-essential-sortie-loop-implementation-report.md`
- `agent-handoffs/hermes-v0-2-essential-sortie-loop-verification-note.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- `prototype/tests/core-tests.js`

## Current known issue

The current implementation resolves all 10 fights instantly and then lets Retreat claim the completed batch. That is now wrong. The theatre should be an ongoing timed loop until retreat.

## Required behavior

Implement this loop:

1. Player customizes mech in workshop.
2. Player clicks Deploy.
3. Suit enters active theatre state.
4. Theatre repeatedly schedules fights against the fixed pool of 10 enemy mechs.
5. Each fight takes 15–30 seconds in normal runtime.
6. For developer/test convenience, you may add a deterministic time-scale/test helper, but user-visible runtime should not be instant.
7. After a **victory**, the suit enters **5 seconds resupply** before next fight.
8. After a **loss**, the suit enters **15 seconds delay/repair lockout** before next fight.
9. During downtime, the suit cannot fight.
10. Loop continues automatically until the player retreats.
11. Spectate is optional: player can watch current fight/state or leave spectate without stopping theatre progress.
12. Retreat ends the active sortie and claims accumulated results so far.
13. Retreat summary must show:
    - fights completed,
    - wins/losses,
    - loot drops,
    - pilot XP and level progress,
    - pilot condition,
    - skill acquisition/progress.
14. Player can return to workshop, modify mech, and redeploy.

## Loot requirements

The current loot feedback is too thin. Add simple but concrete loot:

- It may be salvage currency plus named parts/fragments, or one/two simple item drops if that is safer.
- Loot should be deterministic from sortie facts.
- Loot should visibly suggest why the player might modify the mech before redeploying.
- Avoid deep loot economy.

## Pilot XP / level / skill requirements

The pilot layer must visibly progress.

Minimum acceptable:
- one pilot;
- level and XP bar/readout;
- XP gained from sortie participation plus performance/survival;
- level-up callout if threshold crossed;
- one or two skills with progress/acquisition;
- report copy separates battle outcome, condition, XP/level, and skill progress.

Keep skills small and deterministic. Avoid generic overpowering +10% damage if possible. Good examples:
- Saber Duel Sense progress from melee/saber involvement;
- Missile Pattern Reader progress from missile-heavy encounters;
- Emergency Egress progress/safety note after losses but survival.

## Tests and timing

Update/add tests for:
- theatre scheduler does not resolve all fights instantly;
- victory downtime = 5 seconds;
- loss downtime = 15 seconds;
- loop continues until retreat;
- retreat claims accumulated results only;
- loot is deterministic;
- XP/level/skills are deterministic and visible in state;
- existing core placement/sim tests still pass.

If tests cannot wait 15–30 real seconds, implement pure functions or a scheduler tick abstraction so tests can advance virtual time deterministically while the UI uses real seconds.

## Browser smoke required

Run a browser/manual smoke if possible:
- deploy;
- observe active fight countdown/state;
- observe win resupply or loss repair delay;
- leave spectate and confirm theatre continues;
- retreat after at least one completed fight;
- confirm loot + XP/skill summary;
- return to workshop and redeploy.

Capture screenshots under:

`agent-handoffs/v0-2-real-time-theatre-loop-screenshots/`

## Verification required

Run:

```bash
node prototype/tests/core-tests.js
```

## Report required

Write:

`agent-handoffs/sonnet-v0-2-real-time-theatre-loop-report.md`

Report must include:
1. Files changed.
2. What changed from instant batch to timed theatre loop.
3. Timing behavior implemented.
4. Loot behavior implemented.
5. Pilot XP/level/skills behavior implemented.
6. Verification results.
7. Browser smoke results and screenshot list.
8. Remaining risks / recommended next pass.
