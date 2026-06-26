# 3D Modeling and Rigging Artist Handoff Package - Exploration Draft

Date: 2026-06-26
Status: Exploration draft, not yet roadmap-grafted
Owner: Xuanyue
Project: Kitbash Mecha

## 0. Purpose

This document plans the handoff package we should give external or internal artists so they can
model and rig original 3D skeletal mechs and equipment for Kitbash Mecha.

The package is not just an art brief. It must define an importable Godot 4.6 asset contract:
canonical skeleton, sockets, hardpoints, animations, materials, scale, folder layout, metadata,
and validation gates. The goal is that an artist can deliver a mech frame and equipment set that
drops into the existing director/combat viewer without changing combat truth, deterministic sim
logic, or backpack-grid gameplay rules.

## 1. Upstream Context

Read these before turning this draft into an approved handoff:

- `docs/wishlist/wishlist.md`
- `docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md`
- `docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`
- `docs/pilot-and-war-front-high-level-spec-and-work-map.md`
- `docs/adrs/2026-06-06-build-stack-decision.md`
- `Research/Research Documents/research-synthesis-2026-06-13-gundam-uc-combat-feel.md`
- `Research/Research Documents/research-synthesis-2026-06-15-weighty-mecha-multi-title-and-cockpit.md`
- `Research/Research Documents/research-synthesis-2026-06-16-director-grammar-lighting-color-lens-continuity.md`
- `agent-handoffs/handoff-2026-06-14-km-mech-minimum-animation-set.md`
- `agent-handoffs/handoff-2026-06-13-km-rigged-mech-rifle-combat.md`

Current repo facts that matter:

- The current combat viewer is 3D Godot and the locked direction is hybrid: isometric tactical
  backbone with cinematic intercuts.
- v0.1 uses one unified backpack grid. The 3D mech visualizes the grid build and does not impose
  gameplay constraints of its own.
- The current rigged prototype uses Mixamo FBX clips on a Y-bot stand-in, with a box rifle attached
  to the right hand. That proves the pipeline shape, not the final art.
- The current code treats animation as presentation only. Sim outcomes come from the event log.
- The current art payload is a 2D manifest with hardpoints and FX. It is useful precedent for the
  3D metadata contract, not the shipping 3D format.

Official Godot 4.6 docs used for import assumptions:

- Godot recommends glTF 2.0 for complex 3D scenes and supports `.glb`, `.gltf`, `.blend`, and FBX.
  See: https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- Godot's oriented 3D asset convention is asset front on `+Z`, with Y up; Blender asset front is
  `-Y` before export. See: https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html
- Godot supports BoneMap-based retargeting, but the production contract should still reduce
  retargeting by using one project skeleton template. See:
  https://docs.godotengine.org/en/4.6/classes/class_bonemap.html

## 2. Non-Negotiables

1. Original IP only.

   No licensed names, lore, exact silhouettes, V-fin antenna, split twin-eye visor, RX-style trim,
   or recognizably copied mobile-suit designs. The original visual identity should use a mono-eye,
   single visor band, full-face sensor plate, or another clean original face language.

2. The mesh is a visualizer, not a second rules layer.

   Grid items, power economy, supports, and sim events decide gameplay. Mesh hardpoints affect where
   things appear, not what the sim allows or how much damage a weapon does.

3. One canonical skeleton family.

   Artists should work from a project-owned `KM_MechSkeleton_v1` template. They should not invent a
   custom skeleton per mech unless a later technical review explicitly approves it.

4. Skeleton and socket names are API.

   Names are not cosmetic. Godot scripts and metadata will use them to mount weapons, spawn muzzle
   flashes, aim beams, play clips, and test imports.

5. Animation is presentation.

   Locomotion clips are in-place. The velocity integrator and choreographer move the actor in world
   space. Root motion may be preserved in source files as reference, but exported runtime clips should
   not be required for gameplay position.

6. PBR realistic is the near-term art target.

   The cel flag exists in the director spike, but the current call is realistic PBR with anime-real
   combat staging, not cel-shaded production art.

