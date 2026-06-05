# Artist / Image-Agent Handoff — Mech Bags Side-Profile Mech Sprites

**Project:** Mech Bags  
**Date:** 2026-06-05  
**Owner direction:** “I want side profile gundams.”  
**Target folder for delivered assets:** `D:/Claude/Mech Bags/prototype/assets/sprites/` or `D:/Claude/Mech Bags/agent-handoffs/sprite-assets/` for review batches.

---

## 1. Product context

Mech Bags is currently moving toward a simpler Backpack Battles-like base:

```text
one expandable canvas
→ buy small bag pieces / place items spatially
→ deploy build to theatre
→ mech keeps fighting in paced real-time sorties
→ retreat for loot + pilot XP/skills
→ modify build and redeploy
```

The five body-part bags are no longer the active V0.2 build surface. The art should support a **single-canvas buildcraft game with mech/war identity**, not five separate anatomical boards.

Sprites are needed to make the deployed theatre fights feel like actual mecha battles instead of abstract UI blocks.

---

## 2. Visual direction

Create **side-profile anime mecha sprites** inspired by classic real-robot / Gundam-like silhouettes, but do **not** copy protected named Gundam units, logos, exact armor shapes, colorways, or faction marks.

Desired feel:

- side-view combat sprites;
- angular heroic humanoid mechs;
- readable shoulders, torso, backpack, head crest/antenna, arms, legs;
- tactical military hardware rather than cute chibi;
- clean silhouette at small size;
- fits a dark tactical garage / armored workbench UI;
- enough anime flair to feel exciting;
- not hyper-detailed concept art that becomes unreadable in-game.

Avoid:

- direct RX-78, Zaku, Wing, Strike, Exia, Nu, etc. copies;
- copyrighted emblems/logos;
- front-facing beauty shots;
- extreme 3/4 perspective;
- busy painterly backgrounds;
- tiny details that vanish at 128px width;
- weapons covering the entire silhouette.

---

## 3. Required sprite format

Produce sprites as transparent PNGs.

Recommended working/export sizes:

```text
source canvas: 512×512 transparent PNG
in-game display target: ~160×160 or ~192×192
orientation: strict side profile
facing: right for player base sprite, left-facing mirrored variants are acceptable but not required
background: transparent
```

Each sprite should fit within the frame with padding:

- full mech visible;
- feet not clipped;
- backpack/weapon not clipped;
- centered vertical mass;
- ground line implied but no background floor unless separate shadow is provided.

Naming convention:

```text
mech_player_base_side_r.png
mech_enemy_balanced_side_l.png
mech_enemy_missile_side_l.png
mech_enemy_beam_side_l.png
mech_enemy_turtle_side_l.png
mech_enemy_saber_side_l.png
mech_shadow_soft.png       # optional shared grounding shadow
```

If producing a review batch first, place in:

```text
agent-handoffs/sprite-assets/side-profile-mech-review-batch-01/
```

---

## 4. Minimum first batch

Create **6 side-profile sprites**:

### 1. Player Base Mech — `mech_player_base_side_r.png`

Role: neutral starter player suit.

Visual notes:

- right-facing;
- balanced humanoid frame;
- moderate shoulders;
- visible backpack thruster unit;
- one compact rifle or arm-mounted weapon;
- neutral prototype color scheme, e.g. ivory/steel/blue or white/navy/amber;
- should feel customizable, not like a legendary unique hero unit.

### 2. Balanced Enemy — `mech_enemy_balanced_side_l.png`

Role: standard enemy build.

Visual notes:

- left-facing;
- similar scale to player;
- simple rifle + shield or compact weapon;
- neutral military colors;
- clear all-rounder silhouette.

### 3. Missile Backpack Enemy — `mech_enemy_missile_side_l.png`

Role: missile / burst archetype.

Visual notes:

- left-facing;
- visibly heavier backpack missile pod / shoulder racks;
- silhouette should communicate “missile build” immediately;
- not too bulky; still readable as mobile suit.

### 4. Beam Rifle Enemy — `mech_enemy_beam_side_l.png`

Role: beam / ranged archetype.

Visual notes:

- left-facing;
- long beam rifle or integrated beam cannon;
- leaner frame;
- glowing beam energy accents allowed;
- strong horizontal weapon read.

### 5. Shield Turtle Enemy — `mech_enemy_turtle_side_l.png`

Role: armor / shield archetype.

Visual notes:

