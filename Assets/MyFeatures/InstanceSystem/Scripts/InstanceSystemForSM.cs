using System.Collections;
using System.Collections.Generic;
using static System.Runtime.InteropServices.Marshal;
using UnityEngine;

public class InstanceSystemForSM {
    public struct InstanceData {
        public Vector4 position;
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
    // array of chunks
    Chunk[] chunks;

    uint[] args;
    uint[] argsLOD;
    Mesh instancedMesh;
    Mesh instancedMeshLOD;
    Bounds fieldBounds;
    Material chunkMaterial;

    ComputeShader chunkPointShader;
    ComputeShader windNoiseShader;
    ComputeShader cullShader;

    public InstanceSystemForSM(
        Mesh mesh,
        Mesh meshLOD,
        int fieldSize,
        int chunkDensity,
        int numChunks,
        Material chunkMaterial
    ) {
        this.fieldSize = fieldSize;
        this.chunkDensity = chunkDensity;
        this.numChunks = numChunks;
        this.chunkMaterial = chunkMaterial;
        this.instancedMesh = mesh;
        this.instancedMeshLOD = meshLOD;
        this.fieldBounds = new Bounds(Vector3.zero, new Vector3(-this.fieldSize, 10, this.fieldSize));      // 10 as temp value
        InitArgs();
        InitializeComputeShaders();
        InitializeChunks();
    }

    void InitializeComputeShaders() {
        chunkPointShader = Resources.Load<ComputeShader>("ChunkPoint");
        chunkPointShader.SetInt(Shader.PropertyToID("_Dimension"), fieldSize);
        chunkPointShader.SetInt(Shader.PropertyToID("_ChunkDimension"), chunkDimension);
        chunkPointShader.SetInt(Shader.PropertyToID("_Scale"), chunkDensity);
        chunkPointShader.SetInt(Shader.PropertyToID("_NumChunks"), numChunks);

        voteBuffer = new ComputeBuffer(numInstancesPerChunk, 4);
        scanBuffer = new ComputeBuffer(numInstancesPerChunk, 4);
        groupSumArrayBuffer = new ComputeBuffer(numThreadGroups, 4);
        scannedGroupSumBuffer = new ComputeBuffer(numThreadGroups, 4);

        cullShader = Resources.Load<ComputeShader>("CullInstance");
    }

    static List<Matrix4x4> transforms = new List<Matrix4x4>();
    static List<Tile> tiles = new List<Tile>();

    public class Tile {
        public int startIndex;
        public int count;
    }

    public static void AddTileBuffer(List<Matrix4x4> transforms) {
    }
    public static void RemoveTileBuffer(Tile tile) {

    }

    void InitializeComputeShaders2() {
        chunkPointShader = Resources.Load<ComputeShader>("ChunkPoint");
        chunkPointShader.SetInt(Shader.PropertyToID("_Dimension"), fieldSize);
        chunkPointShader.SetInt(Shader.PropertyToID("_ChunkDimension"), chunkDimension);
        chunkPointShader.SetInt(Shader.PropertyToID("_Scale"), chunkDensity);
        chunkPointShader.SetInt(Shader.PropertyToID("_NumChunks"), numChunks);

        voteBuffer = new ComputeBuffer(numInstancesPerChunk, 4);
        scanBuffer = new ComputeBuffer(numInstancesPerChunk, 4);
        groupSumArrayBuffer = new ComputeBuffer(numThreadGroups, 4);
        scannedGroupSumBuffer = new ComputeBuffer(numThreadGroups, 4);

        cullShader = Resources.Load<ComputeShader>("CullInstance");
    }

    void InitializeChunks2() {
        chunks = new Chunk[numChunks * numChunks];
        for (int x = 0; x < numChunks; ++x) {
            for (int y = 0; y < numChunks; ++y) {
                int index = x + y * numChunks;
                chunks[index] = InitializeChunk2(x, y);
            }
        }
    }

    Chunk InitializeChunk2(int offsetX, int offsetY) {
        Chunk chunk = new Chunk();
        chunk.argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);
        chunk.argsBufferLOD = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);
        chunk.argsBuffer.SetData(args);
        chunk.argsBufferLOD.SetData(argsLOD);
        chunk.positionsBuffer = new ComputeBuffer(numInstancesPerChunk, SizeOf(typeof(InstanceData)));
        chunk.culledPositionsBuffer = new ComputeBuffer(numInstancesPerChunk, SizeOf(typeof(InstanceData)));
        int chunkDim = Mathf.CeilToInt(fieldSize / numChunks);
        Vector3 center = new Vector3(0.0f, 0.0f, 0.0f);
        center.y = 0.0f;
        center.x = -(chunkDim * 0.5f * numChunks) + chunkDim * offsetX;
        center.z = -(chunkDim * 0.5f * numChunks) + chunkDim * offsetY;
        center.x += chunkDim * 0.5f;
        center.z += chunkDim * 0.5f;
        chunk.bounds = new Bounds(center, new Vector3(-chunkDim, 10.0f, chunkDim));
        chunkPointShader.SetInt(Shader.PropertyToID("_OffsetX"), offsetX);
        chunkPointShader.SetInt(Shader.PropertyToID("_OffsetY"), offsetY);
        chunkPointShader.SetBuffer(0, Shader.PropertyToID("_InstanceDataBuffer"), chunk.positionsBuffer);
        int threadGroups = Mathf.CeilToInt(fieldSize / numChunks) * chunkDensity;
        chunkPointShader.Dispatch(0, threadGroups, threadGroups, 1);

