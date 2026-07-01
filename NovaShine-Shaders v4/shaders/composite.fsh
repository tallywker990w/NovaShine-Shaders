#version 120
/* NovaShine - composite (fragment)
   Post-processing pass:
   - Screen-space ray-marched "contact shadows"
   - Screen-space volumetric "god rays" from the sun (crepuscular rays)
   - Radiant glow/streak treatment for emissive blocks (torches, lava,
     glowstone, etc.)
   - Cheap bloom, saturation boost, vignette, rain dimming

   ABOUT "GOD RAYS": Iris/OptiFine shaderpacks run on plain OpenGL, so
   there's no hardware ray-tracing API here. What this uses instead is
   "screen-space volumetric light scattering" - a well-known real-time
   technique (see: GPU Gems 3, Ch. 13, "Volumetric Light Scattering as a
   Post-Process"). It radially samples the depth buffer toward the sun's
   projected screen position, accumulating light from unoccluded (sky)
   pixels along the way. This is the same category of technique most
   game engines actually use for "god rays" - it's a real, legitimate
   effect, just not literal photon ray-tracing.

   ABOUT LIGHT-EMITTING BLOCKS: torches/lava/glowstone don't get their
   own volumetric shafts (that would need a shadow map per light source,
   which isn't practical for arbitrary placed light blocks). Instead they
   get a multi-directional "streak" bloom - bright pixels radiate soft
   light spikes outward in several directions, which reads as a warm
   glowing/radiant light source rather than a flat bright square. */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;

varying vec2 vTexCoord;

// Reconstructs a view-space position from the depth buffer at a given UV
vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clip;
    return viewPos.xyz / viewPos.w;
}

// Cheap per-pixel pseudo-random value, used to jitter the ray march so
// self-occlusion noise reads as a fine dither instead of hard blotches.
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Marches a short ray from the surface toward the light and checks whether
// it runs into closer geometry along the way. Returns 1.0 = unoccluded,
// fading down to ~0.6 the closer/harder the occlusion.
float contactShadow(vec2 uv, vec3 lightDirView) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 1.0; // sky - skip

    vec3 viewPos = getViewPos(uv, depth);

    const int STEPS = 8;
    const float STEP_SIZE = 0.30; // in view-space units (roughly blocks)

    // Jitter the starting point per-pixel so acne becomes fine noise,
    // not hard-edged blocky patches.
    float jitter = hash12(gl_FragCoord.xy) * STEP_SIZE;

    vec3 rayPos = viewPos + lightDirView * jitter;
    float result = 1.0;

    for (int i = 0; i < STEPS; i++) {
        rayPos += lightDirView * STEP_SIZE;

        vec4 clipPos = gbufferProjection * vec4(rayPos, 1.0);
        clipPos.xyz /= clipPos.w;
        vec2 sampleUV = clipPos.xy * 0.5 + 0.5;

        if (sampleUV.x < 0.0 || sampleUV.x > 1.0 ||
            sampleUV.y < 0.0 || sampleUV.y > 1.0) break;

        float sampleDepth = texture2D(depthtex0, sampleUV).r;
        if (sampleDepth >= 1.0) continue; // sky, no occluder

        vec3 sampleViewPos = getViewPos(sampleUV, sampleDepth);

        // If real geometry sits closer to the camera than our marching ray
        // at roughly the same point in space, something is blocking the light.
        if (sampleViewPos.z > rayPos.z + 0.08 && sampleViewPos.z < rayPos.z + 1.5) {
            float closeness = 1.0 - (float(i) / float(STEPS));
            result = mix(1.0, 0.6, closeness);
            break;
        }
    }
    return result;
}

// Projects a light direction (view-space) out to a far point and finds
// where that lands on screen - i.e. where the sun/moon appears visually.
vec2 getLightScreenPos(vec3 lightDirView) {
    vec4 clip = gbufferProjection * vec4(lightDirView * 100.0, 1.0);
    return (clip.xy / clip.w) * 0.5 + 0.5;
}

