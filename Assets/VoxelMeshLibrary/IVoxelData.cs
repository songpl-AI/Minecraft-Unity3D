using UnityEngine;

/// <summary>
/// 体素数据接口 - 定义体素系统必须实现的最小接口
/// 
/// 【设计理念】
/// 通过接口而非具体类型，实现完全解耦
/// 任何体素系统只需实现这个接口即可使用Mesh构建器
/// </summary>
namespace VoxelMeshLibrary
{
    /// <summary>
    /// 体素数据访问器接口
    /// </summary>
    /// <typeparam name="T">体素类型（可以是enum、int、class等任意类型）</typeparam>
    public interface IVoxelData<T>
    {
        /// <summary>
        /// 获取指定位置的体素
        /// </summary>
        T GetVoxel(int x, int y, int z);

        /// <summary>
        /// 判断指定体素是否为"空"（不需要渲染）
        /// </summary>
        bool IsEmpty(T voxel);

        /// <summary>
        /// 获取体素指定面的UV坐标（4个顶点）
        /// </summary>
        Vector2[] GetUVs(T voxel, VoxelFace face);

        /// <summary>
        /// 实际渲染区域的尺寸（不包含边界层）
        /// </summary>
        Vector3Int Size { get; }
    }

    /// <summary>
    /// 体素的6个面
    /// </summary>
    public enum VoxelFace
    {
        Top,      // Y+
        Bottom,   // Y-
        Front,    // Z-
        Back,     // Z+
        Right,    // X+
        Left      // X-
    }
}
