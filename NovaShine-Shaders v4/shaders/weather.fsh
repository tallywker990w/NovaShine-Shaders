#version 120
/* NovaShine - weather (fragment) 
   Complementary Unbound Style Light Rain */

varying vec2 texCoord;
varying vec4 glColor;

uniform sampler2D texture;
uniform float rainStrength;

void main() {
    vec4 color = texture2D(texture, texCoord) * glColor;

    // Set rain transparency to be extremely light and translucent
    color.a *= 0.12 * rainStrength; 

    // Silver/misty white glow instead of heavy dark blue streaks
    vec3 lightRainTint = vec3(0.9, 0.93, 0.96);
    color.rgb = mix(color.rgb, lightRainTint, 0.7);

    // Smoothly taper the edges of the particles to look like sleek teardrops
    float verticalFade = smoothstep(0.0, 0.2, texCoord.y) * smoothstep(1.0, 0.8, texCoord.y);
    color.a *= verticalFade;

    gl_FragColor = color;
}