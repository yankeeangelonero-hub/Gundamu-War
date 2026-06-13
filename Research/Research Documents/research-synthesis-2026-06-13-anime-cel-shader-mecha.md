# Research synthesis — anime cel-shader stack for cel-shaded mecha (Godot 4.6)

Date: 2026-06-13. Source: deep-research pass on anime/cel/toon shader techniques + landmark
implementations for an early-2000s-Gundam cel-shaded mecha look in Godot 4.6 (GDScript, Forward+).
19 sources, 25 claims verified (23 confirmed, 2 killed).

**Purpose:** the spike's `--anime` mode is a quick screen-space *filter* (posterise + depth/normal
ink) on a relit scene — a stopgap. This records the proven, art-directable technique stack to adopt
when real rigged meshes arrive, so we build on documented NPR craft, not a one-off.

---

## The recommended technique stack (verified)

**1. Cel diffuse — banded ramp.** Quantise `NdotL` either by `step()`/`smoothstep()` with a
controllable threshold, or (preferred, art-directable) by sampling a **ramp texture**
(`GradientTexture1D` / `CurveTexture`) with `NdotL`. Multi-step quantise (divide by step width,
`floor`/`ceil`, ~1–16 bands), antialias band edges with `fwidth`+`smoothstep`. In Godot do this via a
custom `light()` override (more control than the built-in `render_mode diffuse_toon`).

**2. Hard anime specular.** Threshold a Blinn-Phong term (`NdotH`, powered by glossiness) with
`smoothstep(0.005, 0.01, x)` for a hard highlight "blob"; or a dedicated specular ramp texture. This
is the "anime metal" sheen on panels.

**3. Toonified Fresnel/rim** with separate colour + intensity — reads the mecha silhouette in cel.

**4. Outlines — inverted hull (primary).** Draw the mesh again, extrude vertices along normals by an
`outline_width`, render **back faces only** with a dark unshaded material. In Godot 4: a `next_pass`
material, `render_mode cull_front, unshaded, depth_draw_never`, extrude in `vertex()`
(`clip_position.xy += normalize(clip_normal.xy)/VIEWPORT_SIZE * clip_position.w * outline_width`).
Art-directable: per-vertex outline width (incl. erasing) via **vertex colours**.

**5. Outlines — screen-space depth+normal (complementary).** Full-screen pass sampling depth+normal
buffers, finite-difference to catch **interior/crease** edges the inverted hull misses. (This is what
the spike's `--anime` filter does today.) Best result for hard-surface mecha = **both** combined:
inverted-hull for silhouette, screen-space for panel-seam creases.

---

## Landmark reference — Guilty Gear Xrd (THE one to study)

Junya Motomura, GDC 2015, *"GuiltyGearXrd's Art Style: The X Factor Between 2D and 3D"* — primary,
unanimously verified. The authoritative reference for 3D-cel that reads as 2D anime, and the
techniques transfer **directly to hard-surface mecha**:

- **Hand-edited vertex normals** on every major feature — auto-calculated normals "often [are] not
  what the Artist intended." This is how you get stable, intentional shading + outlines on hard
  surfaces (panel edges, intakes, joints).
- **Vertex-colour control** of (a) the **shadow threshold** per-vertex (force areas always-shaded, or
  darken occluded zones) and (b) **outline width** per-vertex (including erasing a line). Resolution-
  independent, interpolates cleanly — preferred over textures. This is the mechanism for deciding
  *which* mecha edges get inked and how strongly.
- **Reject mathematically-accurate lighting** — per-character hand-set light vectors, art over physics.

Slides: https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf ·
Talk: https://archive.org/details/GDC2015Motomura ·
ASW Academy (outline/vertex-colour): https://docswell.com/s/ASW_Academy/5LVY67-GG-Toonline-Eng

---

## Godot 4 resources to adopt

- **eldskald/godot4-cel-shader (MIT)** — the ready-to-reference Godot 4 base: custom `light()` →
  `diffuse_light()` sampling a global `diffuse_curve` ramp for banded diffuse, plus bundled toon
  **specular**, **fresnel/rim**, and an **inverted-hull `outline.gdshader`** attached via `next_pass`
  (`cull_front`/`unshaded`/`depth_draw_never`, `outline_width`/`outline_color` globals). Idiomatic
  Godot 4, bundles the whole stack. → https://github.com/eldskald/godot4-cel-shader
- **godotshaders.com "Complete Cel Shader for Godot 4"** — companion writeup of the above.
  https://godotshaders.com/shader/complete-cel-shader-for-godot-4/
- **CC0 screen-space depth+normal outline** (Godot 4 post-process) —
  https://godotshaders.com/shader/post-process-outline-depth-normal/ (and the "thick" variant).
- Technique tutorials (HLSL/Unity, math transfers directly): Roystan toon
  (https://roystan.net/articles/toon-shader/), Ronja improved-toon
  (https://www.ronja-tutorials.com/post/032-improved-toon/) and hull-outline
  (https://www.ronja-tutorials.com/post/020-hull-outline/), danielilett, simonschreibt.
- Genshin-style reference (community, reverse-engineered): festivities/PrimoToon (ramp + specular-ramp
  paths). https://github.com/festivities/PrimoToon

---

## Recommended approach for our case

1. Adopt **eldskald/godot4-cel-shader** as the material base (ramp `light()` + specular + fresnel),
   re-tuned for our palette; keep its **inverted-hull `next_pass`** as the primary outline.
2. Add the **screen-space depth+normal** pass (we already have a version) for interior panel creases.
3. When real rigged glTF mecha arrive, do the GGXrd work in **Blender**: edit vertex normals on hard
   edges + paint **vertex colours** for shadow threshold and outline width. This is the step that
   makes hard-surface line art clean — not a shader tweak.
4. Keep the deterministic split intact — shading is downstream of the sim; none of this touches the log.

---

## Open questions (not resolved by verified sources)

1. **Cel-style beam/energy/thruster FX** — no verified source; likely unshaded emissive with hard
   alpha/additive bands. Needs its own look-dev.
2. **Blender→Godot 4.6 authoring** of custom vertex normals + vertex colours, and whether the glTF
   importer preserves them — GGXrd principle is clear, the concrete toolchain steps are not yet
   confirmed (a small import spike).
3. Exact **balance of inverted-hull vs screen-space** outlines to ink panel seams cleanly on mecha.
4. **Forward+ gotchas** for this stack in 4.6 (custom `light()` behaviour, transparency sorting on the
   outline `next_pass`) — worth a confirmation spike.

## Not substantiated (flagged honestly)

Mecha-title-specific implementation docs (Gundam Versus / New Gundam Breaker / 30MM / Hardcore Mecha)
and "anime metal sheen" / cel beam-FX specifics did **not** survive verification — the report covers
transferable hard-surface craft, not those titles' internals. IP note: techniques only; no copying of
any Gundam designs/assets (original mecha identity per CLAUDE.md).
