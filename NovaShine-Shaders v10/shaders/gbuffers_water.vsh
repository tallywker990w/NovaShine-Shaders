#version 120
/* NovaShine - gbuffers_water (vertex)
   Displaces the top surface of water vertically with layered sine waves
   to create a rolling, animated water surface. */

uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vViewDir;

void main() {
    vec4 pos = gl_Vertex;
    vec4 world = gbufferModelViewInverse * (gl_ModelViewMatrix * pos);

    // Only animate upward-facing water surfaces (top of the water block)
    if (gl_Normal.y > 0.5) {
        float wave =
              sin(world.x * 0.6  + frameTimeCounter * 1.6) * 0.035
            + sin(world.z * 0.8  + frameTimeCounter * 2.2) * 0.025
            + sin((world.x + world.z) * 0.35 + frameTimeCounter * 1.1) * 0.02;
        pos.y += wave;
    }

    gl_Position = gl_ModelViewProjectionMatrix * pos;

    vTexCoord = gl_MultiTexCoord0.xy;
    vColor = gl_Color;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);
    vViewDir = normalize(-(gl_ModelViewMatrix * pos).xyz);
}
