# Handoff — M1 build-screen UI design (for Claude design)

This briefs the visual and interaction design of the M1 build screen so it can be designed in
Claude design and brought back for implementation. The mechanics and data are already fixed in
docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md — this handoff is
about the look and the interaction, not the rules. The end product is the build editor for
Kitbash Mecha v0.1 (a Godot game); design here means mockups and a visual/interaction language,
which then gets implemented as a Godot Control UI, not shipped web code.

## What the screen is for

The player assembles a mech by placing shaped items into a small grid, reads how the build's
power economy and per-weapon numbers respond, and sees the result dressed onto a 3D mech. It is
the same machine they will later watch fight, so the build screen and the battlefield share one
mech. There is no shop and no fight in M1 — items come from a developer palette, and the payoff
is reading the numbers and seeing the guns appear on the mech.

## The zones the layout needs

- The grid: a 5×4 cell surface where items live. Items are polyomino shapes that occupy cells,
  can be rotated, and snap to the grid. Placement needs clear valid/invalid feedback (a shape
  over an occupied or out-of-bounds cell reads as rejected).
- The palette: the source of items to place (a developer inventory in M1; it becomes the shop
  in M3, so leave room for that to grow but do not design the shop now).
- Per-item numbers: each placed item shows its stats in place. Weapons show effective damage and
  power-per-shot, and these change live as supports come to cover them. Supports show their
  modifiers and their power-cost multiplier. Reactors show pool and regen.
- Build totals: the whole build's total power pool and total regen, somewhere persistent.
- The 3D mech preview: a viewport showing the shared mech with the slotted weapons mounted
  (static pose in M1). It updates as the build changes.

## The hard problem to solve

Adjacency legibility. A support buffs only the weapons sitting in its authored buff-slots, and
buffs stack (more covering supports means more damage but exponentially more power cost). The
screen has to make this spatial relationship readable: which cells a support buffs, which
weapons are currently covered, and that a weapon's numbers jumped because of the supports around
it. If the player cannot see at a glance why a weapon is strong or starved, the whole placement
craft is invisible. This is the central design challenge — treat the grid not just as a packing
surface but as a readout of who-buffs-whom.

## Direction and constraints

The mech look is realistic PBR (decided), so the 3D preview should read as a real machine, not a
cel/toon style. The UI tone should feel like an engineering bench — functional, legible,
mecha-flavoured. The grid, the buff-slot visual language, the per-item readouts, and the
interaction states (placing, valid/invalid, rotating, a buffed weapon highlighting its
supporters) are the things worth mocking up. Design for a desktop-first layout that can also
work on mobile later (Steam-first, mobile-compatible).

## What not to design yet

The shop and gauntlet (M3), bag-expansion containers and recipes (M2), behaviour transforms and
their fight visuals (M2), and armor/defense (M2). M1 supports carry only value modifiers, so the
buff readout is numbers changing, not behaviour changing.

## Handback

When the UI design is done, bring it back here. The next step is a single implementation plan
that combines this mechanics design with the UI design, then the build. Nothing is implemented
until that plan is approved.
