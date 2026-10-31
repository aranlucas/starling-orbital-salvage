extends Control
## Title, pause, results, and upgrade choices between sectors.

signal hub_changed
signal purchased
signal roost_pressed
signal primary_pressed
signal upgrade_selected(id: String)
signal sound_toggled
signal motion_toggled
signal abandon_pressed

const UI := preload("res://scripts/ui_style.gd")
var hub_root: Control
var hub_section := "launch"
var workshop_index := 0
var workshop_buttons: Array[Button] = []
var artwork: TextureRect
var shade: ColorRect
var panel: Panel
var eyebrow: Label
var title: Label
var description: Label
var result: Label
var button: Button
var secondary: Button
var footer: Label
var upgrades_root: Control
var sound_button: Button
var motion_button: Button


func _ready() -> void:
	size = Vector2(1280, 800)
	artwork = TextureRect.new()
	artwork.texture = preload("res://assets/art/menu_backdrop.png")
	artwork.size = size
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(artwork)
	shade = ColorRect.new()
	shade.size = size
	add_child(shade)
	panel = Panel.new()
	panel.position = Vector2(74, 150)
	panel.size = Vector2(628, 500)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.065, 0.09, 0.95), 16, Color("34505a")))
	add_child(panel)
	eyebrow = UI.label(panel, "", Vector2(44, 32), 11, UI.CYAN)
	title = UI.label(panel, "", Vector2(42, 67), 43)
	description = UI.label(panel, "", Vector2(44, 200), 14, UI.MUTED)
	description.add_theme_constant_override("line_spacing", 7)
	result = UI.label(panel, "", Vector2(44, 290), 14, UI.GOLD)
	button = UI.button(panel, "LAUNCH EXPEDITION     →", Rect2(44, 337, 540, 56))
	button.pressed.connect(func() -> void: primary_pressed.emit())
	secondary = UI.button(panel, "END EXPEDITION", Rect2(44, 405, 540, 34), Color("788f9c"))
	secondary.pressed.connect(func() -> void: abandon_pressed.emit())
	footer = UI.label(panel, "", Vector2(44, 463), 10, UI.MUTED)
	hub_root = Control.new()
	panel.add_child(hub_root)
	upgrades_root = Control.new()
	add_child(upgrades_root)
	sound_button = UI.button(self, "M   SOUND ON", Rect2(76, 704, 180, 34), Color("93a8ad"))
	motion_button = UI.button(self, "F2   FULL EFFECTS", Rect2(274, 704, 225, 34), Color("93a8ad"))
	sound_button.pressed.connect(func() -> void: sound_toggled.emit())
	motion_button.pressed.connect(func() -> void: motion_toggled.emit())


func update_settings(profile: FlightProfile) -> void:
	sound_button.text = "M   SOUND OFF" if profile.muted else "M   SOUND ON"
	motion_button.text = "F2   REDUCED MOTION" if profile.reduced_motion else "F2   FULL EFFECTS"


