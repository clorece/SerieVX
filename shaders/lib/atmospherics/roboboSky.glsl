/*
 * roboboSky.glsl
 * Physical sky model with Rayleigh/Mie scattering
 */

#ifndef ROBOBO_SKY_GLSL
#define ROBOBO_SKY_GLSL

//============================================================================//
//                              LIGHT SETTINGS                                //
//============================================================================//

#define SUN_ILLUMINANCE 100.0 //[100.0 128000.0]
#define MOON_ILLUMINANCE 10.0 //[0.05 60.0]

#define SUN_COLOR_R 1.0 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]
#define SUN_COLOR_G 0.9 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]
#define SUN_COLOR_B 0.81 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]
#define SUN_COLOR_BASE (vec3(SUN_COLOR_R,SUN_COLOR_G,SUN_COLOR_B) * SUN_ILLUMINANCE)

#define MOON_COLOR_R 0.25 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]
#define MOON_COLOR_G 0.65 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]
#define MOON_COLOR_B 1.0 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]
#define MOON_COLOR_BASE (vec3(MOON_COLOR_R, MOON_COLOR_G, MOON_COLOR_B) * MOON_ILLUMINANCE)

//============================================================================//
//                           ATMOSPHERE GEOMETRY                              //
//============================================================================//

#define PLANET_RADIUS 6731e3
#define ATMOSPHERE_HEIGHT 110e3
#define SCALE_HEIGHTS vec2(8.0e3, 1.2e3)

//============================================================================//
//                         SCATTERING COEFFICIENTS                            //
//============================================================================//

#define MIE_G 0.80 //[0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0 ]

#define COEFF_RAYLEIGH_R 5.8 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.8 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 ]
#define COEFF_RAYLEIGH_G 1.35 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.8 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 ]
#define COEFF_RAYLEIGH_B 3.31 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.8 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 ]
#define COEFF_RAYLEIGH vec3(COEFF_RAYLEIGH_R*1e-6, COEFF_RAYLEIGH_G*1e-5, COEFF_RAYLEIGH_B*1e-5)

#define COEFF_MIE_R 3.0 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 ]
#define COEFF_MIE_G 3.0 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.8 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 ]
#define COEFF_MIE_B 3.0 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.7 5.8 5.9 6.0 6.1 6.2 6.3 6.4 6.5 6.6 6.7 6.8 6.9 7.0 7.1 7.2 7.3 7.4 7.5 7.6 7.7 7.8 7.9 8.0 8.1 8.2 8.3 8.4 8.5 8.6 8.7 8.8 8.9 9.0 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10.0 ]
#define COEFF_MIE vec3(COEFF_MIE_R*1e-6, COEFF_MIE_G*1e-6, COEFF_MIE_B*1e-6)

//============================================================================//
//                             OZONE ABSORPTION                               //
//============================================================================//

#define AIR_NUMBER_DENSITY 2.5035422e25
#define OZONE_CONCENTRATION_PEAK 8e-6
#define OZONE_CROSS_SECTION vec3(2.0e-21, 6.0e-21, 2.0e-22)

//============================================================================//
//                              DERIVED CONSTANTS                             //
//============================================================================//

const float rPI = 1.0 / pi;
const float rLOG2 = 1.0 / log(2.0);

const float sunAngularSize = 0.533333;
const float moonAngularSize = 0.516667;

const float OZONE_NUMBER_DENSITY = AIR_NUMBER_DENSITY * OZONE_CONCENTRATION_PEAK;
const vec3 COEFF_OZONE = (OZONE_CROSS_SECTION * (OZONE_NUMBER_DENSITY * 1.0e-6));

const vec2 INVERSE_SCALE_HEIGHTS = 1.0 / SCALE_HEIGHTS;
const vec2 SCALED_PLANET_RADIUS = PLANET_RADIUS * INVERSE_SCALE_HEIGHTS;
const float ATMOSPHERE_RADIUS = PLANET_RADIUS + ATMOSPHERE_HEIGHT;
const float ATMOSPHERE_RADIUS_SQUARED = ATMOSPHERE_RADIUS * ATMOSPHERE_RADIUS;

#define COEFF_SCATTERING mat2x3(COEFF_RAYLEIGH, COEFF_MIE)
const mat3 COEFF_ATTENUATION = mat3(COEFF_RAYLEIGH, COEFF_MIE * 1.11, COEFF_OZONE);

//============================================================================//
//                               UTILITY MACROS                               //
//============================================================================//

#define clamp01(x) clamp(x, 0.0, 1.0)

//============================================================================//
//                            RAY-SPHERE UTILITIES                            //
//============================================================================//

#ifndef RSI_FUNCTION
#define RSI_FUNCTION
vec2 GetRaySphereIntersection(vec3 position, vec3 direction, float radius) {
	float PoD = dot(position, direction);
	float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
	delta = sqrt(delta);

	return -PoD + vec2(-delta, delta);
}
#endif

