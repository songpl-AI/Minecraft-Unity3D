using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 物品栏系统 - 管理玩家的背包和物品放置
/// 
/// 【设计原理】
/// - 简化的背包系统：固定4个槽位，对应4种可放置的方块
/// - 数字键快捷选择：1-4键快速切换当前物品
/// - 视觉反馈：选中的槽位使用更深的背景色
/// - 物品来源：破坏方块获得，放置方块消耗
/// 
/// 【数据结构】
/// - matCounts[4]: 每个槽位的方块数量
/// - matTypes[4]: 每个槽位对应的方块类型（在Inspector中配置）
/// - curMat: 当前选中的槽位索引（0-3）
/// 
/// 【UI系统】
/// - invImgs[4]: 槽位背景图片（用于高亮显示）
/// - matImgs[4]: 方块图标（有物品时显示，无物品时隐藏）
/// 
/// 【架构位置】
/// TerrainModifier(破坏/放置) ↔ Inventory(物品管理) ↔ UI系统(视觉反馈)
/// </summary>
public class Inventory : MonoBehaviour
{
    // 【核心数据】每个槽位的物品数量
    // 索引对应：0=泥土/草, 1=石头, 2=树干, 3=树叶
    int[] matCounts = new int[] { 0, 0, 0, 0 };

    [Header("物品配置")]
    public BlockType[] matTypes;     // 每个槽位对应的方块类型（在Inspector中设置）

    [Header("UI引用")]
    public Image[] invImgs;          // 槽位背景图片数组（用于高亮）
    public Image[] matImgs;          // 物品图标数组（显示方块图标）

    // 当前选中的槽位索引（0-3）
    int curMat;

    /// <summary>
    /// 初始化：隐藏所有物品图标（开始时背包为空）
    /// </summary>
    void Start()
    {
        // 遍历所有物品图标，初始设为不可见
        // 当玩家捡到物品时才显示
        foreach(Image img in matImgs)
        {
            img.gameObject.SetActive(false);
        }
    }

    /// <summary>
    /// 每帧更新：检测数字键输入切换槽位
    /// </summary>
    void Update()
    {
        // 【快捷键系统】检测数字键1-4
        // KeyCode.Alpha1-4: 键盘主区域的数字键（不是小键盘）
        // GetKeyDown: 按键按下瞬间触发一次（不会连续触发）
        if(Input.GetKeyDown(KeyCode.Alpha1))
            SetCur(0);
        else if(Input.GetKeyDown(KeyCode.Alpha2))
            SetCur(1);
        else if(Input.GetKeyDown(KeyCode.Alpha3))
            SetCur(2);
        else if(Input.GetKeyDown(KeyCode.Alpha4))
            SetCur(3);
    }

    /// <summary>
    /// 切换当前选中的槽位
    /// </summary>
    /// <param name="i">目标槽位索引（0-3）</param>
    void SetCur(int i)
    {
        // 【取消旧槽位高亮】
        // 设置为半透明的暗色背景（RGB=0,0,0, Alpha=43/255≈17%）
        invImgs[curMat].color = new Color(0, 0, 0, 43/255f);

        // 【更新当前槽位】
        curMat = i;
        
        // 【高亮新槽位】
        // 设置为更深的暗色背景（Alpha=80/255≈31%）
        // 通过透明度差异实现选中效果
        invImgs[i].color = new Color(0, 0, 0, 80/255f);
    }

    /// <summary>
    /// 检查当前槽位是否可以放置方块
    /// 被TerrainModifier调用，判断左键是否能放置方块
    /// </summary>
    /// <returns>true=有物品可放置, false=背包空</returns>
    public bool CanPlaceCur()
    {
        return matCounts[curMat] > 0;
    }

    /// <summary>
    /// 获取当前槽位的方块类型
    /// 被TerrainModifier调用，确定要放置什么方块
    /// </summary>
    /// <returns>当前槽位的方块类型</returns>
    public BlockType GetCurBlock()
    {
        return matTypes[curMat];
    }

    /// <summary>
    /// 减少当前槽位的物品数量（放置方块时调用）
    /// </summary>
    public void ReduceCur()
    {
        // 数量减1
        matCounts[curMat]--;

        // 【UI更新】如果用完了，隐藏物品图标
        // 视觉反馈：告诉玩家这个槽位已空
        if(matCounts[curMat] == 0)
            matImgs[curMat].gameObject.SetActive(false);
    }

    /// <summary>
    /// 添加方块到背包（破坏方块时调用）
    /// 
    /// 【物品分类逻辑】
    /// - 草方块/泥土 → 槽位0（统一存为泥土）
    /// - 石头 → 槽位1
    /// - 树干 → 槽位2
    /// - 树叶 → 槽位3
    /// </summary>
    /// <param name="block">被破坏的方块类型</param>
    public void AddToInventory(BlockType block)
    {
        // 【方块类型映射】确定存入哪个槽位
        // 默认槽位0（泥土/草）
        int i = 0;
        
        // 根据方块类型映射到对应槽位
        if(block == BlockType.Stone)
            i = 1;
        else if(block == BlockType.Trunk)
            i = 2;
        else if(block == BlockType.Leaves)
            i = 3;
        // 注意：草方块(Grass)和泥土(Dirt)都存入槽位0

        // 【数量增加】
        matCounts[i]++;
        
        // 【UI更新】如果是第一个，显示物品图标
        // 从0→1时显示图标，给玩家视觉反馈
        if(matCounts[i] == 1)
            matImgs[i].gameObject.SetActive(true);
    }
}
