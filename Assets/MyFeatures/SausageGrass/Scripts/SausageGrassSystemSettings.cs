using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace SoFunny.Miles {
    [System.Serializable]
    [CreateAssetMenu(fileName = "SausageGrassSystemSettings", menuName = "Grass System/Settings")]
    public class SausageGrassSystemSettings : ScriptableObject {
        public ComputeShader computeShader;
        public Material material;
        [SerializeField][Range(0, 5)] public float grassRandomHeightMin = 0.2f;
        [SerializeField][Range(0, 5)] public float grassRandomHeightMax = 0.25f;
        [SerializeField][Range(0, 1)] public float bladeRadius = 0.2f;
        [SerializeField][Range(0, 1)] public float bladeForwardAmount = 0.38f;
        [SerializeField][Range(1, 5)] public float bladeCurveAmount = 2;
        [SerializeField][Range(1, 5)] public int maxBladesPerVertex = 4;
        [SerializeField][Range(1, 5)] public int maxSegmentsPerBlade = 3;
        [SerializeField][Range(0, 1)] public float bottomWidth = 0.1f;
        [SerializeField][Range(0.01f, 1)] public float MinWidth = 0.2f;
        [SerializeField][Range(0.01f, 1)] public float MaxWidth = 0.2f;
        [SerializeField][Range(0.01f, 1)] public float MinHeight = 0.2f;
        [SerializeField][Range(0.01f, 1)] public float MaxHeight = 0.2f;
        [SerializeField] public float windSpeed = 10;
        [SerializeField] public float windStrength = 0.05f;
        [SerializeField] public float affectStrength = 1;
        [SerializeField] public Color topTint = Color.white;
        [SerializeField] public Color bottomTint = Color.blue;
        [SerializeField] public float minFadeDistance = 40;

        [SerializeField] public float maxDrawDistance = 125;
        [SerializeField] public int cullingTreeDepth = 1;
    }
}
