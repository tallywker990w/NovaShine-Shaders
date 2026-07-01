NovaShine Shaders (Iris / OptiFine-format shader pack)
========================================================
Target: Minecraft Java Edition 1.21.1
Loader: Iris (works on Fabric AND NeoForge 1.21.1+, and bundles Sodium
        automatically — you do not need to install Sodium separately)

WHAT'S INSIDE
-------------
- Directional sun/moon lighting, built on top of Minecraft's own lightmap
  (sky + torch/block light) so daytime brightness matches vanilla, with
  a 5x5 PCF shadow map layered on top for soft-edged real shadows.
  Sun/moon light direction, strength, and color blend smoothly with sun
  height instead of hard-switching at day/night.
- Screen-space ray-marched "contact shadows" for fine detail a shadow
  map alone would miss
- God rays (screen-space volumetric light scattering) from the sun, plus
  a radiant glow/streak effect for torches, lava, glowstone, and other
  emissive blocks
- Round sun and moon
- Restyled clouds: warm sunset/sunrise tint, darker/greyer in storms
- Wind-swaying grass, ferns, flowers, and crops (plus subtle leaf sway)
- Animated water: layered wave displacement, Fresnel-based reflection
  tint that shifts with sun/moon color, sun/moon specular highlight
- Post-processing: bloom, saturation boost, vignette, Reinhard tonemap
- Rain/storm response: dims and flattens lighting during weather

CHANGELOG (v4)
--------------
- ADDED: round sun and moon (new gbuffers_skytextured.vsh/fsh masks the
  vanilla square sun/moon quad into a circle with a soft edge and a small
  brightness boost).
- ADDED: better clouds (new gbuffers_clouds.vsh/fsh) - warm sunset/sunrise
  tinting, greyer/darker during storms, gentle brightness lift. Note:
  cloud SHAPE (flat vs "fancy" 3D) is still controlled by vanilla's own
  Video Settings > Clouds option; this only re-styles the coloring.
- ADDED: wind-swaying grass, ferns, flowers, and crops (new
  shaders/block.properties + vertex-shader displacement in
  gbuffers_terrain.vsh). Leaves get a much smaller, subtler sway as a
  bonus. Only the TOP of each plant sways - the base stays anchored to
  the ground, same technique classic OptiFine grass-wave shaders use.
- ADDED: god rays (screen-space volumetric light scattering from the sun)
  and a radiant glow/streak effect for emissive blocks (torches, lava,
  glowstone, etc.) - both in composite.fsh. See the comment at the top of
  that file for the honest explanation of what technique this actually
  is (not hardware ray tracing - see the shadows section above too).
- FIXED (again): sun lighting direction/strength/color now blends
  smoothly with sun height instead of using a hard isDay on/off switch,
  removing the lighting "pop" that happened right at the day/night
  cutoff. Applied consistently in gbuffers_terrain.fsh, gbuffers_water.fsh,
  and composite.fsh's contact shadows + god rays, so everything agrees
  on the same light direction at the same time.
- IMPROVED: water reflections now tint toward the same warm/cool sun-vs-
  moon color as the rest of the lighting (sunsets reflect orange, night
  reflects cool blue) and grazing-angle reflections are a bit stronger.
  Still a Fresnel/sky-tint approximation, not true SSR - see limitations.

CHANGELOG (v3)
--------------
- FIXED: shadow acne (the diagonal banding/blotchy pattern on walls
  reported in-game, especially visible indoors). Root cause was the
  shadow map comparing a surface's depth against itself at texel-level
  precision, which produces a moire-like self-shadowing pattern. Fixed
  with a normal-offset (the shadow sample point is nudged off the
  surface along its normal) plus a slope-scaled bias (steep/edge-on
  surfaces get more bias, since that's where acne is worst).
- FIXED: the contact-shadow ray march (added in v2) was over-triggering
  in small enclosed rooms, producing blotchy false self-occlusion on top
  of the acne. It's now jittered per-pixel (turns residual noise into a
  fine dither instead of hard patches) and fades in gradually instead of
  snapping to a hard dark value.
- Tightened shadowDistance from 140 to 100 blocks so the fixed 2048
  shadow map texels cover less world space each, i.e. sharper shadows
  with less room for acne. Trade-off: shadows fade out a bit sooner at
  long range.

