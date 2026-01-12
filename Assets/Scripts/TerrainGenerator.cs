using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 地形生成器 - 游戏的核心系统，负责整个无限世界的生成和管理
/// 
/// 【设计原理】
/// - 无限世界：基于玩家位置动态加载/卸载区块，理论上可无限延伸
/// - 程序化生成：使用噪声函数生成自然地形，无需预制数据
/// - 对象池系统：复用区块对象，避免频繁实例化/销毁造成的性能问题和内存碎片
/// - 异步生成：使用协程分帧生成，避免一次生成大量区块导致卡顿
/// 
/// 【核心算法】
/// 1. 多层噪声叠加：
///    - 2D Simplex噪声 → 基础地形高度（山丘、平原）
///    - 3D Perlin噪声 → 洞穴和悬崖
///    - 分层系统 → 表层草/泥土，深层石头
/// 
/// 2. 区块流式加载（LOD简化版）：
///    - 检测玩家所在区块
///    - 加载周围5格区块（视野半径）
///    - 卸载距离超过8格的区块
///    - 使用对象池复用GameObject
/// 
/// 3. 树木生成：
///    - 基于区块坐标的随机种子（确保同一位置总是生成相同的树）
///    - 噪声控制密度（山地多树，平原少树）
///    - 程序化生成树干和树叶
/// 
/// 【性能优化策略】
/// - 对象池：避免GC（垃圾回收）压力
/// - 协程生成：每0.2秒生成一个区块，避免掉帧
/// - 静态字典：全局共享区块数据，方便跨系统访问
/// - 分帧逻辑：检测、生成、销毁分散到多帧
/// 
/// 【架构位置】
/// TerrainGenerator (世界管理)
///   ↓ 创建
/// TerrainChunk (区块管理)
///   ↓ 包含
/// WaterChunk (水体)
/// 
/// FastNoise (噪声库) ← 被 TerrainGenerator 使用
/// </summary>
public class TerrainGenerator : MonoBehaviour
{
    [Header("预制体引用")]
    public GameObject terrainChunk;  // 区块预制体（包含TerrainChunk和WaterChunk组件）

    [Header("玩家引用")]
    public Transform player;         // 玩家Transform，用于判断当前位置

    // 【全局区块字典】静态变量，存储所有已加载的区块
    // 键：ChunkPos（区块坐标）
    // 值：TerrainChunk（区块组件引用）
    // 
    // 为什么是静态？
    // - TerrainModifier需要访问以修改方块
    // - 全局单例，避免传参
    public static Dictionary<ChunkPos, TerrainChunk> chunks = new Dictionary<ChunkPos, TerrainChunk>();

    // 【噪声生成器】FastNoise库实例
    FastNoise noise = new FastNoise();

    // 【视野半径】玩家周围加载的区块数量（半径）
    // 5 = 11x11区块 = 176x176米的可见范围
    int chunkDist = 5;

    // 【对象池】存储被卸载但未销毁的区块对象
    // 复用这些对象可以避免频繁的Instantiate/Destroy
    List<TerrainChunk> pooledChunks = new List<TerrainChunk>();

    // 【待生成队列】需要生成但尚未生成的区块位置
    // 通过协程逐个生成，避免一次生成过多
    List<ChunkPos> toGenerate = new List<ChunkPos>();

    /// <summary>
    /// 初始化：立即生成玩家周围的初始区块
    /// </summary>
    void Start()
    {
        // instant=true：立即生成所有初始区块，不使用协程
        // 保证游戏开始时玩家脚下有地面
        LoadChunks(true);
    }

    /// <summary>
    /// 每帧检查是否需要加载新区块
    /// </summary>
    private void Update()
    {
        // instant=false：使用协程异步生成
        LoadChunks();
    }

