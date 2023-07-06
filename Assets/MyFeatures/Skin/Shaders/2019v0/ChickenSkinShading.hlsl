#ifndef CHICKEN_SKIN_SHADING_HLSL_INCLUDED
#define CHICKEN_SKIN_SHADING_HLSL_INCLUDED

#include "ChickenSkinLighting.hlsl"

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
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

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
    o.viewDirWS = GetCameraPositionWS() - vpi.positionWS;
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
    inputData.viewDirectionWS = SafeNormalize(input.viewDirWS);
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
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
    half4 baseMap = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    surfaceData.alpha = _BaseColor.a;
    surfaceData.albedo = baseMap.rgb * _BaseColor;
    // no need surface ao
    surfaceData.occlusion = half(1.0);
    // constant smoothness for skin
    surfaceData.smoothness = _Smoothness;
    surfaceData.metallic = 0.0;
    surfaceData.specular = half3(0.0, 0.0, 0.0);
    //surfaceData.specular = _SpecularColor.rgb;

    skinSurfaceData = (SkinSurfaceData)0;
    skinSurfaceData.thickness = baseMap.a;
    skinSurfaceData.sssStrength = _ScatteringStrength;
}

inline half3 LinearToGammaSpace(half3 linRGB)
{
    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
}

half4 frag(Varyings input) : SV_Target
{
    InputData inputData;
    InitializeInputData(input, inputData);

    //return _BaseColor;
    SurfaceData surfaceData;
    SkinSurfaceData skinSurfaceData;
    InitializeSkinSurfaceData(input.uv0, surfaceData, skinSurfaceData);

    //return half4(surfaceData.albedo, 1);

    half3 diffuseNormalWS = NormalizeNormalPerPixel(input.normalWS);

    half4 color = SkinPBR(inputData, surfaceData, skinSurfaceData, _SubSurfaceColor, diffuseNormalWS, _SpecularAO, _BackScattering);
    
    return color;

    return half4(surfaceData.albedo, 1);

    color.rgb = LinearToGammaSpace(color.rgb);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    // Gamma
    //color = pow(color, 0.45);

    return color;
}
#endif