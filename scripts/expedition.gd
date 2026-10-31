class_name Expedition
extends RefCounted
## Rules and progression for one expedition, independent of rendering and input.

const SECTORS := [
	{"name": "THE QUIET BELT", "subtitle": "Every great expedition starts with a small haul.", "quota": 8, "seconds": 65.0, "rocks": 6, "speed": 0.85, "drones": 0, "storm": false, "color": Color("78f5dd")},
	{"name": "BROKEN RELAY", "subtitle": "Old sentries still guard these forgotten signals.", "quota": 10, "seconds": 65.0, "rocks": 8, "speed": 1.0, "drones": 2, "storm": false, "color": Color("8caeff")},
	{"name": "THE STORMFRONT", "subtitle": "One last haul. Watch the incoming meteor lanes.", "quota": 12, "seconds": 70.0, "rocks": 9, "speed": 1.1, "drones": 2, "storm": true, "color": Color("f3b77b")},
]
const UPGRADES := {
	"magnet": {"name": "TRACTOR ARRAY", "tag": "SALVAGE", "description": "Pull cores in from much farther away.\nKeep your pickup chain alive.", "stat": "+65 pickup range per level", "color": Color("f3c77b")},
	"dash": {"name": "TWIN CAPACITORS", "tag": "MOBILITY", "description": "Dash more often and fly faster.\nTurn tight escapes into a habit.", "stat": "−0.3s dash recharge · +8% speed", "color": Color("78f5dd")},
	"hull": {"name": "REINFORCED HULL", "tag": "SURVIVAL", "description": "An extra hull point and a repair.\nA little room for a rough landing.", "stat": "+1 maximum hull · +1 repair", "color": Color("ffaaa0")},
	"pulse": {"name": "ION RESONATOR", "tag": "CONTROL", "description": "Clear more space with your pulse.\nStun sentries and scatter debris.", "stat": "+65 pulse range · −1s recharge", "color": Color("a7a0ff")},
}
const CHAIN_WINDOW := 4.5

var sector_index := 0
var cargo := 0
var banked := 0
var score := 0
var chain := 0
var chain_left := 0.0
var peak_multiplier := 1
var total_banked := 0
var upgrades: Dictionary = {"magnet": 0, "dash": 0, "hull": 0, "pulse": 0}
var last_bonus := 0


func sector() -> Dictionary:
	return SECTORS[sector_index]


func collect() -> int:
	cargo += 1
	chain += 1
	chain_left = CHAIN_WINDOW
	var points := 100 * multiplier()
	peak_multiplier = maxi(peak_multiplier, multiplier())
	score += points
	return points


func multiplier() -> int:
	return mini(4, 1 + chain / 3)


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
	last_bonus = int(seconds) * 10 + hull * 150
	score += last_bonus
	return last_bonus


func upgrade_offers() -> Array[String]:
	# The second dock lets the player specialize their first choice or branch out.
	var order := ["magnet", "dash", "hull"]
	if sector_index > 0:
		var installed := "magnet"
		for id in order:
			if int(upgrades[id]) > 0:
				installed = id
		order = ["pulse", installed, "hull" if installed != "hull" else "dash"]
	var offers: Array[String] = []
	for id in order:
		if int(upgrades[id]) < 2 and offers.size() < 3:
			offers.append(id)
	return offers


func advance(upgrade: String) -> bool:
	if not quota_met() or sector_index >= SECTORS.size() - 1 or not upgrade in upgrade_offers():
		return false
	upgrades[upgrade] += 1
	sector_index += 1
	cargo = 0
	banked = 0
	break_chain()
	return true


func rank() -> String:
	if score >= 12500:
		return "S"
	if score >= 9500:
		return "A"
	if score >= 7000:
		return "B"
	return "C"
