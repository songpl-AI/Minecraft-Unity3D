using UnityEngine;

/// <summary>
/// 示例1：Minecraft风格的体素系统
/// 展示如何将库集成到现有的Minecraft项目中
/// </summary>
namespace VoxelMeshLibrary.Examples
{
    /// <summary>
    /// Minecraft体素数据适配器
    /// 将现有的BlockType系统适配到IVoxelData接口
    /// </summary>
    public class MinecraftVoxelData : IVoxelData<BlockType>
    {
        private BlockType[,,] blocks;
        private Vector3Int size;

        public MinecraftVoxelData(BlockType[,,] blocks, int width, int height, int depth)
        {
            this.blocks = blocks;
            this.size = new Vector3Int(width, height, depth);
        }

        public BlockType GetVoxel(int x, int y, int z)
        {
            return blocks[x, y, z];
        }

        public bool IsEmpty(BlockType voxel)
        {
            return voxel == BlockType.Air;
        }

        public Vector2[] GetUVs(BlockType voxel, VoxelFace face)
        {
            // 从现有的Block系统获取UV
            Block block = Block.blocks[voxel];
            
            switch (face)
            {
                case VoxelFace.Top:
                    return block.topPos.GetUVs();
                case VoxelFace.Bottom:
                    return block.bottomPos.GetUVs();
                default:
                    return block.sidePos.GetUVs();
            }
        }

        public Vector3Int Size => size;
    }

    /// <summary>
    /// 使用示例
    /// </summary>
    public class MinecraftMeshExample : MonoBehaviour
    {
        void GenerateExample()
        {
            // 1. 准备体素数据（从JSON或程序化生成）
            BlockType[,,] blocks = new BlockType[10, 10, 10];
            // ... 填充数据 ...

            // 2. 创建适配器
            var voxelData = new MinecraftVoxelData(blocks, 8, 8, 8);

            // 3. 生成Mesh
            Mesh mesh = VoxelMeshBuilder.BuildMesh(voxelData);

            // 4. 应用到GameObject
            GameObject obj = new GameObject("VoxelModel");
            MeshFilter meshFilter = obj.AddComponent<MeshFilter>();
            MeshRenderer meshRenderer = obj.AddComponent<MeshRenderer>();
            MeshCollider meshCollider = obj.AddComponent<MeshCollider>();

            meshFilter.mesh = mesh;
            meshCollider.sharedMesh = mesh;
            
            // 设置材质（从场景中获取）
            meshRenderer.material = FindTerrainMaterial();
        }

        Material FindTerrainMaterial()
        {
            TerrainChunk chunk = FindObjectOfType<TerrainChunk>();
            if (chunk != null)
            {
                return chunk.GetComponent<MeshRenderer>().sharedMaterial;
            }
            return null;
        }
    }
}
