using System.Collections.Generic;
using UnityEngine;
using New3DCube;

namespace VoxelPathfinding
{
    [RequireComponent(typeof(VoxelAStarPathfinder))]
    public class VoxelPathfindingTester : MonoBehaviour
    {
        public Transform startTransform;
        public Transform targetTransform;
        public bool autoUpdate = true;
        public Color pathColor = Color.green;

        private VoxelAStarPathfinder pathfinder;
        private List<Vector3Int> currentPath;

        void Start()
        {
            pathfinder = GetComponent<VoxelAStarPathfinder>();
        }

        void Update()
        {
            if (autoUpdate && startTransform != null && targetTransform != null)
            {
                CalculatePath();
            }
            
            // 按空格键手动计算
            if (Input.GetKeyDown(KeyCode.Space))
            {
                CalculatePath();
            }
        }

        [ContextMenu("Calculate Path")]
        public void CalculatePath()
        {
            if (pathfinder == null) pathfinder = GetComponent<VoxelAStarPathfinder>();
            if (pathfinder.gridManager == null)
            {
                pathfinder.gridManager = FindObjectOfType<VoxelGridManager>();
            }

            if (startTransform != null && targetTransform != null)
            {
                Vector3Int startPos = Vector3Int.RoundToInt(startTransform.position);
                Vector3Int targetPos = Vector3Int.RoundToInt(targetTransform.position);

                // 简单的性能节流：如果没有移动，就不重算
                // (这里为了演示简单，暂时不做严格检查)

                currentPath = pathfinder.FindPath(startPos, targetPos);
                
                if (currentPath != null)
                {
                    Debug.Log($"Path found with {currentPath.Count} steps.");
                }
                else
                {
                    // Debug.LogWarning("Path not found.");
                }
            }
        }

        void OnDrawGizmos()
        {
            if (currentPath != null)
            {
                Gizmos.color = pathColor;
                for (int i = 0; i < currentPath.Count; i++)
                {
                    Vector3 pos = currentPath[i];
                    // 绘制一个小方块表示路径点
                    Gizmos.DrawWireCube(pos, Vector3.one * 0.5f);
                    
                    // 绘制连线
                    if (i > 0)
                    {
                        Gizmos.DrawLine(currentPath[i-1], currentPath[i]);
                    }
                }
            }

            if (startTransform != null)
            {
                Gizmos.color = Color.blue;
                Gizmos.DrawWireCube(Vector3Int.RoundToInt(startTransform.position), Vector3.one * 1.1f);
            }

            if (targetTransform != null)
            {
                Gizmos.color = Color.red;
                Gizmos.DrawWireCube(Vector3Int.RoundToInt(targetTransform.position), Vector3.one * 1.1f);
            }
        }
    }
}
