// Scope lens: a glass disc that shows a zoomed picture of where the gun points, a reticle printed on the glass,
// a dark rim and reflections. The picture is looked up from the direction the eye sees each point of the lens,
// so moving the head shifts it (parallax) and it reads as a view through a tube.
// The mesh is in the gun's frame: +x forward, +y up, +z to the right.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D scope_picture : source_color, filter_linear, repeat_disable;
uniform float picture_blend : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lens_center = vec3(0.0);
uniform float lens_radius = 0.0095;
uniform float lens_tan = 0.04;
uniform vec3 glass_tint : source_color = vec3(0.88, 0.96, 1.0);
uniform vec3 reticle_color : source_color = vec3(0.95, 0.12, 0.08);

varying vec3 v_world;
varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Thin line of the given half width (in lens units) along an axis.
float line(float d, float half_width) {
	return 1.0 - smoothstep(half_width, half_width * 1.8, abs(d));
}

void fragment() {
	vec3 ray = normalize(v_world - CAMERA_POSITION_WORLD);
	vec3 fwd = normalize(MODEL_MATRIX[0].xyz);
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 side = normalize(MODEL_MATRIX[2].xyz);
	vec3 e = vec3(dot(ray, fwd), dot(ray, up), dot(ray, side));
	vec2 t = vec2(e.z, e.y) / max(abs(e.x), 0.02);

	// Where the lens point sits on the glass, -1 to 1 across the disc.
	vec2 q = vec2(v_local.z - lens_center.z, v_local.y - lens_center.y) / lens_radius;
	float r = length(q);

	// Zoomed picture, with a touch of colour fringing toward the rim.
	vec2 uv = vec2(0.5) + vec2(t.x, -t.y) / (2.0 * lens_tan * 1.05);
	vec2 fringe = normalize(q + vec2(0.0001)) * r * r * 0.006;
	vec3 picture = vec3(
		texture(scope_picture, uv + fringe).r,
		texture(scope_picture, uv).g,
		texture(scope_picture, uv - fringe).b);
	picture *= glass_tint * 1.05;

	// Dark rim and vignette.
	float rim = smoothstep(0.82, 0.98, r);
	float vignette = 1.0 - smoothstep(0.55, 1.0, r) * 0.7;
	picture *= vignette;

	// Reticle printed on the glass: fine cross, mil dots on the lower arm, red centre dot.
	float cross = max(line(q.y, 0.012) * step(abs(q.x), 0.9), line(q.x, 0.012) * step(abs(q.y), 0.9));
	cross *= 1.0 - smoothstep(0.03, 0.08, r);          // open centre, so the target stays clear
	float dots = 0.0;
	for (int i = 1; i <= 3; i++) {
		float y = float(i) * 0.2;
		dots = max(dots, 1.0 - smoothstep(0.018, 0.03, length(q - vec2(0.0, -y))));
	}
	float centre = 1.0 - smoothstep(0.012, 0.022, r);
	vec3 reticle = reticle_color * (cross * 0.0 + centre * 1.6) + vec3(0.02) * 0.0;
	vec3 fine = vec3(0.0) + vec3(cross + dots) * vec3(0.03);

	// Glass: fresnel reflection, a soft glare streak, dark tint when no picture is shown.
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), VIEW)), 0.0, 1.0), 3.0);
	float glare = smoothstep(0.55, 0.0, abs((q.x * 0.8 + q.y) - 0.6)) * 0.10;

	vec3 shown = mix(picture, vec3(0.0), rim);
	shown = shown * (1.0 - (cross + dots) * 0.85) + reticle + fine;

	ALBEDO = mix(glass_tint * 0.05, vec3(0.0), picture_blend);
	EMISSION = shown * picture_blend + vec3(glare) * (0.6 + 0.4 * picture_blend);
	ROUGHNESS = 0.03;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	ALPHA = clamp(mix(0.28 + fres * 0.45, 1.0, picture_blend) + rim * 0.3, 0.0, 1.0);
}
