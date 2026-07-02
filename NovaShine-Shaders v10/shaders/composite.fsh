#version 120
/* NovaShine - composite (fragment)
   v4: quality profiles.
   CONTACT_SHADOWS, GOD_RAY_SAMPLES, and BLOOM_QUALITY are real Iris/
   OptiFine shader options now (see shaders.properties for the Potato/Low/
   Medium/High/Ultra profiles that set them together with the terrain-
   shader options). Setting GOD_RAY_SAMPLES to 0 disables god rays
   entirely (skips the whole effect, not just a 0-sample loop) and
   BLOOM_QUALITY 0 does the same for bloom.

   Post-processing pass:
   - Screen-space ray-marched "contact shadows"
   - Screen-space volumetric "god rays" from the sun, localized around the
     sun and modulated by the real shadow map
   - Radiant glow/streak treatment for emissive blocks (torches, lava,
     glowstone, etc.)
   - Cheap bloom, saturation boost, vignette
   - Stylized rain streak overlay + rain color grading

   ABOUT "GOD RAYS": Iris/OptiFine shaderpacks run on plain OpenGL, so
   there's no hardware ray-tracing API here. What this uses is
   "screen-space volumetric light scattering" (GPU Gems 3, Ch. 13) -
   the same category of technique most game engines use for this effect.

   ABOUT SHADOWS x GOD RAYS: the god-ray contribution for a pixel is
   multiplied by that pixel's own real shadow-map result, so if you're
   standing in a tree/building's shadow you don't get an extra sunbeam
   glow on top of it - the beams "respect" the shadow map. */

#define CONTACT_SHADOWS 1 // [0 1] Screen-space contact shadows. 0=off (better FPS) 1=on
#define GOD_RAY_SAMPLES 40 // [0 16 24 40 64] God ray quality. 0 disables god rays entirely.
#define BLOOM_QUALITY 2 // [0 1 2 3] Bloom kernel size. 0=off 1=3x3(cheap) 2=5x5 3=7x7(expensive)

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D lightmap;  // <-- Added this line to fix the error

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec2 vTexCoord;

// Reconstructs a view-space position from the depth buffer at a given UV
vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clip;
    return viewPos.xyz / viewPos.w;
}

// Cheap per-pixel pseudo-random value
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

#if CONTACT_SHADOWS
// Marches a short ray from the surface toward the light and checks whether
// it runs into closer geometry along the way. Returns 1.0 = unoccluded,
// fading down to ~0.6 the closer/harder the occlusion.
float contactShadow(vec2 uv, vec3 lightDirView) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 1.0; // sky - skip

    vec3 viewPos = getViewPos(uv, depth);

    const int STEPS = 8;
    const float STEP_SIZE = 0.30;

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
        if (sampleDepth >= 1.0) continue;

        vec3 sampleViewPos = getViewPos(sampleUV, sampleDepth);

        if (sampleViewPos.z > rayPos.z + 0.08 && sampleViewPos.z < rayPos.z + 1.5) {
            float closeness = 1.0 - (float(i) / float(STEPS));
            result = mix(1.0, 0.6, closeness);
            break;
        }
    }
    return result;
}
#endif

#if GOD_RAY_SAMPLES > 0
// Real shadow-map lookup for a screen pixel (approximate: fixed bias, no
// normal-offset since we don't have per-pixel normals here - this is only
// used to modulate the god-ray glow, not for the main shadows, so a small
// amount of acne here doesn't matter).
float getPixelShadow(vec2 uv) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 1.0; // sky counts as "lit" so rays show against it

    vec3 viewPos = getViewPos(uv, depth);
    vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
    vec4 shadowClip = shadowProjection * shadowModelView * worldPos;
    vec3 shadowCoord = shadowClip.xyz * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
        shadowCoord.y < 0.0 || shadowCoord.y > 1.0 ||
        shadowCoord.z < 0.0 || shadowCoord.z > 1.0) {
        return 1.0;
    }

    float bias = 0.0025;
    float shadowDepth = texture2D(shadowtex0, shadowCoord.xy).r;
    return (shadowCoord.z - bias <= shadowDepth) ? 1.0 : 0.5;
}

vec2 getLightScreenPos(vec3 lightDirView) {
    vec4 clip = gbufferProjection * vec4(lightDirView * 100.0, 1.0);
    return (clip.xy / clip.w) * 0.5 + 0.5;
}

