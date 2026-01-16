using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

namespace New3DCube
{
    /// <summary>
    /// 原始 JSON 数据项
    /// 对应 [{"x":-9,"y":0,"z":-9,"c":"#F4A460"}, ...]
    /// </summary>
    [Serializable]
    public class RawVoxelData
    {
        public int x;
        public int y;
        public int z;
        public string c; // Hex color code
    }

    /// <summary>
    /// 运行时体素数据结构
    /// 为了节省内存，这里只存储必要信息
    /// 如果未来需要支持贴图，可以在这里扩展
    /// </summary>
    public struct VoxelInfo
    {
        public bool isEmpty;
        public Color color;
        // public int textureId; // 未来扩展

        public static VoxelInfo Empty => new VoxelInfo { isEmpty = true, color = Color.clear };
        
        public VoxelInfo(Color c)
        {
            isEmpty = false;
            color = c;
        }
    }

    /// <summary>
    /// 用于 JsonUtility 解析数组的包装类
    /// </summary>
    [Serializable]
    public class VoxelDataListWrapper
    {
        public List<RawVoxelData> items;
    }
}
