#version 120
/* NovaShine - shadow (vertex)
   Renders scene geometry from the light's point of view into the shadow map.
   Iris/OptiFine automatically supplies shadowModelView/shadowProjection here.

   These two consts are special engine-recognized names (not custom
   options) - Iris uses them to size the actual shadow map texture and
   shadow frustum. The bracketed comment turns each into a selectable
   option in the Shaderpack Settings screen, and the NovaShine quality
   profiles (see shaders.properties) set them together. */

const int shadowMapResolution = 2048; // [512 1024 2048 3072 4096] Shadow map resolution - higher = sharper shadows, lower = better FPS
const float shadowDistance = 100.0; // [50.0 75.0 100.0 140.0 200.0] How far shadows render, in blocks

varying vec2 vTexCoord;

void main() {
    gl_Position = ftransform();
    vTexCoord = gl_MultiTexCoord0.xy;
}
