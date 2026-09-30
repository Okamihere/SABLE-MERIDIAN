shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = vec3(0.31, 0.28, 0.47);
	ALPHA = 0.48 * pow(facing, 1.6);
}