## 3. Recommended Pipeline Decision

Use a project-owned mechanical humanoid skeleton with a Mixamo-retargetable core.

This is the middle path between two tempting extremes:

- Pure Mixamo skeleton: easiest reuse of current placeholder clips, but too human and poor for armor
  plates, skirt plates, thruster pods, and hard-surface mechanical posing.
- Arbitrary custom rig per artist: best local art freedom, but bad for animation reuse, hardpoint
  automation, and Godot import QA.

`KM_MechSkeleton_v1` should keep a clean humanoid core that can be mapped from Mixamo or other common
humanoid sources, then add mech-specific deformation bones, armor bones, and socket markers. Every
frame variant uses this skeleton template and rest pose unless an approved `KM_MechSkeleton_v2` is
created later.

## 4. Package Contents

The artist package we hand off should contain these files:

```text
artist_handoff/
  README.md
  00_style_brief/
    kitbash_mecha_visual_guardrails.md
    approved_reference_board.pdf
    forbidden_ip_shapes.md
  01_templates/
    KM_MechSkeleton_v1.blend
    KM_MechSkeleton_v1.glb
    KM_MechSockets_v1.json
    KM_MechScaleScene_v1.blend
    KM_GodotImportTest_v1.zip
  02_contracts/
    mesh_contract.md
    rig_contract.md
    animation_contract.md
    equipment_contract.md
    breakaway_contract.md
    materials_contract.md
    validation_checklist.md
  03_examples/
    blockout_frame_example.blend
    blockout_frame_example.glb
    blockout_rifle_example.glb
    blockout_booster_example.glb
    blockout_breakaway_plate_example.glb
    example_import_report.md
  04_delivery_template/
    mech_frame_v1/
      README.md
      source/
      export/
      textures/
      animations/
      equipment/
      metadata/
      preview/
      qa/
```

The repo artifact should probably live under `docs/art/` first, then graduate into an
`artist_handoff/` package once the template files exist.

## 5. Asset Scale and Orientation Contract

Use one Godot unit as one meter.

Required frame scale:

- Standard mech height: 18 to 22 meters from ground to top of head.
- Origin: ground center between feet.
- Rest pose: symmetrical A-pose preferred; T-pose acceptable only if the skeleton template uses it.
- Godot axis convention: Y up, asset front is `+Z`.
- Blender working convention: asset front faces `-Y`, exported to Godot as `+Z` front.
- Apply transforms before export.
- Triangulate before export or via an applied triangulate modifier.
- Export in rest pose; mesh must not be deformed by an active pose at export.

Final engine delivery:

- Preferred: `.glb` plus separate source `.blend`.
- Acceptable fallback: `.gltf` plus external textures when version-control diffability matters.
- FBX may be included for DCC interchange, but should not be the primary engine import unless a
  specific technical reason appears.

## 6. Canonical Skeleton Contract

Proposed skeleton family name: `KM_MechSkeleton_v1`.

Required core bones:

```text
root
pelvis
spine_01
spine_02
chest
neck
head
clavicle_l
upper_arm_l
forearm_l
hand_l
clavicle_r
upper_arm_r
forearm_r
hand_r
thigh_l
shin_l
foot_l
toe_l
thigh_r
shin_r
foot_r
toe_r
```

Recommended mechanical/armor bones:

```text
shoulder_armor_l
shoulder_armor_r
forearm_armor_l
forearm_armor_r
hip_armor_l
hip_armor_r
skirt_front_l
skirt_front_r
skirt_side_l
skirt_side_r
backpack_mount
booster_gimbal_l
booster_gimbal_r
```

Optional finger or manipulator bones:

```text
thumb_01_l, thumb_02_l
index_01_l, index_02_l
thumb_01_r, thumb_02_r
index_01_r, index_02_r
```

Rules:

- Keep the core bone names exact.
- Do not rename bones after animation work starts.
- Keep rest pose identical across all frame variants.
- Rigid armor plates should be mostly weighted to one bone.
- Deformation should occur at visible mechanical joints or under-frame segments, not through armor
  slabs that should read as metal.
