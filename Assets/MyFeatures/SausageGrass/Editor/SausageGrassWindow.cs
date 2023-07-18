using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using UnityEditorInternal;
using Unity.Burst;
using Unity.Jobs;
using Unity.Collections;
namespace SoFunny.Miles {
    public class SausageGrassWindow : EditorWindow {
        public SausageGrassSystemSettings m_SausageGrassSystemSettings;
        public List<GrassPaintingArg> m_GrassPaintingArgs = new List<GrassPaintingArg>();
        public float m_BrushSize = 4.0f;
        [HideInInspector] public int m_GrassQuantity = 0;
        [HideInInspector] public LayerMask m_HitMask = 1;
        [HideInInspector] public LayerMask m_PaintMask = 1;
        [HideInInspector] public float m_BrushSizeFalloff = 0.5f;
        [HideInInspector] int m_ToolbarIndex = 0;
        [HideInInspector] float m_NormalLimit = 1.0f;
        [HideInInspector] float m_Density = 1.0f;
        [HideInInspector] float m_GrassWidth = 1.0f;
        [HideInInspector] float m_GrassLength = 1.0f;
        [HideInInspector] public Color m_GrassColor = Color.green;
        [HideInInspector] float m_ColorRangeR;
        [HideInInspector] float m_ColorRangeG;
        [HideInInspector] float m_ColorRangeB;
        [SerializeField] GameObject m_SausageGrassSystemObj;
        readonly string[] m_MainTabStrings = { "Paint/Edit", "Temp1", "Temp2" };
        readonly string[] m_ToolbarStrings = { "Add", "Remove", "Edit", "Reproject" };
        Vector2 m_ScrollPosition;
        int m_MainTabCurrent;
        bool m_IsPaintingModeActive;
        Ray m_Ray;
        RaycastHit m_RaycastHit;
        Vector3 m_MousePosition;
        Vector3 m_HitPosition;
        Vector3 m_HitPositionCached;
        Vector3 m_HitNormal;
        Vector3 m_LastPosition = Vector3.zero;
        SausageGrassSystem m_SausageGrassSystem;

        [MenuItem("SausageGrass/Paint Tool")]
        static void Init() {
            // Get existing open window or if none, make a new one:
            SausageGrassWindow window = (SausageGrassWindow)EditorWindow.GetWindow(typeof(SausageGrassWindow), false, "Sausage Grass", true);
            window.titleContent = new GUIContent("Sausage Grass");
            window.Show();
        }