func present(state: String, run: Expedition, profile: FlightProfile, reason: String = "") -> void:
	visible = state != "running"
	if not visible:
		return
	artwork.visible = false
	shade.color = Color(0.01, 0.025, 0.04, 0.0 if state == "menu" else 0.85)
	panel.visible = state != "upgrade"
	upgrades_root.visible = state == "upgrade"
	secondary.visible = state in ["paused", "won", "lost"]
	for connection in secondary.pressed.get_connections():
		secondary.pressed.disconnect(connection.callable)
	secondary.text = "END EXPEDITION" if state == "paused" else "H   RETURN TO THE ROOST"
	secondary.pressed.connect(func() -> void:
		if state == "paused":
			abandon_pressed.emit()
		else:
			roost_pressed.emit())
	hub_root.visible = state == "menu"
	description.visible = state != "menu"
	result.visible = state != "menu"
	panel.size = Vector2(628, 610 if state == "menu" else 500)
	panel.position = Vector2(54, 65) if state == "menu" else Vector2(326, 150)
	button.position.y = 510 if state == "menu" else 337
	footer.position.y = 580 if state == "menu" else 463
	if state == "menu":
		_build_hub(profile)
		return
	panel.position.x = 326
	if state == "upgrade":
		_build_upgrades(run)
		return
	match state:
		"paused":
			eyebrow.text = "F L I G H T   O N   H O L D"
			title.text = "Take a breath,\npilot."
			description.text = "Bank cargo by staying inside the safe dock for a moment.\nDash into rocks and sentries to shatter them for bonus points.\nYour ion pulse pushes debris, stuns sentries, and pulls in cores."
			result.text = "SECTOR %d / %d     /     SCORE %05d" % [run.sector_index + 1, run.sectors().size(), run.score]
			button.text = "RESUME EXPEDITION     →"
			footer.text = "ENTER, ESC OR P TO RESUME"
		"won":
			eyebrow.text = "E X P E D I T I O N   C O M P L E T E   /   R A N K  " + run.rank()
			title.text = "The lights stay on.\nWelcome home."
			description.text = "All %d cores home. Your ship made it through the storm.\nTry a different upgrade build or chase a longer pickup chain.\nThank you for flying Starling." % run.total_banked
			result.text = "SCORE %05d   /   BEST %05d   /   PEAK x%d" % [run.score, int(profile.route_records.get(run.route, {"best": 0}).best), run.peak_multiplier]
			button.text = "ANOTHER EXPEDITION     →"
			footer.text = "ENTER OR R TO PLAY AGAIN"
		"lost":
			eyebrow.text = "E X P E D I T I O N   E N D E D   /   S E C T O R  %d" % [run.sector_index + 1]
			title.text = "A rough orbit.\nA fresh start."
			description.text = reason + "\nKeep banking cargo and use your pulse when space gets tight.\nThe next expedition starts with a fresh ship."
			result.text = "SCORE %05d   /   BEST %05d   /   %d CORES BANKED" % [run.score, int(profile.route_records.get(run.route, {"best": 0}).best), run.total_banked]
			button.text = "TRY A NEW EXPEDITION     →"
			footer.text = "ENTER OR R TO RESTART"

	if state == "paused":
		var installed: Array[String] = []
		for id in run.upgrades:
			if int(run.upgrades[id]) > 0:
				installed.append("%s %d" % [Expedition.UPGRADES[id].name, run.upgrades[id]])
		if not installed.is_empty():
			description.text = "INSTALLED THIS RUN\n" + " · ".join(installed.slice(0, 2))
			if installed.size() > 2:
				description.text += "\n" + " · ".join(installed.slice(2))
	if state in ["won", "lost"]:
		var next := profile.next_item()
		var progress := "WORKSHOP COMPLETE"
		if next != "":
			var price := int(FlightProfile.ITEMS[next].cost)
			progress = "NEXT / %s: %d / %d Scrap%s" % [FlightProfile.ITEMS[next].name, mini(profile.scrap, price), price, " · READY" if profile.scrap >= price else ""]
		description.text = ("All %d cores home." % run.total_banked if state == "won" else reason) + "\n+%d SCRAP EARNED  ·  BALANCE %d\n%s" % [profile.last_scrap, profile.scrap, progress]
		footer.text = "ENTER / R  RESTART     ·     H  ROOST / WORKSHOP"


