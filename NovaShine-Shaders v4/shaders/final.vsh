#version 120
/* NovaShine - final (vertex)
   Full-screen quad pass-through */

varying vec2 vTexCoord;

void main() {
    gl_Position = ftransform();
    vTexCoord = gl_MultiTexCoord0.xy;
}
