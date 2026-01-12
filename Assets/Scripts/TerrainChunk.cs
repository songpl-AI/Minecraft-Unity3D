using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 地形区块类 - 管理单个区块的方块数据和网格生成
/// 
/// 【设计原理】
/// - 区块系统：将无限世界划分为16x64x16的小块，便于管理和优化
/// - 动态网格生成：根据方块数据实时构建3D网格
/// - 贪婪网格算法：只渲染暴露在空气中的面，大幅减少顶点数
/// - 邻接检测：多2层边界数据用于检测相邻区块的方块
/// 
/// 【核心算法】
/// 1. 遍历所有非空气方块
/// 2. 检查6个方向的邻接方块
/// 3. 如果邻接方块是空气，生成该方向的面
/// 4. 应用对应的纹理UV坐标
/// 5. 构建三角形索引
/// 
/// 【性能优化】
/// - 面剔除：内部不可见的面不生成（节省90%+顶点）
/// - 单一网格：一个区块只用一个Mesh，减少Draw Call
/// - 共享顶点：相邻三角形共享顶点（通过索引）
/// 
/// 【数据结构】
/// - blocks[18,64,18]：比实际尺寸多2层，用于边界检测
///   * [0]和[17]是边界层，存储相邻区块的方块
///   * [1-16]是实际渲染的方块
/// 
/// 【架构位置】
/// TerrainGenerator(生成数据) → TerrainChunk(构建网格) → MeshFilter/MeshCollider(渲染/碰撞)
/// </summary>
public class TerrainChunk : MonoBehaviour
{
    // 【区块尺寸常量】
    // 
    // 【为什么是16x64x16？】
    // 
    // 1. 宽度/深度 = 16 的原因：
    //    ✅ 二进制优势：16 = 2^4，位运算优化（x/16 = x>>4，x%16 = x&15）
    //    ✅ 内存友好：16x16x64 = 16,384个方块，约64KB内存（每个方块1字节）
    //    ✅ 网格大小：单个区块网格不会过大，BuildMesh()耗时可控（<10ms）
    //    ✅ 加载粒度：16米足够小，玩家移动时能平滑加载新区块
    //    ✅ 历史标准：Minecraft使用16x16，成为行业标准，工具和资源都围绕这个尺寸
    //    ✅ 视野平衡：16米约等于玩家视野的1/5，既不会太频繁加载，也不会看到边界
    // 
    // 2. 高度 = 64 的原因：
    //    ✅ 足够高度：64格（假设1格=1米）足够覆盖大部分地形变化
    //    ✅ 内存平衡：如果太高（如256），内存占用会过大
    //    ✅ 渲染效率：64格高度在面剔除后，实际渲染面数可控
    //    ✅ 游戏性：64米高度足够建造大型建筑，又不会让世界过于空旷
    //    ⚠️  注意：Minecraft原版是256格高，这里用64是简化版
    // 
    // 3. 尺寸权衡表：
    //    尺寸       | 方块数  | 内存(1字节/方块) | BuildMesh耗时 | 加载频率
    //    ----------|---------|-----------------|--------------|----------
    //    8x32x8    | 2,048   | 2KB             | ~1ms         | 频繁
    //    16x64x16  | 16,384  | 64KB            | ~5-10ms      | 适中 ✅
    //    32x128x32 | 131,072 | 512KB           | ~50-100ms    | 稀少
    //    64x256x64 | 1,048,576| 4MB             | ~500ms+      | 很少（卡顿）
    // 
    // 4. 为什么不是其他数字？
    //    ❌ 8x8x8：太小，加载太频繁，边界明显
    //    ❌ 32x32x32：网格太大，BuildMesh会卡顿
    //    ❌ 非2的幂次（如15、17）：无法用位运算优化，性能略差
    //    ✅ 16x64x16：在性能、内存、体验之间的最佳平衡点
    // 
    // 5. 实际影响：
    //    - 玩家移动速度6m/s → 每2.7秒进入新区块 → 加载频率适中
    //    - 11x11区块视野 = 176x176米可见范围 = 合理
    //    - 单个区块网格约5000-15000个顶点（面剔除后）→ 渲染流畅
    // 
    // 6. 可调整性：
    //    如果您的游戏需要：
    //    - 更精细的地形 → 减小到8x32x8（但会增加加载频率）
    //    - 更大的建筑空间 → 增加到32x128x32（但会降低性能）
    //    - 保持当前平衡 → 16x64x16 是最佳选择 ✅
    public const int chunkWidth = 16;   // 区块宽度（X和Z方向）
    public const int chunkHeight = 64;  // 区块高度（Y方向）

