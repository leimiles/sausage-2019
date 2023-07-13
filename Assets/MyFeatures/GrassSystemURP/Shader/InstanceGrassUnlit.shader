Shader "SoFunny/Sausage/PC/InstanceGrassUnlit"
{
    Properties { }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "ShaderModel" = "4.5" }
        Pass
        {
            Name "InstanceGrass"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off
            Blend One Zero
            ZTest LEqual
            ZWrite On
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "./Grass.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                //half3 normalOS : NORMAL;
                #if UNITY_ANY_INSTANCING_ENABLED
                    uint instanceID : INSTANCEID_SEMANTIC;
                #endif
                uint vertexID : VERTEXID_SEMANTIC;
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                half3 normalWS : TEXCOORD2;
                #if UNITY_ANY_INSTANCING_ENABLED
                    uint instanceID : CUSTOM_INSTANCE_ID;
                #endif
                /*
                #if defined(LIGHTMAP_ON)
                    float2 staticLightmapUV;
                #endif
                #if defined(DYNAMICLIGHTMAP_ON)
                    float2 dynamicLightmapUV;
                #endif
                #if !defined(LIGHTMAP_ON)
                    float3 sh;
                #endif
                float4 fogFactorAndVertexLight;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord;
                #endif

                #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
                    uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
                #endif
                #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
                    uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
                #endif
                #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
                    FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
                #endif
                */
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                //UNITY_SETUP_INSTANCE_ID(input);
                //UNITY_TRANSFER_INSTANCE_ID(input, output);
                float3 worldPos;
                half3 normalOS;
                float2 uv;
                half3 vertexColor;
                GetComputeData(input.vertexID, worldPos, normalOS, uv, vertexColor);
                input.positionOS.xyz = worldPos;
                output.positionWS = worldPos;
                VertexPositionInputs vpi = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vpi.positionCS;
                VertexNormalInputs vni = GetVertexNormalInputs(normalOS.xyz);
                output.normalWS = vni.normalWS;
                return output;
            }



            half4 frag(Varyings input) : SV_Target
            {
                //UNITY_SETUP_INSTANCE_ID(input);
                //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return half4(input.normalWS, 1);
            }
            ENDHLSL
        }
    }
}
