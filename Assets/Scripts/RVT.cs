using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class RVT : MonoBehaviour
{
    private RenderTexture allTeerrainMap;
    public Terrain terrain=new Terrain();
    Vector3 size;
    public int renderSize = 2048;
    private Texture2D defualtNormal;
    public Mesh mQuad;
    public Material DrawTexture;
    private RenderBuffer mTerrainMap;
    private RenderBuffer mDepthBuffer;
    private Renderer targetObject;
    private void Init()
    {
        //targetObject=
        size = terrain.terrainData.size;
        Shader.SetGlobalFloat("_terrainSize", size.x);
        Debug.Log(size);
        //allTeerrainMap=RenderTexture.GetTemporary()
        allTeerrainMap = new RenderTexture(renderSize, renderSize,0);
        allTeerrainMap.filterMode = FilterMode.Point;
        allTeerrainMap.wrapMode = TextureWrapMode.Clamp;
        allTeerrainMap.useMipMap = false;
        Shader.SetGlobalTexture("_RVTTtexture", allTeerrainMap);
        mTerrainMap = allTeerrainMap.colorBuffer;
        mDepthBuffer = allTeerrainMap.depthBuffer;
        //this.InitializeQuadMesh();



    }

    // Start is called before the first frame update
    void Start()
    {
        Init();
       
       // DrawTexture.SetMatrix(Shader.PropertyToID("_ImageMVP"), GL.GetGPUProjectionMatrix(mat, true));
        int layerIndex = 0;
        foreach (var alphamap in terrain.terrainData.alphamapTextures)
        {
            Matrix4x4 m1 = Matrix4x4.TRS(Vector3.zero, Quaternion.Euler(-90, 0, 0), Vector3.one * 10);
            Shader.SetGlobalTexture("_Blend", alphamap);
            int index = 1;
            for (; layerIndex < terrain.terrainData.terrainLayers.Length && index <= 4; layerIndex++)
            {
                var layer = terrain.terrainData.terrainLayers[layerIndex];
                var nowScale = new Vector4(size.x/terrain.terrainData.terrainLayers[layerIndex].tileSize.x,   
                                           size.z/terrain.terrainData.terrainLayers[layerIndex].tileSize.y,
                                             terrain.terrainData.terrainLayers[layerIndex].tileOffset.x,
                                             terrain.terrainData.terrainLayers[layerIndex].tileOffset.y);
                Debug.Log(nowScale);
                Shader.SetGlobalVector($"_TileOffset{index}", nowScale);
                Shader.SetGlobalTexture($"_Diffuse{index}", layer.diffuseTexture);
                Shader.SetGlobalTexture($"_Normal{index}", layer.normalMapTexture ?? defualtNormal);
                
                index++;
            }
            Shader.SetGlobalTexture("_HeightOffset", terrain.terrainData.heightmapTexture);
            Shader.SetGlobalFloat("_HeightRange", terrain.terrainData.heightmapScale.y);
            Debug.Log(terrain.terrainData.heightmapScale.y);
            RenderTexture temp = RenderTexture.GetTemporary(renderSize, renderSize, 0, RenderTextureFormat.ARGBFloat);
            Debug.Log(allTeerrainMap.width);
            Debug.Log(allTeerrainMap.height);
            Graphics.Blit(allTeerrainMap, temp);
            Graphics.Blit(temp, allTeerrainMap, DrawTexture);
            //Graphics.SetRenderTarget(mTerrainMap, mDepthBuffer);
            //var tempCB = new CommandBuffer();
            
            //tempCB.DrawMesh(mQuad, Matrix4x4.identity, DrawTexture, 0,0);
            //Graphics.ExecuteCommandBuffer(tempCB);
            //Shader.SetGlobalTexture("_RVTTtexture", allTeerrainMap);
        }



    }

    // Update is called once per frame
    //void Update()
    //{
        
    //}

    void InitializeQuadMesh()
    {
        List<Vector3> quadVertexList = new List<Vector3>();
        List<int> quadTriangleList = new List<int>();
        List<Vector2> quadUVList = new List<Vector2>();

        quadVertexList.Add(new Vector3(0, 1, 0.1f));
        quadUVList.Add(new Vector2(0, 1));
        quadVertexList.Add(new Vector3(0, 0, 0.1f));
        quadUVList.Add(new Vector2(0, 0));
        quadVertexList.Add(new Vector3(1, 0, 0.1f));
        quadUVList.Add(new Vector2(1, 0));
        quadVertexList.Add(new Vector3(1, 1, 0.1f));
        quadUVList.Add(new Vector2(1, 1));

        quadTriangleList.Add(0);
        quadTriangleList.Add(1);
        quadTriangleList.Add(2);

        quadTriangleList.Add(2);
        quadTriangleList.Add(3);
        quadTriangleList.Add(0);

        mQuad = new Mesh();
        mQuad.SetVertices(quadVertexList);
        mQuad.SetUVs(0, quadUVList);
        mQuad.SetTriangles(quadTriangleList, 0);
    }
}
