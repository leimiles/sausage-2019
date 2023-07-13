// @Minionsart version
// credits  to  forkercat https://gist.github.com/junhaowww/fb6c030c17fe1e109a34f1c92571943f
// and  NedMakesGames https://gist.github.com/NedMakesGames/3e67fabe49e2e3363a657ef8a6a09838
// for the base setup for compute shaders
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using System.Collections.Generic;
using System.Collections;

[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind
       .Sequential)]
public struct SourceVertex {
    public Vector3 position;
    public Vector3 normal;
    public Vector2 uv;
    public Vector3 color;
}

[ExecuteInEditMode]
public class GrassComputeScript : MonoBehaviour {
    [HideInInspector] public Material material = default;
    [HideInInspector] public ComputeShader computeShader = default;

    public bool autoUpdate;// very slow
    private Camera m_MainCamera;

    public SO_GrassToolSettings currentPresets;

    ShaderInteractor[] interactors;


    // base data lists
    [SerializeField, HideInInspector]
    List<GrassPaintedData> grassPaintedDatas = new List<GrassPaintedData>();
    [SerializeField, HideInInspector]
    List<SourceVertex> grassPaintedDatasVisible = new List<SourceVertex>();

    // A state variable to help keep track of whether compute buffers have been set up
    private bool m_Initialized;
    // A compute buffer to hold vertex data of the source mesh
    private ComputeBuffer m_SourceVertBuffer;
    // A compute buffer to hold vertex data of the generated mesh
    private ComputeBuffer m_DrawBuffer;
    // A compute buffer to hold indirect draw arguments
    private ComputeBuffer m_ArgsBuffer;
    // Instantiate the shaders so data belong to their unique compute buffers
    private ComputeShader m_InstantiatedComputeShader;
    [SerializeField] Material m_InstantiatedMaterial;
    // The id of the kernel in the grass compute shader
    private int m_IdGrassKernel;
    // The x dispatch size for the grass compute shader
    private int m_DispatchSize;

    // The size of one entry in the various compute buffers
    private const int SOURCE_VERT_STRIDE = sizeof(float) * (3 + 3 + 2 + 3);
    private const int DRAW_STRIDE = sizeof(float) * (3 + ((3 + 2 + 3) * 3));
    private const int INDIRECT_ARGS_STRIDE = sizeof(int) * 4;

    Bounds bounds;
    Plane[] cameraFrustumPlanes;

    // The data to reset the args buffer with every frame
    // 0: vertex count per draw instance. We will only use one instance
    // 1: instance count. One
    // 2: start vertex location if using a Graphics Buffer
    // 3: and start instance location if using a Graphics Buffer
    private int[] argsBufferReset = new int[] { 1, 1, 0, 0 };


    // quadtreedata ----------------------------------------------------------------------
    CullingTreeNode cullingTree;
    List<Bounds> BoundsListVis = new List<Bounds>();
    List<CullingTreeNode> leaves = new List<CullingTreeNode>();
    uint threadGroupSize;
    float cameraOriginalFarPlane;
    public List<SourceVertex> empty = new List<SourceVertex>();

    ///-------------------------------------------------------------------------------------

#if UNITY_EDITOR
    SceneView view;

    public List<GrassPaintedData> SetGrassPaintedDataList {
        get { return grassPaintedDatas; }
        set { grassPaintedDatas = value; }
    }

    // get the scene camera in case of no maincam
    void OnFocus() {
        // Remove delegate listener if it has previously
        // been assigned.
        SceneView.duringSceneGui -= this.OnScene;
        // Add (or re-add) the delegate.
        SceneView.duringSceneGui += this.OnScene;
    }

    void OnDestroy() {
        // When the window is destroyed, remove the delegate
        // so that it will no longer do any drawing.
        SceneView.duringSceneGui -= this.OnScene;
    }

    void OnScene(SceneView scene) {
        view = scene;
        if (!Application.isPlaying) {
            if (view.camera != null) {
                m_MainCamera = view.camera;
            }
        } else {
            m_MainCamera = Camera.main;
        }
    }


