extends CanvasLayer
## In-flight information and short notices. FlightScreens owns full-screen menus.

const UI := preload("res://scripts/ui_style.gd")
const Screens := preload("res://scripts/screens.gd")
var flight_ui: Control
var screens: Control
var core_label: Label
var cargo_label: Label
var time_label: Label
var hull_label: Label
var score_label: Label
var objective: Label
var combo_label: Label
var chain_bar: ProgressBar
var dash_label: Label
var pulse_label: Label
var dash_bar: ProgressBar
var pulse_bar: ProgressBar
var mute_label: Label
var notice_panel: Panel
var notice_label: Label
var notice_left := 0.0
var best_label: Label


func _ready() -> void:
	var root := Control.new()
	flight_ui = root
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UI.label(root, "S T A R L I N G", Vector2(42, 25), 27)
	UI.label(root, "O R B I T A L   S A L V A G E", Vector2(44, 64), 10, UI.MUTED)
	UI.label(root, "CORES BANKED", Vector2(365, 24), 10, UI.MUTED)
	core_label = UI.label(root, "00 / 08", Vector2(365, 43), 25, UI.GOLD)
	cargo_label = UI.label(root, "CARGO ABOARD  00", Vector2(365, 77), 10, UI.MUTED)
	UI.label(root, "SECTOR CLOCK", Vector2(605, 24), 10, UI.MUTED)
	time_label = UI.label(root, "01:05", Vector2(605, 43), 25)
	UI.label(root, "HULL INTEGRITY", Vector2(820, 24), 10, UI.MUTED)
	hull_label = UI.label(root, "◆  ◆  ◆", Vector2(820, 46), 19, UI.CYAN)
	UI.label(root, "EXPEDITION SCORE", Vector2(1060, 24), 10, UI.MUTED)
	score_label = UI.label(root, "00000", Vector2(1060, 43), 25)
	objective = UI.label(root, "", Vector2(43, 102), 11, UI.CYAN)
	combo_label = UI.label(root, "LINK PICKUPS FOR A MULTIPLIER", Vector2(947, 95), 10, UI.MUTED)
	chain_bar = UI.bar(root, Rect2(947, 117, 290, 3), UI.GOLD)
	UI.label(root, "WASD / ARROWS   MOVE", Vector2(44, 757), 11, UI.MUTED)
	dash_label = UI.label(root, "SPACE   DASH / SHATTER", Vector2(293, 749), 11, UI.CYAN)
	dash_bar = UI.bar(root, Rect2(293, 776, 168, 4), UI.CYAN)
	pulse_label = UI.label(root, "E   ION PULSE", Vector2(514, 749), 11, Color("b0a9ff"))
	pulse_bar = UI.bar(root, Rect2(514, 776, 168, 4), Color("b0a9ff"))
	UI.label(root, "P  PAUSE  /  F3  VIEW", Vector2(741, 757), 11, UI.MUTED)
	mute_label = UI.label(root, "M   SOUND ON", Vector2(934, 757), 11, UI.MUTED)
	best_label = UI.label(root, "BEST  00000", Vector2(1120, 757), 10, UI.MUTED)
	notice_panel = Panel.new()
	notice_panel.position = Vector2(280, 146)
	notice_panel.size = Vector2(720, 44)
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.add_theme_stylebox_override("panel", UI.box(Color(0.025, 0.06, 0.085, 0.94), 8, Color("34505a")))
	root.add_child(notice_panel)
	notice_label = UI.label(notice_panel, "", Vector2(16, 11), 13, UI.CYAN)
	notice_label.size.x = 688
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screens = Screens.new()
	add_child(screens)


func render(run: Expedition, pilot: Pilot, seconds: float, profile: FlightProfile, delta: float) -> void:
	flight_ui.visible = not screens.visible
	var sector := run.sector()
	core_label.text = "%02d / %02d" % [run.banked, sector.quota]
	cargo_label.text = "CARGO ABOARD  %02d" % run.cargo
	cargo_label.add_theme_color_override("font_color", UI.GOLD if run.cargo > 0 else UI.MUTED)
	var whole := int(ceil(seconds))
	time_label.text = "%02d:%02d" % [whole / 60, whole % 60]
	time_label.add_theme_color_override("font_color", Color("ff9690") if seconds < 15 else UI.WHITE)
	hull_label.text = "◆ ".repeat(maxi(pilot.health, 0)) + "◇ ".repeat(maxi(0, pilot.max_health - pilot.health))
	score_label.text = "%05d" % run.score
	dash_bar.value = 1 - pilot.cooldown / pilot.cooldown_max
	pulse_bar.value = 1 - pilot.pulse_cooldown / pilot.pulse_cooldown_max
	dash_label.add_theme_color_override("font_color", UI.CYAN if pilot.cooldown <= 0 else UI.MUTED)
	pulse_label.text = "E   ION PULSE" if pilot.pulse_cooldown <= 0 else "E   PULSE  %.1fs" % pilot.pulse_cooldown
	pulse_label.add_theme_color_override("font_color", Color("b0a9ff") if pilot.pulse_cooldown <= 0 else UI.MUTED)
	mute_label.text = "M   SOUND OFF" if profile.muted else "M   SOUND ON"
	best_label.text = "BEST  %05d" % int(profile.route_records.get(run.route, {"best": 0}).best)
	var instruction := "RECOVER & BANK %d CORES" % sector.quota
	if run.cargo + run.banked == int(sector.quota) and run.cargo > 0:
		instruction = "ALL CARGO ABOARD — RETURN TO THE DOCK"
	objective.text = "%02d / %02d   %s   /   %s" % [run.sector_index + 1, run.sectors().size(), sector.name, instruction]
	objective.add_theme_color_override("font_color", sector.color)
	combo_label.text = "x%d PICKUP CHAIN   /   %d LINKED" % [run.multiplier(), run.chain] if run.chain > 0 else "LINK PICKUPS FOR A MULTIPLIER"
	combo_label.add_theme_color_override("font_color", UI.GOLD if run.chain > 0 else UI.MUTED)
	chain_bar.value = run.chain_left / run.chain_window()
	notice_left = maxf(0, notice_left - delta)
	notice_panel.visible = notice_left > 0 and not screens.visible
	notice_panel.modulate.a = minf(1, notice_left * 2)
	screens.update_settings(profile)


func notice(text: String, color: Color = UI.CYAN, duration: float = 3.0) -> void:
	notice_label.text = text
	notice_label.add_theme_color_override("font_color", color)
	notice_left = duration
