Shader "Chicken/PC/Grass/Instanced"
{
    Properties
    {
        [Header(Terrain)]
        [NoScaleOffset]_TerrainColor ("Terrain color", 2D) = "black" { }
        _ColorUp ("ColorUp", Color) = (1, 1, 1, 1)
        _ColorMiddle ("ColorMiddle", Color) = (1, 1, 1, 1)
        _WPosST ("Scale(XY)Offset(ZW) ", Vector) = (1, 1, 0, 0)
        _BlendRatio ("BlendRange,Min(X)Max(Y)", Vector) = (0.2, 0.8, 0, 0)

        // [NoScaleOffset]_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
        // _Color ("Color", Color) = (1,1,1,1)
        // _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5

        _AttenBias ("AttenBias", Range(0, 1)) = 0.5
        _LightStrength ("Light Strength", Range(0, 1)) = 0.5
        _VerticalBillboarding ("_VerticalBillboarding", Range(0, 1)) = 0
        [Header(Wind)]
        _NoiseTex ("Wind Noise", 2D) = "white" { }
        _WindVector ("Wind Vector (x,y) Direction ", Vector) = (1, 1, 1, 1)
        _WindFrequency ("Wind Frequency", Range(0, 1)) = 0.5
        _WindStrength ("Wind Strength", Float) = 1
        [Header(Wave)]
        _NoiseDetailTex ("Wave Noise", 2D) = "white" { }
        _WaveFrequency ("Wave Frequency", Range(0, 1)) = 0.5
        _WaveStrength ("Wave Strength", Float) = 1
        [Header(React)]
        _ActRadius ("Act Radius", Float) = 1
        _ActStrength ("Act Strength", Float) = 1
        _ActOffset ("Act Offset", Float) = 1
        [Header(Toogle)]
        [Toggle(_USE_FOUR)] _USE_FOUR ("Use Four", float) = 1
    }

    SubShader
    {
        Tags { "Queue" = "AlphaTest" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout" }
        Cull off

        Stencil
        {
            Ref 1
            Comp Always
            Pass Replace
        }

        Pass
        {
            Name "Grass"

            HLSLPROGRAM

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma shader_feature _ _SHADOWS_SOFT
            // -------------------------------------
            // keywords
            #pragma multi_compile _ _USE_FOUR
            #pragma multi_compile _ _USE_NORMAL

            #pragma vertex SimpleLitVertex
            #pragma fragment SimpleLitFragment

            #define _USE_MAINTEX 1
            #define _USE_ALPHA_TEST 1
            #define _USE_CUSTOMCOLOR 1
            #define _USE_FOG 1
            #define _USE_ATTENBIAS 1
            #define _USE_LIGHT_STRENGTH 1
            #define _USE_FACE_DIFF 1

            #define _USE_WAVE 1
            #define _USE_WIND 1
            #define _USE_REACT 1
            #define _USE_TERRAIN 1
            #define _USE_STATIC_GI 1
            #define _USE_NORMAL 1

            #include "Chicken-GrassPC-Instanced.hlsl"
            ENDHLSL
        }
    }
}
