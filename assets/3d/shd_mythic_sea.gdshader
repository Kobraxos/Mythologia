shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.15, 0.1, 0.25); // Deep dusk purple
uniform vec3 cloud_color : source_color = vec3(0.5, 0.25, 0.35); // Warm sunset pink/purple clouds
uniform vec3 emission_color : source_color = vec3(1.0, 0.6, 0.15); // Glowing golden/orange sunset
uniform float emission_strength : hint_range(0.0, 10.0) = 1.2;

uniform vec2 pan_speed_1 = vec2(0.015, 0.01);
uniform vec2 pan_speed_2 = vec2(-0.01, 0.015);

uniform float uv_scale = 3.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

// Procedural pseudo-random
vec2 hash(vec2 p) {
    p = vec2(dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)));
    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

// Procedural Simplex Noise (Anti-crash, editor-safe)
float simplex_noise(vec2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

    vec2 i = floor(p + (p.x+p.y)*K1);
    vec2 a = p - i + (i.x+i.y)*K2;
    float m = step(a.y, a.x); 
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0*K2;
    vec3 h = max(0.5 - vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0);
    vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot(n, vec3(70.0)) * 0.5 + 0.5; // Normalize to 0..1
}

// FBM (Fractal Brownian Motion) for more organic, wispy clouds
float fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 3; i++) {
        f += w * simplex_noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

void fragment() {
    vec2 base_uv = UV * uv_scale;
    
    vec2 uv1 = base_uv + TIME * pan_speed_1;
    vec2 uv2 = base_uv + TIME * pan_speed_2;
    
    // Use FBM for a thick organic cloud texture
    float n1 = fbm(uv1);
    float n2 = fbm(uv2 + vec2(5.2, 1.3)); // Offset second noise
    
    // Average
    float combined = (n1 + n2) * 0.5;
    
    // Masks for clouds and glowing divine edges
    float cloud_mask = smoothstep(threshold - 0.25, threshold + 0.15, combined);
    float glow_mask = smoothstep(threshold + 0.05, threshold + 0.3, combined);
    
    // Blend sky base color with white clouds
    vec3 current_color = mix(base_color, cloud_color, cloud_mask);
    
    // Add golden divine glow to the thickest parts of the clouds
    vec3 final_color = current_color + (emission_color * glow_mask * emission_strength);
    
    ALBEDO = final_color;
}
