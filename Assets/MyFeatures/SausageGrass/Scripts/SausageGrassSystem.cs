using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using System.Collections.Generic;
using System.Collections;

// 基于生成网格的草地批渲染方案
namespace SoFunny.Miles {

    // 定义生成顶点的属性
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    public struct VertexAttribute {
        public Vector3 position;
        public Vector3 normal;
        public Vector2 uv;
        public Vector3 color;
    }

    // 定义草地绘制参数
    [System.Serializable]
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    public class GrassPaintingArg {
        public Vector3 position;
        public Color color;
        public Vector3 normal;
        public Vector2 length;
    }

    [ExecuteInEditMode]
    [DisallowMultipleComponent]
    public class SausageGrassSystem : MonoBehaviour {
        public SausageGrassSystemSettings m_SausageGrassSystemSettings;
        public List<VertexAttribute> m_VertexAttributes_Empty = new List<VertexAttribute>();
        [SerializeField, HideInInspector] List<GrassPaintingArg> m_GrassPaintingArgs = new List<GrassPaintingArg>();
        [SerializeField] Material m_InstantiatedMaterial;
        [HideInInspector] public Material m_Material = default;
        [HideInInspector] public ComputeShader m_ComputeShader = default;
        const int VERTEX_STRIDE = sizeof(float) * (3 + 3 + 2 + 3);      // 由 VertexAttribute 长度确定
        const int DRAW_STRIDE = sizeof(float) * (3 + ((3 + 2 + 3) * 3));
        const int INDIRECT_ARGS_STRIDE = sizeof(int) * 4;
        SausageGrassSystemShaderInteract[] interactors;
        Bounds bounds;
        int m_KernelID;
        uint threadGroupSize;
        bool m_Initialized;
        Camera m_MainCamera;
        Plane[] m_FrustumPlanes;
        ComputeShader m_InstantiatedComputeShader;
        ComputeBuffer m_VerticesBuffer;
        ComputeBuffer m_DrawBuffer;
        ComputeBuffer m_ArgsBuffer;
        SausageGrassSystemCullingTreeNode cullingTreeNode;
        List<SausageGrassSystemCullingTreeNode> leaves = new List<SausageGrassSystemCullingTreeNode>();

#if UNITY_EDITOR
        SceneView sceneView;
        void OnScene(SceneView sceneView) {
            this.sceneView = sceneView;
            if (!Application.isPlaying) {
                if (this.sceneView.camera != null) {
                    m_MainCamera = this.sceneView.camera;
                }
            } else {
                m_MainCamera = Camera.main;
            }
        }
#endif

