#ifndef INPUT_SKIN_V2019_LIGHTING_INCLUDED
#define INPUT_SKIN_V2019_LIGHTING_INCLUDED

TEXTURE2D(_SkinRamp); SAMPLER(sampler_SkinRamp); float4 _SkinRamp_TexelSize;

half3 DirectBDRF_Skin(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
    float3 halfDir = SafeNormalize(lightDirectionWS + viewDirectionWS);

    float NoH = saturate(dot(normalWS, halfDir));
    half LoH = saturate(dot(lightDirectionWS, halfDir));
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);
    /*
    #if defined(SHADER_API_MOBILE) || defined(SHADER_API_SWITCH)
        specularTerm = specularTerm - HALF_MIN;
        specularTerm = clamp(specularTerm, 0.0, 100.0);
    #endif
    */

    half3 color = specularTerm * brdfData.specular;
    return color;
}


half3 GlobalIllumination_Skin(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS, half specOccluison)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));
    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion) * specOccluison;
    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}


half3 LightingSkin(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL, half NdotLUnclamped, half curvature, half skinMask)
{
    //half3 radiance = lightColor * NdotL;
    half3 diffuseLighting = brdfData.diffuse * SAMPLE_TEXTURE2D_LOD(_SkinRamp, sampler_SkinRamp, float2((NdotLUnclamped * 0.5 + 0.5), curvature), 0).rgb;
    diffuseLighting = lerp(brdfData.diffuse * NdotL, diffuseLighting, skinMask);
    return (DirectBDRF_Skin(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * NdotL + diffuseLighting) * lightColor * lightAttenuation;
}

half3 LightingSkin(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL, half NdotLUnclamped, half curvature, half skinMask)
{
    return LightingSkin(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);
}


half4 CalculateSkinColor(InputData inputData, half3 albedo, half metallic, half3 specular, half smoothness, half occlusion, half3 emission, half alpha, half4 translucency, half AmbientReflection, half3 diffuseNormalWS, half3 subsurfaceColor, half curvature, half skinMask)
{
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIllumination_Skin(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS, AmbientReflection);

    half NdotLUnclamped = dot(diffuseNormalWS, mainLight.direction);
    half NdotL = saturate(dot(inputData.normalWS, mainLight.direction));
    color += LightingSkin(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);

    half transPower = translucency.y;
    half3 transLightDir = mainLight.direction + inputData.normalWS * translucency.w;
    half transDot = dot(transLightDir, -inputData.viewDirectionWS);
    transDot = exp2(saturate(transDot) * transPower - transPower);
    color += skinMask * subsurfaceColor * transDot * (1.0 - saturate(NdotLUnclamped)) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, translucency.z) * translucency.x;


    #ifdef _ADDITIONAL_LIGHTS
        int pixelLightCount = GetAdditionalLightsCount();
        for (int i = 0; i < pixelLightCount; ++i)
        {
            Light light = GetAdditionalLight(i, inputData.positionWS);

            half NdotLUnclamped = dot(diffuseNormalWS, light.direction);
            NdotL = saturate(dot(inputData.normalWS, light.direction));
            color += LightingSkin(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);

            transLightDir = light.direction + inputData.normalWS * translucency.w;
            transDot = dot(transLightDir, -inputData.viewDirectionWS);
            transDot = exp2(saturate(transDot) * transPower - transPower);
            color += skinMask * subsurfaceColor * transDot * (1.0 - NdotL) * light.color * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x;
        }
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        color += inputData.vertexLighting * brdfData.diffuse;
    #endif
    color += emission;
    return half4(color, alpha);
}

#endif