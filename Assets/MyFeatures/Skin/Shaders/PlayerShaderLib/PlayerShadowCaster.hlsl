#ifndef PLAYERSHADOWCASTER_HLSL_INCLUDED
#define PLAYERSHADOWCASTER_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
};

float3 _LightDirection;
float3 _LightPosition;

Varyings vert(Attributes v)
{
    Varyings o = (Varyings)0;
    // position
    VertexPositionInputs vpi = GetVertexPositionInputs(v.positionOS.xyz);
    o.positionCS = vpi.positionCS;

    float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldDir(v.normalOS);

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    #endif

    o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS * _SkinShadowSampleBias, lightDirectionWS));
    #if UNITY_REVERSED_Z
        o.positionCS.z = min(o.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        o.positionCS.z = max(o.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    return o;
}

half4 frag(Varyings input) : SV_Target
{
    return 0;
}

#endif