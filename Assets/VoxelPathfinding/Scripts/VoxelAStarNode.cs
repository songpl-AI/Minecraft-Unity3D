using UnityEngine;

namespace VoxelPathfinding
{
    public class VoxelAStarNode
    {
        public Vector3Int Position;
        public VoxelAStarNode Parent;
        
        public int GCost; // 距离起点的代价
        public int HCost; // 距离终点的预估代价
        public int FCost => GCost + HCost;

        public VoxelAStarNode(Vector3Int pos)
        {
            Position = pos;
        }

        public override bool Equals(object obj)
        {
            if (obj is VoxelAStarNode node)
                return Position == node.Position;
            return false;
        }

        public override int GetHashCode()
        {
            return Position.GetHashCode();
        }
    }
}
