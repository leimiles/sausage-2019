using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class GrassSystem : MonoBehaviour {
    InstanceSystem instanceSystem;
    // per chunk size, unit "m"
    public int fieldSize = 100;
    // density per chunk
    public int chunkDensity = 1;
    // num of chunks, x and y
    public int numChunks = 1;
    // displacement
    public float displacementStrength = 200.0f;
    [Range(0, 1000.0f)]
    public float distanceCutoff = 1000.0f;
    [Range(0, 1000.0f)]
    public float lodCutoff = 1000.0f;
    // height map
    public Texture heightMap;
    // instanced mesh
    public Mesh grassMesh;
    // instanced mesh for LOD
    public Mesh grassMeshLOD;
    public Material grassMaterial;
    public new Camera camera;
    void OnEnable() {
        instanceSystem = new InstanceSystem(
            grassMesh,
            grassMeshLOD,
            fieldSize,
            chunkDensity,
            numChunks,
            displacementStrength,
            heightMap,
            grassMaterial
            );
    }

    void Update() {
        instanceSystem.DrawInstances(camera, distanceCutoff, lodCutoff);
    }

    void OnDisable() {
        instanceSystem.Release();
    }

    void OnDrawGizmos() {
        if (instanceSystem != null) {
            instanceSystem.DrawChunkGizmo();
        }
    }

}
