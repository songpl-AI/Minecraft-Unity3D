using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 体素模型生成器 - 从JSON数据在场景中生成3D体素模型
/// 
/// 【功能说明】
/// - 解析JSON格式的体素数据（可以来自LLM生成）
/// - 使用现有的Block系统和纹理
/// - 利用类似TerrainChunk的mesh合并技术
/// - 自动检测地面并放置模型
/// - 支持放置在玩家前方或指定位置
/// 
/// 【JSON格式】
/// {
///   "name": "模型名称",
///   "size": {"x": 宽度, "y": 高度, "z": 深度},
///   "voxels": [
///     {"x": 0, "y": 0, "z": 0, "blockType": "Dirt"},
///     {"x": 1, "y": 0, "z": 0, "blockType": "Stone"},
///     ...
///   ]
/// }
/// 
/// 【使用方法】
/// 1. 将此脚本挂载到任意GameObject上
/// 2. 在Inspector中粘贴JSON数据，或在代码中调用GenerateFromJson()
/// 3. 调用SpawnInFrontOfPlayer()在玩家前方生成
/// </summary>
public class VoxelModelGenerator : MonoBehaviour
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

    // 体素数据结构
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

        // 解析JSON
        VoxelData voxelData = ParseJson(jsonData);
        if (voxelData == null)
        {
            Debug.LogError("JSON解析失败！");
            return;
        }

        // 生成模型
        GameObject model = GenerateModel(voxelData);
        if (model == null)
        {
            Debug.LogError("模型生成失败！");
            return;
        }

        // 计算放置位置
        Vector3 spawnPosition = CalculateSpawnPosition(voxelData);

        // 放置模型
        model.transform.position = spawnPosition;

        Debug.Log($"成功生成体素模型：{voxelData.name}，位置：{spawnPosition}");
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
    /// </summary>
    GameObject GenerateModel(VoxelData voxelData)
    {
        // 创建父对象
        GameObject modelObject = new GameObject(voxelData.name);

        // 添加Mesh组件
        MeshFilter meshFilter = modelObject.AddComponent<MeshFilter>();
        MeshRenderer meshRenderer = modelObject.AddComponent<MeshRenderer>();
        MeshCollider meshCollider = modelObject.AddComponent<MeshCollider>();

        // 创建3D数组存储体素数据
        BlockType[,,] blocks = new BlockType[voxelData.size.x + 2, voxelData.size.y + 2, voxelData.size.z + 2];

        // 初始化为空气
        for (int x = 0; x < voxelData.size.x + 2; x++)
            for (int y = 0; y < voxelData.size.y + 2; y++)
                for (int z = 0; z < voxelData.size.z + 2; z++)
                    blocks[x, y, z] = BlockType.Air;

        // 填充体素数据（注意偏移1，因为边界层）
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

        // 构建Mesh（使用类似TerrainChunk的算法）
        Mesh mesh = BuildMesh(blocks, voxelData.size.x, voxelData.size.y, voxelData.size.z);

        // 应用Mesh
        meshFilter.mesh = mesh;
        meshCollider.sharedMesh = mesh;

        // 设置材质（使用地形的材质）
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
    /// 构建Mesh（基于TerrainChunk的BuildMesh方法）
    /// </summary>
    Mesh BuildMesh(BlockType[,,] blocks, int width, int height, int depth)
    {
        Mesh mesh = new Mesh();
        List<Vector3> verts = new List<Vector3>();
        List<int> tris = new List<int>();
        List<Vector2> uvs = new List<Vector2>();

        // 遍历所有方块（跳过边界层）
        for (int x = 1; x <= width; x++)
            for (int z = 1; z <= depth; z++)
                for (int y = 1; y <= height; y++)
                {
                    // 跳过空气方块
                    if (blocks[x, y, z] != BlockType.Air)
                    {
                        // 计算方块位置
                        Vector3 blockPos = new Vector3(x - 1, y - 1, z - 1);
                        int numFaces = 0;

                        // 获取当前方块的纹理配置
                        Block block = Block.blocks[blocks[x, y, z]];

                        // 顶面检查
                        if (y < height && blocks[x, y + 1, z] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(0, 1, 0));
                            verts.Add(blockPos + new Vector3(0, 1, 1));
                            verts.Add(blockPos + new Vector3(1, 1, 1));
                            verts.Add(blockPos + new Vector3(1, 1, 0));

                            AddUVs(uvs, block.topPos);
                            AddTriangles(tris, verts.Count, numFaces);
                            numFaces++;
                        }

                        // 底面检查
                        if (y > 1 && blocks[x, y - 1, z] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(0, 0, 0));
                            verts.Add(blockPos + new Vector3(1, 0, 0));
                            verts.Add(blockPos + new Vector3(1, 0, 1));
                            verts.Add(blockPos + new Vector3(0, 0, 1));

                            AddUVs(uvs, block.bottomPos);
                            AddTriangles(tris, verts.Count, numFaces);
                            numFaces++;
                        }

                        // 前面检查（Z-）
                        if (blocks[x, y, z - 1] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(0, 0, 0));
                            verts.Add(blockPos + new Vector3(0, 1, 0));
                            verts.Add(blockPos + new Vector3(1, 1, 0));
                            verts.Add(blockPos + new Vector3(1, 0, 0));

                            AddUVs(uvs, block.sidePos);
                            AddTriangles(tris, verts.Count, numFaces);
                            numFaces++;
                        }

                        // 后面检查（Z+）
                        if (blocks[x, y, z + 1] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(1, 0, 1));
                            verts.Add(blockPos + new Vector3(1, 1, 1));
                            verts.Add(blockPos + new Vector3(0, 1, 1));
                            verts.Add(blockPos + new Vector3(0, 0, 1));

                            AddUVs(uvs, block.sidePos);
                            AddTriangles(tris, verts.Count, numFaces);
                            numFaces++;
                        }

                        // 右面检查（X+）
                        if (blocks[x + 1, y, z] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(1, 0, 0));
                            verts.Add(blockPos + new Vector3(1, 1, 0));
                            verts.Add(blockPos + new Vector3(1, 1, 1));
                            verts.Add(blockPos + new Vector3(1, 0, 1));

                            AddUVs(uvs, block.sidePos);
                            AddTriangles(tris, verts.Count, numFaces);
                            numFaces++;
                        }

                        // 左面检查（X-）
                        if (blocks[x - 1, y, z] == BlockType.Air)
                        {
                            verts.Add(blockPos + new Vector3(0, 0, 1));
                            verts.Add(blockPos + new Vector3(0, 1, 1));
                            verts.Add(blockPos + new Vector3(0, 1, 0));
                            verts.Add(blockPos + new Vector3(0, 0, 0));

                            AddUVs(uvs, block.sidePos);
                            AddTriangles(tris, verts.Count, numFaces);
                            numFaces++;
                        }
                    }
                }

        // 组装Mesh
        mesh.vertices = verts.ToArray();
        mesh.triangles = tris.ToArray();
        mesh.uv = uvs.ToArray();
        mesh.RecalculateNormals();

        return mesh;
    }

    /// <summary>
    /// 添加UV坐标（从TilePos获取）
    /// TilePos.GetUVs()返回预计算好的4个顶点UV坐标数组
    /// </summary>
    void AddUVs(List<Vector2> uvs, TilePos tilePos)
    {
        uvs.AddRange(tilePos.GetUVs());
    }

    /// <summary>
    /// 添加三角形索引
    /// </summary>
    void AddTriangles(List<int> tris, int vertCount, int faceIndex)
    {
        int offset = vertCount - 4;
        tris.Add(offset + 0);
        tris.Add(offset + 1);
        tris.Add(offset + 2);
        tris.Add(offset + 0);
        tris.Add(offset + 2);
        tris.Add(offset + 3);
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
    /// 获取指定位置的地面高度
    /// </summary>
    float GetGroundHeight(float worldX, float worldZ)
    {
        // 使用射线检测地面
        RaycastHit hit;
        Vector3 rayStart = new Vector3(worldX, 100, worldZ);
        
        if (Physics.Raycast(rayStart, Vector3.down, out hit, 200f))
        {
            return hit.point.y;
        }

        // 如果射线检测失败，返回默认高度
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

    /// <summary>
    /// 生成测试用的狗模型JSON数据
    /// </summary>
    public static string GetTestDogJson()
    {
        return @"{
  ""name"": ""SimpleDog"",
  ""size"": {""x"": 8, ""y"": 6, ""z"": 12},
  ""voxels"": [
    {""x"": 2, ""y"": 0, ""z"": 2, ""blockType"": ""Stone""},
    {""x"": 5, ""y"": 0, ""z"": 2, ""blockType"": ""Stone""},
    {""x"": 2, ""y"": 0, ""z"": 9, ""blockType"": ""Stone""},
    {""x"": 5, ""y"": 0, ""z"": 9, ""blockType"": ""Stone""},
    {""x"": 2, ""y"": 1, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 1, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 1, ""z"": 9, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 1, ""z"": 9, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 7, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 7, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 7, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 7, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 8, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 8, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 8, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 8, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 3, ""z"": 9, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 3, ""z"": 9, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 3, ""z"": 10, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 3, ""z"": 10, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 4, ""z"": 10, ""blockType"": ""Stone""},
    {""x"": 4, ""y"": 4, ""z"": 10, ""blockType"": ""Stone""},
    {""x"": 3, ""y"": 3, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 3, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 4, ""z"": 4, ""blockType"": ""Stone""},
    {""x"": 4, ""y"": 4, ""z"": 4, ""blockType"": ""Stone""}
  ]
}";
    }
}
