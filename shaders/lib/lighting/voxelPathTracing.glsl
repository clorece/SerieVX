#ifndef VOXEL_PATH_TRACING_GLSL
#define VOXEL_PATH_TRACING_GLSL

#include "/lib/misc/voxelization.glsl"

const float PHI = 1.618033988749895;
const float PHI_INV = 0.618033988749895;
const float PHI2_INV = 0.38196601125010515;

float rand(float dither, int i) {
    return fract(dither + float(i) * 0.61803398875);
}

float randWithSeed(float dither, int seed) {
    return fract(dither * 12.9898 + float(seed) * 78.233);
}

vec2 R2Sequence(int n, int seed) {
    float u = fract(float(n) * PHI_INV + fract(float(seed) * PHI_INV));
    float v = fract(float(n) * PHI2_INV + fract(float(seed) * PHI2_INV));
    return vec2(u, v);
}

vec2 CranleyPattersonRotation(vec2 sample, float dither) {
    vec2 shift = vec2(
        fract(dither * 12.9898),
        fract(dither * 78.233)
    );
    return fract(sample + shift);
}

vec3 SampleHemisphereCosine(vec2 Xi) {
    float theta = 6.28318530718 * Xi.y;
    float r = sqrt(Xi.x);
    
    vec3 hemi = vec3(
        r * cos(theta),
        r * sin(theta),
        sqrt(1.0 - Xi.x)
    );
    
    return hemi;
}

void BuildOrthonormalBasis(vec3 normal, out vec3 tangent, out vec3 bitangent) {
    if (normal.z < -0.9999999) {
        tangent = vec3(0.0, -1.0, 0.0);
        bitangent = vec3(-1.0, 0.0, 0.0);
        return;
    }
    
    float a = 1.0 / (1.0 + normal.z);
    float b = -normal.x * normal.y * a;
    
    tangent = vec3(1.0 - normal.x * normal.x * a, b, -normal.x);
    bitangent = vec3(b, 1.0 - normal.y * normal.y * a, -normal.y);
}

vec3 RayDirection(vec3 normal, float dither, int i) {
    vec2 Xi = R2Sequence(i, int(dither * 7919.0));
        Xi = CranleyPattersonRotation(Xi, dither);
    
    vec3 hemiDir = SampleHemisphereCosine(Xi);
    
    vec3 T, B;
    BuildOrthonormalBasis(normal, T, B);

    return normalize(T * hemiDir.x + B * hemiDir.y + normal * hemiDir.z);
}

