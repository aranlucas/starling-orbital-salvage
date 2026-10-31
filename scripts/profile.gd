class_name FlightProfile
extends RefCounted
## A local profile; a configurable path lets tests avoid the player's save.

var path := "user://starling.cfg"
var best := 0
var victories := 0
var runs := 0
var muted := false
var reduced_motion := false


func load_profile() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	best = maxi(0, int(file.get_value("mission", "best", 0)))
	victories = maxi(0, int(file.get_value("mission", "victories", 0)))
	runs = maxi(victories, int(file.get_value("mission", "runs", 0)))
	muted = bool(file.get_value("settings", "muted", false))
	reduced_motion = bool(file.get_value("settings", "reduced_motion", false))


func record_run(score: int, won: bool) -> void:
	best = maxi(best, score)
	runs += 1
	if won:
		victories += 1
	save()


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("mission", "best", best)
	file.set_value("mission", "victories", victories)
	file.set_value("mission", "runs", runs)
	file.set_value("settings", "muted", muted)
	file.set_value("settings", "reduced_motion", reduced_motion)
	var error := file.save(path)
	if error != OK:
		push_warning("Could not save the flight profile: %s" % error_string(error))
