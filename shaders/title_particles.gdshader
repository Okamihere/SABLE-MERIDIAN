shader_type particles;

uniform vec3 mouse_world_pos = vec3(0.0);
uniform float mouse_radius = 1.5;
uniform float mouse_force = 2.5;
uniform float return_strength = 0.8;
uniform float turbulence_strength = 0.3;
uniform float turbulence_speed = 0.5;

// Custom data layout:
// CUSTOM.x = phase_offset
// CUSTOM.y = size_mult
// CUSTOM.z = initial_pos.x
// CUSTOM.w = initial_pos.y
// We'll store initial_pos.z in a separate way, or recompute

void start() {
	// Posição inicial distribuída em caixa ao redor da TV
	vec3 init_pos = vec3(
		mix(-4.0, 4.0, float(RANDOM_SEED)),
		mix(-0.5, 4.5, float(RANDOM_SEED)),
		mix(-3.0, 2.0, float(RANDOM_SEED))
	);
	
	// Evitar área da TV (centro)
	if (abs(init_pos.x) < 1.8 && init_pos.y > 0.5 && init_pos.y < 3.0 && abs(init_pos.z) < 1.5) {
		init_pos.x = sign(init_pos.x) * 1.8 + mix(0.5, 1.5, float(RANDOM_SEED)) * sign(init_pos.x);
	}
	
	TRANSFORM[3].xyz = init_pos;
	
	// Velocidade inicial orgânica
	float phase_offset = float(RANDOM_SEED) * 100.0;
	VELOCITY = vec3(
		mix(-0.15, 0.15, float(RANDOM_SEED)),
		mix(-0.05, 0.12, float(RANDOM_SEED)),
		mix(-0.15, 0.15, float(RANDOM_SEED))
	);
	
	// Armazenar dados customizados
	// CUSTOM.x = phase_offset
	// CUSTOM.y = size_mult
	// CUSTOM.z = initial_pos.x
	// CUSTOM.w = initial_pos.y
	// initial_pos.z armazenamos na posição inicial mesmo
	CUSTOM = vec4(
		phase_offset,
		mix(0.4, 1.3, float(RANDOM_SEED)),
		init_pos.x,
		init_pos.y
	);
	
	// Variação de tamanho
	float size_mult = CUSTOM.y;
	
	// Cores: roxo, vinho, magenta, dourado
	float color_choice = float(RANDOM_SEED);
	vec3 base_color;
	if (color_choice < 0.25) {
		base_color = vec3(0.55, 0.25, 0.75); // roxo
	} else if (color_choice < 0.45) {
		base_color = vec3(0.65, 0.15, 0.45); // vinho
	} else if (color_choice < 0.7) {
		base_color = vec3(0.85, 0.35, 0.65); // magenta
	} else {
		base_color = vec3(1.0, 0.72, 0.35); // dourado
	}
	COLOR = vec4(base_color, mix(0.15, 0.55, float(RANDOM_SEED)));
}

void process() {
	float t = TIME * 0.5;
	
	// Recuperar dados customizados
	float phase_offset = CUSTOM.x;
	float size_mult = CUSTOM.y;
	vec2 init_pos_xy = CUSTOM.zw;
	vec3 init_pos = vec3(init_pos_xy.x, init_pos_xy.y, TRANSFORM[3].z);
	
	// Turbulência orgânica suave
	vec3 turb = vec3(
		sin(t * turbulence_speed + phase_offset + VELOCITY.x * 10.0),
		sin(t * turbulence_speed * 0.7 + phase_offset + 2.3 + VELOCITY.y * 10.0),
		sin(t * turbulence_speed * 0.5 + phase_offset + 4.7 + VELOCITY.z * 10.0)
	) * turbulence_strength;
	
	// Repulsão do mouse
	vec3 to_particle = TRANSFORM[3].xyz - mouse_world_pos;
	float dist = length(to_particle);
	float falloff = 1.0 - smoothstep(0.0, mouse_radius, dist);
	falloff = falloff * falloff;
	
	vec3 repulsion = vec3(0.0);
	if (dist < mouse_radius && dist > 0.001) {
		repulsion = normalize(to_particle) * mouse_force * falloff;
	}
	
	// Retorno suave à posição original
	vec3 to_origin = vec3(init_pos_xy, init_pos.z) - TRANSFORM[3].xyz;
	vec3 return_force = to_origin * return_strength * 0.5;
	
	// Aplicar forças
	vec3 accel = turb + repulsion + return_force;
	VELOCITY += accel * DELTA;
	VELOCITY *= 0.985;
	
	// Atualizar posição
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	
	// Fade baseado na altura e distância do centro
	float height_fade = smoothstep(-0.5, 0.5, TRANSFORM[3].y);
	float center_fade = 1.0 - smoothstep(0.0, 3.5, length(TRANSFORM[3].xz));
	COLOR.a = COLOR.a * height_fade * center_fade * 0.85;
	
	// Variação sutil de tamanho ao longo do tempo
}