    /// <summary>
    /// 【核心方法】在指定位置构建一个地形区块
    /// 
    /// 流程：
    /// 1. 从对象池获取或创建新区块对象
    /// 2. 填充方块数据（使用噪声生成）
    /// 3. 生成树木
    /// 4. 构建地形网格
    /// 5. 构建水面网格
    /// 6. 添加到全局字典
    /// 
    /// 性能考虑：
    /// - 优先使用对象池（避免Instantiate开销）
    /// - 一次性填充所有方块数据
    /// - 只调用一次BuildMesh（避免多次网格重建）
    /// </summary>
    /// <param name="xPos">区块的世界X坐标（必须是16的倍数）</param>
    /// <param name="zPos">区块的世界Z坐标（必须是16的倍数）</param>
    void BuildChunk(int xPos, int zPos)
    {
        TerrainChunk chunk;
        
        // 【对象池系统】优先从池中获取
        if(pooledChunks.Count > 0)  // 池中有可用对象
        {
            // 从池中取出第一个
            chunk = pooledChunks[0];
            
            // 激活对象（之前被SetActive(false)隐藏）
            chunk.gameObject.SetActive(true);
            
            // 从池列表中移除
            pooledChunks.RemoveAt(0);
            
            // 移动到新位置
            chunk.transform.position = new Vector3(xPos, 0, zPos);
        }
        else  // 池为空，需要创建新对象
        {
            // 实例化新的区块GameObject
            // Quaternion.identity = 无旋转
            GameObject chunkGO = Instantiate(terrainChunk, new Vector3(xPos, 0, zPos), Quaternion.identity);
            
            // 获取TerrainChunk组件
            chunk = chunkGO.GetComponent<TerrainChunk>();
        }
        
        // 【填充方块数据】三重循环遍历区块内所有位置
        // 注意：遍历18x64x18（包含边界层）
        for(int x = 0; x < TerrainChunk.chunkWidth+2; x++)
            for(int z = 0; z < TerrainChunk.chunkWidth+2; z++)
                for(int y = 0; y < TerrainChunk.chunkHeight; y++)
                {
                    // 【计算世界坐标】
                    // xPos+x-1：区块坐标 + 局部偏移 - 1（边界层偏移）
                    // 
                    // 示例：区块坐标=16, x=0 → 世界坐标=15（左边界，相邻区块的最后一列）
                    //      区块坐标=16, x=1 → 世界坐标=16（区块的第一列）
                    //      区块坐标=16, x=16 → 世界坐标=31（区块的最后一列）
                    //      区块坐标=16, x=17 → 世界坐标=32（右边界，相邻区块的第一列）
                    
                    // 调用GetBlockType根据世界坐标生成方块类型
                    chunk.blocks[x, y, z] = GetBlockType(xPos+x-1, y, zPos+z-1);
                    
                    // 废弃的简单噪声代码（保留作为参考）
                    // 这个会生成平滑的山丘，但缺少洞穴和多样性
                    //if(Mathf.PerlinNoise((xPos + x-1) * .1f, (zPos + z-1) * .1f) * 10 + y < TerrainChunk.chunkHeight * .5f)
                }

        // 【生成树木】在地形基础上添加树木
        // 必须在BuildMesh之前调用，因为树木修改blocks数组
        GenerateTrees(chunk.blocks, xPos, zPos);

        // 【构建地形网格】将方块数据转换为3D网格
        chunk.BuildMesh();

        // 【构建水面】
        // 获取子对象的WaterChunk组件
        WaterChunk wat = chunk.transform.GetComponentInChildren<WaterChunk>();
        
        // 检测哪些位置需要水面
        wat.SetLocs(chunk.blocks);
        
        // 生成水面网格
        wat.BuildMesh();

        // 【注册到全局字典】方便其他系统访问
        // ChunkPos是结构体，包含(xPos, zPos)
        chunks.Add(new ChunkPos(xPos, zPos), chunk);
    }

