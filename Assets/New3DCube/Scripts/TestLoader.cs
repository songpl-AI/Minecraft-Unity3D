using UnityEngine;
using System.Text;

namespace New3DCube
{
    public class TestLoader : MonoBehaviour
    {
        public VoxelGridManager manager;

        void Start()
        {
            if (manager == null)
                manager = GetComponent<VoxelGridManager>();

            // 生成测试数据
            string json = GenerateTestData();
            
            // 加载
            manager.LoadFromJson(json);
        }

        string GenerateTestData()
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("[");

            // 1. 生成一个 10x10x10 的立方体块
            for (int x = -5; x < 5; x++)
            {
                for (int y = 0; y < 10; y++)
                {
                    for (int z = -5; z < 5; z++)
                    {
                        string color = ((x + z) % 2 == 0) ? "#FF0000" : "#00FF00"; // 红绿相间
                        AppendItem(sb, x, y, z, color);
                        sb.Append(",");
                    }
                }
            }

            // 2. 生成一些散点，测试跨 Chunk
            AppendItem(sb, 20, 5, 20, "#0000FF"); // 蓝色
            sb.Append(",");
            AppendItem(sb, -20, 5, -20, "#FFFF00"); // 黄色
            sb.Append(",");

            // 3. 用户提供的示例数据
            sb.Append("{\"x\":-9,\"y\":0,\"z\":-9,\"c\":\"#F4A460\"},");
            sb.Append("{\"x\":-8,\"y\":0,\"z\":-9,\"c\":\"#F4A460\"},");
            sb.Append("{\"x\":-7,\"y\":0,\"z\":-9,\"c\":\"#F4A460\"}"); // 最后一项不加逗号

            sb.Append("]");
            return sb.ToString();
        }

        void AppendItem(StringBuilder sb, int x, int y, int z, string color)
        {
            sb.Append($"{{\"x\":{x},\"y\":{y},\"z\":{z},\"c\":\"{color}\"}}");
        }
    }
}
