#version 120
/* NovaShine - gbuffers_water (fragment)
   v2: reflection quality pass.
   - Reflection tint now uses the same smooth sun-height blend as terrain
     lighting, so water reflects sunset/sunrise colors and cool moonlight
     instead of always reflecting flat daytime sky color.
   - Grazing-angle (near-horizon) reflections are boosted a bit further,
     which is what makes distant water look like a real reflective sheet
     instead of a flat tinted texture.
   - Specular highlight now also works with the moon at night.

   NOTE: this is still a Fresnel/sky-tint approximation, not a true
   screen-space or ray-traced reflection - it won't show reflected trees,
   terrain, or clouds. A true SSR pass is a bigger follow-up if wanted. */

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 skyColor;
uniform float rainStrength;

varying vec2 vTexCoord;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vViewDir;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);

    vec3 n = normalize(vNormal);
    vec3 v = normalize(vViewDir);

    float sunHeight = sunPosition.y / length(sunPosition);
    float sunVisibility = smoothstep(-0.05, 0.15, sunHeight);
    vec3 lightDir = normalize(mix(moonPosition, sunPosition, sunVisibility));
    vec3 lightColor = mix(vec3(0.55, 0.65, 0.85), vec3(1.05, 0.95, 0.82), sunVisibility);

    // Fresnel term: more reflective at grazing angles, less when looking straight down
    float NdotV = max(dot(n, v), 0.0);
    float fresnel = pow(1.0 - NdotV, 4.0);
    fresnel = clamp(fresnel * 1.0 + 0.08, 0.0, 1.0);

    vec3 deepWater = vec3(0.02, 0.09, 0.14);
    vec3 skyReflect = mix(skyColor, vec3(1.0), 0.15) * mix(vec3(1.0), lightColor, 0.6);

    vec3 base = mix(deepWater, tex.rgb * vColor.rgb, 0.35);
    vec3 col = mix(base, skyReflect, fresnel);

    // Sun/moon specular (Blinn-Phong highlight)
    vec3 h = normalize(lightDir + v);
    float specPower = mix(60.0, 120.0, sunVisibility); // tighter highlight in daylight
    float spec = pow(max(dot(n, h), 0.0), specPower);
    col += lightColor * spec * (1.0 - rainStrength) * mix(0.5, 1.0, sunVisibility);

    float alpha = mix(0.55, 0.88, fresnel);
    gl_FragColor = vec4(col, alpha);
}
