Shader "SoFunny/Sausage/PC/InstancedGrass"
{
    Properties
    {
        _Albedo1 ("Albedo 1", Color) = (1, 1, 1)
        _Albedo2 ("Albedo 2", Color) = (1, 1, 1)
        _Scale ("Scale", Range(0.0, 2.0)) = 0.0
        _Droop ("Droop", Range(0.0, 10.0)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" }

        Pass
        {

            Cull Off
            Zwrite On
            Name "Lit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag

            #define UNITY_PI    3.14159265359f

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "./Random.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 positionWS : TEXCOORD1;
                float noiseVal : TEXCOORD2;
                float3 chunkNum : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct GrassData
            {
                float4 position;
                float2 uv;
                float displacement;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _Albedo1;
                half4 _Albedo2;
                half _Scale;
                half _Droop;
            CBUFFER_END

            TEXTURE2D(_WindNoiseTex);       SAMPLER(sampler_WindNoiseTex);
            StructuredBuffer<GrassData> positionsBuffer;
            int _ChunkNum;

            Varyings vert(Attributes input, uint instanceID : SV_INSTANCEID)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                float4 instancePos = positionsBuffer[instanceID].position;
                float idHash = randValue(abs(instancePos.x * 10000 + instancePos.y * 100 + instancePos.z * 0.05f + 2));
                idHash = randValue(idHash * 100000);

                float4 animationDirection = float4(0.0f, 0.0f, 1.0f, 0.0f);
                animationDirection = normalize(rotateAroundYInDegrees(animationDirection, idHash * 180.0f));

                float4 localPosition = rotateAroundXInDegrees(input.positionOS, 90.0f);
                localPosition = rotateAroundYInDegrees(localPosition, idHash * 180.0f);
                localPosition.y += _Scale * input.uv.y * input.uv.y * input.uv.y;
                localPosition.xz += _Droop * lerp(0.5f, 1.0f, idHash) * (input.uv.y * input.uv.y * _Scale) * animationDirection.xy;
                float4 worldUV = float4(positionsBuffer[instanceID].uv, 0, 0);
                float swayVariance = lerp(0.8, 1.0, idHash);
                half4 windNoiseValue = SAMPLE_TEXTURE2D_LOD(_WindNoiseTex, sampler_WindNoiseTex, worldUV.xy, 0.0);
                float movement = input.uv.y * input.uv.y * windNoiseValue.r;
                movement *= swayVariance;
                localPosition.xz += movement;
                float4 worldPosition = float4(instancePos.xyz + localPosition.xyz, 1.0f);
                worldPosition.y -= positionsBuffer[instanceID].displacement;
                worldPosition.y *= 1.0f + positionsBuffer[instanceID].position.w * lerp(0.8f, 1.0f, idHash);
                worldPosition.y += positionsBuffer[instanceID].displacement;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(worldPosition.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.uv;
                output.noiseVal = windNoiseValue.r;
                output.positionWS = worldPosition;
                output.chunkNum = float3(randValue(_ChunkNum * 20 + 1024), randValue(randValue(_ChunkNum) * 10 + 2048), randValue(_ChunkNum * 4 + 4096));
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half4 col = lerp(_Albedo1, _Albedo2, input.uv.y);

                return col;
            }
            ENDHLSL
        }
    }
}