- Vertex influences should be capped to 4 weights where practical for mobile compatibility.
- Armor/skirt plates should be animated, constrained, or weighted enough to avoid obvious clipping
  during walk, run, strafe, boost, melee, and death.

Cosmetic armor breakaway:

Armor can fall off during battle as spectacle, but it must remain presentation-only. It never changes
HP, defense, hitboxes, sockets, weapon count, power economy, or sim outcome.

Author breakaway armor as separate rigid plates or plate groups, not as inseparable body topology.
Each breakaway group should have an intact mesh, an optional damaged-reveal mesh or stump, and an
optional debris mesh used once the plate detaches. Good candidates are pauldrons, forearm shells,
skirt plates, knee guards, calf covers, chest add-on plates, backpack fins, and cosmetic ablative
panels. Bad candidates are the core pelvis/spine/head frame, hands, feet, primary weapon grips, and
any surface whose disappearance would make locomotion or aiming unreadable.

Breakaway metadata example:

```json
{
  "breakaway_id": "armor_shoulder_r_outer",
  "parent_bone": "shoulder_armor_r",
  "covers_region": "shoulder_r",
  "intact_mesh": "armor_shoulder_r_outer_intact",
  "damaged_reveal_mesh": "armor_shoulder_r_outer_stump",
  "debris_mesh": "armor_shoulder_r_outer_debris",
  "detach_socket": "socket_break_shoulder_r_outer",
  "detach_axis": "+Z",
  "spin_axis": "+Y",
  "mass_class": "medium",
  "fx_tags": ["spark", "smoke_puff"],
  "detach_allowed_when_occupied": false,
  "notes": "Cosmetic only. Shoulder weapon sockets remain owned by the frame."
}
```

Breakaway rules:

- Detachment is triggered by deterministic presentation logic reading combat-truth events, such as
  heavy hit, melee contact, blocked impact, or lethal overkill. The visual choice may use the fight
  seed, but it must never roll gameplay randomness.
- If a hardpoint sits on top of breakaway armor, the hardpoint itself belongs to the frame or a
  non-detaching stump. A falling armor shell may reveal the hardpoint; it must not delete a mounted
  weapon or make the weapon stop firing.
- If we want a mounted weapon to appear to be blasted off later, that is a separate cosmetic
  equipment-breakaway rule. The real grid item still exists for sim purposes unless the sim itself
  has an authored disarm event in a future design.
- Detached pieces should use deterministic arcs/tweens or seeded visual motion for replay stability.
  Avoid relying on unconstrained physics collisions for any visual we expect to reproduce exactly.
- Keep the damaged silhouette attractive. The mech can look battered and stripped, but not like a
  broken import with holes through its core rig.

## 7. Socket and Hardpoint Contract

Sockets should be delivered as named empty nodes or marker nodes parented to the appropriate bones.
If Godot import drops the marker nodes in a given workflow, the fallback is socket bones with the
same names. The validation package must confirm which representation survives import.

Gun-bristling target:

- The standard frame should support at least 24 visible equipment sockets before any cosmetic
  duplicates or variant-specific mounts.
- At least 18 of those sockets should be weapon-capable fallback mounts.
- A stress loadout of 10 to 14 small/medium guns plus reactors, supports, boosters, and shields
  should read as intentionally overloaded rather than broken or stacked on one point.
- Extra sockets are presentation capacity only. They do not increase weapon count, damage, or power
  budget unless the build grid placed those items.

Primary frame sockets:

