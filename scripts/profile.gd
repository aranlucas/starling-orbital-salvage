class_name FlightProfile
extends RefCounted
## Backward-compatible records, Workshop ownership, and preferences.

const ITEMS := {
	"charts": {"name": "Deep Orbit Charts", "cost": 250, "effect": "Unlock the four-sector descent", "module": "Charts"},
	"kestrel": {"name": "Kestrel Frame", "cost": 300, "effect": "Fast interceptor · 2 hull", "module": "Kestrel"},
	"albatross": {"name": "Albatross Frame", "cost": 300, "effect": "Heavy hauler · 4 hull", "module": "Albatross"},
	"chain": {"name": "Chain Battery", "cost": 120, "effect": "+1.5s chain window / level", "module": "Fabricator"},
	"ballast": {"name": "Ballast Dampers", "cost": 120, "effect": "No cargo drag · faster banking", "module": "Fabricator"},
	"chrono": {"name": "Chronometer", "cost": 150, "effect": "+8s to later sector clocks / level", "module": "Fabricator"},
	"ram": {"name": "Ram Plating", "cost": 150, "effect": "Longer dash · shatters add time", "module": "Fabricator"},
	"wing": {"name": "Salvage Wing", "cost": 220, "effect": "An orbiting core collector / level", "module": "Fabricator"},
	"overdrive": {"name": "Overdrive Core", "cost": 220, "effect": "Chained pickups fire free pulses", "module": "Fabricator"},
	"plating": {"name": "Hull Plating", "cost": 250, "effect": "+1 permanent starting / max hull", "module": "Plating"},
	"broker1": {"name": "Scrap Broker I", "cost": 180, "effect": "+15% Scrap payout", "module": "Broker"},
	"broker2": {"name": "Scrap Broker II", "cost": 300, "effect": "+30% total Scrap payout", "module": "Broker"},
	"rig": {"name": "Launch Rig", "cost": 350, "effect": "Start with a random unlocked card", "module": "Rig"},
}
const FRAMES := {
	"starling": {"name": "STARLING", "hull": 3, "speed": 1.0, "recharge": 1.3, "magnet": 45.0, "radius": 13.0, "drag": 1.0},
	"kestrel": {"name": "KESTREL", "hull": 2, "speed": 1.15, "recharge": 1.0, "magnet": 45.0, "radius": 11.0, "drag": 1.0},
	"albatross": {"name": "ALBATROSS", "hull": 4, "speed": 0.88, "recharge": 1.5, "magnet": 80.0, "radius": 13.0, "drag": 0.5},
}
var path := "user://starling.cfg"
var best := 0
var victories := 0
var runs := 0
var muted := false
var reduced_motion := false
var view_3d := false
var invert_y := false
var scrap := 0
var owned: Array[String] = []
var route_records: Dictionary = {}
var selected_route := "survey"
var selected_frame := "starling"
var last_scrap := 0
var preview := false

func enable_preview() -> void:
	preview = true
	path = "user://starling-preview-%d.cfg" % OS.get_process_id()
	owned.assign(ITEMS.keys())
	scrap = 5000

func load_profile() -> void:
	if preview:
		return
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	best = maxi(0, int(file.get_value("mission", "best", 0)))
	victories = maxi(0, int(file.get_value("mission", "victories", 0)))
	runs = maxi(victories, int(file.get_value("mission", "runs", 0)))
	muted = bool(file.get_value("settings", "muted", false))
	reduced_motion = bool(file.get_value("settings", "reduced_motion", false))
	view_3d = bool(file.get_value("settings", "view_3d", false))
	invert_y = bool(file.get_value("settings", "invert_y", false))
	scrap = maxi(0, int(file.get_value("workshop", "scrap", 0)))
	owned.clear()
	for id in file.get_value("workshop", "owned", []):
		if ITEMS.has(id) and not id in owned:
			owned.append(id)
	# Every legacy victory was on Survey; honor the free Charts unlock too.
	if victories > 0 and not owns("charts"):
		owned.append("charts")
	route_records = file.get_value("mission", "routes", {})
	if not route_records.has("survey"):
		route_records.survey = {"best": best, "rank": "—", "runs": runs, "victories": victories}
	selected_route = str(file.get_value("settings", "route", "survey"))
	selected_frame = str(file.get_value("settings", "frame", "starling"))
	if selected_route != "deep" or not owns("charts"):
		selected_route = "survey"
	if not FRAMES.has(selected_frame) or (selected_frame != "starling" and not owns(selected_frame)):
		selected_frame = "starling"

func owns(id: String) -> bool:
	return id in owned

func can_buy(id: String) -> bool:
	return ITEMS.has(id) and not owns(id) and scrap >= int(ITEMS[id].cost) and (id != "broker2" or owns("broker1"))

func purchase(id: String) -> bool:
	if not can_buy(id):
		return false
	scrap -= int(ITEMS[id].cost)
	owned.append(id)
	save()
	return true

func unlocked_cards() -> Array[String]:
	var cards: Array[String] = ["magnet", "dash", "hull", "pulse"]
	for id in ["chain", "ballast", "chrono", "ram", "wing", "overdrive"]:
		if owns(id):
			cards.append(id)
	return cards

func broker_level() -> int:
	return 2 if owns("broker2") else (1 if owns("broker1") else 0)

func payout(banked: int, cleared: int, won: bool, route: String) -> int:
	return int(round((banked * 8 + cleared * 40 + (150 if won else 0)) * (1.25 if route == "deep" else 1.0) * (1.0 + 0.15 * broker_level())))

func next_item() -> String:
	var cheapest := ""
	for id in ITEMS:
		if not owns(id) and (id != "broker2" or owns("broker1")) and (cheapest == "" or ITEMS[id].cost < ITEMS[cheapest].cost):
			cheapest = id
	return cheapest

func record_run(score: int, won: bool, route: String = "survey", banked: int = 0, cleared: int = 0, rank: String = "C") -> void:
	best = maxi(best, score)
	runs += 1
	if won:
		victories += 1
		if route == "survey" and not owns("charts"):
			owned.append("charts")
	var record: Dictionary = route_records.get(route, {"best": 0, "rank": "—", "runs": 0, "victories": 0})
	if score >= int(record.best):
		record.best = score
		record.rank = rank
	record.runs += 1
	record.victories += 1 if won else 0
	route_records[route] = record
	last_scrap = payout(banked, cleared, won, route)
	scrap += last_scrap
	save()

func save() -> void:
	var file := ConfigFile.new()
	for key in ["best", "victories", "runs"]:
		file.set_value("mission", key, get(key))
	file.set_value("mission", "routes", route_records)
	for key in ["muted", "reduced_motion", "view_3d", "invert_y"]:
		file.set_value("settings", key, get(key))
	file.set_value("settings", "route", selected_route)
	file.set_value("settings", "frame", selected_frame)
	file.set_value("workshop", "scrap", scrap)
	file.set_value("workshop", "owned", owned)
	var error := file.save(path)
	if error != OK:
		push_warning("Could not save the flight profile: %s" % error_string(error))
