#ifndef INPUT_SKIN_V2019_INCLUDED
#define INPUT_SKIN_V2019_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "./skin_v2019_lighting.hlsl"

CBUFFER_START(UnityPerMaterial)

    float4 _BaseMap_ST;
    half4 _BaseColor;
    half _Smoothness;
    half3 _SpecularColor;
    half _OcclusionStrength;
    half3 _SubsurfaceColor;
    half _Curvature;
    half _TranslucencyPower;
    half _TranslucencyStrength;
    half _ShadowStrength;
    half _Distortion;

CBUFFER_END

TEXTURE2D(MTAMap); SAMPLER(sampler_MTAMap);

struct VertexInput
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
        DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
        //#ifdef _ADDITIONAL_LIGHTS
        float3 positionWS : TEXCOORD2;
        //#endif
        #ifdef _NORMALMAP
            half4 normalWS : TEXCOORD3;
            half4 tangentWS : TEXCOORD4;
            half4 bitangentWS : TEXCOORD5;
        #else
            half3 normalWS : TEXCOORD3;
            half3 viewDirWS : TEXCOORD4;
        #endif
        half4 fogFactorAndVertexLight : TEXCOORD6;

        #ifdef _MAIN_LIGHT_SHADOWS
            float4 shadowCoord : TEXCOORD7;
        #endif

    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct SkinSurfaceData
{
    half3 albedo;
    half alpha;
    half3 normalTS;
    half3 diffuseNormalTS;
    half3 emission;
    half metallic;
    half3 specular;
    half smoothness;
    half occlusion;
    half translucency;
    half skinMask;
};
#endif