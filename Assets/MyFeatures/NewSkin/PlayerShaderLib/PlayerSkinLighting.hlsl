#ifndef PLAYERSKINLIGHTING_HLSL_INCLUDED
#define PLAYERSKINLIGHTING_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


half3 GlobalIllumination_Skin(BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, half specularAO)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    //half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, occlusion) * specularAO;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion) * specularAO;
    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
    return color;
}

half3 LightingSkin(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half ndotL, half ndotLUnclamped, half curvature)
{
    half3 diffuseLighting = brdfData.diffuse * SAMPLE_TEXTURE2D_LOD(_SkinRampMap, sampler_SkinRampMap, float2((ndotLUnclamped * 0.5 + 0.5), curvature), 0).rgb;
    half specularTerm = DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
    return (specularTerm * brdfData.specular * ndotL + diffuseLighting) * lightColor * lightAttenuation;
}

half3 LightingSkin(BRDFData brdfData, InputData inputData, Light light, half ndotL, half ndotLUnclamped, half curvature)
{
    return LightingSkin(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, inputData.normalWS, inputData.viewDirectionWS, ndotL, ndotLUnclamped, curvature);
}

half4 SkinPBR(InputData inputData, SurfaceData surfaceData, SkinSurfaceData skinSurfaceData, half4 subSurfaceColor, half3 diffuseNormalWS, half specularAO, half backScattering)
{
    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfaceData.occlusion);
    //uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    //Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination_Skin(brdfData, inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS, specularAO);
    // add back scatterring
    half3 backColor = backScattering * SampleSH(-diffuseNormalWS) * surfaceData.albedo * aoFactor.indirectAmbientOcclusion * skinSurfaceData.thickness * subSurfaceColor;
    lightingData.giColor += backColor;

    // main light
    half ndotLUnclamped = dot(diffuseNormalWS, mainLight.direction);
    half ndotL = saturate(dot(inputData.normalWS, mainLight.direction));
    lightingData.mainLightColor = LightingSkin(brdfData, inputData, mainLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);

    half transPower = _TranslucencyPower;
    half3 transLightDir = mainLight.direction + inputData.normalWS * 0.02;
    half transDot = dot(transLightDir, -inputData.viewDirectionWS);
    transDot = exp2(saturate(transDot) * transPower - transPower);
    half3 scatteringColor = subSurfaceColor.rgb * transDot * (1.0h - saturate(ndotLUnclamped)) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * skinSurfaceData.thickness;
    lightingData.mainLightColor += scatteringColor;
    //return half4(scatteringColor, 1);
    //return half4(lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, 1.0);

    // additional Light
    uint lightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightCount)
    Light additionalLight = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    half ndotLUnclamped = dot(diffuseNormalWS, additionalLight.direction);
    half ndotL = saturate(dot(inputData.normalWS, additionalLight.direction));
    lightingData.additionalLightsColor += LightingSkin(brdfData, inputData, additionalLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);


    half transPower = _TranslucencyPower;
    half3 transLightDir = mainLight.direction + inputData.normalWS * 0.02;
    half transDot = dot(transLightDir, -inputData.viewDirectionWS);
    transDot = exp2(saturate(transDot) * transPower - transPower);
    half3 scatteringColor = subSurfaceColor.rgb * transDot * (1.0h - saturate(ndotLUnclamped)) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * skinSurfaceData.thickness;
    lightingData.additionalLightsColor += scatteringColor;

    LIGHT_LOOP_END

    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

half4 SkinPBRWithMask(InputData inputData, SurfaceData surfaceData, SkinSurfaceData skinSurfaceData, half4 subSurfaceColor, half3 diffuseNormalWS, half specularAO, half backScattering)
{
    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfaceData.occlusion);
    //uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    //Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination_Skin(brdfData, inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS, specularAO);
    // add back scatterring
    half3 backColor = backScattering * SampleSH(-diffuseNormalWS) * surfaceData.albedo * aoFactor.indirectAmbientOcclusion * skinSurfaceData.SSSMaskAndThickness * subSurfaceColor;
    lightingData.giColor += backColor;

    // main light
    half ndotLUnclamped = dot(diffuseNormalWS, mainLight.direction);
    half ndotL = saturate(dot(inputData.normalWS, mainLight.direction));
    lightingData.mainLightColor = LightingSkin(brdfData, inputData, mainLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);

    half transPower = _TranslucencyPower;
    half3 transLightDir = mainLight.direction + inputData.normalWS * 0.02;
    half transDot = dot(transLightDir, -inputData.viewDirectionWS);
    transDot = exp2(saturate(transDot) * transPower - transPower);
    half3 scatteringColor = subSurfaceColor.rgb * transDot * (1.0h - saturate(ndotLUnclamped)) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * skinSurfaceData.SSSMaskAndThickness;
    lightingData.mainLightColor += scatteringColor;
    //return half4(scatteringColor, 1);
    //return half4(lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, 1.0);

    // additional Light
    uint lightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightCount)
    Light additionalLight = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    half ndotLUnclamped = dot(diffuseNormalWS, additionalLight.direction);
    half ndotL = saturate(dot(inputData.normalWS, additionalLight.direction));
    lightingData.additionalLightsColor += LightingSkin(brdfData, inputData, additionalLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);

    lightingData.additionalLightsColor += scatteringColor;

    LIGHT_LOOP_END

    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

#endif