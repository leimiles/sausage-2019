using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using UnityEditorInternal;
using Unity.Burst;
using Unity.Jobs;
using Unity.Collections;


public class GrassPainterWindow : EditorWindow {

    // main tabs
    readonly string[] mainTabBarStrings = { "Paint/Edit", "Generate", "General Settings" };

    int mainTab_current;
    Vector2 scrollPos;

    bool paintModeActive;

    readonly string[] toolbarStrings = { "Add", "Remove", "Edit", "Reproject" };

    readonly string[] toolbarStringsEdit = { "Edit Colors", "Edit Length/Width", "Both" };

    readonly string[] imageSelect = { "1", "2", "3", "4" };



    Vector3 hitPos;
    Vector3 hitNormal;

    public SO_GrassToolSettings toolSettings;

    public int grassAmountToGenerate = 100;
    public float radius;
    // options
    [HideInInspector]
    public int toolbarInt = 0;
    [HideInInspector]
    public int toolbarIntEdit = 0;

    public Material mat;

    public List<GrassPaintedData> grassPaintedData = new List<GrassPaintedData>();

    [HideInInspector]
    public int grassAmount = 0;

    // brush settings
    [HideInInspector]
    public LayerMask paintBlockMask = 0;
    [HideInInspector]
    public LayerMask hitMask = 1;
    [HideInInspector]
    public LayerMask paintMask = 1;
    public float brushSize = 4f;
    [HideInInspector]
    public float brushFalloffSize = 0.8f;
    public float Flow;
    [HideInInspector]
    public float density = 1f;
    [HideInInspector]
    public float normalLimit = 1;

    Ray ray;

    // length/width
    [HideInInspector]
    public float sizeWidth = 1f;
    [HideInInspector]
    public float sizeLength = 1f;

    // length/width adjustments
    [HideInInspector]
    public float adjustWidth = 0f;
    [HideInInspector]
    public float adjustLength = 0f;

    public float adjustWidthMax = 2f;
    public float adjustHeightMax = 2f;

    // reproject settings
    [HideInInspector]
    public float reprojectOffset = 1f;

    // color settings
    [HideInInspector]
    public float rangeR, rangeG, rangeB;
    [HideInInspector]
    public Color AdjustedColor;

    // raycast vars
    [HideInInspector]
    public Vector3 hitPosGizmo;
    Vector3 mousePos;

    RaycastHit terrainHit;
    private int flowTimer;
    private Vector3 lastPosition = Vector3.zero;

    [SerializeField]
    GameObject grassObject;


    GrassComputeScript grassCompute;

    NativeArray<float> sizes;
    NativeArray<float> cumulativeSizes;
    NativeArray<float> total;

    Vector3 cachedPos;

    [MenuItem("Tools/Grass Tool")]
    static void Init() {
        // Get existing open window or if none, make a new one:
        GrassPainterWindow window = (GrassPainterWindow)EditorWindow.GetWindow(typeof(GrassPainterWindow), false, "Grass Tool", true);
        var icon = EditorGUIUtility.FindTexture("tree_icon");
        window.titleContent = new GUIContent("Grass Tool", icon);
        window.Show();
    }

    private void OnGUI() {
        scrollPos = EditorGUILayout.BeginScrollView(scrollPos);
        toolSettings = (SO_GrassToolSettings)EditorGUILayout.ObjectField("Tool Settings", toolSettings, typeof(SO_GrassToolSettings), false);
        grassObject = (GameObject)EditorGUILayout.ObjectField("Grass Compute Object", grassObject, typeof(GameObject), true);




        if (grassObject == null) {
            grassObject = FindObjectOfType<GrassComputeScript>()?.gameObject;
        }


        if (grassObject != null) {
            grassCompute = grassObject.GetComponent<GrassComputeScript>();


            if (grassCompute.SetGrassPaintedDataList.Count > 0) {
                grassPaintedData = grassCompute.SetGrassPaintedDataList;
                grassAmount = grassPaintedData.Count;
            } else {
                grassPaintedData.Clear();
            }


            if (toolSettings) {
                grassCompute.currentPresets = toolSettings;
                grassCompute.computeShader = toolSettings.shaderToUse;
            } else {
                EditorGUILayout.LabelField("No Tool Settings Set, create or assign one first. \n Create > Utility> GrassToolSettings", GUILayout.Height(150));
                EditorGUILayout.EndScrollView();
                return;
            }
        } else {

            if (!toolSettings) {
                EditorGUILayout.LabelField("No Tool Settings Set, create or assign one first. \n Create > Utility> GrassToolSettings", GUILayout.Height(150));
                EditorGUILayout.EndScrollView();
                return;
            }
            // create?
            if (GUILayout.Button("Create Grass Object")) {
                if (EditorUtility.DisplayDialog("Create a new Grass Object?",
                   "No Grass Object Found, create a new Object?", "Yes", "No")) {
                    CreateNewGrassObject();
                }


            }
            EditorGUILayout.LabelField("No Grass System Holder found, create a new one", EditorStyles.label);
            EditorGUILayout.EndScrollView();
            return;

        }
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Grass Material", EditorStyles.label);
        EditorGUILayout.BeginHorizontal();
        toolSettings.materialToUse = (Material)EditorGUILayout.ObjectField("Grass Material", toolSettings.materialToUse, typeof(Material), false);

        EditorGUILayout.EndHorizontal();
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Total Grass Amount: " + grassAmount.ToString(), EditorStyles.label);
        EditorGUILayout.BeginHorizontal();
        mainTab_current = GUILayout.Toolbar(mainTab_current, mainTabBarStrings, GUILayout.Height(30));
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.Space();
        EditorGUILayout.Space();

        switch (mainTab_current) {
            case 0: //paint
                ShowPaintPanel();
                break;

            case 1: // generate
                ShowGeneratePanel();
                break;

            case 2: //settings
                ShowMainSettingsPanel();
                break;
        }

        if (GUILayout.Button("Clear Mesh")) {
            if (EditorUtility.DisplayDialog("Clear Painted Mesh?",
               "Are you sure you want to clear the mesh?", "Clear", "Don't Clear")) {
                ClearMesh();
            }
        }

        if (GUILayout.Button("Manual Update")) {
            grassCompute.Reset();
        }

        EditorGUILayout.EndScrollView();
        EditorUtility.SetDirty(toolSettings);

    }

