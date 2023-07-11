#ifndef CHICKEN_GRASSPC_INSTANCED_INCLUDED
#define CHICKEN_GRASSPC_INSTANCED_INCLUDED

#include "Chicken-Common.hlsl"
#include "Chicken-CustomFunction.hlsl"

#ifdef _USE_WIND
    #define _USE_NOISE
#endif
#ifdef _USE_WAVE
    #define _USE_NOISE_DETAIL
#endif
#ifdef _DEBUG_TERRAIN
    #define _USE_TERRAIN
#endif

struct Attributes
{
    float4 vertex : POSITION;
    #ifdef _USE_NORMAL
        half3 normal : NORMAL;
    #endif
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posCS : SV_POSITION;
    half2 uv : TEXCOORD0; // uv0 : xy
    half4 posWSAndFogFactor : TEXCOORD1; // xyz: posW, w: fogFactor
    #ifdef _USE_TERRAIN
        half4 colorUp : COLOR3;
        half4 colorMiddle : COLOR1;
        half4 colorDown : COLOR2;
    #endif
    #ifdef _USE_NORMAL
        half3 vertexSH : TEXCOORD2;
        half3 normal : TEXCOORD3;
    #endif
    #ifdef _USE_VIEW_DIR
        half3 viewDir : TEXCOORD4;
    #endif
    #ifdef _MAIN_LIGHT_SHADOWS
        float4 shadowCoord : TEXCOORD5;
    #endif
    // calc addition light in vertex
    #ifdef _USE_VERTEX_LIGHT
        half4 vertexLight : TEXCOORD6; // xyz used, w reserved
    #endif
    // calc main light diffuse term in vertex ,but specular term not.
    #ifdef _USE_VERTEX_DIFFUSE_MAINLIGHT
        half3 vertexDiffuseMainLight : TEXCOORD7;
    #endif
    #ifdef _USE_STATIC_GI
        half3 staticNormal : TEXCOORD8;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct MeshProperties
{
    float4x4 mat;
};

StructuredBuffer<MeshProperties> _Properties;

// #ifdef _USE_MAINTEX
//     TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
// #endif
#ifdef _USE_RAMPTEX
    TEXTURE2D(_RampTex); SAMPLER(sampler_RampTex);
#endif
#ifdef _USE_NOISE
    //TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
    sampler2D _NoiseTex;
#endif
#ifdef _USE_NOISE_DETAIL
    sampler2D _NoiseDetailTex;
#endif
#ifdef _USE_TERRAIN

    sampler2D _TerrainColor;
    // sampler2D _TerrainMap1;
    // sampler2D _TerrainMap2;
    // sampler2D _TerrainMap3;
    // sampler2D _TerrainMap4;
    // sampler2D _ColorMapUp;
    // sampler2D _ColorMapDown;
#endif

CBUFFER_START(UnityPerMaterial)
    #ifdef _USE_SPLIT_COLOR
        half4 _ColorU01;
        half4 _ColorU02;
        half4 _ColorU03;
        half4 _ColorU04;
        half4 _ColorU05;
        half4 _ColorU06;
        half4 _ColorU07;
        half4 _ColorU08;
        half4 _ColorU09;
        half4 _ColorU10;
        half4 _ColorU11;
        half4 _ColorU12;
        half4 _ColorU13;
        half4 _ColorU14;
        half4 _ColorU15;
        half4 _ColorU16;
    #endif
    #ifdef _USE_TERRAIN
        half4 _ColorUp;
        half4 _ColorMiddle;
        half4 _WPosST;
        half4 _BlendRatio;
    #endif
    #ifdef _USE_WIND
        half4 _WindVector;
    #endif
    #ifdef _USE_NOISE
        half4 _NoiseTex_ST;
    #endif
    #if defined(_USE_NOISE_DETAIL) || defined(_HAVE_GRASS_LOD)
        half4 _NoiseDetailTex_ST;
    #endif
    #ifdef _USE_COLOR
        half4 _Color;
    #endif
    #ifdef _USE_SHADOW_COLOR
        half3 _ShadowColor;
    #endif
    #ifdef _USE_ALPHA
        half _Alpha;
    #endif
    #ifdef _USE_ATTENBIAS
        half _AttenBias;
    #endif
    #ifdef _USE_ALPHA_TEST
        half _Cutoff;
    #endif
    #ifdef _USE_WIND
        half _WindFrequency;
        half _WindStrength;
    #endif
    #if defined(_USE_WAVE) || defined(_HAVE_GRASS_LOD)
        half _WaveFrequency;
        half _WaveStrength;
    #endif
    #ifdef _USE_REACT

