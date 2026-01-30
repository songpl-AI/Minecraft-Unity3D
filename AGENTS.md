# AGENTS.md - Agent Guidelines for Minecraft-Unity3D

## Project Overview

This is a Unity-based Minecraft clone built in C# 9.0, featuring procedural terrain generation, voxel mesh optimization, and first-person player controls.

**Unity Version**: 2022.3.56f1c1
**Language**: C# 9.0
**Target Framework**: .NET Framework 4.7.1

---

## Build & Test Commands

### Build
```bash
# Unity projects are built via Unity Editor, not CLI
# Use Unity Editor > Build Settings to configure and build
# Or use Unity command line:
/Applications/Unity/Hub/Editor/2022.3.56f1c1/Unity.app/Contents/MacOS/Unity \
  -quit -batchmode -nographics \
  -projectPath /Volumes/ExtremeSSD/AIProject/Minecraft-Unity3D \
  -buildTarget StandaloneOSX \
  -buildOSXUniversalPlayer Build/Minecraft.app
```

### Run Tests
```bash
# No automated test framework configured.
# Manual testing via in-game scripts:
# - VoxelModelTestV2.cs: Press G/H/T/C for manual tests
# - VoxelMeshBuilderLuaTest.cs: Lua integration tests
```

### Lint/Analyze
```bash
# Unity handles code analysis via built-in Roslyn analyzers
# Check Unity Console for warnings/errors
# Warning Level: 4 (configured in Assembly-CSharp.csproj)
```

---

## Code Style Guidelines

### Imports & Using Statements
```csharp
// Order: System → System.Collections → Unity → Project namespaces
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// Namespace usage:
namespace VoxelMeshLibrary
{
    // Code here
}
```

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Classes | PascalCase | `TerrainGenerator`, `PlayerMovement` |
| Methods | PascalCase | `BuildChunk()`, `GetBlockType()` |
| Properties | PascalCase | `Speed`, `GroundDistance` |
| Fields (public) | PascalCase | `terrainChunk`, `player` |
| Fields (private) | camelCase or _camelCase | `velocity`, `controller` |
| Local Variables | camelCase | `horizontal`, `vertical` |
| Constants | PascalCase | `chunkDist` (though should be `ChunkDist`) |
| Enums | PascalCase | `BlockType`, `VoxelFace` |
| Enum Values | PascalCase | `BlockType.Grass`, `VoxelFace.Top` |
| Parameters | camelCase | `xPos`, `zPos`, `instant` |
| Namespaces | PascalCase | `VoxelMeshLibrary` |

### Formatting & Style
- **Indentation**: 4 spaces (tabs are discouraged)
- **Braces**: Allman style (opening brace on new line)
- **Spacing**: Spaces around operators, after commas
- **Line Length**: No strict limit, but prefer readable lines
- **Comments**: Extensive XML documentation (Chinese) for public APIs

```csharp
public class PlayerMovement : MonoBehaviour
{
    [Header("移动参数")]
    public float speed = 6.0f;

    private CharacterController controller;

    void Start()
    {
        controller = GetComponent<CharacterController>();
    }

    void Update()
    {
        float horizontal = Input.GetAxis("Horizontal");
        // ...
    }
}
```

### Type Safety
- **Language Version**: C# 9.0 (nullable reference types available but not enforced)
- **Avoid**: `var` for non-obvious types, `as` casting, reflection
- **Prefer**: Explicit types, `is pattern matching`, `as?` with null check

### Error Handling
```csharp
// Unity doesn't use exceptions for flow control
// Prefer:
if (controller == null)
{
    Debug.LogWarning("未找到CharacterController组件");
    return;
}

// Not:
try
{
    controller.Move(moveDirection);
}
catch (System.Exception e)
{
    Debug.LogError(e);
}
```

### Unity-Specific Patterns

#### MonoBehaviour Lifecycle
```csharp
public class Example : MonoBehaviour
{
    [Header("配置")]
    public GameObject prefab;

    [Tooltip("描述此参数的作用")]
    public float spawnDistance = 5f;

    private void Start()
    {
        // Initialization
    }

    private void Update()
    {
        // Per-frame logic
    }

    private void OnDestroy()
    {
        // Cleanup
    }
}
```

#### Coroutines for Async Operations
```csharp
IEnumerator DelayBuildChunks()
{
    while (toGenerate.Count > 0)
    {
        BuildChunk(toGenerate[0].x, toGenerate[0].z);
        toGenerate.RemoveAt(0);
        yield return new WaitForSeconds(0.2f);
    }
}
```

#### Object Pooling
```csharp
// Prefer pooling over Instantiate/Destroy
List<TerrainChunk> pooledChunks = new List<TerrainChunk>();

if (pooledChunks.Count > 0)
{
    chunk = pooledChunks[0];
    chunk.gameObject.SetActive(true);
    pooledChunks.RemoveAt(0);
}
else
{
    GameObject chunkGO = Instantiate(terrainChunk);
    chunk = chunkGO.GetComponent<TerrainChunk>();
}
```

