extends Control
## Title, pause, results, and upgrade choices between sectors.

signal primary_pressed
signal upgrade_selected(id: String)
signal sound_toggled
signal motion_toggled
signal abandon_pressed

const UI := preload("res://scripts/ui_style.gd")
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
	artwork.visible = state in ["menu", "won", "lost"]
	shade.color = Color(0.01, 0.025, 0.04, 0.1 if artwork.visible else 0.9)
	panel.visible = state != "upgrade"
	upgrades_root.visible = state == "upgrade"
	secondary.visible = state == "paused"
	panel.position.x = 74 if artwork.visible else 326
	if state == "upgrade":
		_build_upgrades(run)
		return
	match state:
		"menu":
			eyebrow.text = "S T A R L I N G   /   A N   A R C A D E   E X P E D I T I O N"
			title.text = "Small ship.\nOne more haul."
			description.text = "Three sectors. One ship. A cargo hold full of possibility.\nCollect cores → bank them at the dock → choose an upgrade.\nSPACE dashes through debris. E pulses danger away."
			result.text = "BEST  %05d    /    %d EXPEDITIONS COMPLETED" % [profile.best, profile.victories]
			button.text = "LAUNCH EXPEDITION     →"
			footer.text = "ENTER TO LAUNCH     /     WASD OR ARROWS TO STEER"
		"paused":
			eyebrow.text = "F L I G H T   O N   H O L D"
			title.text = "Take a breath,\npilot."
			description.text = "Bank cargo by staying inside the safe dock for a moment.\nDash into rocks and sentries to shatter them for bonus points.\nYour ion pulse pushes debris, stuns sentries, and pulls in cores."
			result.text = "SECTOR %d / 3     /     SCORE %05d" % [run.sector_index + 1, run.score]
			button.text = "RESUME EXPEDITION     →"
			footer.text = "ENTER, ESC OR P TO RESUME"
		"won":
			eyebrow.text = "E X P E D I T I O N   C O M P L E T E   /   R A N K  " + run.rank()
			title.text = "Three sectors.\nOne great story."
			description.text = "All %d cores home. Your ship made it through the storm.\nTry a different upgrade build or chase a longer pickup chain.\nThank you for flying Starling." % run.total_banked
			result.text = "SCORE %05d   /   BEST %05d   /   PEAK x%d" % [run.score, profile.best, run.peak_multiplier]
			button.text = "ANOTHER EXPEDITION     →"
			footer.text = "ENTER OR R TO PLAY AGAIN"
		"lost":
			eyebrow.text = "E X P E D I T I O N   E N D E D   /   S E C T O R  %d" % [run.sector_index + 1]
			title.text = "A rough orbit.\nA fresh start."
			description.text = reason + "\nKeep banking cargo and use your pulse when space gets tight.\nThe next expedition starts with a fresh ship."
			result.text = "SCORE %05d   /   BEST %05d   /   %d CORES BANKED" % [run.score, profile.best, run.total_banked]
			button.text = "TRY A NEW EXPEDITION     →"
			footer.text = "ENTER OR R TO RESTART"


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
	UI.label(upgrades_root, "NEXT  /  " + Expedition.SECTORS[run.sector_index + 1].name, Vector2(80, 646), 12, UI.CYAN)
	UI.label(upgrades_root, "PRESS 1, 2 OR 3 TO INSTALL AND JUMP", Vector2(880, 646), 11, UI.MUTED)


func _select_upgrade(id: String) -> void:
	upgrade_selected.emit(id)