    void ShowGeneratePanel() {
        grassAmountToGenerate = EditorGUILayout.IntField("Grass Place Amount", grassAmountToGenerate);
        LayerMask tempMask0 = EditorGUILayout.MaskField("Blocking Mask", paintBlockMask, InternalEditorUtility.layers);
        paintBlockMask = InternalEditorUtility.ConcatenatedLayersMaskToLayerMask(tempMask0);

        toolSettings.VertexColorSettings = (SO_GrassToolSettings.VertexColorSetting)EditorGUILayout.EnumPopup("Block On vertex Colors", toolSettings.VertexColorSettings);
        toolSettings.VertexFade = (SO_GrassToolSettings.VertexColorSetting)EditorGUILayout.EnumPopup("Fade on Vertex Colors", toolSettings.VertexFade);

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Width and Length ", EditorStyles.boldLabel);
        sizeWidth = EditorGUILayout.Slider("Grass Width", sizeWidth, 0.01f, 2f);
        sizeLength = EditorGUILayout.Slider("Grass Length", sizeLength, 0.01f, 2f);

        EditorGUILayout.LabelField("Color", EditorStyles.boldLabel);
        AdjustedColor = EditorGUILayout.ColorField("Brush Color", AdjustedColor);
        EditorGUILayout.LabelField("Random Color Variation", EditorStyles.boldLabel);
        rangeR = EditorGUILayout.Slider("Red", rangeR, 0f, 1f);
        rangeG = EditorGUILayout.Slider("Green", rangeG, 0f, 1f);
        rangeB = EditorGUILayout.Slider("Blue", rangeB, 0f, 1f);

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Layer Settings (Cutoff Value, Fade Height Toggle)", EditorStyles.boldLabel);
        for (int i = 0; i < toolSettings.layerBlocking.Length; i++) {
            EditorGUILayout.BeginHorizontal();
            toolSettings.layerBlocking[i] = EditorGUILayout.Slider(i.ToString(), toolSettings.layerBlocking[i], 0f, 1f);
            toolSettings.layerFading[i] = EditorGUILayout.Toggle(toolSettings.layerFading[i]);
            EditorGUILayout.EndHorizontal();
        }

        Transform selection = Selection.activeTransform;

        if (GUILayout.Button("Add Positions From Mesh")) {
            if (selection == null) {
                // no object selected
            } else {
                GeneratePositions(selection.gameObject);
            }

        }
        if (GUILayout.Button("Regenerate on current Mesh (Clears Current)")) {



            if (selection == null) {
                // no object selected
                return;
            } else {
                ClearMesh();
                GeneratePositions(selection.gameObject);
            }
        }


        EditorGUILayout.Space();
    }