    private void OnValidate() {
        // Set up components
        if (!Application.isPlaying) {
            if (view != null) {
                m_MainCamera = view.camera;
            }
        } else {
            m_MainCamera = Camera.main;
        }
    }
#endif

    private void OnEnable() {
        // If initialized, call on disable to clean things up
        if (m_Initialized) {
            OnDisable();
        }
#if UNITY_EDITOR
        SceneView.duringSceneGui += this.OnScene;

        if (!Application.isPlaying) {
            if (view != null) {
                m_MainCamera = view.camera;
            }

        }
#endif
        if (Application.isPlaying) {
            m_MainCamera = Camera.main;
        }

        // empty array to replace the visible grass with
        empty.Clear();
        for (int i = 0; i < grassPaintedDatas.Count; i++) {
            empty.Add(new SourceVertex());
        }



        // Setup compute shader and material manually
        if (currentPresets) {
            material = currentPresets.materialToUse;
        }

        // Don't do anything if resources are not found,
        // or no vertex is put on the mesh.
        if (grassPaintedDatas.Count == 0 || computeShader == null || material == null) {
            return;
        }

        m_Initialized = true;

        // Instantiate the shaders so they can point to their own buffers
        m_InstantiatedComputeShader = Instantiate(computeShader);
        m_InstantiatedMaterial = Instantiate(material);

        cameraFrustumPlanes = new Plane[6];

        // Create the data to upload to the source vert buffer
        SourceVertex[] vertices = new SourceVertex[grassPaintedDatas.Count];
        for (int i = 0; i < vertices.Length; i++) {
            vertices[i] = new SourceVertex() {
                position = grassPaintedDatas[i].position,
                normal = grassPaintedDatas[i].normal,
                uv = grassPaintedDatas[i].length,
                color = new Vector3(grassPaintedDatas[i].color.r, grassPaintedDatas[i].color.g, grassPaintedDatas[i].color.b) // Color --> Vector3
            };
        }


        int numSourceVertices = grassPaintedDatas.Count;

        // amount of segmets
        int maxBladesPerVertex = Mathf.Max(1, currentPresets.allowedBladesPerVertex);
        int maxSegmentsPerBlade = Mathf.Max(1, currentPresets.allowedSegmentsPerBlade);
        // -1 is because the top part of the grass only has 1 triangle
        int maxBladeTriangles = maxBladesPerVertex * (((maxSegmentsPerBlade - 1) * 2) + 1);

        // Create compute buffers

        // The stride is the size, in bytes, each object in the buffer takes up
        m_SourceVertBuffer = new ComputeBuffer(numSourceVertices, SOURCE_VERT_STRIDE,
            ComputeBufferType.Structured, ComputeBufferMode.Immutable);

        m_DrawBuffer = new ComputeBuffer(numSourceVertices * maxBladeTriangles, DRAW_STRIDE,
            ComputeBufferType.Append);
        m_DrawBuffer.SetCounterValue(0);

        m_ArgsBuffer =
            new ComputeBuffer(1, INDIRECT_ARGS_STRIDE, ComputeBufferType.IndirectArguments);

        // Cache the kernel IDs we will be dispatching
        m_IdGrassKernel = m_InstantiatedComputeShader.FindKernel("Main");


        // Set buffer data
        m_InstantiatedComputeShader.SetBuffer(m_IdGrassKernel, "_SourceVertices",
            m_SourceVertBuffer);
        m_InstantiatedComputeShader.SetBuffer(m_IdGrassKernel, "_DrawTriangles", m_DrawBuffer);
        m_InstantiatedComputeShader.SetBuffer(m_IdGrassKernel, "_IndirectArgsBuffer",
            m_ArgsBuffer);

        // Set vertex data
        m_InstantiatedComputeShader.SetInt("_NumSourceVertices", numSourceVertices);
        m_InstantiatedComputeShader.SetInt("_MaxBladesPerVertex", currentPresets.allowedBladesPerVertex);
        m_InstantiatedComputeShader.SetInt("_MaxSegmentsPerBlade", currentPresets.allowedSegmentsPerBlade);

        m_InstantiatedComputeShader.SetFloat("_MinHeight", currentPresets.MinHeight);
        m_InstantiatedComputeShader.SetFloat("_MinWidth", currentPresets.MinWidth);

        m_InstantiatedComputeShader.SetFloat("_MaxHeight", currentPresets.MaxHeight);
        m_InstantiatedComputeShader.SetFloat("_MaxWidth", currentPresets.MaxWidth);
        m_InstantiatedMaterial.SetBuffer("_DrawTriangles", m_DrawBuffer);





        // Calculate the number of threads to use. Get the thread size from the kernel
        // Then, divide the number of triangles by that size
        m_InstantiatedComputeShader.GetKernelThreadGroupSizes(m_IdGrassKernel,
            out threadGroupSize, out _, out _);
        //set once only


        // Get the bounds of the source mesh and then expand by the maximum blade width and height
        bounds = new Bounds(grassPaintedDatas[0].position, Vector3.one);

        for (int i = 0; i < grassPaintedDatas.Count; i++) {
            Vector3 target = grassPaintedDatas[i].position;

            bounds.Encapsulate(target);
        }
        SetGrassDataBase();
        SetupQuadTree();
    }

