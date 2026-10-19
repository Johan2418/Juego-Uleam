shader_type canvas_item;
// Estatua del Salón de las Facultades: convierte el sprite del boss en piedra (o en oro si ya se venció).
// lit = cuánta luz le cae desde arriba (sube al acercarse el jugador).

uniform float lit : hint_range(0.0, 1.5) = 0.4;
uniform float gold : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 stone_dark : source_color = vec4(0.07, 0.075, 0.09, 1.0);
uniform vec4 stone_light : source_color = vec4(0.80, 0.80, 0.83, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// contraste suave para que se lea el volumen
	l = smoothstep(0.02, 0.95, l);
	// grano de piedra
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE / 2.0);
	l += (hash(cell) - 0.5) * 0.07;
	// la luz viene de arriba: la parte alta brilla más
	float top = clamp(1.0 - UV.y * 1.25, 0.0, 1.0);
	float k = l * (0.35 + 0.55 * lit) + top * 0.22 * lit;
	vec3 stone = mix(stone_dark.rgb, stone_light.rgb, clamp(k, 0.0, 1.0)) * mix(vec3(1.0), tint.rgb, 0.18 * lit);
	vec3 g = mix(vec3(0.18, 0.10, 0.02), vec3(1.0, 0.86, 0.48), clamp(k * 1.15, 0.0, 1.0));
	vec3 col = mix(stone, g, gold);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, c.a * COLOR.a);
}
