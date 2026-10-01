shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float focus_progress : hint_range(0.0, 1.0) = 0.0;
uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation_near = 8.0;
uniform float desaturation_far = 32.0;
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform vec2 target_uv = vec2(0.5, 0.5);
uniform vec2 previous_target_uv = vec2(0.5, 0.5);
uniform vec2 player_radius = vec2(0.08, 0.16);
uniform vec2 target_radius = vec2(0.08, 0.16);
uniform vec2 previous_target_radius = vec2(0.08, 0.16);
uniform float target_blend : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	if (focus_progress <= 0.001) {
		ALBEDO = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
		ALPHA = 0.0;
	} else {
		vec4 sharp = textureLod(screen_texture, SCREEN_UV, 0.0);
		vec4 soft = textureLod(screen_texture, SCREEN_UV, 1.7);
		float player_edge = smoothstep(0.82, 1.35, length((SCREEN_UV - player_uv) / player_radius));
		float target_edge = smoothstep(0.82, 1.35, length((SCREEN_UV - target_uv) / target_radius));
		float previous_target_edge = smoothstep(0.82, 1.35, length((SCREEN_UV - previous_target_uv) / previous_target_radius));
		target_edge = min(target_edge, mix(previous_target_edge, 1.0, target_blend));
		float focus_mask = min(player_edge, target_edge);
		float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
		#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
		#endif
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float distance_from_camera = -view.z / view.w;
		float far_amount = smoothstep(desaturation_near, desaturation_far, distance_from_camera);
		vec3 color = mix(sharp.rgb, soft.rgb, blur_strength);
		float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
		color = mix(color, vec3(luminance), desaturation_strength * far_amount);
		ALBEDO = color;
		ALPHA = focus_progress * focus_mask;
	}
}
