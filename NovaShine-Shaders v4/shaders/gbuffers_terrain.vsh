#version 120
/* NovaShine - gbuffers_terrain (vertex)
   Dynamic Wind Sway reacting heavily to thunderstorms */

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec4 vWorldPos;

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform float rainStrength;

// Simple hash function for unique block wind variance
float windHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    vColor = gl_Color;
    
    vNormal = normalize(gl_NormalMatrix * gl_Normal);
    vWorldNormal = normalize((gbufferModelViewInverse * vec4(vNormal, 0.0)).xyz);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vWorldPos = gbufferModelViewInverse * viewPos;

    // Identify foliage (cross quads or leaf layers) exposed to the elements
    if (gl_Normal.y == 0.0 && vLightmap.y > 0.5) {
        float uniqueOffset = windHash(vWorldPos.xz);

        // --- Thunderstorm Math Upgrades ---
        // Basic speed factor is 2.2, but scales up heavily with rain/thunder intensity
        float windSpeedModifier = mix(2.2, 5.5, rainStrength);
        float swayTime = frameTimeCounter * windSpeedModifier;

        // Basic sway amplitude scales up significantly during heavy storms
        float windIntensityModifier = mix(1.0, 2.8, rainStrength);
        float swayX = sin(swayTime + uniqueOffset * 10.0) * 0.05 * windIntensityModifier;
        float swayZ = cos(swayTime * 0.8 + uniqueOffset * 12.0) * 0.03 * windIntensityModifier;

        vWorldPos.x += swayX;
        vWorldPos.z += swayZ;
    }

    gl_Position = gl_ModelViewProjectionMatrix * (gl_ModelViewMatrixInverse * vWorldPos);
}