func _build_upgrades(run: Expedition) -> void:
	for child in upgrades_root.get_children():
		upgrades_root.remove_child(child)
		child.queue_free()
	UI.label(upgrades_root, "S E C T O R  %02d   C O M P L E T E" % [run.sector_index + 1], Vector2(80, 143), 12, UI.CYAN)
	UI.label(upgrades_root, "Make the next haul yours.", Vector2(78, 179), 39)
	UI.label(upgrades_root, "+%d landing bonus. Choose one free upgrade. Every jump repairs 1 hull point." % run.last_bonus, Vector2(80, 244), 15, UI.MUTED)
	var offers := run.upgrade_offers()
	for i in offers.size():
		var id := offers[i]
		var data: Dictionary = Expedition.UPGRADES[id]
		var card := Panel.new()
		card.position = Vector2(80 + i * 380, 306)
		card.size = Vector2(356, 310)
		card.add_theme_stylebox_override("panel", UI.box(Color("10202d"), 12, Color(data.color, 0.55)))
		upgrades_root.add_child(card)
		UI.label(card, "0%d   /   %s" % [i + 1, data.tag], Vector2(24, 24), 11, data.color)
		UI.label(card, data.name, Vector2(23, 70), 22)
		UI.label(card, data.description, Vector2(24, 118), 14, UI.MUTED)
		UI.label(card, data.stat, Vector2(24, 194), 12, data.color)
		var level := int(run.upgrades[id]) + 1
		var install := UI.button(card, "%d   INSTALL LEVEL %d     →" % [i + 1, level], Rect2(24, 247, 308, 42), data.color)
		install.pressed.connect(_select_upgrade.bind(id))
	UI.label(upgrades_root, "NEXT  /  " + run.sectors()[run.sector_index + 1].name, Vector2(80, 646), 12, UI.CYAN)
	UI.label(upgrades_root, "PRESS 1, 2 OR 3 TO INSTALL AND JUMP", Vector2(880, 646), 11, UI.MUTED)


func _select_upgrade(id: String) -> void:
	upgrade_selected.emit(id)


func _build_hub(profile: FlightProfile) -> void:
	for child in hub_root.get_children():
		hub_root.remove_child(child)
		child.queue_free()
	workshop_buttons.clear()
	eyebrow.text = "S T A R L I N G   /   D E E P   O R B I T"
	title.text = "The Roost"
	UI.label(hub_root, "%d  SCRAP" % profile.scrap, Vector2(435, 45), 17, UI.GOLD)
	for i in 3:
		var section: String = ["launch", "workshop", "records"][i]
		var tab := UI.button(hub_root, ["L  LAUNCH", "B  WORKSHOP", "T  RECORDS"][i], Rect2(44 + i * 181, 130, 172, 35), UI.CYAN if hub_section == section else UI.MUTED)
		tab.pressed.connect(func() -> void:
			hub_section = section
			hub_changed.emit())
	button.text = "ENTER   LAUNCH EXPEDITION     →"
	footer.text = "L / B / T  SECTION   ·   Q  ROUTE   ·   F  FRAME   ·   ↑ ↓ / ← →  SELECT"
	match hub_section:
		"launch":
			UI.label(hub_root, "FLIGHT PLAN  /  Q TO SWITCH", Vector2(44, 190), 11, UI.CYAN)
			var route_button := UI.button(hub_root, "SURVEY ROUTE" if profile.selected_route == "survey" else "DEEP ORBIT", Rect2(44, 216, 540, 44))
			route_button.pressed.connect(func() -> void: cycle_route(profile))
			UI.label(hub_root, "3 sectors · the familiar salvage lane" if profile.selected_route == "survey" else "4 sectors · spires, a gravity well, the Leviathan", Vector2(44, 272), 14, UI.MUTED)
			if not profile.owns("charts"):
				UI.label(hub_root, "Deep Orbit: 250 Scrap or your first Survey victory", Vector2(44, 300), 12, UI.GOLD)
			UI.label(hub_root, "SHIP FRAME  /  F TO SWITCH", Vector2(44, 343), 11, UI.CYAN)
			var frame_button := UI.button(hub_root, profile.selected_frame.to_upper(), Rect2(44, 370, 540, 44))
			frame_button.pressed.connect(func() -> void: cycle_frame(profile))
			var stats: Dictionary = FlightProfile.FRAMES[profile.selected_frame]
			UI.label(hub_root, "%d HULL   ·   %.2f SPEED   ·   %.1fs DASH   ·   %d MAGNET" % [int(stats.hull) + (1 if profile.owns("plating") else 0), stats.speed, stats.recharge, stats.magnet], Vector2(44, 430), 13, UI.GOLD)
			UI.label(hub_root, "WASD / arrows steer · SPACE dash · E pulse · F3 Survey view", Vector2(44, 465), 12, UI.MUTED)
		"workshop":
			var ids := FlightProfile.ITEMS.keys()
			workshop_index = clampi(workshop_index, 0, ids.size() - 1)
			var scroll := ScrollContainer.new()
			scroll.position = Vector2(44, 182)
			scroll.size = Vector2(540, 224)
			hub_root.add_child(scroll)
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(rows)
			for i in ids.size():
				var id: String = ids[i]
				var item: Dictionary = FlightProfile.ITEMS[id]
				var row := UI.button(rows, ("› " if i == workshop_index else "  ") + item.name + ("   OWNED" if profile.owns(id) else "   %d" % item.cost), Rect2(0, 0, 520, 30), UI.CYAN if i == workshop_index else Color("6e8795"))
				row.custom_minimum_size = Vector2(510, 31)
				row.alignment = HORIZONTAL_ALIGNMENT_LEFT
				row.pressed.connect(func() -> void:
					workshop_index = i
					hub_changed.emit())
				workshop_buttons.append(row)
			var selected: String = ids[workshop_index]
			UI.label(hub_root, FlightProfile.ITEMS[selected].effect, Vector2(44, 420), 14, UI.GOLD)
			var buy := UI.button(hub_root, "OWNED" if profile.owns(selected) else "SPACE   BUY FOR %d SCRAP" % FlightProfile.ITEMS[selected].cost, Rect2(44, 453, 540, 38), UI.GOLD)
			buy.disabled = not profile.can_buy(selected)
			buy.pressed.connect(func() -> void: buy_selected(profile))
			scroll.set_deferred("scroll_vertical", maxi(0, workshop_index * 35 - 100))
			footer.text = "↑ ↓  SELECT   ·   SPACE  BUY   ·   L / B / T  SECTION   ·   ENTER  LAUNCH"
		"records":
			UI.label(hub_root, "YOUR FLIGHT LOG", Vector2(44, 197), 12, UI.CYAN)
			for i in 2:
				var route: String = ["survey", "deep"][i]
				var record: Dictionary = profile.route_records.get(route, {"best": 0, "rank": "—", "runs": 0, "victories": 0})
				UI.label(hub_root, "SURVEY ROUTE" if i == 0 else "DEEP ORBIT", Vector2(44, 238 + i * 105), 20)
				UI.label(hub_root, "BEST %05d   ·   RANK %s   ·   %d RUNS / %d WINS" % [record.best, record.rank, record.runs, record.victories], Vector2(44, 277 + i * 105), 13, UI.GOLD)
			UI.label(hub_root, "%d TOTAL FLIGHTS  /  %d VICTORIES" % [profile.runs, profile.victories], Vector2(44, 459), 14, UI.MUTED)

