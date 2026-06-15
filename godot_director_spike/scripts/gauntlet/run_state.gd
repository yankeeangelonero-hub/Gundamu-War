extends RefCounted
## RunState — the single source of truth for a gauntlet run.
##
## Held as a static var so scene changes don't lose it. A new run replaces the
## entire record. No persistence between runs (v0.1 scope).

const STARTING_GOLD    := 30
const STARTING_HEARTS  := 3
const WIN_ROUND        := 5        # winning round N ends the run with a victory
const WIN_GOLD_REWARD  := 6
const LOSS_GOLD_REWARD := 2

## Live state of the current run.
static var active  := false
static var seed    := 0            # per-run seed; never wall-clock (determinism)
static var gold    := 0
static var hearts  := 0
static var round   := 0            # 1-based; 0 = not started
static var pilot_id := ""          # which pilot was picked

## Start a fresh run. seed_in must come from the caller (e.g. hash of user action
## sequence) so runs are reproducible, never wall-clock seeded.
static func new_run(pilot: String, seed_in: int) -> void:
	active    = true
	seed      = seed_in
	gold      = STARTING_GOLD
	hearts    = STARTING_HEARTS
	round     = 1
	pilot_id  = pilot

static func apply_win() -> void:
	gold += WIN_GOLD_REWARD

static func apply_loss() -> void:
	hearts -= 1
	gold   += LOSS_GOLD_REWARD

static func run_won() -> bool:
	return round > WIN_ROUND

static func run_over() -> bool:
	return hearts <= 0 or run_won()

static func advance_round() -> void:
	round += 1

static func clear() -> void:
	active   = false
	gold     = 0
	hearts   = 0
	round    = 0
	pilot_id = ""
