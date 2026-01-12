using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 纹理坐标管理类 - 处理纹理图集(Texture Atlas)的UV映射
/// 
/// 【设计原理】
/// - 纹理图集技术：将多个纹理合并到一张大图中，减少Draw Call，提升性能
/// - UV坐标系统：使用0-1范围的归一化坐标定位纹理在图集中的位置
/// - 预计算优化：构造时就计算好所有UV坐标，运行时直接使用
/// 
/// 【UV坐标说明】
/// - 图集大小：16x16个瓦片
/// - 单个瓦片在UV空间的大小：1/16 = 0.0625
/// - 坐标顺序：左下 → 左上 → 右上 → 右下（与Unity的Quad顶点顺序匹配）
/// - 加入0.001偏移：防止纹理采样时出现边缘渗透(Texture Bleeding)
/// 
/// 【架构位置】
/// atlas-4.png(纹理图集) → TilePos(UV计算) → Block(关联方块) → TerrainChunk(应用到网格)
/// </summary>
public class TilePos
{
    // 瓦片在图集中的位置（0-15的整数坐标）
    int xPos, yPos;

    // 预计算的UV坐标数组（4个顶点）
    Vector2[] uvs;

    /// <summary>
    /// 构造函数：根据瓦片在图集中的位置计算UV坐标
    /// </summary>
    /// <param name="xPos">瓦片的X位置（0-15）</param>
    /// <param name="yPos">瓦片的Y位置（0-15）</param>
    public TilePos(int xPos, int yPos)
    {
        this.xPos = xPos;
        this.yPos = yPos;
        
        // 计算四个顶点的UV坐标
        // 【UV坐标计算公式】
        // - 将整数坐标转换为0-1范围：position / 16.0
        // - 加入0.001的偏移避免纹理渗透
        // 
        // 【顶点顺序】对应Unity的Quad网格
        // 0: 左下角
        // 1: 左上角  
        // 2: 右上角
        // 3: 右下角
        uvs = new Vector2[]
        {
            new Vector2(xPos/16f + .001f, yPos/16f + .001f),           // 左下
            new Vector2(xPos/16f+ .001f, (yPos+1)/16f - .001f),        // 左上
            new Vector2((xPos+1)/16f - .001f, (yPos+1)/16f - .001f),   // 右上
            new Vector2((xPos+1)/16f - .001f, yPos/16f+ .001f),        // 右下
        };
    }

    /// <summary>
    /// 获取此瓦片的UV坐标数组
    /// 被TerrainChunk.BuildMesh()调用，用于构建网格的UV
    /// </summary>
    /// <returns>包含4个Vector2的UV坐标数组</returns>
    public Vector2[] GetUVs()
    {
        return uvs;
    }

    /// <summary>
    /// 【核心数据】纹理瓦片字典 - 映射每个纹理类型到图集中的位置
    /// 
    /// 坐标系统：
    /// - 原点(0,0)在左下角
    /// - X轴向右递增，Y轴向上递增
    /// 
    /// 图集布局示例（从atlas-4.png）：
    /// Y=5: [Leaves]
    /// Y=4: [TreeSide]
    /// Y=3: [TreeCX]
    /// Y=2: [Stone]
    /// Y=1: [GrassSide]
    /// Y=0: [Dirt][Grass]
    ///      X=0    X=1
    /// 
    /// 添加新纹理步骤：
    /// 1. 将纹理添加到atlas-4.png图集中
    /// 2. 在Tile枚举中添加新枚举值
    /// 3. 在此字典中添加对应的坐标映射
    /// </summary>
    public static Dictionary<Tile, TilePos> tiles = new Dictionary<Tile, TilePos>()
    {
        {Tile.Dirt, new TilePos(0,0)},       // 泥土：位置(0,0)
        {Tile.Grass, new TilePos(1,0)},      // 草顶部：位置(1,0)
        {Tile.GrassSide, new TilePos(0,1)},  // 草侧面：位置(0,1)
        {Tile.Stone, new TilePos(0,2)},      // 石头：位置(0,2)
        {Tile.TreeSide, new TilePos(0,4)},   // 树皮：位置(0,4)
        {Tile.TreeCX, new TilePos(0,3)},     // 树干横截面：位置(0,3)
        {Tile.Leaves, new TilePos(0,5)},     // 树叶：位置(0,5)
    };
}

/// <summary>
/// 纹理类型枚举 - 定义图集中所有可用的纹理瓦片
/// 
/// 注意：这是纹理层面的枚举，与BlockType（方块类型）不同
/// 一个方块可能使用多个纹理（如草方块使用Grass、GrassSide、Dirt三种纹理）
/// </summary>
public enum Tile {Dirt, Grass, GrassSide, Stone, TreeSide, TreeCX, Leaves}
