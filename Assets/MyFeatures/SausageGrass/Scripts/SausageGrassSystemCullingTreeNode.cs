using UnityEngine;
using System.Collections.Generic;
namespace SoFunny.Miles {
    public class SausageGrassSystemCullingTreeNode {
        public Bounds m_bounds;
        public List<SausageGrassSystemCullingTreeNode> childrenNode = new List<SausageGrassSystemCullingTreeNode>();
        public List<VertexAttribute> grassDataHeld = new List<VertexAttribute>();
        public SausageGrassSystemCullingTreeNode(Bounds bounds, int depth) {
            childrenNode.Clear();
            m_bounds = bounds;
            if (depth > 0) {
                Vector3 size = m_bounds.size;
                size /= 4.0f;
                Vector3 childNodeSize = m_bounds.size / 2.0f;
                Vector3 center = m_bounds.center;
                if (depth % 2 == 0) {
                    childNodeSize.y = m_bounds.size.y;
                    Bounds topLeftSingle = new Bounds(new Vector3(center.x - size.x, center.y, center.z - size.z), childNodeSize);
                    Bounds bottomRightSingle = new Bounds(new Vector3(center.x + size.x, center.y, center.z + size.z), childNodeSize);
                    Bounds topRightSingle = new Bounds(new Vector3(center.x - size.x, center.y, center.z + size.z), childNodeSize);
                    Bounds bottomLeftSingle = new Bounds(new Vector3(center.x + size.x, center.y, center.z - size.z), childNodeSize);

                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(topLeftSingle, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(bottomRightSingle, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(topRightSingle, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(bottomLeftSingle, depth - 1));
                } else {
                    Bounds topLeft = new Bounds(new Vector3(center.x - size.x, center.y - size.y, center.z - size.z), childNodeSize);
                    Bounds bottomRight = new Bounds(new Vector3(center.x + size.x, center.y - size.y, center.z + size.z), childNodeSize);
                    Bounds topRight = new Bounds(new Vector3(center.x - size.x, center.y - size.y, center.z + size.z), childNodeSize);
                    Bounds bottomLeft = new Bounds(new Vector3(center.x + size.x, center.y - size.y, center.z - size.z), childNodeSize);

                    // // layer 2
                    Bounds topLeft2 = new Bounds(new Vector3(center.x - size.x, center.y + size.y, center.z - size.z), childNodeSize);
                    Bounds bottomRight2 = new Bounds(new Vector3(center.x + size.x, center.y + size.y, center.z + size.z), childNodeSize);
                    Bounds topRight2 = new Bounds(new Vector3(center.x - size.x, center.y + size.y, center.z + size.z), childNodeSize);
                    Bounds bottomLeft2 = new Bounds(new Vector3(center.x + size.x, center.y + size.y, center.z - size.z), childNodeSize);

                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(topLeft, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(bottomRight, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(topRight, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(bottomLeft, depth - 1));

                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(topLeft2, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(bottomRight2, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(topRight2, depth - 1));
                    childrenNode.Add(new SausageGrassSystemCullingTreeNode(bottomLeft2, depth - 1));

                }
            }
        }
        public void RetrieveLeaves(Plane[] frustum, List<Bounds> list, List<VertexAttribute> visibleList) {
            if (GeometryUtility.TestPlanesAABB(frustum, m_bounds)) {
                if (childrenNode.Count == 0) {
                    if (grassDataHeld.Count > 0) {
                        list.Add(m_bounds);
                        visibleList.AddRange(grassDataHeld);
                    }
                } else {
                    foreach (SausageGrassSystemCullingTreeNode child in childrenNode) {
                        child.RetrieveLeaves(frustum, list, visibleList);
                    }
                }
            }
        }
        public List<VertexAttribute> RetrieveLeaf(Vector3 point) {
            if (m_bounds.Contains(point)) {
                if (childrenNode.Count == 0) {
                    return grassDataHeld;
                } else {
                    foreach (SausageGrassSystemCullingTreeNode child in childrenNode) {
                        child.RetrieveLeaf(point);
                    }
                }
            }
            return null;
        }

        public bool FindLeaf(GrassPaintingArg point) {
            bool found = false;
            if (m_bounds.Contains(point.position)) {

                if (childrenNode.Count != 0) {
                    foreach (SausageGrassSystemCullingTreeNode child in childrenNode) {
                        if (child.FindLeaf(point)) {
                            return true;
                        }
                    }
                } else {
                    VertexAttribute vert = new VertexAttribute();
                    vert.color = new Vector4(point.color.r, point.color.g, point.color.b, point.color.a);
                    vert.normal = point.normal;
                    vert.position = point.position;
                    vert.uv = point.length;
                    grassDataHeld.Add(vert);
                    return true;
                }
            }
            return found;
        }

        public void RetrieveAllLeaves(List<SausageGrassSystemCullingTreeNode> node) {
            if (childrenNode.Count == 0) {
                node.Add(this);
            } else {
                foreach (SausageGrassSystemCullingTreeNode child in childrenNode) {
                    child.RetrieveAllLeaves(node);
                }
            }
        }

        public bool ClearEmpty() {
            bool delete = false;
            if (childrenNode.Count > 0) {
                //  DownSize();
                int i = childrenNode.Count - 1;
                while (i > 0) {
                    if (childrenNode[i].ClearEmpty()) {
                        childrenNode.RemoveAt(i);
                    }
                    i--;
                }
            }
            if (grassDataHeld.Count == 0 && childrenNode.Count == 0) {
                delete = true;
            }
            return delete;
        }
    }
}