#if COLORED_LIGHTING_INTERNAL > 0
    // Sample skylight contribution from voxel volume
    // Uses the floodfill volume for world-space sky light propagation
    vec3 GetVoxelSkylight(vec3 scenePos, vec3 normal) {
        vec3 voxelPos = SceneToVoxel(scenePos);
        vec3 volumeSize = vec3(voxelVolumeSize);
        
        // Check if inside voxel volume
        if (!CheckInsideVoxelVolume(voxelPos)) {
            return vec3(1.0); // Full skylight outside volume
        }
        
        // Sample from floodfill volume - contains accumulated light
        vec3 normalizedPos = voxelPos / volumeSize;
        vec4 lightVolume = GetLightVolume(normalizedPos);
        
        // Sample in the direction of the normal for directional skylight
        vec3 offsetPos = voxelPos + normal * 2.0;
        offsetPos = clamp(offsetPos, vec3(0.5), volumeSize - 0.5);
        vec3 normalizedOffsetPos = offsetPos / volumeSize;
        vec4 lightVolumeOffset = GetLightVolume(normalizedOffsetPos);
        
        float skyExposure = max(lightVolume.a, lightVolumeOffset.a);
        
        // Check for solid blocks above (simple sky occlusion)
        vec3 upSamplePos = voxelPos + vec3(0.0, 4.0, 0.0);
        if (all(greaterThan(upSamplePos, vec3(0.5))) && all(lessThan(upSamplePos, volumeSize - 0.5))) {
            uint aboveVoxel = texelFetch(voxel_sampler, ivec3(upSamplePos), 0).r;
            if (aboveVoxel >= 1u && aboveVoxel < 200u) {
                skyExposure *= 0.3; // Reduce skylight if blocked
            }
        }
        
        return vec3(skyExposure);
    }
    
    // Calculate ambient occlusion from voxel occupancy data
    // Samples voxel grid to determine how much geometry surrounds the point
    float GetVoxelAO(vec3 scenePos, vec3 normal, float dither) {
        vec3 voxelPos = SceneToVoxel(scenePos);
        vec3 volumeSize = vec3(voxelVolumeSize);
        
        // Check if inside voxel volume
        if (!CheckInsideVoxelVolume(voxelPos)) {
            return 0.0; // No occlusion outside volume
        }
        
        float occlusion = 0.0;
        float totalWeight = 0.0;
        
        const int VOXEL_AO_SAMPLES = 8;
        const float VOXEL_AO_RADIUS = 1.0;
        
        vec3 tangent, bitangent;
        BuildOrthonormalBasis(normal, tangent, bitangent);
        
        for (int i = 0; i < VOXEL_AO_SAMPLES; i++) {
            // Generate sample direction in hemisphere
            vec2 Xi = R2Sequence(i, int(dither * 1000.0));
            Xi = CranleyPattersonRotation(Xi, dither);
            vec3 sampleDir = SampleHemisphereCosine(Xi);
            sampleDir = normalize(tangent * sampleDir.x + bitangent * sampleDir.y + normal * sampleDir.z);
            
            // Sample along the direction
            for (float dist = 1.0; dist <= VOXEL_AO_RADIUS; dist += 1.0) {
                vec3 samplePos = voxelPos + sampleDir * dist;
                
                if (any(lessThan(samplePos, vec3(0.5))) || any(greaterThanEqual(samplePos, volumeSize - 0.5))) {
                    continue;
                }
                
                uint voxelData = texelFetch(voxel_sampler, ivec3(samplePos), 0).r;
                
                // Check if it's a solid block (not air, not light source, not transparent)
                if (voxelData == 1u) {
                    float weight = 1.0 - (dist / VOXEL_AO_RADIUS);
                    weight = weight * weight; // Quadratic falloff
                    occlusion += weight;
                    totalWeight += weight;
                    break;
                }
                totalWeight += (1.0 - dist / VOXEL_AO_RADIUS) * 0.5;
            }
        }
        
        if (totalWeight > 0.0) {
            occlusion /= totalWeight;
        }
        
        return clamp(occlusion, 0.0, 1.0);
    }
    
    // Voxel ray tracing - marches through voxel grid and samples floodfill light
    // Returns accumulated light along the ray (for colored lighting + skylight)
    struct VoxelRayResult {
        bool hitSky;        // Ray escaped to sky
        bool hitSolid;      // Ray hit solid geometry
        vec3 light;         // Accumulated light from floodfill volume
        float distance;     // Distance traveled
    };
    
    VoxelRayResult TraceVoxelRay(vec3 scenePos, vec3 rayDir, float maxDist, float dither) {
        VoxelRayResult result;
        result.hitSky = false;
        result.hitSolid = false;
        result.light = vec3(0.0);
        result.distance = 0.0;
        
        vec3 volumeSize = vec3(voxelVolumeSize);
        vec3 voxelPos = SceneToVoxel(scenePos);
        
        // Check if starting position is inside volume
        if (!CheckInsideVoxelVolume(voxelPos)) {
            result.hitSky = true;
            return result;
        }
        
        // DDA-style voxel traversal
        vec3 rayDirSign = sign(rayDir);
        vec3 rayDirAbs = abs(rayDir);
        vec3 deltaDist = 1.0 / max(rayDirAbs, vec3(0.0001));
        
        ivec3 mapPos = ivec3(floor(voxelPos));
        ivec3 step = ivec3(rayDirSign);
        
        vec3 sideDist = (rayDirSign * (vec3(mapPos) - voxelPos) + rayDirSign * 0.5 + 0.5) * deltaDist;
        
        float totalLight = 0.0;
        int maxSteps = int(min(maxDist * 2.0, 64.0));
        
        for (int i = 0; i < maxSteps; i++) {
            // Check bounds
            if (any(lessThan(mapPos, ivec3(0))) || any(greaterThanEqual(mapPos, ivec3(volumeSize)))) {
                result.hitSky = true;
                break;
            }
            
            uint voxelData = texelFetch(voxel_sampler, mapPos, 0).r;
            
            // Hit solid block
            if (voxelData == 1u) {
                result.hitSolid = true;
                break;
            }
            
            // Sample light from floodfill at this position
            vec3 normalizedPos = (vec3(mapPos) + 0.5) / volumeSize;
            vec4 lightSample = GetLightVolume(normalizedPos);
            result.light += lightSample.rgb * 0.1; // Accumulate with falloff
            
            // DDA step
            if (sideDist.x < sideDist.y) {
                if (sideDist.x < sideDist.z) {
                    sideDist.x += deltaDist.x;
                    mapPos.x += step.x;
                    result.distance += deltaDist.x;
                } else {
                    sideDist.z += deltaDist.z;
                    mapPos.z += step.z;
                    result.distance += deltaDist.z;
                }
            } else {
                if (sideDist.y < sideDist.z) {
                    sideDist.y += deltaDist.y;
                    mapPos.y += step.y;
                    result.distance += deltaDist.y;
                } else {
                    sideDist.z += deltaDist.z;
                    mapPos.z += step.z;
                    result.distance += deltaDist.z;
                }
            }
        }
        
        return result;
    }
    
    vec3 GetVoxelAlbedo(vec3 scenePos) {
        vec3 voxelPos = SceneToVoxel(scenePos);
        
        if (!CheckInsideVoxelVolume(voxelPos)) return vec3(0.5);

        uint packedColor = texelFetch(voxel_color_sampler, ivec3(voxelPos), 0).r;
        
        if (packedColor == 0u) return vec3(0.5); // Fallback
        
        float r = float(packedColor & 0xFFu) / 255.0;
        float g = float((packedColor >> 8) & 0xFFu) / 255.0;
        float b = float((packedColor >> 16) & 0xFFu) / 255.0;
        
        return vec3(r, g, b);
    }
    
    struct VoxelHitResult {
        bool hit;
        vec3 hitPos;
        vec3 hitNormal;
        uint voxelID;
        vec3 light;
    };
    
    VoxelHitResult TraceVoxelHit(vec3 scenePos, vec3 rayDir, float maxDist) {
        VoxelHitResult result;
        result.hit = false;
        result.hitPos = vec3(0.0);
        result.hitNormal = vec3(0.0);
        result.voxelID = 0u;
        result.light = vec3(0.0);
        
        vec3 volumeSize = vec3(voxelVolumeSize);
        vec3 voxelPos = SceneToVoxel(scenePos);
        
        // Check if starting position is inside volume
        if (!CheckInsideVoxelVolume(voxelPos)) {
            return result;
        }
        
        // DDA Setup
        vec3 rayDirSign = sign(rayDir);
        vec3 rayDirAbs = abs(rayDir);
        vec3 deltaDist = 1.0 / max(rayDirAbs, vec3(0.0001));
        
        ivec3 mapPos = ivec3(floor(voxelPos));
        ivec3 step = ivec3(rayDirSign);
        
        vec3 sideDist = (rayDirSign * (vec3(mapPos) - voxelPos) + rayDirSign * 0.5 + 0.5) * deltaDist;
        
        int maxSteps = int(min(maxDist, 256.0));
        vec3 mask = vec3(0.0);
        
        for (int i = 0; i < maxSteps; i++) {
            // Check bounds
            if (any(lessThan(mapPos, ivec3(0))) || any(greaterThanEqual(mapPos, ivec3(volumeSize)))) {
                break;
            }
            
            uint voxelData = texelFetch(voxel_sampler, mapPos, 0).r;
            
            // Hit any non-air block
            if (voxelData > 0u) {
                result.hit = true;
                result.voxelID = voxelData;
                
                // Calculate exact hit position
                // The hit normal is -step * mask.
                result.hitNormal = -vec3(step) * mask;
                
                // Recalculate distance based on the axis we hit
                float dist = 0.0;
                if (mask.x > 0.5) dist = (sideDist.x - deltaDist.x);
                else if (mask.y > 0.5) dist = (sideDist.y - deltaDist.y);
                else dist = (sideDist.z - deltaDist.z);
                
                result.hitPos = scenePos + rayDir * dist;
                // Nudge slightly out to avoid self-intersection
                result.hitPos += result.hitNormal * 0.001;
                
                break;
            }
            
            // DDA step
            mask = vec3(0.0);
            if (sideDist.x < sideDist.y) {
                if (sideDist.x < sideDist.z) {
                    sideDist.x += deltaDist.x;
                    mapPos.x += step.x;
                    mask.x = 1.0;
                } else {
                    sideDist.z += deltaDist.z;
                    mapPos.z += step.z;
                    mask.z = 1.0;
                }
            } else {
                if (sideDist.y < sideDist.z) {
                    sideDist.y += deltaDist.y;
                    mapPos.y += step.y;
                    mask.y = 1.0;
                } else {
                    sideDist.z += deltaDist.z;
                    mapPos.z += step.z;
                    mask.z = 1.0;
                }
            }
        }
        
        return result;
    }
#endif

#endif // VOXEL_PATH_TRACING_GLSL
