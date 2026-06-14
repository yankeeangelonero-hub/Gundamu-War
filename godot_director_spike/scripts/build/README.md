# M1 build grid + power economy

This is the M1 slice of the v0.1 backpack engineering system: the build editor with
the power economy and a minimal adjacency, dressed in the EXOFRAME "Mech Bags Workshop"
visual language adapted from the approved Claude design. It lives inside the director
spike so the build screen and the (future) battlefield share one project. Scope is the
grid, the resolver, and the UI; the 3D mount cascade and the live fight are follow-ups.

The mechanics come from the spec at
`docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`. The look
and interaction come from the EXOFRAME workshop prototype (the React/HTML design under
`Gundam-handoff/.../Mech Bags Workshop - EXOFRAME.html`). Where the two disagreed, the
spec won on mechanics (power-economy reactor, PoE increased/more/flat damage, authored
buff-slots) and the design won on look and feel (the three-column command bay, the CRT
bag viewscreen, the signal palette, the kanji accents). The prototype's bag-expansion,
shop, gold and hull are deliberately not here — those are M2/M3.

## What's where

The pure, renderer-agnostic core (this is what the M0 sim will reuse unchanged):

- `build_data.gd` — loads the item catalogue from `res://data/build_items.json` and does
  the shape/rotation math. The one subtle invariant lives in `rotate_item()`: a support's
  footprint and its buff-slots rotate together under a single normalization, so a rotated
  support still buffs the same cells relative to its body.
- `build_grid.gd` — the 5×4 grid state: placement validity (every cell in-grid, no
  overlap), occupancy, rotation. No rendering.
- `build_resolver.gd` — the heart. A pure function of the placement: per-weapon effective
  damage and per-shot power cost via the spec's PoE algebra
  `(base + Σflat) × (1 + Σincreased) × Π(1 + more)` and `base_cost × Π cost_multiplier`,
  plus the build totals `pool = Σ builder pool`, `regen = Σ builder regen`. Same placement
  always yields the identical result — that is the PvP re-sim guarantee.
- `build_mounts.gd` — the mount cascade (spec §5). Each placed weapon resolves to a 3D
  hardpoint by trying its `preferred_mount`, then walking its `fallback_mounts`, then any
  remaining hardpoint in canonical order; extras past the nine points are reported as
  overflow, not silently dropped. Pure and deterministic, so the M0 fight mounts the same
  weapons in the same places.

The presentation (build screen):

- `build_grid_view.gd` — the bag viewscreen Control. Draws owned cells, placed item plates
  with their effective numbers, the held-item ghost, a support's buff-slot overlay, and a
  glow on supported weapons. Owns no game logic; all state is pushed in via `set_view()`.
- `build_mech_view.gd` — a 3D sub-viewport (its own `SubViewport` + camera + lights) holding
  the shared `MechActor` in build pose. `set_loadout()` runs the cascade and hangs placeholder
  block-out weapon meshes on the resolved hardpoints. The mech is the same node the combat
  viewer drives — `MechActor` gained a `build_pose` setup path (skips the combat FX, stands
  static) and a named hardpoint registry (`register_hardpoints` / `mount` / `clear_mounts`),
  generalised from its old fixed gun attach. The combat path is unchanged (`build_pose`
  defaults false).
- `build_screen.gd` + `../../scenes/build_screen.tscn` — the three-column command bay:
  left readouts (holding / selected / totals, synergies, in-the-bag), centre stage (the 3D
  frame view beside the bag grid), right dev palette. Wires clicks/keys to the grid and
  re-runs the resolver + re-mounts the loadout on every change.

The catalogue itself is data: `res://data/build_items.json` (builder / spender / support
defs, shapes, categories, the dev palette).

## Running it

The build screen is a standalone scene; the project's default scene is still the combat
viewer. Launch the editor directly:

```
godot --path godot_director_spike res://scenes/build_screen.tscn
```

Pick a part from the right-hand rack, click an owned cell to seat it, press `R` to rotate
(shape and buff-slots rotate together), click a placed item to select it (then Detach),
and watch each weapon's effective damage and power-per-shot change as supports cover it.

## Tests

Headless, same `tests/*_check.gd` pattern as the rest of the spike:

```
godot --headless --path godot_director_spike -s res://tests/build_resolver_check.gd
godot --headless --path godot_director_spike -s res://tests/build_grid_check.gd
godot --headless --path godot_director_spike -s res://tests/build_mounts_check.gd
godot --headless --path godot_director_spike -s res://tests/build_screen_check.gd
```

`build_resolver_check` covers the worked PoE examples (single more; stacked increased +
more; flat added; no-coverage base case) and determinism. `build_grid_check` covers
in-grid / no-overlap validity and the rotation invariant (shape AND buff-slots rotate
together). `build_mounts_check` covers the cascade (preferred mount; fallback when a
preferred is taken; non-weapons ignored; overflow past nine hardpoints). `build_screen_check`
is a smoke + wiring test that drives the whole screen through the same methods the buttons
call. `tests/build_screen_shot.gd` is a windowed runner that saves `tmp/build_screen.png`
for visual review (run without `--headless`).

Headless can't exercise `_draw`, so the screenshot runner is the visual gate.

## What's deferred (next agents)

- The M0 fight, which consumes `BuildResolver.resolve()` and `BuildMounts.assign()` output
  unchanged — the build you see is the build that fights.
- Polish on the build-pose mech: it reuses the block-out boxes and root-attached hardpoints
  (so mounted weapons don't ride the arms). A rigged/posed display and per-mount orientation
  tuning are cosmetic follow-ups.
- The real support catalogue values (M2 content), to be seeded from the owner's PoE 2
  reference — adapting mechanics, not names or lore.
