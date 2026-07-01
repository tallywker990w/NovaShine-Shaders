#version 120
/* NovaShine - shadow (vertex)
   Renders scene geometry from the light's point of view into the shadow map.
   Iris/OptiFine automatically supplies shadowModelView/shadowProjection here. */

varying vec2 vTexCoord;

void main() {
    gl_Position = ftransform();
    vTexCoord = gl_MultiTexCoord0.xy;
}
