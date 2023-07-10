using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class GrassSeeds : MonoBehaviour {
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
}
