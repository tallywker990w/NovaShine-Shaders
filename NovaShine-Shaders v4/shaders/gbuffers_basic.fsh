#version 120
/* NovaShine - gbuffers_basic (fragment) */

uniform float rainStrength;

varying vec4 vColor;

void main() {
    vec3 col = vColor.rgb;
    // Slightly desaturate / cool the color during rain
    col = mix(col, col * 0.82 + vec3(0.04, 0.05, 0.07), rainStrength);
    gl_FragColor = vec4(col, vColor.a);
}
