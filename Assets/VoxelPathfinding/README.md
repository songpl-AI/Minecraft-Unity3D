# Voxel Pathfinding Demo

这是一个基于体素世界的 A* 寻路演示。它不依赖 Unity NavMesh，而是直接在 `VoxelGridManager` 的数据上进行寻路。

## 功能特性
- **完全动态**：直接读取 `VoxelInfo` 数据，地形改变后无需烘焙，寻路立即更新。
- **3D 移动能力**：支持平移、跳跃（1格高）和下落（可配置高度）。
- **无限地图支持**：只计算加载范围内的路径。

## 如何使用

1. **准备场景**
   - 确保场景中有一个正在运行的 `VoxelGridManager`（例如 New3DCube 场景）。
   - 创建一个新的 GameObject，命名为 "PathfindingSystem"。

2. **添加组件**
   - 给 "PathfindingSystem" 添加 `VoxelAStarPathfinder` 组件。
   - 确保 `Grid Manager` 字段引用了场景中的 `VoxelGridManager`（如果不填，代码会自动查找）。
   - 给同一个物体添加 `VoxelPathfindingTester` 组件。

3. **设置测试目标**
   - 创建两个球体或立方体 GameObject，分别命名为 "Start" 和 "Target"。
   - 将它们分别拖拽赋值给 `VoxelPathfindingTester` 的 `Start Transform` 和 `Target Transform`。

4. **运行测试**
   - 运行游戏 (Play Mode)。
   - 在 Scene 视口中移动 "Start" 或 "Target" 物体。
   - 你会看到绿色的路径线实时更新。
   - 如果没有路径，请检查起点或终点是否卡在墙里，或者距离太远无法到达。

## 核心参数说明

**VoxelAStarPathfinder**
- `Max Fall Height`: 允许角色从多高的地方跳下来（默认 3 格）。
- `Max Jump Height`: 允许角色跳多高（默认 1 格）。
- `Max Steps`: 防止死循环的最大搜索步数。

## 代码结构
- `VoxelAStarNode.cs`: 寻路节点数据结构。
- `VoxelAStarPathfinder.cs`: 核心寻路算法实现。
- `VoxelPathfindingTester.cs`: 用于测试和 Debug 绘制的工具脚本。
