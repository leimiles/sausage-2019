#ifndef PLAYERINPUT_HLSL_INCLUDED
#define PLAYERINPUT_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
    half4 _BaseColor;
    float4 _BaseMap_ST;
    float4 _EmissionMap_ST;
    half _SpecularAO;
    half _SkinShadowSampleBias;
    half4 _SpecularColor;
    half _BackScattering;
    half4 _SubSurfaceColor;
    half _ScatteringStrength;
    half _Smoothness;
    half _TranslucencyPower;
    half _ShadowStrength;
    half _MinDitherDistance;
    half _MaxDitherDistance;
    float4 _ObjectPosition;
CBUFFER_END

// no need, declared in surfaceinput.hlsl
//TEXTURE2D(_BaseMap);       SAMPLER(sampler_BaseMap);
//TEXTURE2D(_EmissionMap);       SAMPLER(sampler_EmissionMap);
TEXTURE2D(_CEAMap);       SAMPLER(sampler_CEAMap);
TEXTURE2D(_SkinRampMap);       SAMPLER(sampler_SkinRampMap);
TEXTURE2D(_MetallicGlossMap);       SAMPLER(sampler_MetallicGlossMap);

struct SkinSurfaceData
{
    half curvature;
    half emission_Mask;
    half ao;
    half thickness;
    half SSSMaskAndThickness;
};


#endif