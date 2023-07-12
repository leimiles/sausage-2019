using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class GrassSystemForSM : MonoBehaviour {
    InstanceSystemForSM instanceSystemForSM;
    public Mesh grassMesh;
    // instanced mesh for LOD
    public Mesh grassMeshLOD;
    public Material grassMaterial;
    public int fieldSize = 1000;
    // density per chunk
    public int chunkDensity = 1;
    public int numChunks = 20;
    [Range(0, 1000.0f)]
    public float distanceCutoff = 200.0f;
    [Range(0, 1000.0f)]
    public float lodCutoff = 60.0f;
    public new Camera camera;


    void OnEnable() {
        instanceSystemForSM = new InstanceSystemForSM(
            grassMesh,
            grassMeshLOD,
            fieldSize,
            chunkDensity,
            numChunks,
            grassMaterial
        );

    }
    void Update() {

        instanceSystemForSM.DrawInstances(camera, distanceCutoff, lodCutoff);

    }

    void OnDisable() {
        if (instanceSystemForSM != null) {
            instanceSystemForSM.Release();
        }
    }

    void OnDrawGizmos() {
        if (instanceSystemForSM != null) {
            instanceSystemForSM.DrawChunkGizmos();
        }
    }
}
