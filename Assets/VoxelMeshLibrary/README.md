# VoxelMeshLibrary - 独立的体素Mesh合并库

> 一个完全独立、可移植的Unity体素Mesh生成器，采用面剔除和Mesh合并优化

## 📦 特性

- ✅ **完全独立** - 零外部依赖，只使用Unity内置类
- ✅ **类型无关** - 通过接口工作，支持任意体素类型系统
- ✅ **高性能** - 面剔除 + Mesh合并，节省90%+顶点
- ✅ **易于集成** - 清晰的接口，5分钟集成到现有项目
- ✅ **完整文档** - 包含3个使用示例和详细的移植指南

## 🚀 快速开始

### 1. 复制文件到你的项目

```
YourProject/
├── VoxelMeshLibrary/
│   ├── IVoxelData.cs           # 接口定义
│   ├── VoxelMeshBuilder.cs     # 核心构建器
│   └── Examples/               # 使用示例（可选）
```

### 2. 实现接口

```csharp
using VoxelMeshLibrary;

public class MyVoxelData : IVoxelData<int>
{
    private int[,,] voxels;
    private Vector3Int size;

    public int GetVoxel(int x, int y, int z) 
    {
        return voxels[x, y, z];
    }

    public bool IsEmpty(int voxel) 
    {
        return voxel == 0;  // 0表示空
    }

    public Vector2[] GetUVs(int voxel, VoxelFace face) 
    {
        // 返回该体素该面的UV坐标（4个顶点）
        return GetMyUVs(voxel, face);
    }

    public Vector3Int Size => size;
}
```

### 3. 生成Mesh

```csharp
// 1. 准备数据
int[,,] voxels = new int[10, 10, 10];
// ... 填充体素数据 ...

// 2. 创建适配器
var voxelData = new MyVoxelData(voxels, new Vector3Int(8, 8, 8));

// 3. 生成Mesh
Mesh mesh = VoxelMeshBuilder.BuildMesh(voxelData);

// 4. 应用到GameObject
meshFilter.mesh = mesh;
```

完成！🎉

## 📚 核心概念

### 面剔除（Face Culling）

只渲染暴露在"空"体素旁边的面：

```
场景：
□□□
□■□  → 中间的方块只渲染顶面（其他5个面被遮挡）
■■■

结果：节省83%的顶点（6面→1面）
```

### Mesh合并

将所有体素合并为单个Mesh：

```
传统方式：
1000个方块 × 6个面 × 独立GameObject = 6000个Draw Call ❌

合并方式：
1000个方块 → 面剔除 → 合并 = 1个Draw Call ✅
```

### 边界层设计

体素数组比实际尺寸大2：

```
实际尺寸: 8x8x8
数组大小: 10x10x10 ([0-9])

[0]      - 边界层（存储左侧相邻数据）
[1-8]    - 实际渲染区域
[9]      - 边界层（存储右侧相邻数据）
```

这样可以安全地检查边缘体素的相邻体素。

## 📖 接口说明

### IVoxelData<T>

```csharp
public interface IVoxelData<T>
{
    // 获取指定位置的体素
    T GetVoxel(int x, int y, int z);

    // 判断体素是否为"空"（不渲染）
    bool IsEmpty(T voxel);

    // 获取体素指定面的UV坐标（4个顶点）
    Vector2[] GetUVs(T voxel, VoxelFace face);

    // 实际渲染区域尺寸
    Vector3Int Size { get; }
}
```

### VoxelFace 枚举

```csharp
public enum VoxelFace
{
    Top,      // Y+ (顶面)
    Bottom,   // Y- (底面)
    Front,    // Z- (前面)
    Back,     // Z+ (后面)
    Right,    // X+ (右面)
    Left      // X- (左面)
}
```

## 💡 使用示例

### 示例1：Minecraft风格

```csharp
// 适配现有的BlockType系统
public class MinecraftVoxelData : IVoxelData<BlockType>
{
    public bool IsEmpty(BlockType voxel) 
    {
        return voxel == BlockType.Air;
    }

    public Vector2[] GetUVs(BlockType voxel, VoxelFace face) 
    {
        Block block = Block.blocks[voxel];
        switch (face)
        {
            case VoxelFace.Top: return block.topPos.GetUVs();
            case VoxelFace.Bottom: return block.bottomPos.GetUVs();
            default: return block.sidePos.GetUVs();
        }
    }
}
```

### 示例2：简单整数系统

```csharp
// 使用int: 0=空, 1=土, 2=石头
public class SimpleVoxelData : IVoxelData<int>
{
    public bool IsEmpty(int voxel) 
    {
        return voxel == 0;
    }

    public Vector2[] GetUVs(int voxel, VoxelFace face) 
    {
        // 简单映射：每个类型占用16x16图集的一格
        float tileSize = 1f / 16f;
        int tileX = (voxel - 1) % 16;
        int tileY = (voxel - 1) / 16;
        
        float x = tileX * tileSize;
        float y = tileY * tileSize;
        
        return new Vector2[]
        {
            new Vector2(x, y),
            new Vector2(x, y + tileSize),
            new Vector2(x + tileSize, y + tileSize),
            new Vector2(x + tileSize, y)
        };
    }
}
```

