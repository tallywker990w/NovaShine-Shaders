#version 120
/* NovaShine - gbuffers_basic
   Fallback program: sky, weather, misc unlit geometry */

varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    vColor = gl_Color;
}
