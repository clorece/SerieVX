#ifndef NOISE_GLSL
#define NOISE_GLSL

float Noise3D(vec3 position) {
    position.z = fract(position.z) * 128.0;
    float zInteger = floor(position.z);
    float zFraction = fract(position.z);
    
    zFraction = zFraction * zFraction * (3.0 - 2.0 * zFraction);
    
    vec2 offsetA = vec2(23.0, 29.0) * (zInteger) / 128.0;
    vec2 offsetB = vec2(23.0, 29.0) * (zInteger + 1.0) / 128.0;
    float noiseA = texture2D(noisetex, position.xy + offsetA).r;
    float noiseB = texture2D(noisetex, position.xy + offsetB).r;
    return mix(noiseA, noiseB, zFraction);
}

#endif
