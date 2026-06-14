# Checkpoint — KM-DIRECTOR-SPIKE: rigged Mixamo mech + rifle combat (2026-06-13, evening)

Checkpoint after an interactive feel-iteration session on the director spike, continuing from
`handoff-2026-06-13-km-director-iso-hybrid-direction-and-barrage.md`. That session landed the
`hybrid` production direction and the cel-shaded UC-Gundam daytime look. **This session dropped a
real rigged humanoid mesh into the fight** (Mixamo Y-bot stand-in), strapped a box rifle to its
hand, wired the firing pipeline to it, and tuned the duel choreography so the two mechs stay
engaged and trained on each other.

Engine is confirmed (owner: "godot is really good enough and entertaining enough" → recorded in
`godot_director_spike/VERDICT.md`). Standing rule still in force: **nothing is committed.** All work
is on `backpack-system-test`, working tree dirty (last commit `8ab62d1`). The owner paused for the
night without asking to commit — so this is uncommitted-on-purpose.

---

## 1. The headline: rigged mechs are in and fighting

`--mesh` now swaps the grey-box block-out mechs for a **cel-shaded rigged Mixamo Y-bot** holding a
rectangular box rifle, with real skeletal locomotion (idle/firing stance, walk, run, strafe L/R),
a plant-and-fire firing animation, and beams that leave down the barrel. Both mechs hold duel range
and strafe each other. This is a stand-in: the owner's plan is to drop their **own** mech mesh onto
this same Mixamo skeleton later ("strap on weapons, not armour") — so the rig pipeline, not the
Y-bot, is the deliverable.

Run it (from repo root, Windows; Godot 4.6.3):

```
godot --path "D:/claude/Gundamu-War/godot_director_spike" -- --mesh --cel --director=hybrid --log=fight_log_everything
```

(The Godot exe in this environment:
`C:/Users/Yanjie/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.3-stable_win64_console.exe`.
Use the absolute `--path` — a relative `godot_director_spike` path intermittently failed to resolve
when launched from the background shell.)

---

## 2. What was built this session (all in `mech_actor.gd` unless noted)

**Rigged pipeline (`_build_rigged`, `_drive_rig`, `_attach_rifle`):**
- Loads `res://models/run_rifle.fbx` (base, scale `RIG_SCALE = 11`), finds the `Skeleton3D` +
  `AnimationPlayer`, installs clips from the other FBXs via `_add_clip` (reads the `mixamo_com`
  take from each file).
- Clips: `run`, `walk`, `strafe_l`, `strafe_r`, `stand` (looping firing-rifle pose), `fire`
  (one-shot firing stance). `_prep_loco` loops + strips the Hips position track (the velocity
  integrator owns translation); `_prep_oneshot` does the same but `LOOP_NONE` for `fire`.
- **Default stand pose is the firing-rifle stance** (`stand`, a looped second copy of
  `firing_rifle.fbx`), not the relaxed rifle-idle — owner's explicit call. `rifle_idle.fbx` is
  still imported but unused (easy to flip back).
- `_drive_rig` clip selection: **strafe** (lateral-dominant, `spd>5`) → **run** (`spd>14`) →
  **walk** (`spd>2`) → **stand**. Backward movement while facing the enemy plays walk/run with a
  **negative `speed_scale`** so a retreat reads as a backpedal, not a moonwalk.
- Strafe left/right was direction-corrected: front is local +Z, so local +X is the mech's LEFT →
  `+lat` plays `strafe_l`. The strafe clips are the rifle-holding "Strafe Left/Right Rifle" variants.

**Rifle + firing (`_attach_rifle`, `fire_weapon`, `muzzle_forward`; `garnish.gd`):**
- Box rifle on a `BoneAttachment3D("mixamorig_RightHand")` → `holder` (Node3D, `rotation_degrees
  (-90,0,0)`) → rifle mesh + `muzzle` node at local `+Z 0.78` (barrel tip). The holder carries the
  facing rotation so the rifle reads forward and the muzzle sits at the barrel tip.
