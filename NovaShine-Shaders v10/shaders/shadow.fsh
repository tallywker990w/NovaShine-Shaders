#version 120
/* NovaShine - shadow (fragment)
   Alpha-tests against the block texture so leaves/glass/foliage don't
   cast solid rectangular shadows. */

uniform sampler2D texture;
varying vec2 vTexCoord;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.5) discard;
    gl_FragColor = vec4(1.0);
}
