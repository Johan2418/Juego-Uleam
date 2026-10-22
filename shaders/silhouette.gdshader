shader_type canvas_item;
// Silueta negra con luz de borde (portada): el boss se ve como una sombra recortada contra la luz.

uniform vec4 rim_color : source_color = vec4(1.0, 0.4, 0.2, 1.0);
uniform float rim_px = 3.0;
uniform float rim = 1.0;
uniform vec2 light_dir = vec2(0.0, -1.0);
uniform vec4 body : source_color = vec4(0.02, 0.015, 0.04, 1.0);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE * rim_px;
	// borde iluminado: el lado que mira hacia la luz (si el vecino en esa dirección es transparente)
	float lit = 1.0 - texture(TEXTURE, UV + light_dir * px).a;
	float any_edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		any_edge = max(any_edge, 1.0 - texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px * 0.6).a);
	}
	vec3 c = body.rgb;
	c = mix(c, rim_color.rgb, clamp(lit, 0.0, 1.0) * rim);
	c = mix(c, rim_color.rgb * 0.55, any_edge * 0.35 * rim);
	COLOR = vec4(c, a * COLOR.a);
}
