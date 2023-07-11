#ifndef CHICKEN_COMMON_INCLUDED
#define CHICKEN_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#if defined(_USE_SPECULAR) || defined(_USE_MATCAP) || defined(_USE_SPECULAR_CUSTOM)
    #define _USE_MASKTEX 1
#endif

#if defined(_USE_SPECULAR) || defined(_USE_SPECULAR_SIMPLE) || defined(_USE_RIM_LIGHT) || defined(_USE_SPECULAR_CUSTOM)
    #define _USE_VIEW_DIR 1
#endif

#if defined(_USE_MAINTEX) || defined(_USE_NORMALMAP) || defined(_USE_MASKTEX) || defined(_USE_MATCAP) || defined(_USE_SPECULAR)
    #define _USE_UV0 1
#endif

// turn on _RECEIVE_SHADOWS_OFF used by srp shader lib
#ifdef _USE_NOT_RECEIVE_SHADOW
    #define _RECEIVE_SHADOWS_OFF 1
#endif

#define PI          3.14159265358979323846
#define TWO_PI      6.28318530717958647693
#define FOUR_PI     12.5663706143591729538
#define INV_PI      0.31830988618379067154
#define INV_TWO_PI  0.15915494309189533577
#define INV_FOUR_PI 0.07957747154594766788
#define HALF_PI     1.57079632679489661923
#define INV_HALF_PI 0.63661977236758134308
#define LOG2_E      1.44269504088896340736
#define E           2.71828182845904523536
#define INV_SQR_TWO_PI    0.28209479177387814347

#endif