func cycle_route(profile: FlightProfile) -> void:
	if profile.owns("charts"):
		profile.selected_route = "deep" if profile.selected_route == "survey" else "survey"
		profile.save()
	hub_changed.emit()

func cycle_frame(profile: FlightProfile, direction: int = 1) -> void:
	var frames: Array[String] = ["starling"]
	for id in ["kestrel", "albatross"]:
		if profile.owns(id):
			frames.append(id)
	profile.selected_frame = frames[posmod(frames.find(profile.selected_frame) + direction, frames.size())]
	profile.save()
	hub_changed.emit()

func buy_selected(profile: FlightProfile) -> void:
	if profile.purchase(FlightProfile.ITEMS.keys()[workshop_index]):
		purchased.emit()
	hub_changed.emit()

func hub_key(key: int, profile: FlightProfile) -> void:
	match key:
		KEY_L: hub_section = "launch"
		KEY_B: hub_section = "workshop"
		KEY_T: hub_section = "records"
		KEY_Q: cycle_route(profile)
		KEY_F: cycle_frame(profile)
		KEY_UP, KEY_DOWN:
			if hub_section == "workshop":
				workshop_index = posmod(workshop_index + (-1 if key == KEY_UP else 1), FlightProfile.ITEMS.size())
		KEY_LEFT, KEY_RIGHT:
			if hub_section == "launch":
				cycle_frame(profile, -1 if key == KEY_LEFT else 1)
		KEY_SPACE:
			if hub_section == "workshop":
				buy_selected(profile)
	hub_changed.emit()
