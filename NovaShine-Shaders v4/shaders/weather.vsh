#version 120
/* NovaShine - weather (vertex)
   Stretches rain particles into razor-thin vertical needles 
   resembling Complementary Unbound's velocity sheets. */

varying vec2 texCoord;
varying vec4 glColor;
varying vec3 position;

uniform float frameTimeCounter;

void main() {
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    glColor = gl_Color;

    vec4 pos = gl_Vertex;

    // Isolate falling rain blocks (cross-quad sheets have flat horizontal normals)
    if (gl_Normal.y == 0.0) { 
        // 1. Massive vertical stretch to create long needle trails
        pos.y *= 3.5; 

        // 2. Make them ultra-thin on the horizontal axes
        pos.x *= 0.15;
        pos.z *= 0.15;

        // 3. Add fake vertical velocity so the needles look like they are tearing down
        pos.y -= fract(frameTimeCounter * 8.0) * 0.5;
    }

    gl_Position = gl_ModelViewProjectionMatrix * pos;
    position = pos.xyz;
}