# Checkpoint — KM-DIRECTOR-SPIKE: iso-hybrid direction found + dynamic city + barrage (2026-06-13)

Checkpoint after an interactive feel-iteration session on the director spike. Builds on the
prior handoff (`handoff-2026-06-13-km-director-spike-executed-three-viewer-variants.md`, in the
owner's Downloads). That session left three viewer variants and an empty `VERDICT.md`. This
session iterated the camera feel hard, made the fight world dynamic (roaming mechs + destructible
city), added three more grammars, stress-tested at 10× gunfire, and — the headline — **the owner
landed on a production direction.** Nothing is committed (standing rule: no commits without
instruction). All work is on `backpack-system-test`, working tree dirty.

---

## 1. The headline: the direction

The owner's call, in their words: **"isometric with destructible environments as a base, with
cinematic shots intercutting."** This is now built and watchable as the `hybrid` variant. It is
the synthesis of the whole exploration: an orthographic tactical view is the legible backbone the
eye lives in, and the camera cuts to cinematic perspective shots on the big beats (opening
exchange, a mid-fight city-wrecking beam, the kill), then cuts back to iso. This is the strongest
answer the spike produced to the "watchable AND readable" question.

Engine question is de-facto answered: Godot 4.6.3 + GDScript did everything asked — orthographic
+ perspective switching mid-fight, deterministic log-driven staging, destructible city, DOF /
letterbox / volumetric fog, and held 60 fps under a 1,700-round barrage. Formal judging
(`VERDICT.md` checkboxes) has still not been convened, but the confirmation condition in the
stack ADR is met in practice.

---

## 2. What exists now — six director grammars

All selectable via `--director=<name>`; all share one fight log, one city, one garnish/audio
stack. Run from repo root: `godot --path godot_director_spike -- --director=<name>`.

| Variant | One-liner |
|---|---|
| `cinematic` (default) | base grammar: wide → over-shoulder → dolly/two-shot → killcam → wreck orbit |
| `witness` | embedded ground documentary; handheld; tracking kill-gaze slow-mo |
| `broadcast` | telephoto + mid/long drone plates + hard snap cut-ins + bullet-time kill |
| `blend` | Pacific Rim / Hathaway mix: drone-top → pedestrian ground + cockpit + drone plates + bullet-time |
| `iso` | **fixed orthographic tactical view**, frame-to-fit zoom, slow-mo kill zoom |
| `hybrid` | **THE DIRECTION**: iso base, cinematic perspective shots cut in on the beats |

Each variant has a headless contract suite (`tests/<name>_check.gd`). All six green at checkpoint
(`director_check` covers cinematic identity; `witness/broadcast/blend/iso/hybrid_check` the rest).
Run pattern: `godot --headless --path godot_director_spike --script res://tests/<name>_check.gd`.

---

## 3. What changed this session (all uncommitted)

**Camera feel** (`director.gd` + variants):
- Eliminated jerk: all variants route aim through `_apply_aim()` — eased look-at with an angular
  guard (swings > ~28° snap-cut instead of swinging; rotation rate-capped within a shot). Shake
  multipliers cut hard.
- DOF (shallow on close coverage, deep on plates), 2.39:1 letterbox bars, dutch/roll on cockpit /
  ground / killcam / bullet-time. Camera uses `CameraAttributesPractical` for the DOF.

**The world went dynamic:**
- Mechs roam in 2D: `mech_actor.walk_to(x, z, dur)` + `face_toward()`, eased yaw. The fight log
  carries `to_z` waypoints; `fight_log.json` rechoreographed so the duel uses the whole
  intersection.
- `city_builder.gd`: two-street grid (main `|z|<15`, cross `|x|<20`), a cleared plaza apron
  around the intersection (negative space to frame against), two hero gate-towers on the cross
  corners. Every building registers in group `kb_building` with an `aabb` meta.
- Beams detonate architecture: `garnish.gd` raycasts each `fire_beam` against `kb_building`; any
  crossed building erupts + collapses (debris chunks, dust ring, sink). Pure visual — the sim/log
  stays authoritative; same seed + same log ⇒ same buildings die.
- Garnish also gained: muzzle **charge-up** anticipation (pre-reads the log, glows 0.45s before
  each beam), **wreck smoke** through the aftermath.

**Occlusion — the important architectural decision:**
- Went through two approaches. First a reposition resolver (orbit-to-open-axis / crane / dolly).
  The owner saw the camera "bouncing off buildings" → **replaced with a see-through pass**: the
  lens flies its intended path STRAIGHT THROUGH buildings, and any building between lens and
  subject (or within 7 m of the lens) dissolves via alpha-hash dither, restoring when clear. Reads
  as a near-clip. `_resolve_occlusion()` now returns the pose unchanged and only fades materials;
  `iso`/`hybrid` use `_fade_for_iso()` to fade for both mechs in one pass. Destroyed buildings are
  exempt (keep their collapse).
  - Open knob: alpha-hash can look grainy in a freeze-frame. Smooth alpha-blend was rejected
    (boxes show interior walls). Revisit if the dither reads noisy in motion.

**Harness:**
- `main.gd` flags: `--director=`, `--still`, `--frames` (dumps a PNG every 1.5 game-sec to `tmp/`
  for shot review without ffmpeg), and `--log=<name>` (loads `data/<name>.json`).

**Barrage stress test:**
- `data/fight_log_barrage.json` — same choreography, both mechs fire_burst every 4 ticks (12–20
  rounds), occasional beams, one lethal at tick 230. **113 fire events (~12×), 1,700 rounds.**
- Ran clean on `blend` and `hybrid`: **p5 155 / avg 217 fps** windowed (RTX 5070 Ti laptop, 1080p,
  Forward+). No degradation vs the normal log. The log→director→garnish pipeline scales to dense
  combat.

---

## 4. Artifacts (local, gitignored `godot_director_spike/tmp/`)

- `hybrid_barrage.mp4` — delivered to owner. The direction (hybrid) on the barrage log, 45s, h.264.
- Per-variant contact sheets `sheet_*.png`, frame dumps `frame_*.png`.
- **MP4 pipeline** (ffmpeg is NOT on PATH): Godot `--write-movie out.avi` → the ffmpeg binary
  bundled inside the `imageio_ffmpeg` pip package
  (`...\Python312\Lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe`) →
  `-c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart`. Reusable for any variant+log.
- Owner instruction at checkpoint: **do not render more unless asked.**

---

## 5. Environment / gotchas

- Godot 4.6.3 on PATH as `godot`. Local docs mirror: `G:\My Drive\Vault_2_0\Knowledge\Tech\Godot`.
- ImageMagick (`magick`) is on PATH for montages; ffmpeg only via imageio_ffmpeg (see §4).
- One transient Vulkan device-lost crash (`VK_SUCCESS`/signal 11) during a frame capture; cleared
  on retry. Driver hiccup, not code. One transient shell cwd glitch fixed with explicit `cd`.
- `godot_spike/` is the separate GL-Compatibility deploy slice — still do not touch.

## 6. How to resume

1. The build call is made; next is making it real, not more prototyping. Convene the `VERDICT.md`
   judging on `hybrid` (owner + art + cold viewer), tick the boxes, close the stack ADR condition.
2. Route the outcome (per the design spec's Routing section / `vouse-routing-changes`): stack ADR
   from provisional→confirmed, supersede `docs/slices/KM-STACK-SPIKE-...`, fold the iso-hybrid +
   destructible-city + cinematic-intercut direction into the wishlist/work-map as the combat-viewer
   spec.
3. Optional polish before judging: the alpha-hash dither look (§3), and rendering the other
   variants of the barrage for the side-by-side.
4. Nothing is committed — decide what of the spike work graduates into the real build vs stays a
   reference prototype.

---

## 7. Session continuation (2026-06-13 pm) — Gundam-feel movement + melee

After the owner judged the build "more MechWarrior than Gundam," a deep-research pass
(`Research/Research Documents/research-synthesis-2026-06-13-gundam-uc-combat-feel.md`) on the
Torrington Base battle established the key finding: **the camera grammar was already Gundam-correct;
the feel gap was the movement model.** Implemented from there (all in `mech_actor.gd` unless noted):

- **Real velocity integrator** replaced per-segment position tweens. Each mech has `velocity`,
  steers toward `_target` with capped accel, and carries momentum across waypoints (banks through
  turns, can't stop on a dime). This is the movement core now.
- **Heavy feel = LOW ACCEL, not low top speed.** `max_speed≈48`, `max_accel≈24`. (Capping top speed
  tanked perf — slow mechs linger in dense building zones and the fade overdraw collapses FPS; see
  [[director-spike-deferred-tuning]].)
- **Grounded with occasional ground-boost.** Default is grounded walk/strafe; boost is ~20% of
  moves with a 3.2s cooldown — a low horizontal thruster skim (`to_y≈3`), not a vertical leap.
  Boost = a velocity impulse + flare. Verticality exists (`to_y` waypoints) but is used sparingly.
- **Limb-driven AMBAC turns** (arms swing to whip the torso), velocity-based bank/lean, footstep
  **ground-shake** (proximity-scaled: pedestrian shots rumble, iso stays calm) + **landing** dust.
- **Melee (Tier 2), fully deterministic.** New `melee` event kind in the log (loader + schema). The
  SIM decides the outcome (`hit/blocked/lethal/style/result`); the renderer only presents it — beam
  saber ignite + lunge + cleave swing + **swing trail**, defender **parry** (two blades lock).
  Clash physics: `result:"lock"` plants both (no sliding, strain into the press) or
  `"knockback"` shoves the loser back with real momentum. The kill is a saber **cleave** (hybrid's
  lethal detection was generalised to any kind, so the bullet-time cam wraps a melee kill).
- **Near-camera cull** (`director._cull_near`, group `kb_near_cull`): close-up shots hard-hide
  buildings/rubble/debris between lens and subject — without it, debris buried the blade.

**New director shot:** hybrid gained `melee_cut` (tight, slightly slow close-up on each clash).

**New fight logs** (all loaded via `--log=<name>`, deterministic): `fight_log_barrage` (12× gunfire
stress test), `fight_log_duel` (orbiting strafe firefight), `fight_log_ground` (heavy grounded
duel w/ boosts), `fight_log_air` (3D verticality test), `fight_log_melee` (melee in the full fight),
`fight_log_saber` (clean open-plaza saber duel — the readable melee showcase).

**Determinism check (the owner asked): NOT drifted.** The fight log is still the authority; mech
movement (velocity integrator, frame-dependent `delta`) is presentation only and never decides an
outcome. Melee connects because the event says so, not via collision on rendered positions.

**Deferred (owner: "sharpen later"):** building-fade perf cliff + movement/melee feel tuning vs real
3D models (see [[director-spike-deferred-tuning]]); the chaotic full-fight melee still has the
explosion-wash/debris issues that the clean `fight_log_saber` avoids. **Remaining research Tier 2:**
all-range homing swarms and a dodge-pursuit weave. Still uncommitted.
