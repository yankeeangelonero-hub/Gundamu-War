# Handoff — the v0.1 build→fight loop, and the camera/movement gap to close next

This picks up after the v0.1 vertical slice landed: you can now build a backpack, deploy it, and
watch the fight it produces. The thing that needs the next pass is feel — the camera work and the
mech movement in a deployed fight read noticeably weaker than the combat reference we already had,
and closing that gap means going back to the Gundam-UC combat research and the old prototype rather
than inventing something new.

## Where the work stands

The whole loop is on `main` and pushed (commits `fc3f4e6` then `372a82a`). M1 is the build editor:
a 5×4 grid, the power-battery economy, PoE increased/more/flat support math, the mount cascade, and
the EXOFRAME-styled build screen, all under `godot_director_spike/scripts/build/` with headless
tests in `godot_director_spike/tests/`. M0 is the deterministic build→fight: `build_fight_sim.gd`
turns two builds plus a seed into the event log the proven viewer plays, a seeded ghost opponent
comes from `opponent_source.gd`, and `fight_handoff.gd` plus an injection branch in
`scripts/main.gd` make DEPLOY run the sim, play a human-scale intro, run the fight in the hybrid
director, and return to the restored bag. Each weapon now mounts on the fighting mech and fires its
own effect (beam, tracer burst, missile salvo, charged cannon) from its own hardpoint.

To see it: `godot --path godot_director_spike res://scenes/build_screen.tscn`, build something with
a reactor and a few weapons, and deploy. The reference to compare against is the standalone combat
the director was tuned on: `godot --path godot_director_spike -- --log=fight_log_everything
--director=hybrid`. Run both back to back — the difference between them is most of what this handoff
is about. The headless checks (`build_*_check.gd`, plus the existing `hybrid_check`/`director_check`)
all pass; run them with `godot --headless --path godot_director_spike -s res://tests/<name>.gd`.

## Why the deployed fight reads thinner than the reference

The honest diagnosis is that the camera and movement aren't worse code than before — the M0 sim is
feeding them far less to work with. The hand-authored logs like `fight_log_everything` contain
verticality, boosts, melee clashes, bursts, missiles, and a momentum-swing arc, and the hybrid
director's grammar was tuned against exactly that richness. A deployed M0 fight, by contrast, emits a
flat exchange: both mechs spawn, close once with a cosmetic `advance`, then trade weapon fire from a
fixed stand-off until someone dies or the sudden-death overload ends it. There is no verticality, no
burst-coast movement, no melee, and no dramatic arc. So the director has thin material to cut, and
the mechs mostly stand and shoot. Both the camera and the movement suffer from the same root cause:
the sim isn't emitting the beats the renderer already knows how to dramatize.

That matters because it changes what "fix the camera" and "fix the movement" mean. Before reworking
either system, the next person should watch a deployed fight beside `fight_log_everything` and
decide how much of the gap is simply the sparse log versus the systems themselves.

## The movement gap, and what the research already says

This is the better-understood half. There is a deep-research synthesis from 2026-06-13 at
`Research/Research Documents/research-synthesis-2026-06-13-gundam-uc-combat-feel.md` whose whole
purpose was diagnosing why the spike reads "MechWarrior" instead of "Gundam UC." Its conclusion was
that the read comes almost entirely from the movement model, and it lays out the fixes in leverage
order: add verticality (mechs fight in a 3D volume — boost up, dive, hover — instead of staying
locked to the ground), replace constant-velocity lerps with burst-coast-snap thrust motion
(accelerate hard, coast ballistically, change vector sharply at the next waypoint), and sell facing
changes through limb-driven AMBAC snaps rather than turret-style yaw. Below that come exchange
variety (closing melee, all-range homing swarms, dodge-pursuit runs) and a momentum-swing fight arc
instead of uniform attrition.

