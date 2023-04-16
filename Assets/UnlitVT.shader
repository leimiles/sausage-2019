Shader "RVT/UnlitRVT" {
    Properties{
        _BaseMap("Example Texture", 2D) = "white" {}
        _BaseColor("Example Colour", Color) = (0, 0.66, 0.73, 1)
            _sub("_sub",float)=1
            _all("_all",float)=1
            _pow("_pow",float)=1
    }
        SubShader{
            Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float _terrainSize;
            float _sub;
            float _all;
            float _HeightRange;
            float _pow;
            TEXTURE2D(_RVTTtexture);
            SAMPLER(sampler_RVTTtexture);

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_HeightOffset);
            SAMPLER(sampler_HeightOffset);
            CBUFFER_END
            ENDHLSL

            Pass {
                Name "Example"
                Tags { "LightMode" = "UniversalForward" }

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

                half4 frag(v2f i) : SV_Target {
                    
                    half2 uvW = i.positionWS.xz / _terrainSize;                    
                    float2 transUv = uvW;
                    half4 blendMap = SAMPLE_TEXTURE2D(_RVTTtexture, sampler_RVTTtexture, transUv);
                    half4 height = SAMPLE_TEXTURE2D(_HeightOffset, sampler_HeightOffset, transUv);
                   // i.positionWS.y = LinearEyeDepth(i.positionWS.y, _ZBufferParams);
                    half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                    float offset = i.positionWS.y- pow(height.x * _HeightRange*2,1);
                    
                    offset = ((offset) - _sub) / _all;
                    offset = pow(offset, _pow);
                    offset = saturate(offset);
                   /* if (offset > _all)
                    {
                        offset = 1;
                    }
                    else
                    {
                        offset = 0;
                    }*/
                    float4 finalColor = lerp(blendMap, baseMap, offset);
                   // return offset.x;
                    return finalColor;
                }
                ENDHLSL
            }
        }
}