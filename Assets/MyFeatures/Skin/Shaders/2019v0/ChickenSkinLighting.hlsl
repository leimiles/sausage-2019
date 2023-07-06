#ifndef CHICKEN_SKIN_LIGHTING_HLSL_INCLUDED
#define CHICKEN_SKIN_LIGHTING_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

half3 GlobalIllumination_Skin(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS, half specularAO)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion) * specularAO;
    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
    return color;
}

half3 LightingSkin(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half ndotL, half ndotLUnclamped, half curvature)
{
    half3 diffuseLighting = brdfData.diffuse * SAMPLE_TEXTURE2D_LOD(_SkinRampMap, sampler_SkinRampMap, float2((ndotLUnclamped * 0.5 + 0.5), curvature), 0).rgb;
    //half specularTerm = DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
    float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
    float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

    float NoH = saturate(dot(normalWS, halfDir));
    half LoH = half(saturate(dot(lightDirectionWS, halfDir)));

    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;
    half d2 = half(d * d);

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / (d2 * max(half(0.1), LoH2) * brdfData.normalizationTerm);

    return (specularTerm * brdfData.specular + diffuseLighting) * lightColor * lightAttenuation * ndotL;
}

half3 LightingSkin(BRDFData brdfData, InputData inputData, Light light, half ndotL, half ndotLUnclamped, half curvature)
{
    return LightingSkin(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, inputData.normalWS, inputData.viewDirectionWS, ndotL, ndotLUnclamped, curvature);
}

half4 SkinPBR(InputData inputData, SurfaceData surfaceData, SkinSurfaceData skinSurfaceData, half4 subSurfaceColor, half3 diffuseNormalWS, half specularAO, half backScattering)
{
    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);
    //return half4(surfaceData.albedo, 1);
    //return half4(brdfData.roughness, brdfData.roughness2, brdfData.perceptualRoughness, 1);

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half ndotv = pow(1 - saturate(dot(inputData.normalWS, inputData.viewDirectionWS)), _ScatteringEdge);

    half3 giColor = GlobalIllumination_Skin(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.normalWS, inputData.viewDirectionWS, specularAO);

    // add back scatterring
    half3 backColor = backScattering * SampleSH(-diffuseNormalWS) * surfaceData.albedo * surfaceData.occlusion * skinSurfaceData.sssStrength * skinSurfaceData.thickness * subSurfaceColor * ndotv;
    giColor += backColor;

    // main light
    half ndotLUnclamped = saturate(dot(diffuseNormalWS, mainLight.direction));
    half ndotL = saturate(dot(inputData.normalWS, mainLight.direction));
    half3 mainLightColor = LightingSkin(brdfData, inputData, mainLight, ndotL, ndotLUnclamped, 1.0);

    half transPower = _TranslucencyPower;
    half3 transLightDir = mainLight.direction + inputData.normalWS * 0.02;
    half transDot = dot(transLightDir, -inputData.viewDirectionWS);
    transDot = exp2(saturate(transDot) * transPower - transPower);


    //return transDot;
    half3 scatteringColor = subSurfaceColor.rgb * transDot * max(0, (1.0h - saturate(ndotLUnclamped))) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * skinSurfaceData.sssStrength * skinSurfaceData.thickness * ndotv;
    mainLightColor += scatteringColor;
    //return half4(lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, 1.0);

    // additional Light
    #ifdef _ADDITIONAL_LIGHTS
        uint lightCount = GetAdditionalLightsCount();
        half3 additionalLightsColor = 0;
        for (uint lightIndex = 0u; lightIndex < lightCount; ++lightIndex)
        {
            Light additionalLight = GetAdditionalLight(lightIndex, inputData.positionWS);
            half ndotLUnclamped = dot(diffuseNormalWS, additionalLight.direction);
            half ndotL = saturate(dot(inputData.normalWS, additionalLight.direction));
            additionalLightsColor += LightingSkin(brdfData, inputData, additionalLight, ndotL, ndotLUnclamped, 1.0);
        }

        additionalLightsColor += scatteringColor;
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLightingColor = inputData.vertexLighting * brdfData.diffuse;
    #endif

    half3 color = giColor + mainLightColor;

    #ifdef _ADDITIONAL_LIGHTS
        color += additionalLightsColor;
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        color += vertexLightingColor;
    #endif

    return half4(color, surfaceData.alpha);
}

#endif