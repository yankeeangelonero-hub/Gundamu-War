extends RefCounted
class_name TimeEmphasis
## The time-emphasis precedence arbiter (Phase 3 Slice 1, spec Open Q#3).
## One tool owns a contact beat — an escalation ladder by beat weight:
## bullet-time (kill cam) > hitstop (heavy hit) > impact-frame (minor hit).
## This file is the PURE decision; the effects (time freeze, screen flash) are
## applied by the caller (garnish/director) based on what this returns.

## Decide which tool owns a contact beat. Pure, no side effects.
## Returns "bullet" | "hitstop" | "impact" | "none".
static func decide(in_bullet_time: bool, damage: float, hitstop_threshold: float) -> String:
	if in_bullet_time:
		return "bullet"
	if damage > hitstop_threshold:
		return "hitstop"
	if damage > 0.0:
		return "impact"
	return "none"
