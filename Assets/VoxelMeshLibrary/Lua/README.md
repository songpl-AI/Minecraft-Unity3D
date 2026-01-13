# VoxelMeshBuilder - Lua 版本

## 📁 文件结构

```
VoxelMeshLibrary/Lua/
├── README.md                           # 本文件
├── VoxelMeshBuilder.lua                # 核心：体素 Mesh 构建器
├── VoxelMeshBuilderExample.lua         # 示例：使用示例和测试数据
├── VoxelMeshBuilderLuaTest.cs          # Unity C# 测试脚本
└── VoxelMeshBuilder_Lua使用说明.md      # 详细使用文档
```

## 📋 概述

这是 VoxelMeshLibrary 的 xLua 版本，将 C# 实现转换为 Lua 脚本，可在 Unity 中通过 xLua 动态生成体素 Mesh。

## 🚀 快速开始

### 1. 前置条件
- Unity 项目已安装 xLua 插件
- 了解基本的 Lua 语法

### 2. 使用方式

#### 方式 A：在 Unity 场景中测试

1. 创建一个空 GameObject
2. 添加 `VoxelMeshBuilderLuaTest` 组件（从本文件夹拖入）
3. 配置参数：
   - **Test Type**: 选择 `SimpleCube` 或 `MinecraftTerrain`
   - **Voxel Material**: 拖入材质
4. 运行场景

#### 方式 B：在代码中调用

```csharp
using XLua;

public class MyVoxelScript : MonoBehaviour
{
    private LuaEnv luaEnv;
    
    void Start()
    {
        luaEnv = new LuaEnv();
        
        // 加载 Lua 脚本（确保路径正确）
        TextAsset luaScript = Resources.Load<TextAsset>("VoxelMeshLibrary/Lua/VoxelMeshBuilderExample");
        luaEnv.DoString(luaScript.text);
        
        // 调用 Lua 函数生成 Mesh
        var createMesh = luaEnv.Global.GetInPath<System.Func<Mesh>>("VoxelModule.CreateSimpleCube");
        Mesh mesh = createMesh();
        
        // 应用到 MeshFilter
        GetComponent<MeshFilter>().mesh = mesh;
    }
}
```

### 3. 在 Lua 中自定义

```lua
-- 导入模块
local VoxelMeshModule = require("VoxelMeshBuilder")
local VoxelMeshBuilder = VoxelMeshModule.VoxelMeshBuilder

-- 创建自定义体素数据
local myVoxelData = {
    Size = CS.UnityEngine.Vector3Int(10, 10, 10),
    
    GetVoxel = function(self, x, y, z)
        -- 返回体素类型
        return self.data[x][y][z]
    end,
    
    IsEmpty = function(self, voxel)
        return voxel == 0
    end,
    
    GetUVs = function(self, voxel, face)
        return {
            CS.UnityEngine.Vector2(0, 0),
            CS.UnityEngine.Vector2(0, 1),
            CS.UnityEngine.Vector2(1, 1),
            CS.UnityEngine.Vector2(1, 0)
        }
    end
}

-- 生成 Mesh
local mesh = VoxelMeshBuilder:BuildMesh(myVoxelData)
return mesh
```

## 📚 核心 API

### VoxelMeshBuilder

```lua
-- 构建体素 Mesh
local mesh = VoxelMeshBuilder:BuildMesh(voxelData)
```

### VoxelFace 枚举

```lua
VoxelFace = {
    Top = 0,      -- Y+
    Bottom = 1,   -- Y-
    Front = 2,    -- Z-
    Back = 3,     -- Z+
    Right = 4,    -- X+
    Left = 5      -- X-
}
```

### IVoxelData 接口

实现以下方法：

| 方法/属性 | 说明 | 返回类型 |
|----------|------|---------|
| `Size` | 渲染区域尺寸（不含边界） | `Vector3Int` |
| `GetVoxel(x, y, z)` | 获取指定位置的体素 | 任意类型 |
| `IsEmpty(voxel)` | 判断体素是否为空 | `boolean` |
| `GetUVs(voxel, face)` | 获取体素面的 UV 坐标 | `Vector2[4]` |

## 📖 详细文档

请查看 [VoxelMeshBuilder_Lua使用说明.md](./VoxelMeshBuilder_Lua使用说明.md) 获取：
- 完整 API 文档
- 高级使用示例
- 性能优化建议
- 故障排查指南

## 🔗 相关文档

- [VoxelMeshLibrary C# 版本](../README.md)
- [快速参考](../快速参考.md)
- [移植指南](../移植指南.md)

## ⚡ 性能说明

Lua 版本性能约为 C# 版本的 40-60%，但提供了以下优势：
- ✅ 热更新能力
- ✅ 更灵活的脚本修改
- ✅ 无需重新编译
- ✅ 适合快速原型开发

## 💡 使用场景

推荐在以下场景使用 Lua 版本：
- 需要热更新的体素系统
- 快速原型和实验性功能
- 由非程序员（如策划）配置的体素规则
- MOD 支持和用户自定义内容

对于性能要求极高的场景，建议使用 C# 版本。

## 📝 示例项目

本文件夹包含两个完整示例：

### 1. SimpleCube - 简单立方体
生成一个 3×3×3 的空心立方体

### 2. MinecraftTerrain - 分层地形
生成 Minecraft 风格的多层地形，包含：
- 石头底层
- 泥土中层
- 草方块顶层
- 中心空洞

## 🤝 支持

如有问题或建议，请参考：
1. 详细使用说明文档
2. 示例代码注释
3. Unity Console 错误信息

---

**版本**: 1.0  
**日期**: 2026-01-13  
**作者**: AI Assistant