    void ShowPaintPanel() {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("Paint Mode:", EditorStyles.boldLabel);
        paintModeActive = EditorGUILayout.Toggle(paintModeActive);
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.LabelField("Paint Status (Right-Mouse Button to paint)", EditorStyles.boldLabel);
        toolbarInt = GUILayout.Toolbar(toolbarInt, toolbarStrings);

        EditorGUILayout.LabelField("Hit Settings", EditorStyles.boldLabel);
        LayerMask tempMask = EditorGUILayout.MaskField("Hit Mask", InternalEditorUtility.LayerMaskToConcatenatedLayersMask(hitMask), InternalEditorUtility.layers);
        hitMask = InternalEditorUtility.ConcatenatedLayersMaskToLayerMask(tempMask);
        LayerMask tempMask2 = EditorGUILayout.MaskField("Painting Mask", InternalEditorUtility.LayerMaskToConcatenatedLayersMask(paintMask), InternalEditorUtility.layers);
        paintMask = InternalEditorUtility.ConcatenatedLayersMaskToLayerMask(tempMask2);

        // GUI.color = Color.white;
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Brush Settings", EditorStyles.boldLabel);
        brushSize = EditorGUILayout.Slider("Brush Size", brushSize, 0.1f, 50f);

        if (toolbarInt == 0) {
            normalLimit = EditorGUILayout.Slider("Normal Limit", normalLimit, 0f, 1f);
            density = EditorGUILayout.Slider("Density", density, 0.1f, 10f);
        }

        if (toolbarInt == 2) {
            toolbarIntEdit = GUILayout.Toolbar(toolbarIntEdit, toolbarStringsEdit);
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Flood Options", EditorStyles.boldLabel);
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Flood Colors")) {
                FloodColor();
            }
            if (GUILayout.Button("Flood Length/Width")) {
                FloodLengthAndWidth();
            }
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.LabelField("Soft Falloff Settings", EditorStyles.boldLabel);
            brushFalloffSize = EditorGUILayout.Slider("Brush Falloff Size", brushFalloffSize, 0.01f, 1f);
            Flow = EditorGUILayout.Slider("Brush Flow", Flow, 0.1f, 10f);
        }

        if (toolbarInt == 0 || toolbarInt == 2) {
            EditorGUILayout.Space();

            if (toolbarInt == 2) {
                EditorGUILayout.LabelField("Adjust Width and Length Gradually", EditorStyles.boldLabel);
                adjustWidth = EditorGUILayout.Slider("Grass Width Adjustment", adjustWidth, -1f, 1f);
                adjustLength = EditorGUILayout.Slider("Grass Length Adjustment", adjustLength, -1f, 1f);

                adjustWidthMax = EditorGUILayout.Slider("Grass Width Adjustment Max Clamp", adjustWidthMax, 0.01f, 3f);
                adjustHeightMax = EditorGUILayout.Slider("Grass Length Adjustment Max Clamp", adjustHeightMax, 0.01f, 3f);
                EditorGUILayout.Space();
            }
            EditorGUILayout.LabelField("Width and Length ", EditorStyles.boldLabel);
            sizeWidth = EditorGUILayout.Slider("Grass Width", sizeWidth, 0.01f, 2f);
            sizeLength = EditorGUILayout.Slider("Grass Length", sizeLength, 0.01f, 2f);


            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Color", EditorStyles.boldLabel);
            AdjustedColor = EditorGUILayout.ColorField("Brush Color", AdjustedColor);
            EditorGUILayout.LabelField("Random Color Variation", EditorStyles.boldLabel);
            rangeR = EditorGUILayout.Slider("Red", rangeR, 0f, 1f);
            rangeG = EditorGUILayout.Slider("Green", rangeG, 0f, 1f);
            rangeB = EditorGUILayout.Slider("Blue", rangeB, 0f, 1f);
        }