#### Static Global State (Use Judiciously)
```csharp
// Used for global singleton-like access
public static Dictionary<ChunkPos, TerrainChunk> chunks = new Dictionary<ChunkPos, TerrainChunk>();

// Access from anywhere:
TerrainGenerator.chunks[myChunkPos].BuildMesh();
```

---

## Architecture Patterns

### Voxel System
```
Block.cs (Block definitions)
  ↓
TerrainChunk.cs (Chunk mesh generation)
  ↓
TerrainGenerator.cs (World management, object pooling)
  ↓
VoxelMeshLibrary/ (Generic mesh building)
```

### Data Flow
```
FastNoise (Procedural generation)
  → GetBlockType() (Block type determination)
  → Block.blocks[] (Block lookup)
  → BuildMesh() (Voxel mesh construction)
  → Unity MeshFilter/MeshRenderer (Rendering)
```

### Key Systems
- **TerrainGenerator**: Infinite world generation with chunk streaming
- **TerrainChunk**: 16x16x64 chunk with mesh generation
- **VoxelMeshBuilder**: Generic face-culling mesh builder
- **FastNoise**: Noise library for procedural terrain
- **PlayerMovement**: First-person character controller

---

## Documentation Standards

### XML Documentation (Chinese)
```csharp
/// <summary>
/// 玩家移动控制器 - 处理第一人称角色的移动和跳跃
///
/// 【设计原理】
/// - 使用Unity的CharacterController组件
/// - 物理模拟：自定义重力系统
///
/// 【架构位置】
/// Input → PlayerMovement → CharacterController → 物理系统
/// </summary>
public class PlayerMovement : MonoBehaviour
{
    /// <summary>
    /// 移动速度（单位/秒）
    /// </summary>
    public float speed = 6.0f;
}
```

### Comments
- Use Chinese for user-facing comments (matches existing codebase)
- English is acceptable for internal/technical comments
- Inline comments for complex algorithms (see GetBlockType for examples)

---

## Performance Considerations

### Critical Optimizations in This Codebase
1. **Face Culling**: Only render exposed faces (saves 87%+ vertices)
2. **Mesh Merging**: Single mesh per chunk vs thousands of draw calls
3. **Object Pooling**: Reuse chunk GameObjects instead of Instantiate/Destroy
4. **Coroutines**: Spread heavy work across frames (0.2s delay per chunk)
5. **Static Dictionaries**: O(1) block lookup with single initialization

### When to Optimize
- Profile first using Unity Profiler
- Chunk mesh generation is the main bottleneck
- Face culling provides 10x improvement over naive rendering

---

## Common Patterns & Idioms

### Region Directives
```csharp
#region Test Data
string GetDogJson() { /* ... */ }
string GetHouseJson() { /* ... */ }
#endregion
```

### Header Attributes
```csharp
[Header("移动参数")]
public float speed = 6.0f;

[Tooltip("检测球体半径")]
public float groundDistance = .4f;
```

### Null-Safe Component Access
```csharp
player = Camera.main?.transform;
if (generator.player == null)
{
    Debug.LogWarning("未找到主相机，使用默认位置");
}
```

---

## File Organization

```
Assets/
├── Scripts/                 # Core game logic
│   ├── Block.cs            # Block definitions
│   ├── TerrainGenerator.cs # World generation
│   ├── TerrainChunk.cs     # Chunk management
│   ├── PlayerMovement.cs   # Player controls
│   └── LoadOBJ/            # OBJ model loading
├── VoxelMeshLibrary/       # Generic voxel mesh builder
│   ├── IVoxelData.cs       # Interface
│   ├── VoxelMeshBuilder.cs # Core algorithm
│   └── Examples/           # Usage examples
└── ProjectSettings/        # Unity project settings
```

---

## Testing Guidelines

### Manual Testing
- Use `VoxelModelTestV2.cs` for quick in-game testing
- Keys: G (dog), H (house), T (tree), C (clear)
- Test terrain generation by moving player around

### Validation Checklist
- [ ] Mesh renders correctly (no holes, no missing faces)
- [ ] Performance is acceptable (< 10ms per chunk)
- [ ] Chunk loading/unloading works smoothly
- [ ] No console warnings/errors
- [ ] Object pooling is active (check for Instantiate spam)

---

## Before Committing

1. **Run Unity Editor**: Verify no console errors
2. **Test Gameplay**: Play scene, move player, generate terrain
3. **Check Performance**: Use Profiler, verify < 16.6ms (60fps)
4. **Review Changes**: Ensure no accidental Debug.Log spam
5. **Format Code**: Unity auto-formats on save (Rider/VS format)

---

## Notes for AI Agents

- **This is a Unity game project, not a traditional software project**
- **No unit tests** - verification is done via gameplay testing
- **Code comments are in Chinese** - follow this convention for new code
- **Unity Editor is required** for building and testing
- **Performance is critical** - voxel systems are CPU-bound
- **Face culling is the core optimization** - never remove or disable it
- **Object pooling is mandatory** - never use Instantiate/Destroy in hot paths