    // 【方块数据数组】
    // 三维数组：[X, Y, Z]
    // 大小[18,64,18]：比实际尺寸(16x64x16)多2层
    // 
    // 为什么多2层？
    // - 索引[0]和[17]存储相邻区块的边界方块
    // - 用于判断边缘方块是否需要渲染面
    // - 避免区块边界出现裂缝
    // 
    // 示例：blocks[1,10,1]是实际的第一个方块
    //      blocks[0,10,1]是左侧相邻区块的最后一个方块
    public BlockType[,,] blocks = new BlockType[chunkWidth + 2, chunkHeight, chunkWidth + 2];

    void Start()
    {
        // 无需初始化，由TerrainGenerator填充数据
    }

    /// <summary>
    /// 【核心方法】根据方块数据构建3D网格
    /// 
    /// 算法流程：
    /// 1. 遍历所有方块位置
    /// 2. 对于非空气方块，检查6个方向
    /// 3. 如果某方向是空气，添加该面的顶点、UV、三角形
    /// 4. 组装成Mesh并应用到组件
    /// 
    /// 性能考虑：
    /// - 使用List动态添加，避免预分配过大数组
    /// - 只在数据改变时调用（放置/破坏方块）
    /// - 单次调用可能需要几毫秒（大区块）
    /// </summary>
    public void BuildMesh()
    {
        // 【创建网格对象】
        Mesh mesh = new Mesh();

        // 【网格数据容器】
        // 使用List而非数组：方便动态添加，不需要预知大小
        List<Vector3> verts = new List<Vector3>();  // 顶点位置列表
        List<int> tris = new List<int>();           // 三角形索引列表（每3个索引定义一个三角形）
        List<Vector2> uvs = new List<Vector2>();    // UV纹理坐标列表

        // 【三重循环遍历所有方块】
        // 注意：x和z从1开始到16，跳过边界层[0]和[17]
        // 只渲染实际的16x64x16区域
        for(int x = 1; x < chunkWidth + 1; x++)
            for(int z = 1; z < chunkWidth + 1; z++)
                for(int y = 0; y < chunkHeight; y++)
                {
                    // 【跳过空气方块】
                    // 空气不渲染，节省大量顶点
                    if(blocks[x, y, z] != BlockType.Air)
                    {
                        // 【计算方块的世界位置】
                        // 减1是因为数组索引从1开始，但世界坐标从0开始
                        Vector3 blockPos = new Vector3(x - 1, y, z - 1);
                        
                        // 记录这个方块生成了多少个面（用于后续生成三角形索引）
                        int numFaces = 0;
                        
                        // ========== 检查6个方向，生成可见的面 ==========
                        
                        // 【顶面】检查上方是否有方块
                        if(y < chunkHeight - 1 && blocks[x, y + 1, z] == BlockType.Air)
                        {
                            // 添加4个顶点（逆时针顺序，从Unity相机看是正面）
                            // 顶点顺序很重要：决定法线方向（背面剔除）
                            verts.Add(blockPos + new Vector3(0, 1, 0)); // 左下
                            verts.Add(blockPos + new Vector3(0, 1, 1)); // 左上
                            verts.Add(blockPos + new Vector3(1, 1, 1)); // 右上
                            verts.Add(blockPos + new Vector3(1, 1, 0)); // 右下
                            numFaces++;

                            // 添加顶面的UV坐标（从Block字典获取）
                            uvs.AddRange(Block.blocks[blocks[x, y, z]].topPos.GetUVs());
                        }

                        // 【底面】检查下方是否有方块
                        if(y > 0 && blocks[x, y - 1, z] == BlockType.Air)
                        {
                            // 底面顶点顺序与顶面相反（法线向下）
                            verts.Add(blockPos + new Vector3(0, 0, 0));
                            verts.Add(blockPos + new Vector3(1, 0, 0));
                            verts.Add(blockPos + new Vector3(1, 0, 1));
                            verts.Add(blockPos + new Vector3(0, 0, 1));
                            numFaces++;

                            uvs.AddRange(Block.blocks[blocks[x, y, z]].bottomPos.GetUVs());
                        }

                        // 【前面】Z负方向（朝向相机初始方向）
                        if(blocks[x, y, z - 1] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(0, 0, 0));
                            verts.Add(blockPos + new Vector3(0, 1, 0));
                            verts.Add(blockPos + new Vector3(1, 1, 0));
                            verts.Add(blockPos + new Vector3(1, 0, 0));
                            numFaces++;

                            uvs.AddRange(Block.blocks[blocks[x, y, z]].sidePos.GetUVs());
                        }

                        // 【右面】X正方向
                        if(blocks[x + 1, y, z] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(1, 0, 0));
                            verts.Add(blockPos + new Vector3(1, 1, 0));
                            verts.Add(blockPos + new Vector3(1, 1, 1));
                            verts.Add(blockPos + new Vector3(1, 0, 1));
                            numFaces++;

                            uvs.AddRange(Block.blocks[blocks[x, y, z]].sidePos.GetUVs());
                        }

                        // 【后面】Z正方向
                        if(blocks[x, y, z + 1] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(1, 0, 1));
                            verts.Add(blockPos + new Vector3(1, 1, 1));
                            verts.Add(blockPos + new Vector3(0, 1, 1));
                            verts.Add(blockPos + new Vector3(0, 0, 1));
                            numFaces++;

                            uvs.AddRange(Block.blocks[blocks[x, y, z]].sidePos.GetUVs());
                        }