        half _ActRadius;
        half _ActStrength;
        half _ActOffset;
    #endif
    #ifdef _USE_TERRAIN
        half _Weight;
        half _Edge;
    #endif
    #ifdef _USE_LIGHT_STRENGTH
        half _LightStrength;
    #endif

    #ifdef _HAVE_GRASS_LOD
        half _VerticalBillboarding;
    #endif
CBUFFER_END
#ifdef _USE_REACT
    float4 _RolePos[16];
    // int _RoleCount;
#endif
#ifdef _USE_CUSTOMCOLOR
    half4 _PlantSingleColor;
    half4 _PlantPairOneColor;
    half4 _PlantPairTwoColor;
    half _PlantLightness;
#endif

half3 GetDeltaWindPos(float3 worldPos, float2 uv)
{
    #ifdef _USE_WIND
        float2 uvWind = worldPos.xz * _NoiseTex_ST.xy + _WindFrequency * _Time.y + _NoiseTex_ST.zw;
        half windSample = tex2Dlod(_NoiseTex, float4(uvWind, 0, 0)).r;
        return windSample * normalize(_WindVector.xyz) * _WindStrength * uv.y * uv.y;
    #else
        return half3(0, 0, 0);
    #endif
}

half3 GetDeltaWavePos(float3 worldPos, float2 uv)
{
    #ifdef _USE_WAVE
        float2 uvWave = worldPos.xz * _NoiseDetailTex_ST.xy + _WaveFrequency * _Time.y + _NoiseDetailTex_ST.zw;
        half2 waveSample = tex2Dlod(_NoiseDetailTex, float4(uvWave, 0, 0)).xy;
        return half3(waveSample.x, 0, waveSample.y) * _WaveStrength * uv.y * uv.y;
    #else
        return half3(0, 0, 0);
    #endif
}

half3 GetDeltaReactPos(float3 worldPos, float2 uv)
{
    #ifdef _USE_REACT
        half3 deltaReactPos = half3(0, 0, 0);
        // _RolePos[0] = float4(-1, 0, 0, 1);
        // _RolePos[1] = float4(1, 0, 0, 1);
        // _RoleCount = 2;

        for (int i = 0; i < 16; i++)
        {
            float4 thisPos = _RolePos[i];
            // float4 thisPos = float4(0,0,0,1);
            thisPos.y += _ActOffset;
            float dis = distance(thisPos.xyz, worldPos.xyz);
            float pushDown = saturate(1 - dis + thisPos.w * _ActRadius) * uv.y * uv.y * _ActStrength;
            // float3 direction = normalize(worldPos.xyz - thisPos.xyz);
            float3 direction = normalize(float3(worldPos.x, 0, worldPos.z) - float3(thisPos.x, 0, thisPos.z) + float3(0, -0.1f, 0));
            deltaReactPos += direction * pushDown;
        }

        return normalize(deltaReactPos + float3(0.001f, 0, 0)) * clamp(distance(deltaReactPos, float3(0, 0, 0)), 0, uv.y * uv.y * 0.7f);
        // return deltaReactPos;
        // return half3(0,0,0);
    #else
        return half3(0, 0, 0);
    #endif
}

void GetTerrainColor(float3 worldPos, out half4 colorUp, out half4 colorMiddle, out half4 colorDown)
{
    #ifdef _USE_TERRAIN
        float3x3 matrixPosToUV = float3x3(
            1 / _WPosST.x, 0, _WPosST.z,
            0, 1 / _WPosST.y, _WPosST.w,
            0, 0, 1
        );
        float2 uv = mul(matrixPosToUV, float3(worldPos.xz, 1)).xy;
        colorUp = _ColorUp;
        colorMiddle = _ColorMiddle;
        // colorUp = tex2Dlod(_TerrainColor, float4(uv,0,0));
        colorDown = tex2Dlod(_TerrainColor, float4(uv, 0, 0));
        //     #ifdef _USE_FOUR
        //         half4 terrainSample1 = tex2Dlod(_TerrainMap1, float4(uv, 0, 0));
        //         half4 terrainSample2 = half4(0,0,0,0);
        //         half4 terrainSample3 = half4(0,0,0,0);
        //         half4 terrainSample4 = half4(0,0,0,0);
        //     #else
        //         half4 tempSample1 = tex2Dlod(_TerrainMap1, float4(uv, 0, 0));
        //         half4 tempSample2 = tex2Dlod(_TerrainMap2, float4(uv, 0, 0));
        //         half4 tempSample3 = tex2Dlod(_TerrainMap3, float4(uv, 0, 0));
        //         half4 tempSample4 = tex2Dlod(_TerrainMap4, float4(uv, 0, 0));
        //         half4 terrainSample1, terrainSample2, terrainSample3, terrainSample4;
        //         GetControlValue(
        //             _Weight,_Edge,
        //             tempSample1,tempSample2,tempSample3,tempSample4,
        //             terrainSample1,terrainSample2,terrainSample3,terrainSample4);
        //     #endif
        //     #ifdef _USE_SPLIT_COLOR
        //         half4 Color01Up = _ColorU01;
        //         half4 Color01Down = _ColorU01;
        //         half4 Color02Up = _ColorU02;
        //         half4 Color02Down = _ColorU02;
        //         half4 Color03Up = _ColorU03;
        //         half4 Color03Down = _ColorU03;
        //         half4 Color04Up = _ColorU04;
        //         half4 Color04Down = _ColorU04;
        //         half4 Color05Up = _ColorU05;
        //         half4 Color05Down = _ColorU05;
        //         half4 Color06Up = _ColorU06;
        //         half4 Color06Down = _ColorU06;
        //         half4 Color07Up = _ColorU07;
        //         half4 Color07Down = _ColorU07;
        //         half4 Color08Up = _ColorU08;
        //         half4 Color08Down = _ColorU08;
        //         half4 Color09Up = _ColorU09;
        //         half4 Color09Down = _ColorU09;
        //         half4 Color10Up = _ColorU10;
        //         half4 Color10Down = _ColorU10;
        //         half4 Color11Up = _ColorU11;
        //         half4 Color11Down = _ColorU11;
        //         half4 Color12Up = _ColorU12;
        //         half4 Color12Down = _ColorU12;
        //         half4 Color13Up = _ColorU13;
        //         half4 Color13Down = _ColorU13;
        //         half4 Color14Up = _ColorU14;
        //         half4 Color14Down = _ColorU14;
        //         half4 Color15Up = _ColorU15;
        //         half4 Color15Down = _ColorU15;
        //         half4 Color16Up = _ColorU16;
        //         half4 Color16Down = _ColorU16;
        //     #else
        //         half4 Color01Up = tex2Dlod(_ColorMapUp,     float4(0.125, 0.875, 0, 0));
        //         half4 Color01Down = tex2Dlod(_ColorMapDown, float4(0.125, 0.875, 0, 0));
        //         half4 Color02Up = tex2Dlod(_ColorMapUp,     float4(0.375, 0.875, 0, 0));
        //         half4 Color02Down = tex2Dlod(_ColorMapDown, float4(0.375, 0.875, 0, 0));
        //         half4 Color03Up = tex2Dlod(_ColorMapUp,     float4(0.625, 0.875, 0, 0));
        //         half4 Color03Down = tex2Dlod(_ColorMapDown, float4(0.625, 0.875, 0, 0));
        //         half4 Color04Up = tex2Dlod(_ColorMapUp,     float4(0.875, 0.875, 0, 0));
        //         half4 Color04Down = tex2Dlod(_ColorMapDown, float4(0.875, 0.875, 0, 0));
        //         half4 Color05Up = tex2Dlod(_ColorMapUp,     float4(0.125, 0.625, 0, 0));
        //         half4 Color05Down = tex2Dlod(_ColorMapDown, float4(0.125, 0.625, 0, 0));
        //         half4 Color06Up = tex2Dlod(_ColorMapUp,     float4(0.375, 0.625, 0, 0));
        //         half4 Color06Down = tex2Dlod(_ColorMapDown, float4(0.375, 0.625, 0, 0));
        //         half4 Color07Up = tex2Dlod(_ColorMapUp,     float4(0.625, 0.625, 0, 0));
        //         half4 Color07Down = tex2Dlod(_ColorMapDown, float4(0.625, 0.625, 0, 0));
        //         half4 Color08Up = tex2Dlod(_ColorMapUp,     float4(0.875, 0.625, 0, 0));
        //         half4 Color08Down = tex2Dlod(_ColorMapDown, float4(0.875, 0.625, 0, 0));
        //         half4 Color09Up = tex2Dlod(_ColorMapUp,     float4(0.125, 0.375, 0, 0));
        //         half4 Color09Down = tex2Dlod(_ColorMapDown, float4(0.125, 0.375, 0, 0));
        //         half4 Color10Up = tex2Dlod(_ColorMapUp,     float4(0.375, 0.375, 0, 0));
        //         half4 Color10Down = tex2Dlod(_ColorMapDown, float4(0.375, 0.375, 0, 0));
        //         half4 Color11Up = tex2Dlod(_ColorMapUp,     float4(0.625, 0.375, 0, 0));
        //         half4 Color11Down = tex2Dlod(_ColorMapDown, float4(0.625, 0.375, 0, 0));
        //         half4 Color12Up = tex2Dlod(_ColorMapUp,     float4(0.875, 0.375, 0, 0));
        //         half4 Color12Down = tex2Dlod(_ColorMapDown, float4(0.875, 0.375, 0, 0));
        //         half4 Color13Up = tex2Dlod(_ColorMapUp,     float4(0.125, 0.125, 0, 0));
        //         half4 Color13Down = tex2Dlod(_ColorMapDown, float4(0.125, 0.125, 0, 0));
        //         half4 Color14Up = tex2Dlod(_ColorMapUp,     float4(0.375, 0.125, 0, 0));
        //         half4 Color14Down = tex2Dlod(_ColorMapDown, float4(0.375, 0.125, 0, 0));
        //         half4 Color15Up = tex2Dlod(_ColorMapUp,     float4(0.625, 0.125, 0, 0));
        //         half4 Color15Down = tex2Dlod(_ColorMapDown, float4(0.625, 0.125, 0, 0));
        //         half4 Color16Up = tex2Dlod(_ColorMapUp,     float4(0.875, 0.125, 0, 0));
        //         half4 Color16Down = tex2Dlod(_ColorMapDown, float4(0.875, 0.125, 0, 0));
        //     #endif
        //     #ifdef _DEBUG_TERRAIN
        //     colorUp = colorDown =
        //         + terrainSample1.r * half4(1,0,0,1) + terrainSample1.g * half4(0,1,0,1) + terrainSample1.b * half4(0,0,1,1) + terrainSample1.a * half4(0.5,0.5,0.5,0.5)
        //         + terrainSample2.r * half4(1,0,0,1) + terrainSample2.g * half4(0,1,0,1) + terrainSample2.b * half4(0,0,1,1) + terrainSample2.a * half4(0.5,0.5,0.5,0.5)
        //         + terrainSample3.r * half4(1,0,0,1) + terrainSample3.g * half4(0,1,0,1) + terrainSample3.b * half4(0,0,1,1) + terrainSample3.a * half4(0.5,0.5,0.5,0.5)
        //         + terrainSample4.r * half4(1,0,0,1) + terrainSample4.g * half4(0,1,0,1) + terrainSample4.b * half4(0,0,1,1) + terrainSample4.a * half4(0.5,0.5,0.5,0.5);
        //     #else
        //     colorUp =
        //         #ifdef _USE_FOUR
        //         + (1 - terrainSample1.g - terrainSample1.b - terrainSample1.a) * Color01Up
        //         #else
        //         + terrainSample1.r * Color01Up
        //         #endif
        //         + terrainSample1.g * Color02Up + terrainSample1.b * Color03Up + terrainSample1.a * Color04Up
        //         + terrainSample2.r * Color05Up + terrainSample2.g * Color06Up + terrainSample2.b * Color07Up + terrainSample2.a * Color08Up
        //         + terrainSample3.r * Color09Up + terrainSample3.g * Color10Up + terrainSample3.b * Color11Up + terrainSample3.a * Color12Up
        //         + terrainSample4.r * Color13Up + terrainSample4.g * Color14Up + terrainSample4.b * Color15Up + terrainSample4.a * Color16Up;
        //     colorDown =
        //         #ifdef _USE_FOUR
        //         + (1 - terrainSample1.g - terrainSample1.b - terrainSample1.a) * Color01Down
        //         #else
        //         + terrainSample1.r * Color01Down
        //         #endif
        //         + terrainSample1.g * Color02Down + terrainSample1.b * Color03Down + terrainSample1.a * Color04Down
        //         + terrainSample2.r * Color05Down + terrainSample2.g * Color06Down + terrainSample2.b * Color07Down + terrainSample2.a * Color08Down
        //         + terrainSample3.r * Color09Down + terrainSample3.g * Color10Down + terrainSample3.b * Color11Down + terrainSample3.a * Color12Down
        //         + terrainSample4.r * Color13Down + terrainSample4.g * Color14Down + terrainSample4.b * Color15Down + terrainSample4.a * Color16Down;
        //     #endif
        // #else
        //     colorUp = colorDown = half4(0,0,0,0);
    #endif
}

Varyings SimpleLitVertex(Attributes v, uint instanceID : SV_InstanceID)
{
    Varyings o = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(v);
    #ifdef _USE_BILLBOARD
        float3 center = float3(0, 0, 0);
        float3 viewer = TransformWorldToObject(_WorldSpaceCameraPos);//mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1));
        float3 normalDir = viewer - center;
        normalDir.y *= _VerticalBillboarding;
        normalDir = normalize(normalDir);
        float3 upDir = float3(0, 1, 0);
        float3 rightDir = normalize(cross(upDir, normalDir));
        upDir = normalize(cross(normalDir, rightDir));
        float3 centerOffs = v.vertex.xyz - center;
        float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
        v.vertex = float4(localPos, 1);
    #endif
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
    #ifdef _USE_NORMAL
        VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal);
        o.normal = normalInput.normalWS;
        OUTPUT_SH(o.normal.xyz, o.vertexSH);
    #endif

