using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using System;

public class PCLeavesISEShaderGUI : BaseShaderGUI {
    #region GUIConent

    public static readonly GUIContent mainTextureGUI = new GUIContent("Main Texture");
    public static readonly GUIContent cutOffGUI = new GUIContent("Cut Off: ");
    public static readonly GUIContent windSpeedGUI = new GUIContent("Wind Speed: ");
    public static readonly GUIContent windWaveScaleGUI = new GUIContent("Wind Wave Scale: ");
    public static readonly GUIContent windForceGUI = new GUIContent("Wind Force: ");
    public static readonly GUIContent radiusGUI = new GUIContent("Vegets Raidus: ");
    public static readonly GUIContent transNormalGUI = new GUIContent("Trans Normal: ");
    public static readonly GUIContent transScatteringGUI = new GUIContent("Trans Scattering: ");
    public static readonly GUIContent transDirectGUI = new GUIContent("Trans Direct: ");
    public static readonly GUIContent transAmbientGUI = new GUIContent("Trans Ambient: ");
    public static readonly GUIContent transStrengthGUI = new GUIContent("Trans Strength: ");
    public static readonly GUIContent lightEffectGUI = new GUIContent("Light Influence: ");
    public static readonly GUIContent hidePower = new GUIContent("Hide Power: ");
    public static readonly GUIContent aOStrength = new GUIContent("AO Strength: ");
    public static readonly GUIContent useLODGUI = new GUIContent("Use LOD: ");

    #endregion

    #region MaterialProperty

    protected MaterialProperty leaves_BaseColorProp { get; set; }
    protected MaterialProperty leaves_SecondColorProp { get; set; }
    protected MaterialProperty leaves_MainTextureProp { get; set; }
    protected MaterialProperty leaves_RadiusAndTransProp { get; set; }
    protected MaterialProperty leaves_TransProp { get; set; }
    protected MaterialProperty leaves_WindsProp { get; set; }
    protected MaterialProperty leaves_HidePowerProp { get; set; }
    protected MaterialProperty leaves_AOStrength { get; set; }
    protected MaterialProperty leaves_UseLOD { get; set; }

    #endregion

    public override void MaterialChanged(Material material) {
        SetMaterialKeywords(material);
    }


    public override void FindProperties(MaterialProperty[] properties) {
        //Debug.Log("FindProperties");
        leaves_BaseColorProp = FindProperty("_BaseColor", properties, false);
        leaves_SecondColorProp = FindProperty("_SecondColor", properties, false);
        leaves_MainTextureProp = FindProperty("_MainTexture", properties, false);
        leaves_WindsProp = FindProperty("_WindSpeed_WindWavesScale_WindForce_Cutoff", properties, false);
        leaves_RadiusAndTransProp = FindProperty("_Radius_TransNormal_TransScattering_TransDirect", properties, false);
        leaves_TransProp = FindProperty("_TransAmbient_TransStrength_LightEffect", properties, false);
        leaves_HidePowerProp = FindProperty("_HidePower", properties, false);
        leaves_AOStrength = FindProperty("_AOStrength", properties, false);
        leaves_UseLOD = FindProperty("_USE_LOD", properties, false);

    }

    private void SetKeyword(Material material, string keyword, bool value) {
        if (value) {
            material.EnableKeyword(keyword);
        } else {
            material.DisableKeyword(keyword);
        }
    }

    private void SetMaterialKeywords(Material material) {
        // Reset
        material.shaderKeywords = null;

        // MeshBlend
        //SetKeyword(material, "_USE_VIEW_FADE_RANGE", material.GetFloat("_ViewFade") == 1.0);

        // useLOD
        if (material.HasProperty("_USE_LOD")) {
            CoreUtils.SetKeyword(material, "_USE_LOD_ON", material.GetFloat("_USE_LOD") == 1.0f);
        }
    }

    public override void DrawSurfaceOptions(Material material) {
        //Debug.Log("DrawSurfaceOptions");
    }

    public override void DrawSurfaceInputs(Material material) {
        //Debug.Log("DrawSurfaceInputs");
        DrawColorProperties(material);
        DrawViewFadeProperties(material);
        DrawWindProperties(material);
        DrawRadiusAndTransProperties(material);
        DrawTransProperties(material);
        DrawUseLODProperty(material);
    }

