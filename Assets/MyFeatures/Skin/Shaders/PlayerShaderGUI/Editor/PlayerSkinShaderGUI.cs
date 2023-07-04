using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;


public class PlayerSkinShaderGUI : ShaderGUI {
    MaterialEditor materialEditor { get; set; }
    MaterialProperty[] properties { get; set; }
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties) {
        //base.OnGUI(materialEditor, properties);
        this.materialEditor = materialEditor;
        this.properties = properties;
        EditorGUILayout.LabelField("Player Shader", EditorStyles.boldLabel);
        EditorGUILayout.Space();
    }
}
