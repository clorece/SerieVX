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
#include "/lib/antialiasing/atrous.glsl"

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
    
    #ifdef DENOISER_ENABLED
        vec4 filtered = AtrousFilter(texCoord, 2);
        giFiltered = filtered.rgb;
        aoFiltered.r = filtered.a;
    #else
        giFiltered = centerGI;
        aoFiltered.r = centerAO;
    #endif
    
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
