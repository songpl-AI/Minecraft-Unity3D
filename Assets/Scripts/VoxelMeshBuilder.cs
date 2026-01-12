using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 通用体素Mesh生成器 - 不依赖特定的方块类型系统
/// 
/// 【设计理念】
/// - 解耦：不强制依赖 BlockType.Air
/// - 灵活：支持任意类型系统（泛型）
/// - 通用：可配置透明/空类型的判断逻辑
/// 
/// 【使用场景】
/// 1. 当前Minecraft项目：使用BlockType，Air作为空类型
/// 2. 其他体素项目：使用自定义类型，自定义空类型判断
/// 3. 医学可视化：使用int密度值，<threshold认为是空
/// </summary>
public static class VoxelMeshBuilder
{
    /// <summary>
    /// 通用的体素Mesh构建方法（泛型版本）
    /// </summary>
    /// <typeparam name="T">体素类型（例如：BlockType, int, 自定义enum等）</typeparam>
    /// <param name="voxels">体素数据3D数组</param>
    /// <param name="width">实际宽度（不含边界层）</param>
    /// <param name="height">实际高度（不含边界层）</param>
    /// <param name="depth">实际深度（不含边界层）</param>
    /// <param name="isEmptyFunc">判断某个体素是否为"空"的函数</param>
    /// <param name="getUVsFunc">获取某个体素的UV坐标的函数</param>
    /// <returns>生成的Mesh</returns>
    public static Mesh BuildMesh<T>(
        T[,,] voxels,
        int width,
        int height,
        int depth,
        System.Func<T, bool> isEmptyFunc,
        System.Func<T, FaceDirection, Vector2[]> getUVsFunc)
    {
        Mesh mesh = new Mesh();
        List<Vector3> verts = new List<Vector3>();
        List<int> tris = new List<int>();
        List<Vector2> uvs = new List<Vector2>();

        // 遍历所有体素（跳过边界层，从1开始）
        for (int x = 1; x <= width; x++)
            for (int z = 1; z <= depth; z++)
                for (int y = 1; y <= height; y++)
                {
                    T currentVoxel = voxels[x, y, z];
                    
                    // 跳过"空"体素
                    if (isEmptyFunc(currentVoxel))
                        continue;

                    Vector3 blockPos = new Vector3(x - 1, y - 1, z - 1);
                    int numFaces = 0;

                    // 顶面检查
                    if (y < height && isEmptyFunc(voxels[x, y + 1, z]))
                    {
                        AddFace(verts, uvs, tris, blockPos, FaceDirection.Top, 
                               getUVsFunc(currentVoxel, FaceDirection.Top), ref numFaces);
                    }

                    // 底面检查
                    if (y > 1 && isEmptyFunc(voxels[x, y - 1, z]))
                    {
                        AddFace(verts, uvs, tris, blockPos, FaceDirection.Bottom, 
                               getUVsFunc(currentVoxel, FaceDirection.Bottom), ref numFaces);
                    }

                    // 前面检查（Z-）
                    if (isEmptyFunc(voxels[x, y, z - 1]))
                    {
                        AddFace(verts, uvs, tris, blockPos, FaceDirection.Front, 
                               getUVsFunc(currentVoxel, FaceDirection.Front), ref numFaces);
                    }

                    // 后面检查（Z+）
                    if (isEmptyFunc(voxels[x, y, z + 1]))
                    {
                        AddFace(verts, uvs, tris, blockPos, FaceDirection.Back, 
                               getUVsFunc(currentVoxel, FaceDirection.Back), ref numFaces);
                    }

                    // 右面检查（X+）
                    if (isEmptyFunc(voxels[x + 1, y, z]))
                    {
                        AddFace(verts, uvs, tris, blockPos, FaceDirection.Right, 
                               getUVsFunc(currentVoxel, FaceDirection.Right), ref numFaces);
                    }

                    // 左面检查（X-）
                    if (isEmptyFunc(voxels[x - 1, y, z]))
                    {
                        AddFace(verts, uvs, tris, blockPos, FaceDirection.Left, 
                               getUVsFunc(currentVoxel, FaceDirection.Left), ref numFaces);
                    }
                }

        // 组装Mesh
        mesh.vertices = verts.ToArray();
        mesh.triangles = tris.ToArray();
        mesh.uv = uvs.ToArray();
        mesh.RecalculateNormals();

        return mesh;
    }

