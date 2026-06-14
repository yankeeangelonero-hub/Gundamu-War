# Handoff — minimum pose and animation set for the mech (2026-06-14)

## Where this stands

The director spike now renders the real Gundam Mk-II mech mesh instead of the grey block-out. It imports as a single textured model (~20 m tall, 4K albedo), and the viewer can show it three ways through `main.gd`: a turntable for look review (`--gundam`), a pedestrian worm's-eye (`--gundam --ped`), and a hero crane with scale-reference figures, a low golden sun, and depth haze (`--gundam --hero`). Each of those composes with `--cel` for the cel-shaded variant and `--tune` for a live slider panel.

After comparing cel against realistic PBR on the actual textured mech, the call is that the realistic 3D look reads better for this project. So the near-term art direction is realistic PBR. The cel pipeline still exists behind the `--cel` flag and should not be deleted — it is just no longer the target, and no further cel tuning is planned unless the decision is revisited.

The mech itself has no animation. Its rig is a single 67-bone Blender skeleton with non-Mixamo naming (`pelvis`, `Arm_u/m/d.L`, `Leg_u/m/d.L`, and so on) plus mech-specific armor bones — shoulderguards, footguards, and front and side skirt plates. The clips the spike plays today do not belong to this rig; they live on a separate 65-bone Mixamo placeholder and are wired in `mech_actor.gd` inside `_build_rigged`: an idle, a walk, a run, strafe left and right, and a firing stance. Those Mixamo clips are the source material we will retarget onto the Gundam rig, not the final animations.

## What the mech actually has to do

The combat simulation is deterministic and separate from rendering, so animation here is cosmetic — it has to make the duel read, not drive it. The director and garnish only ever put the mech into a small number of visible states: it advances and repositions on the ground, it fires ranged weapons, it strikes in melee, it reacts to being hit, it guards, it boosts, and it dies. Everything the player sees is one of those. That keeps the required clip list short, and it means we should resist authoring more than the states the sim can actually produce.

Two things further shrink the list. Aiming does not need its own clips: Godot's runtime look-at modifier can rotate the upper body and weapon toward the target on top of the idle, so a single idle plus a single firing stance covers every aim angle. And facing changes are already handled by the body-yaw tracking in `mech_actor.gd` (`combat_face`), so a dedicated turn-in-place clip is probably unnecessary for now.

## The minimum set, by priority

The first tier is locomotion and idle. The mech is always in one of these, so without them it is either a statue or a T-pose, and nothing else matters until they exist. These are looping clips:

- Idle — the resting, rifle-ready stance the mech holds when stopped.
- Walk — also played in reverse for a backpedal, so a retreat reads as walking backward rather than moonwalking.
- Run.
- Strafe left.
- Strafe right.

These five are exactly the ones already proven on the Mixamo placeholder, so they are the natural first retarget target.

The second tier is the combat reads — the one-shot actions that turn locomotion into a fight. They can be upper-body-biased where possible so they blend over whatever the legs are doing:

- Fire — a plant-and-recoil firing stance. One generic stance is enough to start, because the muzzle flash, beam, and missile effects are all garnish, not animation, so the same body action serves rifle, beam, and bazooka.
- Melee strike — a saber or fist swing.
- Hit reaction — a short flinch when taking damage.
- Death — the collapse or shutdown that ends the duel.

With the first tier plus fire and death, the duel is legible end to end. Adding melee and the hit reaction is what makes it feel like an exchange rather than two mechs trading invisible blows, so the recommended first animated milestone is those nine clips.

The third tier is weight and feel, worth doing once the fight is legible. A boost or dash lunge with a thruster pose, currently faked by speeding up locomotion. A jump and a landing settle, where the landing is where mass really sells. A guard or block stance for parries. None of these block a believable duel; they raise it.

Beyond the clips, two static poses matter. The retarget step needs a clean bind pose — an A-pose or T-pose on the Gundam rig that matches the source rig's rest pose, or the transfer comes out twisted. And the idle doubles as the mech's signature ready pose, the silhouette it holds at rest, so it is worth keying deliberately rather than treating as a throwaway.

## What this means for the next person

The path is the cheapest pipeline from the animation research (saved in the project memory): retarget the existing Mixamo clips onto the Gundam's 67-bone rig in Blender, using Auto-Rig Pro's Remap or the free Rokoko plugin, then import the finished clips into Godot as an AnimationLibrary on the mech's own skeleton. Do the heavy retargeting in Blender rather than leaning on Godot's BoneMap, because Godot's humanoid profile has no slots for this rig's armor, skirt, toe, or finger bones and will only map the standard humanoid core.

A few things will bite if ignored. The source motion is human-proportioned and the mech is not, so the root translation has to be scaled by a single uniform factor or the feet will slide; a foot-lock pass cleans up the contacts. The Mixamo motion is also human-cadenced and floaty, so each clip wants re-timing roughly fifteen to twenty-five percent slower and stiffer to land the heavy Gundam feel — without that step the retarget looks like a person in a costume. The armor and skirt bones are never driven by the source motion at all; the simplest first pass is to leave them static, and a later pass can constrain the shoulderguards to the arms and the skirt plates to the legs, or bake a little physics sway, to keep them from reading as rigidly bolted on. Finally, the agent research flagged a glTF-plus-BoneMap importer bug in Godot 4.3 and 4.4 where animation tracks could be lost; we are on 4.6, so confirm a retargeted clip actually imports with its tracks intact before committing to the whole set.

One open question for whoever picks this up: whether to retarget all nine first-milestone clips from Mixamo, or to hand-author the few hero actions — boost, jump, melee — in Cascadeur for real mechanical weight and only retarget the mundane locomotion. The research leans toward the hybrid, but it is a cost-versus-quality call that has not been made yet.
