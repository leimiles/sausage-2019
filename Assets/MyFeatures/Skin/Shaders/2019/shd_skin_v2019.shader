Shader "SoFunny/SausageMan/PC/Skin"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1.0, 0.68, 0.68, 1.0)
        _BaseMap ("Base Map", 2D) = "white" { }
        [NoScaleOffset] MTAMap ("Mask (R) Thickness (G) Occlusion (B)", 2D) = "white" { }
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.5
        _OcclusionStrength ("Occlusion Strength", Range(0.0, 1.0)) = 1.0
        _SpecularColor ("Specular Color", Color) = (0.0, 0.0, 0.0, 0)
        _Curvature ("Curvature", Range(0.0, 1.0)) = 0.5
        _SubsurfaceColor ("Subsurface Color", Color) = (1.0, 0.18, 0.18, 1.0)
        _TranslucencyPower ("Transmission Power", Range(0.0, 10.0)) = 8.0
        _TranslucencyStrength ("Transmission Strength", Range(0.0, 1.0)) = 0.55
        _ShadowStrength ("Shadow Strength", Range(0.0, 1.0)) = 0.7
        _Distortion ("Transmission Distortion", Range(0.0, 0.1)) = 0.01
        [NoScaleOffset] _SkinRamp ("Skin Ramp", 2D) = "white" { }
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "ShaderModel" = "4.5" }
        Pass
        {
            Name "SausageSkin"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            //#define _SPECULAR_SETUP 1
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _NORMALMAP
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            #pragma multi_compile_instancing
            #include "./skin_v2019_input.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            VertexOutput vert(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                output.uv.xy = input.texcoord;
                #ifdef _NORMALMAP
                    output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
                    output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
                    output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
                #else
                    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
                    output.viewDirWS = viewDirWS;
                #endif
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                #ifdef _ADDITIONAL_LIGHTS
                    output.positionWS = vertexInput.positionWS;
                #endif
                #if defined(_MAIN_LIGHT_SHADOWS)
                    output.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                output.positionCS = vertexInput.positionCS;
                return output;
            }

            inline void InitializeSkinSurfaceData(float2 uv, out SkinSurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = 1;
                outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
                outSurfaceData.metallic = 0;
                outSurfaceData.specular = _SpecularColor;
                outSurfaceData.normalTS = half3(0, 0, 1);
                outSurfaceData.diffuseNormalTS = half3(0, 0, 1);
                half4 mask_thickness_ao = SAMPLE_TEXTURE2D(MTAMap, sampler_MTAMap, uv);
                outSurfaceData.translucency = mask_thickness_ao.g;
                outSurfaceData.skinMask = mask_thickness_ao.r;
                outSurfaceData.occlusion = lerp(1.0h, mask_thickness_ao.a, _OcclusionStrength);
                outSurfaceData.smoothness = albedoAlpha.a * _Smoothness;
                outSurfaceData.emission = 0;
            }

            void InitializeInputData(VertexOutput input, half3 normalTS, out InputData inputData)
            {
                inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                #ifdef _NORMALMAP
                    half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
                    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
                #else
                    half3 viewDirWS = input.viewDirWS;
                    inputData.normalWS = input.normalWS;
                #endif
                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                viewDirWS = SafeNormalize(viewDirWS);
                inputData.viewDirectionWS = viewDirWS;
                #if defined(_MAIN_LIGHT_SHADOWS)
                    inputData.shadowCoord = input.shadowCoord;
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif
                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                //return _BaseColor;

                SkinSurfaceData skinSurfaceData;
                InitializeSkinSurfaceData(input.uv.xy, skinSurfaceData);
                InputData inputData;
                InitializeInputData(input, skinSurfaceData.normalTS, inputData);

                //return half4(skinSurfaceData.albedo, 1);

                half3 normalWS;
                normalWS = input.normalWS;
                
                //return half4(skinSurfaceData.albedo, 1);

                half4 color = CalculateSkinColor(inputData, skinSurfaceData.albedo, skinSurfaceData.metallic, skinSurfaceData.specular, skinSurfaceData.smoothness, skinSurfaceData.occlusion, skinSurfaceData.emission, skinSurfaceData.alpha,
                half4(_TranslucencyStrength * skinSurfaceData.translucency, _TranslucencyPower, _ShadowStrength, _Distortion), 1, normalWS, _SubsurfaceColor,
                lerp(skinSurfaceData.translucency, 1, _Curvature), skinSurfaceData.skinMask);
                
                return color;

                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                return color;
            }
            ENDHLSL
        }
        /*
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma multi_compile_instancing
            #include "./skin_v2019_input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            half3 _LightDirection;

            VertexOutput ShadowPassVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                half3 normalWS = TransformObjectToWorldDir(input.normalOS);
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                return output;
            }

            half4 ShadowPassFragment(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "DepthOnly" }
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing

            #define DEPTHONLYPASS
            #include "./skin_v2019_input.hlsl"

            VertexOutput DepthOnlyVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthOnlyFragment(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                return 0;
            }

            ENDHLSL
        }
        */
    }
}