```text
socket_head_aux
socket_head_side_l
socket_head_side_r
socket_chest_aux_l
socket_chest_aux_r
socket_chest_center
socket_hand_grip_l
socket_hand_grip_r
socket_forearm_l
socket_forearm_r
socket_forearm_under_l
socket_forearm_under_r
socket_upper_arm_l
socket_upper_arm_r
socket_shoulder_l
socket_shoulder_r
socket_shoulder_top_l
socket_shoulder_top_r
socket_shoulder_side_l
socket_shoulder_side_r
socket_hip_l
socket_hip_r
socket_waist_front_l
socket_waist_front_r
socket_waist_rear_l
socket_waist_rear_r
socket_backpack_center
socket_backpack_high
socket_backpack_low
socket_back_boom_l
socket_back_boom_r
socket_back_boom_high_l
socket_back_boom_high_r
socket_leg_l
socket_leg_r
socket_thigh_l
socket_thigh_r
socket_knee_l
socket_knee_r
socket_calf_l
socket_calf_r
socket_ankle_l
socket_ankle_r
socket_thruster_main_l
socket_thruster_main_r
```

Overflow sockets for maxed-out grid builds:

```text
socket_shoulder_aux_l
socket_shoulder_aux_r
socket_shoulder_rear_l
socket_shoulder_rear_r
socket_back_low_l
socket_back_low_r
socket_knee_aux_l
socket_knee_aux_r
socket_calf_aux_l
socket_calf_aux_r
socket_backpack_side_l
socket_backpack_side_r
socket_backpack_top_l
socket_backpack_top_r
socket_tail_boom_l
socket_tail_boom_r
```

Socket directionality:

```text
hand_grip       +Z = weapon barrel/blade forward, +Y = weapon up
forearm         +Z = barrel forward along arm aim, +Y = away from forearm surface
forearm_under   +Z = barrel forward along arm aim, +Y = downward/outward from forearm underside
shoulder/top    +Z = barrel forward over shoulder, +Y = local up from shoulder armor
shoulder/side   +Z = barrel forward, +Y = outward from shoulder side armor
chest/head      +Z = forward from torso/head, +Y = local up
hip/waist       +Z = forward or slight outward-forward, +Y = local up
backpack/back   +Z = forward over the mech or upward-forward for artillery booms, +Y = local up
leg/knee/calf   +Z = forward along stance direction, +Y = outward from leg armor
thruster        +Z = thrust visual points out of the nozzle, metadata must mark exhaust direction
shield          +Z = outward face/impact normal, +Y = local up
```

Each socket in metadata needs:

```json
{
  "id": "socket_hand_grip_r",
  "parent": "hand_r",
  "type_tags": ["hand-grip", "weapon", "saber", "primary"],
  "side": "right",
  "priority": 10,
  "direction": {
    "forward_axis": "+Z",
    "up_axis": "+Y"
  },
  "local_transform": {
    "position": [0, 0, 0],
    "rotation_degrees": [0, 0, 0]
  },
  "notes": "Primary right-hand weapon mount. Weapon front points +Z."
}
```

Hardpoint principles:

- A maxed loadout must still display. Provide enough generic fallback mounts that 10 to 14 visible
  weapons plus non-weapon modules can appear without stacking into one spot.
- Hand weapons are preferred for rifles/sabers, but fallback must include forearms, upper arms,
  shoulders, chest, hips, waist, legs, backpack, and back booms.
- Builders/reactors need visible body/backpack/hip/back hardpoints so power economy reads on the
  mech, not just in the UI.
- Supports should have visible module forms: optic, targeting relay, cooling fin, amplifier coil,
  capacitor pack, ammo feed, splitter vane, etc.
- Socket transforms should be authored so a plain blockout weapon points correctly before any custom
  per-weapon offsets.
- Sockets should leave enough clearance for recoil, melee wind-up, shoulder turns, and walking
  silhouettes. A mount that only works in the bind pose is not production-ready.

## 8. Equipment Mesh Contract

Equipment is separate from the base frame. The build grid decides which equipment is mounted; the
hardpoint cascade decides where it appears.

Required first equipment set:

- Rifle or beam carbine: hand-grip weapon with `muzzle_main`.
- Saber hilt: hand-grip weapon with `blade_origin`.
- Heavy cannon: back/shoulder heavy weapon with `muzzle_main`.
- Missile rack: shoulder/back/forearm weapon with `muzzle_01...muzzle_N`.
- Shield: forearm or hand support/defense item.
- Booster pack: backpack mobility item with `thruster_l`, `thruster_r`, and optional gimbals.
- Reactor/generator: builder item with emissive power core and at least one heat/vent detail.
- Support module: small and medium generic support modules that can represent early M1 support buffs.

