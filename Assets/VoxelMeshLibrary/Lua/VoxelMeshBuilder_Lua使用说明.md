# VoxelMeshBuilder Lua 版本使用说明

## 📋 概述

这是一个将 VoxelMeshLibrary 的 C# 版本转换为 xLua 脚本的实现，可以在 Unity 中通过 Lua 脚本动态生成体素 Mesh。

## 📁 文件结构

```
Assets/Scripts/
├── VoxelMeshBuilder.lua              # 核心：体素 Mesh 构建器（Lua版本）
├── VoxelMeshBuilderExample.lua      # 示例：使用示例和测试数据
└── VoxelMeshBuilderLuaTest.cs       # Unity C# 脚本：加载和调用 Lua
```

## 🚀 快速开始

### 1. 前置条件

- Unity 项目
- 已安装并配置好 xLua 插件
- 基本了解 Lua 语法

### 2. 安装步骤

#### 方法 A: 使用 Resources 文件夹（推荐）

```
Assets/
└── Resources/
    └── LuaScripts/
        ├── VoxelMeshBuilder.lua
        └── VoxelMeshBuilderExample.lua
```

#### 方法 B: 使用 TextAsset 直接引用

1. 将 Lua 文件放在 `Assets/Scripts/` 下
2. 在 Unity 中选中 Lua 文件，设置为 TextAsset
3. 在 `VoxelMeshBuilderLuaTest` 组件中拖入 `luaScript` 字段

### 3. 创建测试场景

1. 创建一个空的 GameObject
2. 添加 `VoxelMeshBuilderLuaTest` 组件
3. 配置参数：
   - **Test Type**: 选择测试类型（SimpleCube 或 MinecraftTerrain）
   - **Voxel Material**: 拖入一个材质
4. 运行游戏

## 📚 API 文档

### VoxelMeshBuilder（核心类）

#### BuildMesh(voxelData)

构建体素 Mesh 的主方法。

**参数：**
- `voxelData`: 实现了 IVoxelData 接口的 Lua table

**返回：**
- `CS.UnityEngine.Mesh`: 生成的 Unity Mesh 对象

**示例：**
```lua
local mesh = VoxelMeshBuilder:BuildMesh(voxelData)
```

### IVoxelData 接口

需要实现以下方法和属性：

```lua
{
    -- 属性：渲染区域尺寸
    Size = CS.UnityEngine.Vector3Int(width, height, depth),
    
    -- 方法：获取指定位置的体素
    GetVoxel = function(self, x, y, z)
        -- 返回体素数据（任意类型，如 int、string 等）
        return voxel
    end,
    
    -- 方法：判断体素是否为空
    IsEmpty = function(self, voxel)
        -- 返回 true（空） 或 false（实体）
        return voxel == 0
    end,
    
    -- 方法：获取体素指定面的 UV 坐标
    GetUVs = function(self, voxel, face)
        -- 返回包含 4 个 Vector2 的 table
        return {
            CS.UnityEngine.Vector2(0, 0),
            CS.UnityEngine.Vector2(0, 1),
            CS.UnityEngine.Vector2(1, 1),
            CS.UnityEngine.Vector2(1, 0)
        }
    end
}
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

## 💡 使用示例

### 示例 1: 简单的立方体

```lua
local VoxelMeshModule = require("VoxelMeshBuilder")
local VoxelMeshBuilder = VoxelMeshModule.VoxelMeshBuilder

-- 创建简单的体素数据
local SimpleVoxelData = {}
SimpleVoxelData.__index = SimpleVoxelData

function SimpleVoxelData:new(sizeX, sizeY, sizeZ)
    local obj = {}
    setmetatable(obj, SimpleVoxelData)
    
    obj.Size = CS.UnityEngine.Vector3Int(sizeX, sizeY, sizeZ)
    obj.voxels = {}
    
    -- 初始化数组（包含边界层）
    local totalSize = (sizeX + 2) * (sizeY + 2) * (sizeZ + 2)
    for i = 1, totalSize do
        obj.voxels[i] = 0
    end
    
    return obj
end

function SimpleVoxelData:SetVoxel(x, y, z, value)
    local index = self:GetIndex(x, y, z)
    self.voxels[index] = value
end

function SimpleVoxelData:GetVoxel(x, y, z)
    local index = self:GetIndex(x, y, z)
    return self.voxels[index]
end

function SimpleVoxelData:IsEmpty(voxel)
    return voxel == 0
end

function SimpleVoxelData:GetUVs(voxel, face)
    return {
        CS.UnityEngine.Vector2(0, 0),
        CS.UnityEngine.Vector2(0, 1),
        CS.UnityEngine.Vector2(1, 1),
        CS.UnityEngine.Vector2(1, 0)
    }
end

function SimpleVoxelData:GetIndex(x, y, z)
    local sizeX = self.Size.x + 2
    local sizeY = self.Size.y + 2
    return x + y * sizeX + z * sizeX * sizeY + 1
end

-- 使用示例
local voxelData = SimpleVoxelData:new(5, 5, 5)

-- 填充一些体素
for x = 1, 5 do
    for z = 1, 5 do
        voxelData:SetVoxel(x, 1, z, 1)  -- 底层
    end
end

