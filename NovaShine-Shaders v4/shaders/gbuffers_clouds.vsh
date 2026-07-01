#version 120
/* NovaShine - gbuffers_clouds (vertex)
   NOTE: cloud SHAPE/geometry (flat vs "fancy" extruded cuboids) is
   controlled by vanilla's own Video Settings > Clouds option - this
   shader only re-styles the coloring/lighting of whatever geometry
   vanilla hands us. */

varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    vColor = gl_Color;
}
