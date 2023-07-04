#ifndef PLAYERSHADING_HLSL_INCLUDED
#define PLAYERSHADING_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv0 : TEXCOORD0;
    half3 normalOS : NORMAL;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv0 : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    half3 viewDirWS : TEXCOORD3;
    float4 shadowCoord : TEXCOORD4;
    half4 vertexLightAndFog : TEXCOORD5;
    half3 sh : COLOR0;
};


Varyings vert(Attributes v)
{
    Varyings o = (Varyings)0;
    VertexPositionInputs vpi = GetVertexPositionInputs(v.positionOS.xyz);
    o.positionCS = vpi.positionCS;
    o.uv0 = TRANSFORM_TEX(v.uv0, _BaseMap);
    o.positionWS = vpi.positionWS;
    VertexNormalInputs vni = GetVertexNormalInputs(v.normalOS);
    o.normalWS = vni.normalWS;
    o.viewDirWS = SafeNormalize(GetWorldSpaceNormalizeViewDir(vpi.positionWS));
    o.shadowCoord = TransformWorldToShadowCoord(vpi.positionWS);
    o.vertexLightAndFog.rgb = VertexLighting(vpi.positionWS, vni.normalWS);
    o.vertexLightAndFog.w = ComputeFogFactor(vpi.positionCS.z);
    o.sh = SampleSH(vni.normalWS);
    return o;
}

void InitializeInputData(Varyings input, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;
    inputData.normalWS = input.normalWS;
    inputData.viewDirectionWS = input.viewDirWS;
    inputData.shadowCoord = input.shadowCoord;
    inputData.fogCoord = input.vertexLightAndFog.w;
    inputData.vertexLighting = input.vertexLightAndFog.rgb;
    inputData.bakedGI = input.sh;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);;
    inputData.shadowMask = 0;
    inputData.tangentToWorld = 0;
}

half4 frag(Varyings input) : SV_Target
{
    half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0);
    InputData inputdata;
    InitializeInputData(input, inputdata);
    //return half4(inputdata.normalizedScreenSpaceUV.rg, 1, 1);

    AmbientOcclusionFactor ao = CreateAmbientOcclusionFactor(inputdata.normalizedScreenSpaceUV, 0.5);
    return half4(ao.indirectAmbientOcclusion, ao.indirectAmbientOcclusion, ao.indirectAmbientOcclusion, 1.0 ) * baseColor;
}
#endif