// Screen-space volumetric light scattering ("god rays"). Radially samples
// toward the light's screen position; unoccluded (sky) samples add light,
// with an exponential decay the further out the ray travels.
float godRays(vec2 uv, vec2 lightScreenPos) {
    const int NUM_SAMPLES = 40;
    const float DECAY = 0.965;
    const float DENSITY = 0.9;

    vec2 deltaUV = (uv - lightScreenPos) * (DENSITY / float(NUM_SAMPLES));
    vec2 sampleUV = uv;
    float illum = 0.0;
    float currentDecay = 1.0;

    for (int i = 0; i < NUM_SAMPLES; i++) {
        sampleUV -= deltaUV;
        float depth = texture2D(depthtex0, sampleUV).r;
        float skyMask = depth >= 0.9999 ? 1.0 : 0.0;
        illum += skyMask * currentDecay;
        currentDecay *= DECAY;
    }
    return illum / float(NUM_SAMPLES);
}

// Multi-directional streak bloom for emissive blocks (torches, lava,
// glowstone...). Cheap approximation of a radiant glow/star filter.
vec3 lightStreaks(vec2 uv) {
    vec2 dirs[4];
    dirs[0] = vec2(1.0, 0.0);
    dirs[1] = vec2(0.0, 1.0);
    dirs[2] = vec2(0.707, 0.707);
    dirs[3] = vec2(-0.707, 0.707);

    vec3 streak = vec3(0.0);
    for (int d = 0; d < 4; d++) {
        for (int i = 1; i <= 6; i++) {
            vec2 offset = dirs[d] * float(i) * 0.0035;
            vec3 s1 = texture2D(colortex0, uv + offset).rgb;
            vec3 s2 = texture2D(colortex0, uv - offset).rgb;
            float b1 = max(dot(s1, vec3(0.299, 0.587, 0.114)) - 0.78, 0.0);
            float b2 = max(dot(s2, vec3(0.299, 0.587, 0.114)) - 0.78, 0.0);
            float falloff = 1.0 / float(i);
            streak += (s1 * b1 + s2 * b2) * falloff;
        }
    }
    return streak * 0.05;
}

void main() {
    vec3 col = texture2D(colortex0, vTexCoord).rgb;

    // Smooth sun/moon blend (matches gbuffers_terrain.fsh - avoids the
    // lighting/ray direction "popping" right at the day/night cutoff)
    float sunHeight = sunPosition.y / length(sunPosition);
    float sunVisibility = smoothstep(-0.05, 0.15, sunHeight);
    vec3 lightDirView = normalize(mix(moonPosition, sunPosition, sunVisibility));

    float contact = contactShadow(vTexCoord, lightDirView);
    col *= mix(1.0, contact, 0.3); // subtle blend, no crushed-black patches

    // God rays: only from the sun (moon rays are barely visible anyway and
    // it keeps this cheap), fade out below the horizon and in rain/storms.
    vec2 sunScreenPos = getLightScreenPos(normalize(sunPosition));
    float sunFade = smoothstep(-0.02, 0.1, sunHeight) * (1.0 - rainStrength);
    if (sunFade > 0.001 &&
        sunScreenPos.x > -0.6 && sunScreenPos.x < 1.6 &&
        sunScreenPos.y > -0.6 && sunScreenPos.y < 1.6) {
        float rays = godRays(vTexCoord, sunScreenPos) * sunFade;
        col += vec3(1.0, 0.88, 0.65) * rays * 0.6;
    }

    // Radiant glow for emissive blocks (torches/lava/glowstone/etc.)
    col += lightStreaks(vTexCoord);

    // Saturation boost
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, 1.15);

    // Cheap bloom: average bright neighboring pixels and add them back in
    vec3 bloom = vec3(0.0);
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * 0.0025;
            vec3 s = texture2D(colortex0, vTexCoord + offset).rgb;
            float brightness = max(dot(s, vec3(0.299, 0.587, 0.114)) - 0.7, 0.0);
            bloom += s * brightness;
        }
    }
    bloom /= 25.0;
    col += bloom * 0.6;

    // Vignette
    vec2 uv = vTexCoord - 0.5;
    float vig = 1.0 - dot(uv, uv) * 0.6;
    col *= vig;

    // Slightly flatten/desaturate during rain
    col = mix(col, col * 0.85, rainStrength * 0.5);

    gl_FragColor = vec4(col, 1.0);
}
