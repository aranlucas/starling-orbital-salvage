class_name Expedition
extends RefCounted
## Rules and progression for one expedition, independent of rendering and input.

const SECTORS := [
	{"name": "THE QUIET BELT", "subtitle": "Every great expedition starts with a small haul.", "quota": 8, "seconds": 65.0, "rocks": 6, "speed": 0.85, "drones": 0, "storm": false, "color": Color("78f5dd")},
	{"name": "BROKEN RELAY", "subtitle": "Old sentries still guard these forgotten signals.", "quota": 10, "seconds": 65.0, "rocks": 8, "speed": 1.0, "drones": 2, "storm": false, "color": Color("8caeff")},
	{"name": "THE STORMFRONT", "subtitle": "One last haul. Watch the incoming meteor lanes.", "quota": 12, "seconds": 70.0, "rocks": 9, "speed": 1.1, "drones": 2, "storm": true, "color": Color("f3b77b")},
]
const DEEP_SECTORS := [
	{"name": "THE SHELF", "subtitle": "At the lip of a deeper orbit.", "quota": 9, "seconds": 65.0, "rocks": 7, "speed": 0.85, "drones": 1, "storm": false, "color": Color("78f5dd")},
	{"name": "FOUNDRY SPIRES", "subtitle": "Slide around the silent refineries.", "quota": 10, "seconds": 70.0, "rocks": 6, "speed": 1.0, "drones": 2, "storm": false, "color": Color("ffb878")},
	{"name": "THE WELL", "subtitle": "Pulse to reverse the pull.", "quota": 11, "seconds": 70.0, "rocks": 7, "speed": 1.0, "drones": 1, "storm": true, "color": Color("b1a0ff")},
	{"name": "THE LEVIATHAN", "subtitle": "Crack the vents. Bring the light home.", "quota": 12, "seconds": 80.0, "rocks": 4, "speed": 0.85, "drones": 0, "storm": false, "color": Color("ffaaa0")},
]
const UPGRADES := {
	"magnet": {"name": "TRACTOR ARRAY", "tag": "SALVAGE", "description": "Pull cores in from much farther away.\nKeep your pickup chain alive.", "stat": "+65 pickup range per level", "color": Color("f3c77b")},
	"dash": {"name": "TWIN CAPACITORS", "tag": "MOBILITY", "description": "Dash more often and fly faster.\nTurn tight escapes into a habit.", "stat": "−0.3s dash recharge · +8% speed", "color": Color("78f5dd")},
	"hull": {"name": "REINFORCED HULL", "tag": "SURVIVAL", "description": "An extra hull point and a repair.\nA little room for a rough landing.", "stat": "+1 maximum hull · +1 repair", "color": Color("ffaaa0")},
	"pulse": {"name": "ION RESONATOR", "tag": "CONTROL", "description": "Clear more space with your pulse.\nStun sentries and scatter debris.", "stat": "+65 pulse range · −1s recharge", "color": Color("a7a0ff")},
	"chain": {"name": "CHAIN BATTERY", "tag": "COMBO", "description": "Keep your pickup chain alive.\nLevel 2 unlocks the x5 multiplier.", "stat": "+1.5s chain window per level", "color": Color("f3c77b")},
	"ballast": {"name": "BALLAST DAMPERS", "tag": "HAULING", "description": "Carry a full hold at full speed.\nUnload faster at every dock.", "stat": "No cargo drag · −0.2s banking / level", "color": Color("78d8c6")},
	"chrono": {"name": "CHRONOMETER", "tag": "TIME", "description": "More time for every later sector.\nMake room for one more haul.", "stat": "+8s sector clock per level", "color": Color("8caeff")},
	"ram": {"name": "RAM PLATING", "tag": "ASSAULT", "description": "Stay protected through longer dashes.\nDash-shatters extend the clock.", "stat": "+0.1s dash · +1.5s / shatter / level", "color": Color("ffaaa0")},
	"wing": {"name": "SALVAGE WING", "tag": "ESCORT", "description": "A companion collects nearby cores.\nLevel 2 brings a second wing.", "stat": "+1 orbiting salvage drone per level", "color": Color("78f5dd")},
	"overdrive": {"name": "OVERDRIVE CORE", "tag": "CONTROL", "description": "Linked pickups fire a free ion pulse.\nEvery sixth core; fourth at level 2.", "stat": "Free pulses at chain 6 / 4", "color": Color("a7a0ff")},
}
const CHAIN_WINDOW := 4.5

