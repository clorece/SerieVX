/////////////////////////////////////
// Complementary Shaders by EminGT //
// Cloud Blur & Reconstruction     //
/////////////////////////////////////

//Common//
//Common//
#include "/lib/common.glsl"


//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;
flat in vec3 upVec, sunVec;

//Pipeline Constants//

//Common Variables//
#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"

// Color Includes (Required for mainClouds)
#include "/lib/colors/lightAndAmbientColors.glsl"
#include "/lib/colors/skyColors.glsl"
#include "/lib/util/spaceConversion.glsl"

// Cloud Map Generation (Top Down Density)
#if defined CLOUD_SHADOWS && defined OVERWORLD
    #include "/lib/atmospherics/clouds/cloudCoord.glsl"
    #include "/lib/atmospherics/clouds/mainClouds.glsl"
    #define CLOUD_SHADOW_GENERATION
    //#include "/lib/atmospherics/clouds/cloudShadows.glsl"
#endif

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

// Check if a pixel was rendered (not a checkerboard hole)
// Must match deferred5.glsl IsActivePixel exactly
bool IsActivePixel(ivec2 p) {
    #if CLOUD_RENDER_RESOLUTION == 3
        return true;
    #elif CLOUD_RENDER_RESOLUTION == 2
        return !((p.x & 1) != 0 && (p.y & 1) != 0); // 3/4 resolution: skip bottom-right of each 2x2
    #elif CLOUD_RENDER_RESOLUTION == 1
        return ((p.x + p.y) & 1) == 0; // Checkerboard: every other pixel
    #else
        return true;
    #endif
}

// Helper to get combined depth (uses DH when regular depth is at far plane)
float GetCombinedDepth(vec2 coord) {
    float depth = texture2D(depthtex0, coord).r;
    #ifdef DISTANT_HORIZONS
        if (depth >= 1.0) {
            float dhDepth = texture2D(dhDepthTex, coord).r;
            if (dhDepth < 1.0) {
                // Convert DH depth to a comparable value
                // When DH has geometry and regular doesn't, use a value < 1.0
                return 0.999; // Indicates "has geometry but far"
            }
        }
    #endif
    return depth;
}

