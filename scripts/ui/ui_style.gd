extends RefCounted
## Estilo común de la portada y la selección de personaje: letra arcade en cursiva
## (Impact / Arial Black si están en el sistema) con borde grueso, como los menús de los 90.
## Sin class_name: cargar con preload("res://scripts/ui/ui_style.gd").

static var _font: Font


static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Impact", "Arial Black", "Franklin Gothic Heavy", "Liberation Sans", "DejaVu Sans"])
		sf.font_weight = 900
		sf.font_italic = true
		sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		sf.fallbacks = [ThemeDB.fallback_font]
		_font = sf
	return _font


## Texto arcade: sombra, borde grueso oscuro y relleno con degradado simple (arriba claro).
static func title(ci: CanvasItem, pos: Vector2, s: String, size: int, fill: Color, edge: Color = Color(0.05, 0.03, 0.1),
		align: int = HORIZONTAL_ALIGNMENT_CENTER, width: float = -1.0, skew: float = -0.18, base: Transform2D = Transform2D.IDENTITY) -> void:
	var f := font()
	var m := base * Transform2D(Vector2(1, 0), Vector2(skew, 1), pos)
	ci.draw_set_transform_matrix(m)
	var p := Vector2(-width * 0.5 if width > 0.0 and align == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0.0)
	ci.draw_string_outline(f, p + Vector2(3, 4), s, align, width, size, maxi(6, size / 6), Color(0, 0, 0, 0.55))
	ci.draw_string_outline(f, p, s, align, width, size, maxi(6, size / 6), edge)
	ci.draw_string(f, p, s, align, width, size, fill)
	# brillo en la mitad de arriba
	ci.draw_string(f, p + Vector2(0, -1), s, align, width, size, Color(1, 1, 1, 0.18))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func text_w(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Polígono inclinado (paralelogramo) de ancho w y alto h; slant = desplazamiento de arriba.
static func slanted(r: Rect2, slant: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(slant, 0), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - slant, r.end.y), Vector2(r.position.x, r.end.y)])