        void OnEnable() {
            if (m_Initialized) {
                OnDisable();
            }
#if UNITY_EDITOR
            SceneView.duringSceneGui += this.OnScene;
            if (!Application.isPlaying) {
                if (sceneView != null) {
                    m_MainCamera = sceneView.camera;
                }
            }

#endif
            if (Application.isPlaying) {
                m_MainCamera = Camera.main;
            }

            m_VertexAttributes_Empty.Clear();
            for (int i = 0; i < m_GrassPaintingArgs.Count; i++) {
                m_VertexAttributes_Empty.Add(new VertexAttribute());
            }

            if (m_SausageGrassSystemSettings) {
                m_Material = m_SausageGrassSystemSettings.material;
            }

            if (m_GrassPaintingArgs.Count == 0 || m_ComputeShader == null || m_Material == null) {
                Debug.Log("nope, not ready.");
                return;
            }

            m_Initialized = true;
            Debug.Log("yep, ready.");

            // 创建 compute shader 用户生成草地网格
            m_InstantiatedComputeShader = Instantiate(m_ComputeShader);
            // 创建 material 用于渲染草地网格
            m_InstantiatedMaterial = Instantiate(m_Material);

            m_FrustumPlanes = new Plane[6];

            // 基于绘制参数构建顶点数据
            VertexAttribute[] vertices = new VertexAttribute[m_GrassPaintingArgs.Count];
            for (int i = 0; i < vertices.Length; i++) {
                vertices[i] = new VertexAttribute() {
                    position = m_GrassPaintingArgs[i].position,
                    normal = m_GrassPaintingArgs[i].normal,
                    uv = m_GrassPaintingArgs[i].length,
                    color = new Vector3(m_GrassPaintingArgs[i].color.r, m_GrassPaintingArgs[i].color.g, m_GrassPaintingArgs[i].color.b)
                };
            }

            // 顶点数量
            int numSourceVertexAttributes = m_GrassPaintingArgs.Count;
            // 每个顶点生成的面片上限
            int maxBladesPerVertex = Mathf.Max(1, m_SausageGrassSystemSettings.maxBladesPerVertex);
            // 每个面片的分段上限
            int maxSegmentsPerBlade = Mathf.Max(1, m_SausageGrassSystemSettings.maxSegmentsPerBlade);
            // 每个面片的三角形上限
            int maxBladeTriangles = maxBladesPerVertex * (((maxSegmentsPerBlade - 1) * 2) + 1);
            // 构建 compute buffer，描述顶点个数，以及每个顶点的长度
            m_VerticesBuffer = new ComputeBuffer(numSourceVertexAttributes, VERTEX_STRIDE, ComputeBufferType.Structured, ComputeBufferMode.Immutable);
            m_DrawBuffer = new ComputeBuffer(numSourceVertexAttributes * maxBladeTriangles, DRAW_STRIDE, ComputeBufferType.Append);
            m_DrawBuffer.SetCounterValue(0);
            m_ArgsBuffer = new ComputeBuffer(1, INDIRECT_ARGS_STRIDE, ComputeBufferType.IndirectArguments);
            m_KernelID = m_InstantiatedComputeShader.FindKernel("CSMain");

            // set buffer
            m_InstantiatedComputeShader.SetBuffer(m_KernelID, Shader.PropertyToID("_VertexAttributes"), m_VerticesBuffer);
            m_InstantiatedComputeShader.SetBuffer(m_KernelID, Shader.PropertyToID("_Triangles"), m_DrawBuffer);
            m_InstantiatedComputeShader.SetBuffer(m_KernelID, Shader.PropertyToID("_IndirectArgsBuffer"), m_ArgsBuffer);

            m_InstantiatedComputeShader.SetInt(Shader.PropertyToID("_NumSourceVertices"), numSourceVertexAttributes);
            m_InstantiatedComputeShader.SetInt(Shader.PropertyToID("_MaxBladesPerVertex"), m_SausageGrassSystemSettings.maxBladesPerVertex);
            m_InstantiatedComputeShader.SetInt(Shader.PropertyToID("_MaxSegmentsPerBlade"), m_SausageGrassSystemSettings.maxSegmentsPerBlade);

            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_MinHeight"), m_SausageGrassSystemSettings.MinHeight);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_MaxHeight"), m_SausageGrassSystemSettings.MaxHeight);

            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_MinWidth"), m_SausageGrassSystemSettings.MinWidth);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_MaxWidth"), m_SausageGrassSystemSettings.MaxWidth);

            m_InstantiatedMaterial.SetBuffer(Shader.PropertyToID("_DrawTriangles"), m_DrawBuffer);
            // 该函数其他输出可以忽略
            m_InstantiatedComputeShader.GetKernelThreadGroupSizes(m_KernelID, out threadGroupSize, out _, out _);
            bounds = new Bounds(m_GrassPaintingArgs[0].position, Vector3.one);

            for (int i = 0; i < m_GrassPaintingArgs.Count; i++) {
                Vector3 target = m_GrassPaintingArgs[i].position;
                bounds.Encapsulate(target);
            }

            SetupGrassDataBase();
            SetupQuadTree();

        }

        void SetupQuadTree() {
            cullingTreeNode = new SausageGrassSystemCullingTreeNode(bounds, m_SausageGrassSystemSettings.cullingTreeDepth);
            cullingTreeNode.RetrieveAllLeaves(leaves);
            for (int i = 0; i < m_GrassPaintingArgs.Count; i++) {
                cullingTreeNode.FindLeaf(m_GrassPaintingArgs[i]);
            }
            cullingTreeNode.ClearEmpty();
        }

        // compute shader 参数避免每帧更新
        void SetupGrassDataBase() {
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_Time"), Time.time);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_GrassRandomHeightMin"), m_SausageGrassSystemSettings.grassRandomHeightMin);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_GrassRandomHeightMax"), m_SausageGrassSystemSettings.grassRandomHeightMax);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_WindSpeed"), m_SausageGrassSystemSettings.windSpeed);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_WindStrength"), m_SausageGrassSystemSettings.windStrength);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_InteractorStrength"), m_SausageGrassSystemSettings.affectStrength);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_BladeRadius"), m_SausageGrassSystemSettings.bladeRadius);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_BladeForward"), m_SausageGrassSystemSettings.bladeForwardAmount);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_BladeCurve"), Mathf.Max(0, m_SausageGrassSystemSettings.bladeCurveAmount));
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_BottomWidth"), m_SausageGrassSystemSettings.bottomWidth);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_MinFadeDist"), m_SausageGrassSystemSettings.minFadeDistance);
            m_InstantiatedComputeShader.SetFloat(Shader.PropertyToID("_MaxFadeDist"), m_SausageGrassSystemSettings.maxDrawDistance);
            interactors = (SausageGrassSystemShaderInteract[])FindObjectsOfType(typeof(SausageGrassSystemShaderInteract));
            m_InstantiatedMaterial.SetColor(Shader.PropertyToID("_TopTint"), m_SausageGrassSystemSettings.topTint);
            m_InstantiatedMaterial.SetColor(Shader.PropertyToID("_BottomTint"), m_SausageGrassSystemSettings.bottomTint);
        }

        public void Reset() {
            OnDisable();
            OnEnable();
        }

        void OnDisable() {

        }

    }
}
