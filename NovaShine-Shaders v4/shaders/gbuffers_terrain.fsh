#version 120
/* NovaShine - gbuffers_terrain (fragment)
   v5.2: Dynamic Puddle Accumulation & Evaporation.
   Replaced instant rainStrength checks with the 'wetness' uniform, 
   allowing puddles to accumulate over time and slowly dry up over 
   30-60 seconds once the storm stops. */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;

uniform mat4 gbufferModelViewInverse; // Used to find the camera's view direction for reflections
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;
uniform float wetness;           // Dynamic weather transition variable (built into Iris/OptiFine)
uniform float frameTimeCounter; // Used for animating ripples

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec4 vWorldPos;

// Simple pseudo-random hash function for puddle distribution
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Generates animated ripples for the puddle surfaces
float getPuddleRipple(vec2 uv, float time) {
    float ripple = 0.0;
    for(int i = 0; i < 2; i++) {
        vec2 center = vec2(hash(vec2(float(i), 1.0)), hash(vec2(float(i), 5.0)));
        float distanceVal = distance(uv, center);
        float t = fract(time * 0.6 + float(i) * 0.5);
        ripple += sin((distanceVal - t) * 25.0) * max(0.0, 1.0 - distanceVal * 5.0) * (1.0 - t);
    }
    return ripple;
}

// A simple procedural sky color generator based on your current sunHeight/lightColor
vec3 getSkyReflection(vec3 reflectVector, float sunVisibility, vec3 currentLightColor) {
    vec3 baseSky = mix(vec3(0.1, 0.12, 0.18), vec3(0.4, 0.42, 0.45), sunVisibility);
    vec3 horizonGradient = currentLightColor * 0.15;
    
    vec3 skyColor = mix(baseSky, baseSky + horizonGradient, max(0.0, 1.0 - reflectVector.y));
    return skyColor * 0.6; 
}

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

    // --- Rain Puddle Calculation ---
    float puddleMask = 0.0;
    vec3 reflectionColor = vec3(0.0);
    float reflectionStrength = 0.0;

    // Check if surface faces upward and blocks are exposed to open sky
    // Utilizing 'wetness' instead of 'rainStrength' keeps puddles around after storm stops
    if (wn.y > 0.85 && wetness > 0.0 && vLightmap.y > 0.85) {
        vec2 puddleUV = vWorldPos.xz * 0.15; 
        
        // Bilinear Grid Noise Generation
        vec2 i = floor(puddleUV);
        vec2 f = fract(puddleUV);
        vec2 u = f * f * (3.0 - 2.0 * f); 

        float mixNoise = mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
                             mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);

        // Adjust threshold based on wetness so puddle boundaries contract organically as they dry
        float threshold = mix(0.65, 0.35, wetness); 
        puddleMask = clamp((mixNoise - threshold) * 5.0, 0.0, 1.0);

        if (puddleMask > 0.02) {
            // Distort normal with animated water waves (ripples fade out if it's no longer actively raining)
            float rippleStrength = rainStrength; 
            float ripple = getPuddleRipple(fract(vWorldPos.xz * 0.5), frameTimeCounter) * rippleStrength;
            
            wn.x += ripple * 0.04 * puddleMask;
            wn.z += ripple * 0.04 * puddleMask;
            wn = normalize(wn);

            n.x += ripple * 0.02 * puddleMask;
            n.z += ripple * 0.02 * puddleMask;
            n = normalize(n);

            // Compute Reflection Vectors
            vec3 viewDir = normalize(vWorldPos.xyz); 
            vec3 reflectDir = reflect(viewDir, wn);

            // Fetch sky tint based on day/night factors
            reflectionColor = getSkyReflection(reflectDir, sunVisibility, lightColor);

            // Fresnel equation
            float fresnel = pow(1.0 - max(0.0, dot(-viewDir, wn)), 5.0);
            reflectionStrength = mix(0.15, 0.75, fresnel) * puddleMask;
        }
    }

    float NdotL = max(dot(n, lightDir), 0.0);
    float shadow = getShadow(vWorldPos, wn, NdotL);

    // Wet texture look: Darken areas where puddles accumulate
    vec3 texColor = tex.rgb;
    texColor = mix(texColor, texColor * 0.55, puddleMask);

    // Base lighting calculation
    vec3 base = texColor * vColor.rgb * lightmapColor;

    float sunPop = NdotL * shadow * lightStrength * 0.35;
    vec3 col = base + base * sunPop * lightColor;

    // Layer reflection color over the top of the dark puddle sections
    if (puddleMask > 0.02) {
        col = mix(col, reflectionColor, reflectionStrength);
    }

    // Storms flatten contrast and dim things slightly
    col = mix(col, col * 0.7, rainStrength);

    col *= vec3(1.02, 1.0, 0.97); // subtle overall warm grade

    gl_FragColor = vec4(col, tex.a * vColor.a);
}