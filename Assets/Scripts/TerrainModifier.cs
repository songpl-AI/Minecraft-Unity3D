using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 地形修改器 - 处理玩家对方块的破坏和放置
/// 
/// 【设计原理】
/// - 射线检测系统：从相机位置发射射线，检测玩家注视的方块
/// - 精确定位：通过碰撞点计算目标方块在区块中的索引
/// - 交互距离限制：最远4米，模拟真实的手臂长度
/// - 即时更新：修改方块后立即重建网格，提供即时反馈
/// 
/// 【交互机制】
/// - 左键：放置方块（在空气中，碰撞点外侧）
/// - 右键：破坏方块（在实体方块中，碰撞点内侧）
/// - 微小偏移技巧：通过±0.01的偏移区分"内侧"和"外侧"
/// 
/// 【坐标转换链】
/// 世界坐标 → 区块坐标（/16取整×16） → 方块索引（取整后+1）
/// 
/// 【架构位置】
/// Input → TerrainModifier → TerrainChunk(修改数据) → BuildMesh(更新视觉)
///                         ↘ Inventory(更新背包)
/// </summary>
public class TerrainModifier : MonoBehaviour
{
    [Header("射线检测配置")]
    public LayerMask groundLayer;    // 地形层级遮罩（只检测地形，不检测UI等）

    [Header("引用")]
    public Inventory inv;            // 物品栏引用（用于放置/拾取方块）

    // 最大交互距离（米）
    float maxDist = 4;

    void Start()
    {
        // 无需初始化
    }

    /// <summary>
    /// 每帧检测鼠标点击并处理方块交互
    /// </summary>
    void Update()
    {
        // 【输入检测】
        // GetMouseButtonDown: 鼠标按下的瞬间（单次触发）
        // 0=左键, 1=右键
        bool leftClick = Input.GetMouseButtonDown(0);
        bool rightClick = Input.GetMouseButtonDown(1);
        
        // 如果有点击事件
        if(leftClick || rightClick)
        {
            // 【射线检测】
            // 从相机位置沿相机前方发射射线
            RaycastHit hitInfo;  // 存储碰撞信息
            
            // Physics.Raycast参数：
            // - 起点：transform.position（相机位置）
            // - 方向：transform.forward（相机前方）
            // - 输出：hitInfo（碰撞详细信息）
            // - 距离：maxDist（最大4米）
            // - 层级：groundLayer（只检测地形层）
            if(Physics.Raycast(transform.position, transform.forward, out hitInfo, maxDist, groundLayer))
            {
                // 【确定目标方块位置】
                Vector3 pointInTargetBlock;

                // 【破坏 vs 放置】通过微小偏移区分目标方块
                // 
                // 碰撞点（hitInfo.point）在方块表面
                // 需要判断是要操作哪个方块：
                // - 破坏：碰撞到的那个方块（向内偏移）
                // - 放置：碰撞点外侧的空气方块（向外偏移）
                
                if(rightClick)  // 破坏方块
                {
                    // 向前移动0.01米，进入方块内部
                    // 确保Floor取整后得到正确的方块坐标
                    pointInTargetBlock = hitInfo.point + transform.forward * .01f;
                }
                else  // 放置方块
                {
                    // 向后移动0.01米，在碰撞点外侧
                    // 这样就定位到玩家想放置方块的空位置
                    pointInTargetBlock = hitInfo.point - transform.forward * .01f;
                }

                // 【坐标转换第1步：世界坐标 → 区块坐标】
                // 
                // 区块是16x16的网格，区块坐标都是16的倍数
                // 例如：世界坐标18.5 → 区块坐标16
                //      世界坐标-5.2 → 区块坐标-16
                // 
                // 算法：Floor(坐标/16) * 16
                int chunkPosX = Mathf.FloorToInt(pointInTargetBlock.x / 16f) * 16;
                int chunkPosZ = Mathf.FloorToInt(pointInTargetBlock.z / 16f) * 16;

                // 创建区块位置结构体（用于字典查询）
                ChunkPos cp = new ChunkPos(chunkPosX, chunkPosZ);

                // 【获取目标区块】
                // 从TerrainGenerator的全局字典中查找
                TerrainChunk tc = TerrainGenerator.chunks[cp];

                // 【坐标转换第2步：世界坐标 → 方块索引】
                // 
                // bix: 方块在区块中的X索引
                // 1. Floor(世界X坐标)：得到方块的世界整数坐标
                // 2. 减去区块X坐标：得到相对于区块的偏移（0-15）
                // 3. +1：因为blocks数组有边界层，实际索引从1开始
                // 
                // 示例：世界坐标18, 区块坐标16
                //      → Floor(18) - 16 + 1 = 3
                //      → 区块内第3个方块（数组索引[3]）
                int bix = Mathf.FloorToInt(pointInTargetBlock.x) - chunkPosX+1;
                int biy = Mathf.FloorToInt(pointInTargetBlock.y);  // Y不需要减，因为区块Y从0开始
                int biz = Mathf.FloorToInt(pointInTargetBlock.z) - chunkPosZ+1;

                // 【执行操作】根据点击类型修改方块
                if(rightClick)  // 破坏方块
                {
                    // 【添加到背包】破坏前先记录方块类型
                    inv.AddToInventory(tc.blocks[bix, biy, biz]);
                    
                    // 【破坏方块】将方块设为空气
                    tc.blocks[bix, biy, biz] = BlockType.Air;
                    
                    // 【更新网格】重新生成网格以反映变化
                    // 这会移除该方块的所有面，并可能显示邻接方块的新面
                    tc.BuildMesh();
                }
                else if(leftClick)  // 放置方块
                {
                    // 【检查背包】确保有方块可放置
                    if(inv.CanPlaceCur())
                    {
                        // 【放置方块】从背包获取当前选中的方块类型
                        tc.blocks[bix, biy, biz] = inv.GetCurBlock();

                        // 【更新网格】重新生成网格显示新方块
                        // 这会添加新方块的面，并隐藏被遮挡的邻接面
                        tc.BuildMesh();

                        // 【消耗物品】从背包减少1个
                        inv.ReduceCur();
                    }
                }
            }
        }
    }
}
