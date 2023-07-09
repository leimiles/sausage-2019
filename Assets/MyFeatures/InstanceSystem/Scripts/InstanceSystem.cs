using System.Collections;
using System.Collections.Generic;
using static System.Runtime.InteropServices.Marshal;
using UnityEngine;

public class InstanceSystem {
    public struct GrassData {
        public Vector4 position;
        public Vector2 texcoord;
        public float displacement;
    }
    private struct Chunk {
        public ComputeBuffer argsBuffer;
        public ComputeBuffer argsBufferLOD;
        public ComputeBuffer positionsBuffer;
        public ComputeBuffer culledPositionsBuffer;
        public Bounds bounds;
        public Material material;

    }

    #region CS Args
    private int numInstancesPerChunk;
    private int chunkDimension;
    private int numThreadGroups;
    private int numVoteThreadGroups;
    private int numGroupScanThreadGroups;
    private int numWindThreadGroups;
    private int numGrassInitThreadGroups;
    #endregion

    #region  CS Buffers
    private ComputeBuffer voteBuffer;
    private ComputeBuffer scanBuffer;
    private ComputeBuffer groupSumArrayBuffer;
    private ComputeBuffer scannedGroupSumBuffer;
    #endregion


    // per chunk size, unit "m"
    int fieldSize;
    // density per chunk
    int chunkDensity;
    // num of chunks, x and y
    int numChunks;
    // displacement
    float displacementStrength;
    // array of chunks
    Chunk[] chunks;

    uint[] args;
    uint[] argsLOD;
    Mesh instancedMesh;
    Mesh instancedMeshLOD;
    Texture heightmap;
    Bounds fieldBounds;
    Material chunkMaterial;

    ComputeShader chunkPointShader;
    ComputeShader windNoiseShader;
    ComputeShader cullShader;

    private RenderTexture windNoiseRT;

    public InstanceSystem(Mesh mesh,
     Mesh meshLOD,
     int fieldSize,
     int chunkDensity,
     int numChunks,
     float displacementStrength,
     Texture heightmap,
     Material chunkMaterial
     ) {
        this.fieldSize = fieldSize;
        this.chunkDensity = chunkDensity;
        this.numChunks = numChunks;
        this.displacementStrength = displacementStrength;
        this.heightmap = heightmap;
        this.chunkMaterial = chunkMaterial;
        instancedMesh = mesh;
        instancedMeshLOD = meshLOD;

        InitArgs();
        InitializeComputeShaders();
        InitWind();
        InitializeChunks();

        fieldBounds = new Bounds(Vector3.zero, new Vector3(-fieldSize, displacementStrength * 2, fieldSize));
    }

