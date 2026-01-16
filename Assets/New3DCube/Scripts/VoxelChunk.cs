using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace New3DCube
{
    [RequireComponent(typeof(MeshFilter))]
    [RequireComponent(typeof(MeshRenderer))]
    [RequireComponent(typeof(MeshCollider))]
    public class VoxelChunk : MonoBehaviour
    {
        private VoxelInfo[,,] voxels;
        private int size;
        private Vector3Int chunkCoord;
        private VoxelGridManager manager;
        private Mesh mesh;
        private MeshCollider meshCollider;
        
        // 缓存的 Mesh 数据列表，避免每次 GC
        private List<Vector3> vertices = new List<Vector3>();
        private List<int> triangles = new List<int>();
        private List<Color> colors = new List<Color>();

        /// <summary>
        /// 初始化 Chunk
        /// </summary>
        public void Initialize(VoxelGridManager mgr, Vector3Int coord, int chunkSize)
        {
            this.manager = mgr;
            this.chunkCoord = coord;
            this.size = chunkSize;
            
            // 初始化数组
            voxels = new VoxelInfo[size, size, size];
            for (int x = 0; x < size; x++)
                for (int y = 0; y < size; y++)
                    for (int z = 0; z < size; z++)
                        voxels[x, y, z] = VoxelInfo.Empty;

            mesh = new Mesh();
            GetComponent<MeshFilter>().sharedMesh = mesh;
            meshCollider = GetComponent<MeshCollider>();
        }

        /// <summary>
        /// 设置本地体素数据
        /// </summary>
        public void SetVoxel(int x, int y, int z, VoxelInfo info)
        {
            if (IsInside(x, y, z))
            {
                voxels[x, y, z] = info;
            }
        }

        /// <summary>
        /// 获取本地体素数据
        /// </summary>
        public VoxelInfo GetVoxel(int x, int y, int z)
        {
            if (IsInside(x, y, z))
            {
                return voxels[x, y, z];
            }
            return VoxelInfo.Empty;
        }

        private bool IsInside(int x, int y, int z)
        {
            return x >= 0 && x < size && y >= 0 && y < size && z >= 0 && z < size;
        }

        /// <summary>
        /// 重建网格
        /// </summary>
        public void RebuildMesh()
        {
            vertices.Clear();
            triangles.Clear();
            colors.Clear();

            for (int x = 0; x < size; x++)
            {
                for (int y = 0; y < size; y++)
                {
                    for (int z = 0; z < size; z++)
                    {
                        if (!voxels[x, y, z].isEmpty)
                        {
                            GenerateVoxel(x, y, z, voxels[x, y, z]);
                        }
                    }
                }
            }

            mesh.Clear();
            mesh.vertices = vertices.ToArray();
            mesh.triangles = triangles.ToArray();
            mesh.colors = colors.ToArray(); // 使用顶点颜色
            mesh.RecalculateNormals();
            
            // 更新碰撞体
            meshCollider.sharedMesh = null; // 必须先置空强制刷新
            meshCollider.sharedMesh = mesh;
        }

        private void GenerateVoxel(int x, int y, int z, VoxelInfo info)
        {
            Vector3 pos = new Vector3(x, y, z);

            // Right (X+)
            if (CheckNeighbor(x + 1, y, z))
                AddQuad(
                    pos + new Vector3(1, 0, 0),
                    pos + new Vector3(1, 1, 0),
                    pos + new Vector3(1, 1, 1),
                    pos + new Vector3(1, 0, 1),
                    info.color
                );

            // Left (X-)
            if (CheckNeighbor(x - 1, y, z))
                AddQuad(
                    pos + new Vector3(0, 0, 1),
                    pos + new Vector3(0, 1, 1),
                    pos + new Vector3(0, 1, 0),
                    pos + new Vector3(0, 0, 0),
                    info.color
                );

            // Top (Y+)
            if (CheckNeighbor(x, y + 1, z))
                AddQuad(
                    pos + new Vector3(0, 1, 0),
                    pos + new Vector3(0, 1, 1),
                    pos + new Vector3(1, 1, 1),
                    pos + new Vector3(1, 1, 0),
                    info.color
                );

            // Bottom (Y-)
            if (CheckNeighbor(x, y - 1, z))
                AddQuad(
                    pos + new Vector3(0, 0, 1),
                    pos + new Vector3(0, 0, 0),
                    pos + new Vector3(1, 0, 0),
                    pos + new Vector3(1, 0, 1),
                    info.color
                );

            // Front (Z+)
            if (CheckNeighbor(x, y, z + 1))
                AddQuad(
                    pos + new Vector3(1, 0, 1),
                    pos + new Vector3(1, 1, 1),
                    pos + new Vector3(0, 1, 1),
                    pos + new Vector3(0, 0, 1),
                    info.color
                );

            // Back (Z-)
            if (CheckNeighbor(x, y, z - 1))
                AddQuad(
                    pos + new Vector3(0, 0, 0),
                    pos + new Vector3(0, 1, 0),
                    pos + new Vector3(1, 1, 0),
                    pos + new Vector3(1, 0, 0),
                    info.color
                );
        }

        private void AddQuad(Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3, Color c)
        {
            int index = vertices.Count;
            vertices.Add(v0);
            vertices.Add(v1);
            vertices.Add(v2);
            vertices.Add(v3);

            colors.Add(c);
            colors.Add(c);
            colors.Add(c);
            colors.Add(c);

            triangles.Add(index);
            triangles.Add(index + 1);
            triangles.Add(index + 2);
            triangles.Add(index);
            triangles.Add(index + 2);
            triangles.Add(index + 3);
        }

        /// <summary>
        /// 检查指定位置是否是空的（如果是空的，说明当前面可见）
        /// </summary>
        private bool CheckNeighbor(int x, int y, int z)
        {
            // 如果在 Chunk 内部
            if (IsInside(x, y, z))
            {
                return voxels[x, y, z].isEmpty;
            }
            
            // 如果在 Chunk 外部，查询 Manager
            Vector3Int worldPos = chunkCoord + new Vector3Int(x, y, z);
            // 注意：GetVoxelInfo 返回的是 VoxelInfo，如果 isEmpty 为 true 表示是空气
            return manager.GetVoxelInfo(worldPos).isEmpty;
        }

        // 废弃旧的 IsFaceVisible，统一用 CheckNeighbor
        private bool IsFaceVisible(int x, int y, int z) => CheckNeighbor(x, y, z);
    }
}
