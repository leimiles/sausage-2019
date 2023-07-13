using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
[CreateAssetMenu(fileName = "Grass Tool Settings", menuName = "Utility/GrassToolSettings")]
public class SO_GrassToolSettings : ScriptableObject {
    [SerializeField] public enum VertexColorSetting { None, Red, Blue, Green };
    public ComputeShader shaderToUse;
    public Material materialToUse;
    // Blade
    [Header("Blade")]
    [SerializeField][Range(0, 5)] public float grassRandomHeightMin = 0.2f;
    [SerializeField][Range(0, 5)] public float grassRandomHeightMax = 0.25f;
    [SerializeField][Range(0, 1)] public float bladeRadius = 0.2f;
    [SerializeField][Range(0, 1)] public float bladeForwardAmount = 0.38f;
    [SerializeField][Range(1, 5)] public float bladeCurveAmount = 2;

    [SerializeField][Range(0, 1)] public float bottomWidth = 0.1f;

    [SerializeField][Range(0.01f, 1)] public float MinWidth = 0.2f;
    [SerializeField][Range(0.01f, 1)] public float MinHeight = 0.2f;

    [SerializeField][Range(0.01f, 1)] public float MaxWidth = 0.2f;
    [SerializeField][Range(0.01f, 1)] public float MaxHeight = 0.2f;


    // Wind
    [Header("Wind")]
    [SerializeField] public float windSpeed = 10;
    [SerializeField] public float windStrength = 0.05f;

    [Header("Grass")]
    [SerializeField][Range(1, 15)] public int allowedBladesPerVertex = 4;
    [SerializeField][Range(1, 5)] public int allowedSegmentsPerBlade = 5;
    // Interactor

    [Header("Interactor Strength")]
    [SerializeField] public float affectStrength = 1;

    // Material
    [Header("Material")]
    [SerializeField] public Color topTint = new Color(1, 1, 1);
    [SerializeField] public Color bottomTint = new Color(0, 0, 1);


    [Header("LOD/ Culling")]
    [SerializeField] public float minFadeDistance = 40;

    [SerializeField] public float maxDrawDistance = 125;

    [SerializeField] public bool drawBounds;
    [SerializeField] public int cullingTreeDepth = 1;

    [Header("Terrain Layer Settings")]
    [SerializeField] public float[] layerBlocking;
    [SerializeField] public bool[] layerFading;

    [Header("Vertex Color Settings")]

    [SerializeField] public VertexColorSetting VertexColorSettings;

    [SerializeField] public VertexColorSetting VertexFade;

    [Header("Other")]
    [SerializeField] public UnityEngine.Rendering.ShadowCastingMode castShadow;

    private void OnValidate() {
        if (layerBlocking.Length != 8) {
            layerBlocking = new float[8];

        }
        if (layerFading.Length != 8) {
            layerFading = new bool[8];

        }
    }

}