    #if defined(_USE_WIND) || defined(_USE_WAVE) || defined(_USE_REACT) || defined(_USE_TERRAIN)
        // float3 worldPos = TransformObjectToWorld(v.vertex.xyz);

        float3 worldPos = mul(_Properties[instanceID].mat, v.vertex).xyz;
        #ifdef _USE_TERRAIN
            GetTerrainColor(worldPos, o.colorUp, o.colorMiddle, o.colorDown);
        #endif
        half3 totalDeltaPos = GetDeltaWindPos(worldPos, v.uv)
        + GetDeltaWavePos(worldPos, v.uv)
        + GetDeltaReactPos(worldPos, v.uv);
        worldPos.xyz += totalDeltaPos;
        o.posCS = TransformWorldToHClip(worldPos);
        vertexInput.positionCS = o.posCS;
        vertexInput.positionWS = worldPos;
    #else
        o.posCS = TransformWorldToHClip(mul(_Properties[instanceID].mat, v.vertex).xyz);
        vertexInput.positionCS = o.posCS;
        vertexInput.positionWS = _Properties[instanceID].mat, v.vertex).xyz;
    #endif

    o.uv = v.uv;
    o.posWSAndFogFactor.xyz = vertexInput.positionWS;
    o.posWSAndFogFactor.w = ComputeFogFactor(vertexInput.positionCS.z);

    #ifdef _USE_VIEW_DIR
        half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
        o.viewDir = viewDirWS;
    #endif

    #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
        // o.shadowCoord = GetShadowCoord(vertexInput);
        o.shadowCoord = float4(0, 0, 0, 0);
    #endif

    #ifdef _USE_VERTEX_LIGHT
        o.vertexLight = half4(VertexLighting(vertexInput.positionWS, normalInput.normalWS), 0.0h);
    #endif

    // if enable receive shadow , shadow attenuation will calc in frag
    #ifdef _USE_VERTEX_DIFFUSE_MAINLIGHT
        Light mainLight = GetMainLight();
        #ifdef _USE_ATTENBIAS
            half3 mainColor = mainLight.color * saturate(mainLight.distanceAttenuation + _AttenBias);
        #else
            half3 mainColor = mainLight.color * mainLight.distanceAttenuation;
        #endif
        o.vertexDiffuseMainLight = LightingLambert(mainColor, mainLight.direction, normalInput.normalWS) ;
    #endif

    #ifdef _USE_STATIC_GI
        o.staticNormal = TransformObjectToWorldNormal(half3(0, 1, 0));
    #endif

    return o;
}

