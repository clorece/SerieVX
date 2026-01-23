/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////
//Common//
#include "/lib/common.glsl"
//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER
noperspective in vec2 texCoord;
flat in vec3 upVec, sunVec;

//Pipeline Constants//
const bool colortex11Clear = false;

//Common Variables//
#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"
//Common Functions//

float GetLinearDepth2(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}


#ifdef TEMPORAL_FILTER
    // Previous frame reprojection from Chocapic13
    vec2 Reprojection(vec3 pos, vec3 cameraOffset) {
        pos = pos * 2.0 - 1.0;

        vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
        viewPosPrev /= viewPosPrev.w;
        viewPosPrev = gbufferModelViewInverse * viewPosPrev;

        vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
        previousPosition = gbufferPreviousModelView * previousPosition;
        previousPosition = gbufferPreviousProjection * previousPosition;
        return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
    }

    vec2 SHalfReprojection(vec3 playerPos, vec3 cameraOffset) {
        vec4 proPos = vec4(playerPos + cameraOffset, 1.0);
        vec4 previousPosition = gbufferPreviousModelView * proPos;
        previousPosition = gbufferPreviousProjection * previousPosition;
        return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
    }
    
    vec3 ClipAABB(vec3 nowColor, vec3 minC, vec3 maxC) {
        vec3 p_clip = 0.5 * (maxC + minC);
        vec3 e_clip = 0.5 * (maxC - minC);
        vec3 v_clip = nowColor - p_clip;
        vec3 v_unit = v_clip / e_clip;
        vec3 a_unit = abs(v_unit);
        float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));
        if (ma_unit > 1.0) {
            return p_clip + v_clip / ma_unit;
        } else {
            return nowColor;
        }
    }
#endif

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/fog/mainFog.glsl"
#include "/lib/colors/skyColors.glsl"

#ifdef TAA
    #include "/lib/antialiasing/jitter.glsl"
#endif

#if defined NETHER || END
    #include "/lib/colors/lightAndAmbientColors.glsl"
#endif

#define MIN_LIGHT_AMOUNT 1.0

#include "/lib/lighting/indirectLighting.glsl"

bool IsActivePixel(vec2 coord) {
    #if PT_RENDER_RESOLUTION == 3
        return true;
    #else
        ivec2 p = ivec2(coord);
        
        if (PT_RENDER_RESOLUTION == 2) return !((p.x & 1) != 0 && (p.y & 1) != 0);
        if (PT_RENDER_RESOLUTION == 1) return ((p.x + p.y) & 1) == 0;
        if (PT_RENDER_RESOLUTION == 0) return ((p.x & 1) == 0 && (p.y & 1) == 0);
        
        return true;
    #endif
}

