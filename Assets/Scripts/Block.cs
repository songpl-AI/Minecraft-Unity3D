using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 方块定义类 - 游戏中所有方块的数据模型
/// 
/// 【设计原理】
/// - 采用"六面体纹理映射"设计：每个方块可以有不同的顶部、侧面、底部纹理
/// - 使用静态字典存储所有方块类型，实现单例模式，节省内存
/// - 通过TilePos获取纹理坐标，实现纹理图集(Texture Atlas)的UV映射
/// 
/// 【架构位置】
/// Block.cs → 被 TerrainChunk.cs 调用 → 用于生成网格时获取纹理坐标
/// </summary>
public class Block
{
    // 三个面的纹理类型（Tile枚举）
    public Tile top, side, bottom;

    // 三个面对应的纹理坐标位置（用于UV映射）
    public TilePos topPos, sidePos, bottomPos;

    /// <summary>
    /// 构造函数1：创建六面使用相同纹理的方块
    /// 用于：泥土、石头、树叶等各面相同的方块
    /// </summary>
    /// <param name="tile">统一的纹理类型</param>
    public Block(Tile tile)
    {
        top = side = bottom = tile;
        GetPositions();
    }

    /// <summary>
    /// 构造函数2：创建顶部、侧面、底部使用不同纹理的方块
    /// 用于：草方块（顶部草、侧面草+泥土、底部泥土）、树干等
    /// </summary>
    /// <param name="top">顶部纹理</param>
    /// <param name="side">侧面纹理（4个侧面）</param>
    /// <param name="bottom">底部纹理</param>
    public Block(Tile top, Tile side, Tile bottom)
    {
        this.top = top;
        this.side = side;
        this.bottom = bottom;
        GetPositions();
    }

    /// <summary>
    /// 从纹理枚举获取对应的UV坐标位置
    /// 通过TilePos.tiles字典查询，将Tile枚举转换为实际的纹理坐标
    /// </summary>
    void GetPositions()
    {
        topPos = TilePos.tiles[top];
        sidePos = TilePos.tiles[side];
        bottomPos = TilePos.tiles[bottom];
    }

    /// <summary>
    /// 【核心数据】方块类型字典 - 定义游戏中所有方块的纹理配置
    /// 
    /// 设计模式：静态单例字典，全局共享
    /// 优势：
    /// 1. 只初始化一次，节省内存
    /// 2. 通过BlockType快速查询方块配置
    /// 3. 易于扩展新方块类型
    /// 
    /// 使用示例：Block.blocks[BlockType.Grass] 获取草方块的配置
    /// </summary>
    public static Dictionary<BlockType, Block> blocks = new Dictionary<BlockType, Block>(){
        {BlockType.Grass, new Block(Tile.Grass, Tile.GrassSide, Tile.Dirt)},  // 草方块：顶部草、侧面草泥混合、底部泥土
        {BlockType.Dirt, new Block(Tile.Dirt)},                                // 泥土：六面相同
        {BlockType.Stone, new Block(Tile.Stone)},                              // 石头：六面相同
        {BlockType.Trunk, new Block(Tile.TreeCX, Tile.TreeSide, Tile.TreeCX)}, // 树干：顶底年轮、侧面树皮
        {BlockType.Leaves, new Block(Tile.Leaves)},                            // 树叶：六面相同
    };
}

/// <summary>
/// 方块类型枚举 - 定义游戏中所有可用的方块种类
/// 
/// Air: 空气（不渲染，用于标记空位置）
/// Dirt: 泥土
/// Grass: 草方块
/// Stone: 石头
/// Trunk: 树干
/// Leaves: 树叶
/// 
/// 扩展提示：添加新方块需要同时修改：
/// 1. 此枚举
/// 2. Block.blocks字典
/// 3. Tile枚举（如需新纹理）
/// 4. TilePos.tiles字典（纹理坐标）
/// </summary>
public enum BlockType {Air, Dirt, Grass, Stone, Trunk, Leaves}