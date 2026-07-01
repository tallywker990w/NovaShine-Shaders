#version 120
/* NovaShine - gbuffers_clouds (fragment)
   Warmer sunset/sunrise tinting, greyer/darker during storms, and a
   gentle brightness lift so clouds read as soft and voluminous rather
   than flat. */

uniform vec3 sunPosition;
uniform float rainStrength;

varying vec4 vColor;

void main() {
    vec3 col = vColor.rgb;

    float sunHeight = sunPosition.y / length(sunPosition);
    // Peaks near the horizon (sunrise/sunset), fades out at midday/midnight
    float duskFactor = 1.0 - smoothstep(0.0, 0.55, abs(sunHeight));

    vec3 warmTint = vec3(1.20, 0.82, 0.62);
    col = mix(col, col * warmTint, duskFactor * 0.55);

    // Gentle lift so clouds don't look flat/grey
    col = col * 1.05 + 0.02;

    // Storms: darker, greyer, flatter clouds
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(luma) * 0.65, rainStrength);

    gl_FragColor = vec4(col, vColor.a);
}
