using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// 示例3：高级用法 - 自定义体素类
/// 展示更复杂的体素系统（带元数据的体素）
/// </summary>
namespace VoxelMeshLibrary.Examples
{
    /// <summary>
    /// 自定义体素类（包含类型和额外数据）
    /// </summary>
    public class CustomVoxel
    {
        public VoxelType Type;
        public Color Tint;           // 颜色叠加
        public float Damage;         // 损坏程度
        public Dictionary<string, object> Metadata;  // 自定义元数据

        public CustomVoxel(VoxelType type)
        {
            Type = type;
            Tint = Color.white;
            Damage = 0f;
            Metadata = new Dictionary<string, object>();
        }
    }

    public enum VoxelType
    {
        Air,
        Stone,
        Dirt,
        Wood,
        Metal,
        Glass
    }

    /// <summary>
    /// 自定义体素数据适配器
    /// </summary>
    public class CustomVoxelData : IVoxelData<CustomVoxel>
    {
        private CustomVoxel[,,] voxels;
        private Vector3Int size;
        private Material voxelMaterial;

        public CustomVoxelData(CustomVoxel[,,] voxels, Vector3Int size, Material material)
        {
            this.voxels = voxels;
            this.size = size;
            this.voxelMaterial = material;
        }

        public CustomVoxel GetVoxel(int x, int y, int z)
        {
            return voxels[x, y, z];
        }

        public bool IsEmpty(CustomVoxel voxel)
        {
            // 空气和玻璃都认为是透明（可以看到内部）
            return voxel == null || 
                   voxel.Type == VoxelType.Air || 
                   voxel.Type == VoxelType.Glass;
        }

        public Vector2[] GetUVs(CustomVoxel voxel, VoxelFace face)
        {
            // 根据体素类型获取UV
            // 这里可以根据面的方向使用不同的纹理
            Vector2 baseUV = GetBaseUVForType(voxel.Type, face);
            float tileSize = 1f / 16f;

            return new Vector2[]
            {
                baseUV,
                baseUV + new Vector2(0, tileSize),
                baseUV + new Vector2(tileSize, tileSize),
                baseUV + new Vector2(tileSize, 0)
            };
        }

        Vector2 GetBaseUVForType(VoxelType type, VoxelFace face)
        {
            float tileSize = 1f / 16f;
            
            // 根据类型和面返回不同的UV起始位置
            switch (type)
            {
                case VoxelType.Stone:
                    return new Vector2(0, 0);
                case VoxelType.Dirt:
                    return new Vector2(tileSize, 0);
                case VoxelType.Wood:
                    // 木头：侧面用树皮，顶底用年轮
                    if (face == VoxelFace.Top || face == VoxelFace.Bottom)
                        return new Vector2(0, tileSize);
                    else
                        return new Vector2(tileSize, tileSize);
                case VoxelType.Metal:
                    return new Vector2(2 * tileSize, 0);
                default:
                    return Vector2.zero;
            }
        }

        public Vector3Int Size => size;
    }

    /// <summary>
    /// 高级使用示例
    /// </summary>
    public class AdvancedVoxelExample : MonoBehaviour
    {
        public Material voxelMaterial;

        void Start()
        {
            // 1. 创建复杂的体素数据
            CustomVoxel[,,] voxels = new CustomVoxel[12, 12, 12];

            // 初始化为空气
            for (int x = 0; x < 12; x++)
                for (int y = 0; y < 12; y++)
                    for (int z = 0; z < 12; z++)
                        voxels[x, y, z] = new CustomVoxel(VoxelType.Air);

            // 创建一个带损坏的石头墙
            for (int x = 3; x < 9; x++)
            {
                for (int y = 1; y < 7; y++)
                {
                    var stone = new CustomVoxel(VoxelType.Stone);
                    stone.Damage = Random.Range(0f, 0.5f);  // 随机损坏
                    stone.Tint = Color.Lerp(Color.white, Color.gray, stone.Damage);
                    voxels[x, y, 5] = stone;
                }
            }

            // 添加木制门框
            for (int y = 2; y < 5; y++)
            {
                voxels[5, y, 5] = new CustomVoxel(VoxelType.Wood);
                voxels[6, y, 5] = new CustomVoxel(VoxelType.Wood);
            }

            // 2. 创建适配器
            var voxelData = new CustomVoxelData(
                voxels,
                new Vector3Int(10, 10, 10),
                voxelMaterial
            );

            // 3. 生成Mesh
            Mesh mesh = VoxelMeshBuilder.BuildMesh(voxelData);

            // 4. 应用到场景
            GameObject obj = new GameObject("CustomVoxelModel");
            obj.transform.position = Vector3.zero;

            MeshFilter meshFilter = obj.AddComponent<MeshFilter>();
            MeshRenderer meshRenderer = obj.AddComponent<MeshRenderer>();
            MeshCollider meshCollider = obj.AddComponent<MeshCollider>();

            meshFilter.mesh = mesh;
            meshRenderer.material = voxelMaterial;
            meshCollider.sharedMesh = mesh;

            Debug.Log($"生成的Mesh: {mesh.vertexCount} 个顶点, {mesh.triangles.Length / 3} 个三角形");
        }
    }
}
