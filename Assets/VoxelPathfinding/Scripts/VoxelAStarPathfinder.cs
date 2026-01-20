using System.Collections.Generic;
using UnityEngine;
using New3DCube; // 引用现有的体素系统

namespace VoxelPathfinding
{
    public class VoxelAStarPathfinder : MonoBehaviour
    {
        [Header("Settings")]
        public VoxelGridManager gridManager; // 需要引用场景中的 VoxelGridManager
        public int maxFallHeight = 3;        // 最大下落高度
        public int maxJumpHeight = 1;        // 最大跳跃高度（通常为1）
        public int maxSteps = 1000;          // 防止死循环的最大搜索步数

        // 简化的邻居偏移量（前后左右）
        private readonly Vector3Int[] neighborOffsets = new Vector3Int[]
        {
            new Vector3Int(1, 0, 0),  // 右
            new Vector3Int(-1, 0, 0), // 左
            new Vector3Int(0, 0, 1),  // 前
            new Vector3Int(0, 0, -1)  // 后
        };

        /// <summary>
        /// 核心寻路方法
        /// </summary>
        public List<Vector3Int> FindPath(Vector3Int startPos, Vector3Int targetPos)
        {
            if (gridManager == null)
            {
                Debug.LogError("VoxelGridManager not assigned!");
                return null;
            }

            // 1. 验证起点和终点是否有效
            if (!IsWalkable(startPos) && !IsWalkable(startPos + Vector3Int.down)) // 允许起点稍微悬空一点
            {
                Debug.LogWarning($"Start position {startPos} is not walkable.");
                // 尝试修正起点到最近的地面
                startPos = FindGround(startPos);
                if (!IsWalkable(startPos)) return null;
            }

            if (!IsWalkable(targetPos))
            {
                Debug.LogWarning($"Target position {targetPos} is not walkable. Trying to find ground.");
                targetPos = FindGround(targetPos);
                if (!IsWalkable(targetPos)) return null;
            }

            // A* 初始化
            List<VoxelAStarNode> openList = new List<VoxelAStarNode>();
            HashSet<Vector3Int> closedSet = new HashSet<Vector3Int>();

            VoxelAStarNode startNode = new VoxelAStarNode(startPos);
            VoxelAStarNode targetNode = new VoxelAStarNode(targetPos);

            openList.Add(startNode);

            int steps = 0;
            while (openList.Count > 0)
            {
                // 安全限制
                if (steps++ > maxSteps)
                {
                    Debug.LogWarning("Pathfinding max steps reached.");
                    break;
                }

                // 获取 F 值最小的节点
                VoxelAStarNode currentNode = openList[0];
                for (int i = 1; i < openList.Count; i++)
                {
                    if (openList[i].FCost < currentNode.FCost || 
                        (openList[i].FCost == currentNode.FCost && openList[i].HCost < currentNode.HCost))
                    {
                        currentNode = openList[i];
                    }
                }

                openList.Remove(currentNode);
                closedSet.Add(currentNode.Position);

                // 到达终点
                if (currentNode.Position == targetNode.Position)
                {
                    return RetracePath(startNode, currentNode);
                }

                // 遍历邻居
                foreach (Vector3Int neighborPos in GetNeighbors(currentNode.Position))
                {
                    if (closedSet.Contains(neighborPos)) continue;

                    int newMovementCostToNeighbor = currentNode.GCost + GetDistance(currentNode.Position, neighborPos);
                    
                    VoxelAStarNode neighborNode = openList.Find(n => n.Position == neighborPos);
                    
                    if (neighborNode == null || newMovementCostToNeighbor < neighborNode.GCost)
                    {
                        if (neighborNode == null)
                        {
                            neighborNode = new VoxelAStarNode(neighborPos);
                            openList.Add(neighborNode);
                        }

                        neighborNode.GCost = newMovementCostToNeighbor;
                        neighborNode.HCost = GetDistance(neighborPos, targetNode.Position);
                        neighborNode.Parent = currentNode;
                    }
                }
            }

            return null; // 没找到路径
        }

