Shader "funnyland/chr/skin"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap ("Base Map", 2D) = "white" { }
        _SkinRampMap ("Skin Ramp Map", 2D) = "white" { }
        _CEATMap ("Curvature, Emission Mask, AO, Thickness", 2D) = "white" { }
        _SubSurfaceColor ("SubSurface Color", Color) = (1, 0, 0, 1)
        _ScatteringStrength ("SubSurface Scattering Strength", Range(0.0, 1.0)) = 0.025
        _TranslucencyPower ("Transmission Power", Range(0.0, 10.0)) = 2.0
        _BackScattering ("Ambient Back Scattering", Range(0.0, 10.0)) = 8.0
        _SpecularAO ("Specular AO", Range(0.0, 1)) = 0.212
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.45
        _SpecularColor ("Specular Color", Color) = (0.2, 0.2, 0.2, 0)
        _ShadowStrength ("Shadow Strength", Range(0.0, 1.0)) = 0.8
        _SkinShadowSampleBias ("SkinShadow Bias", Range(0.0, 1)) = 0
        [Toggle] _Test ("Test", Float) = 0
        [Toggle(FOG_ON)] _Fog_On ("Fog_On", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "ShaderModel" = "4.5" }
        LOD 300
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #define _SPECULAR_SETUP
            #pragma multi_compile _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma shader_feature_local _TEST_ON
            #pragma shader_feature_local FOG_ON
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "./PlayerShaderLib/PlayerSkinInput.hlsl"
            #include "./PlayerShaderLib/PlayerSkinShading.hlsl"
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
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex vert
            #pragma fragment frag

            //  Include base inputs and all other needed "base" includes
            #include "./PlayerShaderLib/PlayerSkinInput.hlsl"
            #include "./PlayerShaderLib/PlayerShadowCaster.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include "./PlayerShaderLib/PlayerSkinInput.hlsl"
            #include "./PlayerShaderLib/PlayerDepthOnly.hlsl"

            ENDHLSL
        }
    }

    //CustomEditor "PlayerSkinShaderGUI"

}
