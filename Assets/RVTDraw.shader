Shader "RVT/DrawTexture" {
    Properties{
        _BaseMap("Example Texture", 2D) = "white" {}
        _BaseColor("Example Colour", Color) = (0, 0.66, 0.73, 1)
    }
        SubShader{
            Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor; 
            float4 _TileOffset1;
            float4 _TileOffset2;
            float4 _TileOffset3;
            float4 _TileOffset4;
            float _terrainSize;

            TEXTURE2D(_Blend);
            SAMPLER(sampler_Blend);

            TEXTURE2D(_Diffuse1);
            SAMPLER(sampler_Diffuse1);

            TEXTURE2D(_Diffuse2);
            SAMPLER(sampler_Diffuse2);

            TEXTURE2D(_Diffuse3);
            SAMPLER(sampler_Diffuse3);

            TEXTURE2D(_Diffuse4);
            SAMPLER(sampler_Diffuse4);

            TEXTURE2D(_Normal1);
            SAMPLER(sampler_Normal1);

            TEXTURE2D(_Normal2);
            SAMPLER(sampler_Normal2);

            TEXTURE2D(_Normal3);
            SAMPLER(sampler_Normal3);

            TEXTURE2D(_Normal4);
            SAMPLER(sampler_Normal4);



            CBUFFER_END
            ENDHLSL

            Pass {
                Name "Example"
                Tags { "LightMode" = "UniversalForward" }
               // Cull Off ZWrite Off ZTest Always
                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                struct a2v {
                    float4 positionOS   : POSITION;
                    float2 uv           : TEXCOORD0;
                    float4 color        : COLOR;
                };

                struct v2f {
                    float4 positionCS  : SV_POSITION;
                    float2 uv           : TEXCOORD0;
                    float4 color        : COLOR;
                    float3 positionWS   :TEXCOORD1;
                };

             

                v2f vert(a2v v) {
                    v2f o;

                    //VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                    //o.positionCS = positionInputs.positionCS;
                    // Or this :
                    o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                    o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                    o.color = v.color;
                    return o;
                }

                half4 frag(v2f i) : SV_Target{
                    half2 uvW = i.positionWS.xz / _terrainSize;
                    half4 blend = SAMPLE_TEXTURE2D(_Blend, sampler_Blend, i.uv);

                    float2 transUv = i.uv *_TileOffset1.xy + _TileOffset1.zw;
                    half4 diffuse1 = SAMPLE_TEXTURE2D(_Diffuse1, sampler_Diffuse1, transUv);
                    half4 normal1 = SAMPLE_TEXTURE2D(_Normal1, sampler_Normal1, transUv);
                    transUv = i.uv * _TileOffset2.xy + _TileOffset2.zw;
                    half4 diffuse2 = SAMPLE_TEXTURE2D(_Diffuse2, sampler_Diffuse2, transUv);
                    half4 normal2 = SAMPLE_TEXTURE2D(_Normal2, sampler_Normal2, transUv);
                    transUv = i.uv * _TileOffset3.xy + _TileOffset3.zw;
                    half4 diffuse3 = SAMPLE_TEXTURE2D(_Diffuse3, sampler_Diffuse3, transUv);
                    half4 normal3 = SAMPLE_TEXTURE2D(_Normal3, sampler_Normal3, transUv);
                    transUv = i.uv * _TileOffset4.xy + _TileOffset4.zw;
                    half4 diffuse4 = SAMPLE_TEXTURE2D(_Diffuse4, sampler_Diffuse4, transUv);
                    half4 normal4 = SAMPLE_TEXTURE2D(_Normal4, sampler_Normal4, transUv);
                    //return float4()

                    half4 finalColor = blend.r * diffuse1 + blend.g * diffuse2 + blend.b * diffuse3 + blend.a * diffuse4;
                    return finalColor;
                }
                ENDHLSL
            }
        }
}