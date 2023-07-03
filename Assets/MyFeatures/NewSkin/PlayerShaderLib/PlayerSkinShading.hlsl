#ifndef PLAYERSHADING_HLSL_INCLUDED
#define PLAYERSHADING_HLSL_INCLUDED

#include "PlayerSkinLighting.hlsl"
#include "PlayerDitherFading.hlsl"

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
    #ifdef _DITHER_FADING_ON
        float4 positionSS : TEXCOORD6;
    #endif
    half3 normalWS : TEXCOORD2;
    half3 viewDirWS : TEXCOORD3;
    float4 shadowCoord : TEXCOORD4;
    half4 vertexLightAndFog : TEXCOORD5;
    half3 sh : COLOR0;
};

Varyings vert(Attributes v)
{
    Varyings o = (Varyings)0;
    // position
    VertexPositionInputs vpi = GetVertexPositionInputs(v.positionOS.xyz);
    o.positionCS = vpi.positionCS;
    o.positionWS = vpi.positionWS;
    // screen position
    #ifdef _DITHER_FADING_ON
        o.positionSS = ComputeScreenPos(o.positionCS);
    #endif
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
    inputData.positionCS = input.positionCS;
    inputData.normalWS = SafeNormalize(input.normalWS);
    inputData.viewDirectionWS = input.viewDirWS;
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
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);;
    inputData.shadowMask = 0;
    inputData.tangentToWorld = 0;
}

void InitializeSkinSurfaceData(float2 uv, out SurfaceData surfaceData, out SkinSurfaceData skinSurfaceData)
{
    surfaceData = (SurfaceData)0;
    half4 baseMap = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    surfaceData.alpha = baseMap.a * _BaseColor.a;
    surfaceData.albedo = baseMap.rgb * _BaseColor;
    // no need surface ao
    surfaceData.occlusion = half(1.0);
    // no need clear coat
    surfaceData.clearCoatSmoothness = half(0.0);
    surfaceData.clearCoatMask = half(0.0);
    // constant smoothness for skin
    #if _METALLICMAP_ON
        half4 specGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
        surfaceData.smoothness = specGloss.a * _Smoothness;
        surfaceData.metallic = specGloss.r;
    #else
        surfaceData.smoothness = _Smoothness;
        surfaceData.metallic = 0.0;
    #endif
    surfaceData.specular = half3(0.0, 0.0, 0.0);

    skinSurfaceData = (SkinSurfaceData)0;
    half4 CEA_Color = SAMPLE_TEXTURE2D(_CEAMap, sampler_CEAMap, uv);
    skinSurfaceData.curvature = CEA_Color.r;
    skinSurfaceData.emission_Mask = CEA_Color.g;
    skinSurfaceData.ao = CEA_Color.b;
    //skinSurfaceData.thickness = CEAT_Color.a * _ScatteringStrength;
    skinSurfaceData.SSSMaskAndThickness = baseMap.a * _ScatteringStrength;
}

half4 frag(Varyings input) : SV_Target
{
    InputData inputData;
    InitializeInputData(input, inputData);
    SurfaceData surfaceData;
    SkinSurfaceData skinSurfaceData;
    InitializeSkinSurfaceData(input.uv0, surfaceData, skinSurfaceData);
    half3 diffuseNormalWS = NormalizeNormalPerPixel(input.normalWS);

    //AmbientOcclusionFactor ao = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfaceData.occlusion);
    //return half4(ao.indirectAmbientOcclusion, ao.indirectAmbientOcclusion, ao.indirectAmbientOcclusion, 1.0) * baseColor;
    //half4 color = SkinPBR(inputData, surfaceData, skinSurfaceData, _SubSurfaceColor, diffuseNormalWS, _SpecularAO, _BackScattering);
    half4 color = SkinPBRWithMask(inputData, surfaceData, skinSurfaceData, _SubSurfaceColor, diffuseNormalWS, _SpecularAO, _BackScattering);

    // camera dither fading
    #if _DITHER_FADING_ON
        float4 distanceDither = distance(_WorldSpaceCameraPos.xyz, _ObjectPosition.xyz);
        distanceDither = 1 - Remap(distanceDither, half2(_MaxDitherDistance, _MinDitherDistance), half2(0, 1));
        half dither = DitherMatrix(distanceDither, input.positionSS).r;
        clip(dither);
    #endif

    #if FOG_ON
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
    #endif

    //color.a = 1;

    return color;
}
#endif