    /// <summary>
    /// 【核心算法】根据3D坐标生成方块类型
    /// 
    /// 这是整个地形生成的核心，使用多层噪声叠加创建自然地形
    /// 
    /// 【噪声层次结构】
    /// 1. 基础地形层（2D噪声）：
    ///    - simplex1：大尺度地形起伏（山脉、谷地）
    ///    - simplex2：小尺度细节（小山丘），被大尺度噪声调制
    ///    - heightMap = simplex1 + simplex2：最终地形高度
    /// 
    /// 2. 洞穴层（3D噪声）：
    ///    - caveNoise1：3D Perlin噪声，创建洞穴空间
    ///    - caveMask：2D遮罩，控制洞穴出现区域
    /// 
    /// 3. 石层（2D噪声）：
    ///    - 类似地形层，但控制石头的分布深度
    ///    - 地表以下一定深度才是石头
    /// 
    /// 【数学原理】
    /// - 频率（乘数）：越大越密集，0.8=平缓, 5=密集
    /// - 振幅（乘数）：越大起伏越大，*10=温和, *20=剧烈
    /// - 偏移（+0.5）：将[-1,1]映射到[0,1]，用作乘数
    /// - 嵌套调制：用一层噪声控制另一层的强度
    /// 
    /// 【方块分层逻辑】
    /// - 高于地表 → 空气
    /// - 地表1格 → 草方块
    /// - 地表下浅层 → 泥土
    /// - 深层 → 石头
    /// - 洞穴区域 → 强制空气（挖空）
    /// </summary>
    /// <param name="x">世界X坐标</param>
    /// <param name="y">世界Y坐标（高度）</param>
    /// <param name="z">世界Z坐标</param>
    /// <returns>该位置应生成的方块类型</returns>
    BlockType GetBlockType(int x, int y, int z)
    {
        // 【废弃代码】简单的平面地形（保留作为学习参考）
        // 这个会在Y=33处生成一个平面
        /*if(y < 33)
            return BlockType.Dirt;
        else
            return BlockType.Air;*/

        // ========== 第1层：基础地形高度 ==========
        
        // 【大尺度地形噪声】
        // 频率0.8（较低）→ 平缓的大山丘
        // *10 振幅 → 10格高度变化
        float simplex1 = noise.GetSimplex(x*.8f, z*.8f)*10;
        
        // 【小尺度细节噪声】
        // 第一部分：frequency=3（密集）→ 小起伏
        // 第二部分：frequency=0.3（平缓）作为调制器
        //   * (+0.5)：将[-1,1]转为[0,1]，用作乘数
        //   * 这样不同区域的小起伏强度不同（有的平坦，有的崎岖）
        float simplex2 = noise.GetSimplex(x * 3f, z * 3f) * 10 * (noise.GetSimplex(x*.3f, z*.3f)+.5f);

        // 【合并地形高度】
        float heightMap = simplex1 + simplex2;

        // 【计算地表高度】
        // chunkHeight * 0.5 = 32（中间高度）
        // + heightMap（-20到+20的变化）
        // 最终范围约：12 ~ 52
        float baseLandHeight = TerrainChunk.chunkHeight * .5f + heightMap;

        // ========== 第2层：3D洞穴系统 ==========
        
        // 【3D洞穴噪声】
        // GetPerlinFractal：分形噪声，更复杂的纹理
        // x*5, y*10, z*5：在Y方向拉伸，创建垂直的洞穴通道
        float caveNoise1 = noise.GetPerlinFractal(x*5f, y*10f, z*5f);
        
        // 【洞穴遮罩】控制哪些区域有洞穴
        // +0.3：增加洞穴出现的概率
        float caveMask = noise.GetSimplex(x * .3f, z * .3f)+.3f;

        // ========== 第3层：石头分布 ==========
        
        // 【石层高度噪声】（类似地形层）
        float simplexStone1 = noise.GetSimplex(x * 1f, z * 1f) * 10;
        
        // 小尺度细节，被另一层调制
        float simplexStone2 = (noise.GetSimplex(x * 5f, z * 5f)+.5f) * 20 * (noise.GetSimplex(x * .3f, z * .3f) + .5f);

        // 合并石层高度
        float stoneHeightMap = simplexStone1 + simplexStone2;
        
        // 石层顶部高度（约在区块高度的25%）
        float baseStoneHeight = TerrainChunk.chunkHeight * .25f + stoneHeightMap;

        // 【废弃代码】可能是实验性的悬崖生成
        // 使用Y坐标参与噪声计算，创建3D悬崖效果
        //float cliffThing = noise.GetSimplex(x * 1f, z * 1f, y) * 10;
        //float cliffThingMask = noise.GetSimplex(x * .4f, z * .4f) + .3f;

        // ========== 第4层：方块类型判定 ==========
        
        // 默认是空气
        BlockType blockType = BlockType.Air;

        // 【地下方块】如果在地表以下
        if(y <= baseLandHeight)
        {
            // 默认是泥土
            blockType = BlockType.Dirt;

            // 【地表层】如果是最顶上一层，且不在水下
            // y > baseLandHeight - 1：地表层（地表下0-1格）
            // y > WaterChunk.waterHeight-2：水位线以上（否则是泥土海底）
            if(y > baseLandHeight - 1 && y > WaterChunk.waterHeight-2)
                blockType = BlockType.Grass;  // 改为草方块

            // 【深层石头】如果低于石层高度
            if(y <= baseStoneHeight)
                blockType = BlockType.Stone;
        }

        // 【洞穴挖空】如果洞穴噪声超过阈值，强制为空气
        // Mathf.Max(caveMask, .2f)：洞穴遮罩最小为0.2（保证总有一些洞穴）
        // caveNoise1 > 阈值 → 挖空这个位置
        if(caveNoise1 > Mathf.Max(caveMask, .2f))
            blockType = BlockType.Air;

        // 【废弃的实验代码】
        // 可能是尝试其他地形效果
        /*if(blockType != BlockType.Air)
            blockType = BlockType.Stone;*/

        // 3D密度场实验（创建浮空岛效果）
        //if(blockType == BlockType.Air && noise.GetSimplex(x * 4f, y * 4f, z*4f) < 0)
          //  blockType = BlockType.Dirt;

        // 简单Perlin噪声地形（最基础版本）
        //if(Mathf.PerlinNoise(x * .1f, z * .1f) * 10 + y < TerrainChunk.chunkHeight * .5f)
        //    return BlockType.Grass;

        return blockType;
    }

