#version 120
/* NovaShine - gbuffers_textured
   Particles, held items, GUI-adjacent textured quads */

varying vec2 vTexCoord;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    vTexCoord = gl_MultiTexCoord0.xy;
    vColor = gl_Color;
}
