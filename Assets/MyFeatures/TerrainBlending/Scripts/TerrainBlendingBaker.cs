using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TerrainBlendingBaker : MonoBehaviour {

    public Shader depthShader;
    public RenderTexture depthTexture;
    private Camera depthCamera;
    // Start is called before the first frame update
    void Start() {

    }

    // Update is called once per frame
    void Update() {
        UpdateBakingCamera();
    }

    private void UpdateBakingCamera() {
        if (depthCamera == null) {
            depthCamera = GetComponent<Camera>();
        } else {
            Debug.Log(depthCamera.orthographicSize);
            Shader.SetGlobalFloat("AABB", depthCamera.orthographicSize * 2);
        }
    }

    [ContextMenu("Bake Depth")]     // click ... to see the menu
    public void BakeTerrainDepth() {
        UpdateBakingCamera();
        if (depthShader != null && depthTexture != null) {
            //depthCamera.SetReplacementShader(depthShader, "RenderType");
            depthCamera.RenderWithShader(depthShader, "RenderType");
            depthCamera.targetTexture = depthTexture;
        } else {
            Debug.Log("Plz, prepare depth shader and depth RT");
        }
    }
}