        if (toolbarInt == 3) {
            EditorGUILayout.Space();
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Reprojection Y Offset", EditorStyles.boldLabel);

            reprojectOffset = EditorGUILayout.FloatField(reprojectOffset);
            EditorGUILayout.EndHorizontal();
        }
        EditorGUILayout.Space();
    }

    void ShowMainSettingsPanel() {
        EditorGUILayout.LabelField("Blade Mix/Max Settings", EditorStyles.boldLabel);
        toolSettings.MinWidth = EditorGUILayout.Slider("Minimum Grass Width", toolSettings.MinWidth, 0.01f, 1f);
        toolSettings.MinHeight = EditorGUILayout.Slider("Minimum Grass Height", toolSettings.MinHeight, 0.01f, 1f);
        toolSettings.MaxWidth = EditorGUILayout.Slider("Maximum Grass Width", toolSettings.MaxWidth, 0.01f, 1f);
        toolSettings.MaxHeight = EditorGUILayout.Slider("Maximum Grass Height", toolSettings.MaxHeight, 0.01f, 1f);
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Random Height/Width", EditorStyles.boldLabel);
        toolSettings.grassRandomHeightMin = EditorGUILayout.FloatField("Min Random:", toolSettings.grassRandomHeightMin);
        toolSettings.grassRandomHeightMax = EditorGUILayout.FloatField("Min Random:", toolSettings.grassRandomHeightMax);

        EditorGUILayout.MinMaxSlider("Random Grass Height", ref toolSettings.grassRandomHeightMin, ref toolSettings.grassRandomHeightMax, -5f, 5f);
        EditorGUILayout.Space();
        toolSettings.bladeRadius = EditorGUILayout.Slider("Blade Radius", toolSettings.bladeRadius, 0f, 2f);
        toolSettings.bladeForwardAmount = EditorGUILayout.Slider("Blade Forward", toolSettings.bladeForwardAmount, 0f, 2f);
        toolSettings.bladeCurveAmount = EditorGUILayout.Slider("Blade Curve", toolSettings.bladeCurveAmount, 0f, 2f);
        toolSettings.bottomWidth = EditorGUILayout.Slider("Bottom Width", toolSettings.bottomWidth, 0f, 2f);
        toolSettings.allowedBladesPerVertex = EditorGUILayout.IntSlider("Allowed Blades Per Vertex", toolSettings.allowedBladesPerVertex, 1, 15);
        toolSettings.allowedSegmentsPerBlade = EditorGUILayout.IntSlider("Allowed Segments Per Blade", toolSettings.allowedSegmentsPerBlade, 1, 5);

        EditorGUILayout.Separator();
        EditorGUILayout.LabelField("Wind Settings", EditorStyles.boldLabel);
        toolSettings.windSpeed = EditorGUILayout.Slider("Wind Speed", toolSettings.windSpeed, -2f, 2f);
        toolSettings.windStrength = EditorGUILayout.Slider("Wind Strength", toolSettings.windStrength, -2f, 2f);

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Tinting Settings", EditorStyles.boldLabel);
        toolSettings.topTint = EditorGUILayout.ColorField("Top Tint", toolSettings.topTint);
        toolSettings.bottomTint = EditorGUILayout.ColorField("Bottom Tint", toolSettings.bottomTint);

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("LOD/Culling Settings", EditorStyles.boldLabel);
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("Show Culling Bounds:", EditorStyles.boldLabel);
        toolSettings.drawBounds = EditorGUILayout.Toggle(toolSettings.drawBounds);
        EditorGUILayout.EndHorizontal();
        toolSettings.minFadeDistance = EditorGUILayout.FloatField("Min Fade Distance", toolSettings.minFadeDistance);
        toolSettings.maxDrawDistance = EditorGUILayout.FloatField("Max Draw Distance", toolSettings.maxDrawDistance);
        toolSettings.cullingTreeDepth = EditorGUILayout.IntField("Culling Tree Depth", toolSettings.cullingTreeDepth);


        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Other Settings", EditorStyles.boldLabel);
        toolSettings.affectStrength = EditorGUILayout.FloatField("Interactor Bend Strength", toolSettings.affectStrength);
        toolSettings.castShadow = (UnityEngine.Rendering.ShadowCastingMode)EditorGUILayout.EnumPopup("Shadow Settings", toolSettings.castShadow);


    }

    void CreateNewGrassObject() {
        grassObject = new GameObject();
        grassObject.name = "Grass System - Holder";
        grassCompute = grassObject.AddComponent<GrassComputeScript>();

        // setup object

        grassCompute.computeShader = toolSettings.shaderToUse;
        grassCompute.currentPresets = toolSettings;

        grassPaintedData = new List<GrassPaintedData>();
        grassCompute.SetGrassPaintedDataList = grassPaintedData;
        grassCompute.material = toolSettings.materialToUse;
    }

    void OnSceneGUI(SceneView sceneView) {
        if (paintModeActive) {
            DrawHandles();
        }
    }
    // draw the painter handles
    void DrawHandles() {

        //  Ray ray = HandleUtility.GUIPointToWorldRay(Event.current.mousePosition);
        RaycastHit hit;
        if (Physics.Raycast(ray, out hit, 200f, hitMask.value)) {
            hitPos = hit.point;
            hitNormal = hit.normal;

        }
        //base
        Color discColor = Color.green;
        Color discColor2 = new Color(0, 0.5f, 0, 0.4f);
        switch (toolbarInt) {

            case 1:
                discColor = Color.red;
                discColor2 = new Color(0.5f, 0f, 0f, 0.4f);
                break;
            case 2:
                discColor = Color.yellow;
                discColor2 = new Color(0.5f, 0.5f, 0f, 0.4f);

                Handles.color = discColor;
                Handles.DrawWireDisc(hitPos, hitNormal, (brushFalloffSize * brushSize));
                Handles.color = discColor2;
                Handles.DrawSolidDisc(hitPos, hitNormal, (brushFalloffSize * brushSize));

                break;
            case 3:
                discColor = Color.cyan;
                discColor2 = new Color(0, 0.5f, 0.5f, 0.4f);
                break;
        }


        Handles.color = discColor;
        Handles.DrawWireDisc(hitPos, hitNormal, brushSize);
        Handles.color = discColor2;
        Handles.DrawSolidDisc(hitPos, hitNormal, brushSize);

        if (hitPos != cachedPos) {
            SceneView.RepaintAll();
            cachedPos = hitPos;
        }


    }

