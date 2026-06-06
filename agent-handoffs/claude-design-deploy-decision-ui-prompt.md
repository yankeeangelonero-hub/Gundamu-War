# Handoff — Deploy-Decision Test UI (design pass)

This hands a UI design task to a Claude design session. The goal is to design the interface
for the next test version of Kitbash Mecha — the deploy decision — so the owner can feel and
tune the experience and draft a basic UI from it before any build work begins. This is a
design pass, not implementation. No game logic, no engine code; what comes back is a set of
connected screens the owner can look at, react to, and use as the basis for a rough UI.

This narrows the earlier broad experience-mockup handoff
(claude-frontend-design-experience-mockups-prompt.md), which was written against an older
draft of the intent and covered the whole loop. For this task, design only the deploy-decision
test described below, in the current direction.

## Where the work stands

Kitbash Mecha is a mech build-fighter with a pilot bond. The player is the partner engineer:
they kitbash a mech from a tree of snap-together parts, fit it out for a single persistent
pilot, deploy that pilot into a war, and watch the deterministic fight resolve without
touching the controls. The current intent is recorded in docs/wishlist/wishlist.md (read it
first — it carries the feeling), with the loop drawn in docs/wishlist/flows/core-loop.mmd and
docs/wishlist/flows/homecoming.mmd. The build plan is in
docs/pilot-and-war-front-high-level-spec-and-work-map.md, where this test version is the slice
KM-DEPLOY.

Two things to internalize from the intent before designing. First, the loop is a positive
power fantasy: the player is building toward an unstoppable ace, the pilot's in-fight meter is
sync climbing toward a breakthrough rather than stress toward a breakdown, and there is no
permanent harm to the pilot — a hard fight's downside is a slower road, not injury. Second,
power is never free but it is potential the pilot grows into, expressed through the
pilot-machine fit: can this pilot, at her current ability, control this machine.

## What the test version is

The whole test is one decision: push her or protect her. The player fits a mech to a single
pilot, reads how well she handles it, and chooses between a safe fit for steady growth and
pushing the fit to chase a breakthrough at the cost of a harder fight. They then watch the
fight and see how the pilot grew. That single choice contains the entire pilot-fit and growth
thesis, which is why it is the test. Keep the scope here: one pilot, one opponent mech (a
seeded stand-in, not a real player yet), and no separate war-map or front-picking screen in
this test.

The screens to design, and what each must carry:

The workshop fit-out screen is where the player builds and fits. Much of this already exists
in the v0.4 Workshop prototype (see reference material) — the kitbash tree with typed-socket
snap-fit, the pilot present on screen with a reactive voice, and the mutual gating where
active parts mount inert until the pilot's ability chips are seated. Evolve that, do not
reinvent it. What this test adds to it is the fit forecast: somewhere readable, the screen
shows how well the pilot handles the current build — her capacity against the machine's
demand — and a projection of how sync will behave in the coming fight.

The deploy-decision panel is the new heart of this test. It presents the gamble plainly:
detune or fit her better for a safe, steady run, versus push the build as-is to chase the
breakthrough. It must show the upside of each path — projected sync gain, the odds of a
breakthrough, what she might learn — and the cost of pushing, which is a harder fight she
might lose, never harm to her. Confirming the choice is the deploy moment, the point where the
player hands her over and loses control, so give that act some weight.

The watched-fight view is where the player watches, unable to intervene. The center is the
player's mech fighting the opponent mech, rendered from the built parts, with one primary
attack at a time. The thing this view must get right is legibility: the sync meter climbing,
and the visible connection between the fit and how the fight is going. When the build
underperforms, the player has to be able to read why — the frame outpaces her, sync is slow to
climb — and never feel it as bad luck. This is the make-or-break screen of the whole test, so
design it to be watchable and to narrate cause and effect, not just to show numbers move.

The homecoming readout is where the outcome lands as growth. It shows what the pilot grew into
— experience, a higher sync ceiling, a breakthrough if the player pushed and it paid off — and
what was salvaged. The register is a relieved, proud welcome on a win and an "onward, a little
stronger" on a loss; it is not a flat results table, and it never shows injury or a frayed
bond.

The screens connect in a loop: workshop fit-out leads to the deploy-decision panel, confirming
leads to the watched fight, the fight resolving leads to homecoming, and homecoming returns to
the workshop. Design them connected so the owner can walk the cycle.

## What matters most

Legibility is the one thing that, done at eighty percent, sinks this. Because the player cannot
touch the fight, the cause-and-effect — build to fit to sync to outcome — has to be close to
narrated on screen, both in the pre-deploy forecast and during the fight. If a loss can read as
random, the design has failed even if every screen is pretty. Treat the fit forecast and the
in-fight sync visualization as the primary design problems, not decoration.

The pilot is a character the player is meant to bond with, so she is present on screen as a
person, not hidden in a stats menu. The mood is an intimate war story — a mechanic who cares
about someone — not a cold management dashboard. The deploy moment should feel weighty and the
homecoming should feel earned.

## Constraints

Generic original mecha only. No Gundam names, factions, lore, or trademarked silhouettes —
specifically no V-fin antenna, no split twin-eye visor, no RX-78 silhouette or trim. Original
identity uses a mono-eye, a single visor band, or a full-face sensor plate. There is no 3D.

The mockups are stack-agnostic: plain HTML and CSS are enough, no framework is assumed, and
the goal is a connected, clickable set the owner can walk and judge. The eventual game is built
in Godot, but the design pass does not need it. Keep the fidelity at "good enough to feel the
deploy gamble and the ascent and to draft a basic UI from," not pixel-final art.

Hold the scope fences so the test is not muddied: one pilot, not a stable; the bond grows from
battle outcomes, so no between-mission conversations or relationship activities to design; one
opponent mech, no grunts; no war-map or front-picking screen in this test; and nothing that
inflicts permanent harm on the pilot.

## Reference material

The art payload is in output/kitbash-approved-0e22-payload/: hard-surface part sprites
(rig_frame, rig_head, rig_saber, rig_rifle, and so on, each with an anchor image), flipbook FX
strips (fx_saber_blade, fx_beam_muzzle, fx_hit_spark, fx_thruster_flame, and others), and
kb-art-manifest.json, which is the shared source of truth for per-part canvas, pivot, depth,
mirror, and exposed child anchors. Use the manifest anchors when composing a mech so the design
matches how parts actually mount. Art direction lives in agent-handoffs/Kitbash - Art
Handoff.md.

One gap to resolve before or during this pass: the v0.4 Workshop wireframe and its data layer
(referred to in the mechanics handoff as Kitbash Workshop.html and kb-data.jsx) are not present
in this repository — only the art payload is. The build screen described above already exists in
those files, so the owner should provide them to the design session as the fit-out starting
point; otherwise the session works from the art payload and the descriptions here. The owner's
mechanics design is in agent-handoffs/Kitbash - Mechanics Handoff.md.

## What to produce and where it goes

Produce the connected screens for the deploy-decision test and place them in
docs/wishlist/mockups/. Once they exist, add short inline references to them from
docs/wishlist/wishlist.md where the relevant parts of the loop are discussed, so the design and
the intent stay linked. If the design surfaces a question the wishlist did not settle, raise it
with the owner rather than inventing an answer; this pass is meant to test the intent, not
quietly extend it.

These mockups are for the owner to feel the deploy gamble and the ascent and to draft a basic UI
from before build work begins. They are not final art and not a commitment to a layout; their job
is to let the owner walk workshop to deploy to watch to homecoming and confirm it feels like the
war story in the wishlist. When the owner has drafted the basic UI from them, build planning for
KM-DEPLOY resumes.