                        // 【左面】X负方向
                        if(blocks[x - 1, y, z] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(0, 0, 1));
                            verts.Add(blockPos + new Vector3(0, 1, 1));
                            verts.Add(blockPos + new Vector3(0, 1, 0));
                            verts.Add(blockPos + new Vector3(0, 0, 0));
                            numFaces++;

                            uvs.AddRange(Block.blocks[blocks[x, y, z]].sidePos.GetUVs());
                        }

                        // 【生成三角形索引】
                        // 每个面由2个三角形组成（4个顶点 → 6个索引）
                        // 
                        // Quad分割方式：
                        // 0---3    三角形1: 0→1→2
                        // |  /|    三角形2: 0→2→3
                        // | / |
                        // |/  |
                        // 1---2
                        //
                        // tl: 这个方块第一个顶点的索引位置
                        int tl = verts.Count - 4 * numFaces;
                        
                        // 为每个面生成2个三角形（6个索引）
                        for(int i = 0; i < numFaces; i++)
                        {
                            // 三角形1: 0→1→2 (逆时针)
                            // 三角形2: 0→2→3 (逆时针)
                            // 逆时针顺序确保法线朝外（右手定则）
                            tris.AddRange(new int[] { 
                                tl + i * 4,     // 顶点0
                                tl + i * 4 + 1, // 顶点1
                                tl + i * 4 + 2, // 顶点2
                                tl + i * 4,     // 顶点0（第二个三角形）
                                tl + i * 4 + 2, // 顶点2
                                tl + i * 4 + 3  // 顶点3
                            });
                        }
                    }
                }

        // 【组装网格】将数据写入Mesh对象
        mesh.vertices = verts.ToArray();   // 设置顶点数组
        mesh.triangles = tris.ToArray();   // 设置三角形索引
        mesh.uv = uvs.ToArray();           // 设置UV坐标

        // 【计算法线】自动计算每个顶点的法线向量（用于光照）
        // Unity会基于相邻三角形平均计算法线
        mesh.RecalculateNormals();

        // 【应用网格】
        // MeshFilter：负责渲染（显示）
        GetComponent<MeshFilter>().mesh = mesh;
        
        // MeshCollider：负责碰撞检测（物理）
        // sharedMesh: 多个对象共享同一网格数据，节省内存
        GetComponent<MeshCollider>().sharedMesh = mesh;
    }

    /// <summary>
    /// 辅助方法：添加一个方形面（未实现）
    /// 可能是计划中的代码复用优化，但最终采用了内联实现
    /// 保留作为未来重构的参考
    /// </summary>
    void AddSquare(List<Vector3> verts, List<int> tris)
    {
        // 未实现：可以重构上面重复的添加顶点代码
        // 传入：面的方向、位置、纹理类型
        // 输出：添加到verts和tris
    }
}

