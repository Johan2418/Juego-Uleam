shader_type canvas_item;
// Recolorea la ropa del cuerpo compartido.
// mask_tex: R = camisa, G = pantalón (generada por tools/character_split/build_characters.py)
// El sombreado se conserva escalando el color destino por la luminancia original.

uniform sampler2D mask_tex : filter_nearest;
uniform vec3 shirt_color = vec3(0.765, 0.82, 0.925);
uniform vec3 pants_color = vec3(0.24, 0.357, 0.541);
uniform float shirt_ref = 0.833;
uniform float pants_ref = 0.377;
uniform bool use_mask = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (use_mask) {
		vec4 m = texture(mask_tex, UV);
		float lum = (c.r + c.g + c.b) / 3.0;
		if (m.r > 0.5) {
			c.rgb = clamp(shirt_color * (lum / shirt_ref), 0.0, 1.0);
		} else if (m.g > 0.5) {
			c.rgb = clamp(pants_color * (lum / pants_ref), 0.0, 1.0);
		}
	}
	COLOR = c * COLOR;
}
