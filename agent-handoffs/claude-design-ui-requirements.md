# Claude Design Handoff — Mech Bags 0.1 UI Requirements

Date: 2026-06-04
Project root: `D:/Claude/Mech Bags`
Audience: Claude Design / UI concept agent

## Purpose

Generate basic UI design requirements and a lightweight visual direction for `Mech Bags` Version 0.1. This is not a production implementation task. Produce design requirements, layout guidance, and optionally a static HTML/design mock if requested later.

The design must support a simple browser prototype, not a complex mech simulator.

## Product summary

`Mech Bags` is a Backpack Battles-style async autobattler prototype. The twist is that the inventory is split into five mech body-part bags:

- Head
- Torso
- Back
- Left Arm
- Right Arm

Players buy shaped parts and body expansion upgrades, place items into any bag without anatomical restrictions, then watch 2D sprite battles resolve through a paused ATB animation queue.

Key owner correction: **no anatomy police**. If a player wants a beam rifle on the Head bag, the UI should allow it and make it amusing/readable.

## Design goals

1. **Faithful Backpack Battles readability** — shop, bag grids, item shapes, placement, and synergies should be immediately understandable.
2. **Five-bag mech fantasy** — the board should feel like upgrading parts of a mech, even though mechanically they are just five bags.
3. **Low-complexity prototype** — avoid heavy realism, dense stat screens, 3D assumptions, or simulation jargon.
4. **ATB playback clarity** — battle view must make the paused event sequence obvious: time advances, a weapon becomes ready, time pauses, animation plays, time resumes.
5. **Funny/cursed builds are valid** — visual language should embrace weird placements rather than implying invalid loadouts.

## Required screens / states

### 1. Build/shop screen

Must include:

- Five named bag grids: Head, Torso, Back, Left Arm, Right Arm.
- The five grids arranged like a loose mech silhouette if possible.
- Shop row with item cards and body expansion cards.
- Gold/round/wins/losses display.
- Buttons: Reroll, Lock optional, Battle/Ready.
- Side panel or tooltip area for selected item stats and active adjacency effects.
- Clear indication that items can go in any bag.

Bag expansion cards should read like body upgrades, e.g.:

- `Head Expansion — add 1 cell to Head`
- `Right Arm Extension — add 1 cell to Right Arm`
- `Back Rack Upgrade — add 1 cell to Back`

The UI must show that upgrading Head affects only Head, not the whole board.

### 2. Item placement state

Must support/communicate:

- Shaped pieces with visible occupied cells.
- Rotation affordance.
- Valid vs invalid placement due only to geometry/overlap/bounds.
- No red/error treatment for “wrong body part.”
- Same-bag adjacency highlighting.

Suggested item examples for mock visuals:

- Beam Rifle — long 1x3 shape
- Machine Gun — long 1x2 or 1x3 shape
- Missile Pod — L-shape
- Battery — 1x2 block
- Sensor — 1x1 chip
- Armor Plate — 2x2 block
- Shield — 1x2 block
- Booster — 1x2 or angled 2-cell item

### 3. Battle playback screen

Must include:

- Player mech sprite/placeholder on left.
- Enemy mech sprite/placeholder on right.
- HP bars.
- Current event banner, e.g. `Head Beam Rifle fires!`
- Combat log.
- Optional ATB bars or compact weapon queue.
- Battle speed/skip affordance if space allows.

Critical animation rule to communicate:

> Time advances until a weapon is ready. Time pauses. That weapon's animation plays from the bag/body anchor. Damage/effects resolve. Time resumes.

Because items can be in any bag, animation anchors should come from the bag:

- Head item fires from head/camera area.
- Torso item fires from chest/core area.
- Back item fires over shoulder/backpack area.
- Left Arm item fires from left side.
- Right Arm item fires from right side.

Do not require visually accurate equipment mounting. Prototype readability beats realism.

### 4. Battle result/report state

Must include:

- Win/loss result.
- Short reason summary.
- Key events from the timeline.
- Button to continue to next shop round.

Example report copy:

- `Your Head Beam Rifle dealt the most damage.`
- `Enemy Shield blocked two Machine Gun bursts.`
- `Your Missile Pod missed twice because no Sensor bonus was active.`

Keep language playful and mechanical, not militarily serious.

## Visual direction

Target tone: toy-like tactical garage, readable, slightly chunky, 2D arcade prototype.

Avoid:

- Overly realistic Gundam UI.
- Dense cockpit HUD.
- Purple generic SaaS gradients.
- 3D/mech-sim seriousness.
- Anything that implies licensed Gundam assets.

Prefer:

- Chunky pixel/arcade or clean comic-industrial styling.
- Clear cell grids.
- Strong item color coding by tag.
- Mech silhouette board framing.
- Small sparks, muzzle flashes, hit flashes, damage numbers.
- Readable typography and large hit targets.

Possible palette direction:

- Dark graphite workshop background.
- Off-white grid cells.
- Safety yellow/orange action accents.
- Cyan/blue beam effects.
- Green sensor/economy items.
- Red/orange ballistic/explosive items.

## UX invariants

- The player must understand that each body part is a separate bag.
- The player must understand that item placement is unrestricted by body part.
- The player must see which bag will expand before buying/applying an expansion.
- The player must understand why a placement is invalid if it fails: overlap, out of bounds, or shape collision only.
- The battle viewer must never show multiple primary attack animations competing for attention in Version 0.1.
- The combat log should name the bag source for weird builds: `Head Beam Rifle`, `Back Sensor`, `Right Arm Reactor`.

## Deliverable requested from Claude Design

Write a UI requirements/design brief under:

`D:/Claude/Mech Bags/Research/UI Design Requirements.md`

Include:

1. Build/shop screen layout requirements.
2. Battle screen layout requirements.
3. Item/card visual language.
4. Bag expansion UI treatment.
5. ATB playback/animation readability rules.
6. Minimal sprite/effect requirements for prototype.
7. Accessibility/readability notes.
8. A small wireframe or ASCII/Markdown layout sketch is acceptable.

Optional if the design agent is asked to produce a mock later:

- Create a static HTML mock under `D:/Claude/Mech Bags/Research/Design Mockups/mech-bags-0-1-ui.html`.

Do not create production app code unless explicitly instructed later.
