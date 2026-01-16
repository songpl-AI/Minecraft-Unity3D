using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace New3DCube
{
    public class VoxelGridManager : MonoBehaviour
    {
        [Header("Configuration")]
        [Tooltip("每个区块的大小。设得很大(如1000)可以实现不分块的效果")]
        public int chunkSize = 16;
        
        [Tooltip("用于渲染方块的材质，需要支持顶点颜色")]
        public Material voxelMaterial;

        [Header("Debug")]
        public bool loadOnStart = false;
        [TextArea]
        public string debugJsonData = "";

        // 全局区块字典
        private Dictionary<Vector3Int, VoxelChunk> chunks = new Dictionary<Vector3Int, VoxelChunk>();

        // 射线检测相关
        private Camera mainCamera;

        void Start()
        {
            mainCamera = Camera.main;
            if (loadOnStart && !string.IsNullOrEmpty(debugJsonData))
            {
                LoadFromJson(debugJsonData);
            }
        }

        void Update()
        {
            HandleInput();
        }

        /// <summary>
        /// 从 JSON 字符串加载数据并生成网格
        /// </summary>
        public void LoadFromJson(string json)
        {
            ClearAll();

            List<RawVoxelData> dataList = VoxelUtils.ParseJsonArray(json);
            if (dataList == null || dataList.Count == 0)
            {
                Debug.LogWarning("No voxel data found in JSON.");
                return;
            }

            // 1. 填充数据
            foreach (var item in dataList)
            {
                Vector3Int worldPos = new Vector3Int(item.x, item.y, item.z);
                Color color = VoxelUtils.ParseHexColor(item.c);
                SetVoxelData(worldPos, new VoxelInfo(color), false); // false = 不立即重建
            }

            // 2. 批量重建网格
            foreach (var chunk in chunks.Values)
            {
                chunk.RebuildMesh();
            }
            
            Debug.Log($"Loaded {dataList.Count} voxels into {chunks.Count} chunks.");
        }

        /// <summary>
        /// 清除所有方块
        /// </summary>
        public void ClearAll()
        {
            foreach (var chunk in chunks.Values)
            {
                Destroy(chunk.gameObject);
            }
            chunks.Clear();
        }

        /// <summary>
        /// 处理鼠标点击交互
        /// </summary>
        private void HandleInput()
        {
            if (Input.GetMouseButtonDown(1) || (Input.GetKey(KeyCode.LeftControl) && Input.GetMouseButtonDown(0))) // 右键或 Ctrl+左键 删除
            {
                Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
                if (Physics.Raycast(ray, out RaycastHit hit))
                {
                    // 稍微向内偏移，确保取整后在方块内部
                    Vector3 point = hit.point + ray.direction * 0.01f;
                    Vector3Int worldPos = new Vector3Int(
                        Mathf.FloorToInt(point.x),
                        Mathf.FloorToInt(point.y),
                        Mathf.FloorToInt(point.z)
                    );

                    RemoveVoxel(worldPos);
                }
            }
        }

        /// <summary>
        /// 删除指定位置的方块
        /// </summary>
        public void RemoveVoxel(Vector3Int worldPos)
        {
            // 1. 设置为空
            SetVoxelData(worldPos, VoxelInfo.Empty, true);
        }

        /// <summary>
        /// 设置体素数据
        /// </summary>
        /// <param name="rebuildMesh">是否立即重建受影响的网格</param>
        private void SetVoxelData(Vector3Int worldPos, VoxelInfo info, bool rebuildMesh)
        {
            Vector3Int chunkCoord = VoxelUtils.GetChunkCoordinate(worldPos, chunkSize);
            Vector3Int localPos = VoxelUtils.GetLocalCoordinate(worldPos, chunkSize);

            VoxelChunk chunk = GetOrCreateChunk(chunkCoord);
            chunk.SetVoxel(localPos.x, localPos.y, localPos.z, info);

            if (rebuildMesh)
            {
                chunk.RebuildMesh();
                
                // 检查是否需要更新邻居 Chunk
                UpdateNeighborChunksIfNeeded(worldPos, localPos, chunkCoord);
            }
        }

        /// <summary>
        /// 检查修改位置是否在 Chunk 边界，如果是，需要更新相邻 Chunk 的 Mesh
        /// </summary>
        private void UpdateNeighborChunksIfNeeded(Vector3Int worldPos, Vector3Int localPos, Vector3Int chunkCoord)
        {
            // X 轴边界
            if (localPos.x == 0) TryRebuildChunk(chunkCoord + new Vector3Int(-chunkSize, 0, 0));
            if (localPos.x == chunkSize - 1) TryRebuildChunk(chunkCoord + new Vector3Int(chunkSize, 0, 0));

            // Y 轴边界
            if (localPos.y == 0) TryRebuildChunk(chunkCoord + new Vector3Int(0, -chunkSize, 0));
            if (localPos.y == chunkSize - 1) TryRebuildChunk(chunkCoord + new Vector3Int(0, chunkSize, 0));

            // Z 轴边界
            if (localPos.z == 0) TryRebuildChunk(chunkCoord + new Vector3Int(0, 0, -chunkSize));
            if (localPos.z == chunkSize - 1) TryRebuildChunk(chunkCoord + new Vector3Int(0, 0, chunkSize));
        }

        private void TryRebuildChunk(Vector3Int coord)
        {
            if (chunks.TryGetValue(coord, out VoxelChunk chunk))
            {
                chunk.RebuildMesh();
            }
        }

        /// <summary>
        /// 获取或创建 Chunk
        /// </summary>
        private VoxelChunk GetOrCreateChunk(Vector3Int chunkCoord)
        {
            if (chunks.TryGetValue(chunkCoord, out VoxelChunk chunk))
            {
                return chunk;
            }

            // 创建新 Chunk
            GameObject go = new GameObject($"Chunk_{chunkCoord.x}_{chunkCoord.y}_{chunkCoord.z}");
            go.transform.parent = transform;
            go.transform.position = chunkCoord;
            
            // 添加组件
            chunk = go.AddComponent<VoxelChunk>();
            chunk.GetComponent<MeshRenderer>().material = voxelMaterial;
            
            // 初始化
            chunk.Initialize(this, chunkCoord, chunkSize);
            
            chunks.Add(chunkCoord, chunk);
            return chunk;
        }

        /// <summary>
        /// 对外接口：获取全局体素信息
        /// </summary>
        public VoxelInfo GetVoxelInfo(Vector3Int worldPos)
        {
            Vector3Int chunkCoord = VoxelUtils.GetChunkCoordinate(worldPos, chunkSize);
            Vector3Int localPos = VoxelUtils.GetLocalCoordinate(worldPos, chunkSize);

            if (chunks.TryGetValue(chunkCoord, out VoxelChunk chunk))
            {
                return chunk.GetVoxel(localPos.x, localPos.y, localPos.z);
            }

            return VoxelInfo.Empty;
        }
    }
}