void InitializeInputData(Varyings i, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = i.posWSAndFogFactor.xyz;
    inputData.fogCoord = i.posWSAndFogFactor.w;
    //inputData.shadowMask = half4(1,1,1,1);
    #ifdef _USE_VIEW_DIR
        inputData.viewDirectionWS = normalize(i.viewDir);
    #endif
    #ifdef _USE_NORMAL
        inputData.normalWS = normalize(i.normal);
        inputData.bakedGI = i.vertexSH;
    #endif
    #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
        // inputData.shadowCoord = i.shadowCoord;
        inputData.shadowCoord = TransformWorldToShadowCoord(i.posWSAndFogFactor.xyz);
    #endif
    #ifdef _USE_VERTEX_LIGHT
        inputData.vertexLighting = i.vertexLight.xyz;
    #endif
}

#ifdef _USE_FACE_DIFF
    half4 SimpleLitFragment(Varyings i, float facing : VFACE) : SV_Target
    {
        #ifdef _USE_NORMAL
            i.normal = facing > 0 ? i.normal : - i.normal;
        #endif
#else
    half4 SimpleLitFragment(Varyings i) : SV_TARGET
    {
#endif

//--------------------------------------
// apply main texture
// #ifdef _USE_MAINTEX
//     half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
// #else
    half4 albedo = half4(1.0h, 1.0h, 1.0h, 1.0h);
// #endif

//--------------------------------------
// apply alpha test
#ifdef _USE_ALPHA_TEST
    clip(albedo.a - _Cutoff);
#endif

//--------------------------------------
// initialize input data
InputData inputData = (InputData)0;
InitializeInputData(i, inputData);

//--------------------------------------
// apply color to texture
#ifdef _USE_COLOR
    albedo.rgb *= _Color.rgb;
#endif
#ifdef _DEBUG_TERRAIN
    return i.colorMiddle;
#endif

//--------------------------------------
// Light
//Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
Light mainLight = GetMainLight(inputData.shadowCoord);
#ifdef _USE_NoLight
    mainLight.distanceAttenuation = 0;
#endif
#ifdef _USE_NORMAL
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));
#endif