//============================================================================//
//                              PHASE FUNCTIONS                               //
//============================================================================//

float GetRayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) * rPI;
	return cosTheta * mul_add.x + mul_add.y;
}

float GetMiePhase(float cosTheta, const float g) {
	float gg = g * g;
	return (gg * -0.25 + 0.25) * rPI * pow(-(2.0 * g) * cosTheta + (gg + 1.0), -1.5);
}

vec2 GetPhase(float cosTheta, const float g) {
	return vec2(GetRayleighPhase(cosTheta), GetMiePhase(cosTheta, g));
}

//============================================================================//
//                          ATMOSPHERE DENSITY MODEL                          //
//============================================================================//

vec3 GetAtmosphereDensity(float centerDistance) {
	vec2 rayleighMie = exp(centerDistance * -INVERSE_SCALE_HEIGHTS + SCALED_PLANET_RADIUS);

	float ozone = exp(-max(0.0, (35000.0 - centerDistance) - PLANET_RADIUS) * (1.0 / 5000.0))
	            * exp(-max(0.0, (centerDistance - 35000.0) - PLANET_RADIUS) * (1.0 / 15000.0));
	
	return vec3(rayleighMie, ozone);
}

//============================================================================//
//                          AIRMASS / OPTICAL DEPTH                           //
//============================================================================//

vec3 GetAirmass(vec3 position, vec3 direction, float rayLength, const float steps) {
	float stepSize  = rayLength * (1.0 / steps);
	vec3  increment = direction * stepSize;
	position += increment * 0.5;

	vec3 airmass = vec3(0.0);
	for (int i = 0; i < steps; ++i, position += increment) {
		airmass += GetAtmosphereDensity(length(position));
	}

	return airmass * stepSize;
}

vec3 GetAirmass(vec3 position, vec3 direction, const float steps) {
	float rayLength = dot(position, direction);
	      rayLength = rayLength * rayLength + ATMOSPHERE_RADIUS_SQUARED - dot(position, position);
		  if (rayLength < 0.0) return vec3(0.0);
	      rayLength = sqrt(rayLength) - dot(position, direction);

	return GetAirmass(position, direction, rayLength, steps);
}

vec3 GetOpticalDepth(vec3 position, vec3 direction, float rayLength, const float steps) {
	return COEFF_ATTENUATION * GetAirmass(position, direction, rayLength, steps);
}

vec3 GetOpticalDepth(vec3 position, vec3 direction, const float steps) {
	return COEFF_ATTENUATION * GetAirmass(position, direction, steps);
}

//============================================================================//
//                           TRANSMITTANCE SAMPLING                           //
//============================================================================//

vec3 GetAtmosphereTransmittance(vec3 position, vec3 direction, const float steps) {
	return exp2(-GetOpticalDepth(position, direction, steps) * rLOG2);
}

//============================================================================//
//                        MAIN ATMOSPHERE SCATTERING                          //
//============================================================================//

