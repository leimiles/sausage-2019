Shader "SoFunny/Sausage/PC/InstancedTest"
{
    Properties
    {
        _Albedo1 ("Albedo 1", Color) = (1, 0, 0, 1)
        _Albedo2 ("Albedo 2", Color) = (0, 1, 1, 1)
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
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct InstanceData
            {
                float4 position;
            };
            CBUFFER_START(UnityPerMaterial)
                half4 _Albedo1;
                half4 _Albedo2;
            CBUFFER_END

            StructuredBuffer<InstanceData> positionsBuffer;
            int _ChunkNum;

            Varyings vert(Attributes input, uint instanceID : SV_INSTANCEID)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                float4 instancePos = positionsBuffer[instanceID].position;
                float4 worldPosition = float4(instancePos.xyz, 1.0f);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(worldPosition.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = input.uv;
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