    /// <summary>
    /// 添加一个面的顶点、UV和三角形
    /// </summary>
    static void AddFace(
        List<Vector3> verts,
        List<Vector2> uvs,
        List<int> tris,
        Vector3 blockPos,
        FaceDirection direction,
        Vector2[] faceUVs,
        ref int numFaces)
    {
        // 根据方向添加4个顶点
        switch (direction)
        {
            case FaceDirection.Top:
                verts.Add(blockPos + new Vector3(0, 1, 0));
                verts.Add(blockPos + new Vector3(0, 1, 1));
                verts.Add(blockPos + new Vector3(1, 1, 1));
                verts.Add(blockPos + new Vector3(1, 1, 0));
                break;

            case FaceDirection.Bottom:
                verts.Add(blockPos + new Vector3(0, 0, 0));
                verts.Add(blockPos + new Vector3(1, 0, 0));
                verts.Add(blockPos + new Vector3(1, 0, 1));
                verts.Add(blockPos + new Vector3(0, 0, 1));
                break;

            case FaceDirection.Front:
                verts.Add(blockPos + new Vector3(0, 0, 0));
                verts.Add(blockPos + new Vector3(0, 1, 0));
                verts.Add(blockPos + new Vector3(1, 1, 0));
                verts.Add(blockPos + new Vector3(1, 0, 0));
                break;

            case FaceDirection.Back:
                verts.Add(blockPos + new Vector3(1, 0, 1));
                verts.Add(blockPos + new Vector3(1, 1, 1));
                verts.Add(blockPos + new Vector3(0, 1, 1));
                verts.Add(blockPos + new Vector3(0, 0, 1));
                break;

            case FaceDirection.Right:
                verts.Add(blockPos + new Vector3(1, 0, 0));
                verts.Add(blockPos + new Vector3(1, 1, 0));
                verts.Add(blockPos + new Vector3(1, 1, 1));
                verts.Add(blockPos + new Vector3(1, 0, 1));
                break;

            case FaceDirection.Left:
                verts.Add(blockPos + new Vector3(0, 0, 1));
                verts.Add(blockPos + new Vector3(0, 1, 1));
                verts.Add(blockPos + new Vector3(0, 1, 0));
                verts.Add(blockPos + new Vector3(0, 0, 0));
                break;
        }

        // 添加UV坐标
        uvs.AddRange(faceUVs);

        // 添加三角形索引
        int offset = verts.Count - 4;
        tris.Add(offset + 0);
        tris.Add(offset + 1);
        tris.Add(offset + 2);
        tris.Add(offset + 0);
        tris.Add(offset + 2);
        tris.Add(offset + 3);

        numFaces++;
    }

    /// <summary>
    /// Minecraft项目专用的便捷方法
    /// </summary>
    public static Mesh BuildMeshForMinecraft(
        BlockType[,,] blocks,
        int width,
        int height,
        int depth)
    {
        return BuildMesh(
            blocks,
            width,
            height,
            depth,
            // 判断是否为空：检查是否是Air
            voxel => voxel == BlockType.Air,
            // 获取UV：从Block字典获取
            (voxel, direction) => {
                Block block = Block.blocks[voxel];
                switch (direction)
                {
                    case FaceDirection.Top:
                    case FaceDirection.Bottom:
                        return direction == FaceDirection.Top ? 
                            block.topPos.GetUVs() : block.bottomPos.GetUVs();
                    default:
                        return block.sidePos.GetUVs();
                }
            }
        );
    }
}

/// <summary>
/// 面的方向枚举
/// </summary>
public enum FaceDirection
{
    Top,
    Bottom,
    Front,
    Back,
    Right,
    Left
}