    void SetupQuadTree() {
        cullingTree = new CullingTreeNode(bounds, currentPresets.cullingTreeDepth);
        cullingTree.RetrieveAllLeaves(leaves);

        //binning, put each posWS into the correct cell
        for (int i = 0; i < grassPaintedDatas.Count; i++) {
            cullingTree.FindLeaf(grassPaintedDatas[i]);
        }
        cullingTree.ClearEmpty();
    }


    void GetFrustomData() {
        if (m_MainCamera == null) {
            return;
        }
        cameraOriginalFarPlane = m_MainCamera.farClipPlane;
        m_MainCamera.farClipPlane = currentPresets.maxDrawDistance;//allow drawDistance control    
        GeometryUtility.CalculateFrustumPlanes(m_MainCamera, cameraFrustumPlanes);

        m_MainCamera.farClipPlane = cameraOriginalFarPlane;//revert far plane edit

        BoundsListVis.Clear();
        grassPaintedDatasVisible.Clear();

        m_SourceVertBuffer.SetData(empty);

        cullingTree.RetrieveLeaves(cameraFrustumPlanes, BoundsListVis, grassPaintedDatasVisible);


        m_SourceVertBuffer.SetData(grassPaintedDatasVisible);
    }

    private void OnDisable() {
        // Dispose of buffers and copied shaders here
        if (m_Initialized) {
            // If the application is not in play mode, we have to call DestroyImmediate
            if (Application.isPlaying) {
                Destroy(m_InstantiatedComputeShader);
                Destroy(m_InstantiatedMaterial);
            } else {
                DestroyImmediate(m_InstantiatedComputeShader);
                DestroyImmediate(m_InstantiatedMaterial);
            }
            // Release each buffer
            m_SourceVertBuffer?.Release();
            m_DrawBuffer?.Release();
            m_ArgsBuffer?.Release();
            grassPaintedDatasVisible.Clear();
        }
        m_Initialized = false;
    }