//--------------------------------------
// Shadow
#ifdef _USE_NOT_RECEIVE_SHADOW
    half3 attenuatedLightColor = mainLight.color * saturate(mainLight.distanceAttenuation);
#else
    #ifdef _USE_ATTENBIAS
        half3 attenuatedLightColor = mainLight.color *
        saturate(mainLight.distanceAttenuation * mainLight.shadowAttenuation + _AttenBias);
    #else
        half3 attenuatedLightColor = mainLight.color *
        saturate(mainLight.distanceAttenuation * mainLight.shadowAttenuation);
    #endif

    #ifdef _USE_SHADOW_COLOR
        attenuatedLightColor += _ShadowColor * (1 - mainLight.shadowAttenuation);
    #endif
#endif

half4 FinalColor = half4(1, 1, 1, 1);
#ifdef _USE_NORMAL
    half NdotL = dot(inputData.normalWS, mainLight.direction);
    half NdotLHalf = NdotL * 0.5 + 0.5;
#else
    half NdotL = 0;
    half NdotLHalf = 0.5;
#endif
//--------------------------------------
// Diffuse
#ifdef _USE_VERTEX_DIFFUSE_MAINLIGHT
    half3 diffuseColor = inputData.bakedGI + i.vertexDiffuseMainLight * mainLight.shadowAttenuation;