// Smart Blur: Fills holes and softens edges (combined horizontal + vertical + diagonals)
vec4 SmartBlur(sampler2D cloudTex, vec2 coord) {
    vec4 sum = vec4(0.0);
    float validWeightSum = 0.0;
    float totalKernelWeight = 0.0;
    
    // Moderate blur radius (intermediate setting)
    float weights[4] = float[4](0.30, 0.22, 0.15, 0.08);
    vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    
    float centerDepth = GetCombinedDepth(coord);
    
    // Center Sample
    vec4 centerSample = texture2D(cloudTex, coord);
    float centerW = weights[0];
    totalKernelWeight += centerW;
    
    if (centerSample.a > 0.001) {
        sum += centerSample * centerW;
        validWeightSum += centerW;
    }
    
    // Sample in a cross pattern + diagonals - reduced to 3 pixels
    for (int i = 1; i <= 3; i++) {
        float w = weights[i];
        float diagW = w * 0.7; // Slightly lower weight for diagonals
        
        // Horizontal samples
        vec2 posR = coord + vec2(float(i) * pixelSize.x, 0.0);
        vec2 posL = coord - vec2(float(i) * pixelSize.x, 0.0);
        
        // Vertical samples  
        vec2 posU = coord + vec2(0.0, float(i) * pixelSize.y);
        vec2 posD = coord - vec2(0.0, float(i) * pixelSize.y);
        
        // Diagonal samples for better coverage
        vec2 posTR = coord + vec2(float(i) * pixelSize.x, float(i) * pixelSize.y);
        vec2 posTL = coord + vec2(-float(i) * pixelSize.x, float(i) * pixelSize.y);
        vec2 posBR = coord + vec2(float(i) * pixelSize.x, -float(i) * pixelSize.y);
        vec2 posBL = coord - vec2(float(i) * pixelSize.x, float(i) * pixelSize.y);
        
        vec4 sampleR = texture2D(cloudTex, posR);
        vec4 sampleL = texture2D(cloudTex, posL);
        vec4 sampleU = texture2D(cloudTex, posU);
        vec4 sampleD = texture2D(cloudTex, posD);
        vec4 sampleTR = texture2D(cloudTex, posTR);
        vec4 sampleTL = texture2D(cloudTex, posTL);
        vec4 sampleBR = texture2D(cloudTex, posBR);
        vec4 sampleBL = texture2D(cloudTex, posBL);
        
        // Depth safety for each sample (relaxed threshold for smoother blending)
        float depthR = GetCombinedDepth(posR);
        float depthL = GetCombinedDepth(posL);
        float depthU = GetCombinedDepth(posU);
        float depthD = GetCombinedDepth(posD);
        float depthTR = GetCombinedDepth(posTR);
        float depthTL = GetCombinedDepth(posTL);
        float depthBR = GetCombinedDepth(posBR);
        float depthBL = GetCombinedDepth(posBL);
        
        float depthThreshold = 0.02; // Relaxed threshold for smoother blending
        float dwR = abs(centerDepth - depthR) < depthThreshold ? 1.0 : 0.0;
        float dwL = abs(centerDepth - depthL) < depthThreshold ? 1.0 : 0.0;
        float dwU = abs(centerDepth - depthU) < depthThreshold ? 1.0 : 0.0;
        float dwD = abs(centerDepth - depthD) < depthThreshold ? 1.0 : 0.0;
        float dwTR = abs(centerDepth - depthTR) < depthThreshold ? 1.0 : 0.0;
        float dwTL = abs(centerDepth - depthTL) < depthThreshold ? 1.0 : 0.0;
        float dwBR = abs(centerDepth - depthBR) < depthThreshold ? 1.0 : 0.0;
        float dwBL = abs(centerDepth - depthBL) < depthThreshold ? 1.0 : 0.0;
        
        // Accumulate weights (cardinal + diagonal)
        totalKernelWeight += w * (dwR + dwL + dwU + dwD);
        totalKernelWeight += diagW * (dwTR + dwTL + dwBR + dwBL);
        
        // Cardinal directions
        if (sampleR.a > 0.001) { sum += sampleR * w * dwR; validWeightSum += w * dwR; }
        if (sampleL.a > 0.001) { sum += sampleL * w * dwL; validWeightSum += w * dwL; }
        if (sampleU.a > 0.001) { sum += sampleU * w * dwU; validWeightSum += w * dwU; }
        if (sampleD.a > 0.001) { sum += sampleD * w * dwD; validWeightSum += w * dwD; }
        
        // Diagonal directions
        if (sampleTR.a > 0.001) { sum += sampleTR * diagW * dwTR; validWeightSum += diagW * dwTR; }
        if (sampleTL.a > 0.001) { sum += sampleTL * diagW * dwTL; validWeightSum += diagW * dwTL; }
        if (sampleBR.a > 0.001) { sum += sampleBR * diagW * dwBR; validWeightSum += diagW * dwBR; }
        if (sampleBL.a > 0.001) { sum += sampleBL * diagW * dwBL; validWeightSum += diagW * dwBL; }
    }
    
    if (validWeightSum < 0.0001) return vec4(0.0);
    
    // Reconstruct pixel - simple weighted average, no alpha reduction
    vec4 result = sum / validWeightSum;
    
    return result;
}

//Program//
void main() {
    vec4 currentClouds = SmartBlur(colortex12, texCoord);

    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    vec2 prvCoord = Reprojection(vec3(texCoord, 1.0), cameraOffset);
    
    vec4 historyClouds = texture2D(colortex10, prvCoord);
    
    float blendFactor = 0.7;


    float velocity = length(cameraOffset) * 16.0;
    //blendFactor *= exp(-velocity) * 0.5 + 0.5;

    blendFactor = max(blendFactor, 0.0);
    
    vec4 finalClouds = mix(currentClouds, historyClouds, blendFactor * 0.95);
    
    finalClouds = max(finalClouds, vec4(0.0));

    /* RENDERTARGETS:10,14 */
    gl_FragData[0] = finalClouds;
    gl_FragData[1] = finalClouds;
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;
flat out vec3 upVec, sunVec;

//Program//
void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    upVec = normalize(gbufferModelView[1].xyz);
    sunVec = normalize(sunPosition);
}

#endif
