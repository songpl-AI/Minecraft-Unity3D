using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace VoxelPathfinding
{
    [RequireComponent(typeof(VoxelAStarPathfinder))]
    public class VoxelPathfindingAgent : MonoBehaviour
    {
        public Transform target;
        public float moveSpeed = 5f;
        public float turnSpeed = 10f;
        public float repathRate = 0.5f; // 每0.5秒重新寻路一次

        private VoxelAStarPathfinder pathfinder;
        private List<Vector3Int> path;
        private int currentPathIndex;
        private float lastRepathTime;
        private bool isMoving;

        void Start()
        {
            pathfinder = GetComponent<VoxelAStarPathfinder>();
        }

        void Update()
        {
            if (target == null) return;

            // 定期重新寻路
            if (Time.time > lastRepathTime + repathRate)
            {
                lastRepathTime = Time.time;
                RequestPath();
            }

            // 沿着路径移动
            if (isMoving && path != null && currentPathIndex < path.Count)
            {
                MoveAlongPath();
            }
        }

        void RequestPath()
        {
            if (pathfinder.gridManager == null)
                pathfinder.gridManager = FindObjectOfType<New3DCube.VoxelGridManager>();

            if (pathfinder.gridManager == null) return;

            Vector3Int startPos = Vector3Int.RoundToInt(transform.position);
            Vector3Int targetPos = Vector3Int.RoundToInt(target.position);

            // 如果已经在目标附近，停止
            if (Vector3.Distance(transform.position, target.position) < 1.0f)
            {
                path = null;
                isMoving = false;
                return;
            }

            List<Vector3Int> newPath = pathfinder.FindPath(startPos, targetPos);
            if (newPath != null && newPath.Count > 0)
            {
                path = newPath;
                currentPathIndex = 0;
                isMoving = true;
                
                // 简单的平滑处理：如果新路径的第一个点就是当前点，跳过
                if (path.Count > 1 && Vector3.Distance(transform.position, path[0]) < 0.5f)
                {
                    currentPathIndex = 1;
                }
            }
        }

        void MoveAlongPath()
        {
            Vector3 targetNodePos = path[currentPathIndex];
            
            // 简单的移动逻辑：直接向目标点移动
            // 实际项目中应该处理跳跃抛物线等物理效果
            Vector3 moveDir = (targetNodePos - transform.position).normalized;
            
            // 移动
            transform.position += moveDir * moveSpeed * Time.deltaTime;

            // 旋转
            if (moveDir != Vector3.zero)
            {
                Quaternion targetRotation = Quaternion.LookRotation(moveDir);
                transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, turnSpeed * Time.deltaTime);
            }

            // 检查是否到达当前节点
            if (Vector3.Distance(transform.position, targetNodePos) < 0.2f)
            {
                currentPathIndex++;
                if (currentPathIndex >= path.Count)
                {
                    isMoving = false;
                }
            }
        }

        void OnDrawGizmos()
        {
            if (path != null)
            {
                Gizmos.color = Color.yellow;
                for (int i = currentPathIndex; i < path.Count - 1; i++)
                {
                    Gizmos.DrawLine(path[i], path[i + 1]);
                }
            }
        }
    }
}