    // 记录玩家当前所在的区块（用于检测区块切换）
    // 初始化为(-1,-1)，保证第一次一定触发加载
    ChunkPos curChunk = new ChunkPos(-1,-1);
    
    /// <summary>
    /// 【核心系统】区块流式加载管理器
    /// 
    /// 功能：
    /// 1. 检测玩家是否进入新区块
    /// 2. 加载玩家周围的区块（视野半径内）
    /// 3. 卸载远离玩家的区块（释放内存）
    /// 4. 清理过期的待生成队列
    /// 
    /// 【加载策略】
    /// - 加载半径：chunkDist = 5（11x11区块）
    /// - 卸载半径：chunkDist + 3 = 8（17x17区块）
    /// - 保留缓冲区：3格区块，避免频繁加载/卸载
    /// 
    /// 【性能优化】
    /// - 只在玩家进入新区块时触发
    /// - 使用协程异步生成（instant=false时）
    /// - 对象池复用，避免频繁实例化
    /// 
    /// 流程图：
    /// 玩家移动 → 检测区块切换 → 标记需要加载的区块 → 
    /// → 标记需要卸载的区块 → 启动协程逐个生成
    /// </summary>
    /// <param name="instant">true=立即生成所有区块, false=使用协程异步生成</param>
    void LoadChunks(bool instant = false)
    {
        // 【计算玩家当前所在区块】
        // Floor(x/16)*16：将世界坐标转为区块坐标
        // 示例：玩家在(25, y, 30) → 区块(16, 16)
        //      玩家在(-5, y, 18) → 区块(-16, 16)
        int curChunkPosX = Mathf.FloorToInt(player.position.x/16)*16;
        int curChunkPosZ = Mathf.FloorToInt(player.position.z/16)*16;

        // 【检测区块切换】只有进入新区块才需要更新
        // 优化：避免每帧都执行下面的循环
        if(curChunk.x != curChunkPosX || curChunk.z != curChunkPosZ)
        {
            // 更新当前区块记录
            curChunk.x = curChunkPosX;
            curChunk.z = curChunkPosZ;

            // ========== 第1步：加载新区块 ==========
            
            // 【双重循环】遍历玩家周围的所有区块
            // 范围：玩家位置 ± (16 * chunkDist)
            // chunkDist=5 → 11x11=121个区块
            // 步进16：因为区块坐标都是16的倍数
            for(int i = curChunkPosX - 16 * chunkDist; i <= curChunkPosX + 16 * chunkDist; i += 16)
                for(int j = curChunkPosZ - 16 * chunkDist; j <= curChunkPosZ + 16 * chunkDist; j += 16)
                {
                    ChunkPos cp = new ChunkPos(i, j);

                    // 【检查区块是否需要生成】
                    // 条件1：不在已加载字典中
                    // 条件2：不在待生成队列中
                    // 两个条件都满足才添加
                    if(!chunks.ContainsKey(cp) && !toGenerate.Contains(cp))
                    {
                        if(instant)  // 立即模式（用于游戏开始）
                        {
                            BuildChunk(i, j);  // 直接生成，可能导致卡顿
                        }
                        else  // 异步模式（用于运行时）
                        {
                            toGenerate.Add(cp);  // 添加到队列，稍后协程处理
                        }
                    }
                }

            // ========== 第2步：卸载远离的区块 ==========
            
            // 【收集需要销毁的区块】
            List<ChunkPos> toDestroy = new List<ChunkPos>();
            
            // 遍历所有已加载的区块
            foreach(KeyValuePair<ChunkPos, TerrainChunk> c in chunks)
            {
                ChunkPos cp = c.Key;
                
                // 【距离检测】如果区块距离超过阈值
                // chunkDist + 3 = 8：比加载半径多3格缓冲区
                // 缓冲区作用：避免玩家在边界来回走时频繁加载/卸载
                if(Mathf.Abs(curChunkPosX - cp.x) > 16 * (chunkDist + 3) || 
                    Mathf.Abs(curChunkPosZ - cp.z) > 16 * (chunkDist + 3))
                {
                    toDestroy.Add(c.Key);  // 标记为需要卸载
                }
            }

            // ========== 第3步：清理待生成队列 ==========
            
            // 【移除玩家已走远的待生成区块】
            // 避免生成玩家已经离开的区域
            // chunkDist + 1：比加载半径稍大一点
            foreach(ChunkPos cp in toGenerate)
            {
                if(Mathf.Abs(curChunkPosX - cp.x) > 16 * (chunkDist + 1) ||
                    Mathf.Abs(curChunkPosZ - cp.z) > 16 * (chunkDist + 1))
                    toGenerate.Remove(cp);  // 从队列移除
            }

            // ========== 第4步：执行卸载操作 ==========
            
            foreach(ChunkPos cp in toDestroy)
            {
                // 【隐藏区块】而不是销毁
                // SetActive(false)：停止渲染和更新，但保留对象
                chunks[cp].gameObject.SetActive(false);
                
                // 【放入对象池】供后续复用
                pooledChunks.Add(chunks[cp]);
                
                // 【从字典移除】释放引用
                chunks.Remove(cp);
            }

            // ========== 第5步：启动异步生成协程 ==========
            
            // 如果有待生成的区块，启动协程逐个生成
            // 协程会在后台慢慢处理，每个区块间隔0.2秒
            StartCoroutine(DelayBuildChunks());
        }
    }

