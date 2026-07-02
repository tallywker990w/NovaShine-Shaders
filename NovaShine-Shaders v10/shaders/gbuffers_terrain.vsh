#version 120
/* NovaShine - gbuffers_terrain (vertex)
   Handles solid terrain blocks. Passes world-space position so the
   fragment shader can project it into shadow space for shadow mapping. */

#define WAVING_PLANTS 1 // [0 1] Wind-swaying grass, plants, and leaves. 0=off (better FPS) 1=on

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

// Iris/OptiFine special vertex attributes, populated via block.properties
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec4 vWorldPos;

void main() {
    vec4 pos = gl_Vertex;

#if WAVING_PLANTS
    bool isPlant = mc_Entity.x == 10001.0;
    bool isLeaf  = mc_Entity.x == 10002.0;

    if (isPlant || isLeaf) {
        vec4 world = gbufferModelViewInverse * (gl_ModelViewMatrix * pos);

        float sway = sin(world.x * 0.9 + frameTimeCounter * 2.2)
                   + sin(world.z * 0.7 + frameTimeCounter * 1.6) * 0.7;

        if (isPlant) {
            // Grass/ferns/flowers/crops: cross-quads with a "planted" base.
            // Only sway the TOP vertices (mc_midTexCoord tells us where the
            // texture's vertical midpoint is) so the bottom stays anchored
            // to the ground - the classic OptiFine grass-wave trick.
            if (gl_MultiTexCoord0.y < mc_midTexCoord.y) {
                pos.x += sway * 0.09;
                pos.z += sway * 0.09 * 0.6;
            }
        } else {
            // Leaves: full cube blocks with no "base" to anchor to, so ALL
            // vertices sway together (gating by mc_midTexCoord here would
            // move some vertices of the same cube and not others, causing
            // visible shearing/warping within a single leaf block). Kept
            // to a small amplitude since large motion on a full cube will
            // open visible gaps between neighboring leaf blocks.
            pos.x += sway * 0.045;
            pos.z += sway * 0.045 * 0.6;
        }
    }
#endif

    gl_Position = gl_ModelViewProjectionMatrix * pos;

    vTexCoord = gl_MultiTexCoord0.xy;
    // Vanilla's baked lightmap coordinate (sky brightness + torch/block light).
    // Sampling this in the fragment shader is what keeps daylight looking
    // correctly bright instead of falling back to a flat low ambient value.
    vLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);

    // World-space normal (used to push the shadow sample point off the
    // surface a little, which prevents the surface from self-shadowing
    // itself into acne/banding patterns).
    vWorldNormal = normalize(mat3(gbufferModelViewInverse) * vNormal);

    // Reconstruct a world-space (camera-relative) position for shadow projection.
    // Uses the (possibly wind-swayed) position so grass shadows match its sway.
    vWorldPos = gbufferModelViewInverse * (gl_ModelViewMatrix * pos);
}