#else
    #ifdef _USE_NORMAL
        #ifdef _USE_CUSTOMCOLOR
            half3 diffuseColor = attenuatedLightColor
            * (inputData.bakedGI
            + _PlantPairOneColor.rgb * saturate(NdotL)
            + _PlantPairTwoColor.rgb * (1.0 - step(1.0, 1.0 + NdotL)) * (1.0 + NdotL));
        #else
            half3 diffuseColor = attenuatedLightColor
            * (inputData.bakedGI + attenuatedLightColor * saturate(NdotL));
        #endif
    #else
        #ifdef _USE_CUSTOMCOLOR
            half3 diffuseColor = attenuatedLightColor
            * lerp(mainLight.color, _PlantSingleColor.rgb, _PlantSingleColor.a);
        #else
            half3 diffuseColor = attenuatedLightColor;
        #endif
    #endif
#endif

#ifdef _USE_LIGHT_STRENGTH
    diffuseColor = lerp(attenuatedLightColor, diffuseColor, _LightStrength);
#endif

#ifdef _USE_RAMPTEX
    half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, half2(NdotLHalf, 0.5)).rgb;
    #ifdef _USE_CUSTOMCOLOR
        diffuseColor = diffuseColor
        + lerp(rampColor
        , lerp(_PlantPairTwoColor.rgb, _PlantPairOneColor.rgb, NdotLHalf)
        , _PlantPairTwoColor.a * _PlantPairOneColor.a);
    #else
        diffuseColor += rampColor * mainLight.color;
    #endif
