shader_type canvas_item;
// Frosted glass: the picture behind a Control, blurred, dimmed and tinted. A stylebox drawn through this shader keeps
// its own colour only where it is not transparent: a near-transparent fill becomes pure glass, a border or a wash
// (alpha above zero) is mixed over it. Used by GlassPanel and GlassButton through data/ui/glass_material.tres.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 7.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.05, 0.07, 0.08, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float darken : hint_range(0.0, 1.0) = 0.2;
uniform float saturation : hint_range(0.0, 1.5) = 0.75;

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * exp2(blur_lod) * 0.5;
	vec3 sum = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb * 0.2;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 offset = vec2(cos(angle), sin(angle)) * step_size;
		sum += textureLod(screen_texture, SCREEN_UV + offset, blur_lod).rgb * 0.1;
	}
	float grey = dot(sum, vec3(0.299, 0.587, 0.114));
	vec3 glass = mix(vec3(grey), sum, saturation) * (1.0 - darken);
	glass = mix(glass, tint.rgb, tint_strength);
	COLOR = vec4(mix(glass, COLOR.rgb, COLOR.a), 1.0);
}
