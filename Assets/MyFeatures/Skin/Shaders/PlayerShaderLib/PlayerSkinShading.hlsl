#ifndef PLAYERSHADING_HLSL_INCLUDED
#define PLAYERSHADING_HLSL_INCLUDED

#include "PlayerSkinLighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv0 : TEXCOORD0;
    half3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
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

bool IsPerspectiveProjection()
{
    return (unity_OrthoParams.w == 0);
}

half3 GetWorldSpaceNormalizeViewDir(float3 positionWS)
{
    if (IsPerspectiveProjection())
    {
        // Perspective
        float3 V = _WorldSpaceCameraPos.xyz - positionWS;
        return half3(normalize(V));
    }
    else
    {
        // Orthographic
        float4x4 viewMat = UNITY_MATRIX_V;
        return -viewMat[2].xyz;
    }
}

Varyings vert(Attributes v)
{
    Varyings o = (Varyings)0;
    // position
    VertexPositionInputs vpi = GetVertexPositionInputs(v.positionOS.xyz);
    o.positionCS = vpi.positionCS;
    o.positionWS = vpi.positionWS;
    // uv
    o.uv0 = TRANSFORM_TEX(v.uv0, _BaseMap);
    // normal
    VertexNormalInputs vni = GetVertexNormalInputs(v.normalOS);
    o.normalWS = vni.normalWS;
    // view
    o.viewDirWS = SafeNormalize(GetWorldSpaceNormalizeViewDir(vpi.positionWS));
    // shadow
    //o.shadowCoord = TransformWorldToShadowCoord(vpi.positionWS);
    vpi.positionWS += vni.normalWS.xyz * _SkinShadowSampleBias;
    o.shadowCoord = GetShadowCoord(vpi);
    // fog
    o.vertexLightAndFog.rgb = VertexLighting(vpi.positionWS, vni.normalWS);
    o.vertexLightAndFog.w = ComputeFogFactor(vpi.positionCS.z);
    // sh
    o.sh = SampleSH(vni.normalWS);

    return o;
}

void InitializeInputData(Varyings input, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    //inputData.positionCS = input.positionCS;
    inputData.normalWS = SafeNormalize(input.normalWS);
    inputData.viewDirectionWS = input.viewDirWS;
    inputData.shadowCoord = input.shadowCoord;
    inputData.fogCoord = input.vertexLightAndFog.w;
    inputData.vertexLighting = input.vertexLightAndFog.rgb;
    inputData.bakedGI = input.sh;
    //inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);;
    //inputData.shadowMask = 0;
    //inputData.tangentToWorld = 0;

}

void InitializeSkinSurfaceData(float2 uv, out SurfaceData surfaceData, out SkinSurfaceData skinSurfaceData)
{
    surfaceData = (SurfaceData)0;
    surfaceData.albedo = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).rgb * _BaseColor.rgb;
    // no need surface ao
    surfaceData.occlusion = half(1.0);
    // no need clear coat
    //surfaceData.clearCoatSmoothness = half(0.0);
    //surfaceData.clearCoatMask = half(0.0);
    // constant smoothness for skin
    surfaceData.smoothness = _Smoothness;
    surfaceData.specular = _SpecularColor.rgb;

    skinSurfaceData = (SkinSurfaceData)0;
    half4 CEAT_Color = SAMPLE_TEXTURE2D(_CEATMap, sampler_CEATMap, uv);
    skinSurfaceData.curvature = CEAT_Color.r;
    skinSurfaceData.emission_Mask = CEAT_Color.g;
    skinSurfaceData.ao = CEAT_Color.b;
    skinSurfaceData.thickness = CEAT_Color.a * _ScatteringStrength;
}
/*
inline float GammaToLinearSpaceExact(float value)
{
    if (value <= 0.04045F)
        return value / 12.92F;
    else if (value < 1.0F)
        return pow((value + 0.055F) / 1.055F, 2.4F);
    else
        return pow(value, 2.2F);
}

inline half3 GammaToLinearSpace(half3 sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);
}

inline float LinearToGammaSpaceExact(float value)
{
    if (value <= 0.0F)
        return 0.0F;
    else if (value <= 0.0031308F)
        return 12.92F * value;
    else if (value < 1.0F)
        return 1.055F * pow(value, 0.4166667F) - 0.055F;
    else
        return pow(value, 0.45454545F);
}
*/

half4 frag(Varyings input) : SV_Target
{
    half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0);
    //return baseColor;
    //return half4(0, 1, 0, 1);
    //return half4(LinearToGammaSpace(input.normalWS.rgb), 1);

    InputData inputData;
    InitializeInputData(input, inputData);

    //return half4(LinearToGammaSpace(input.shadowCoord.xyz), 1);
    //return half4(input.shadowCoord.xyz, 1);

    SurfaceData surfaceData;
    SkinSurfaceData skinSurfaceData;
    InitializeSkinSurfaceData(input.uv0, surfaceData, skinSurfaceData);
    half3 diffuseNormalWS = NormalizeNormalPerPixel(input.normalWS);

    //AmbientOcclusionFactor ao = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfaceData.occlusion);
    //return half4(ao.indirectAmbientOcclusion, ao.indirectAmbientOcclusion, ao.indirectAmbientOcclusion, 1.0) * baseColor;
    half4 color = SkinPBR(inputData, surfaceData, skinSurfaceData, _SubSurfaceColor, diffuseNormalWS, _SpecularAO, _BackScattering);

    return color;
}
#endif