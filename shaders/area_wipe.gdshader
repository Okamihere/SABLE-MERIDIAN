shader_type canvas_item;

uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 veil_color : source_color = vec4(0.025, 0.035, 0.075, 1.0);
uniform vec4 edge_color : source_color = vec4(0.5, 0.67, 0.83, 1.0);

void fragment() {
	float wave = 0.065 * sin(SCREEN_UV.x * 14.0 + TIME * 3.3) + 0.035 * sin(SCREEN_UV.x * 31.0 - TIME * 2.1);
	float threshold = 1.0 - SCREEN_UV.y + wave;
	float front = coverage * 1.3;
	float fog = smoothstep(threshold - 0.16, threshold + 0.15, front);
	float edge = 1.0 - smoothstep(0.0, 0.13, abs(front - threshold));
	float alpha = clamp(fog + edge * 0.22, 0.0, 1.0);
	if (coverage <= 0.001) {
		alpha = 0.0;
	}
	if (coverage >= 0.999) {
		alpha = 1.0;
	}
	COLOR.rgb = mix(veil_color.rgb, edge_color.rgb, edge * 0.52);
	COLOR.a = alpha;
}