Equipment orientation:

- Origin/pivot at its mount point.
- Equipment front points `+Z`.
- Grip or mount transform must align to the target socket without hand-authored script offsets.
- Include local marker nodes for effect origins:
  - `muzzle_main`
  - `muzzle_01...`
  - `blade_origin`
  - `thruster_main`
  - `eject_port`
  - `impact_focus` when useful for shields or large modules

Equipment metadata should include:

```json
{
  "id": "eq_rifle_blockout_v1",
  "category": "spender",
  "mount_tags": ["hand-grip", "forearm", "shoulder", "hip"],
  "preferred_mount": "socket_hand_grip_r",
  "fallback_mounts": [
    "socket_hand_grip_l",
    "socket_forearm_r",
    "socket_forearm_l",
    "socket_forearm_under_r",
    "socket_forearm_under_l",
    "socket_upper_arm_r",
    "socket_upper_arm_l",
    "socket_shoulder_r",
    "socket_shoulder_l",
    "socket_shoulder_top_r",
    "socket_shoulder_top_l",
    "socket_shoulder_side_r",
    "socket_shoulder_side_l",
    "socket_hip_r",
    "socket_hip_l",
    "socket_waist_front_r",
    "socket_waist_front_l",
    "socket_back_boom_r",
    "socket_back_boom_l"
  ],
  "effect_sockets": ["muzzle_main"],
  "scale_notes": "Sized for 20m frame."
}
```

## 9. Material and Texture Contract

Use PBR materials. The director can push grade, lighting, and accent color globally, so assets
should not bake an entire mood into their textures.

Required material slots:

- `mat_armor_primary`
- `mat_armor_secondary`
- `mat_inner_frame`
- `mat_joint_dark`
- `mat_sensor_emissive`
- `mat_weapon_metal`
- `mat_thruster_emissive`
- `mat_glass_or_lens`

Texture recommendations:

- Base frame: 2K to 4K texture sets depending on final complexity.
- Weapons and small modules: 1K to 2K texture sets.
- Use albedo, normal, ORM, and emissive where needed.
- Keep grime and panel wear readable but restrained; the viewer uses fast cuts and long shots, so
  silhouette, material separation, and emissive cues matter more than tiny decals.
- Provide team/accent mask if feasible so the game can tint sides without duplicating textures.

Visual identity requirements:

- Sensor face should be original: mono-eye, single visor band, full-face sensor plate, or a new
  equivalent.
- The silhouette should be humanoid and readable at isometric distance.
- Shoulder/back/hip zones should leave visual room for mounted grid equipment.
- Thruster locations should be obvious from the rear and in three-quarter views.
- Avoid over-dense greebling around joints where animation must stay readable.

## 10. Animation Contract

The minimum first milestone is nine clips.

Looping clips:

- `idle`
- `walk`
- `run`
- `strafe_l`
- `strafe_r`

One-shot clips:

- `fire`
- `melee_strike`
- `hit_react`
- `death`

Second milestone clips:

- `boost_dash`
- `jump_start`
- `land_heavy`
- `guard`
- `parry`
- `clash_lock`
- `heavy_recoil`

Clip rules:

- Locomotion is in-place for runtime use.
- Root translation may exist in source reference files, but exported runtime clips must not be
  required to move the actor through the world.
- Maintain foot contact quality. Foot sliding is one of the fastest ways to make a 20m machine read
  like a person in a costume.
- Motions should be slower, stiffer, and more committed than human mocap. Weight is sold through
  cadence, follow-through, impact dwell, and pose commitment.
- Firing should plant the upper body and recoil through shoulders/chest without detaching the weapon
  from the hand.
- Melee should include wind-up, committed lunge or cleave, contact frame, and recovery.
- Hit reaction should read at long camera distance: torso snap, shoulder displacement, or stagger.
- Death should provide a readable shutdown/topple/silhouette collapse; the director and garnish can
  add explosion staging.

