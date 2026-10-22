shader_type canvas_item;
// Pantalla dividida dinámica (Voronoi) para 2 jugadores: mezcla las dos vistas por el lado
// de una línea que pasa por el centro, perpendicular a la dirección jugador 1 -> jugador 2.

uniform sampler2D view_a : filter_nearest;
uniform sampler2D view_b : filter_nearest;
uniform vec2 normal = vec2(1.0, 0.0);
uniform float split = 0.0;
uniform float line = 0.0;
uniform vec2 size = vec2(1280.0, 720.0);

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float side = dot(p, normal);
	vec4 a = texture(view_a, UV);
	vec4 b = texture(view_b, UV);
	vec4 c = (split > 0.5 && side > 0.0) ? b : a;
	float d = abs(side);
	float dark = (1.0 - smoothstep(2.0, 3.5, d)) * line;
	float glow = (1.0 - smoothstep(0.0, 1.0, d)) * line;
	c.rgb = mix(c.rgb, vec3(0.02, 0.02, 0.05), dark);
	c.rgb = mix(c.rgb, vec3(0.9, 0.95, 1.0), glow * 0.8);
	COLOR = vec4(c.rgb, 1.0);
}
