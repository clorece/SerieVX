#ifndef INCLUDE_SKY
    #define INCLUDE_SKY

    #ifdef OVERWORLD
    #include "/lib/colors/lightAndAmbientColors.glsl"
    #include "/lib/colors/skyColors.glsl"
    #include "/lib/atmospherics/roboboSky.glsl"

    #ifdef CAVE_FOG
        #include "/lib/atmospherics/fog/caveFactor.glsl"
    #endif

    vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround, out vec3 transmittance) {
        VdotU = max(VdotU, 0.0);
        
        vec3 wUpVec = normalize(gbufferModelView[1].xyz);
        vec3 wSunVec = normalize(sunPosition);
        
        float SdotU = dot(wSunVec, wUpVec);
        float denom = 1.0 - SdotU * SdotU;
        vec3 viewVec;
        
        if (denom < 0.0001) {
             float sinTheta = sqrt(max(0.0, 1.0 - VdotU * VdotU));
             vec3 arbitrary = abs(wUpVec.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
             vec3 ortho = normalize(cross(wUpVec, arbitrary));
             viewVec = wUpVec * VdotU + ortho * sinTheta;
        } else {
             float b = (VdotS - VdotU * SdotU) / denom;
             float a = VdotU - b * SdotU;
             vec3 ortho = normalize(cross(wUpVec, wSunVec));
             float lenSq = a*a + b*b + 2.0*a*b*SdotU;
             float c = sqrt(max(0.0, 1.0 - lenSq));

             viewVec = a*wUpVec + b*wSunVec + c*ortho;
        }

        vec2 pid;
        vec3 sky = GetAtmosphere(vec3(0.0), viewVec, wUpVec, wSunVec, -wSunVec, pid, transmittance, 4, dither);

        if (isEyeInWater == 1) {
            float VdotUmax0 = max(VdotU, 0.0);
            float VdotUmax0M = 1.0 - VdotUmax0 * VdotUmax0;
            sky = mix(sky * 3.0, waterFogColor, VdotUmax0M);
        }
        
        #ifdef CAVE_FOG
           sky = mix(sky, caveFogColor, GetCaveFactor() * (1.0 - max(VdotU,0.0)*max(VdotU,0.0)));
        #endif
        
        return sky;
    }

    vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        vec3 transmittance;
        return GetSky(VdotU, VdotS, dither, doGlare, doGround, transmittance);
    }

    vec3 GetLowQualitySky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround, out vec3 transmittance) {
        vec3 wUpVec = normalize(gbufferModelView[1].xyz);
        vec3 wSunVec = normalize(sunPosition);
        
        float SdotU = dot(wSunVec, wUpVec);
        float denom = 1.0 - SdotU * SdotU;
        vec3 viewVec;
        
        if (denom < 0.0001) {
             float sinTheta = sqrt(max(0.0, 1.0 - VdotU * VdotU));
             vec3 arbitrary = abs(wUpVec.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
             vec3 ortho = normalize(cross(wUpVec, arbitrary));
             viewVec = wUpVec * VdotU + ortho * sinTheta;
        } else {
             float b = (VdotS - VdotU * SdotU) / denom;
             float a = VdotU - b * SdotU;
             vec3 ortho = normalize(cross(wUpVec, wSunVec));
             float lenSq = a*a + b*b + 2.0*a*b*SdotU;
             float c = sqrt(max(0.0, 1.0 - lenSq));
             viewVec = a*wUpVec + b*wSunVec + c*ortho;
        }
        
        vec2 pid;
        // Low Quality: 2 steps
        vec3 sky = GetAtmosphere(vec3(0.0), viewVec, wUpVec, wSunVec, -wSunVec, pid, transmittance, 2, dither, 1.0, doGlare);
        
        if (isEyeInWater == 1) {
             float VdotUmax0 = max(VdotU, 0.0);
             float VdotUmax0M = 1.0 - VdotUmax0 * VdotUmax0;
             sky = mix(sky * 3.0, waterFogColor, VdotUmax0M);
        }
        #ifdef CAVE_FOG
           sky = mix(sky, caveFogColor, GetCaveFactor() * (1.0 - max(VdotU,0.0)*max(VdotU,0.0)));
        #endif
        
        return sky;
    }

    vec3 GetLowQualitySky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
        vec3 transmittance;
        return GetLowQualitySky(VdotU, VdotS, dither, doGlare, doGround, transmittance);
    }

    #else

    #endif
    
    #ifndef OVERWORLD
        vec3 GetSky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
            #ifdef END
                return endSkyColor;
            #else
                return vec3(0.0);
            #endif
        }
        
        vec3 GetLowQualitySky(float VdotU, float VdotS, float dither, bool doGlare, bool doGround) {
            #ifdef END
                return endSkyColor;
            #else
                return vec3(0.0);
            #endif
        }
    #endif

#endif //INCLUDE_SKY