Recommended clip annotations:

```json
{
  "clip": "melee_strike",
  "loop": false,
  "events": [
    {"name": "windup", "frame": 8},
    {"name": "blade_on", "frame": 10},
    {"name": "contact", "frame": 22},
    {"name": "recover", "frame": 38}
  ]
}
```

Godot-side note:

- Current rig prototype keeps the rifle rigidly mounted to the hand and aims the whole body. Do not
  design around a detached independently-aimed gun. If upper-body aim layers are added later, they
  should preserve hand/weapon contact.

## 11. Runtime Procedural Animation Contract

The authored clips provide the readable base pose. Runtime procedural animation adds contact,
aiming, hit reaction, recoil, boost force, armor motion, and stance adaptation on top. This is how
we get a mech that reacts to the exact fight log without authoring a unique animation for every
possible weapon, hit direction, and terrain position.

Godot implementation assumption:

- Use an `AnimationTree` or `AnimationMixer` for base clips and blends.
- Use `SkeletonModifier3D`-based modifiers after animation playback for procedural overlays. Godot
  4.6 documents that skeleton modifiers run after `AnimationMixer` playback, which is the ordering
  we want: clip first, procedural correction second.
- Prefer Godot 4.6 `IKModifier3D` descendants such as `TwoBoneIK3D` for legs and simple arms.
  `SkeletonIK3D` exists but is deprecated in 4.6, so it should not be the production target.
- Use `LookAtModifier3D` or a custom skeleton modifier for torso/head/turret aim where useful.
- Use custom `SkeletonModifier3D` scripts for mech-specific pose impulses: stagger, recoil,
  AMBAC arm swing, banking, landing compression, and impact settle.

Runtime layer order:

```text
1. Base authored clip
   idle / walk / run / strafe / fire / melee / hit / death

2. Locomotion pose shaping
   speed scale, cadence, pose hold, bank/lean, pelvis height, planted-vs-mobile firing

3. Aim and weapon alignment
   torso yaw/pitch, shoulder settle, hand/socket preservation, optional turret/look-at bones

4. Foot and contact IK
   foot targets, knee poles, ankle/toe roll, pelvis compensation, foot locking

5. Impact overlays
   recoil, stagger, hit-region flinch, guard strain, melee clash press, knockback anticipation

6. Secondary mechanical motion
   armor plate lag, skirt clearance, booster gimbal, springy fins, cable sway if present

7. Cosmetic breakaway and debris
   deterministic plate detach, sparks, smoke, damaged reveal meshes
```

Leg IK / "reverse IK" target:

Each leg should be compatible with a standard two-bone IK chain:

```text
thigh_l -> shin_l -> foot_l
thigh_r -> shin_r -> foot_r
```

Required IK helper markers:

```text
ik_foot_target_l
ik_foot_target_r
ik_knee_pole_l
ik_knee_pole_r
ik_toe_target_l
ik_toe_target_r
foot_heel_l
foot_heel_r
foot_ball_l
foot_ball_r
foot_toe_l
foot_toe_r
```

Leg IK rules:

- Foot targets are generated by the runtime from the current staged movement and terrain sample.
  On flat test stages they stay on the deck; on uneven terrain they ray/sample downward and align the
  foot to the surface normal.
- Knee pole markers must sit in front of the natural knee bend so the leg does not flip during
  strafes, recoil, or knockback.
- The authored locomotion clips should include clear foot contact windows. The runtime can then lock
  a foot during planted frames and release it during swing frames.
- Pelvis height should be adjustable by the runtime so both feet can stay planted without stretching
  the legs.
- Toe bones are optional but recommended. They let a 20m machine push off, absorb landings, and keep
  heavy footfalls readable.
- If a leg carries mounted equipment, the IK solution must not swing that equipment through the torso
  or the opposite leg.

Damage reaction model:

Damage reaction is built from event-log facts plus authored additive poses. The sim says a hit,
block, near-miss, melee clash, knockback, or kill happened. The presentation layer chooses the visual
reaction from deterministic data and the fight seed.

