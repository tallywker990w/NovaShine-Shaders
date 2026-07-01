#version 120
/* NovaShine - gbuffers_terrain (fragment)
   v7.0: Puddle logic completely removed. Ground surfaces stay dry 
   while weather shaders handle the atmospheric rain sheets. */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;

uniform mat4 gbufferModelViewInverse; 
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec4 vWorldPos;

// 5x5 PCF shadow sample, with normal-offset + slope-scaled bias to kill acne
float getShadow(vec4 worldPosition, vec3 worldNormal, float NdotL) {
    vec3 offsetPos = worldPosition.xyz + worldNormal * 0.06;

    vec4 shadowClip = shadowProjection * shadowModelView * vec4(offsetPos, 1.0);
    vec3 shadowCoord = shadowClip.xyz * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.x > 1.0 ||
        shadowCoord.y < 0.0 || shadowCoord.y > 1.0 ||
        shadowCoord.z < 0.0 || shadowCoord.z > 1.0) {
        return 1.0; 
    }

    float bias = mix(0.0035, 0.0009, NdotL);
    float shadow = 0.0;
    float texel = 1.0 / 2048.0; 

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float depth = texture2D(shadowtex0, shadowCoord.xy + vec2(float(x), float(y)) * texel).r;
            shadow += (shadowCoord.z - bias <= depth) ? 1.0 : 0.0;
        }
    }
    return shadow / 25.0;
}

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

    vec3 texColor = tex.rgb;

    // Base lighting calculation
    vec3 base = texColor * vColor.rgb * lightmapColor;

    float sunPop = NdotL * shadow * lightStrength * 0.35;
    vec3 col = base + base * sunPop * lightColor;

    // Storms flatten contrast and dim things slightly
    col = mix(col, col * 0.7, rainStrength);

    col *= vec3(1.02, 1.0, 0.97); // subtle overall warm grade

    gl_FragColor = vec4(col, tex.a * vColor.a);
}