    /// <summary>
    /// 【程序化树木生成器】在区块中随机生成树木
    /// 
    /// 【设计原理】
    /// - 确定性随机：使用区块坐标作为随机种子，保证同一区块总生成相同的树
    /// - 密度控制：使用噪声函数控制树木密度，创建森林/平原的自然分布
    /// - 程序化形状：随机树高、树叶大小，每棵树都独一无二
    /// - 边界安全：树只生成在区块内部（1-14），避免跨区块问题
    /// 
    /// 【算法流程】
    /// 1. 使用噪声判断该区块是否适合长树
    /// 2. 计算树木数量（基于噪声值）
    /// 3. 为每棵树随机位置、高度、树叶大小
    /// 4. 从地面向上堆叠树干
    /// 5. 在树干顶部生成锥形树叶
    /// 
    /// 【随机种子原理】
    /// - 种子 = x * 10000 + z
    /// - 同一区块坐标 → 同一种子 → 同一随机序列
    /// - 好处：世界可重现，保存只需存坐标，不需存每棵树
    /// </summary>
    /// <param name="blocks">区块的方块数组（会被修改）</param>
    /// <param name="x">区块的世界X坐标</param>
    /// <param name="z">区块的世界Z坐标</param>
    void GenerateTrees(BlockType[,,] blocks, int x, int z)
    {
        // 【创建确定性随机数生成器】
        // 种子 = x * 10000 + z
        // 示例：区块(16, 32) → 种子 160032
        // 同一区块永远使用同一种子 → 同样的树
        System.Random rand = new System.Random(x * 10000 + z);

        // 【树木密度噪声】
        // 使用与地形相同的噪声（0.8频率）
        // 值域：-1 到 1
        float simplex = noise.GetSimplex(x * .8f, z * .8f);

        // 【只在噪声为正的区域生成树】
        // simplex > 0：约50%的区块有树（山地）
        // simplex < 0：没有树（平原、沙漠）
        if(simplex > 0)
        {
            // 【放大密度值】
            // *2 → 值域变为 0 到 2
            simplex *= 2f;
            
            // 【计算树木数量】
            // rand.NextDouble(): 0-1的随机数
            // * 5: 最多5棵树
            // * simplex: 密度调制（0-2），高地形=更多树
            // 最终范围：0 到 10 棵树/区块
            int treeCount = Mathf.FloorToInt((float)rand.NextDouble() * 5 * simplex);

            // 【生成每一棵树】
            for(int i = 0; i < treeCount; i++)
            {
                // 【随机树的位置】
                // 范围：1-14（避开边界，0和15是边界层）
                // 为什么避开边界？树可能跨越到相邻区块，导致视觉错误
                int xPos = (int)(rand.NextDouble() * 14) + 1;
                int zPos = (int)(rand.NextDouble() * 14) + 1;

                // 【查找地面高度】
                // 从顶部开始向下扫描
                int y = TerrainChunk.chunkHeight - 1;
                
                // 向下找到第一个非空气方块（地面）
                while(y > 0 && blocks[xPos, y, zPos] == BlockType.Air)
                {
                    y--;
                }
                // 此时y是地面，y+1是地面上方第一个空气位置
                y++;

                // 【随机树高】
                // 4 + [0-3] = 4到7格高
                int treeHeight = 4 + (int)(rand.NextDouble() * 4);

                // 【生成树干】从下往上堆叠
                for(int j = 0; j < treeHeight; j++)
                {
                    // 边界检查：不超过区块顶部
                    if(y+j < 64)
                        blocks[xPos, y+j, zPos] = BlockType.Trunk;
                }

                // 【随机树叶参数】
                // leavesWidth: 1-6格宽（树叶覆盖范围）
                // leavesHeight: 0-2格高（未使用，可能是废弃的参数）
                int leavesWidth = 1 + (int)(rand.NextDouble() * 6);
                int leavesHeight = (int)(rand.NextDouble() * 3);

                // 【生成锥形树叶】
                // iter: 迭代计数，用于创建从下到上逐渐收缩的锥形
                int iter = 0;
                
                // 从树干顶部-1开始，向上生成树高度的树叶层
                // 为什么treeHeight作为树叶层数？创建高耸的锥形树冠
                for(int m = y + treeHeight - 1; m <= y + treeHeight - 1 + treeHeight; m++)
                {
                    // 【每一层树叶】
                    // 从中心向外扩散，形成方形树叶层
                    // iter/2: 每层向内收缩半格，创建锥形效果
                    //
                    // 示例：leavesWidth=4, iter=0
                    //   k: xPos-2 到 xPos+2 （5格宽）
                    // 示例：leavesWidth=4, iter=2  
                    //   k: xPos-1 到 xPos+1 （3格宽，收缩了）
                    for(int k = xPos - (int)(leavesWidth * .5)+iter/2; k <= xPos + (int)(leavesWidth * .5)-iter/2; k++)
                        for(int l = zPos - (int)(leavesWidth * .5)+iter/2; l <= zPos + (int)(leavesWidth * .5)-iter/2; l++)
                        {
                            // 【边界检查】
                            // 确保在区块范围内（0-15）
                            // 确保不超过区块顶部（0-63）
                            // 随机概率80%生成树叶（创建不规则边缘，更自然）
                            if(k >= 0 && k < 16 && l >= 0 && l < 16 && m >= 0 && m < 64 && rand.NextDouble() < .8f)
                                blocks[k, m, l] = BlockType.Leaves;
                        }

                    iter++;  // 下一层收缩更多
                }
            }
        }
    }

