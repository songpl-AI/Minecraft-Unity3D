using System.Collections.Generic;
using UnityEngine;
using VoxelMeshLibrary;

/// <summary>
/// 体素模型生成器 V2 - 使用通用VoxelMeshLibrary
/// 
/// 【改进】
/// - 使用通用的VoxelMeshLibrary进行Mesh构建
/// - 通过MinecraftVoxelAdapter适配BlockType系统
/// - 代码更简洁，逻辑更清晰
/// - 易于维护和扩展
/// 
/// 【功能】
/// - 从JSON解析体素数据
/// - 使用通用库生成优化的Mesh
/// - 自动检测地面并放置模型
/// - 支持放置在玩家前方或指定位置
/// 
/// 【使用方法】
/// 1. 将此脚本挂载到场景中的GameObject上
/// 2. 在Inspector中粘贴JSON数据
/// 3. 运行游戏，按G键测试生成
/// </summary>
public class VoxelModelGeneratorV2 : MonoBehaviour
{
    [Header("测试配置")]
    [Tooltip("体素模型的JSON数据")]
    [TextArea(10, 30)]
    public string jsonData = "";

    [Tooltip("是否在Start时自动生成")]
    public bool generateOnStart = true;

    [Tooltip("生成位置：玩家前方的距离")]
    public float spawnDistanceFromPlayer = 5f;

    [Tooltip("是否自动放置在地面上")]
    public bool snapToGround = true;

    [Header("引用")]
    [Tooltip("玩家对象（留空则自动查找MainCamera）")]
    public Transform player;

    [Tooltip("地形生成器（用于检测地面高度）")]
    public TerrainGenerator terrainGenerator;

    // JSON数据结构
    [System.Serializable]
    public class VoxelData
    {
        public string name;
        public VoxelSize size;
        public List<VoxelBlock> voxels;
    }

    [System.Serializable]
    public class VoxelSize
    {
        public int x;
        public int y;
        public int z;
    }

    [System.Serializable]
    public class VoxelBlock
    {
        public int x;
        public int y;
        public int z;
        public string blockType;
    }

    void Start()
    {
        // 自动查找引用
        if (player == null)
        {
            player = Camera.main?.transform;
        }

        if (terrainGenerator == null)
        {
            terrainGenerator = FindObjectOfType<TerrainGenerator>();
        }

        // 如果启用自动生成且有JSON数据，则生成模型
        if (generateOnStart && !string.IsNullOrEmpty(jsonData))
        {
            GenerateAndSpawnModel();
        }
    }

    void Update()
    {
        // 按G键生成模型（用于测试）
        if (Input.GetKeyDown(KeyCode.G))
        {
            GenerateAndSpawnModel();
        }
    }

    /// <summary>
    /// 生成并放置模型（完整流程）
    /// </summary>
    public void GenerateAndSpawnModel()
    {
        if (string.IsNullOrEmpty(jsonData))
        {
            Debug.LogError("JSON数据为空！请在Inspector中设置jsonData字段。");
            return;
        }

        // 1. 解析JSON
        VoxelData voxelData = ParseJson(jsonData);
        if (voxelData == null)
        {
            Debug.LogError("JSON解析失败！");
            return;
        }

        // 2. 生成模型
        GameObject model = GenerateModel(voxelData);
        if (model == null)
        {
            Debug.LogError("模型生成失败！");
            return;
        }

        // 3. 计算放置位置
        Vector3 spawnPosition = CalculateSpawnPosition(voxelData);

        // 4. 放置模型
        model.transform.position = spawnPosition;

        Debug.Log($"✅ 成功生成体素模型：{voxelData.name}，位置：{spawnPosition}");
    }

    /// <summary>
    /// 解析JSON数据
    /// </summary>
    VoxelData ParseJson(string json)
    {
        try
        {
            return JsonUtility.FromJson<VoxelData>(json);
        }
        catch (System.Exception e)
        {
            Debug.LogError($"JSON解析错误：{e.Message}");
            return null;
        }
    }