    public override void DrawAdvancedOptions(Material material) {
        //Debug.Log("DrawAdvancedOptions");
    }

    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader) {
        //Debug.Log("AssignNewShaderToMaterial");
        MaterialChanged(material);
    }

    public void DrawColorProperties(Material material) {
        if (leaves_BaseColorProp != null && leaves_SecondColorProp != null) {
            materialEditor.ColorProperty(leaves_BaseColorProp, "Color1: ");
            materialEditor.ColorProperty(leaves_SecondColorProp, "Color2: ");
        }

        if (leaves_MainTextureProp != null) {
            materialEditor.TexturePropertySingleLine(mainTextureGUI, leaves_MainTextureProp);
        }
    }

    public void DrawUseLODProperty(Material material) {
        //materialEditor.ShaderProperty(leaves_UseLOD, useLOD);
        if (leaves_UseLOD != null) {
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = leaves_UseLOD.hasMixedValue;
            var useLOD = EditorGUILayout.Toggle(useLODGUI, leaves_UseLOD.floatValue == 1.0f);
            if (EditorGUI.EndChangeCheck()) {
                leaves_UseLOD.floatValue = useLOD ? 1.0f : 0.0f;
            }
            EditorGUI.showMixedValue = false;
        }
    }

    /*
    public void DrawRadiusProperty(Material material)
    {
        if (leaves_RadiusProp != null)
        {
            materialEditor.RangeProperty(leaves_RadiusProp, "Radius: ");
        }
    }
    */
    public void DrawViewFadeProperties(Material material) {
        materialEditor.ShaderProperty(leaves_HidePowerProp, hidePower);
        EditorGUI.BeginChangeCheck();
        leaves_AOStrength.floatValue = EditorGUI.Slider(EditorGUILayout.GetControlRect(), aOStrength,
            leaves_AOStrength.floatValue, 0.0f, 1.0f);
        if (EditorGUI.EndChangeCheck()) {
            materialEditor.RegisterPropertyChangeUndo(leaves_AOStrength.displayName);
            //leaves_WindsProp.vectorValue = windPropertyValues;
        }
    }

    public void DrawWindProperties(Material material) {
        if (leaves_WindsProp != null) {
            Vector4 windPropertyValues = leaves_WindsProp.vectorValue;
            //Rect rect = EditorGUILayout.GetControlRect();
            EditorGUI.BeginChangeCheck();
            windPropertyValues.w = EditorGUI.Slider(EditorGUILayout.GetControlRect(), cutOffGUI, windPropertyValues.w,
                0.0f, 1.0f);
            windPropertyValues.x = EditorGUI.Slider(EditorGUILayout.GetControlRect(), windSpeedGUI,
                windPropertyValues.x, 0.0f, 2.0f);
            windPropertyValues.y = EditorGUI.Slider(EditorGUILayout.GetControlRect(), windWaveScaleGUI,
                windPropertyValues.y, 0.0f, 1.0f);
            windPropertyValues.z = EditorGUI.Slider(EditorGUILayout.GetControlRect(), windForceGUI,
                windPropertyValues.z, 0.0f, 2.0f);

            leaves_WindsProp.vectorValue = windPropertyValues;
            if (EditorGUI.EndChangeCheck()) {
                materialEditor.RegisterPropertyChangeUndo(leaves_WindsProp.displayName);
                //leaves_WindsProp.vectorValue = windPropertyValues;
            }
        }
    }

    public void DrawRadiusAndTransProperties(Material material) {
        if (leaves_RadiusAndTransProp != null) {
            Vector4 temp = leaves_RadiusAndTransProp.vectorValue;
            //Rect rect = EditorGUILayout.GetControlRect();
            EditorGUI.BeginChangeCheck();
            temp.x = EditorGUI.Slider(EditorGUILayout.GetControlRect(), radiusGUI, temp.x, 0.01f, 100.0f);
            temp.y = EditorGUI.Slider(EditorGUILayout.GetControlRect(), transNormalGUI, temp.y, 0.0f, 1.0f);
            temp.z = EditorGUI.Slider(EditorGUILayout.GetControlRect(), transScatteringGUI, temp.z, 1.0f, 50.0f);
            temp.w = EditorGUI.Slider(EditorGUILayout.GetControlRect(), transDirectGUI, temp.w, 0.0f, 1.0f);

            leaves_RadiusAndTransProp.vectorValue = temp;
            if (EditorGUI.EndChangeCheck()) {
                materialEditor.RegisterPropertyChangeUndo(leaves_RadiusAndTransProp.displayName);
                //leaves_WindsProp.vectorValue = windPropertyValues;
            }
        }
    }

    public void DrawTransProperties(Material material) {
        if (leaves_TransProp != null) {
            Vector4 temp = leaves_TransProp.vectorValue;
            //Rect rect = EditorGUILayout.GetControlRect();
            EditorGUI.BeginChangeCheck();
            temp.x = EditorGUI.Slider(EditorGUILayout.GetControlRect(), transAmbientGUI, temp.x, 0.0f, 1.0f);
            temp.y = EditorGUI.Slider(EditorGUILayout.GetControlRect(), transStrengthGUI, temp.y, 0.0f, 10.0f);
            temp.z = EditorGUI.Slider(EditorGUILayout.GetControlRect(), lightEffectGUI, temp.z, 0.0f, 2.0f);

            leaves_TransProp.vectorValue = temp;
            if (EditorGUI.EndChangeCheck()) {
                materialEditor.RegisterPropertyChangeUndo(leaves_TransProp.displayName);
                //leaves_WindsProp.vectorValue = windPropertyValues;
            }
        }
    }
}