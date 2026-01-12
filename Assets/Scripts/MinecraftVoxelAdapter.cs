using UnityEngine;
using VoxelMeshLibrary;

/// <summary>
/// Minecraft体素数据适配器 - 将BlockType系统适配到通用接口
/// 
/// 【功能】
/// - 实现IVoxelData接口，连接BlockType系统和通用Mesh构建器
/// - 处理UV映射（从Block字典获取纹理坐标）
/// - 定义"空"的概念（BlockType.Air）
/// 
/// 【使用】
/// var adapter = new MinecraftVoxelAdapter(blocks, width, height, depth);
/// Mesh mesh = VoxelMeshBuilder.BuildMesh(adapter);
/// </summary>
public class MinecraftVoxelAdapter : IVoxelData<BlockType>
{
    private BlockType[,,] blocks;
    private Vector3Int size;

    /// <summary>
    /// 构造函数
    /// </summary>
    /// <param name="blocks">体素数据数组（包含边界层，大小为size+2）</param>
    /// <param name="width">实际宽度（不含边界层）</param>
    /// <param name="height">实际高度（不含边界层）</param>
    /// <param name="depth">实际深度（不含边界层）</param>
    public MinecraftVoxelAdapter(BlockType[,,] blocks, int width, int height, int depth)
    {
        this.blocks = blocks;
        this.size = new Vector3Int(width, height, depth);
    }

    /// <summary>
    /// 获取指定位置的体素
    /// </summary>
    public BlockType GetVoxel(int x, int y, int z)
    {
        return blocks[x, y, z];
    }

    /// <summary>
    /// 判断体素是否为"空"
    /// Minecraft中，Air类型认为是空
    /// </summary>
    public bool IsEmpty(BlockType voxel)
    {
        return voxel == BlockType.Air;
    }

    /// <summary>
    /// 获取体素指定面的UV坐标
    /// 从Block字典中获取对应方块的纹理坐标
    /// </summary>
    public Vector2[] GetUVs(BlockType voxel, VoxelFace face)
    {
        // 从Block字典获取方块配置
        Block block = Block.blocks[voxel];

        // 根据面的方向返回对应的UV坐标
        switch (face)
        {
            case VoxelFace.Top:
                return block.topPos.GetUVs();

            case VoxelFace.Bottom:
                return block.bottomPos.GetUVs();

            case VoxelFace.Front:
            case VoxelFace.Back:
            case VoxelFace.Right:
            case VoxelFace.Left:
                // 侧面都使用sidePos
                return block.sidePos.GetUVs();

            default:
                return block.sidePos.GetUVs();
        }
    }

    /// <summary>
    /// 实际渲染区域的尺寸（不包含边界层）
    /// </summary>
    public Vector3Int Size => size;
}
