Shader "Chicken/PC/SkinWithSSS"
{
    Properties
    {
        //[HDR]_BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap ("RGB:Albedo, A:Thickness", 2D) = "white" { }
        _SkinRampMap ("Skin Ramp Map", 2D) = "white" { }
        _SubSurfaceColor ("SubSurface Color", Color) = (1, 0, 0, 1)
        _ScatteringEdge ("Scattering Edge", Float) = 1
        _ScatteringStrength ("SubSurface Scattering Strength", Range(0.0, 1.0)) = 0.025
        _TranslucencyPower ("Transmission Power", Range(0.0, 10.0)) = 2.0
        _BackScattering ("Ambient Back Scattering", Range(0.0, 10.0)) = 8.0
        _SpecularAO ("Specular AO", Range(0.0, 1)) = 0.212
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.45
        //_SpecularColor ("Specular Color", Color) = (0.2, 0.2, 0.2, 0)
        _ShadowStrength ("Shadow Strength", Range(0.0, 1.0)) = 0.8
        _SkinShadowSampleBias ("SkinShadow Bias", Range(0.0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma target 3.0

            #pragma multi_compile _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            //#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "./ChickenSkinInput.hlsl"
            #include "./ChickenSkinShading.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex vert
            #pragma fragment frag

            //  Include base inputs and all other needed "base" includes
            #include "./ChickenSkinInput.hlsl"
            #include "./ChickenSkinShadowCaster.hlsl"

            ENDHLSL
        }

    }
}
