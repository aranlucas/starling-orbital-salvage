extends SceneTree

var failures := 0
var path := "user://starling-profile-audit-%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func _run() -> void:
	for damaged in [42, [], "damaged", null]:
		var file := ConfigFile.new()
		file.set_value("mission", "best", 1234)
		file.set_value("mission", "runs", 3)
		file.set_value("mission", "victories", 1)
		file.set_value("mission", "routes", damaged)
		file.set_value("workshop", "owned", damaged)
		_check(file.save(path) == OK, "Fixture written")
		var profile := FlightProfile.new()
		profile.path = path
		profile.load_profile()
		_check(profile.best == 1234 and profile.route_records.survey.best == 1234, "Malformed containers preserve legacy best")
		_check(profile.owns("charts") and profile.route_records.survey.runs == 3, "Legacy wins still unlock Charts")
		profile.record_run(1500, false, "deep", 2, 0, "C")
		var reloaded := FlightProfile.new()
		reloaded.path = path
		reloaded.load_profile()
		_check(reloaded.route_records.deep.runs == 1 and reloaded.scrap == 20, "Recovered profile pays and reloads")
	var nested := ConfigFile.new()
	nested.set_value("mission", "best", 500)
	nested.set_value("mission", "routes", {"survey": {"best": 750}, "deep": {"best": [], "runs": "broken", "victories": -4, "rank": {}}})
	nested.set_value("workshop", "owned", ["kestrel", "kestrel", "unknown", 42])
	_check(nested.save(path) == OK, "Nested fixture written")
	var profile := FlightProfile.new()
	profile.path = path
	profile.load_profile()
	_check(profile.route_records.survey.best == 750 and profile.route_records.survey.runs == 0, "Partial records preserve valid fields and fill missing ones")
	_check(profile.route_records.deep == {"best": 0, "rank": "—", "runs": 0, "victories": 0}, "Invalid nested fields recover safely")
	_check(profile.owned == ["kestrel"], "Ownership filters duplicates, unknown IDs and wrong types")
	profile.record_run(800, true, "survey", 30, 3, "B")
	_check(profile.route_records.survey.victories == 1 and profile.route_records.survey.rank == "B", "Partial record supports a later victory")
	var scalar := ConfigFile.new()
	for key in ["best", "runs", "victories"]:
		scalar.set_value("mission", key, [])
	scalar.set_value("workshop", "scrap", {})
	_check(scalar.save(path) == OK, "Scalar fixture written")
	profile = FlightProfile.new()
	profile.path = path
	profile.load_profile()
	_check(profile.best == 0 and profile.runs == 0 and profile.scrap == 0, "Malformed numeric values use defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PROFILE AUDIT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
