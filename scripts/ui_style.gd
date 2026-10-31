class_name FlightUI
extends RefCounted

const WHITE := Color("e5eee9")
const MUTED := Color("8ca2b0")
const CYAN := Color("78f5dd")
const GOLD := Color("f3c77b")


static func box(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(1)
	return style


static func label(parent: Node, text: String, pos: Vector2, font_size: int = 14, color: Color = WHITE) -> Label:
	var item := Label.new()
	item.text = text
	item.position = pos
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


static func button(parent: Node, text: String, rect: Rect2, accent: Color = CYAN) -> Button:
	var item := Button.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.focus_mode = Control.FOCUS_NONE
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_size_override("font_size", 14)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		item.add_theme_color_override(state, Color("10242b"))
	item.add_theme_stylebox_override("normal", box(accent))
	item.add_theme_stylebox_override("hover", box(accent.lightened(0.2)))
	item.add_theme_stylebox_override("pressed", box(accent.darkened(0.2)))
	parent.add_child(item)
	return item


static func bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var item := ProgressBar.new()
	item.position = rect.position
	item.show_percentage = false
	item.max_value = 1.0
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", 1)
	item.add_theme_stylebox_override("background", box(Color("20343e"), 2))
	item.add_theme_stylebox_override("fill", box(color, 2))
	parent.add_child(item)
	item.size = rect.size
	return item
