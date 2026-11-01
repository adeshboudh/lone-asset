// SPDX-License-Identifier: MIT
// Blockout grid: 1 m lines, bolder every 5 m, in world space so every surface reads at the same scale.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.55, 0.57, 0.6);
uniform vec3 line_color : source_color = vec3(0.3, 0.32, 0.35);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1.0 on a grid line of the given spacing and half-width, anti-aliased.
float grid(vec2 p, float spacing, float half_width) {
	vec2 distance_to_line = abs(fract(p / spacing + 0.5) - 0.5) * spacing;
	vec2 aa = fwidth(p);
	vec2 line = 1.0 - smoothstep(vec2(half_width), vec2(half_width) + aa, distance_to_line);
	return max(line.x, line.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = (n.y >= n.x && n.y >= n.z) ? world_position.xz : ((n.x >= n.z) ? world_position.zy : world_position.xy);
	float lines = max(grid(p, 1.0, 0.01), grid(p, 5.0, 0.03));
	ALBEDO = mix(base_color, line_color, lines);
	ROUGHNESS = 0.9;
}
