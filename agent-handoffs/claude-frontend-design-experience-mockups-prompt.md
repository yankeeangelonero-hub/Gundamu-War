# Handoff — Experience Mockups for the Pilot + War-Front Loop

Superseded for near-term use (2026-06-06). This broad, whole-loop handoff was written
against an earlier draft of the intent. For the next test version, use the focused
claude-design-deploy-decision-ui-prompt.md instead, which covers the deploy-decision test in
the current direction (positive valence, single pilot, no theatre yet). Keep this file for
the eventual full-loop design pass.

This hands off a design-exploration task to a frontend-design session. The goal is to
produce explorable UI mockups of the new core loop so the owner can feel and fine-tune
the experience before any of it is committed to a build. This is not an implementation
task. Nothing in the real prototype should change, and no game logic should be written.
What comes back is a set of connected screens the owner can click through and react to.

## Where the work stands

The project pivoted to Kitbash Mecha, a browser autobattler where the player kitbashes
a humanoid mech from a tree of snap-together parts and watches the exact machine fight
a deterministic duel. That duel core already exists as a working v0.3 prototype under
prototype/ — it has the blueprint build UI, the combat rig, a shop, and a salvage draft.
Open prototype/index.html to see the current look; it is the visual starting point for
two of the screens below, not a constraint on the rest.

On top of that working duel, the owner has settled a larger experience: the player is a
partner engineer who fits out a mech for a single persistent pilot they bond with, sends
that pilot into a living war, watches the fight unable to intervene, and welcomes home a
pilot changed by the outcome. The full intent is written in docs/wishlist/wishlist.md,
with the loop drawn in docs/wishlist/flows/core-loop.mmd and the consequence branch in
docs/wishlist/flows/homecoming.mmd. The screen-by-screen brief you are building against
is docs/wishlist/mockup-brief.md. Read the wishlist first for the feeling, then the
mockup brief for what each screen must carry; this handoff does not repeat their content.

The build plan exists but is deliberately parked. The decomposition in
docs/pilot-and-war-front-high-level-spec-and-work-map.md lays out how this would be
built, and it is on hold precisely so the owner can test the experience in mockups first
and let it change before committing. Treat that document as background, not as something
to implement.

## What these mockups are for

The owner wants to fine-tune the experience, so the mockups need to be good enough to
walk the loop and judge how it feels, not pixel-final art. The four screens are the
Workshop where the player fits out the mech and the pilot, the Theatre where they read
the drifting war and choose where to deploy, the Duel-watch where they watch their mech
fight with no controls, and the Homecoming where the outcome lands on the pilot and the
salvage comes back. The mockup brief describes what each must contain. The most
important thing to get across is the emotional arc: building for someone you care about,
the weight of handing them over at deployment, the helplessness of watching, and the
relief or the wound of the homecoming. If a reviewer clicks through these four screens
and feels that arc, the mockups have done their job.

The two screens that already have a visual reference are the Workshop, which extends the
existing blueprint build UI, and the Duel-watch, which wraps the existing combat rig.
Reuse and evolve that look rather than inventing a new one for them, so the mockups read
as the same product the prototype is. The Theatre and the Homecoming are new screens
with no existing reference; the brief describes their intent and they are where the most
design exploration is wanted. The Theatre is the hardest and the most valuable to get
right, because it has to make a war feel alive and ongoing around the player without any
backend behind it, and the owner has said it is the key highlight of the concept.

## What matters while you work

Keep it tech-light. Plain HTML and CSS are enough; no framework is assumed and none is
needed for a clickable set. The screens should connect the way the loop does — the
Workshop leads to the Theatre, deploying leads to the Duel-watch, the fight resolving
leads to Homecoming, and Homecoming returns to the Workshop — so the owner can actually
walk the cycle. Static is fine where motion is not the point; the Duel-watch can suggest
the fight rather than fully animate it.

A few hard constraints from the project carry into the mockups. There is no licensed
Gundam IP anywhere — no real names, factions, or lore — and a couple of mechanics in the
wishlist use placeholder genre terms that must be renamed generically if they surface in
the UI, in particular the remote-drone weapon and its pilot attunement ability. There is
no 3D. And the experience should read as an intimate war story, a mechanic who cares
about a person, not a cold management dashboard, so the pilot should be present on screen
as a character rather than hidden in a stats menu.

Some things in the wishlist are deliberately out of these mockups because they are out
of near-term scope: there is one pilot, not a stable of several; the bond grows only from
battle outcomes, so there are no between-mission conversations or relationship activities
to design yet; there are no grunts in the field, only mechs; and the live two-faction war
is a far-future north star, so the Theatre is a local, drifting backdrop rather than a
real faction conflict. Designing those in now would mislead the test.

## What to produce and where it goes

Produce the four connected screens as mockups and place them in docs/wishlist/mockups/,
which currently holds only a placeholder. Once they exist, add short inline references to
them from docs/wishlist/wishlist.md where each screen is discussed, the way the wishlist
already points at its flows and brief, so the mockups and the intent stay linked. If
along the way the design surfaces a question about what the experience should be —
something the wishlist did not settle — raise it with the owner rather than inventing an
answer, because the wishlist is the record of intent and this task is meant to test it,
not to quietly extend it.

When the mockups are back and the owner has clicked through them, the next step is the
owner's: either revise the wishlist where the test changed their mind, or unpark the
decomposition and pick the first build slice. That decision waits until after the
experience has been felt.
