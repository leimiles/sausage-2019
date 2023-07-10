using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CreateAssetMenu(fileName = "Data", menuName = "InstanceDrawer/Data", order = 1)]
public class TransformRecorder : ScriptableObject {
    public TextAsset text;
    public Mesh instanceMesh;
    public bool[] shadowStates;
    public Material[] materials;
    [HideInInspector]
    public List<Matrix4x4> transformInfo;
}
