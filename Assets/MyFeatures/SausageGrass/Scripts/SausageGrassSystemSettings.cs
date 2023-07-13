using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
[CreateAssetMenu(fileName = "SausageGrassSystemSettings", menuName = "Grass System/Settings")]
public class SausageGrassSystemSettings : ScriptableObject {
    public ComputeShader computeShader;
    public Material material;
    [SerializeField][Range(1, 5)] public int maxBladesPerVertex = 4;
    [SerializeField][Range(1, 5)] public int maxSegmentsPerBlade = 3;
    [SerializeField][Range(0.01f, 1)] public float MinWidth = 0.2f;
    [SerializeField][Range(0.01f, 1)] public float MaxWidth = 0.2f;
    [SerializeField][Range(0.01f, 1)] public float MinHeight = 0.2f;
    [SerializeField][Range(0.01f, 1)] public float MaxHeight = 0.2f;
}
