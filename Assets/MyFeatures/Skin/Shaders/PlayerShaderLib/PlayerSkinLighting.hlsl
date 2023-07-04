#ifndef PLAYERSKINLIGHTING_HLSL_INCLUDED
#define PLAYERSKINLIGHTING_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct AmbientOcclusionFactor
{
    half indirectAmbientOcclusion;
    half directAmbientOcclusion;
};

struct LightingData
{
    half3 giColor;
    half3 mainLightColor;
    half3 additionalLightsColor;
    half3 vertexLightingColor;
    half3 emissionColor;
};

half DirectBRDFSpecular(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
    float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
    float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

    float NoH = saturate(dot(float3(normalWS), halfDir));
    half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

    // On platforms where half actually means something, the denominator has a risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
    #if REAL_IS_HALF
        specularTerm = specularTerm - HALF_MIN;
        // Update: Conservative bump from 100.0 to 1000.0 to better match the full float specular look.
        // Roughly 65504.0 / 32*2 == 1023.5,
        // or HALF_MAX / ((mobile) MAX_VISIBLE_LIGHTS * 2),
        // to reserve half of the per light range for specular and half for diffuse + indirect + emissive.
        specularTerm = clamp(specularTerm, 0.0, 1000.0); // Prevent FP16 overflow on mobiles
    #endif

    return specularTerm;
}


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

half4 CalculateShadowMask(InputData inputData)
{
    // To ensure backward compatibility we have to avoid using shadowMask input, as it is not present in older shaders
    #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
        half4 shadowMask = inputData.shadowMask;
    #elif !defined(LIGHTMAP_ON)
        half4 shadowMask = unity_ProbesOcclusion;
    #else
        half4 shadowMask = half4(1, 1, 1, 1);
    #endif

    return shadowMask;
}

LightingData CreateLightingData(InputData inputData, SurfaceData surfaceData)
{
    LightingData lightingData;

    lightingData.giColor = inputData.bakedGI;
    lightingData.emissionColor = surfaceData.emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}

half3 CalculateLightingColor(LightingData lightingData, half3 albedo)
{
    half3 lightingColor = 0;
    lightingColor *= albedo;
    return lightingColor;
}


half4 CalculateFinalColor(LightingData lightingData, half3 albedo, half alpha, float fogCoord)
{
    #if defined(_FOG_FRAGMENT)
        #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
            float viewZ = -fogCoord;
            float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
            half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
        #else
            half fogFactor = 0;
        #endif
    #else
        half fogFactor = fogCoord;
    #endif
    half3 lightingColor = CalculateLightingColor(lightingData, albedo);
    half3 finalColor = MixFog(lightingColor, fogFactor);

    return half4(finalColor, alpha);
}

inline half3 LinearToGammaSpace(half3 linRGB)
{
    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
}

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


half4 SkinPBR(InputData inputData, SurfaceData surfaceData, SkinSurfaceData skinSurfaceData, half4 subSurfaceColor, half3 diffuseNormalWS, half specularAO, half backScattering)
{
    BRDFData brdfData;
    //InitializeBRDFData(surfaceData, brdfData);
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    half4 shadowMask = CalculateShadowMask(inputData);
    //AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, surfaceData.occlusion);
    AmbientOcclusionFactor aoFactor;
    aoFactor.directAmbientOcclusion = 1;
    aoFactor.indirectAmbientOcclusion = 1;
    //uint meshRenderingLayers = GetMeshRenderingLightLayer();
    //Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    Light mainLight = GetMainLight(inputData.shadowCoord);
    //Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);

    //return half4(aoFactor.directAmbientOcclusion, aoFactor.indirectAmbientOcclusion, 1, 1);
    inputData.bakedGI = LinearToGammaSpace(inputData.bakedGI);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, shadowMask);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    //return half4(LinearToGammaSpace(lightingData.giColor), 1);

    lightingData.giColor = GlobalIllumination_Skin(brdfData, inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS, specularAO);

    //return half4(lightingData.giColor, 1);

    // add back scatterring
    half3 backColor = backScattering * SampleSH(-diffuseNormalWS) * surfaceData.albedo * aoFactor.indirectAmbientOcclusion * skinSurfaceData.thickness * subSurfaceColor.rgb;
    lightingData.giColor += backColor;

    //return half4(lightingData.giColor, 1);

    // main light
    half ndotLUnclamped = dot(diffuseNormalWS, mainLight.direction);
    half ndotL = saturate(dot(inputData.normalWS, mainLight.direction));
    lightingData.mainLightColor = LightingSkin(brdfData, inputData, mainLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);

    return half4(ndotLUnclamped, ndotLUnclamped, 1, 1);
    return half4(lightingData.mainLightColor, 1);

    half transPower = _TranslucencyPower;
    half3 transLightDir = mainLight.direction + inputData.normalWS * 0.02;
    half transDot = dot(transLightDir, -inputData.viewDirectionWS);
    transDot = exp2(saturate(transDot) * transPower - transPower);
    half3 scatteringColor = subSurfaceColor.rgb * transDot * (1.0h - saturate(ndotLUnclamped)) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * skinSurfaceData.thickness;
    lightingData.mainLightColor += scatteringColor;
    //return half4(scatteringColor, 1);
    //return half4(lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * ndotL, 1.0);

    // additional Light
    /*
    uint lightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightCount)
    Light additionalLight = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    half ndotLUnclamped = dot(diffuseNormalWS, additionalLight.direction);
    half ndotL = saturate(dot(inputData.normalWS, additionalLight.direction));
    lightingData.additionalLightsColor += LightingSkin(brdfData, inputData, additionalLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);
    */
    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            //Light additionalLight = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            Light additionalLight = GetAdditionalLight(lightIndex, inputData.positionWS);
            half ndotLUnclamped = dot(diffuseNormalWS, additionalLight.direction);
            half ndotL = saturate(dot(inputData.normalWS, additionalLight.direction));
            lightingData.additionalLightsColor += LightingSkin(brdfData, inputData, additionalLight, ndotL, ndotLUnclamped, skinSurfaceData.curvature);

            half transPower = _TranslucencyPower;
            half3 transLightDir = mainLight.direction + inputData.normalWS * 0.02;
            half transDot = dot(transLightDir, -inputData.viewDirectionWS);
            transDot = exp2(saturate(transDot) * transPower - transPower);
            half3 scatteringColor = subSurfaceColor.rgb * transDot * (1.0h - saturate(ndotLUnclamped)) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, _ShadowStrength) * skinSurfaceData.thickness;
            lightingData.additionalLightsColor += scatteringColor;
        }
    #endif

    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;

    //return CalculateFinalColor(lightingData, surfaceData.alpha);
    return CalculateFinalColor(lightingData, surfaceData.albedo, surfaceData.alpha, inputData.fogCoord);
}

#endif