#if UNITY_EDITOR
    public void HandleUndo() {
        if (grassCompute != null) {

            SceneView.RepaintAll();
            grassCompute.Reset();
        }
    }

    private void OnEnable() {
        SceneView.duringSceneGui += OnSceneGUI;
        SceneView.duringSceneGui += this.OnScene;
        Undo.undoRedoPerformed += this.HandleUndo;
        terrainHit = new RaycastHit();
    }

    void RemoveDelegates() {
        // When the window is destroyed, remove the delegate
        // so that it will no longer do any drawing.
        SceneView.duringSceneGui -= OnSceneGUI;
        SceneView.duringSceneGui -= this.OnScene;
        Undo.undoRedoPerformed -= this.HandleUndo;
    }

    void OnDisable() {
        RemoveDelegates();
    }

    void OnDestroy() {
        RemoveDelegates();
    }

    public void ClearMesh() {
        Undo.RegisterCompleteObjectUndo(this, "Cleared Grass");
        grassAmount = 0;
        grassPaintedData.Clear();
        grassCompute.SetGrassPaintedDataList = grassPaintedData;
        grassCompute.Reset();
    }

    public void GeneratePositions(GameObject selection) {
        Undo.RegisterCompleteObjectUndo(this, "Add new Positions from " + selection.name);
        // mesh
        if (selection.TryGetComponent(out MeshFilter sourceMesh)) {

            CalcAreas(sourceMesh.sharedMesh);
            Matrix4x4 localToWorld = sourceMesh.transform.localToWorldMatrix;

            var oTriangles = sourceMesh.sharedMesh.triangles;
            var oVertices = sourceMesh.sharedMesh.vertices;
            var oColors = sourceMesh.sharedMesh.colors;
            var oNormals = sourceMesh.sharedMesh.normals;

            var meshTriangles = new NativeArray<int>(oTriangles.Length, Allocator.Temp);
            var meshVertices = new NativeArray<Vector4>(oVertices.Length, Allocator.Temp);
            var meshColors = new NativeArray<Color>(oVertices.Length, Allocator.Temp);
            var meshNormals = new NativeArray<Vector3>(oNormals.Length, Allocator.Temp);
            for (int i = 0; i < meshTriangles.Length; i++) {
                meshTriangles[i] = oTriangles[i];
            }

            for (int i = 0; i < meshVertices.Length; i++) {
                meshVertices[i] = oVertices[i];
                meshNormals[i] = oNormals[i];
                if (oColors.Length == 0) {
                    meshColors[i] = Color.black;
                } else {
                    meshColors[i] = oColors[i];
                }

            }

            var point = new NativeArray<Vector3>(1, Allocator.Temp);

            var normals = new NativeArray<Vector3>(1, Allocator.Temp);

            var lengthWidth = new NativeArray<float>(1, Allocator.Temp);
            var job = new MyJob {
                CumulativeSizes = cumulativeSizes,
                MeshColors = meshColors,
                MeshTriangles = meshTriangles,
                MeshVertices = meshVertices,
                MeshNormals = meshNormals,
                Total = total,
                Sizes = sizes,
                Point = point,
                Normals = normals,
                VertexColorSettings = toolSettings.VertexColorSettings,
                VertexFade = toolSettings.VertexFade,
                LengthWidth = lengthWidth,
            };

            for (int j = 0; j < grassAmountToGenerate; j++) {
                job.Execute();
                GrassPaintedData newData = new GrassPaintedData();
                Vector3 newPoint = point[0];
                newData.position = localToWorld.MultiplyPoint3x4(newPoint);

                Collider[] cols = Physics.OverlapBox(newData.position, Vector3.one * 0.2f, Quaternion.identity, paintBlockMask);
                if (cols.Length > 0) {
                    newPoint = Vector3.zero;
                }
                newData.color = new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1); ;
                newData.length = new Vector2(sizeWidth, sizeLength) * lengthWidth[0];
                newData.normal = normals[0];

                if (newPoint != Vector3.zero) {
                    grassPaintedData.Add(newData);
                }

            }

            sizes.Dispose();
            cumulativeSizes.Dispose();
            total.Dispose();
            meshColors.Dispose();
            meshTriangles.Dispose();
            meshVertices.Dispose();
            meshNormals.Dispose();
            point.Dispose();
            lengthWidth.Dispose();

            RebuildMesh();
        } else if (selection.TryGetComponent(out Terrain terrain)) {
            // terrainmesh

            for (int j = 0; j < grassAmountToGenerate; j++) {
                Matrix4x4 localToWorld = terrain.transform.localToWorldMatrix;
                GrassPaintedData newData = new GrassPaintedData();
                Vector3 newPoint = Vector3.zero;
                Vector3 newNormal = Vector3.zero;
                float[,,] maps = new float[0, 0, 0];
                GetRandomPointOnTerrain(localToWorld, ref maps, terrain, terrain.terrainData.size, ref newPoint, ref newNormal);
                newData.position = newPoint;

                Collider[] cols = Physics.OverlapBox(newData.position, Vector3.one * 0.2f, Quaternion.identity, paintBlockMask);
                if (cols.Length > 0) {
                    newPoint = Vector3.zero;
                }


                float getFadeMap = 0;
                // check map layers
                for (int i = 0; i < maps.Length; i++) {
                    getFadeMap += System.Convert.ToInt32(toolSettings.layerFading[i]) * maps[0, 0, i] * 10f;
                    if (maps[0, 0, i] > toolSettings.layerBlocking[i]) {
                        newPoint = Vector3.zero;
                    }
                }




                float e = Mathf.Clamp((1 - (getFadeMap)), 0, 1f);
                newData.color = new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1); ;



                newData.length = new Vector2(sizeWidth, sizeLength * e);
                newData.normal = newNormal;
                if (newPoint != Vector3.zero) {
                    grassPaintedData.Add(newData);
                }
            }
            RebuildMesh();
        }

    }

    void GetRandomPointOnTerrain(Matrix4x4 localToWorld, ref float[,,] maps, Terrain terrain, Vector3 size, ref Vector3 point, ref Vector3 normal) {
        point = new Vector3(Random.Range(0, size.x), 0, Random.Range(0, size.z));
        // sample layers wip

        float pointSizeX = (point.x / size.x);
        float pointSizeZ = (point.z / size.z);

        Vector3 newScale2 = new Vector3(pointSizeX * terrain.terrainData.alphamapResolution, 0, pointSizeZ * terrain.terrainData.alphamapResolution);
        int terrainx = Mathf.RoundToInt(newScale2.x);
        int terrainz = Mathf.RoundToInt(newScale2.z);

        maps = terrain.terrainData.GetAlphamaps(terrainx, terrainz, 1, 1);
        normal = terrain.terrainData.GetInterpolatedNormal(pointSizeX, pointSizeZ);
        point = localToWorld.MultiplyPoint3x4(point);
        point.y = terrain.SampleHeight(point) + terrain.GetPosition().y;
    }


    public void CalcAreas(Mesh mesh) {
        sizes = GetTriSizes(mesh.triangles, mesh.vertices);
        cumulativeSizes = new NativeArray<float>(sizes.Length, Allocator.Temp);
        total = new NativeArray<float>(1, Allocator.Temp);

        for (int i = 0; i < sizes.Length; i++) {
            total[0] += sizes[i];
            cumulativeSizes[i] = total[0];
        }
    }

    // Using BurstCompile to compile a Job with burst
    // Set CompileSynchronously to true to make sure that the method will not be compiled asynchronously
    // but on the first schedule
    //[BurstCompile(CompileSynchronously = true)]
    private struct MyJob : IJob {
        [ReadOnly]
        public NativeArray<float> Sizes;

        [ReadOnly]
        public NativeArray<float> Total;

        [ReadOnly]
        public NativeArray<float> CumulativeSizes;

        [ReadOnly]
        public NativeArray<Color> MeshColors;

        [ReadOnly]
        public NativeArray<Vector4> MeshVertices;

        [ReadOnly]
        public NativeArray<Vector3> MeshNormals;

        [ReadOnly]
        public NativeArray<int> MeshTriangles;

        [WriteOnly]
        public NativeArray<Vector3> Point;

        [WriteOnly]
        public NativeArray<float> LengthWidth;

        [WriteOnly]
        public NativeArray<Vector3> Normals;

        public SO_GrassToolSettings.VertexColorSetting VertexColorSettings;


        public SO_GrassToolSettings.VertexColorSetting VertexFade;

        public void Execute() {
            float randomsample = Random.value * Total[0];
            int triIndex = -1;

            for (int i = 0; i < Sizes.Length; i++) {
                if (randomsample <= CumulativeSizes[i]) {
                    triIndex = i;
                    break;
                }
            }
            if (triIndex == -1)
                Debug.LogError("triIndex should never be -1");

            switch (VertexColorSettings) {
                case SO_GrassToolSettings.VertexColorSetting.Red:
                    if (MeshColors[MeshTriangles[triIndex * 3]].r > 0.5f) {
                        Point[0] = Vector3.zero;
                        return;
                    }
                    break;
                case SO_GrassToolSettings.VertexColorSetting.Green:
                    if (MeshColors[MeshTriangles[triIndex * 3]].g > 0.5f) {
                        Point[0] = Vector3.zero;
                        return;
                    }
                    break;
                case SO_GrassToolSettings.VertexColorSetting.Blue:
                    if (MeshColors[MeshTriangles[triIndex * 3]].b > 0.5f) {
                        Point[0] = Vector3.zero;
                        return;
                    }
                    break;
            }

            switch (VertexFade) {
                case SO_GrassToolSettings.VertexColorSetting.Red:
                    float red = MeshColors[MeshTriangles[triIndex * 3]].r;
                    float red2 = MeshColors[MeshTriangles[triIndex * 3 + 1]].r;
                    float red3 = MeshColors[MeshTriangles[triIndex * 3 + 2]].r;

                    LengthWidth[0] = 1.0f - ((red + red2 + red3) * 0.3f);
                    break;
                case SO_GrassToolSettings.VertexColorSetting.Green:
                    float green = MeshColors[MeshTriangles[triIndex * 3]].g;
                    float green2 = MeshColors[MeshTriangles[triIndex * 3 + 1]].g;
                    float green3 = MeshColors[MeshTriangles[triIndex * 3 + 2]].g;

                    LengthWidth[0] = 1.0f - ((green + green2 + green3) * 0.3f);
                    break;
                case SO_GrassToolSettings.VertexColorSetting.Blue:
                    float blue = MeshColors[MeshTriangles[triIndex * 3]].b;
                    float blue2 = MeshColors[MeshTriangles[triIndex * 3 + 1]].b;
                    float blue3 = MeshColors[MeshTriangles[triIndex * 3 + 2]].b;

                    LengthWidth[0] = 1.0f - ((blue + blue2 + blue3) * 0.3f);
                    break;
                case SO_GrassToolSettings.VertexColorSetting.None:
                    LengthWidth[0] = 1.0f;
                    break;
            }

            Vector3 a = MeshVertices[MeshTriangles[triIndex * 3]];
            Vector3 b = MeshVertices[MeshTriangles[triIndex * 3 + 1]];
            Vector3 c = MeshVertices[MeshTriangles[triIndex * 3 + 2]];

            // Generate random barycentric coordinates
            float r = Random.value;
            float s = Random.value;

            if (r + s >= 1) {
                r = 1 - r;
                s = 1 - s;
            }

            Normals[0] = MeshNormals[MeshTriangles[triIndex * 3 + 1]];

            // Turn point back to a Vector3
            Vector3 pointOnMesh = a + r * (b - a) + s * (c - a);

            Point[0] = pointOnMesh;

        }
    }

    public NativeArray<float> GetTriSizes(int[] tris, Vector3[] verts) {
        int triCount = tris.Length / 3;
        var sizes = new NativeArray<float>(triCount, Allocator.Temp);
        for (int i = 0; i < triCount; i++) {
            sizes[i] = .5f * Vector3.Cross(
                verts[tris[i * 3 + 1]] - verts[tris[i * 3]],
                verts[tris[i * 3 + 2]] - verts[tris[i * 3]]).magnitude;
        }
        return sizes;
    }

    public void FloodColor() {
        Undo.RegisterCompleteObjectUndo(this, "Flooded Color");
        for (int i = 0; i < grassPaintedData.Count; i++) {
            grassPaintedData[i].color = new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1);

        }
        RebuildMesh();
    }

    public void FloodLengthAndWidth() {
        Undo.RegisterCompleteObjectUndo(this, "Flooded Length/Width");
        for (int i = 0; i < grassPaintedData.Count; i++) {
            grassPaintedData[i].length = new Vector2(sizeWidth, sizeLength); ;

        }

        RebuildMesh();
    }

    Ray RandomRay(Vector3 position, Vector3 normal, float radius, float falloff) {
        Vector3 a = Vector3.zero;
        Quaternion rotation = Quaternion.LookRotation(normal, Vector3.up);

        var rad = Random.Range(0f, 2 * Mathf.PI);
        a.x = Mathf.Cos(rad);
        a.y = Mathf.Sin(rad);

        float r;

        //In the case the curve isn't valid, only sample within the falloff range
        r = Mathf.Sqrt(Random.Range(0f, falloff));

        a = position + (rotation * (a.normalized * r * radius));
        return new Ray(a + normal, -normal);
    }

    void OnScene(SceneView scene) {
        if (this != null && paintModeActive) {

            Event e = Event.current;
            mousePos = e.mousePosition;
            float ppp = EditorGUIUtility.pixelsPerPoint;
            mousePos.y = scene.camera.pixelHeight - mousePos.y * ppp;
            mousePos.x *= ppp;
            mousePos.z = 0;

            // ray for gizmo(disc)
            ray = scene.camera.ScreenPointToRay(mousePos);
            // undo system
            if (e.type == EventType.MouseDown && e.button == 1) {
                switch (toolbarInt) {

                    case 0:

                        Undo.RegisterCompleteObjectUndo(this, "Added Grass");
                        break;

                    case 1:
                        Undo.RegisterCompleteObjectUndo(this, "Removed Grass");
                        break;

                    case 2:
                        Undo.RegisterCompleteObjectUndo(this, "Edited Grass");
                        break;
                    case 3:
                        Undo.RegisterCompleteObjectUndo(this, "Reprojected Grass");
                        break;



                }
            }
            if (e.type == EventType.MouseDrag && e.button == 1) {
                switch (toolbarInt) {

                    case 0:
                        AddGrassPainting(terrainHit, e);

                        break;

                    case 1:
                        grassPaintedData.RemoveAll(RemovePoints);
                        e.Use();
                        break;

                    case 2:
                        EditGrassPainting(terrainHit, e);
                        break;
                    case 3:
                        ReprojectGrassPainting(terrainHit, e);
                        break;



                }
                RebuildMesh();
            }


        }
    }

    public void AddGrassPainting(RaycastHit terrainHit, Event e) {
        // if the ray hits something thats on the layer mask,  within the grass limit and within the y normal limit
        if (Physics.Raycast(ray, out terrainHit, 200f, hitMask.value)) {
            if ((paintMask.value & (1 << terrainHit.transform.gameObject.layer)) > 0) {
                for (int k = 0; k < density * brushSize; k++) {
                    if (terrainHit.normal != Vector3.zero) {


                        Ray ray2 = RandomRay(terrainHit.point, terrainHit.normal, brushSize, 0.01f);
                        if (Physics.Raycast(ray2, out terrainHit, 200f, hitMask.value)) {
                            if ((paintMask.value & (1 << terrainHit.transform.gameObject.layer)) > 0 && terrainHit.normal.y <= (1 + normalLimit) && terrainHit.normal.y >= (1 - normalLimit)) {
                                hitPos = terrainHit.point;
                                hitNormal = terrainHit.normal;

                                if (k != 0) {
                                    // can paint
                                    GrassPaintedData newData = new GrassPaintedData();
                                    newData.color = new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1);
                                    newData.position = hitPos;
                                    newData.length = new Vector2(sizeWidth, sizeLength);
                                    newData.normal = hitNormal;

                                    grassPaintedData.Add(newData);

                                } else {// to not place everything at once, check if the first placed point far enough away from the last placed first one
                                    if (Vector3.Distance(terrainHit.point, lastPosition) > brushSize) {

                                        GrassPaintedData newData = new GrassPaintedData();
                                        newData.color = new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1);
                                        newData.position = hitPos;

                                        newData.length = new Vector2(sizeWidth, sizeLength);
                                        newData.normal = hitNormal;
                                        grassPaintedData.Add(newData);


                                        if (k == 0) {
                                            lastPosition = hitPos;
                                        }
                                    }

                                }
                            }

                        }
                    }
                }
            }
        }
        e.Use();
    }

    void EditGrassPainting(RaycastHit terrainHit, Event e) {

        if (Physics.Raycast(ray, out terrainHit, 200f, hitMask.value)) {
            hitPos = terrainHit.point;
            hitPosGizmo = hitPos;
            hitNormal = terrainHit.normal;
            for (int j = 0; j < grassPaintedData.Count; j++) {
                Vector3 pos = grassPaintedData[j].position;

                //  pos += grassObject.transform.position;
                float dist = Vector3.Distance(terrainHit.point, pos);

                // if its within the radius of the brush, remove all info
                if (dist <= brushSize) {

                    float falloff = Mathf.Clamp01((dist / (brushFalloffSize * brushSize)));

                    //store the original color
                    Color OrigColor = grassPaintedData[j].color;

                    // add in the new color
                    Color newCol = (new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1));

                    Vector2 origLength = grassPaintedData[j].length;
                    Vector2 newLength = new Vector2(adjustWidth, adjustLength);


                    flowTimer++;
                    if (flowTimer > Flow) {
                        // edit colors
                        if (toolbarIntEdit == 0 || toolbarIntEdit == 2) {
                            grassPaintedData[j].color = Color.Lerp(newCol, OrigColor, falloff);
                        }
                        // edit grass length
                        if (toolbarIntEdit == 1 || toolbarIntEdit == 2) {
                            grassPaintedData[j].length = Vector2.Lerp(origLength + newLength, origLength, falloff);
                            grassPaintedData[j].length.x = Mathf.Clamp(grassPaintedData[j].length.x, 0.1f, adjustWidthMax);
                            grassPaintedData[j].length.y = Mathf.Clamp(grassPaintedData[j].length.y, 0.1f, adjustHeightMax);
                        }
                        flowTimer = 0;
                    }
                }
            }
        }
        e.Use();
    }

    void ReprojectGrassPainting(RaycastHit terrainHit, Event e) {
        if (Physics.Raycast(ray, out terrainHit, 200f, hitMask.value)) {
            hitPos = terrainHit.point;
            hitPosGizmo = hitPos;
            hitNormal = terrainHit.normal;

            for (int j = 0; j < grassPaintedData.Count; j++) {
                Vector3 pos = grassPaintedData[j].position;
                //  pos += grassObject.transform.position;
                float dist = Vector3.Distance(terrainHit.point, pos);

                // if its within the radius of the brush, raycast to a new position
                if (dist <= brushSize) {
                    RaycastHit raycastHit;
                    Vector3 meshPoint = new Vector3(pos.x, pos.y + reprojectOffset, pos.z);
                    if (Physics.Raycast(meshPoint, Vector3.down, out raycastHit, 200f, paintMask.value)) {
                        Vector3 newPoint = raycastHit.point;//- grassObject.transform.position;
                        grassPaintedData[j].position = newPoint;
                    }
                }
            }
        }
        e.Use();
    }

    private bool RemovePoints(GrassPaintedData point) {
        RaycastHit terrainHit;
        if (Physics.Raycast(ray, out terrainHit, 200f, hitMask.value)) {
            hitPos = terrainHit.point;
            hitPosGizmo = hitPos;
            hitNormal = terrainHit.normal;

            Vector3 pos = point.position;
            // pos += grassObject.transform.position;
            float dist = Vector3.Distance(terrainHit.point, pos);

            // if its within the radius of the brush, remove all info
            if (dist <= brushSize) {
                return true;
            } else {
                return false;
            }
        }
        return false;
    }

    void RebuildMesh() {
        grassAmount = grassPaintedData.Count;
        grassCompute.Reset();

    }
#endif
}

