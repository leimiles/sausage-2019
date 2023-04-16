using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class DrawMesh : MonoBehaviour
{
    private Mesh mQuad;

    public Material material;

    private void Start()
    {
        this.InitializeQuadMesh();
    }

    void Update()
    {
        Matrix4x4 m1 = Matrix4x4.TRS(Vector3.zero, Quaternion.Euler(-90, 0, 0), Vector3.one*10);
        Graphics.DrawMesh(mQuad,m1,  material, 0);
    }

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
