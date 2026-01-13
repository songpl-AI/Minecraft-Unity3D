using UnityEngine;
// using XLua;

/// <summary>
/// Unity C# 脚本 - 使用 xLua 调用 VoxelMeshBuilder
/// 
/// 【功能】
/// 1. 加载 Lua 脚本
/// 2. 调用 Lua 中的 VoxelMeshBuilder
/// 3. 将生成的 Mesh 应用到 GameObject
/// 
/// 【使用方法】
/// 1. 将此脚本挂载到 GameObject 上
/// 2. 确保 VoxelMeshBuilder.lua 和 VoxelMeshBuilderExample.lua 在正确的路径
/// 3. 运行游戏
/// </summary>
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class VoxelMeshBuilderLuaTest : MonoBehaviour
{
    [Header("Lua 脚本配置")]
    [Tooltip("Lua 脚本文件（TextAsset）")]
    public TextAsset luaScript;
    
    [Header("测试选项")]
    [Tooltip("选择要生成的测试类型")]
    public TestType testType = TestType.SimpleCube;
    
    [Header("材质配置")]
    [Tooltip("体素材质")]
    public Material voxelMaterial;
    
    // 测试类型枚举
    public enum TestType
    {
        SimpleCube,          // 简单立方体
        MinecraftTerrain     // Minecraft风格地形
    }
    
    // xLua 环境
    // private LuaEnv luaEnv;
    
    void Start()
    {
        // 初始化 xLua 环境
        InitLuaEnv();
        
        // 生成体素 Mesh
        GenerateVoxelMesh();
    }
    
    /// <summary>
    /// 初始化 xLua 环境
    /// </summary>
    void InitLuaEnv()
    {
        // luaEnv = new LuaEnv();
        //
        // // 设置 Lua 脚本加载路径（可以从 Resources 或其他位置加载）
        // luaEnv.AddLoader(CustomLoader);
    }
    
    /// <summary>
    /// 自定义 Lua 加载器（从 Resources 加载）
    /// </summary>
    byte[] CustomLoader(ref string filepath)
    {
        // 从 Resources/LuaScripts 文件夹加载
        string path = "LuaScripts/" + filepath.Replace('.', '/');
        TextAsset luaFile = Resources.Load<TextAsset>(path);
        
        if (luaFile != null)
        {
            return luaFile.bytes;
        }
        
        // 如果没有找到，尝试直接从 Resources 根目录加载
        luaFile = Resources.Load<TextAsset>(filepath);
        if (luaFile != null)
        {
            return luaFile.bytes;
        }
        
        Debug.LogWarning($"Lua 文件未找到: {filepath}");
        return null;
    }
    
    /// <summary>
    /// 生成体素 Mesh
    /// </summary>
    void GenerateVoxelMesh()
    {
        try
        {
            // 方法1: 如果使用 TextAsset
            if (luaScript != null)
            {
                // luaEnv.DoString(luaScript.text);
            }
            // 方法2: 直接执行 Lua 代码
            else
            {
                // 加载 VoxelMeshBuilderExample 模块
                // luaEnv.DoString(@"
                //     VoxelModule = require('VoxelMeshBuilderExample')
                // ");
            }
            
            // 调用 Lua 函数生成 Mesh
            Mesh mesh = null;
            
            switch (testType)
            {
                case TestType.SimpleCube:
                    mesh = CallLuaFunction<Mesh>("VoxelModule.CreateSimpleCube");
                    break;
                    
                case TestType.MinecraftTerrain:
                    mesh = CallLuaFunction<Mesh>("VoxelModule.CreateMinecraftTerrain");
                    break;
            }
            
            // 应用 Mesh
            if (mesh != null)
            {
                MeshFilter meshFilter = GetComponent<MeshFilter>();
                meshFilter.mesh = mesh;
                
                // 设置材质
                if (voxelMaterial != null)
                {
                    MeshRenderer meshRenderer = GetComponent<MeshRenderer>();
                    meshRenderer.material = voxelMaterial;
                }
                
                Debug.Log($"✅ 体素 Mesh 生成成功! 顶点数: {mesh.vertexCount}, 三角形数: {mesh.triangles.Length / 3}");
            }
            else
            {
                Debug.LogError("❌ Mesh 生成失败");
            }
        }
        catch (System.Exception e)
        {
            Debug.LogError($"❌ Lua 执行错误: {e.Message}\n{e.StackTrace}");
        }
    }
    
    /// <summary>
    /// 调用 Lua 函数
    /// </summary>
    T CallLuaFunction<T>(string functionPath)
    {
        // var func = luaEnv.Global.GetInPath<System.Func<T>>(functionPath);
        // if (func != null)
        // {
        //     return func();
        // }
        // else
        // {
        //     Debug.LogError($"❌ 未找到 Lua 函数: {functionPath}");
        //     return default(T);
        // }
        return default(T);
    }
    
    void OnDestroy()
    {
        // 释放 xLua 环境
        // if (luaEnv != null)
        // {
        //     luaEnv.Dispose();
        // }
    }
    
    /// <summary>
    /// 在编辑器中手动触发生成
    /// </summary>
    [ContextMenu("重新生成 Mesh")]
    void RegenerateMesh()
    {
        // 清理旧的 Mesh
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        if (meshFilter.mesh != null)
        {
            DestroyImmediate(meshFilter.mesh);
        }
        
        // 重新初始化
        // if (luaEnv == null)
        // {
        //     InitLuaEnv();
        // }
        
        // 生成新的 Mesh
        GenerateVoxelMesh();
    }
}
