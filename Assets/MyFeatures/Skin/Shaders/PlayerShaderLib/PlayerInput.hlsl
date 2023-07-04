#ifndef PLAYERINPUT_HLSL_INCLUDED
#define PLAYERINPUT_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _EmissionMap_ST;
CBUFFER_END

TEXTURE2D(_BaseMap);       SAMPLER(sampler_BaseMap);
TEXTURE2D(_EmissionMap);       SAMPLER(sampler_EmissionMap);

#endif