    /// <summary>
    /// 【协程】逐个生成待生成队列中的区块
    /// 
    /// 【为什么用协程？】
    /// - 避免卡顿：一次生成大量区块会导致明显掉帧
    /// - 分帧处理：每0.2秒生成一个区块，平滑分散计算负担
    /// - 优先级管理：队列可以动态调整，玩家走远的区块会被移除
    /// 
    /// 【工作原理】
    /// 1. 每次循环生成一个区块
    /// 2. 等待0.2秒（WaitForSeconds）
    /// 3. 继续下一个，直到队列为空
    /// 
    /// 【性能影响】
    /// - 每秒最多生成5个区块
    /// - 玩家快速移动时可能看到地形逐渐"长出来"
    /// - 可以调整等待时间平衡性能和体验
    /// </summary>
    IEnumerator DelayBuildChunks()
    {
        // 【循环处理队列】
        while(toGenerate.Count > 0)
        {
            // 【生成第一个区块】
            // 总是处理队列开头，保持先进先出
            BuildChunk(toGenerate[0].x, toGenerate[0].z);
            
            // 【从队列移除】
            toGenerate.RemoveAt(0);

            // 【等待0.2秒】
            // 暂停协程，让其他代码运行
            // 下一帧继续执行（实际是0.2秒后的帧）
            yield return new WaitForSeconds(.2f);
        }
        // 队列为空，协程自动结束
    }
}

/// <summary>
/// 区块位置结构体 - 用于标识区块的2D坐标
/// 
/// 【为什么用结构体？】
/// - 值类型：比类更轻量，栈分配
/// - 可哈希：可作为Dictionary的键
/// - 不可变语义：坐标一旦确定不应改变
/// 
/// 【使用场景】
/// - Dictionary<ChunkPos, TerrainChunk> 的键
/// - 标记待生成/待销毁的区块
/// 
/// 注意：结构体默认不能直接作为字典键（需要实现GetHashCode）
/// 但C#会自动为简单结构体生成哈希函数
/// </summary>
public struct ChunkPos
{
    public int x, z;  // 区块的X和Z坐标（必须是16的倍数）
    
    /// <summary>
    /// 构造函数：创建区块坐标
    /// </summary>
    /// <param name="x">区块X坐标（16的倍数）</param>
    /// <param name="z">区块Z坐标（16的倍数）</param>
    public ChunkPos(int x, int z)
    {
        this.x = x;
        this.z = z;
    }
}