var route := "survey"
var frame := "starling"
var plating := false
var rng := RandomNumberGenerator.new()
var unlocked: Array[String] = ["magnet", "dash", "hull", "pulse"]
var cached_offers: Array[String] = []
var sectors_cleared := 0
var sector_index := 0
var cargo := 0
var banked := 0
var score := 0
var chain := 0
var chain_left := 0.0
var peak_multiplier := 1
var total_banked := 0
var upgrades: Dictionary = {"magnet": 0, "dash": 0, "hull": 0, "pulse": 0, "chain": 0, "ballast": 0, "chrono": 0, "ram": 0, "wing": 0, "overdrive": 0}
var last_bonus := 0


func sector() -> Dictionary:
	return sectors()[sector_index]


func sectors() -> Array:
	return DEEP_SECTORS if route == "deep" else SECTORS


func configure(profile: FlightProfile, seed_value: int) -> void:
	route = profile.selected_route
	frame = profile.selected_frame
	plating = profile.owns("plating")
	unlocked = profile.unlocked_cards()
	rng.seed = seed_value
	if profile.owns("rig"):
		upgrades[unlocked[rng.randi_range(0, unlocked.size() - 1)]] = 1


func chain_window() -> float:
	return CHAIN_WINDOW + 1.5 * int(upgrades.chain)


func free_pulse_due() -> bool:
	return int(upgrades.overdrive) > 0 and chain % (4 if int(upgrades.overdrive) == 2 else 6) == 0


func bank_seconds() -> float:
	return 0.7 - 0.2 * int(upgrades.ballast)


func sector_seconds() -> float:
	return float(sector().seconds) + 8 * int(upgrades.chrono)


func collect() -> int:
	cargo += 1
	chain += 1
	chain_left = chain_window()
	var points := 100 * multiplier()
	peak_multiplier = maxi(peak_multiplier, multiplier())
	score += points
	return points


func multiplier() -> int:
	return mini(5 if int(upgrades.chain) == 2 else 4, 1 + chain / 3)


func tick(delta: float) -> void:
	chain_left = maxf(0, chain_left - delta)
	if chain_left <= 0:
		chain = 0


func break_chain() -> void:
	chain = 0
	chain_left = 0


func bank_cargo() -> int:
	var count := cargo
	banked += count
	total_banked += count
	cargo = 0
	score += count * 50
	return count


func quota_met() -> bool:
	return banked >= int(sector().quota)


func complete_sector(seconds: float, hull: int) -> int:
	sectors_cleared += 1
	last_bonus = int(seconds) * 10 + hull * 150
	score += last_bonus
	return last_bonus


func upgrade_offers() -> Array[String]:
	if not cached_offers.is_empty():
		return cached_offers.duplicate()
	var pool: Array[String] = []
	var installed: Array[String] = []
	for id in unlocked:
		if int(upgrades[id]) < 2:
			pool.append(id)
			if int(upgrades[id]) > 0:
				installed.append(id)
	if not installed.is_empty():
		var id := installed[rng.randi_range(0, installed.size() - 1)]
		cached_offers.append(id)
		pool.erase(id)
	while cached_offers.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		cached_offers.append(pool[index])
		pool.remove_at(index)
	# Shuffle offers with the same expedition RNG (never the global RNG).
	for i in range(cached_offers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value := cached_offers[i]
		cached_offers[i] = cached_offers[j]
		cached_offers[j] = value
	return cached_offers.duplicate()


func advance(upgrade: String) -> bool:
	if not quota_met() or sector_index >= sectors().size() - 1 or not upgrade in upgrade_offers():
		return false
	upgrades[upgrade] += 1
	cached_offers.clear()
	sector_index += 1
	cargo = 0
	banked = 0
	break_chain()
	return true


func rank() -> String:
	if score >= (18000 if route == "deep" else 12500):
		return "S"
	if score >= (14000 if route == "deep" else 9500):
		return "A"
	if score >= (10000 if route == "deep" else 7000):
		return "B"
	return "C"
