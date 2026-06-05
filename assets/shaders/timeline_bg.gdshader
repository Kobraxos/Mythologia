shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.06, 0.04, 0.05, 0.95); // Obsidienne / Pourpre sombre
uniform vec4 mist_color : source_color = vec4(0.55, 0.35, 0.15, 0.6); // Encens Divin / Ambre
uniform vec4 dust_color : source_color = vec4(1.0, 0.8, 0.3, 0.8); // Poussière d'or / Braises
uniform float speed = 0.03;

// Fonction de bruit pseudo-aléatoire
float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// Bruit de valeur
float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(random(i), random(i + vec2(1.0, 0.0)), f.x),
			   mix(random(i + vec2(0.0, 1.0)), random(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Fractal Brownian Motion (FBM)
float fbm(vec2 uv) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(uv);
		uv = uv * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 aspect_uv = UV * vec2(7.5, 1.0);
	
	float alpha_mask = smoothstep(0.0, 0.35, UV.x);
	
	// 1. Volutes d'encens dorées (Brume avec plus de contraste)
	vec2 mist_uv = aspect_uv * 1.2 + vec2(TIME * -speed, TIME * (speed * 0.5));
	float mist_value = fbm(mist_uv);
	mist_value = smoothstep(0.2, 0.8, mist_value); // Effet fumée dense
	
	// 2. Particules : Poussière d'or / Braises dérivant lentement (Couche 1)
	vec2 dust_uv1 = aspect_uv * 4.0 + vec2(TIME * speed * 2.0, TIME * -speed * 2.0);
	float rand1 = random(floor(dust_uv1));
	float circle1 = smoothstep(0.3, 0.0, distance(fract(dust_uv1), vec2(0.5)));
	float dust1 = (rand1 > 0.96) ? circle1 * (sin(TIME * 3.0 + rand1 * 100.0) * 0.5 + 0.5) : 0.0;
	
	// Particules : Poussière d'or (Couche 2, plus petite et plus lente)
	vec2 dust_uv2 = aspect_uv * 8.0 + vec2(TIME * speed * 1.5, TIME * -speed * 1.0);
	float rand2 = random(floor(dust_uv2));
	float circle2 = smoothstep(0.4, 0.0, distance(fract(dust_uv2), vec2(0.5)));
	float dust2 = (rand2 > 0.98) ? circle2 * (sin(TIME * 2.0 + rand2 * 100.0) * 0.5 + 0.5) : 0.0;
	
	// 3. Composition finale
	vec4 final_color = mix(base_color, mist_color, mist_value * 0.6);
	final_color.rgb += dust_color.rgb * (dust1 + dust2 * 0.5); // Illumination par l'or
	final_color.a *= alpha_mask; // Fondu sur la gauche
	
	COLOR = final_color;
}