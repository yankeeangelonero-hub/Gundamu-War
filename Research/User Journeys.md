---
project: mech-bags
artefact: research-index
doc_type: user-journeys
status: active
last_updated: 2026-06-05
---

# User Journeys — Mech Bags

This living journey document records the player-facing journeys the project should test. It is not a feature list. Each journey describes what a player is trying to accomplish, what success feels like, and what can break the experience.

---

## Current prototype journeys — Version 0.1

### Journey 1 — First-time player: “What is this game?”

**Goal:** Understand the core loop quickly and place the first mech item.

1. Player opens the prototype.
2. They see five named mech bags: Head, Torso, Back, Left Arm, Right Arm.
3. They buy a cheap shop item.
4. The item appears in hand and is selected.
5. They tap/click a valid grid cell.
6. The item appears on that body-part bag.
7. They press Battle.
8. They understand the win/loss result and rewards.

**Success moment:** “I get it — I buy parts, arrange them in body bags, then test the build.”

**Risks:** Placement feedback is unclear; mobile user cannot tell whether tap placement succeeded; result/reward copy does not explain that the run continues.

### Journey 2 — Experimenter: “Can I put weird weapons anywhere?”

**Goal:** Discover the project’s signature freedom: unrestricted body-part placement.

1. Player buys a weapon such as Beam Rifle or Missile Pod.
2. They try placing it in an unusual body part such as Head.
3. The game allows it if the shape fits.
4. The player realizes the system is spatial, not anatomically restrictive.
5. They experiment with strange but valid layouts.

**Success moment:** “Beam Rifle in Head is valid.”

**Risks:** Visuals or copy accidentally imply anatomy restrictions; invalid geometry failure is mistaken for a rule restriction.

### Journey 3 — Optimizer: “How do I make a stronger build?”

**Goal:** Learn adjacency, stats, and build synergies.

1. Player buys multiple items.
2. They inspect item info and notice adjacency rules.
3. They move or rotate items to activate same-bag synergies.
4. The board shows visible adjacency glow/bonus feedback.
5. The player compares battle performance and adjusts.

**Success moment:** “Arrangement matters, not only price.”

**Risks:** Active adjacency feedback is too subtle; stats are unreadable; player cannot distinguish potential synergies from active synergies.

### Journey 4 — Expansion planner: “Which body part should I grow?”

**Goal:** Use bag expansion as a strategic identity choice.

1. Player sees a named expansion card in the shop.
2. They buy it.
3. Only that body-part bag gains a row.
4. The change is visibly confirmed.
5. The player specializes that bag or rebalances across the mech.

**Success moment:** “My Head/Back/etc. is now my weapon/support platform.”

**Risks:** Expansion feedback is not obvious; expanded body part does not feel strategically different.

### Journey 5 — Short-run player: “Can I clear a run?”

**Goal:** Complete the prototype’s short buy/fight/advance loop.

1. Player starts with limited gold.
2. They buy, place, and battle.
3. They receive rewards after battle.
4. Their build persists between rounds.
5. They improve the build through shops and expansions.
6. They reach RUN CLEAR or RUN OVER.

**Success moment:** “I built a mech that survived the run.”

**Risks:** Post-battle continuation is unclear; reward and run-progress copy do not show what changed.

### Journey 6 — Mobile player: “Can I play this on my phone?”

**Goal:** Buy, place, rotate, move, and battle using touch only.

1. Player opens the prototype on a narrow/mobile browser.
2. They buy an item.
3. They tap a hand item to select it.
4. They tap a grid cell to place it.
5. They tap a placed item to select/edit it.
6. They use the Rotate button to rotate the placed item in place.
7. They tap another cell to move it.
8. Invalid moves or rotations keep the original placement and show feedback.
9. Battle and result screens remain readable.

**Success moment:** “I can play without a keyboard or desktop mouse.”

**Risks:** Shop/board scroll friction; selected/editing state unclear; silent invalid placement; hover-only preview logic breaks real tap/click paths.

---

## Next-version candidate journeys — Warfront + pilot + build-surface test

The next version should test whether the project remains a backpack-grid mech builder or shifts to a more direct gear/mech customisation surface. Both options should be evaluated against the same warfront and pilot journeys.

### Journey 7 — Warfront commander: “What changed on the front today?”

**Goal:** Return to a living campaign board and understand why the mission board changed.

