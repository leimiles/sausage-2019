using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
[ExecuteInEditMode]
public class GrassSeeds : MonoBehaviour {
    public bool debugInstance = false;
    public bool matchLocal = false;
    public TransformRecorder transformRecorder;
    bool isActive;
    void Start() {
        if (transformRecorder != null) {
            if (transformRecorder.transformInfo != null) {
                Debug.Log(transformRecorder.transformInfo.Count);
            }
        }
    }

    void OnEnable() {
        isActive = true;
    }

    void Update() {

    }

    void OnDisable() {
        isActive = false;
    }

    void OnDrawGizmos() {
        if (debugInstance) {
            DrawProxy();
        }
    }

    void DrawProxy() {
        for (int i = 0; i < transformRecorder.transformInfo.Count; ++i) {
            if (i == 0) {
                Debug.Log("transform recorder: " + transformRecorder.transformInfo[i].GetColumn(3));
                Debug.Log("transform recorder inverse: " + transformRecorder.transformInfo[i].inverse.GetColumn(3));
                Matrix4x4 matchMatrix = transformRecorder.transformInfo[i].inverse * this.transform.localToWorldMatrix;
                Debug.Log("matchmatrix: " + matchMatrix.GetColumn(3));
            }
            //Gizmos.DrawWireCube(matchMatrix.MultiplyPoint(transformRecorder.transformInfo[i].GetColumn(3)), Vector3.one * 0.1f);
            Gizmos.DrawWireCube(transformRecorder.transformInfo[i].GetColumn(3), Vector3.one * 0.1f);
        }
    }
}