- left-facing;
- thick shoulder/torso armor;
- large shield visible in side profile;
- squat durable stance;
- communicates survivability before detail.

### 6. Saber Rush Enemy — `mech_enemy_saber_side_l.png`

Role: melee/speed archetype.

Visual notes:

- left-facing;
- dynamic forward lean;
- one beam saber / energy blade visible;
- lighter legs/shoulders;
- speed silhouette rather than tank silhouette.

---

## 5. Style constraints for game readability

Every sprite must pass these checks:

1. **Silhouette check:** At 96px wide, the sprite still reads as a mech.
2. **Archetype check:** Missile / shield / beam / saber variants are distinguishable without reading text.
3. **Side-profile check:** Major body orientation is side-on, not front-facing.
4. **Transparency check:** PNG has transparent background.
5. **Contrast check:** Sprite reads on dark blue/black battle background.
6. **No-IP-copy check:** Does not reproduce a named Gundam/mecha design exactly.

Preferred rendering style:

- semi-clean anime sprite/concept hybrid;
- crisp edges;
- mild cel shading;
- controlled highlights;
- limited palette per unit;
- strong outline or rim light if needed for dark UI.

---

## 6. Optional animation states

If doing static sprites only, skip this section.

If generating animation-ready states, use the same frame size and silhouette registration:

```text
idle
attack_rifle
attack_saber
hit
downed_or_disabled
```

Do not animate yet unless explicitly requested. For now, static side-profile sprites are enough.

---

## 7. Integration notes for frontend worker

Current prototype likely uses CSS/DOM sprite placeholders. Integration should be simple:

- add sprite files under `prototype/assets/sprites/`;
- update battle/spectate display to use `<img>` or CSS background-image;
- player sprite uses right-facing asset;
- enemy sprite uses left-facing asset;
- choose enemy sprite by enemy archetype/name;
- preserve current tests and battle logic;
- do not make sprite loading required for simulation determinism.

Suggested mapping:

```js
balanced  -> mech_enemy_balanced_side_l.png
missile   -> mech_enemy_missile_side_l.png
beam      -> mech_enemy_beam_side_l.png
defense   -> mech_enemy_turtle_side_l.png
melee     -> mech_enemy_saber_side_l.png
ballistic -> mech_enemy_balanced_side_l.png or later ballistic-specific sprite
```

If a sprite fails to load, fallback should remain a colored placeholder silhouette.

---

## 8. Prompt template for image generation

Use this as the base prompt and vary archetype-specific details:

```text
Transparent PNG game sprite, strict side-profile anime real-robot mecha, original Gundam-inspired but not copying any existing Gundam design, angular humanoid armored mobile suit, crisp readable silhouette, cel-shaded, dark tactical sci-fi palette, clean edges, no background, no text, no logo, full body visible, centered, 512x512, designed to remain readable at 128px wide.
```

Add archetype clause examples:

```text
balanced starter unit, compact rifle, moderate backpack thrusters, white steel navy amber colors, right-facing
```

```text
missile artillery unit, large backpack missile pods and shoulder racks, heavier upper silhouette, left-facing
```

```text
shield defense unit, thick armor, large side-profile shield, squat durable stance, left-facing
```

```text
beam rifle unit, long beam rifle silhouette, lean frame, glowing cyan energy accents, left-facing
```

```text
saber rush unit, forward-leaning agile frame, visible energy blade, light armor, left-facing
```

Negative prompt / avoid list:

```text
no exact Gundam RX-78, no Zaku, no copyrighted logos, no text, no watermark, no background, no front view, no 3/4 view, no chibi, no cropped feet, no photorealistic render, no busy line noise
```

---

## 9. Delivery checklist

For the first handoff batch, deliver:

- [ ] 6 transparent PNG side-profile sprites.
- [ ] One contact sheet preview image with all sprites side by side on dark background.
- [ ] File list with dimensions and byte sizes.
- [ ] Short note explaining which archetype each sprite represents.
- [ ] Confirmation that designs are original and not direct Gundam copies.
- [ ] If integrated into prototype, include browser screenshots of player/enemy sprites in battle/spectate screen.

---

## 10. Success definition

This handoff succeeds if a reviewer can open the contact sheet and immediately say:

> “These are side-profile Gundam-like mechs for a Backpack Battles-style warfront autobattler, and I can tell the missile, shield, beam, melee, and balanced archetypes apart at a glance.”
