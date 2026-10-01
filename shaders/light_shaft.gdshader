shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec3 shaft_color : source_color = vec3(0.42, 0.29, 0.78);

void fragment() {
	float vertical = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = shaft_color;
	ALPHA = 0.22 * vertical * pow(facing, 1.5);
}
