using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 水体区块类 - 为每个地形区块生成水面
/// 
/// 【设计原理】
/// - 固定水位系统：全局统一水位高度（海平面）
/// - 填充算法：地形低于水位的地方生成水面
/// - 双面渲染：水面既渲染正面也渲染背面（水下也能看到水面）
/// - 独立网格：水与地形分离，便于应用不同材质（透明、反射等）
/// 
/// 【水体生成策略】
/// - 不生成水体积，只生成水面（性能优化）
/// - 使用2D数组标记哪些位置需要水面
/// - 水面是平面网格，位于waterHeight高度
/// 
/// 【视觉效果】
/// - 可在材质中添加：透明度、波浪动画、反射、折射
/// - 当前实现是基础版，后续可扩展
/// 
/// 【架构位置】
/// TerrainChunk(生成地形) → WaterChunk(检测并生成水面) → 独立渲染
/// </summary>
public class WaterChunk : MonoBehaviour
{
    // 【全局水位高度】
    // 相当于"海平面"，低于此高度且无地形覆盖的地方会有水
    // 值为28：约在区块高度(64)的43%位置
    public const int waterHeight = 28;

    // 【水面标记数组】
    // 2D数组：[x, z]，标记哪些位置需要生成水面
    // 0 = 不需要水（地形高于水位）
    // 1 = 需要水（地形低于水位）
    public int[,] locs = new int[16,16];

    /// <summary>
    /// 初始化：设置水面的局部Y位置
    /// </summary>
    void Start()
    {
        // 【位置设置】
        // localPosition：相对于父物体（TerrainChunk）的位置
        // 水面GameObject是TerrainChunk的子物体
        // 设置Y=waterHeight，使水面处于正确的高度
        transform.localPosition = new Vector3(0, waterHeight, 0);
    }

    /// <summary>
    /// 根据地形方块数据，标记哪些位置需要水面
    /// 被TerrainGenerator在生成区块时调用
    /// </summary>
    /// <param name="blocks">地形区块的方块数据（18x64x18数组）</param>
    public void SetLocs(BlockType[,,] blocks)
    {
        int y;

        // 【遍历区块的每个XZ位置】
        // 只需要2D遍历，因为水面是平的
        for(int x = 0; x < 16; x++)
        {
            for(int z = 0; z < 16; z++)
            {
                // 默认不需要水
                locs[x, z] = 0;

                // 【查找地面高度】
                // 从顶部向下搜索，找到第一个非空气方块
                y = TerrainChunk.chunkHeight - 1;

                // 【向下扫描】直到找到地面或到达底部
                // blocks[x+1, y, z+1]：+1是因为blocks数组包含边界层
                while(y > 0 && blocks[x+1, y, z+1] == BlockType.Air)
                {
                    y--;
                }
                // 此时y是地面的高度（最高的非空气方块）

                // 【判断是否需要水】
                // y+1：地面上方的第一个空气方块位置
                // 如果这个位置低于水位，说明这里应该被水淹没
                if(y+1 < waterHeight)
                    locs[x, z] = 1;  // 标记需要生成水面
            }
        }
    }

    // 【UV坐标模板】
    // 标准的四边形UV：(0,0)→(0,1)→(1,1)→(1,0)
    // 用于给水面贴上完整的纹理
    Vector2[] uvpat = new Vector2[] { 
        new Vector2(0, 0),  // 左下
        new Vector2(0, 1),  // 左上
        new Vector2(1, 1),  // 右上
        new Vector2(1, 0)   // 右下
    };

    /// <summary>
    /// 【核心方法】根据locs数组生成水面网格
    /// 
    /// 算法：
    /// 1. 遍历所有标记为"需要水"的位置
    /// 2. 为每个位置生成一个1x1的水面四边形
    /// 3. 生成两次顶点（正面+反面），实现双面渲染
    /// </summary>
    public void BuildMesh()
    {
        // 【创建网格】
        Mesh mesh = new Mesh();

        // 【网格数据容器】
        List<Vector3> verts = new List<Vector3>();
        List<int> tris = new List<int>();
        List<Vector2> uvs = new List<Vector2>();

        // 【遍历所有XZ位置】
        for(int x = 0; x < 16; x++)
            for(int z = 0; z < 16; z++)
            { 
                // 【检查是否需要水】
                if(locs[x,z]==1)
                {
                    // ===== 第一组：正面（从上往下看） =====
                    // 生成一个水平的四边形
                    // Y=0 因为这个GameObject已经在waterHeight位置了
                    verts.Add(new Vector3(x, 0, z));       // 左下
                    verts.Add(new Vector3(x, 0, z+1));     // 左上
                    verts.Add(new Vector3(x+1, 0, z+1));   // 右上
                    verts.Add(new Vector3(x+1, 0, z));     // 右下

                    // ===== 第二组：反面（从下往上看） =====
                    // 完全相同的顶点，但三角形索引顺序相反
                    // 用于在水下也能看到水面
                    verts.Add(new Vector3(x, 0, z));
                    verts.Add(new Vector3(x, 0, z + 1));
                    verts.Add(new Vector3(x + 1, 0, z + 1));
                    verts.Add(new Vector3(x + 1, 0, z));

                    // 【添加UV坐标】
                    // 每个四边形需要两组UV（正面+反面）
                    uvs.AddRange(uvpat);
                    uvs.AddRange(uvpat);
                    
                    // 【生成三角形索引】
                    // tl: 这个水面四边形的第一个顶点索引
                    int tl = verts.Count-8;  // -8 因为添加了8个顶点（2组x4）
                    
                    // 正面三角形（逆时针，法线向上）：
                    // 三角形1: 0→1→2
                    // 三角形2: 0→2→3
                    //
                    // 反面三角形（顺时针，法线向下）：
                    // 三角形1: 7→6→4  (相当于反转了顺序)
                    // 三角形2: 6→5→4
                    tris.AddRange(new int[] { 
                        tl, tl + 1, tl + 2,       // 正面三角形1
                        tl, tl + 2, tl + 3,       // 正面三角形2
                        tl+3+4, tl+2+4, tl+4,     // 反面三角形1（索引顺序相反）
                        tl+2+4, tl+1+4, tl+4      // 反面三角形2（索引顺序相反）
                    });
                }
            }

        // 【组装网格】
        mesh.vertices = verts.ToArray();
        mesh.triangles = tris.ToArray();
        mesh.uv = uvs.ToArray();

        // 【计算法线】
        // 正面法线向上，反面法线向下
        mesh.RecalculateNormals();

        // 【应用网格】
        // 只需要MeshFilter（渲染），不需要MeshCollider
        // 水体通常不参与物理碰撞，或使用触发器（Trigger）
        GetComponent<MeshFilter>().mesh = mesh;
    }
}