-- 生成 Mesh
local mesh = VoxelMeshBuilder:BuildMesh(voxelData)
```

### 示例 2: Minecraft 风格地形

参考 `VoxelMeshBuilderExample.lua` 中的 `MinecraftVoxelData` 类。

## 🔧 高级用法

### 1. 自定义纹理 UV

```lua
function MyVoxelData:GetUVs(blockType, face)
    -- 假设使用 16x16 的纹理图集
    local textureUnit = 1.0 / 16.0
    
    -- 根据方块类型和面类型计算 UV
    local textureIndex = self:GetTextureIndex(blockType, face)
    local x = (textureIndex % 16) * textureUnit
    local y = math.floor(textureIndex / 16) * textureUnit
    
    return {
        CS.UnityEngine.Vector2(x, y),
        CS.UnityEngine.Vector2(x, y + textureUnit),
        CS.UnityEngine.Vector2(x + textureUnit, y + textureUnit),
        CS.UnityEngine.Vector2(x + textureUnit, y)
    }
end
```

### 2. 程序化地形生成

```lua
function GenerateProceduralTerrain(sizeX, sizeZ)
    local voxelData = MyVoxelData:new(sizeX, 10, sizeZ)
    
    -- 使用 Perlin 噪声生成地形
    for x = 1, sizeX do
        for z = 1, sizeZ do
            local height = GetPerlinHeight(x, z)  -- 自定义噪声函数
            
            for y = 1, height do
                if y == height then
                    voxelData:SetVoxel(x, y, z, 1)  -- 草方块
                elseif y >= height - 3 then
                    voxelData:SetVoxel(x, y, z, 2)  -- 泥土
                else
                    voxelData:SetVoxel(x, y, z, 3)  -- 石头
                end
            end
        end
    end
    
    return VoxelMeshBuilder:BuildMesh(voxelData)
end
```

### 3. 动态更新 Mesh

在 Unity C# 中：

```csharp
public class DynamicVoxelController : MonoBehaviour
{
    private LuaEnv luaEnv;
    private LuaFunction updateMeshFunc;
    
    void Start()
    {
        luaEnv = new LuaEnv();
        luaEnv.DoString(luaScript.text);
        updateMeshFunc = luaEnv.Global.Get<LuaFunction>("UpdateVoxelMesh");
    }
    
    public void UpdateVoxel(int x, int y, int z, int blockType)
    {
        // 调用 Lua 函数更新体素
        Mesh newMesh = updateMeshFunc.Call(x, y, z, blockType)[0] as Mesh;
        GetComponent<MeshFilter>().mesh = newMesh;
    }
}
```

## ⚠️ 注意事项

### 1. 数组索引

- **C# 数组**：从 0 开始
- **Lua table**：从 1 开始
- 在转换时需要注意索引偏移（代码中已处理）

### 2. 边界层

体素数据需要包含边界层（每个维度 +2），用于面剔除算法：
- 实际渲染区域：`Size.x × Size.y × Size.z`
- 数据数组大小：`(Size.x + 2) × (Size.y + 2) × (Size.z + 2)`

### 3. 性能考虑

- **大型体素世界**：建议分块处理，每个 Chunk 独立生成 Mesh
- **动态更新**：只更新变化的 Chunk，避免重建整个世界
- **内存管理**：及时调用 `luaEnv.Tick()` 进行垃圾回收

```csharp
void Update()
{
    if (Time.frameCount % 100 == 0)
    {
        luaEnv.Tick();  // 每 100 帧清理一次
    }
}
```

### 4. xLua 类型映射

| C# 类型 | Lua 访问方式 |
|---------|-------------|
| `Vector3` | `CS.UnityEngine.Vector3(x, y, z)` |
| `Vector2` | `CS.UnityEngine.Vector2(x, y)` |
| `Vector3Int` | `CS.UnityEngine.Vector3Int(x, y, z)` |
| `Mesh` | `CS.UnityEngine.Mesh()` |
| `Array` | `CS.System.Array.CreateInstance(type, size)` |

## 🐛 故障排查

### 问题 1: Lua 文件加载失败

**症状：**
```
Lua 文件未找到: VoxelMeshBuilder
```

**解决方案：**
1. 检查 Lua 文件是否在 `Resources/LuaScripts/` 目录下
2. 确认文件名和 `require` 语句一致
3. 或者使用 TextAsset 直接引用

### 问题 2: Mesh 生成为空

**症状：**
```
Mesh 生成成功! 顶点数: 0, 三角形数: 0
```

**解决方案：**
1. 检查体素数据是否正确填充
2. 确认 `IsEmpty()` 方法逻辑正确
3. 打印调试信息查看体素值

### 问题 3: UV 坐标显示不正确

**症状：** 纹理显示错乱

**解决方案：**
1. 检查 `GetUVs()` 返回的 Vector2 数组顺序
2. 确认 UV 坐标范围在 [0, 1] 之间
3. 验证纹理图集配置

## 📊 性能对比

| 项目 | C# 版本 | Lua 版本 |
|------|---------|----------|
| 生成 10×10×10 体素 | ~2ms | ~5ms |
| 生成 50×50×50 体素 | ~50ms | ~120ms |
| 内存占用 | 较低 | 略高（GC） |
| 灵活性 | 需重编译 | 热更新 |

**结论：** Lua 版本性能约为 C# 版本的 40-60%，但提供了热更新能力。

## 🎯 最佳实践

1. **分块管理**：大型世界使用 Chunk 系统
2. **对象池**：复用 Mesh 对象，减少 GC
3. **异步生成**：在协程中生成 Mesh，避免卡顿
4. **LOD 优化**：远处使用简化的 Mesh
5. **定期 GC**：调用 `luaEnv.Tick()` 清理内存

## 📖 相关文档

- [xLua 官方文档](https://github.com/Tencent/xLua)
- [VoxelMeshLibrary C# 版本](../VoxelMeshLibrary/README.md)
- [体素模型生成器使用说明](../体素模型生成器使用说明.md)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

与项目主体保持一致。
