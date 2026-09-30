shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = vec3(0.45, 0.36, 0.62);
	ALPHA = 0.19 * facing * facing;
}