        return chunk;
    }

    void InitArgs2() {
        numInstancesPerChunk = 0;
        chunkDimension = numInstancesPerChunk;
        numInstancesPerChunk *= numInstancesPerChunk;
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
        numVoteThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 128.0f);
        numGroupScanThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 1024.0f);
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

    void InitArgs() {
        numInstancesPerChunk = Mathf.CeilToInt(fieldSize / numChunks) * chunkDensity;
        chunkDimension = numInstancesPerChunk;
        numInstancesPerChunk *= numInstancesPerChunk;
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
        numVoteThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 128.0f);
        numGroupScanThreadGroups = Mathf.CeilToInt(numInstancesPerChunk / 1024.0f);
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
        for (int x = 0; x < numChunks; ++x) {
            for (int y = 0; y < numChunks; ++y) {
                int index = x + y * numChunks;
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
        chunk.positionsBuffer = new ComputeBuffer(numInstancesPerChunk, SizeOf(typeof(InstanceData)));
        chunk.culledPositionsBuffer = new ComputeBuffer(numInstancesPerChunk, SizeOf(typeof(InstanceData)));

        int chunkDim = Mathf.CeilToInt(fieldSize / numChunks);

        Vector3 center = new Vector3(0.0f, 0.0f, 0.0f);
        center.y = 0.0f;
        center.x = -(chunkDim * 0.5f * numChunks) + chunkDim * offsetX;
        center.z = -(chunkDim * 0.5f * numChunks) + chunkDim * offsetY;
        center.x += chunkDim * 0.5f;
        center.z += chunkDim * 0.5f;

        chunk.bounds = new Bounds(center, new Vector3(-chunkDim, 50.0f, chunkDim));     // per bound height is 10

        chunkPointShader.SetInt(Shader.PropertyToID("_OffsetX"), offsetX);
        chunkPointShader.SetInt(Shader.PropertyToID("_OffsetY"), offsetY);
        chunkPointShader.SetBuffer(0, Shader.PropertyToID("_InstanceDataBuffer"), chunk.positionsBuffer);
        int threadGroups = Mathf.CeilToInt(fieldSize / numChunks) * chunkDensity;
        chunkPointShader.Dispatch(0, threadGroups, threadGroups, 1);

        chunk.material = new Material(chunkMaterial);
        chunk.material.SetBuffer(Shader.PropertyToID("positionsBuffer"), chunk.culledPositionsBuffer);
        chunk.material.SetInt(Shader.PropertyToID("_ChunkNum"), offsetX + offsetY * numChunks);
        return chunk;
    }

    void Cull(Chunk chunk, Matrix4x4 vp, float distanceCutoff, bool noLOD, Vector3 cameraPosition) {
        if (noLOD) {
            chunk.argsBuffer.SetData(args);
        } else {
            chunk.argsBufferLOD.SetData(argsLOD);
        }

        // Vote
        cullShader.SetMatrix(Shader.PropertyToID("MATRIX_VP"), vp);
        cullShader.SetBuffer(0, Shader.PropertyToID("_InstanceDataBuffer"), chunk.positionsBuffer);
        cullShader.SetBuffer(0, Shader.PropertyToID("_VoteBuffer"), voteBuffer);
        cullShader.SetVector(Shader.PropertyToID("_CameraPosition"), cameraPosition);
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
        cullShader.SetBuffer(3, Shader.PropertyToID("_InstanceDataBuffer"), chunk.positionsBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_VoteBuffer"), voteBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_ScanBuffer"), scanBuffer);
        cullShader.SetBuffer(3, Shader.PropertyToID("_ArgsBuffer"), noLOD ? chunk.argsBuffer : chunk.argsBufferLOD);
        cullShader.SetBuffer(3, Shader.PropertyToID("_InstanceDataOutputBuffer"), chunk.culledPositionsBuffer);
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

    public void DrawInstances(Camera camera, float distanceCutoff, float lodCutoff) {
        Matrix4x4 p = camera.projectionMatrix;
        Matrix4x4 v = camera.transform.worldToLocalMatrix;
        Matrix4x4 vp = p * v;
        for (int i = 0; i < numChunks * numChunks; ++i) {
            float distance = Vector3.Distance(camera.transform.position, chunks[i].bounds.center);
            bool noLOD = distance < lodCutoff;
            Cull(chunks[i], vp, distanceCutoff, noLOD, camera.transform.position);
            if (noLOD) {
                Graphics.DrawMeshInstancedIndirect(instancedMesh, 0, chunks[i].material, fieldBounds, chunks[i].argsBuffer);
            } else {
                Graphics.DrawMeshInstancedIndirect(instancedMeshLOD, 0, chunks[i].material, fieldBounds, chunks[i].argsBufferLOD);
            }
        }
    }

    public void DrawChunkGizmos() {
        Color color = Gizmos.color;
        Gizmos.color = Color.yellow;
        if (chunks != null) {
            for (int i = 0; i < numChunks * numChunks; ++i) {
                Gizmos.DrawWireCube(chunks[i].bounds.center, chunks[i].bounds.size);
            }
        }
        Gizmos.color = color;

    }

}
