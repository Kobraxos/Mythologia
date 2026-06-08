shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// AAA Fix : 'repeat_disable' empêche la carte graphique de dupliquer la texture quand la rotation dépasse les bords (UV > 1.0 ou < 0.0).
uniform sampler2D ring_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float rotation_speed = 0.2;
uniform float pulse_speed = 2.0;
uniform float pulse_intensity = 0.1;

void fragment() {
	// Décalage des UV pour tourner autour du centre (0.5, 0.5)
	vec2 centered_uv = UV - 0.5;
	
	// Matrice de rotation 2D
	float s = sin(TIME * rotation_speed);
	float c = cos(TIME * rotation_speed);
	mat2 rot = mat2(vec2(c, -s), vec2(s, c));
	vec2 rot_uv = (rot * centered_uv) + 0.5;
	
	// Échantillonnage de la texture avec les UV pivotés
	vec4 tex_color = texture(ring_texture, rot_uv);
	
	// Effet de respiration (Pulse)
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
	
	// On multiplie par COLOR (le modulate injecté par le script de l'Unité) et le pulse
	ALBEDO = tex_color.rgb * COLOR.rgb * pulse;
	ALPHA = tex_color.a * COLOR.a;
}