vec3 GetAtmosphere(
	vec3 background, 
	vec3 nViewPos, 
	vec3 upVec, 
	vec3 sunVec, 
	vec3 moonVec, 
	out vec2 pid, 
	out vec3 transmittance, 
	const int iSteps, 
	float dither, 
	float stepMult, 
	bool doMie
) {
	const int jSteps = 4;

	vec3 viewPos = (PLANET_RADIUS + eyeAltitude) * upVec;

	// Atmosphere intersection
	vec2 aid = GetRaySphereIntersection(viewPos, nViewPos, ATMOSPHERE_RADIUS);
	if (aid.y < 0.0) {
		transmittance = vec3(1.0); 
		return vec3(0.0);
	}

	// Planet intersection
	pid = GetRaySphereIntersection(viewPos, nViewPos, PLANET_RADIUS * 0.998);
	bool planetIntersected = pid.y >= 0.0;

	// Compute ray segment
	vec2 sd = vec2(
		(planetIntersected && pid.x < 0.0) ? pid.y : max(aid.x, 0.0), 
		(planetIntersected && pid.x > 0.0) ? pid.x : aid.y
	);

	float stepSize  = (sd.y - sd.x) * (1.0 / float(iSteps)) * stepMult;
	vec3  increment = nViewPos * stepSize;
	vec3  position  = nViewPos * sd.x + viewPos;
	position += increment * 0.34;

	// Phase function setup
	vec2 phaseSun  = GetPhase(dot(nViewPos, sunVec ), MIE_G);
	vec2 phaseMoon = GetPhase(dot(nViewPos, moonVec), MIE_G);

	// Mie phase horizon fade
	if (doMie) {
		float VdotU = dot(nViewPos, upVec);
		float mieFade = smoothstep(-0.01, 0.05, VdotU);
		phaseSun.y *= mieFade;
		phaseMoon.y *= mieFade;
	} else {
		phaseSun.y = 0.0;
		phaseMoon.y = 0.0;
	}

	// Accumulation variables
	vec3 scatteringSun     = vec3(0.0);
	vec3 scatteringMoon    = vec3(0.0);
	vec3 scatteringAmbient = vec3(0.0);
	transmittance = vec3(1.0);

	float currentDist = 0.0;
	float maxDist = sd.y - sd.x;

	// Main integration loop
	for (int i = 0; i < iSteps; ++i, position += increment) {
		if (currentDist > maxDist) break;
		
		vec3 density = GetAtmosphereDensity(length(position));
		if (density.y > 1e35) break;

		vec3 stepAirmass      = density * stepSize;
		vec3 stepOpticalDepth = COEFF_ATTENUATION * stepAirmass;

		vec3 stepTransmittance       = exp2(-stepOpticalDepth * rLOG2);
		vec3 stepTransmittedFraction = clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);
		vec3 stepScatteringVisible   = transmittance * stepTransmittedFraction;

		// Sun and Moon single-scattering
		scatteringSun  += COEFF_SCATTERING * (stepAirmass.xy * phaseSun ) * stepScatteringVisible * GetAtmosphereTransmittance(position, sunVec,  jSteps);
		scatteringMoon += COEFF_SCATTERING * (stepAirmass.xy * phaseMoon) * stepScatteringVisible * GetAtmosphereTransmittance(position, moonVec, jSteps);

		// Ambient scattering
		scatteringAmbient += COEFF_SCATTERING * stepAirmass.xy * stepScatteringVisible;

		transmittance *= stepTransmittance;
		currentDist += stepSize;
	}

	// Combine all scattering contributions
	vec3 scattering = scatteringSun * SUN_COLOR_BASE 
	                + scatteringAmbient * background 
	                + scatteringMoon * MOON_COLOR_BASE;

	// Weather and time adjustments
	scattering = max(mix(
		scattering, 
		mix(vec3(1.0, 1.0, 1.0) - nightFactor, scattering, 1.0 - rainFactor), 
		nightFactor + rainFactor
	), vec3(0.0));
	
	scattering = pow(scattering, vec3(1.0 / 1.2)) * 0.5;

	// Dither to reduce banding
	scattering += (dither - 0.5) / 64.0;

	return scattering;
}

//============================================================================//
//                       CONVENIENCE OVERLOADS                                //
//============================================================================//

vec3 GetAtmosphere(
	vec3 background, 
	vec3 nViewPos, 
	vec3 upVec, 
	vec3 sunVec, 
	vec3 moonVec, 
	out vec2 pid, 
	out vec3 transmittance, 
	const int iSteps, 
	float dither, 
	float stepMult
) {
	return GetAtmosphere(background, nViewPos, upVec, sunVec, moonVec, pid, transmittance, iSteps, dither, stepMult, true);
}

vec3 GetAtmosphere(
	vec3 background, 
	vec3 nViewPos, 
	vec3 upVec, 
	vec3 sunVec, 
	vec3 moonVec, 
	out vec2 pid, 
	out vec3 transmittance, 
	const int iSteps, 
	float dither
) {
	return GetAtmosphere(background, nViewPos, upVec, sunVec, moonVec, pid, transmittance, iSteps, dither, 1.0);
}

//============================================================================//
//                          SUN AND MOON DISC RENDERING                       //
//============================================================================//

vec3 GetSunAndMoon(vec3 nViewPos, vec3 sunVec, vec3 moonVec, vec3 upVec, vec3 transmittance) {
	vec3 scattering = vec3(0.0);
	
	vec3 viewPos = (PLANET_RADIUS + eyeAltitude) * upVec;
	vec2 pid = GetRaySphereIntersection(viewPos, nViewPos, PLANET_RADIUS * 0.998);
	bool planetIntersected = pid.y >= 0.0;
	
	if (!planetIntersected) {
		// Sun disc
		float sunHalfAngle = sunAngularSize * pi / 180.0 * 0.5;
		float sunCos = cos(sunHalfAngle);
		float sunViewDot = dot(nViewPos, sunVec);
		float sunDisc = smoothstep(sunCos - 0.0001, sunCos + 0.0001, sunViewDot);
		scattering += SUN_COLOR_BASE * transmittance * sunDisc * 50.0 * (1.0 - rainFactor);

		// Moon disc
		float moonHalfAngle = moonAngularSize * pi / 180.0 * 0.5;
		float moonCos = cos(moonHalfAngle);
		float moonViewDot = dot(nViewPos, moonVec);
		float moonDisc = smoothstep(moonCos - 0.0001, moonCos + 0.0001, moonViewDot);
		scattering += MOON_COLOR_BASE * transmittance * moonDisc * 50.0 * (1.0 - rainFactor);
	}
	
	scattering = pow(scattering, vec3(1.0 / 1.2)) * 0.5;
	return scattering;
}

#endif
