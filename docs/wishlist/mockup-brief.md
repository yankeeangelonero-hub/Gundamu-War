# Kitbash Mecha — Mockup Brief

This brief is for whoever produces the mockups next, whether that is a
frontend-design session or a human designer. It says which screens the wishlist
asks for and what each one needs to carry. It does not specify the visual design —
padding, components, palette, and type are the producer's call. It describes what
each screen must accomplish and how the screens connect, so the result can be a
connected set the user can walk through.

The mood the experience is reaching for, stated once here so every screen inherits
it: this is an intimate war story, not a spreadsheet. The player is a mechanic who
cares about a person. The interface should make the workshop feel hands-on and the
deployment feel weighty, and it should let the duel and the surrounding war be felt
at the same time. It should not feel like a cold management dashboard, and it should
not bury the pilot — the pilot is a character the player is meant to bond with, so
the pilot is present on screen, not hidden in a stats menu.

No technology anchor constrains the mockups beyond the project's own: this is a
browser experience, plain HTML and CSS are enough for the mockups, and no framework
is assumed. The fidelity goal is a clickable or at least connected static set that
lets the user approve the flow and feel before any feature spec is written.

## Workshop

The screen where the player is the engineer. This is the home base and the screen
the loop keeps returning to.

The main body is the mech the player is building — a humanoid frame shown clearly
enough that the player can see what is mounted where, with the snap-together parts
visible as a structure they can edit. The player attaches and detaches parts here.
Somewhere persistent on the screen is the pilot — a portrait and presence, not a
line in a table — because this is the person the player is fitting the machine out
for, and the bond should be readable at a glance. The player also equips the pilot's
skills here, and the screen has to show when a skill cannot be equipped because the
part it needs is not installed, and when a part is inert because the pilot has not
unlocked the matching ability. That mutual gating is the heart of the screen, so the
relationship between a chosen skill and a required part must be legible, not buried.

From the Workshop the player moves to the Theatre to deploy, when the pilot is fit to
fly. If the pilot is benched, the Workshop makes that state clear and the player can
keep tuning while they wait.

## Theatre

The screen where the player reads the living war and chooses where to send the pilot.

This screen has to do the hardest conceptual work: convey a war that is going on
whether or not the player is in it. It shows the front or fronts the player can
deploy to and gives a sense that the war is drifting — that fighting is happening
beyond the player's own machine. It does not need to be a literal animated battlefield
in the first mockup, but it should communicate that the player is picking a spot in
something larger and alive, not selecting a level from a menu. The player's choice of
where to deploy is made here, and confirming it is the deploy moment — the handing-over
that the experience treats as a point of no return, so the screen should give that
choice some weight rather than making it a casual click.

From the Theatre, confirming a deployment leads to the Duel watch screen.

## Duel watch

The screen where the player watches, unable to intervene.

The center of this screen is the player's mech fighting an enemy mech — the actual
machine the player built, rendered as it fights. Around or alongside it, the player
should be able to feel the larger war continuing, so the macro war and the personal
duel are both present at once rather than on separate screens. The screen carries the
tension of the whole experience: the player cares about both the build holding up and
the pilot surviving, and has no controls to change either. There is nothing for the
player to click during the fight except, at most, to control pacing or skip; the
screen's job is to be watchable and legible, not interactive.

When the fight resolves, the player moves to Homecoming.

## Homecoming / Debrief

The screen where the outcome lands on the pilot and the build.

This screen shows what changed. It shows the pilot's new state — experience gained
and any level or new skill on a win, injury or fatigue on a survived loss — and it
shows the bond moving in response to what happened. It shows what was salvaged from
the enemies that were beaten, presented as material the player will take back into the
Workshop. The emotional register matters here: a win should feel like a relieved
welcome-home and a loss should feel like tending to someone who got hurt in a machine
you built, so this screen is not a flat results table. From Homecoming the player
returns to the Workshop, carrying a changed pilot and new parts, and the loop begins
again.

## What these mockups are for

These mockups are for the user to approve the flow and the feel of the core loop
before any feature spec is written. They will likely become the visual reference that
the first feature spec points back to. They are not final art and not a commitment to
any particular layout; their job is to let the user walk the loop — workshop, deploy,
watch, homecoming — and confirm that it feels like the war story described in the
wishlist. The flows these screens implement are in flows/core-loop.mmd and
flows/homecoming.mmd.