    // LateUpdate is called after all Update calls
    private void LateUpdate() {
        // If in edit mode, we need to update the shaders each Update to make sure settings changes are applied
        // Don't worry, in edit mode, Update isn't called each frame
        if (Application.isPlaying == false && autoUpdate) {
            OnDisable();
            OnEnable();
        }

        // If not initialized, do nothing (creating zero-length buffer will crash)
        if (!m_Initialized) {
            // Initialization is not done, please check if there are null components
            // or just because there is not vertex being painted.
            return;
        }
        // get the data from the camera for culling
        GetFrustomData();

        // Update the shader with frame specific data
        SetGrassDataUpdate();
        // Clear the draw and indirect args buffers of last frame's data
        m_ArgsBuffer.SetData(argsBufferReset);

        m_DrawBuffer.SetCounterValue(0);

        m_DispatchSize = Mathf.CeilToInt((float)grassPaintedDatasVisible.Count / threadGroupSize);
        if (m_DispatchSize > 0) {
            // Dispatch the grass shader. It will run on the GPU
            m_InstantiatedComputeShader.Dispatch(m_IdGrassKernel, m_DispatchSize, 1, 1);
            // DrawProceduralIndirect queues a draw call up for our generated mesh
            Graphics.DrawProceduralIndirect(m_InstantiatedMaterial, bounds, MeshTopology.Triangles,
                m_ArgsBuffer, 0, null, null, currentPresets.castShadow, true, gameObject.layer);
        }
    }
    private void SetGrassDataBase() {
        // Send things to compute shader that dont need to be set every frame
        m_InstantiatedComputeShader.SetFloat("_Time", Time.time);
        m_InstantiatedComputeShader.SetFloat("_GrassRandomHeightMin", currentPresets.grassRandomHeightMin);
        m_InstantiatedComputeShader.SetFloat("_GrassRandomHeightMax", currentPresets.grassRandomHeightMax);
        m_InstantiatedComputeShader.SetFloat("_WindSpeed", currentPresets.windSpeed);
        m_InstantiatedComputeShader.SetFloat("_WindStrength", currentPresets.windStrength);
        interactors = (ShaderInteractor[])FindObjectsOfType(typeof(ShaderInteractor));
        m_InstantiatedComputeShader.SetFloat("_InteractorStrength", currentPresets.affectStrength);
        m_InstantiatedComputeShader.SetFloat("_BladeRadius", currentPresets.bladeRadius);
        m_InstantiatedComputeShader.SetFloat("_BladeForward", currentPresets.bladeForwardAmount);
        m_InstantiatedComputeShader.SetFloat("_BladeCurve", Mathf.Max(0, currentPresets.bladeCurveAmount));
        m_InstantiatedComputeShader.SetFloat("_BottomWidth", currentPresets.bottomWidth);
        m_InstantiatedComputeShader.SetFloat("_MinFadeDist", currentPresets.minFadeDistance);
        m_InstantiatedComputeShader.SetFloat("_MaxFadeDist", currentPresets.maxDrawDistance);
        m_InstantiatedMaterial.SetColor("_TopTint", currentPresets.topTint);
        m_InstantiatedMaterial.SetColor("_BottomTint", currentPresets.bottomTint);
    }

    public void Reset() {
        OnDisable();
        OnEnable();
    }
    private void SetGrassDataUpdate() {
        // variables sent to the shader every frame
        m_InstantiatedComputeShader.SetFloat("_Time", Time.time);
        m_InstantiatedComputeShader.SetMatrix("_LocalToWorld", transform.localToWorldMatrix);
        if (interactors.Length > 0) {
            Vector4[] positions = new Vector4[interactors.Length];

            for (int i = 0; i < interactors.Length; i++) {
                positions[i] = new Vector4(interactors[i].transform.position.x, interactors[i].transform.position.y, interactors[i].transform.position.z,
                interactors[i].radius);

            }
            int shaderID = Shader.PropertyToID("_PositionsMoving");
            m_InstantiatedComputeShader.SetVectorArray(shaderID, positions);
            m_InstantiatedComputeShader.SetFloat("_InteractorsLength", interactors.Length);
        }
        if (m_MainCamera != null) {
            m_InstantiatedComputeShader.SetVector("_CameraPositionWS", m_MainCamera.transform.position);
        }
#if UNITY_EDITOR
        // if we dont have a main camera (it gets added during gameplay), use the scene camera
        else if (view != null) {
            m_InstantiatedComputeShader.SetVector("_CameraPositionWS", view.camera.transform.position);
        }
#endif
    }


    // draw the bounds gizmos
    void OnDrawGizmos() {
        if (currentPresets) {
            if (currentPresets.drawBounds) {
                Gizmos.color = new Color(0, 1, 0, 0.3f);
                for (int i = 0; i < BoundsListVis.Count; i++) {
                    Gizmos.DrawWireCube(BoundsListVis[i].center, BoundsListVis[i].size);
                }
                Gizmos.color = new Color(1, 0, 0, 0.3f);
                Gizmos.DrawWireCube(bounds.center, bounds.size);
            }
        }

    }
}

[System.Serializable]
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind
       .Sequential)]
public class GrassPaintedData {
    public Vector3 position;
    public Color color;
    public Vector3 normal;
    public Vector2 length;
}
