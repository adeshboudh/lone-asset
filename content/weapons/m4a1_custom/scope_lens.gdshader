// Scope lens: a glass disc that shows a zoomed picture of where the player aims (the view camera's forward
// direction, which is where the bullets go), a reticle, a dark rim and reflections. The picture is looked up from
// the direction the eye sees each point of the lens relative to the lens centre, so the centre of the lens always
// shows the aim point and moving the head shifts the picture a little (parallax).
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
	// Half a millimetre toward the shooter, so the disc never fights the glass recess it sits in (flicker).
	vec3 lifted = VERTEX - vec3(0.0005, 0.0, 0.0);
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(lifted, 1.0)).xyz;
	VERTEX = lifted;
}

void fragment() {
	// Eye rays through this point and through the lens centre, in the view camera's frame (x right, y up, -z forward).
	vec3 centre_world = (MODEL_MATRIX * vec4(lens_center, 1.0)).xyz;
	vec3 ray = mat3(VIEW_MATRIX) * normalize(v_world - CAMERA_POSITION_WORLD);
	vec3 ray_centre = mat3(VIEW_MATRIX) * normalize(centre_world - CAMERA_POSITION_WORLD);
	vec2 t = ray.xy / max(-ray.z, 0.02) - ray_centre.xy / max(-ray_centre.z, 0.02);

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

	// Reticle: a soft red dot with a faint halo, no lines, like a red-dot sight (the HUD plus is hidden while aimed).
	float core = exp(-pow(r / 0.055, 2.0));
	float halo = exp(-pow(r / 0.20, 2.0)) * 0.22;
	vec3 reticle = reticle_color * (core * 0.85 + halo);

	// Glass: fresnel reflection, a soft glare streak, dark tint when no picture is shown.
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), VIEW)), 0.0, 1.0), 3.0);
	float glare = smoothstep(0.55, 0.0, abs((q.x * 0.8 + q.y) - 0.6)) * 0.10;

	vec3 shown = mix(picture, vec3(0.0), rim);
	shown += reticle;

	ALBEDO = mix(glass_tint * 0.05, vec3(0.0), picture_blend);
	EMISSION = shown * picture_blend + vec3(glare) * (0.6 + 0.4 * picture_blend);
	ROUGHNESS = 0.03;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	ALPHA = clamp(mix(0.28 + fres * 0.45, 1.0, picture_blend) + rim * 0.3, 0.0, 1.0);
}
