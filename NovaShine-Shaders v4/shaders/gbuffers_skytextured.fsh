#version 120
/* NovaShine - gbuffers_skytextured (fragment)
   Masks the sun/moon's square texture quad into a clean circle, with a
   soft glow-falloff edge, and brightens the sun a little so it reads
   as a real light source in the sky rather than a flat sprite. */

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec4 vColor;

void main() {
    vec2 centered = vTexCoord - 0.5;
    float dist = length(centered);

    // Hard circular cutoff with a soft antialiased edge
    float mask = 1.0 - smoothstep(0.40, 0.46, dist);
    if (mask <= 0.0) discard;

    vec4 tex = texture2D(texture, vTexCoord);
    vec3 col = tex.rgb * vColor.rgb * 1.25; // small brightness boost

    gl_FragColor = vec4(col, tex.a * vColor.a * mask);
}
