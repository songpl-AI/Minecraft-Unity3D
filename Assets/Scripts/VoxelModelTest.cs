using UnityEngine;

/// <summary>
/// 体素模型生成器快速测试脚本
/// 
/// 【使用方法】
/// 1. 将此脚本挂载到场景中的任意GameObject上
/// 2. 运行游戏
/// 3. 按对应的按键生成不同的测试模型：
///    - G键: 生成简单的狗模型
///    - H键: 生成小房子模型
///    - T键: 生成树木模型
///    - C键: 清除所有生成的模型
/// </summary>
public class VoxelModelTest : MonoBehaviour
{
    [Header("配置")]
    [Tooltip("生成距离")]
    public float spawnDistance = 8f;

    [Tooltip("是否自动贴地")]
    public bool snapToGround = true;

    private GameObject lastGeneratedModel;

    void Update()
    {
        // G键 - 生成狗模型
        if (Input.GetKeyDown(KeyCode.G))
        {
            Debug.Log("生成狗模型...");
            GenerateModel(GetDogJson(), "SimpleDog");
        }

        // H键 - 生成房子模型
        if (Input.GetKeyDown(KeyCode.H))
        {
            Debug.Log("生成房子模型...");
            GenerateModel(GetHouseJson(), "SimpleHouse");
        }

        // T键 - 生成树模型
        if (Input.GetKeyDown(KeyCode.T))
        {
            Debug.Log("生成树模型...");
            GenerateModel(GetTreeJson(), "SimpleTree");
        }

        // C键 - 清除所有模型
        if (Input.GetKeyDown(KeyCode.C))
        {
            Debug.Log("清除所有生成的模型...");
            ClearAllModels();
        }
    }

    /// <summary>
    /// 生成模型
    /// </summary>
    void GenerateModel(string jsonData, string modelName)
    {
        // 创建临时GameObject
        GameObject generatorObj = new GameObject("TempGenerator");
        VoxelModelGenerator generator = generatorObj.AddComponent<VoxelModelGenerator>();

        // 配置生成器
        generator.jsonData = jsonData;
        generator.generateOnStart = false;
        generator.spawnDistanceFromPlayer = spawnDistance;
        generator.snapToGround = snapToGround;

        // 查找玩家
        generator.player = Camera.main?.transform;
        if (generator.player == null)
        {
            Debug.LogWarning("未找到主相机，使用默认位置");
        }

        // 查找地形生成器
        generator.terrainGenerator = FindObjectOfType<TerrainGenerator>();

        // 生成模型
        generator.GenerateAndSpawnModel();

        // 销毁临时生成器
        Destroy(generatorObj);

        Debug.Log($"✅ {modelName} 生成成功！");
    }

    /// <summary>
    /// 清除所有生成的模型
    /// </summary>
    void ClearAllModels()
    {
        // 查找所有生成的模型并删除
        string[] modelNames = { "SimpleDog", "SimpleHouse", "SimpleTree" };
        int count = 0;

        foreach (string name in modelNames)
        {
            GameObject[] models = GameObject.FindGameObjectsWithTag("Untagged");
            foreach (GameObject obj in models)
            {
                if (obj.name == name)
                {
                    Destroy(obj);
                    count++;
                }
            }
        }

        Debug.Log($"已清除 {count} 个模型");
    }

    /// <summary>
    /// 狗模型JSON
    /// 一只简单的体素狗，包含身体、四条腿、头部和尾巴
    /// </summary>
    string GetDogJson()
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

    /// <summary>
    /// 房子模型JSON
    /// 一个简单的小房子，包含墙壁、屋顶和门
    /// </summary>
    string GetHouseJson()
    {
        return @"{
  ""name"": ""SimpleHouse"",
  ""size"": {""x"": 7, ""y"": 8, ""z"": 7},
  ""voxels"": [
    {""x"": 0, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 1, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 2, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 3, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 4, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 5, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 0, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 1, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 2, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 3, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 4, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 5, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 6, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 0, ""z"": 1, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 0, ""z"": 2, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 0, ""z"": 3, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 0, ""z"": 4, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 0, ""z"": 5, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 1, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 2, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 3, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 4, ""blockType"": ""Stone""},
    {""x"": 6, ""y"": 0, ""z"": 5, ""blockType"": ""Stone""},
    {""x"": 0, ""y"": 1, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 1, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 1, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 1, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 1, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 1, ""z"": 1, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 1, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 1, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 1, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 1, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 1, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 1, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 2, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 1, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 2, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 1, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 2, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 0, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 2, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 3, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 4, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 5, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 6, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 1, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 0, ""y"": 3, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 1, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 2, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 3, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 4, ""blockType"": ""Dirt""},
    {""x"": 6, ""y"": 3, ""z"": 5, ""blockType"": ""Dirt""},
    {""x"": 1, ""y"": 4, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 4, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 4, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 4, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 4, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 4, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 4, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 4, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 4, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 4, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 5, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 5, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 5, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 5, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 5, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 5, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 5, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 5, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 5, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 5, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 6, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 6, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 6, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 7, ""z"": 3, ""blockType"": ""Leaves""}
  ]
}";
    }

    /// <summary>
    /// 树模型JSON
    /// 一棵简单的树，包含树干和树冠
    /// </summary>
    string GetTreeJson()
    {
        return @"{
  ""name"": ""SimpleTree"",
  ""size"": {""x"": 7, ""y"": 12, ""z"": 7},
  ""voxels"": [
    {""x"": 3, ""y"": 0, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 3, ""y"": 1, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 3, ""y"": 2, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 3, ""y"": 3, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 3, ""y"": 4, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 3, ""y"": 5, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 3, ""y"": 6, ""z"": 3, ""blockType"": ""Trunk""},
    {""x"": 1, ""y"": 7, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 7, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 7, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 7, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 7, ""z"": 1, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 7, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 7, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 7, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 7, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 7, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 7, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 7, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 7, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 7, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 7, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 7, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 7, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 7, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 7, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 7, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 1, ""y"": 7, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 7, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 7, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 7, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 5, ""y"": 7, ""z"": 5, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 8, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 8, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 8, ""z"": 2, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 8, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 8, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 8, ""z"": 3, ""blockType"": ""Leaves""},
    {""x"": 2, ""y"": 8, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 8, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 4, ""y"": 8, ""z"": 4, ""blockType"": ""Leaves""},
    {""x"": 3, ""y"": 9, ""z"": 3, ""blockType"": ""Leaves""}
  ]
}";
    }
}