1. Player opens the game after a war tick.
2. They see a compact warfront report: territory pressure, captured/lost areas, town status, and notable NPC/pilot events.
3. The mission board has changed because of that state.
4. The player understands what kinds of builds are useful today.
5. They choose a mission/front to prepare for.

**Success moment:** “The world moved while I was away, and now I know what the front needs.”

**Risks:** Warfront reads like random flavor rather than state; LLM report contradicts deterministic state; player cannot connect front changes to build decisions.

### Journey 8 — Mission adapter: “How should I change my mech for this operation?”

**Goal:** Adjust the build in response to mission conditions.

1. Player reads a mission brief: terrain, enemy pressure, recommended strengths, and pilot risk.
2. They inspect their current mech.
3. They modify equipment to match the mission.
4. The UI explains why the build is more or less suitable.
5. They deploy and later receive a report tying performance to those choices.

**Success moment:** “I changed the mech for this mission, and the report showed why it mattered.”

**Risks:** Mission modifiers feel arbitrary; the best build stays universal; report does not connect outcome to build choices.

### Journey 9 — Pilot caretaker: “Can I win without getting my pilot hurt?”

**Goal:** Weigh mission rewards against pilot injury/out-of-service risk.

1. Player selects a pilot.
2. They see pilot condition, specialty, risk tolerance, and current availability.
3. The mission shows readable pilot risk before deployment.
4. The player adjusts mech protection, safety gear, or mission choice.
5. After battle, the pilot may be unharmed, fatigued, wounded, out of service, missing, or rarely killed/retired.
6. The player receives a report and must decide whether to rest, redeploy, use a backup, or take a safer mission.

**Success moment:** “The pilot is a person inside the machine, so my build and deployment choices have stakes.”

**Risks:** Injury feels random/punitive; pilot becomes a flat stat bonus; players become afraid to experiment; recovery downtime blocks play rather than creating choices.

### Journey 10 — War hero: “Can my pilot/mech become known for something?”

**Goal:** Earn titles, reputation, and identity through specific warfront actions.

1. Player performs well in a mission or saves a threatened area.
2. The warfront report names the contribution.
3. The pilot/mech earns progress toward a title, medal, seasonal skin, or exclusive part.
4. The title is tied to a concrete deed, not only generic rating.
5. The player can remember why the title was earned.

**Success moment:** “This is not just Gold III; my pilot became the Defender of a specific place.”

**Risks:** Rewards feel cosmetic-only with no story; title eligibility is opaque; LLM invents honors not backed by simulator rules.

### Journey 11 — Build-surface comparison: “Grid builder or gear customisation?”

**Goal:** Test whether the player better understands and enjoys warfront adaptation through a backpack-grid surface or a gear/mech-customisation surface.

1. Player receives the same mission brief in two prototype surfaces:
   - body-part backpack grid;
   - gear/mech customisation.
2. They modify the mech in each surface.
3. They compare which surface better communicates capability, mission fit, and pilot risk.
4. They deploy or simulate both versions and read the outcome report.
5. The project records which surface made the decision clearer and more fun.

**Success moment:** “This surface makes me understand what my mech can do, why it suits the mission, and how it protects or risks my pilot.”

**Risks:** Gear customisation becomes generic; grid system feels like a Backpack Battles reskin; either surface hides pilot risk or mission suitability.

---

## Distilled essential-loop journey

A distillation pass (2026-06-05, `agent-handoffs/opus-essential-loop-distillation-report.md`) recommended proving the warfront/pilot direction as a smaller essential loop before building the warfront map or a second build surface. Xuanyue then corrected the framing in `Research/Research Documents/concept-handoff-2026-06-05-theatre-meta-feed-essential-loop.md`: the essential loop should not center authored mission conditions and pre-deploy risk tuning. He later narrowed the build surface in `Research/Research Documents/concept-handoff-2026-06-05-single-canvas-buyable-bags.md`: Version 0.2 should start from one big canvas with buyable small bags/pieces, closer to Backpack Battles, rather than five body-part bags.

Journeys 7 (warfront map), 10 (war hero / titles), and 11 (grid-vs-gear comparison) remain deferred beyond the essential loop. Journey 12 is now the primary candidate V0.2 journey.

### Journey 12 — Essential loop: “Buy bag space, deploy, keep fighting, retreat, improve”

