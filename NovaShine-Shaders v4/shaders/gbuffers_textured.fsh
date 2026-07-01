#version 120
/* NovaShine - gbuffers_textured (fragment) */

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec4 vColor;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.02) discard;
    gl_FragColor = tex * vColor;
}
