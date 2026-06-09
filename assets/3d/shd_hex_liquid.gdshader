shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.0, 0.4, 0.6); // Water cyan/blue
uniform vec3 emission_color : source_color = vec3(0.0, 0.6, 0.8);
uniform float emission_strength : hint_range(0.0, 5.0) = 1.0;

uniform float wave_speed = 0.5;
uniform float wave_scale = 2.0;

uniform float fade_start_y = 0.0;
uniform float fade_end_y = -15.0;

varying vec3 world_pos;
varying vec3 world_normal;

// Procedural pseudo-random
vec2 hash(vec2 p) {
    p = vec2(dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)));
    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

// Procedural Simplex Noise
float simplex_noise(vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2 i = floor(p + (p.x+p.y)*K1);
    vec2 a = p - i + (i.x+i.y)*K2;
    float m = step(a.y, a.x); 
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0*K2;
    vec3 h = max(0.5 - vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0);
    vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot(n, vec3(70.0)) * 0.5 + 0.5;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = (MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    // Top surface mask
    float is_top_surface = smoothstep(0.5, 0.9, abs(world_normal.y));
    
    // Scrolling UV for waves
    vec2 wave_uv = world_pos.xz * wave_scale + TIME * wave_speed * vec2(0.3, 0.2);
    float noise = simplex_noise(wave_uv);
    
    // Derived Normal for the bump mapping (Specular sparkle)
    float eps = 0.01;
    float noise_dx = simplex_noise(wave_uv + vec2(eps, 0.0)) - noise;
    float noise_dy = simplex_noise(wave_uv + vec2(0.0, eps)) - noise;
    
    // Tangent-space normal bump
    vec3 bump_normal = normalize(vec3(-noise_dx * 20.0, 1.0, -noise_dy * 20.0));
    
    // Blend bump mapping only on the top surface
    vec3 final_normal = mix(vec3(0.0, 1.0, 0.0), bump_normal, is_top_surface);
    NORMAL_MAP = final_normal * 0.5 + 0.5;
    
    // Color
    vec3 final_albedo = base_color + (noise * 0.1);
    
    // Abyssal fade
    float fade = clamp((world_pos.y - fade_end_y) / (fade_start_y - fade_end_y), 0.0, 1.0);
    final_albedo *= fade;
    
    ALBEDO = final_albedo;
    
    // Specular / Reflection
    ROUGHNESS = mix(0.9, 0.05, is_top_surface); // Very smooth on top
    SPECULAR = mix(0.1, 0.8, is_top_surface);   // High specular
    METALLIC = mix(0.0, 0.5, is_top_surface);   // Metallic reflection
    
    // Emission
    EMISSION = emission_color * noise * emission_strength * fade * is_top_surface;
}
