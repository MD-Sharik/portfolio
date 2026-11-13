extends RefCounted
## Small helpers to build themed UI in code.


static func flat(bg: Color, radius: int = 28, border_w: int = 0, border: Color = Color.TRANSPARENT, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.14)
		s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 24
	s.content_margin_right = 24
	return s


static func make_button(text: String, bg: Color, fg: Color, font_size: int = 46, min_h: float = 120.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var normal := flat(bg, 34, 0, Color.TRANSPARENT, 8)
	var pressed := flat(bg.darkened(0.14), 34, 0, Color.TRANSPARENT, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", normal)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, fg)
	return b


static func make_label(text: String, size: int, color: Color, outline: int = 0, outline_color: Variant = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", color if outline_color == null else outline_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