        void OnGUI() {
            m_ScrollPosition = EditorGUILayout.BeginScrollView(m_ScrollPosition);
            m_SausageGrassSystemSettings = (SausageGrassSystemSettings)EditorGUILayout.ObjectField("Grass Settings: ", m_SausageGrassSystemSettings, typeof(SausageGrassSystemSettings), false);
            m_SausageGrassSystemObj = (GameObject)EditorGUILayout.ObjectField("Grass System: ", m_SausageGrassSystemObj, typeof(GameObject), true);
            if (m_SausageGrassSystemObj == null) {
                m_SausageGrassSystemObj = FindObjectOfType<SausageGrassSystem>()?.gameObject;
            }

            if (m_SausageGrassSystemObj != null) {
                m_SausageGrassSystem = m_SausageGrassSystemObj.GetComponent<SausageGrassSystem>();
                if (m_SausageGrassSystem.SetGrassPaintingArgs.Count > 0) {
                    m_GrassPaintingArgs = m_SausageGrassSystem.SetGrassPaintingArgs;
                    m_GrassQuantity = m_GrassPaintingArgs.Count;
                } else {
                    m_GrassPaintingArgs.Clear();
                }
                if (m_SausageGrassSystemSettings) {
                    m_SausageGrassSystem.m_SausageGrassSystemSettings = m_SausageGrassSystemSettings;
                    m_SausageGrassSystem.m_ComputeShader = m_SausageGrassSystemSettings.computeShader;
                } else {
                    EditorGUILayout.LabelField("Grass System Setting must be set. \n Create > Grass System > Settings", GUILayout.Height(150));
                    EditorGUILayout.EndScrollView();
                    return;
                }
            } else {
                if (!m_SausageGrassSystemSettings) {
                    EditorGUILayout.LabelField("Grass System Setting must be set. \n Create > Grass System > Settings", GUILayout.Height(150));
                    EditorGUILayout.EndScrollView();
                    return;
                }
                if (GUILayout.Button("Create Grass Settings")) {
                    if (EditorUtility.DisplayDialog("Create Grass Setting", "Create A New Object?", "Yes", "No")) {
                        CreateNewGrassSettings();
                    }
                }
                EditorGUILayout.LabelField("Can't find Grass System, create a new one", EditorStyles.label);
                EditorGUILayout.EndScrollView();
                return;
            }
            EditorGUILayout.Space();
            //EditorGUILayout.LabelField("Grass Material", EditorStyles.label);
            EditorGUILayout.BeginHorizontal();
            m_SausageGrassSystemSettings.material = (Material)EditorGUILayout.ObjectField("Grass Material: ", m_SausageGrassSystemSettings.material, typeof(Material), false);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.LabelField("Grass Quantity: " + m_GrassQuantity.ToString(), EditorStyles.label);
            EditorGUILayout.BeginHorizontal();
            m_MainTabCurrent = GUILayout.Toolbar(m_MainTabCurrent, m_MainTabStrings, GUILayout.Height(30));
            EditorGUILayout.EndHorizontal();

            switch (m_MainTabCurrent) {
                case 0:
                    ShowPaintPanel();
                    break;
            }

            if (GUILayout.Button("Clear")) {
                if (EditorUtility.DisplayDialog("Clear?", "Comfirm Clear?", "Clear", "Cancel")) {
                    ClearGrass();
                }
            }

            if (GUILayout.Button("Update")) {
                m_SausageGrassSystem.Reset();
            }

            EditorGUILayout.EndScrollView();
            EditorUtility.SetDirty(m_SausageGrassSystemSettings);
        }

        void ShowPaintPanel() {
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Paint Mode:", EditorStyles.boldLabel);
            m_IsPaintingModeActive = EditorGUILayout.Toggle(m_IsPaintingModeActive);
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.LabelField("Right-Mouse-Button to paint.", EditorStyles.boldLabel);
            m_ToolbarIndex = GUILayout.Toolbar(m_ToolbarIndex, m_ToolbarStrings);

            LayerMask hitMask = EditorGUILayout.MaskField("Hit Mask: ", InternalEditorUtility.LayerMaskToConcatenatedLayersMask(m_HitMask), InternalEditorUtility.layers);
            m_HitMask = InternalEditorUtility.ConcatenatedLayersMaskToLayerMask(hitMask);
            LayerMask paintMask = EditorGUILayout.MaskField("Paint Mask: ", InternalEditorUtility.LayerMaskToConcatenatedLayersMask(m_PaintMask), InternalEditorUtility.layers);
            m_PaintMask = InternalEditorUtility.ConcatenatedLayersMaskToLayerMask(paintMask);

            EditorGUILayout.Space();
            m_BrushSize = EditorGUILayout.Slider("Brush Size: ", m_BrushSize, 0.1f, 50.0f);

            if (m_ToolbarIndex == 0) {
                m_NormalLimit = EditorGUILayout.Slider("Normal Limit: ", m_NormalLimit, 0.0f, 1.0f);
                m_Density = EditorGUILayout.Slider("Density: ", m_Density, 0.1f, 10.0f);
            }
            if (m_ToolbarIndex == 2) {
                // nope
            }
            if (m_ToolbarIndex == 0 || m_ToolbarIndex == 2) {
                EditorGUILayout.Space();
                m_GrassWidth = EditorGUILayout.Slider("Grass Width: ", m_GrassWidth, 0.01f, 2.0f);
                m_GrassLength = EditorGUILayout.Slider("Grass Length: ", m_GrassLength, 0.01f, 2.0f);
                EditorGUILayout.Space();
                m_GrassColor = EditorGUILayout.ColorField("Brush Color: ", m_GrassColor);
                m_ColorRangeR = EditorGUILayout.Slider("Red: ", m_ColorRangeR, 0.0f, 1.0f);
                m_ColorRangeG = EditorGUILayout.Slider("Green: ", m_ColorRangeG, 0.0f, 1.0f);
                m_ColorRangeB = EditorGUILayout.Slider("Blue: ", m_ColorRangeB, 0.0f, 1.0f);
            }
            EditorGUILayout.Space();
        }

