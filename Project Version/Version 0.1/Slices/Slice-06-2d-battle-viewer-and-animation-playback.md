---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "06"
title: 2D battle viewer and paused animation playback
status: not-started
updated: 2026-06-04
depends_on: ["05"]
---

# Slice 06 — 2D battle viewer and paused animation playback

## Goal

Build the battle viewer that animates the event list produced by the ATB simulator. One attack animation plays at a time. Simulation time does not advance during an animation. HP bars and the combat log update after each event resolves.

## Deliverable

A battle viewer screen (or overlay) that:
- Shows two mech sprites/placeholders (player left, enemy right)
- Shows HP bars for each side
- Steps through the event list one event at a time, pausing display time during each animation
- Shows an event banner naming the bag source and item (e.g. "Head Beam Rifle fires!")
- Appends each resolved event to a combat log
- Shows a battle result screen when one side reaches 0 HP

## Acceptance checks

1. **The battle viewer renders two mech sprites and HP bars before the first event plays.** Initial HP bars reflect full health.
2. **Events play one at a time with a visible pause between each.** Display time visibly advances to the next event, pauses, the weapon animation plays, and only then does display time resume (BEH-004).
3. **The event banner names the bag source using the format `[Bag] [Item Name] fires!`** (e.g. "Head Beam Rifle fires!", "Back Missile Pod fires!") for every attack event (ARC-005).
4. **HP bars update to reflect resolved damage after each event.** The update occurs after the animation completes, not before or during.
5. **Multiple primary attack animations never play simultaneously.** Only one attack animation is active at any moment during normal playback (BEH-004).

## Notes

- Sprite art: placeholder coloured rectangles or simple SVG shapes are acceptable. Production sprites are out of scope.
- Animation anchors by bag: Head = top, Torso = centre, Back = over-shoulder, Left Arm = left, Right Arm = right. See `Research/flows/atb-battle-flow.md`.
- Speed/skip controls are optional in this slice. If out of scope, record as deferred in `Research/wishlist.md`.
- The viewer must not call back into the simulator during playback. It reads from the frozen event list only (ARC-001).
- After the last event, show a battle result screen with win/loss banner, a short reason summary, and key event highlights (BEH-005).