CHANGELOG (v2)
--------------
- FIXED: daytime was too dark. v1 replaced Minecraft's lighting with a flat
  0.30 ambient value, so any face not directly angled at the sun looked
  dim even in full daylight. v2 now samples the vanilla lightmap texture
  as the lighting base (correct in daylight, dim at night, glows near
  torches) and layers directional sun lighting + shadows on top of that,
  instead of replacing it.
- ADDED: screen-space ray-marched contact shadows in the composite pass,
  in addition to the shadow map. See the note below on what "ray traced"
  can honestly mean here.
- Shadow map upgraded from 3x3 to 5x5 PCF for softer edges.

HONEST LIMITATIONS (please read)
---------------------------------
- "Ray traced shadows": Iris/OptiFine shaderpacks run on plain OpenGL —
  there is no DXR/RTX hardware ray-tracing API exposed to this format, so
  true hardware-accelerated ray-traced shadows are not achievable in an
  Iris shaderpack, period. What this pack DOES include is a genuine
  ray-marching technique: it marches a short ray through the depth buffer
  toward the sun/moon in screen space and tests for occlusion at each
  step (see contactShadow() in composite.fsh). This is the real
  "screen-space ray tracing" technique big engines use for contact
  shadows. It's a legitimate ray-marching method, just not hardware RT/
  voxel path tracing — I don't want to overstate what it is.
- Water "reflections" are a Fresnel/sky-color approximation, not a true
  screen-space or ray-traced reflection. They look convincing but won't
  show actual reflected trees/terrain/clouds. A true SSR pass for water
  is a natural next step if you want it — just ask.
- This pack does NOT include voxel path tracing / full scene GI (what
  SEUS PTGI, Bliss, or Complementary's path-traced modes do). That's a
  months-long undertaking by dedicated teams.
- The contact-shadow ray march uses fixed step count/size tuned by eye,
  not tested on your hardware/scenes — if it looks too weak, too strong,
  or causes banding, the STEPS/STEP_SIZE constants at the top of
  contactShadow() in composite.fsh are the place to tune it.
- Foliage/leaves use simple alpha-test shadows (no colored/translucent
  shadows).

INSTALLATION
------------
1. Install Iris:
   - Fabric: install Fabric Loader, then get "Iris" from Modrinth/CurseForge
     into your mods folder (it bundles Sodium — don't add Sodium separately).
   - NeoForge: Iris 1.21.1+ has an official NeoForge build; install it the
     same way, into your NeoForge mods folder.
   - Note: plain "Forge" (not NeoForge) is NOT supported by Iris. If you're
     stuck on old Forge, look at the unofficial "Oculus" + "Embeddium" combo
     instead — this pack should still work there since it's plain
     OptiFine/Iris-format GLSL, but it isn't tested on Oculus.
2. Drop NovaShine-Shaders.zip directly into:
   .minecraft/shaderpacks/
   (Iris can load shaderpacks straight from the zip — no need to extract.)
3. Launch Minecraft, go to Options > Video Settings > Shader Packs, and
   select "NovaShine-Shaders".
4. Recommended: allocate at least 4GB RAM to the JVM, and use a render
   distance of 10-12 chunks for smooth performance while shadows are on.

TWEAKING
--------
- shadowMapResolution in shaders/shaders.properties controls shadow
  sharpness vs. performance (2048 is a good middle ground; try 1024 if
  FPS is low, 4096 if you have a strong GPU).
- Wave height/speed: edit the `wave` calculation in
  shaders/gbuffers_water.vsh.
- Bloom strength: edit the `col += bloom * 0.6;` line in
  shaders/composite.fsh (lower the 0.6 for a subtler look).
- Wind sway: add/remove block names in shaders/block.properties (under
  block.10001 for full sway, block.10002 for leaves' subtle sway) to
  change which blocks wave in the wind. Sway amount/speed is set in the
  `sway`/`amount` lines in shaders/gbuffers_terrain.vsh.
- God ray strength: `col += vec3(1.0, 0.88, 0.65) * rays * 0.6;` in
  shaders/composite.fsh - lower the 0.6 for subtler rays, or raise
  NUM_SAMPLES in godRays() for smoother (but more expensive) rays.
- Sun/moon circle size: the `0.40`/`0.46` values in
  shaders/gbuffers_skytextured.fsh control the disc radius and edge
  softness.

WANT MORE?
----------
If you'd like, I can extend this pack with:
- A real screen-space reflection pass for water (reflects actual scene
  geometry, not just sky color)
- Volumetric-style light shafts
- Colored/translucent shadows for stained glass and leaves
- A performance-oriented "lite" preset alongside this "high" one
Just ask and I'll build directly on top of these files.