        void CreateNewGrassSettings() {

        }

        void OnSceneGUI(SceneView sceneView) {
            if (m_IsPaintingModeActive) {
                DrawHandles();
            }
        }

        void DrawHandles() {
            RaycastHit hit;
            if (Physics.Raycast(m_Ray, out hit, 200.0f, m_HitMask.value)) {
                m_HitPosition = hit.point;
                m_HitNormal = hit.normal;
            }
            Color discColor1 = Color.green;
            Color discColor2 = new Color(0.0f, 0.5f, 0.0f, 0.5f);
            switch (m_ToolbarIndex) {
                case 1:
                    discColor1 = Color.red;
                    discColor2 = new Color(0.5f, 0.0f, 0.0f, 0.5f);
                    break;
                case 2:
                    discColor1 = Color.yellow;
                    discColor2 = new Color(0.5f, 0.5f, 0.0f, 0.5f);
                    Handles.color = discColor1;
                    Handles.DrawWireDisc(m_HitPosition, m_HitNormal, (m_BrushSizeFalloff * m_BrushSize));
                    Handles.color = discColor2;
                    Handles.DrawSolidDisc(m_HitPosition, m_HitNormal, (m_BrushSizeFalloff * m_BrushSize));
                    break;
                case 3:
                    discColor1 = Color.cyan;
                    discColor2 = new Color(0.0f, 0.5f, 0.5f, 0.5f);
                    break;
            }
            Handles.color = discColor1;
            Handles.DrawWireDisc(m_HitPosition, m_HitNormal, m_BrushSize);
            Handles.color = discColor2;
            Handles.DrawSolidDisc(m_HitPosition, m_HitNormal, m_BrushSize);
            if (m_HitPosition != m_HitPositionCached) {
                SceneView.RepaintAll();
                m_HitPositionCached = m_HitPosition;
            }
        }

#if UNITY_EDITOR
        void HandleUndo() {
            if (m_SausageGrassSystem != null) {
                SceneView.RepaintAll();
                m_SausageGrassSystem.Reset();
            }
        }
        void OnScene(SceneView sceneView) {
            if (this != null && m_IsPaintingModeActive) {
                Event e = Event.current;
                m_MousePosition = e.mousePosition;
                float pixelsPerPoint = EditorGUIUtility.pixelsPerPoint;
                m_MousePosition.y = sceneView.camera.pixelHeight - m_MousePosition.y * pixelsPerPoint;
                m_MousePosition.x *= pixelsPerPoint;
                m_MousePosition.z = 0;

                m_Ray = sceneView.camera.ScreenPointToRay(m_MousePosition);

                if (e.type == EventType.MouseDown && e.button == 1) {
                    switch (m_ToolbarIndex) {
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
                    switch (m_ToolbarIndex) {
                        case 0:
                            AddGrass(m_RaycastHit, e);
                            break;
                        case 1:
                            break;
                        case 2:
                            break;
                        case 3:
                            break;
                    }
                    RebuildMesh();
                }
            }
        }
        Ray GetRandomRay(Vector3 position, Vector3 normal, float radius, float falloff) {
            Vector3 vec = Vector3.zero;
            Quaternion rotation = Quaternion.LookRotation(normal, Vector3.up);
            var randomValue = Random.Range(0.0f, 2.0f * Mathf.PI);
            vec.x = Mathf.Cos(randomValue);
            vec.y = Mathf.Sin(randomValue);
            float root;
            root = Mathf.Sqrt(Random.Range(0.0f, falloff));
            vec = position + (rotation * (vec.normalized * root * radius));
            return new Ray(vec + normal, -normal);
        }
        void AddGrass(RaycastHit raycastHit, Event e) {
            if (Physics.Raycast(m_Ray, out raycastHit, 200.0f, m_HitMask.value)) {
                if ((m_PaintMask.value & (1 << raycastHit.transform.gameObject.layer)) > 0) {
                    for (int i = 0; i < m_Density * m_BrushSize; i++) {
                        if (raycastHit.normal != Vector3.zero) {
                            Ray ray = GetRandomRay(raycastHit.point, raycastHit.normal, m_BrushSize, 0.01f);
                            if (Physics.Raycast(ray, out raycastHit, 200.0f, m_HitMask.value)) {
                                if ((m_PaintMask.value & (1 << raycastHit.transform.gameObject.layer)) > 0 && raycastHit.normal.y <= (1 + m_NormalLimit) && raycastHit.normal.y >= (1 - m_NormalLimit)) {
                                    m_HitPosition = raycastHit.point;
                                    m_HitNormal = raycastHit.normal;
                                    if (i != 0) {
                                        GrassPaintingArg data = new GrassPaintingArg();
                                        data.color = new Color(m_GrassColor.r + (Random.Range(0, 1.0f) * m_ColorRangeR), m_GrassColor.g + (Random.Range(0, 1.0f) * m_ColorRangeG), m_GrassColor.b + (Random.Range(0, 1.0f) * m_ColorRangeB), 1);
                                        data.position = m_HitPosition;
                                        data.length = new Vector2(m_GrassWidth, m_GrassLength);
                                        data.normal = m_HitNormal;
                                        m_GrassPaintingArgs.Add(data);
                                    } else {
                                        if (Vector3.Distance(raycastHit.point, m_LastPosition) > m_BrushSize) {
                                            GrassPaintingArg data = new GrassPaintingArg();
                                            data.color = new Color(m_GrassColor.r + (Random.Range(0, 1.0f) * m_ColorRangeR), m_GrassColor.g + (Random.Range(0, 1.0f) * m_ColorRangeG), m_GrassColor.b + (Random.Range(0, 1.0f) * m_ColorRangeB), 1);
                                            data.position = m_HitPosition;
                                            data.length = new Vector2(m_GrassWidth, m_GrassLength);
                                            data.normal = m_HitNormal;
                                            m_GrassPaintingArgs.Add(data);
                                            if (i == 0) {
                                                m_LastPosition = m_HitPosition;
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
            Debug.Log(m_GrassPaintingArgs.Count);
        }
        void OnEnable() {
            SceneView.duringSceneGui += this.OnSceneGUI;
            SceneView.duringSceneGui += this.OnScene;
            Undo.undoRedoPerformed += this.HandleUndo;
            m_RaycastHit = new RaycastHit();
        }
        void OnDisable() {
            RemoveDelegates();
        }
        void OnDestroy() {
            RemoveDelegates();
        }
        void RemoveDelegates() {
            // 关闭窗口后，移除回调方法
            SceneView.duringSceneGui -= this.OnSceneGUI;
            SceneView.duringSceneGui -= this.OnScene;
            Undo.undoRedoPerformed -= this.HandleUndo;
        }
        void RebuildMesh() {
            m_GrassQuantity = m_GrassPaintingArgs.Count;
            m_SausageGrassSystem.Reset();
        }
        public void ClearGrass() {
            Undo.RegisterCompleteObjectUndo(this, "Cleared Grass");
            m_GrassQuantity = 0;
            m_GrassPaintingArgs.Clear();
            m_SausageGrassSystem.SetGrassPaintingArgs = m_GrassPaintingArgs;
            m_SausageGrassSystem.Reset();
        }
#endif
    }
}