**Goal:** Complete the smallest repeatable Version 0.2 loop where the player customizes one expandable canvas, buys small bag pieces, deploys into a fixed theatre pool, lets the suit fight repeatedly over real elapsed time, optionally spectates or leaves, retreats, gains loot and pilot XP/skills, modifies the build, and redeploys.

1. Player opens the workshop and sees one big build canvas plus their pilot.
2. They customize what they believe is the strongest build available by placing items on owned canvas cells.
3. They buy or earn a small bag piece/canvas expansion and attach it to increase usable space.
4. They place/rotate/move items on the expanded canvas.
5. They deploy the build to the war theatre.
6. The build enters an active battlefront loop against a pool of 10 other builds.
7. Each fight takes roughly 15–30 seconds rather than resolving instantly.
8. If the build wins, it enters a short 5-second resupply before the next fight.
9. If the build loses, it enters a 15-second delay/repair lockout before it can fight again.
10. The player can spectate a live/current fight if they want.
11. The player can leave spectate at any time while the theatre loop continues.
12. The player retreats back to the workshop when ready.
13. The retreat summary shows accumulated fights, loot drops, pilot XP/level progress, pilot condition, and skill acquisition/progress.
14. The player learns from the result, uses loot/bag space to modify the canvas/build, and deploys again.

**Success moment:** “I expanded my bag, sent my build to the front, pulled it back with loot and pilot growth, changed the canvas, and wanted to send it out again.”

**Risks:** The single canvas feels too generic without mech flavor; bag-piece buying is unclear; real-time pacing feels too slow or too passive; spectating feels mandatory instead of optional; retreat timing is unclear; downtime penalties feel like waiting rather than consequence; loot does not create a reason to modify the build; pilot XP feels like a generic grind; skill acquisition is not visible enough; deterministic results are not explainable; the pool of 10 enemy builds feels too small or too opaque.

### Journey 13 — Pilot career: “Can this pilot become better because of what they survived?”

**Goal:** Make the pilot feel like a persistent combatant with skill growth, not only a condition marker.

1. Player deploys a pilot with visible Level, XP, and one or two early skill tracks.
2. The mech fights theatre enemies.
3. The sortie report separates battle result, pilot condition, and pilot growth.
4. The pilot gains XP from sortie participation, survival, and strong performance.
5. The pilot gains skill-track progress from relevant patterns, such as surviving missile-heavy enemies or repeatedly using heavy-frame builds.
6. If the pilot levels up or progresses a skill, the report explains what changed.
7. The player adapts the mech with awareness of both theatre meta and the pilot's developing strengths.

**Success moment:** “My pilot is learning from this war, and that growth matters without replacing mech-building.”

**Risks:** Skills become flat invisible stat bonuses; progression makes one pilot/build obviously optimal; injury blocks progression too harshly; XP rewards only wins and discourages experimentation; skill UI becomes too deep for the essential-loop version.

---

## Next-version test flag

The immediate next-version journey is Journey 12 plus the pilot-career growth check in Journey 13. The next version should validate whether the one-canvas + buyable-bag-pieces → deploy → repeated timed fights → optional spectate/leave → retreat → loot + pilot XP/skill acquisition → modify → redeploy loop works before spending build time on a gear surface, full warfront map, titles, multiple pilots, or five-body-part variants.

Recommended evidence to collect:

- Is one big canvas with buyable bag pieces clearer than the five-body-part board?
- Can the player buy/attach bag space and understand why usable cells changed?
- Can the player deploy into a fixed pool of 10 enemy builds and understand that the suit will keep fighting until retreat?
- Does each 15–30 second fight feel active enough without requiring constant watching?
- Does optional spectating add flavor without becoming required?
- Is retreat a clear boundary between theatre/combat state and workshop/improvement state?
- Do victory resupply (5s) and loss delay/repair (15s) feel like meaningful consequences rather than dead waiting?
- Do loot drops create a concrete reason to modify the canvas/build before redeploying?
- Does the sortie report connect build performance, pilot condition, pilot XP/level, and skill acquisition/progress clearly?
- Do pilot skills feel like career identity rather than flat RPG stat bonuses?
- Does the player want to run a second sortie after the first retreat?
- Does the loop remain usable on mobile?

Journeys 7–11 remain deferred candidate journeys for later versions. The current draft-proposed `Project Version/Version 0.2/Version 0_2 Project Specifications.md` has been rewritten around this single-canvas real-time theatre loop and remains proposed pending Version 0.1 close.