The key architectural point from that research is that all of it is deterministic event and waypoint
data on the existing log → director → garnish pipeline. The movement integrator that would express
it already exists in `scripts/mech_actor.gd` (the velocity/accel model, boost, the AMBAC arm-swing,
the saber/melee methods) and the director already dispatches `advance` with a `to_y`, `melee`,
`fire_burst`, and so on. What's missing is that `build_fight_sim.gd` never emits those — it only
emits a spawn, two cosmetic ground-level advances, and weapon fire. So the first move is almost
certainly to enrich what the sim emits (verticality and burst-coast waypoints, the occasional
closing melee, a pressure-then-reversal shape) rather than to rewrite the integrator. The mech
movement dials themselves (`max_speed`, `max_accel`, boost cadence) were always flagged as
placeholders tuned on block-out boxes, noted for retuning once the fight had real movement to show;
that retune is part of this work.

## The camera gap, and the nuance to be careful about

The same 2026-06-13 research argued the camera grammar was already on-target — that the hybrid
director's iso base, intercut hero shots, over-the-shoulder framing, bullet-time kill, and
fit-to-scale framing are exactly the "camera as a second actor, constant reframing, authored cut
rhythm" that reads as UC. Take that finding as true for the rich logs it was judged on, but do not
let it shut down the camera question, because the deployed fight genuinely looks worse and the owner
sees it. The likely reason is structural: the hybrid shot builder in `scripts/directors/hybrid.gd`
keys its intercuts off `fire_beam` events and a single lethal beat, so a short M0 fight — few beams,
maybe an overload ending, no melee — gives it almost nothing to schedule, and it falls back to long
stretches of the static iso base. The intro camera in `main.gd` (`_intro`) is also separate from the
director and only frames the player's mech.

So the camera work for this pass is less "redesign the grammar" and more "make the grammar hold up
when the fight is sparse, and make sure the sim hands it enough beats." Concretely that means: once
the sim emits movement and melee, confirm the hybrid grammar picks them up; consider teaching the
shot builder to treat any fire event (not just `fire_beam`) and the overload finish as cut-worthy
beats so an all-gatling or overload-ending fight still gets dramatized; and decide whether the intro
should hand off into the fight's first shot more deliberately. If after the sim is enriched the
camera still reads thin, that's the signal that the grammar itself needs new shot types for the
build-fight context, and the research's camera findings (F4–F6 in that doc) are the brief for it.

## The prototype as a reference

The old web prototype under `prototype/` is worth reopening for this, the way it was for the
per-weapon firing fix. Its core (`game-core.js`) models each weapon as an independent attacker with
its own cooldown and tags every combat event with the source node, and its renderer anchors and
highlights the firing weapon — that's the model we matched to make weapons fire individually. For the
movement and pacing work it's a thinner reference (it's a step-through DOM viewer, not a real-time 3D
fight), but its event model and the way it makes each action legible are the right mental model: the
sim should emit rich, source-tagged, deterministic events, and the renderer should dramatize them.
The lesson from the per-weapon fix applies again here — when something "isn't working" visually, the
first suspect is that the sim isn't emitting the event the renderer already handles.

## What the next person should do

Start by watching a deployed M0 fight next to `fight_log_everything --director=hybrid` and forming
your own view of how much of the gap is the sparse log. Then work the movement side first, because
the research is clearest there and the camera partly rides on it: enrich `build_fight_sim.gd` to emit
verticality and burst-coast `advance` waypoints, the occasional closing melee, and a pressure →
reversal → climax shape, keeping every addition deterministic data on the existing pipeline. Retune
the `mech_actor.gd` movement dials against the result. Then revisit the camera: confirm the hybrid
grammar dramatizes the new beats, broaden its cut triggers so sparse and overload-ending fights still
read, and only reach for new shot types if it still falls flat. Keep the combat-viewer reference
(`fight_log_everything` + `--director=hybrid`) as the bar, hold to determinism so PvP re-sim still
works, and keep the mecha identity original per the project's IP rules — the named units in the
research are evidence, not things to copy.

One smaller cleanup worth folding in while you're in here: the fighting mech still carries its
built-in default gun box from the block-out body, which no longer fires anything now that weapons
shoot from their mounts, so it can be suppressed for deployed fights.
