#ifdef OVERWORLD
    #include "/lib/atmospherics/sky.glsl"
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
#endif
#if defined END && defined DEFERRED1
    #include "/lib/atmospherics/enderBeams.glsl"
#endif

#ifdef ATM_COLOR_MULTS
    #include "/lib/colors/colorMultipliers.glsl"
#endif
#ifdef MOON_PHASE_INF_ATMOSPHERE
    #include "/lib/colors/moonPhaseInfluence.glsl"
#endif

#define LQ_CLOUD

#include "/lib/lighting/voxelPathTracing.glsl"
#include "/lib/colors/lightAndAmbientColors.glsl"

vec3 refPos = vec3(0.0);

vec4 GetReflection(vec3 normalM, vec3 viewPos, vec3 nViewPos, vec3 playerPos, float lViewPos, float z0,
                   sampler2D depthtex, float dither, float skyLightFactor, float fresnel,
                   float smoothness, vec3 geoNormal, vec3 color, vec3 shadowMult, float highlightMult) {
    // ============================== Step 1: Prepare ============================== //
    vec2 rEdge = vec2(0.6, 0.55);
    vec3 normalMR = normalM;

    #if RENDER_SCALE < 1.0
        // With vertex scaling, gl_FragCoord.xy / view gives [0, RENDER_SCALE] which matches texture content
        z0 = texture2D(depthtex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).x;
    #endif

    #if defined GBUFFERS_WATER && WATER_STYLE == 1 && defined GENERATED_NORMALS
        normalMR = normalize(mix(geoNormal, normalM, 0.05));
    #endif

    vec3 nViewPosR = normalize(reflect(nViewPos, normalMR));
    float RVdotU = dot(nViewPosR, upVec);
    float RVdotS = dot(nViewPosR, sunVec);

    #if defined GBUFFERS_WATER && WATER_STYLE >= 2
        normalMR = normalize(mix(geoNormal, normalM, 0.8));
    #endif
    // ============================== End of Step 1 ============================== //

    // ============================== Step 2: Calculate Terrain Reflection and Alpha ============================== //
    vec4 reflection = vec4(0.0);
    #if defined DEFERRED1 || WATER_REFLECT_QUALITY >= 1
        #if defined DEFERRED1 || WATER_REFLECT_QUALITY >= 2 && !defined DH_WATER
            // Method 1: Ray Marched Reflection //

            // Ray Marching
            vec3 start = viewPos + normalMR * (lViewPos * 0.025 * (1.0 - fresnel) + 0.05);
            #if defined GBUFFERS_WATER && WATER_STYLE >= 2
                vec3 vector = normalize(reflect(nViewPos, normalMR)); // Not using nViewPosR because normalMR changed
            #else
                vec3 vector = nViewPosR;
            #endif
            //vector = normalize(vector - 0.5 * (1.0 - smoothness) * (1.0 - fresnel) * normalMR); // reflection anisotropy test
            //vector = normalize(vector - 0.075 * dither * (1.0 - pow2(pow2(fresnel))) * normalMR);
            vector *= 0.5;
            vec3 viewPosRT = viewPos + vector;
            vec3 tvector = vector;

            int sr = 0;
            float dist = 0.0;
            vec3 rfragpos = vec3(0.0);
            for (int i = 0; i < 32; i++) { //originally 30 itterations but cut in half to save fps
                refPos = nvec3(gbufferProjection * vec4(viewPosRT, 1.0)) * 0.5 + 0.5;

                // Check bounds in UNSCALED space
                if (abs(refPos.x - 0.5) > rEdge.x || abs(refPos.y - 0.5) > rEdge.y) break;

                // Scale ONLY for texture sampling
                #if RENDER_SCALE < 1.0
                    vec2 refPosSample = ScaleToViewport(refPos.xy);
                #else
                    vec2 refPosSample = refPos.xy;
                #endif

                // Sample depth from scaled texture coords, but unproject using full [0,1] screen coords
                // This is correct because gbufferProjectionInverse expects normalized screen coords
                float sampledDepth = texture2D(depthtex, refPosSample).r;
                rfragpos = nvec3(gbufferProjectionInverse * vec4(vec3(refPos.xy, sampledDepth) * 2.0 - 1.0, 1.0));
                dist = length(start - rfragpos);

                float err = length(viewPosRT - rfragpos);

                if (err < length(vector) * 3.0) {
                    sr++;
                    if (sr >= 6) break;
                    tvector -= vector;
                    vector *= 0.1;
                }
                vector *= 2.0;
                tvector += vector * (0.95 + 0.1 * dither);
                viewPosRT = start + tvector;
            }

            // Finalizing Terrain Reflection and Alpha 
            if (refPos.z < 0.99997) {
                vec2 absPos = abs(refPos.xy - 0.5);
                vec2 cdist = absPos / rEdge;
                // float border = clamp(1.0 - pow(max(cdist.x, cdist.y), 50.0), 0.0, 1.0);
                float border = smoothstep(0.5, 0.4, max(absPos.x, absPos.y));
                reflection.a = border;

                float lViewPosRT = length(rfragpos);

                if (reflection.a > 0.001) {
                    vec2 edgeFactor = pow2(pow2(pow2(cdist)));
                    refPos.y += (dither - 0.5) * (0.05 * (edgeFactor.x + edgeFactor.y));

                    #ifdef DEFERRED1
                        float smoothnessDM = pow2(smoothness);
                        float lodFactor = 1.0 - exp(-0.125 * (1.0 - smoothnessDM) * dist);
                        float lod = log2(viewHeight / 8.0 * (1.0 - smoothnessDM) * lodFactor) * 0.45;
                        if (z0 <= 0.56) lod *= 2.22; // Using more lod to compensate for less roughness noise on held items
                        lod = max(lod - 1.0, 0.0);

                        reflection.rgb = texture2DLod(colortex0, ScaleToViewport(refPos.xy), lod).rgb;
                    #else
                        reflection = texture2D(gaux2, ScaleToViewport(refPos.xy));
                        reflection.rgb = pow2(reflection.rgb + 1.0);
                    #endif

                    float skyFade = 0.0;
                    DoFog(reflection.rgb, skyFade, lViewPosRT, ViewToPlayer(rfragpos.xyz), RVdotU, RVdotS, dither);

                    edgeFactor.x = pow2(edgeFactor.x);
                    edgeFactor = 1.0 - edgeFactor;
                    reflection.a *= pow(edgeFactor.x * edgeFactor.y, 2.0 + 3.0 * GetLuminance(reflection.rgb));
                }

                float posDif = lViewPosRT - lViewPos;
                reflection.a *= clamp(posDif + 3.0, 0.0, 1.0);
            }
            #if defined DEFERRED1 && defined TEMPORAL_FILTER
                else refPos.z = 1.0;
            #endif
            #if !defined DEFERRED1 && defined DISTANT_HORIZONS
                else
            #endif
        #endif
        #if !defined DEFERRED1 && (WATER_REFLECT_QUALITY < 2 || defined DISTANT_HORIZONS) || defined DH_WATER
        {   // Method 2: Mirorred Image Reflection //

            #if WATER_REFLECT_QUALITY < 2
                float verticalStretch = 0.013; // for potato quality reflections
            #else
                float verticalStretch = 0.0025; // for distant horizons reflections
            #endif

            vec4 clipPosR = gbufferProjection * vec4(nViewPosR + verticalStretch * viewPos, 1.0);
            vec3 screenPosR = clipPosR.xyz / clipPosR.w * 0.5 + 0.5;
            vec2 screenPosRM = abs(screenPosR.xy - 0.5);

            if (screenPosRM.x < rEdge.x && screenPosRM.y < rEdge.y) {
                vec2 edgeFactor = pow2(pow2(pow2(screenPosRM / rEdge)));
                screenPosR.y += (dither - 0.5) * (0.03 * (edgeFactor.x + edgeFactor.y) + 0.004);

                #if RENDER_SCALE < 1.0
                    vec2 scaledScreenPos = screenPosR.xy * RENDER_SCALE;
                #else
                    vec2 scaledScreenPos = screenPosR.xy;
                #endif
                
                screenPosR.z = texture2D(depthtex1, scaledScreenPos).x;
                vec3 viewPosR = ScreenToView(screenPosR);
                if (lViewPos <= 2.0 + length(viewPosR)) {
                    reflection = texture2D(gaux2, ScaleToViewport(screenPosR.xy));
                    reflection.rgb = pow2(reflection.rgb + 1.0);
                }

                edgeFactor.x = pow2(edgeFactor.x);
                edgeFactor = 1.0 - edgeFactor;
                reflection.a *= edgeFactor.x * edgeFactor.y;
            }

            reflection.a *= reflection.a;
            reflection.a *= clamp01((dot(nViewPos, nViewPosR) - 0.45) * 10.0); // Fixes perpendicular ref
        }
        #endif
    #endif
    // ============================== End of Step 2 ============================== //

    // ============================== End of Step 2 ============================== //
    
    // ============================== Step 2.5: Voxel Reflection ============================== //
    /*
    #if COLORED_LIGHTING_INTERNAL > 0
        #if defined DEFERRED1 || WATER_REFLECT_QUALITY >= 1
        if (reflection.a < 1.0) {
            vec3 worldRayDir = mat3(gbufferModelViewInverse) * nViewPosR;
            vec3 startScenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
            
            // Offset start slightly to avoid self-intersection
            startScenePos += worldRayDir * 0.1;

            float remainingAlpha = 1.0 - reflection.a;
            
            VoxelHitResult voxelHit = TraceVoxelHit(startScenePos, worldRayDir, 256.0);
            
            if (voxelHit.hit) {
                vec3 albedo = GetVoxelAlbedo(voxelHit.hitPos - voxelHit.hitNormal * 0.05);
                
                // Simple lighting: LPV (Ambient)
                vec3 voxelPos = SceneToVoxel(voxelHit.hitPos);
                vec3 normPos = voxelPos / vec3(voxelVolumeSize);
                vec4 lightVol = GetLightVolume(normPos);
                
                // Add some directional lighting approximation if possible, or just use LPV
                // LPV has skylight and blocklight.
                // We can also assume some sun lighting if hitting top? 
                // TraceVoxelHit returns hitNormal.
                vec3 sunDir = mat3(gbufferModelViewInverse) * sunVec; // sunVec is uniform? Or passed in?
                // sunVec is available in reflections.glsl (line 38 uses it).
                
                float NdotS = max(dot(voxelHit.hitNormal, sunDir), 0.0);
                vec3 directLight = vec3(0.0);
                
                // Check shadow map?
                // GetShadow is available if we include indirectLighting.glsl, but we didn't include it. 
                // We implied use of voxelPathTracing.glsl.
                // Re-implementing Shadow Check here would be expensive.
                // Let's rely on LPV + Simple Sun.
                
                // Check if sky is visible from voxel hit (simple vertical check)
                float skyLight = lightVol.a; // encapsulated in LPV alpha usually? 
                // In GetVoxelSkylight: lightVolume.a is used for sky exposure.
                
                // Only apply direct sun if sky exposure is high?
                if (lightVol.a > 0.5) {
                    directLight = lightColor * NdotS * (1.0 - rainFactor) * lightVol.a;
                }
                
                vec3 voxelColor = albedo * (lightVol.rgb + directLight + 0.05) * 2.0; // + ambient
                
                // Fog for voxel reflection
                float dist = distance(startScenePos, voxelHit.hitPos);
                // Simple fog approach
                float fogFactor = 1.0 - exp(-dist * 0.005);
                voxelColor = mix(voxelColor, fogColor, fogFactor); // fogColor uniform?
                
                reflection.rgb = mix(voxelColor, reflection.rgb, reflection.a);
                reflection.a = 1.0; // Voxel hit is solid
            }
        }
        #endif
    #endif
    */

    // ============================== Step 3: Add Sky Reflection ============================== //
    #if defined DEFERRED1 || WATER_REFLECT_QUALITY >= 1
        if (reflection.a < 1.0)
    #endif
    {
        #ifdef OVERWORLD
            #if defined DEFERRED1 || WATER_REFLECT_QUALITY >= 2
                vec3 skyReflection = GetSky(RVdotU, RVdotS, dither, true, true);
            #else
                vec3 skyReflection = GetLowQualitySky(RVdotU, RVdotS, dither, true, true);
            #endif

            #ifdef ATM_COLOR_MULTS
                skyReflection *= atmColorMult;
            #endif
            #ifdef MOON_PHASE_INF_ATMOSPHERE
                skyReflection *= moonPhaseInfluence;
            #endif

            #ifdef DEFERRED1
                skyReflection *= skyLightFactor;
            #else
                float specularHighlight = GGX(normalM, nViewPos, lightVec, max(dot(normalM, lightVec), 0.0), smoothness);
                skyReflection += specularHighlight * highlightColor * shadowMult * highlightMult * invRainFactor;
                float cloudLinearDepth = 1.0;
                float skyFade = 1.0;
                vec3 auroraBorealis = vec3(0.0);
                vec3 nightNebula = vec3(0.0);
                
                #if WATER_REFLECT_QUALITY >= 1
                    #ifdef SKY_EFFECT_REFLECTION
                        #if AURORA_STYLE > 0
                            auroraBorealis = GetAuroraBorealis(nViewPosR, RVdotU, dither);
                            skyReflection += auroraBorealis;
                        #endif
                        #ifdef NIGHT_NEBULA
                            nightNebula += GetNightNebula(nViewPosR, RVdotU, RVdotS);
                            skyReflection += nightNebula;
                        #endif
                        
                        vec2 starCoord = GetStarCoord(nViewPosR, 0.5);
                        skyReflection += GetStars(starCoord, RVdotU, RVdotS);
                    #endif

                            #ifdef VL_CLOUDS_ACTIVE
                                // Draw procedural clouds directly in reflection
                                vec3 nPlayerPosR = mat3(gbufferModelViewInverse) * nViewPosR;
                                vec4 clouds = pow(GetClouds(cloudLinearDepth, skyFade, cameraPosition, nPlayerPosR * 100000.0,
                                                        1000000.0, RVdotS, RVdotU, dither, auroraBorealis, nightNebula) * 1.0, vec4( 1.0 / 2.2));
                                
                                // Composite clouds into sky reflection
                                skyReflection = mix(skyReflection, clouds.rgb, clouds.a);
                            #endif

                    skyReflection = mix(color * 0.5, skyReflection, skyLightFactor);
                #else
                    skyReflection = mix(color, skyReflection, skyLightFactor * 0.5);
                #endif
            #endif
        #elif defined END
            #ifdef DEFERRED1
                vec3 skyReflection = (endSkyColor + 0.4 * DrawEnderBeams(RVdotU, playerPos)) * skyLightFactor;
            #else
                vec3 skyReflection = endSkyColor * shadowMult;
            #endif

            #ifdef ATM_COLOR_MULTS
                skyReflection *= atmColorMult;
            #endif
        #else
            vec3 skyReflection = vec3(0.0);
        #endif

        reflection.rgb = mix(skyReflection, reflection.rgb, reflection.a);
    } 
    // ============================== End of Step 3 ============================== //

    return reflection;
}