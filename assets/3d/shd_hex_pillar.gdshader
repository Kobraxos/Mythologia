shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.55, 0.55, 0.6); // Greyish marble
uniform vec3 detail_color : source_color = vec3(0.45, 0.45, 0.5); // Second color for organic noise
uniform vec3 crack_color : source_color = vec3(1.0, 0.75, 0.15); // Divine Gold
uniform float emission_strength : hint_range(0.0, 10.0) = 1.5;

uniform float uv_scale = 0.4; // MUCH lower scale = huge, rare veins instead of a messy web
uniform float crack_thickness : hint_range(0.0, 1.0) = 0.015; // VERY thin hairline fractures

uniform float fade_start_y = 0.0;
uniform float fade_end_y = -15.0;

uniform float roughness_base : hint_range(0.0, 1.0) = 0.1;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.1;
uniform float noise_darkening : hint_range(0.0, 1.0) = 0.5;

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

// Generates sharp glowing cracks where noise crosses 0.5
float get_crack(vec2 p) {
    float n = simplex_noise(p);
    float d = abs(n - 0.5) * 2.0; // 0.0 at center, 1.0 at edges
    return 1.0 - smoothstep(0.0, crack_thickness, d);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = (MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    // 1. Triplanar Mapping for Cracks
    vec3 blending = abs(world_normal);
    blending = normalize(max(blending, 0.00001));
    float b = (blending.x + blending.y + blending.z);
    blending /= vec3(b, b, b);
    
    // Extremely slow drift so it's not distracting
    vec2 drift = vec2(TIME * 0.005, TIME * 0.003);
    
    float cx = get_crack(world_pos.zy * uv_scale + drift);
    float cy = get_crack(world_pos.xz * uv_scale + drift);
    float cz = get_crack(world_pos.xy * uv_scale + drift);
    
    float crack = cx * blending.x + cy * blending.y + cz * blending.z;
    
    // 2. Readability Mask (The Game Design fix)
    // We want the TOP surface (where units stand) to be mostly clean.
    // world_normal.y is 1.0 on flat top, 0.0 on vertical sides.
    float is_top_surface = smoothstep(0.5, 0.9, abs(world_normal.y));
    
    // Cracks are 100% visible on sides, but faded to 15% on the top.
    float crack_visibility = mix(1.0, 0.15, is_top_surface);
    crack *= crack_visibility;
    
    // 3. Organic Surface Mixing
    float surface_noise = simplex_noise(world_pos.xz * 4.0); // 0.0 to 1.0
    
    // Mix base color and detail color
    vec3 mixed_color = mix(base_color, detail_color, surface_noise);
    
    // Darken slightly for texture depth
    vec3 final_albedo = mixed_color - vec3(surface_noise * noise_darkening * 0.2); 
    
    // Blend the cracks into the albedo so they are visible even without emission (like dry sand in crevices)
    final_albedo = mix(final_albedo, crack_color, crack);
    
    // 4. Abyssal Fade (Fade to black as it goes down)
    float fade = clamp((world_pos.y - fade_end_y) / (fade_start_y - fade_end_y), 0.0, 1.0);
    
    final_albedo *= fade;
    
    ALBEDO = final_albedo;
    
    // ROUGHNESS & METALLIC
    METALLIC = metallic_base;
    ROUGHNESS = roughness_base + (surface_noise * 0.5);
    
    // EMISSION
    EMISSION = crack_color * crack * emission_strength * fade;
}