- **Rifle is rigidly mounted** and rides with the body. We tried per-frame independent rifle aim
  (`look_at` with `use_model_front=true`, slerped) but the owner rejected it: the gun aimed but
  detached from the arm. Final call: **aim the whole body, keep the rifle rigid.** (That aim code
  was removed — don't re-add it.)
- `fire_weapon()` (rigged): plays the one-shot `fire` clip and holds it up to 0.8s via `_fire_t`,
  which makes `_drive_rig` yield the body (plant-and-fire). `garnish._on_event` calls it for any
  `fire*` event kind.
- `muzzle_forward()` returns the muzzle's world `+Z` (the barrel axis). `garnish._barrel_aim()`
  re-points beams/buster/burst-tracers down that axis at the original muzzle→target distance, so
  shots leave the gun where it's pointed (hits still reach the enemy, misses still overshoot).

**Duel choreography:**
- `director.gd` — `_engage(raw, enemy)`: every `advance` target is reprojected to within
  `ENGAGE_MIN 34`..`ENGAGE_MAX 80` units of the enemy at the same bearing, so a log position that
  used to walk a mech off into the distance now lands on the ring → the move sweeps *around* the
  enemy (a strafe) instead of fleeing. Pure function of (log target, enemy pos) → deterministic.
- `mech_actor.gd` — body facing lerp raised `6→11`/sec (`12→16` dashing) so a mech orbiting
  quickly keeps its front (and rifle) on the enemy instead of lagging and looking away.

**Guards:** all box-visual methods (`recoil/flinch/block_pose/parry/ignite_saber/retract_saber/
melee_strike/muzzle_pos`) early-return in rigged mode (`if rigged: return` or null-guards) so the
rig path never touches the absent block-out nodes.

---

## 3. Assets added (uncommitted, untracked)

- `godot_director_spike/models/`: `run_rifle.fbx`, `walk.fbx`, `strafe_left.fbx`, `strafe_right.fbx`,
  `firing_rifle.fbx`, `rifle_idle.fbx` (+ `.import`). Sources live in `Research/Animations/` (Mixamo
  exports). md5-verified that `strafe_left/right` are the rifle-holding variants.
- `godot_director_spike/inspect_fbx.gd` — throwaway skeleton/anim dumper (run via `--script`).
- Also untracked from prior session: `art_config.gd`, the `cel*.gdshader` family, `pause_controller.gd`,
  `Research/Mood Images/`, various `.uid` files, and `tmp_*.txt` scratch files (the `tmp_*.txt` are
  junk, safe to delete).

---

## 4. Fight logs — weapon/projectile density

`--log=<stem>` maps to `res://data/<stem>.json` (note: the full stem, e.g. `fight_log_everything`,
NOT `everything`). Density survey (fires = all `fire*` kinds):

| log | events | fires | mix |
|---|---|---|---|
| `fight_log` (default) | 19 | 9 | sparse: 5 beam, 4 burst, 7 advance |
| `fight_log_everything` | 101 | 50 | **all four weapons**: 17 beam, 29 burst, 2 missiles, 2 buster, 48 advance |
| `fight_log_guns` | 113 | 56 | densest pure-gun: 21 beam, 35 burst, 54 advance |
| `fight_log_barrage` | 123 | 113 | wall-to-wall burst, but only 7 advance (near-stationary) |

Owner asked for "more weapons and projectiles" → currently launching with `fight_log_everything`
(variety + movement). **This is a launch flag, not a default** — `--mesh` with no `--log` still
loads the sparse `fight_log.json`. If the owner wants density to be the default, point the `--log`
default in `main.gd` (~line 329) at a richer log, or branch it on `rig`.

---

## 5. Open threads / where it stands

- **Last thing on screen:** the `fight_log_everything` run with the faster facing + engagement ring.
  Owner had not yet reacted to whether "one mech looking away" is fully fixed by the `6→11` facing
  bump — **verify that first next session.** If a mech still looks away, the next suspects are (a)
  the engagement ring letting the enemy cross behind during a fast orbit, or (b) a stale
  `face_toward` from a fire event; consider snapping facing on fire events for the defender too.
- **Plant-and-fire feel:** the 0.8s `_fire_t` hold freezes the legs while the body slides during
  rapid fire. Acceptable for now; if it reads as gliding, the proper fix is an upper-body-only
  blend (AnimationTree with a bone filter / `SkeletonModifier3D`) so legs keep strafing while the
  torso fires — deferred, owner hasn't asked.
- **Real mesh drop-in:** the whole point. When the owner brings their mech mesh, it should retarget
  onto this same Mixamo skeleton (same bone names = zero retargeting) and `_attach_rifle` /
  `_strap_armor` mount points reused. `_strap_armor()` still exists but is NOT called (bare Y-bot).
- **Missile launchers / buster as separate rectangles:** owner mentioned wanting these as bolt-on
  weapon boxes (beyond the single rifle); not built yet.
- **Deferred (from memory):** building-fade perf cliff; add camera-occlusion checks to unit tests
  when changing shots; beam-FX cel styling refinement; real-model feel tuning.

---

## 6. Constraints (unchanged, do not violate)

No backend/DB/network in the near-term prototype. No real Gundam IP/names/lore (original identity:
mono-eye / single visor band; no V-fin, twin-eye, or RX-78 trim). No permanent pilot harm. No C# /
no 3D-stack change. **Do not commit/push/install without explicit instruction.** Commit co-author
line when eventually told to commit:
`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
