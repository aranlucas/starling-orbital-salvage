class_name ShipBuild
extends RefCounted

static func maximum_hull(upgrades: Dictionary, frame: String, plating: bool) -> int:
	return int(FlightProfile.FRAMES[frame].hull) + int(upgrades.get("hull", 0)) + int(plating)

static func stats(upgrades: Dictionary, frame: String, plating: bool) -> Dictionary:
	var base: Dictionary = FlightProfile.FRAMES[frame]
	return {
		"max_health": maximum_hull(upgrades, frame, plating),
		"speed_multiplier": float(base.speed) + 0.08 * int(upgrades.get("dash", 0)),
		"cooldown_max": maxf(0.25, float(base.recharge) - 0.3 * int(upgrades.get("dash", 0))),
		"pulse_cooldown_max": 7.0 - int(upgrades.get("pulse", 0)),
		"cargo_drag": 0.0 if int(upgrades.get("ballast", 0)) > 0 else float(base.drag),
	}
