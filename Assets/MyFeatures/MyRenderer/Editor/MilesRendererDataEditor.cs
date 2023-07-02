using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;
using UnityEditor;
using UnityEditor.Rendering.Universal;

[CustomEditor(typeof(MilesRendererData), true)]
public class MilesRendererDataEditor : ScriptableRendererDataEditor {
    SerializedProperty m_ShaderResources;

    private void OnEnable() {
        m_ShaderResources = serializedObject.FindProperty("shaderResources");
    }

    public override void OnInspectorGUI() {
        serializedObject.Update();
        serializedObject.ApplyModifiedProperties();

        //base.OnInspectorGUI();

        EditorGUILayout.Space();
        EditorGUILayout.PropertyField(m_ShaderResources, true);

    }
}