### 示例3：自定义体素类

```csharp
// 复杂的体素类（带元数据）
public class CustomVoxel
{
    public VoxelType Type;
    public Color Tint;
    public float Damage;
}

public class CustomVoxelData : IVoxelData<CustomVoxel>
{
    public bool IsEmpty(CustomVoxel voxel) 
    {
        // 空气和玻璃都认为是透明
        return voxel == null || 
               voxel.Type == VoxelType.Air || 
               voxel.Type == VoxelType.Glass;
    }

    public Vector2[] GetUVs(CustomVoxel voxel, VoxelFace face) 
    {
        // 根据类型和面方向返回不同UV
        // 可以考虑损坏程度、颜色叠加等
        return GetComplexUVs(voxel, face);
    }
}
```

## 📊 性能数据

基于8x8x8的测试模型：

| 方块数 | 传统方式 | 面剔除后 | 优化率 |
|-------|---------|---------|--------|
| 512 | 3,072面 | 384面 | 87.5% |
| 顶点数 | 12,288 | 1,536 | 87.5% |
| 三角形 | 6,144 | 768 | 87.5% |

实际场景（内部有空腔）优化率可达90%+！

## 🔧 移植到其他项目

### 步骤1：复制核心文件

只需要2个文件：
- `IVoxelData.cs`
- `VoxelMeshBuilder.cs`

### 步骤2：实现IVoxelData接口

根据你的体素类型系统实现4个方法。

### 步骤3：调用BuildMesh

```csharp
Mesh mesh = VoxelMeshBuilder.BuildMesh(yourVoxelData);
```

### 完整示例（从零开始）

```csharp
using UnityEngine;
using VoxelMeshLibrary;

public class QuickStart : MonoBehaviour
{
    // 最简单的实现
    public class SimpleData : IVoxelData<int>
    {
        int[,,] data = new int[10,10,10];
        
        public SimpleData() 
        {
            // 创建一个3x3x3的立方体
            for(int x=3; x<6; x++)
                for(int y=3; y<6; y++)
                    for(int z=3; z<6; z++)
                        data[x,y,z] = 1;
        }
        
        public int GetVoxel(int x, int y, int z) => data[x,y,z];
        public bool IsEmpty(int v) => v == 0;
        public Vector2[] GetUVs(int v, VoxelFace f) => new Vector2[4]; // 简化
        public Vector3Int Size => new Vector3Int(8,8,8);
    }

    void Start()
    {
        // 3行代码生成体素模型！
        Mesh mesh = VoxelMeshBuilder.BuildMesh(new SimpleData());
        GetComponent<MeshFilter>().mesh = mesh;
        GetComponent<MeshCollider>().sharedMesh = mesh;
    }
}
```

## 🎓 高级用法

### 自定义顶点生成

如果需要修改顶点位置（如圆角、斜面），可以继承并重写：

```csharp
public static class CustomVoxelMeshBuilder
{
    // 复制VoxelMeshBuilder.cs的代码
    // 修改AddFaceVertices方法
    // 添加你的自定义逻辑
}
```

### 多材质支持

生成多个submesh：

```csharp
// 为不同类型的体素生成不同的submesh
// 每个submesh可以使用不同的材质
```

### LOD系统

为大模型生成不同细节级别：

```csharp
// LOD 0: 完整细节
Mesh detailedMesh = VoxelMeshBuilder.BuildMesh(fullData);

// LOD 1: 1/2细节（跳过一些体素）
Mesh mediumMesh = VoxelMeshBuilder.BuildMesh(halfData);

// LOD 2: 1/4细节
Mesh lowMesh = VoxelMeshBuilder.BuildMesh(quarterData);
```

## ❓ 常见问题

### Q: 为什么数组大小要+2？

A: 边界层用于检测边缘体素的相邻体素。如果不加边界层，检测`blocks[0, y, z]`的左侧时会越界。

### Q: 如何处理透明方块（如玻璃）？

A: 在`IsEmpty()`中返回`true`，让后面的面也能渲染出来。

### Q: 性能如何？

A: 对于16x16x16的区块（4096个方块），生成Mesh通常<10ms。面剔除后通常只有10-20%的面需要渲染。

### Q: 支持动画吗？

A: 当前版本生成静态Mesh。如果需要动画，可以：
1. 重新生成Mesh（适合低频率变化）
2. 使用Shader动画（适合波动、流动效果）
3. 使用骨骼动画（需要额外实现）

### Q: 可以用于非立方体体素吗？

A: 可以！修改`AddFaceVertices`方法中的顶点位置即可。例如生成六边形、八面体等。

## 📝 授权

本库为教学目的创建，可自由使用、修改和分发。

## 🙏 致谢

- 基于Minecraft的体素系统设计
- 灵感来自Greedy Meshing算法
- Unity社区的优秀教程

## 📮 联系

如有问题或建议，欢迎提issue！

---

**版本**: 1.0  
**更新日期**: 2026-01-12  
**兼容性**: Unity 2019.4+

**核心理念**: 简单、高效、可移植 🚀
