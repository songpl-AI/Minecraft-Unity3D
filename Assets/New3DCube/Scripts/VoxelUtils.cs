using UnityEngine;
using System.Collections.Generic;

namespace New3DCube
{
    public static class VoxelUtils
    {
        /// <summary>
        /// 解析 Hex 颜色字符串 (#RRGGBB)
        /// </summary>
        public static Color ParseHexColor(string hex)
        {
            if (string.IsNullOrEmpty(hex)) return Color.white;
            
            // 确保以 # 开头
            if (!hex.StartsWith("#")) hex = "#" + hex;
            
            Color color;
            if (ColorUtility.TryParseHtmlString(hex, out color))
            {
                return color;
            }
            return Color.white; // 解析失败返回白色
        }

        /// <summary>
        /// 计算给定坐标所在的 Chunk 坐标
        /// </summary>
        public static Vector3Int GetChunkCoordinate(Vector3Int worldPos, int chunkSize)
        {
            int x = Mathf.FloorToInt((float)worldPos.x / chunkSize) * chunkSize;
            int y = Mathf.FloorToInt((float)worldPos.y / chunkSize) * chunkSize;
            int z = Mathf.FloorToInt((float)worldPos.z / chunkSize) * chunkSize;
            return new Vector3Int(x, y, z);
        }

        /// <summary>
        /// 计算给定坐标在 Chunk 内的局部坐标 (0 到 chunkSize-1)
        /// </summary>
        public static Vector3Int GetLocalCoordinate(Vector3Int worldPos, int chunkSize)
        {
            // 使用模运算处理负数坐标
            // 比如 chunkSize=16:
            // world=18 -> 18 % 16 = 2
            // world=-1 -> -1 % 16 = -1 (C#特性), 需要修正为 15
            
            int x = worldPos.x % chunkSize;
            int y = worldPos.y % chunkSize;
            int z = worldPos.z % chunkSize;

            if (x < 0) x += chunkSize;
            if (y < 0) y += chunkSize;
            if (z < 0) z += chunkSize;

            return new Vector3Int(x, y, z);
        }

        /// <summary>
        /// 手动解析 JSON 数组字符串，避免 JsonUtility 必须要有顶层对象的限制
        /// 这是一个简单的解析器，假设格式比较标准
        /// </summary>
        public static List<RawVoxelData> ParseJsonArray(string json)
        {
            // 如果 JSON 是以 [ 开头，我们可以把它包装在一个对象里用 JsonUtility 解析
            // 或者简单的字符串处理
            
            // 方法：包装成 {"items": [...]}
            string wrappedJson = "{\"items\":" + json + "}";
            try 
            {
                VoxelDataListWrapper wrapper = JsonUtility.FromJson<VoxelDataListWrapper>(wrappedJson);
                return wrapper.items;
            }
            catch (System.Exception e)
            {
                Debug.LogError("JSON Parsing Failed: " + e.Message);
                return new List<RawVoxelData>();
            }
        }
    }
}
