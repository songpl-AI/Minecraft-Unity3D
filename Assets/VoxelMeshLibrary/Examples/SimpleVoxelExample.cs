using UnityEngine;

/// <summary>
/// 示例2：简单的整数体素系统
/// 展示如何在全新项目中从零使用这个库
/// </summary>
namespace VoxelMeshLibrary.Examples
{
    /// <summary>
    /// 简单体素数据（使用int类型）
    /// 0 = 空, 1 = 土, 2 = 石头, 3 = 草
    /// </summary>
    public class SimpleVoxelData : IVoxelData<int>
    {
        private int[,,] voxels;
        private Vector3Int size;
        private Texture2D textureAtlas;  // 纹理图集

        public SimpleVoxelData(int[,,] voxels, Vector3Int size, Texture2D textureAtlas)
        {
            this.voxels = voxels;
            this.size = size;
            this.textureAtlas = textureAtlas;
        }

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
            // 简单的UV映射：假设16x16的图集
            float tileSize = 1f / 16f;
            int tileX = (voxel - 1) % 16;  // 横向位置
            int tileY = (voxel - 1) / 16;  // 纵向位置

            float x = tileX * tileSize;
            float y = tileY * tileSize;

            // 返回4个顶点的UV（左下、左上、右上、右下）
            return new Vector2[]
            {
                new Vector2(x, y),
                new Vector2(x, y + tileSize),
                new Vector2(x + tileSize, y + tileSize),
                new Vector2(x + tileSize, y)
            };
        }

        public Vector3Int Size => size;
    }

    /// <summary>
    /// 使用示例
    /// </summary>
    public class SimpleVoxelExample : MonoBehaviour
    {
        public Texture2D textureAtlas;
        public Material voxelMaterial;

        void Start()
        {
            // 1. 创建简单的体素数据（一个小立方体）
            int[,,] voxels = new int[10, 10, 10];
            
            // 填充一些数据
            for (int x = 3; x < 7; x++)
                for (int y = 3; y < 7; y++)
                    for (int z = 3; z < 7; z++)
                        voxels[x, y, z] = 1;  // 土

            // 2. 创建体素数据适配器
            var voxelData = new SimpleVoxelData(
                voxels, 
                new Vector3Int(8, 8, 8), 
                textureAtlas
            );

            // 3. 生成Mesh
            Mesh mesh = VoxelMeshBuilder.BuildMesh(voxelData);

            // 4. 创建GameObject并应用
            GameObject voxelObject = new GameObject("SimpleVoxelModel");
            voxelObject.transform.position = Vector3.zero;

            MeshFilter meshFilter = voxelObject.AddComponent<MeshFilter>();
            MeshRenderer meshRenderer = voxelObject.AddComponent<MeshRenderer>();
            
            meshFilter.mesh = mesh;
            meshRenderer.material = voxelMaterial;
            meshRenderer.material.mainTexture = textureAtlas;
        }
    }
}
