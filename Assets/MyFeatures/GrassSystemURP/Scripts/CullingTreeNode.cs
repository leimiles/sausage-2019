using UnityEngine;
using System.Collections.Generic;

public class CullingTreeNode
{
    public Bounds m_bounds;

    public List<CullingTreeNode> children = new List<CullingTreeNode>();
    public List<SourceVertex> grassDataHeld = new List<SourceVertex>();

    public CullingTreeNode(Bounds bounds, int depth)
    {
        children.Clear();
        m_bounds = bounds;

        if (depth > 0)
        {
            Vector3 size = m_bounds.size;
            size /= 4.0f;
            Vector3 childSize = m_bounds.size / 2.0f;
            Vector3 center = m_bounds.center;

            // needs less subdiv in the y axis, if you have a LOT of verticality, delete this if statement)
            if (depth % 2 == 0)
            {
                childSize.y = m_bounds.size.y;
                Bounds topLeftSingle = new Bounds(new Vector3(center.x - size.x, center.y, center.z - size.z), childSize);
                Bounds bottomRightSingle = new Bounds(new Vector3(center.x + size.x, center.y, center.z + size.z), childSize);
                Bounds topRightSingle = new Bounds(new Vector3(center.x - size.x, center.y, center.z + size.z), childSize);
                Bounds bottomLeftSingle = new Bounds(new Vector3(center.x + size.x, center.y, center.z - size.z), childSize);

                children.Add(new CullingTreeNode(topLeftSingle, depth - 1));
                children.Add(new CullingTreeNode(bottomRightSingle, depth - 1));
                children.Add(new CullingTreeNode(topRightSingle, depth - 1));
                children.Add(new CullingTreeNode(bottomLeftSingle, depth - 1));
            }
            else
            {
                // // layer 1
                Bounds topLeft = new Bounds(new Vector3(center.x - size.x, center.y - size.y, center.z - size.z), childSize);
                Bounds bottomRight = new Bounds(new Vector3(center.x + size.x, center.y - size.y, center.z + size.z), childSize);
                Bounds topRight = new Bounds(new Vector3(center.x - size.x, center.y - size.y, center.z + size.z), childSize);
                Bounds bottomLeft = new Bounds(new Vector3(center.x + size.x, center.y - size.y, center.z - size.z), childSize);

                // // layer 2
                Bounds topLeft2 = new Bounds(new Vector3(center.x - size.x, center.y + size.y, center.z - size.z), childSize);
                Bounds bottomRight2 = new Bounds(new Vector3(center.x + size.x, center.y + size.y, center.z + size.z), childSize);
                Bounds topRight2 = new Bounds(new Vector3(center.x - size.x, center.y + size.y, center.z + size.z), childSize);
                Bounds bottomLeft2 = new Bounds(new Vector3(center.x + size.x, center.y + size.y, center.z - size.z), childSize);

                children.Add(new CullingTreeNode(topLeft, depth - 1));
                children.Add(new CullingTreeNode(bottomRight, depth - 1));
                children.Add(new CullingTreeNode(topRight, depth - 1));
                children.Add(new CullingTreeNode(bottomLeft, depth - 1));

                children.Add(new CullingTreeNode(topLeft2, depth - 1));
                children.Add(new CullingTreeNode(bottomRight2, depth - 1));
                children.Add(new CullingTreeNode(topRight2, depth - 1));
                children.Add(new CullingTreeNode(bottomLeft2, depth - 1));
            }
        }
    }

    public void RetrieveLeaves(Plane[] frustum, List<Bounds> list, List<SourceVertex> visibleList)
    {
        if (GeometryUtility.TestPlanesAABB(frustum, m_bounds))
        {
            if (children.Count == 0)
            {
                if (grassDataHeld.Count > 0)
                {
                    list.Add(m_bounds);
                    visibleList.AddRange(grassDataHeld);
                }
            }
            else
            {
                foreach (CullingTreeNode child in children)
                {
                    child.RetrieveLeaves(frustum, list, visibleList);
                }
            }
        }
    }

    public List<SourceVertex> returnLeaf(Vector3 point)
    {
        if (m_bounds.Contains(point))
        {
            if (children.Count == 0)
            {
                return grassDataHeld;
            }
            else
            {
                foreach (CullingTreeNode child in children)
                {
                    child.returnLeaf(point);

                }
            }
        }
        return null;
    }

    public bool FindLeaf(GrassPaintedData point)
    {
        bool FoundSpot = false;
        if (m_bounds.Contains(point.position))
        {

            if (children.Count != 0)
            {
                foreach (CullingTreeNode child in children)
                {
                    if (child.FindLeaf(point))
                    {
                        return true;
                    }

                }

            }
            else
            {

                SourceVertex vert = new SourceVertex();
                vert.color = new Vector4(point.color.r, point.color.g, point.color.b, point.color.a);
                vert.normal = point.normal;
                vert.position = point.position;
                vert.uv = point.length;
                grassDataHeld.Add(vert);
                return true;
            }
        }
        return FoundSpot;
    }

    public void RetrieveAllLeaves(List<CullingTreeNode> target)
    {
        if (children.Count == 0)
        {
            target.Add(this);
        }
        else
        {
            foreach (CullingTreeNode child in children)
            {
                child.RetrieveAllLeaves(target);
            }
        }
    }

    public bool ClearEmpty()
    {
        bool delete = false;
        if (children.Count > 0)
        {
            //  DownSize();
            int i = children.Count - 1;
            while (i > 0)
            {
                if (children[i].ClearEmpty())
                {
                    children.RemoveAt(i);
                }
                i--;
            }
        }
        if (grassDataHeld.Count == 0 && children.Count == 0)
        {
            delete = true;
        }
        return delete;
    }
}