    void InitWind() {
        windNoiseRT = new RenderTexture(1024, 1024, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        windNoiseRT.enableRandomWrite = true;
        windNoiseRT.Create();
        numWindThreadGroups = Mathf.CeilToInt(windNoiseRT.height / 8.0f);
    }

    void InitializeComputeShaders() {

        chunkPointShader = Resources.Load<ComputeShader>("GrassChunkPoint");
        windNoiseShader = Resources.Load<ComputeShader>("WindNoise");
        cullShader = Resources.Load<ComputeShader>("CullGrass");

        voteBuffer = new ComputeBuffer(numInstancesPerChunk, 4);
        scanBuffer = new ComputeBuffer(numInstancesPerChunk, 4);
        groupSumArrayBuffer = new ComputeBuffer(numThreadGroups, 4);
        scannedGroupSumBuffer = new ComputeBuffer(numThreadGroups, 4);

        chunkPointShader.SetInt(Shader.PropertyToID("_Dimension"), fieldSize);
        chunkPointShader.SetInt(Shader.PropertyToID("_ChunkDimension"), chunkDimension);
        chunkPointShader.SetInt(Shader.PropertyToID("_Scale"), chunkDensity);
        chunkPointShader.SetInt(Shader.PropertyToID("_NumChunks"), numChunks);
        chunkPointShader.SetTexture(0, Shader.PropertyToID("_HeightMap"), heightmap);
        chunkPointShader.SetFloat(Shader.PropertyToID("_DisplacementStrength"), displacementStrength);

    }

    void InitArgs() {
        numInstancesPerChunk = Mathf.CeilToInt(fieldSize / numChunks) * chunkDensity;
        chunkDimension = numInstancesPerChunk;
        //Debug.Log("chunkDimension: " + chunkDimension);
        numInstancesPerChunk *= numInstancesPerChunk;
        //Debug.Log("numInstancesPerChunk: " + numInstancesPerChunk);
        numThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 128.0f);

        if (numThreadGroups > 128) {
            int powerOf2 = 128;
            while (powerOf2 < numThreadGroups) {
                powerOf2 *= 2;
            }
            numThreadGroups = powerOf2;
        } else {
            while (128 % numThreadGroups != 0) {
                numThreadGroups++;
            }
        }

        //Debug.Log("numThreadGroups: " + numThreadGroups);
        numVoteThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 128.0f);
        //Debug.Log("numVoteThreadGroups: " + numVoteThreadGroups);
        numGroupScanThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 1024.0f);
        //Debug.Log("numGroupScanThreadGroups: " + numGroupScanThreadGroups);

        args = new uint[5] { 0, 0, 0, 0, 0 };
        args[0] = (uint)instancedMesh.GetIndexCount(0);
        args[1] = (uint)0;
        args[2] = (uint)instancedMesh.GetIndexStart(0);
        args[3] = (uint)instancedMesh.GetBaseVertex(0);

        argsLOD = new uint[5] { 0, 0, 0, 0, 0 };
        argsLOD[0] = (uint)instancedMeshLOD.GetIndexCount(0);
        args[1] = (uint)0;
        args[2] = (uint)instancedMeshLOD.GetIndexStart(0);
        args[3] = (uint)instancedMeshLOD.GetBaseVertex(0);
    }

    void InitializeChunks() {
        chunks = new Chunk[numChunks * numChunks];
        //Debug.Log("numChunks: " + numChunks);
        for (int x = 0; x < numChunks; ++x) {
            for (int y = 0; y < numChunks; ++y) {
                int index = x + y * numChunks;
                //Debug.Log(index);
                chunks[index] = InitializeChunk(x, y);
            }
        }
    }

    Chunk InitializeChunk(int offsetX, int offsetY) {
        Chunk chunk = new Chunk();

        chunk.argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);
        chunk.argsBufferLOD = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);

        chunk.argsBuffer.SetData(args);
        chunk.argsBufferLOD.SetData(argsLOD);

        chunk.positionsBuffer = new ComputeBuffer(numInstancesPerChunk, SizeOf(typeof(GrassData)));
        chunk.culledPositionsBuffer = new ComputeBuffer(numInstancesPerChunk, SizeOf(typeof(GrassData)));
        int chunkDim = Mathf.CeilToInt(fieldSize / numChunks);
        //Debug.Log("chunkDim: " + chunkDim);

        Vector3 center = new Vector3(0.0f, 0.0f, 0.0f);
        center.y = 0.0f;
        center.x = -(chunkDim * 0.5f * numChunks) + chunkDim * offsetX;
        center.z = -(chunkDim * 0.5f * numChunks) + chunkDim * offsetY;
        center.x += chunkDim * 0.5f;
        center.z += chunkDim * 0.5f;
        //Debug.Log("c: " + c);

        chunk.bounds = new Bounds(center, new Vector3(-chunkDim, 10.0f, chunkDim));

        chunkPointShader.SetInt(Shader.PropertyToID("_OffsetX"), offsetX);
        chunkPointShader.SetInt(Shader.PropertyToID("_OffsetY"), offsetY);
        chunkPointShader.SetBuffer(0, Shader.PropertyToID("_GrassDataBuffer"), chunk.positionsBuffer);
        int threadGroups = Mathf.CeilToInt(fieldSize / numChunks) * chunkDensity;
        chunkPointShader.Dispatch(0, threadGroups, threadGroups, 1);

        chunk.material = new Material(chunkMaterial);
        chunk.material.SetBuffer(Shader.PropertyToID("positionsBuffer"), chunk.culledPositionsBuffer);
        chunk.material.SetFloat(Shader.PropertyToID("_DisplacementStrength"), displacementStrength);
        chunk.material.SetTexture(Shader.PropertyToID("_WindNoiseTex"), windNoiseRT);
        chunk.material.SetInt(Shader.PropertyToID("_ChunkNum"), offsetX + offsetY * numChunks);

        return chunk;
    }

    public void DrawInstances(Camera camera, float distanceCutoff, float lodCutoff) {
        Matrix4x4 p = camera.projectionMatrix;
        Matrix4x4 v = camera.transform.worldToLocalMatrix;
        Matrix4x4 vp = p * v;

        for (int i = 0; i < numChunks * numChunks; ++i) {
            float distance = Vector3.Distance(camera.transform.position, chunks[i].bounds.center);
            bool noLOD = distance < lodCutoff;
            Cull(chunks[i], vp, distanceCutoff, noLOD);
            if (noLOD) {
                Graphics.DrawMeshInstancedIndirect(instancedMesh, 0, chunks[i].material, fieldBounds, chunks[i].argsBuffer);
            } else {
                Graphics.DrawMeshInstancedIndirect(instancedMeshLOD, 0, chunks[i].material, fieldBounds, chunks[i].argsBufferLOD);
            }
        }
    }

    public void DrawChunkGizmo() {
        Color color = Gizmos.color;
        Gizmos.color = Color.yellow;
        if (chunks != null) {
            for (int i = 0; i < numChunks * numChunks; ++i) {
                Gizmos.DrawWireCube(chunks[i].bounds.center, chunks[i].bounds.size);
            }
        }
    }

    void Cull(Chunk chunk, Matrix4x4 vp, float distanceCutoff, bool noLOD) {
        if (noLOD) {
            chunk.argsBuffer.SetData(args);
        } else {
            chunk.argsBufferLOD.SetData(argsLOD);
        }
        // Vote
        cullShader.SetMatrix(Shader.PropertyToID("MATRIX_VP"), vp);
        cullShader.SetBuffer(0, Shader.PropertyToID("_GrassDataBuffer"), chunk.positionsBuffer);
        cullShader.SetBuffer(0, Shader.PropertyToID("_VoteBuffer"), voteBuffer);
        cullShader.SetVector(Shader.PropertyToID("_CameraPosition"), Camera.main.transform.position);
        cullShader.SetFloat(Shader.PropertyToID("_Distance"), distanceCutoff);
        cullShader.Dispatch(0, numVoteThreadGroups, 1, 1);

        // Scan Instances
        cullShader.SetBuffer(1, Shader.PropertyToID("_VoteBuffer"), voteBuffer);
        cullShader.SetBuffer(1, Shader.PropertyToID("_ScanBuffer"), scanBuffer);
        cullShader.SetBuffer(1, Shader.PropertyToID("_GroupSumArray"), groupSumArrayBuffer);
        cullShader.Dispatch(1, numThreadGroups, 1, 1);

        // Scan Groups
        cullShader.SetInt(Shader.PropertyToID("_NumOfGroups"), numThreadGroups);
        cullShader.SetBuffer(2, Shader.PropertyToID("_GroupSumArrayIn"), groupSumArrayBuffer);
        cullShader.SetBuffer(2, Shader.PropertyToID("_GroupSumArrayOut"), scannedGroupSumBuffer);
        cullShader.Dispatch(2, numGroupScanThreadGroups, 1, 1);

        // Compact
        cullShader.SetBuffer(3, Shader.PropertyToID("_GrassDataBuffer"), chunk.positionsBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_VoteBuffer"), voteBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_ScanBuffer"), scanBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_ArgsBuffer"), noLOD ? chunk.argsBuffer : chunk.argsBufferLOD);
        cullShader.SetBuffer(3, Shader.PropertyToID("_CulledGrassOutputBuffer"), chunk.culledPositionsBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_GroupSumArray"), scannedGroupSumBuffer);
        cullShader.Dispatch(3, numThreadGroups, 1, 1);
    }

    public void Release() {
        voteBuffer.Release();
        voteBuffer = null;
        scanBuffer.Release();
        scanBuffer = null;
        groupSumArrayBuffer.Release();
        groupSumArrayBuffer = null;
        scannedGroupSumBuffer.Release();
        scannedGroupSumBuffer = null;
        windNoiseRT.Release();
        windNoiseRT = null;

        for (int i = 0; i < numChunks * numChunks; ++i) {
            FreeChunk(chunks[i]);
        }
        chunks = null;
    }

    void FreeChunk(Chunk chunk) {
        chunk.positionsBuffer.Release();
        chunk.positionsBuffer = null;
        chunk.culledPositionsBuffer.Release();
        chunk.culledPositionsBuffer = null;
        chunk.argsBuffer.Release();
        chunk.argsBuffer = null;
        chunk.argsBufferLOD.Release();
        chunk.argsBufferLOD = null;
    }

}
