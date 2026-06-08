shader_type canvas_item;

uniform sampler2D portrait_tex : source_color, filter_linear_mipmap;
uniform float is_active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 border_color : source_color = vec4(0.85, 0.70, 0.25, 1.0); // Or Divin
uniform vec4 ray_color : source_color = vec4(1.0, 0.9, 0.5, 0.8); // Lumière céleste

void fragment() {
	vec2 center = vec2(0.5);
	vec2 uv = UV;
	float dist = distance(uv, center);
	
	// Rayons mathématiques de nos cercles (0.5 = bords extérieurs du carré)
	float inner_radius = 0.36;
	float border_radius = 0.42;
	
	// 1. Masques & Anti-Aliasing
	float mask_inner = 1.0 - smoothstep(inner_radius - 0.01, inner_radius + 0.005, dist);
	float mask_border = 1.0 - smoothstep(border_radius - 0.01, border_radius + 0.005, dist);
	float is_on_border = mask_border - mask_inner; // Isole précisément l'anneau
	
	// 2. Traitement du Portrait (Incrustation & Ombres AAA)
	vec2 portrait_uv = (uv - center) * (0.5 / inner_radius) + center;
	vec4 portrait = texture(portrait_tex, portrait_uv);
	if (portrait_uv.x < 0.0 || portrait_uv.x > 1.0 || portrait_uv.y < 0.0 || portrait_uv.y > 1.0) {
		portrait = vec4(0.0);
	}
	// Vignettage : Assombrit les bords du portrait pour l'enfoncer "sous" l'anneau métallique
	float vignette = smoothstep(inner_radius * 0.65, inner_radius, dist);
	portrait.rgb = mix(portrait.rgb, vec3(0.0), vignette * 0.6);
	
	float angle = atan(uv.y - center.y, uv.x - center.x);
	
	// 3. Traitement de la Bordure (Effet 3D & Métal)
	// Calcul du "relief" du bord : 0 aux extrémités, 1 au centre du métal (courbure parfaite)
	float border_profile = sin(((dist - inner_radius) / (border_radius - inner_radius)) * 3.14159265);
	// Reflet métallique dynamique (Sweep) qui tourne autour du cercle
	float shine = smoothstep(0.7, 1.0, sin(angle * 1.5 + TIME * 2.0));
	float active_shine = mix(0.15, 0.8, is_active); // Le reflet est éclatant quand l'unité est active
	
	vec3 final_border = border_color.rgb * (0.35 + border_profile * 0.75); // Volume de base
	final_border += vec3(shine * active_shine); // Ajout du reflet spéculaire
	final_border += vec3(border_profile * is_active * 0.4); // Le métal lui-même surchauffe quand actif
	
	// 4. Création procédurale des Godrays
	float rays = sin(angle * 8.0 - TIME * 1.5) * 0.5 + 0.5;
	rays *= sin(angle * 3.0 + TIME * 0.8) * 0.5 + 0.5; // Double onde pour plus de majesté
	
	float ray_fade = 1.0 - smoothstep(border_radius, 0.5, dist);
	vec4 ray_final = ray_color * rays * ray_fade * is_active;
	
	// 5. Compositing Final
	vec4 color = mix(vec4(0.0), portrait, mask_inner * portrait.a);
	color.rgb = mix(color.rgb, final_border, is_on_border); // Applique le métal 3D
	color.a = max(color.a, is_on_border); // Force l'opacité sur l'anneau
	
	COLOR = color + (ray_final * (1.0 - mask_border));
}