// Screen-space volumetric light scattering ("god rays"), localized around
// the sun via a screen-distance falloff (not a flat sky-wide haze).
float godRays(vec2 uv, vec2 lightScreenPos) {
    const float DECAY = 0.965;
    const float DENSITY = 0.9;

    float distFromSun = length(uv - lightScreenPos);
    float proximity = exp(-distFromSun * distFromSun * 3.0);
    if (proximity < 0.01) return 0.0;

    vec2 deltaUV = (uv - lightScreenPos) * (DENSITY / float(GOD_RAY_SAMPLES));
    vec2 sampleUV = uv;
    float illum = 0.0;
    float currentDecay = 1.0;

    for (int i = 0; i < GOD_RAY_SAMPLES; i++) {
        sampleUV -= deltaUV;
        float depth = texture2D(depthtex0, sampleUV).r;
        float skyMask = depth >= 0.9999 ? 1.0 : 0.0;
        illum += skyMask * currentDecay;
        currentDecay *= DECAY;
    }
    return (illum / float(GOD_RAY_SAMPLES)) * proximity;
}
#endif

// Multi-directional streak bloom for emissive blocks (torches, lava, etc.)
// Kept independent of BLOOM_QUALITY since it's what makes torches/lava
// actually read as light sources - only disabled at BLOOM_QUALITY 0.
#if BLOOM_QUALITY > 0
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
#endif

// Stylized procedural rain streak overlay - independent of the actual
// rain particles, this adds a subtle "rain on the lens/atmosphere" feel.
// Now fades out when indoors (using skylight from lightmap).
float rainOverlay(vec2 uv) {
    uv.x += frameTimeCounter * 0.05;
    uv.y += frameTimeCounter * 1.3;
    uv *= vec2(24.0, 10.0);

    vec2 cell = floor(uv);
    vec2 local = fract(uv) - 0.5;
    float n = hash12(cell);

    float streak = smoothstep(0.05, 0.0, abs(local.x + 0.15 * local.y)) *
                    smoothstep(0.5, 0.0, abs(local.y));
    return streak * step(0.82, n);
}

void main() {
    vec3 col = texture2D(colortex0, vTexCoord).rgb;

    float sunHeight = sunPosition.y / length(sunPosition);
    float sunVisibility = smoothstep(-0.05, 0.15, sunHeight);
    vec3 lightDirView = normalize(mix(moonPosition, sunPosition, sunVisibility));

#if CONTACT_SHADOWS
    float contact = contactShadow(vTexCoord, lightDirView);
    col *= mix(1.0, contact, 0.3);
#endif

#if GOD_RAY_SAMPLES > 0
    // God rays: fade out below the horizon and quickly fade out as rain
    // picks up (and back in again once it clears, since rainStrength is
    // just a smoothly-interpolated value Iris/OptiFine updates for us).
    vec2 sunScreenPos = getLightScreenPos(normalize(sunPosition));
    float rainFade = 1.0 - smoothstep(0.05, 0.35, rainStrength);
    float sunFade = smoothstep(-0.02, 0.1, sunHeight) * rainFade;

    if (sunFade > 0.001 &&
        sunScreenPos.x > -0.6 && sunScreenPos.x < 1.6 &&
        sunScreenPos.y > -0.6 && sunScreenPos.y < 1.6) {
        float pixelShadow = getPixelShadow(vTexCoord);
        float rays = godRays(vTexCoord, sunScreenPos) * sunFade * pixelShadow;
        col += vec3(1.0, 0.88, 0.65) * rays * 0.8;
    }
#endif

#if BLOOM_QUALITY > 0
    col += lightStreaks(vTexCoord);
#endif

    // Saturation boost
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, 1.15);

#if BLOOM_QUALITY > 0
    // Cheap bloom - kernel radius set by BLOOM_QUALITY (1=3x3, 2=5x5, 3=7x7)
    vec3 bloom = vec3(0.0);
    float bloomSamples = 0.0;
    for (int x = -BLOOM_QUALITY; x <= BLOOM_QUALITY; x++) {
        for (int y = -BLOOM_QUALITY; y <= BLOOM_QUALITY; y++) {
            vec2 offset = vec2(float(x), float(y)) * 0.0025;
            vec3 s = texture2D(colortex0, vTexCoord + offset).rgb;
            float brightness = max(dot(s, vec3(0.299, 0.587, 0.114)) - 0.8, 0.0);
            bloom += s * brightness;
            bloomSamples += 1.0;
        }
    }
    bloom /= bloomSamples;
    col += bloom * 0.5;
#endif

    // Vignette
    vec2 uv = vTexCoord - 0.5;
    float vig = 1.0 - dot(uv, uv) * 0.6;
    col *= vig;

    // Rain: cooler/flatter color grade + the procedural streak overlay
    vec3 luma3 = vec3(dot(col, vec3(0.299, 0.587, 0.114)));
    vec3 rainGraded = mix(col, luma3, 0.35) * vec3(0.85, 0.92, 1.05) * 0.85;
    col = mix(col, rainGraded, rainStrength);

    // Rain overlay - now disappears when indoors
    float overlay = rainOverlay(vTexCoord) * rainStrength;
    float skyExposure = texture2D(lightmap, vTexCoord).g; // skylight from lightmap
    overlay *= skyExposure * skyExposure; // quadratic fade indoors

    col += vec3(0.65, 0.72, 0.85) * overlay * 0.5;

    gl_FragColor = vec4(col, 1.0);
}