    /// <summary>
    /// 从体素数据生成3D模型
    /// 【改进】使用通用的VoxelMeshLibrary，代码更简洁
    /// </summary>
    GameObject GenerateModel(VoxelData voxelData)
    {
        // 1. 创建GameObject
        GameObject modelObject = new GameObject(voxelData.name);

        // 2. 准备体素数据数组（包含边界层）
        BlockType[,,] blocks = new BlockType[
            voxelData.size.x + 2,
            voxelData.size.y + 2,
            voxelData.size.z + 2
        ];

        // 3. 初始化为空气
        for (int x = 0; x < voxelData.size.x + 2; x++)
            for (int y = 0; y < voxelData.size.y + 2; y++)
                for (int z = 0; z < voxelData.size.z + 2; z++)
                    blocks[x, y, z] = BlockType.Air;

        // 4. 填充JSON中定义的体素（注意偏移1，因为边界层）
        foreach (var voxel in voxelData.voxels)
        {
            BlockType blockType = ParseBlockType(voxel.blockType);
            if (voxel.x >= 0 && voxel.x < voxelData.size.x &&
                voxel.y >= 0 && voxel.y < voxelData.size.y &&
                voxel.z >= 0 && voxel.z < voxelData.size.z)
            {
                blocks[voxel.x + 1, voxel.y + 1, voxel.z + 1] = blockType;
            }
        }

        // 5. 创建适配器（连接到通用库）
        var adapter = new MinecraftVoxelAdapter(
            blocks,
            voxelData.size.x,
            voxelData.size.y,
            voxelData.size.z
        );

        // 6. 使用通用库生成Mesh（一行代码！）
        Mesh mesh = VoxelMeshBuilder.BuildMesh(adapter);

        // 7. 添加组件并应用Mesh
        MeshFilter meshFilter = modelObject.AddComponent<MeshFilter>();
        MeshRenderer meshRenderer = modelObject.AddComponent<MeshRenderer>();
        MeshCollider meshCollider = modelObject.AddComponent<MeshCollider>();

        meshFilter.mesh = mesh;
        meshCollider.sharedMesh = mesh;

        // 8. 设置材质
        Material terrainMaterial = FindTerrainMaterial();
        if (terrainMaterial != null)
        {
            meshRenderer.material = terrainMaterial;
        }
        else
        {
            Debug.LogWarning("未找到地形材质，使用默认材质");
        }

        return modelObject;
    }

    /// <summary>
    /// 计算生成位置
    /// </summary>
    Vector3 CalculateSpawnPosition(VoxelData voxelData)
    {
        Vector3 position = Vector3.zero;

        if (player != null)
        {
            // 在玩家前方
            position = player.position + player.forward * spawnDistanceFromPlayer;
        }

        if (snapToGround && terrainGenerator != null)
        {
            // 检测地面高度
            float groundHeight = GetGroundHeight(position.x, position.z);
            position.y = groundHeight;
        }
        else
        {
            position.y = 0;
        }

        return position;
    }

    /// <summary>
    /// 获取指定位置的地面高度（射线检测）
    /// </summary>
    float GetGroundHeight(float worldX, float worldZ)
    {
        RaycastHit hit;
        Vector3 rayStart = new Vector3(worldX, 100, worldZ);

        if (Physics.Raycast(rayStart, Vector3.down, out hit, 200f))
        {
            return hit.point.y;
        }

        return 0f;
    }

    /// <summary>
    /// 解析方块类型字符串
    /// </summary>
    BlockType ParseBlockType(string typeStr)
    {
        switch (typeStr.ToLower())
        {
            case "grass": return BlockType.Grass;
            case "dirt": return BlockType.Dirt;
            case "stone": return BlockType.Stone;
            case "trunk": return BlockType.Trunk;
            case "leaves": return BlockType.Leaves;
            default:
                Debug.LogWarning($"未知的方块类型：{typeStr}，使用默认类型Dirt");
                return BlockType.Dirt;
        }
    }

    /// <summary>
    /// 查找地形材质
    /// </summary>
    Material FindTerrainMaterial()
    {
        // 尝试从场景中的TerrainChunk获取材质
        TerrainChunk chunk = FindObjectOfType<TerrainChunk>();
        if (chunk != null)
        {
            MeshRenderer renderer = chunk.GetComponent<MeshRenderer>();
            if (renderer != null && renderer.sharedMaterial != null)
            {
                return renderer.sharedMaterial;
            }
        }

        // 尝试从Resources加载
        Material mat = Resources.Load<Material>("Ground");
        if (mat != null)
        {
            return mat;
        }

        return null;
    }
}