#endif

#ifdef _USE_CUSTOMCOLOR
    diffuseColor *= (1 + _PlantLightness);
#endif

FinalColor.rgb = diffuseColor * albedo.rgb;

#ifdef _USE_TERRAIN
    half3 color = lerp(i.colorMiddle.rgb, i.colorUp.rgb, smoothstep(_BlendRatio.y, _BlendRatio.z, i.uv.y));
    #ifdef _USE_STATIC_GI
        half NdotLStatic = dot(i.staticNormal, mainLight.direction);
        half3 GIStatic = SampleSHVertex(i.staticNormal);
        FinalColor.rgb = lerp(
            i.colorDown.rgb * saturate(mainLight.distanceAttenuation * mainLight.shadowAttenuation + 0.436),
            // * (GIStatic + attenuatedLightColor * saturate(NdotLStatic))
            // * saturate(mainLight.distanceAttenuation * mainLight.shadowAttenuation + _AttenBias),
            color * FinalColor.rgb,
            smoothstep(_BlendRatio.x, _BlendRatio.y, i.uv.y));

    #else
        FinalColor.rgb *= lerp(i.colorDown.rgb, i.colorMiddle.rgb, smoothstep(_BlendRatio.x, _BlendRatio.y, i.uv.y));
    #endif
#endif

//--------------------------------------
// apply fog
FinalColor.rgb = MixFog(FinalColor.rgb, inputData.fogCoord);

//--------------------------------------
// Alpha
#ifdef _USE_ALPHA
    return half4(FinalColor.rgb, _Alpha * FinalColor.a);
#else
    return FinalColor;
#endif
}
#endif