Required authored additive poses or short overlays:

```text
hit_front_light
hit_front_heavy
hit_left_light
hit_left_heavy
hit_right_light
hit_right_heavy
hit_back_heavy
guard_strain
recoil_light
recoil_heavy
melee_clash_press
landing_compress
boost_lean
```

Reaction metadata example:

```json
{
  "reaction_id": "hit_front_heavy",
  "trigger_tags": ["hit", "heavy"],
  "affected_bones": ["pelvis", "spine_01", "spine_02", "chest", "head", "clavicle_l", "clavicle_r"],
  "impulse_axis": "-Z",
  "peak_frame": 5,
  "recover_frames": 18,
  "max_influence": 0.85,
  "allows_foot_lock": true,
  "allows_weapon_fire": false
}
```

Damage reaction rules:

- A light hit should usually be an additive flinch over the current locomotion.
- A heavy hit should combine upper-body flinch, pelvis shift, foot brace, camera/time emphasis, sparks,
  and optional armor breakaway.
- A melee clash should drive both machines into planted strain poses. Foot IK locks both actors so
  the contact reads as mass pressing against mass, not sliding.
- A near-miss should not use hit reaction poses. It should bias dodge/weave, torso duck, shield raise,
  or foot replant without implying damage.
- A kill can leave the procedural stack and hand control to the authored `death` clip plus garnish.

Artist deliverables for procedural support:

- IK marker nodes or bones named exactly as above.
- Pole target placement that bends knees reliably in idle, walk, strafe, fire, and hit poses.
- Additive reaction poses listed above, authored on the same skeleton and rest pose.
- Clip event annotations for foot contact, foot release, muzzle/fire, melee contact, guard contact,
  landing, and recovery.
- Clearance pass showing that sockets, weapons, breakaway plates, skirts, and leg armor survive the
  procedural extremes.

Determinism boundary:

- Procedural animation remains presentation. It never decides whether a hit lands.
- Procedural choices that need variety use the fight seed and event-log data, not unseeded random.
- For replay stability, prefer deterministic tweens and terrain samples over unconstrained physics.
  Full physics ragdoll is acceptable only for non-authoritative debris or an optional non-replay mode.

## 12. Quality Gates

The handoff package is not accepted until a delivered asset passes these checks.

Import checks:

- `.glb` imports into Godot 4.6 without missing mesh, skeleton, material, or animation tracks.
- The imported frame is 18 to 22 Godot units tall.
- Asset front is `+Z`; `look_at(..., use_model_front=true)` behavior is sane.
- Rest pose matches `KM_MechSkeleton_v1`.
- Socket nodes or socket bones survive import with exact names.
- Material slots are named and separable.

Rig checks:

- All required bones exist.
- No major armor plate bends like rubber.
- No major clipping in idle, walk, run, strafe, fire, melee, hit, and death.
- Grip sockets stay aligned through fire and melee.
- Foot contacts are stable in walk/run/strafe.
- Death pose does not explode the rig or invert limbs.

Procedural animation checks:

- Foot IK markers and knee pole markers exist and solve cleanly for both legs.
- A flat-ground IK pass keeps feet planted during idle, firing, melee clash, and heavy hit overlays.
- A slope/step test adjusts feet and pelvis without knee flipping, foot stretching, or armor clipping.
- Additive hit poses layer over idle, walk, strafe, fire, and guard without breaking weapon alignment.
- Recoil and heavy-hit overlays respect mounted equipment clearance on hands, forearms, shoulders,
  waist, backpack, and legs.
- Clip event annotations exist for contact/release/fire/impact/recovery frames.

Mount checks:

- A rifle mounted to `socket_hand_grip_r` points along `+Z` and emits from `muzzle_main`.
- A saber mounted to either hand places `blade_origin` correctly.
- Shoulder and back weapons clear the head during idle, walk, and fire.
- A stress loadout with 10 to 14 guns plus several non-weapon modules can be mounted using
  preferred/fallback hardpoints and remains visually distinguishable.
