#version 120
/* NovaShine - gbuffers_weather (fragment)
   Stylizes rain/snow: cool blue tint, a soft brightness boost so drops
   catch the light instead of looking like flat grey streaks, and a bit
   of extra contrast on the alpha so streaks read as crisper glints. */

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec4 vColor;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.02) discard;

    vec3 col = tex.rgb * vColor.rgb;
    col *= vec3(0.92, 0.97, 1.12); // cool blue tint
    col *= 1.25; // glinting highlight boost

    // Sharpen the alpha falloff a little so drops look crisper, not soft/blurry
    float alpha = pow(tex.a, 0.85) * vColor.a;

    gl_FragColor = vec4(col, alpha);
}
