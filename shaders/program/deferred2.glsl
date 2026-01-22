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

//Common Variables//
#include "/lib/commonVariables.glsl"
#include "/lib/commonFunctions.glsl"

//Common Functions//
float GetLinearDepth2(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/util/spaceConversion.glsl"

bool IsActivePixel(vec2 fragCoord) {
    #if PT_RENDER_RESOLUTION == 3
        return true;
    #elif PT_RENDER_RESOLUTION == 2
        ivec2 p = ivec2(fragCoord);
        return !((p.x & 1) != 0 && (p.y & 1) != 0);
    #elif PT_RENDER_RESOLUTION == 1
        ivec2 p = ivec2(fragCoord);
        return ((p.x + p.y) & 1) == 0;
    #elif PT_RENDER_RESOLUTION == 0
        ivec2 p = ivec2(fragCoord);
        return ((p.x & 1) == 0 && (p.y & 1) == 0);
    #endif
    return true;
}

//Program//
// Helper to check for NaNs (GLSL 1.30 has isnan, but isinf is 4.0+)
bool IsValid(float x) { return !isnan(x); }
bool IsValid(vec2 v) { return IsValid(v.x) && IsValid(v.y); }
bool IsValid(vec3 v) { return IsValid(v.x) && IsValid(v.y) && IsValid(v.z); }

void main() {
    float z0 = texelFetch(depthtex0, texelCoord, 0).r;
    
    vec3 giFiltered = vec3(0.0);
    vec3 aoFiltered = vec3(0.0);
    
    // Read center data
    vec4 centerGIData = texture2D(colortex11, texCoord);
    vec3 centerGI = centerGIData.rgb;
    float centerAO = centerGIData.a;
    
    if (!IsValid(centerGI)) centerGI = vec3(0.0);
    if (!IsValid(centerAO)) centerAO = 0.0;
    
    float centerDepth = GetLinearDepth(z0);
    vec3 centerNormal = mat3(gbufferModelView) * texelFetch(colortex5, texelCoord, 0).rgb;
    
    // Variance from Temporal Moments (colortex13)
    // R=unused, G=Moment1, B=Moment2, A=HistoryLength
    vec2 moments = texture2D(colortex13, texCoord).gb;
    if (!IsValid(moments)) moments = vec2(0.0);

    float variance = max(moments.y - moments.x * moments.x, 0.0);
    if (!IsValid(variance)) variance = 0.0;
    
    float centerLum = dot(centerGI, vec3(0.2126, 0.7152, 0.0722));
    
    // Filter Parameters
    int stepSize = 2; // Step Size 2
    
    // Adapting phiColor based on variance (SVGF style):
    float phiColor = 4.0 + variance * 100.0; // Higher variance = blur more (relaxed edge)
    phiColor = clamp(phiColor, 0.1, 1000.0);

    float phiNormal = 128.0;
    float phiDepth = 1.0;
    
    // Spatial Variance Estimation (Fallback for low history)
    float historyLength = texture2D(colortex13, texCoord).a;
    if (historyLength < 4.0) {
        float sumLuma = 0.0;
        float sumLumaSq = 0.0;
        float sampleCount = 0.0;
        
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                vec2 varOffset = vec2(i, j) * float(stepSize * DENOISER_STEP_SIZE) / vec2(viewWidth, viewHeight);
                vec2 varCoord = texCoord + varOffset;
                
                if (!IsActivePixel(varCoord * vec2(viewWidth, viewHeight))) continue;
                
                vec3 varSample = texture2D(colortex11, varCoord).rgb;
                float varLuma = dot(varSample, vec3(0.2126, 0.7152, 0.0722));
                
                sumLuma += varLuma;
                sumLumaSq += varLuma * varLuma;
                sampleCount += 1.0;
            }
        }
        
        if (sampleCount > 0.0) {
            float meanLuma = sumLuma / sampleCount;
            float spatialVariance = max((sumLumaSq / sampleCount) - (meanLuma * meanLuma), 0.0);
            
            // Mix temporal and spatial variance based on history length
            // History near 0 = 100% spatial. History 4 = 100% temporal (as it becomes reliable)
            float spatialMix = 1.0 - clamp(historyLength / 4.0, 0.0, 1.0);
            variance = mix(variance, spatialVariance, spatialMix);
        }
    }

    float weightSum = 0.0;
    
    const float kWeights[3] = float[3](0.25, 0.5, 0.25); // 1-2-1 normalized

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(x, y) * float(stepSize * DENOISER_STEP_SIZE) / vec2(viewWidth, viewHeight);
            vec2 sampleCoord = texCoord + offset;
            
            if (!IsActivePixel(sampleCoord * vec2(viewWidth, viewHeight))) continue;

            vec4 sampleGIData = texture2D(colortex11, sampleCoord);
            vec3 sampleGI = sampleGIData.rgb;
            float sampleAO = sampleGIData.a;
            
            if (!IsValid(sampleGI)) sampleGI = vec3(0.0);
            
            vec3 sampleNormal = mat3(gbufferModelView) * texture2D(colortex5, sampleCoord).rgb;
            float sampleDepth = GetLinearDepth(texture2D(depthtex0, sampleCoord).r);
            
            // Edge Stopping Functions
            
            // 1. Normal
            float wNormal = pow(max(0.0, dot(centerNormal, sampleNormal)), phiNormal);
            
            // 2. Depth
            float wDepth = 0.0;
            if (abs(centerDepth - sampleDepth) * far < 0.5 * (1.0 + abs(x) + abs(y))) {
                 wDepth = exp(-abs(centerDepth - sampleDepth) / (phiDepth * max(length(vec2(x,y)) * 0.01, 1e-5) + 1e-5));
            }
            
            // 3. Luminance (Color)
            float sampleLum = dot(sampleGI, vec3(0.2126, 0.7152, 0.0722));
            float wColor = exp(-abs(centerLum - sampleLum) / phiColor);
            
            // Combine
            float w = wNormal * wDepth * wColor;
            if (!IsValid(w)) w = 0.0;
            
            // Kernel Weight
            float k = kWeights[abs(x)] * kWeights[abs(y)]; // 3x3 Gaussian
            
            float finalWrap = w * k;

            giFiltered += sampleGI * finalWrap;
            aoFiltered.r += sampleAO * finalWrap;
            weightSum += finalWrap;
        }
    }
    
    if (weightSum > 0.001) {
        giFiltered /= weightSum;
        aoFiltered.r /= weightSum;
    } else {
        giFiltered = centerGI;
        aoFiltered.r = centerAO;
    }
    
    /* RENDERTARGETS: 11 */
    gl_FragData[0] = vec4(giFiltered, aoFiltered.r);
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
