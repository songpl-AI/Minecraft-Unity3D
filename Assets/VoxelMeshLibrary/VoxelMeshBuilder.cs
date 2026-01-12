using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 独立的体素Mesh构建器 - 可移植到任何Unity项目
/// 
/// 【核心算法】
/// - 面剔除（Face Culling）：只渲染暴露在空气中的面
/// - Mesh合并：将所有体素合并为单个Mesh，减少Draw Call
/// - 顶点共享：通过索引数组共享顶点，节省内存
/// 
/// 【性能优化】
/// - 只遍历实体体素，跳过空体素
/// - 使用List动态增长，避免预分配过大数组
/// - 每个面只在必要时生成（相邻是空才生成）
/// 
/// 【使用方法】
/// 1. 实现IVoxelData接口
/// 2. 调用BuildMesh()方法
/// 3. 将生成的Mesh应用到MeshFilter
/// 
/// 【移植性】
/// - 零依赖：只依赖Unity内置类（Vector3、Mesh等）
/// - 类型无关：通过接口访问数据，不依赖具体类型
/// - 框架无关：纯算法实现，可用于任何Unity项目
/// 
/// 【版本】1.0
/// 【作者】AI Assistant
/// 【日期】2026-01-12
/// </summary>
namespace VoxelMeshLibrary
{
    public static class VoxelMeshBuilder
    {
        /// <summary>
        /// 构建体素Mesh（核心方法）
        /// </summary>
        /// <typeparam name="T">体素类型</typeparam>
        /// <param name="voxelData">体素数据访问器</param>
        /// <returns>生成的Mesh对象</returns>
        public static Mesh BuildMesh<T>(IVoxelData<T> voxelData)
        {
            Mesh mesh = new Mesh();
            List<Vector3> vertices = new List<Vector3>();
            List<int> triangles = new List<int>();
            List<Vector2> uvs = new List<Vector2>();

            Vector3Int size = voxelData.Size;

            // 遍历所有体素位置
            // 注意：假设体素数据包含边界层（+2），实际渲染区域从索引1开始
            for (int x = 1; x <= size.x; x++)
            {
                for (int z = 1; z <= size.z; z++)
                {
                    for (int y = 1; y <= size.y; y++)
                    {
                        T voxel = voxelData.GetVoxel(x, y, z);

                        // 跳过空体素
                        if (voxelData.IsEmpty(voxel))
                            continue;

                        // 计算体素在世界坐标中的位置（减1是因为边界层偏移）
                        Vector3 position = new Vector3(x - 1, y - 1, z - 1);

                        // 检查6个方向，生成暴露的面
                        CheckAndAddFace(voxelData, vertices, uvs, triangles, 
                                       voxel, x, y + 1, z, position, VoxelFace.Top);
                        
                        CheckAndAddFace(voxelData, vertices, uvs, triangles, 
                                       voxel, x, y - 1, z, position, VoxelFace.Bottom);
                        
                        CheckAndAddFace(voxelData, vertices, uvs, triangles, 
                                       voxel, x, y, z - 1, position, VoxelFace.Front);
                        
                        CheckAndAddFace(voxelData, vertices, uvs, triangles, 
                                       voxel, x, y, z + 1, position, VoxelFace.Back);
                        
                        CheckAndAddFace(voxelData, vertices, uvs, triangles, 
                                       voxel, x + 1, y, z, position, VoxelFace.Right);
                        
                        CheckAndAddFace(voxelData, vertices, uvs, triangles, 
                                       voxel, x - 1, y, z, position, VoxelFace.Left);
                    }
                }
            }

            // 组装Mesh
            mesh.vertices = vertices.ToArray();
            mesh.triangles = triangles.ToArray();
            mesh.uv = uvs.ToArray();
            mesh.RecalculateNormals();  // 自动计算法线

            return mesh;
        }

        /// <summary>
        /// 检查相邻体素，如果是空则添加该面
        /// </summary>
        static void CheckAndAddFace<T>(
            IVoxelData<T> voxelData,
            List<Vector3> vertices,
            List<Vector2> uvs,
            List<int> triangles,
            T currentVoxel,
            int neighborX, int neighborY, int neighborZ,
            Vector3 position,
            VoxelFace face)
        {
            // 获取相邻体素
            T neighbor = voxelData.GetVoxel(neighborX, neighborY, neighborZ);

            // 如果相邻是空，则该面需要渲染
            if (!voxelData.IsEmpty(neighbor))
                return;

            // 添加该面的4个顶点
            AddFaceVertices(vertices, position, face);

            // 添加UV坐标
            Vector2[] faceUVs = voxelData.GetUVs(currentVoxel, face);
            uvs.AddRange(faceUVs);

            // 添加三角形索引（2个三角形 = 6个索引）
            AddFaceTriangles(triangles, vertices.Count);
        }

        /// <summary>
        /// 添加一个面的4个顶点
        /// </summary>
        static void AddFaceVertices(List<Vector3> vertices, Vector3 position, VoxelFace face)
        {
            switch (face)
            {
                case VoxelFace.Top:
                    vertices.Add(position + new Vector3(0, 1, 0));
                    vertices.Add(position + new Vector3(0, 1, 1));
                    vertices.Add(position + new Vector3(1, 1, 1));
                    vertices.Add(position + new Vector3(1, 1, 0));
                    break;

                case VoxelFace.Bottom:
                    vertices.Add(position + new Vector3(0, 0, 0));
                    vertices.Add(position + new Vector3(1, 0, 0));
                    vertices.Add(position + new Vector3(1, 0, 1));
                    vertices.Add(position + new Vector3(0, 0, 1));
                    break;

                case VoxelFace.Front:
                    vertices.Add(position + new Vector3(0, 0, 0));
                    vertices.Add(position + new Vector3(0, 1, 0));
                    vertices.Add(position + new Vector3(1, 1, 0));
                    vertices.Add(position + new Vector3(1, 0, 0));
                    break;

                case VoxelFace.Back:
                    vertices.Add(position + new Vector3(1, 0, 1));
                    vertices.Add(position + new Vector3(1, 1, 1));
                    vertices.Add(position + new Vector3(0, 1, 1));
                    vertices.Add(position + new Vector3(0, 0, 1));
                    break;

                case VoxelFace.Right:
                    vertices.Add(position + new Vector3(1, 0, 0));
                    vertices.Add(position + new Vector3(1, 1, 0));
                    vertices.Add(position + new Vector3(1, 1, 1));
                    vertices.Add(position + new Vector3(1, 0, 1));
                    break;

                case VoxelFace.Left:
                    vertices.Add(position + new Vector3(0, 0, 1));
                    vertices.Add(position + new Vector3(0, 1, 1));
                    vertices.Add(position + new Vector3(0, 1, 0));
                    vertices.Add(position + new Vector3(0, 0, 0));
                    break;
            }
        }

        /// <summary>
        /// 添加一个面的三角形索引
        /// </summary>
        static void AddFaceTriangles(List<int> triangles, int vertexCount)
        {
            int offset = vertexCount - 4;
            
            // 第一个三角形
            triangles.Add(offset + 0);
            triangles.Add(offset + 1);
            triangles.Add(offset + 2);
            
            // 第二个三角形
            triangles.Add(offset + 0);
            triangles.Add(offset + 2);
            triangles.Add(offset + 3);
        }
    }
}