//Program//
void main() {
    if (!IsActivePixel(gl_FragCoord.xy)) {
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(0.0);
        return;
    }

    vec2 scaledCoord = texCoord * RENDER_SCALE;
    ivec2 scaledTexelCoord = ivec2(scaledCoord * vec2(viewWidth, viewHeight));
    
    float z0 = texelFetch(depthtex0, scaledTexelCoord, 0).r;
    vec3 gi = vec3(0.0);
    vec3 ao = vec3(0.0);
    vec3 emissive = vec3(0.0); // New: separate emissive output

    // Use scaledCoord for ray marching (viewPos must project back to scaled buffer)
    vec4 screenPos = vec4(scaledCoord, z0, 1.0);

    // Fix World Position Stability: Subtract TAA jitter to get stable NDC
    #ifdef TAA
        vec2 jitterOffset = vec2(0.0);
        vec2 outputSize = vec2(viewWidth, viewHeight) * RENDER_SCALE;
        // Jitter is in pixels, divide by resolution to get UV/NDC offset
        vec2 taaOffset = jitterOffsets[int(framemod8)] / outputSize;
        
        #if TAA_MODE == 1
            taaOffset *= 0.25;
        #endif
        
        jitterOffset = taaOffset;
        
        // IMPORTANT: Subtract jitter to un-do the shift applied during projection
        screenPos.xy -= jitterOffset;
    #endif

    
    // Use unscaled texCoord for shadow lookups (correct world position at any render scale)
    vec4 unscaledScreenPos = vec4(texCoord, z0, 1.0);
    #ifdef TAA
        // unscaledScreenPos uses texCoord (0..1). jitterOffset matches Scaled Buffer UV.
        // We must scale the jitter offset to match unscaled texture if Render Scale != 1.0.
        // jitterOffset = Px / (W * Scale).
        // unscaledScreenPos delta = Px / W.
        // So unscaledDelta = jitterOffset * Scale.
        // (Px/(W*S)) * S = Px/W. Correct.
        unscaledScreenPos.xy -= jitterOffset * RENDER_SCALE;
    #endif

    vec4 unscaledViewPos = gbufferProjectionInverse * (unscaledScreenPos * 2.0 - 1.0);
    unscaledViewPos /= unscaledViewPos.w;
    // Reconstruct stable viewPos from stable screenPos
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    
    vec3 nViewPos = normalize(viewPos.xyz);
    vec3 playerPos = ViewToPlayer(viewPos.xyz);
    
    vec3 texture5 = texelFetch(colortex5, scaledTexelCoord, 0).rgb;
    vec3 normalM = mat3(gbufferModelView) * texture5;
    vec4 texture6 = texelFetch(colortex6, scaledTexelCoord, 0);
    float skyLightFactor = texture6.b;
    bool entityOrHand = z0 < 0.56;
    
    float dither = texture2D(noisetex, scaledCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    #ifdef TAA
        dither = fract(dither + goldenRatio * mod(float(frameCounter), 360.0));
    #endif

    float VdotU = dot(nViewPos, upVec);
    float VdotS = dot(nViewPos, sunVec);
    vec3 normalG = normalM;

    

    #ifdef TAA
        float noiseMult = 1.0;
    #else
        float noiseMult = 0.1;
    #endif
    vec2 roughCoord = gl_FragCoord.xy / 128.0;
    float roughNoise = texture2D(noisetex, roughCoord).r;
    roughNoise = fract(roughNoise + goldenRatio * mod(float(frameCounter), 360.0));
    roughNoise = noiseMult * (roughNoise - 0.5);
    normalG += roughNoise;

    gi = min(GetGI(ao, emissive, normalG, unscaledViewPos.xyz, unscaledViewPos.xyz, nViewPos, depthtex0, dither, 1.0, VdotU, VdotS, entityOrHand).rgb, vec3(4.0));
    gi = max(gi, vec3(0.0));
    
    // Temporal Accumulation
    vec3 finalGI = gi;
    vec3 finalEmissive = emissive;
    float finalAO = ao.r;
    
    vec2 moments = vec2(0.0);
    float historyLength = 0.0;
    
    #ifdef TEMPORAL_FILTER
        vec3 cameraOffset = cameraPosition - previousCameraPosition;
        vec2 prevUV = Reprojection(vec3(texCoord, z0), cameraOffset);
        
        bool validReprojection = prevUV.x >= 0.0 && prevUV.x <= 1.0 && prevUV.y >= 0.0 && prevUV.y <= 1.0;

        
        /*if (validReprojection) {
            // Note: colortex1 contains previous depth. 
            // If RENDER_SCALE is used, data is in [0, RENDER_SCALE].
            float prevDepth = texture2D(colortex1, prevUV * RENDER_SCALE).r;
            float linearZ = GetLinearDepth(z0);
            float prevLinearZ = GetLinearDepth(prevDepth);
            
            // Allow small depth difference, accounting for motion (heuristic)
            float depthThreshold = 1.0 * max(length(cameraOffset), 0.1); 
            
            if (abs(linearZ - prevLinearZ) * far > depthThreshold + 0.1) {
                validReprojection = false;
            }
        }*/
        

        if (validReprojection) {
            // colortex11: RGB = History GI, A = History AO (matches FragData[1] logic)
            vec4 historyData1 = texture2D(colortex11, prevUV * RENDER_SCALE);
            vec3 historyGI = historyData1.rgb;
            float historyAO = historyData1.a;
            
            // SVGF History (Moments + Length) from colortex13
            // Format: R=?, G=Moment1, B=Moment2, A=Length
            vec4 historyData2 = texture2D(colortex13, prevUV * RENDER_SCALE);
            vec2 historyMoments = historyData2.gb;
            float historyLen = historyData2.a;

            float currentLuma = dot(emissive, vec3(0.2126, 0.7152, 0.0722));
            // History luma check logic from original code might need historyEmissive or GI?
            // "float historyLuma = dot(historyEmissive, vec3(0.2126, 0.7152, 0.0722));"
            // If we don't have historyEmissive, we can skip firefly check or use GI luma?
            // For now, I'll comment out the explicit firefly check reliant on missing buffer, or assume we trust blendFactor.
            
            float blendFactor = 1.0 - clamp(BLEND_WEIGHT * 50.0, 0.01, 0.5);

            // Reduce blending based on camera velocity
            float lViewPos = length(viewPos.xyz);
            float velocity = length(cameraOffset) * max(16.0 - lViewPos / gbufferProjection[1][1], 3.0);
            //blendFactor *= exp(-velocity) * 0.5 + 0.5;
            
            // Reduce blending if depth changed
            
            float linearZ0 = GetLinearDepth(z0);
            vec2 oppositePreCoord = texCoord - 2.0 * (prevUV - texCoord);
            float linearZDif = abs(GetLinearDepth(texture2D(colortex1, oppositePreCoord).r) - linearZ0) * far;
            //blendFactor *= max0(2.0 - linearZDif) * 0.5;
            //blendFactor *= max0(1.0 - linearZDif * 0.2);

            /*
            vec3 texture5P = texture2D(colortex5, oppositePreCoord, 0).rgb;
            vec3 texture5Dif = abs(texture5 - texture5P);
            if (texture5Dif != clamp(texture5Dif, vec3(-0.004), vec3(0.004))) {
                blendFactor = 0.75;
                    //color.rgb = vec3(1,0,1);
            }
            */
            
            /* 
            // Firefly rejection removed because we might not have historyEmissive in colortex9 anymore if we wipe it
            float emissiveBlend = blendFactor;
            if (currentLuma > historyLuma + 0.5) {
                emissiveBlend = mix(emissiveBlend, 1.0, 0.9); // Push towards 1.0 (pure history)
            }
            */
            
            finalGI = mix(gi, historyGI, blendFactor);
            // finalEmissive = mix(emissive, historyEmissive, emissiveBlend);
            finalAO = mix(ao.r, historyAO, blendFactor);
            
            // SVGF Moments Accumulation
            historyLength = min(historyLen + 1.0, 255.0);
            // Moments usually accumulate with same alpha (blendFactor) or 1/historyLength
            // Standard SVGF: alpha = 1 / historyLength.
            // User wants to preserve blendFactor for GI. I will use it for moments too to keep consistency.
            // float momentAlpha = 1.0 / max(historyLength, 1.0);
            
            float luma = dot(gi, vec3(0.2126, 0.7152, 0.0722));
            vec2 currentMoments = vec2(luma, luma * luma);
            moments = mix(historyMoments, currentMoments, blendFactor); // using blendFactor as requested weight
            
        } else {
            finalGI = gi;
            finalEmissive = emissive;
            finalAO = ao.r;
            
            historyLength = 1.0;
            float luma = dot(gi, vec3(0.2126, 0.7152, 0.0722));
            moments = vec2(luma, luma * luma);
        }
    #else
        float luma = dot(gi, vec3(0.2126, 0.7152, 0.0722));
        moments = vec2(luma, luma * luma);
        historyLength = 1.0;
    #endif


    /* RENDERTARGETS: 9,11,13 */
    gl_FragData[0] = vec4(0.0, 1.0, 0.0, 1.0); // DEBUG GREEN
    gl_FragData[1] = vec4(finalGI, finalAO);
    gl_FragData[2] = vec4(0.0, moments.x, moments.y, historyLength);
}
#endif
//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER
noperspective out vec2 texCoord;
flat out vec3 upVec, sunVec;
//Attributes//
//Common Variables//
//Common Functions//
//Includes//
#include "/lib/antialiasing/jitter.glsl"

//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);
    #if defined TAA
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
    #endif

    //#if defined TAA
    //    gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
    //#endif
}
#endif