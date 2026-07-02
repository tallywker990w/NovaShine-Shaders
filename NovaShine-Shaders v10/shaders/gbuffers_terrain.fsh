#version 120
/* NovaShine - gbuffers_terrain (fragment)
   v7: quality profiles.
   shadowMapResolution/shadowDistance/SHADOW_SAMPLES/PUDDLES are now real
   Iris/OptiFine shader options (see shaders.properties for the Potato/Low/
   Medium/High/Ultra profiles that set them together). The shadow bias and
   texel size used to be hardcoded for 2048 res / 100 block distance - now
   they scale automatically with whatever profile is active. */

// Must be declared identically to shadow.vsh (same name+value list = same
// option, switched together everywhere it appears).
const int shadowMapResolution = 2048; // [512 1024 2048 3072 4096] Shadow map resolution - higher = sharper shadows, lower = better FPS
const float shadowDistance = 100.0; // [50.0 75.0 100.0 140.0 200.0] How far shadows render, in blocks

#define SHADOW_SAMPLES 2 // [0 1 2 3] Shadow softness (PCF kernel radius). 0=hard/cheapest 3=softest/most expensive
#define PUDDLES 1 // [0 1] Rain puddles on exposed ground. 0=off (better FPS in rain) 1=on

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform float rainStrength;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec4 vWorldPos;

// PCF shadow sample, kernel size controlled by SHADOW_SAMPLES. Normal-offset
// + slope-scaled bias (both scaled to the actual shadowMapResolution/
// shadowDistance in use) to kill acne at any quality tier.
float getShadow(vec4 worldPosition, vec3 worldNormal, float NdotL) {
    // World-space size of one shadow-map texel at the current resolution/
    // distance - this is what the old hardcoded "0.06" was standing in for.
    float texelWorldSize = (shadowDistance * 2.0) / float(shadowMapResolution);
    vec3 offsetPos = worldPosition.xyz + worldNormal * (texelWorldSize * 1.5);

    vec4 shadowClip = shadowProjection * shadowModelView * vec4(offsetPos, 1.0);
    vec3 shadowCoord = shadowClip.xyz * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
        shadowCoord.y < 0.0 || shadowCoord.y > 1.0 ||
        shadowCoord.z < 0.0 || shadowCoord.z > 1.0) {
        return 1.0;
    }

    float bias = mix(0.0035, 0.0009, NdotL);
    float texel = 1.0 / float(shadowMapResolution);

    float shadow = 0.0;
    float samples = 0.0;
    for (int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++) {
        for (int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++) {
            float depth = texture2D(shadowtex0, shadowCoord.xy + vec2(float(x), float(y)) * texel).r;
            shadow += (shadowCoord.z - bias <= depth) ? 1.0 : 0.0;
            samples += 1.0;
        }
    }
    return shadow / samples;
}

#if PUDDLES
// Cheap 2D value noise, used to shape irregular puddle blobs
// Renamed (nova_*) to avoid conflict with Iris internals (terrain_solid.fsh etc.)
float nova_hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float nova_noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = nova_hash2(i);
    float b = nova_hash2(i + vec2(1.0, 0.0));
    float c = nova_hash2(i + vec2(0.0, 1.0));
    float d = nova_hash2(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
#endif

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.1) discard;

    vec3 lightmapColor = texture2D(lightmap, vLightmap).rgb;

    float sunHeight = sunPosition.y / length(sunPosition);
    float sunVisibility = smoothstep(-0.05, 0.15, sunHeight);

    vec3 lightDir = normalize(mix(moonPosition, sunPosition, sunVisibility));
    float lightStrength = mix(0.45, 1.0, sunVisibility);
    vec3 lightColor = mix(vec3(0.55, 0.65, 0.85), vec3(1.05, 0.95, 0.82), sunVisibility);

    vec3 n = normalize(vNormal);
    vec3 wn = normalize(vWorldNormal);
    float NdotL = max(dot(n, lightDir), 0.0);
    float shadow = getShadow(vWorldPos, wn, NdotL);

    vec3 base = tex.rgb * vColor.rgb * lightmapColor;

    // Warm glow boost for light-emitting blocks (torches, lava, glowstone,
    // etc.). vLightmap.x is the raw block-light coordinate, which rises the
    // closer a surface is to an actual light source.
    float blockLight = vLightmap.x;
    vec3 emissiveGlow = tex.rgb * vColor.rgb * vec3(1.0, 0.55, 0.22) * pow(blockLight, 4.0) * 0.9;
    base += emissiveGlow;

    float sunPop = NdotL * shadow * lightStrength * 0.35;
    vec3 col = base + base * sunPop * lightColor;

    // Storms flatten contrast and dim things slightly
    col = mix(col, col * 0.7, rainStrength);

#if PUDDLES
    // Rain puddles: only on upward-facing, sky-exposed surfaces
    float topFacing = smoothstep(0.55, 0.9, wn.y);
    float skylight = vLightmap.y; // raw skylight coordinate, 0=indoors/covered, 1=open sky
    if (topFacing > 0.01 && skylight > 0.4 && rainStrength > 0.01) {
        vec3 absoluteWorldPos = vWorldPos.xyz + cameraPosition;
        float puddleNoise = nova_noise2(absoluteWorldPos.xz * 0.15);
        float puddleMask = smoothstep(0.5, 0.62, puddleNoise) * topFacing * skylight * rainStrength;

        if (puddleMask > 0.005) {
            vec3 viewDir = normalize(-vWorldPos.xyz);
            vec3 h = normalize(lightDir + viewDir);
            float puddleSpec = pow(max(dot(wn, h), 0.0), 90.0);
            vec3 skyTint = mix(vec3(0.45, 0.55, 0.7), lightColor, 0.4);

            col = mix(col, col * 0.55 + skyTint * 0.35, puddleMask);
            col += lightColor * puddleSpec * puddleMask * shadow * 1.1;
        }
    }
#endif

    col *= vec3(1.02, 1.0, 0.97); // subtle overall warm grade

    gl_FragColor = vec4(col, tex.a * vColor.a);
}