- Thruster FX origins face the intended exhaust direction.

Breakaway checks:

- Each authored breakaway group can hide its intact mesh, reveal its damaged mesh or stump, and spawn
  its debris mesh from the correct detach socket.
- A deterministic test hit detaches the same armor group on replay from the same log and seed.
- Detaching armor does not remove gameplay sockets, mounted weapons, muzzle markers, or thruster
  markers.
- Detached plates clear the actor during idle, walk, strafe, fire, melee, and death preview tests.
- The stripped frame still reads as an intentional damaged mech rather than missing geometry.

Combat viewer checks:

- Asset reads in hybrid director's isometric base shot.
- Asset reads in close melee shot.
- Asset reads in low pedestrian/scale shot.
- Muzzle flashes, beams, missiles, saber blade, and thrusters originate from the correct markers.
- The frame still reads as original Kitbash Mecha identity under grade and lighting changes.

Performance checks:

- First target is Steam PC, but avoid obviously wasteful topology or material counts.
- Mobile-compatible second target means keep material slots and skinned vertex counts under review.
- Provide LOD or simplified variants later if profiling shows the need; do not block the first art
  contract on premature LOD work.

## 13. Recommended Work Sequence

Phase 0 - Technical template

- Build `KM_MechSkeleton_v1.blend`.
- Add required sockets as markers.
- Export a greybox frame and greybox equipment.
- Import into Godot and prove sockets, animation, and hardpoint cascade.
- Produce the package examples.

Phase 1 - Artist blockout

- Artist delivers greybox original frame on the template skeleton.
- Artist delivers first four clips: `idle`, `walk`, `fire`, `melee_strike`.
- Integrate in the current viewer and compare against the blockout rig.

Phase 2 - Production base frame

- Artist delivers final base mesh, PBR materials, and all nine milestone clips.
- Integrate in the viewer and run import/rig/mount checks.

Phase 3 - Equipment kit

- Artist delivers first equipment set: rifle, saber, cannon, missile rack, shield, booster, reactor,
  support modules.
- Wire metadata to the build-grid mount cascade.
- Test maxed visible loadout.

Phase 4 - Feel pass

- Tune animation cadence and silhouette against the director grammar.
- Validate heavy/light archetype reads using current presets: bruiser, skirmisher, gunner, anvil,
  hornet, lancer, bastion.
- Record preview captures and mark any rig issues before content multiplication.

## 14. Package Review Questions

Resolve these before paying for final production art:

1. Do we want one universal frame mesh for v0.1, or 2 to 3 frame silhouettes that share the same
   skeleton?
2. Should external artists author the nine milestone clips, or should they deliver rigged meshes and
   we contract a separate animator for motion?
3. Are socket markers reliable enough through our chosen `.glb` import path, or should sockets be
   bones for maximum robustness?
4. What first visual identity is approved: mono-eye, visor band, or full-face sensor plate?
5. What is the first equipment-kit list required by M1/M0: rifle/saber/cannon/missile/shield/booster/
   reactor/support, or a smaller proof set?
6. Should the roadmap gain a pending node such as `art-skel-handoff` before this work is assigned?

## 15. Recommended Roadmap Treatment

Do not graft this directly into the active M0/M1 route yet.

Recommended node if approved:

```json
{
  "id": "art-skel-handoff",
  "title": "3D mech skeleton + artist handoff package",
  "state": "pending",
  "kind": "art-pipeline",
  "version": "0.1",
  "deps": ["dec-stack", "cf-viewer"],
  "goal": "Define and validate the project-owned 3D mech skeleton, socket, hardpoint, material, equipment, and animation contract for artists.",
  "doneWhen": "A greybox frame and equipment kit import into Godot, sockets survive import, the nine-clip contract is proven at least with blockout motion, and the handoff package is ready for production artists."
}
```

It can run parallel to M0/M1 once the greybox import harness exists. It should not block the
fireworks sandbox unless we decide the sandbox must use production art instead of blockout art.
