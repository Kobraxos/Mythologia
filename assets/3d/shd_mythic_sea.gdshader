shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.02, 0.02, 0.05); // Very dark navy/void
uniform vec3 emission_color : source_color = vec3(0.4, 0.1, 0.9); // Deep magical purple
uniform float emission_strength : hint_range(0.0, 10.0) = 2.5;

uniform vec2 pan_speed_1 = vec2(0.03, 0.02);
uniform vec2 pan_speed_2 = vec2(-0.02, 0.04);

uniform float uv_scale = 4.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.65; // High threshold for thin, rare wisps

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
    
    // Use FBM for a much more organic, smoky, "soul-like" texture
    float n1 = fbm(uv1);
    float n2 = fbm(uv2);
    
    // Average
    float combined = (n1 + n2) * 0.5;
    
    // Smoothstep for very soft, smoky edges instead of harsh blobs
    float crests = smoothstep(threshold - 0.2, threshold + 0.1, combined);
    
    // Add glow to ALBEDO (since unshaded ignores EMISSION)
    vec3 final_color = base_color + (emission_color * crests * emission_strength);
    
    ALBEDO = final_color;
}
