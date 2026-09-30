shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 fog_color : source_color = vec4(0.45, 0.62, 0.83, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
uniform float phase_offset = 0.0;

void fragment() {
	float t = TIME * 0.42 + phase_offset;
	float fold_a = sin(UV.x * 12.0 + UV.y * 8.0 + t * 2.4);
	float fold_b = sin(UV.x * 23.0 - UV.y * 14.0 - t * 1.7);
	float fold_c = sin(UV.y * 31.0 + fold_a * 2.0 + t * 3.0);
	float cloud = 0.5 + 0.22 * fold_a + 0.16 * fold_b + 0.12 * fold_c;
	float side_fade = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
	float vertical_fade = smoothstep(0.0, 0.18, UV.y) * smoothstep(0.0, 0.1, 1.0 - UV.y);
	float pulse = 0.9 + 0.1 * sin(TIME * 1.8 + phase_offset);
	ALBEDO = fog_color.rgb * (0.72 + cloud * 0.5);
	EMISSION = fog_color.rgb * (0.18 + cloud * 0.36) * pulse;
	ALPHA = clamp((0.28 + cloud * 0.56) * side_fade * vertical_fade * opacity, 0.0, 0.86);
}
