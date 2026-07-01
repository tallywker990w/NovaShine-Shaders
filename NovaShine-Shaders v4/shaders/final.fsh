#version 120
/* NovaShine - final (fragment)
   Reinhard tonemap + gentle gamma lift. Last pass before the screen. */

uniform sampler2D colortex0;
varying vec2 vTexCoord;

void main() {
    vec3 col = texture2D(colortex0, vTexCoord).rgb;

    // Reinhard tonemapping to tame bloom/highlights
    col = col / (col + vec3(1.0));

    // Gentle gamma lift
    col = pow(col, vec3(1.0 / 1.05));

    gl_FragColor = vec4(col, 1.0);
}