        /// <summary>
        /// 获取所有合法的可移动邻居节点
        /// </summary>
        private List<Vector3Int> GetNeighbors(Vector3Int currentPos)
        {
            List<Vector3Int> neighbors = new List<Vector3Int>();

            foreach (Vector3Int offset in neighborOffsets)
            {
                // 1. 尝试平移
                Vector3Int targetPos = currentPos + offset;
                if (IsWalkable(targetPos))
                {
                    neighbors.Add(targetPos);
                    continue;
                }

                // 2. 尝试跳跃 (上移 1 格)
                // 条件：头顶必须有空间跳，目标位置必须可站立
                // 检查当前位置头顶
                if (!IsSolid(currentPos + Vector3Int.up) && !IsSolid(currentPos + Vector3Int.up * 2))
                {
                    Vector3Int jumpPos = targetPos + Vector3Int.up;
                    if (IsWalkable(jumpPos))
                    {
                        neighbors.Add(jumpPos);
                        continue;
                    }
                }

                // 3. 尝试下落 (下移 1 到 maxFallHeight 格)
                // 条件：目标位置原本是空的（悬崖），往下找直到找到地面
                if (!IsSolid(targetPos) && !IsSolid(targetPos + Vector3Int.up)) // 确保前面是空的，且能走过去
                {
                    for (int k = 1; k <= maxFallHeight; k++)
                    {
                        Vector3Int fallPos = targetPos + Vector3Int.down * k;
                        if (IsWalkable(fallPos))
                        {
                            neighbors.Add(fallPos);
                            break; // 找到落脚点就停止
                        }
                        
                        // 如果中间遇到了障碍物但又不是地面（比如只有一格空间），则不能通过，停止
                        if (IsSolid(fallPos)) break; 
                    }
                }
            }

            return neighbors;
        }

        /// <summary>
        /// 检查某个位置是否适合站立
        /// 规则：
        /// 1. 该位置必须是空的（空气）
        /// 2. 该位置上方必须是空的（头顶空间，假设高2格）
        /// 3. 该位置下方必须是实心的（地面）
        /// </summary>
        private bool IsWalkable(Vector3Int pos)
        {
            // 检查自身 (脚的位置)
            if (IsSolid(pos)) return false;

            // 检查头顶 (假设角色高 2 格)
            if (IsSolid(pos + Vector3Int.up)) return false;

            // 检查脚下 (必须有支撑)
            if (!IsSolid(pos + Vector3Int.down)) return false;

            return true;
        }

        /// <summary>
        /// 检查某个位置是否是实心方块
        /// </summary>
        private bool IsSolid(Vector3Int pos)
        {
            if (gridManager == null) return false;
            // GetVoxelInfo 返回 Empty 表示空气，所以 !isEmpty 表示实心
            return !gridManager.GetVoxelInfo(pos).isEmpty;
        }

        private Vector3Int FindGround(Vector3Int pos)
        {
            // 简单的向下寻找地面逻辑
            for (int i = 0; i < 10; i++)
            {
                if (IsWalkable(pos)) return pos;
                pos += Vector3Int.down;
            }
            return pos;
        }

        private List<Vector3Int> RetracePath(VoxelAStarNode startNode, VoxelAStarNode endNode)
        {
            List<Vector3Int> path = new List<Vector3Int>();
            VoxelAStarNode currentNode = endNode;

            while (currentNode != startNode)
            {
                path.Add(currentNode.Position);
                currentNode = currentNode.Parent;
            }
            path.Add(startNode.Position); // 包含起点
            path.Reverse();
            return path;
        }

        private int GetDistance(Vector3Int a, Vector3Int b)
        {
            // 曼哈顿距离，适合网格
            return Mathf.Abs(a.x - b.x) + Mathf.Abs(a.y - b.y) + Mathf.Abs(a.z - b.z);
        }
    }
}
