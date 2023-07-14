Shader "Chicken/PC/Leaves_ISE"
{
    Properties
    {
        _BaseColor ("Main Color", Color) = (0, 1, 0, 1)
        _SecondColor ("Second Color", Color) = (0, 0, 0, 1)
        _HidePower ("Hide Power", float) = 4.0
        _AOStrength ("AO Strength", float) = 1.0
        [NoScaleOffset]_MainTexture ("Main Texture", 2D) = "white" { }
        _WindSpeed_WindWavesScale_WindForce_Cutoff ("WindSpeed, WindScale, WindForce, Cutoff ( < 1.0 )", Vector) = (0.5, 0.2, 0.2, 0.35)
        _Radius_TransNormal_TransScattering_TransDirect ("Radius, TransNormal, TransScattering, TransDirect", Vector) = (45.0, 1.0, 1.0, 0.15)
        _TransAmbient_TransStrength_LightEffect ("TransAmbient, TransStrength, LightEffect, Null", Vector) = (0.4, 0.65, 1.0, 0.0)
        [Toggle]_USE_LOD ("Use LOD", Float) = 0.0
    }

    SubShader
    {

        Tags { "RenderPipeline" = "UniversalPipeline" "Queue" = "AlphaTest+51" }
        Cull Off
        Stencil
        {
            Ref 1
            Comp Always
            Pass Replace
        }
        HLSLINCLUDE
        #pragma target 3.0
        float3 mod3D289(float3 x)
        {
            return x - floor(x / 289.0) * 289.0;
        }

        float4 mod3D289(float4 x)
        {
            return x - floor(x / 289.0) * 289.0;
        }

        float4 permute(float4 x)
        {
            return mod3D289((x * 34.0 + 1.0) * x);
        }

        float4 taylorInvSqrt(float4 r)
        {
            return 1.79284291400159 - r * 0.85373472095314;
        }

        float snoise(float3 v)
        {
            const float2 C = float2(0.1667, 0.3333);
            float3 i = floor(v + dot(v, C.yyy));
            float3 x0 = v - i + dot(i, C.xxx);
            float3 g = step(x0.yzx, x0.xyz);
            float3 l = 1.0 - g;
            float3 i1 = min(g.xyz, l.zxy);
            float3 i2 = max(g.xyz, l.zxy);
            float3 x1 = x0 - i1 + C.xxx;
            float3 x2 = x0 - i2 + C.yyy;
            float3 x3 = x0 - 0.5;
            i = mod3D289(i);
            float4 p = permute(
                permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0)) + i.y + float4(0.0, i1.y, i2.y, 1.0)) + i.x +
                float4(0.0, i1.x, i2.x, 1.0));
            float4 j = p - 49.0 * floor(p / 49.0); // mod(p,7*7)
            float4 x_ = floor(j / 7.0);
            float4 y_ = floor(j - 7.0 * x_); // mod(j,N)
            float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
            float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;
            float4 h = 1.0 - abs(x) - abs(y);
            float4 b0 = float4(x.xy, y.xy);
            float4 b1 = float4(x.zw, y.zw);
            float4 s0 = floor(b0) * 2.0 + 1.0;
            float4 s1 = floor(b1) * 2.0 + 1.0;
            float4 sh = -step(h, 0.0);
            float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
            float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
            float3 g0 = float3(a0.xy, h.x);
            float3 g1 = float3(a0.zw, h.y);
            float3 g2 = float3(a1.xy, h.z);
            float3 g3 = float3(a1.zw, h.w);
            float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
            g0 *= norm.x;
            g1 *= norm.y;
            g2 *= norm.z;
            g3 *= norm.w;
            float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
            m = m * m;
            m = m * m;
            float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
            return 42.0 * dot(m, px);
        }


        float4 FixedTess(float tessValue)
        {
            return tessValue;
        }

        float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess, float4x4 o2w,
        float3 cameraPos)
        {
            float3 wpos = mul(o2w, vertex).xyz;
            float dist = distance(wpos, cameraPos);
            float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
            return f;
        }

        float4 CalcTriEdgeTessFactors(float3 triVertexFactors)
        {
            float4 tess;
            tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
            tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
            tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
            tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
            return tess;
        }

        float CalcEdgeTessFactor(float3 wpos0, float3 wpos1, float edgeLen, float3 cameraPos, float4 scParams)
        {
            float dist = distance(0.5 * (wpos0 + wpos1), cameraPos);
            float len = distance(wpos0, wpos1);
            float f = max(len * scParams.y / (edgeLen * dist), 1.0);
            return f;
        }

        float DistanceFromPlane(float3 pos, float4 plane)
        {
            float d = dot(float4(pos, 1.0f), plane);
            return d;
        }

        bool WorldViewFrustumCull(float3 wpos0, float3 wpos1, float3 wpos2, float cullEps, float4 planes[6])
        {
            float4 planeTest;
            planeTest.x = ((DistanceFromPlane(wpos0, planes[0]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos1, planes[0]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos2, planes[0]) > - cullEps) ? 1.0f : 0.0f);
            planeTest.y = ((DistanceFromPlane(wpos0, planes[1]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos1, planes[1]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos2, planes[1]) > - cullEps) ? 1.0f : 0.0f);
            planeTest.z = ((DistanceFromPlane(wpos0, planes[2]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos1, planes[2]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos2, planes[2]) > - cullEps) ? 1.0f : 0.0f);
            planeTest.w = ((DistanceFromPlane(wpos0, planes[3]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos1, planes[3]) > - cullEps) ? 1.0f : 0.0f) +
            ((DistanceFromPlane(wpos2, planes[3]) > - cullEps) ? 1.0f : 0.0f);
            return !all(planeTest);
        }

        float4 DistanceBasedTess(float4 v0, float4 v1, float4 v2, float tess, float minDist, float maxDist,
        float4x4 o2w, float3 cameraPos)
        {
            float3 f;
            f.x = CalcDistanceTessFactor(v0, minDist, maxDist, tess, o2w, cameraPos);
            f.y = CalcDistanceTessFactor(v1, minDist, maxDist, tess, o2w, cameraPos);
            f.z = CalcDistanceTessFactor(v2, minDist, maxDist, tess, o2w, cameraPos);

            return CalcTriEdgeTessFactors(f);
        }

        float4 EdgeLengthBasedTess(float4 v0, float4 v1, float4 v2, float edgeLength, float4x4 o2w, float3 cameraPos,
        float4 scParams)
        {
            float3 pos0 = mul(o2w, v0).xyz;
            float3 pos1 = mul(o2w, v1).xyz;
            float3 pos2 = mul(o2w, v2).xyz;
            float4 tess;
            tess.x = CalcEdgeTessFactor(pos1, pos2, edgeLength, cameraPos, scParams);
            tess.y = CalcEdgeTessFactor(pos2, pos0, edgeLength, cameraPos, scParams);
            tess.z = CalcEdgeTessFactor(pos0, pos1, edgeLength, cameraPos, scParams);
            tess.w = (tess.x + tess.y + tess.z) / 3.0f;
            return tess;
        }

        float4 EdgeLengthBasedTessCull(float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement,
        float4x4 o2w, float3 cameraPos, float4 scParams, float4 planes[6])
        {
            float3 pos0 = mul(o2w, v0).xyz;
            float3 pos1 = mul(o2w, v1).xyz;
            float3 pos2 = mul(o2w, v2).xyz;
            float4 tess;

            if (WorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement, planes))
            {
                tess = 0.0f;
            }
            else
            {
                tess.x = CalcEdgeTessFactor(pos1, pos2, edgeLength, cameraPos, scParams);
                tess.y = CalcEdgeTessFactor(pos2, pos0, edgeLength, cameraPos, scParams);
                tess.z = CalcEdgeTessFactor(pos0, pos1, edgeLength, cameraPos, scParams);
                tess.w = (tess.x + tess.y + tess.z) / 3.0f;
            }
            return tess;
        }

        inline float Dither8x8Bayer(int x, int y)
        {
            const float dither[64] = {
                1, 49, 13, 61, 4, 52, 16, 64,
                33, 17, 45, 29, 36, 20, 48, 32,
                9, 57, 5, 53, 12, 60, 8, 56,
                41, 25, 37, 21, 44, 28, 40, 24,
                3, 51, 15, 63, 2, 50, 14, 62,
                35, 19, 47, 31, 34, 18, 46, 30,
                11, 59, 7, 55, 10, 58, 6, 54,
                43, 27, 39, 23, 42, 26, 38, 22
            };
            int r = y * 8 + x;
            return dither[r] * 0.015; // same # of instructions as pre-dividing due to compiler magic

        }

        /*
        float3 windDirection(float3 windOffset, float direction)
        {
            // wind direction happens around Y axis
            float rad = radians(360.0 * direction);
            float4 c0 = float4(cos(rad), 0, -1.0 * sin(rad), 0.0);
            float4 c1 = float4(0.0, 1.0, 0.0, 0.0);
            float4 c2 = float4(sin(rad), 0.0, cos(rad), 0.0);
            float4 c3 = float4(0.0, 0.0, 0.0, 1.0);

            float4x4 orientMat = float4x4(c0, c1, c2, c3);

            return mul(orientMat, float4(windOffset, 1.0));
        }
        */
        ENDHLSL

        Pass
        {

            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            Blend One Zero, One Zero
            ZWrite On

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _USE_LOD_ON
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            /*
            #pragma multi_compile_fragment LOD_FADE_CROSSFADE

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif
            */

            //#define LOD_FADE_CROSSFADE 1

            CBUFFER_START(UnityPerMaterial)
                half4 _WindSpeed_WindWavesScale_WindForce_Cutoff;
                half4 _Radius_TransNormal_TransScattering_TransDirect;
                half4 _TransAmbient_TransStrength_LightEffect;
                half4 _BaseColor;
                half4 _SecondColor;
                half _HidePower;
                half _AOStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                half2 uv0 : TEXCOORD0;
                half3 normalOS : NORMAL;
                float4 vetexCol : COLOR;
                //half4 tangentOS : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2 uv0 : TEXCOORD0;
                half4 lightmapUVOrVertexSH : TEXCOORD1;
                half4 normalWSAndCenterLength : TEXCOORD2;
                half4 viewDirWSAndFogFactor : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                #if !defined(_USE_LOD_ON)
                    float4 preNormalWS : TEXCOORD6; // xyz:preNormal w:AO
                    float4 screenPos : TEXCOORD7;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTexture);    SAMPLER(sampler_MainTexture);

            half4 UniversalFragmentPBR(InputData inputData, half3 albedo, half metallic, half3 specular, half smoothness, half occlusion, half3 emission, half alpha, half lightEffect)
            {
                BRDFData brdfData;
                InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

                Light mainLight = GetMainLight(inputData.shadowCoord);
                // HY style
                mainLight.color *= lightEffect;

                MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

                half3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.normalWS,
                inputData.viewDirectionWS);
                color += LightingPhysicallyBased(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);
                return half4(color, alpha);
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                positionWS = TransformObjectToWorld(input.positionOS.xyz);
                #if !defined(_USE_LOD_ON)
                    float time = _TimeParameters.x * (_WindSpeed_WindWavesScale_WindForce_Cutoff.x * 5.0);
                    float perlinNoise = snoise((positionWS + time) * _WindSpeed_WindWavesScale_WindForce_Cutoff.y);
                    perlinNoise = perlinNoise * _WindSpeed_WindWavesScale_WindForce_Cutoff.z * 0.1;
                    positionWS.xyz += half3(perlinNoise.x, perlinNoise.x, perlinNoise.x);
                #endif
                output.positionWS = positionWS;
                half lengthToPivot = length(input.positionOS.xyz);
                lengthToPivot = saturate(lengthToPivot / _Radius_TransNormal_TransScattering_TransDirect.x);
                float4 positionCS = TransformWorldToHClip(positionWS);
                output.positionCS = positionCS;
                VertexNormalInputs vni = GetVertexNormalInputs(input.normalOS);
                output.normalWSAndCenterLength.xyz = vni.normalWS;
                output.normalWSAndCenterLength.w = smoothstep(0.25, 0.30, lengthToPivot);
                output.uv0 = input.uv0;
                OUTPUT_SH(vni.normalWS.xyz, output.lightmapUVOrVertexSH.xyz);
                //half3 vertexLight = VertexLighting(positionWS, vni.normalWS);
                output.viewDirWSAndFogFactor.xyz = SafeNormalize(GetCameraPositionWS() - positionWS);
                output.viewDirWSAndFogFactor.w = ComputeFogFactor(positionCS.z);
                #if !defined(_USE_LOD_ON)
                    float3 preNormalOS = input.vetexCol.xyz * 2 - 1;
                    preNormalOS.x = -preNormalOS.x;
                    float3 preNormalWS = TransformObjectToWorldNormal(preNormalOS);
                    output.preNormalWS = float4(preNormalWS, input.vetexCol.w);
                    output.screenPos = ComputeScreenPos(positionCS);
                #endif
                return output;
            }

            half4 UniversalFragmentSimple(InputData inputData, half3 diffuse, half4 specularGloss, half smoothness, half alpha, half lightEffect)
            {
                Light mainLight = GetMainLight(inputData.shadowCoord);
                MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));
                mainLight.color *= lightEffect;
                half3 attenuatedLightColor = mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation);
                half3 diffuseColor = inputData.bakedGI + LightingLambert(attenuatedLightColor, mainLight.direction, inputData.normalWS);
                half3 specularColor = LightingSpecular(attenuatedLightColor, mainLight.direction, inputData.normalWS, inputData.viewDirectionWS, specularGloss, smoothness);

                half3 finalColor = diffuseColor * diffuse;

                #if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                    finalColor += specularColor;
                #endif
                return half4(finalColor, alpha);
            }


            half4 frag(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                half4 mainColor = SAMPLE_TEXTURE2D(_MainTexture, sampler_MainTexture, input.uv0);

                InputData inputData;
                inputData.positionWS = input.positionWS;

                inputData.viewDirectionWS = input.viewDirWSAndFogFactor.xyz;
                inputData.shadowCoord = 0; // shadow is not needed for now
                inputData.normalWS = normalize(input.normalWSAndCenterLength.xyz);
                inputData.fogCoord = input.viewDirWSAndFogFactor.w;
                inputData.bakedGI = SAMPLE_GI(input.lightmapUVOrVertexSH.xy, input.lightmapUVOrVertexSH.xyz, input.normalWSAndCenterLength.xyz);
                half4 brdfColor;
                #if !defined(_USE_LOD_ON)
                    float3 preWorldNormal = normalize(input.preNormalWS.xyz);
                    float NdotV = dot(preWorldNormal, inputData.viewDirectionWS);
                    NdotV = abs(NdotV);
                    float4 screenPos = input.screenPos / input.screenPos.w;
                    float2 clipScreen = screenPos.xy * _ScreenParams.xy;
                    float dither = Dither8x8Bayer(fmod(clipScreen.x, 8), fmod(clipScreen.y, 8));
                    float clampResult = clamp((((1.0 - ((1.0 - NdotV) * 2.0))) * _HidePower), 0.0, 1.0);
                    dither = step(dither, clampResult);
                    clip(mainColor.a * dither - _WindSpeed_WindWavesScale_WindForce_Cutoff.w);
                    half3 Albedo = lerp(_BaseColor.rgb, _SecondColor.rgb, input.normalWSAndCenterLength.w) * mainColor.rgb;
                    brdfColor = UniversalFragmentPBR(
                        inputData,
                        Albedo,
                        0.0,
                        0.0,
                        0.0,
                        lerp(1, input.preNormalWS.w, _AOStrength),
                        0.0,
                        mainColor.a,
                        _TransAmbient_TransStrength_LightEffect.z
                    );
                    Light mainLight = GetMainLight();
                    half3 mainLightAtten = mainLight.color * mainLight.distanceAttenuation;
                    half3 mainLightDir = mainLight.direction + inputData.normalWS *
                    _Radius_TransNormal_TransScattering_TransDirect.y;

                    half mainVdotL = pow(saturate(dot(inputData.viewDirectionWS, -mainLightDir)),
                    _Radius_TransNormal_TransScattering_TransDirect.z);
                    half3 mainTranslucency = mainLightAtten * (mainVdotL * _Radius_TransNormal_TransScattering_TransDirect.w
                    + inputData.bakedGI * _TransAmbient_TransStrength_LightEffect.x);
                    mainTranslucency = Albedo * mainTranslucency * _TransAmbient_TransStrength_LightEffect.y;
                    brdfColor.rgb += mainTranslucency;
                    brdfColor.rgb = saturate(brdfColor.rgb);
                    brdfColor.rgb = MixFog(brdfColor.rgb, input.viewDirWSAndFogFactor.w);
                    return brdfColor;
                #else
                    half3 Albedo = lerp(_BaseColor.rgb, _SecondColor.rgb, input.normalWSAndCenterLength.w) * mainColor.rgb;
                    brdfColor = UniversalFragmentSimple(inputData, Albedo, 0.0, 0.0, mainColor.a, _TransAmbient_TransStrength_LightEffect.z);
                    clip(mainColor.a - _WindSpeed_WindWavesScale_WindForce_Cutoff.w);
                    return brdfColor;
                #endif
                // #endif

            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            /*
                #pragma multi_compile_fragment LOD_FADE_CROSSFADE

                #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
                #endif
            */

            CBUFFER_START(UnityPerMaterial)
                half4 _WindSpeed_WindWavesScale_WindForce_Cutoff;
                half4 _Radius_TransNormal_TransScattering_TransDirect;
                half4 _TransAmbient_TransStrength_LightEffect;
                half4 _BaseColor;
                half4 _SecondColor;
                half _HidePower;
                half _AOStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                half2 uv0 : TEXCOORD0;
                half3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2 uv0 : TEXCOORD0;
                half4 lightmapUVOrVertexSH : TEXCOORD1;
                half4 normalWSAndCenterLength : TEXCOORD2;
                half4 viewDirWSAndFogFactor : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTexture);
            SAMPLER(sampler_MainTexture);
            float3 _LightDirection;

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float time = _TimeParameters.x * (_WindSpeed_WindWavesScale_WindForce_Cutoff.x * 5.0);
                float perlinNoise = snoise((positionWS + time) * _WindSpeed_WindWavesScale_WindForce_Cutoff.y);

                // wind force
                perlinNoise = perlinNoise * _WindSpeed_WindWavesScale_WindForce_Cutoff.z * 0.1;

                // world pos
                positionWS = TransformObjectToWorld(input.positionOS.xyz);

                // use fixed center based
                half lengthToPivot = length(input.positionOS.xyz);
                lengthToPivot = saturate(lengthToPivot / _Radius_TransNormal_TransScattering_TransDirect.x);

                positionWS.xyz += half3(perlinNoise.x, perlinNoise.x, perlinNoise.x);

                VertexNormalInputs vni = GetVertexNormalInputs(input.normalOS);
                // manually transform
                //float3 positionVS = TransformWorldToView(positionWS);
                // float4 positionCS = TransformWorldToHClip(positionWS);
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, vni.normalWS, _LightDirection));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                output.positionCS = positionCS;
                output.positionWS = positionWS;

                output.normalWSAndCenterLength.xyz = vni.normalWS;
                output.normalWSAndCenterLength.w = smoothstep(0.25, 0.30, lengthToPivot);

                output.uv0 = input.uv0;

                OUTPUT_SH(vni.normalWS.xyz, output.lightmapUVOrVertexSH.xyz);
                output.viewDirWSAndFogFactor.xyz = SafeNormalize(_WorldSpaceCameraPos.xyz - positionWS);
                output.viewDirWSAndFogFactor.w = ComputeFogFactor(positionCS.z);

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                half4 mainColor = SAMPLE_TEXTURE2D(_MainTexture, sampler_MainTexture, input.uv0);
                clip(mainColor.a - _WindSpeed_WindWavesScale_WindForce_Cutoff.w);
                return 0;
            }
            ENDHLSL
        }
    }

    CustomEditor "PCLeavesISEShaderGUI"
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}