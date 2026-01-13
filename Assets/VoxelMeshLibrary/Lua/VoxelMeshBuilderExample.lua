--[[
VoxelMeshBuilder 使用示例 - Lua版本

演示如何在xLua中使用VoxelMeshBuilder构建体素Mesh

【使用步骤】
1. 在Unity C#脚本中加载此Lua文件
2. 准备体素数据（实现IVoxelData接口）
3. 调用BuildMesh生成Mesh
4. 应用到GameObject的MeshFilter

【示例数据】
这里演示一个简单的3x3x3立方体，中心是空的
]]

-- 导入VoxelMeshBuilder模块
local VoxelMeshModule = require("VoxelMeshBuilder")
local VoxelMeshBuilder = VoxelMeshModule.VoxelMeshBuilder
local VoxelFace = VoxelMeshModule.VoxelFace

-- 导入Unity命名空间
local UnityEngine = CS.UnityEngine
local Vector3Int = UnityEngine.Vector3Int
local Vector2 = UnityEngine.Vector2

-- ============================================================================
-- 示例1: 简单的体素数据实现
-- ============================================================================
local SimpleVoxelData = {}
SimpleVoxelData.__index = SimpleVoxelData

function SimpleVoxelData:new(sizeX, sizeY, sizeZ)
    local obj = {}
    setmetatable(obj, SimpleVoxelData)
    
    -- 实际渲染尺寸
    obj.Size = Vector3Int(sizeX, sizeY, sizeZ)
    
    -- 体素数据数组（包含边界层，所以是 size+2）
    obj.voxels = {}
    local totalSize = (sizeX + 2) * (sizeY + 2) * (sizeZ + 2)
    for i = 1, totalSize do
        obj.voxels[i] = 0  -- 0表示空气
    end
    
    return obj
end

-- 设置体素
function SimpleVoxelData:SetVoxel(x, y, z, voxelType)
    local index = self:GetIndex(x, y, z)
    self.voxels[index] = voxelType
end

-- 获取体素
function SimpleVoxelData:GetVoxel(x, y, z)
    local index = self:GetIndex(x, y, z)
    return self.voxels[index]
end

-- 判断是否为空
function SimpleVoxelData:IsEmpty(voxel)
    return voxel == 0
end

-- 获取UV坐标（简单示例，所有面使用相同UV）
function SimpleVoxelData:GetUVs(voxel, face)
    -- 返回标准的0-1 UV坐标
    return {
        Vector2(0, 0),
        Vector2(0, 1),
        Vector2(1, 1),
        Vector2(1, 0)
    }
end

-- 计算数组索引（私有方法）
function SimpleVoxelData:GetIndex(x, y, z)
    local sizeX = self.Size.x + 2
    local sizeY = self.Size.y + 2
    return x + y * sizeX + z * sizeX * sizeY + 1  -- Lua数组从1开始
end

-- ============================================================================
-- 示例2: Minecraft风格的体素数据（支持多种方块类型）
-- ============================================================================
local MinecraftVoxelData = {}
MinecraftVoxelData.__index = MinecraftVoxelData

function MinecraftVoxelData:new(sizeX, sizeY, sizeZ)
    local obj = {}
    setmetatable(obj, MinecraftVoxelData)
    
    obj.Size = Vector3Int(sizeX, sizeY, sizeZ)
    obj.voxels = {}
    
    local totalSize = (sizeX + 2) * (sizeY + 2) * (sizeZ + 2)
    for i = 1, totalSize do
        obj.voxels[i] = 0
    end
    
    -- 纹理UV配置（假设使用16x16的纹理图集，每个方块纹理占1/16）
    obj.textureUnit = 1.0 / 16.0
    
    -- 方块类型UV映射
    obj.blockUVs = {
        [1] = { top = 0, side = 1, bottom = 2 },     -- 草方块
        [2] = { top = 3, side = 3, bottom = 3 },     -- 泥土
        [3] = { top = 4, side = 4, bottom = 4 },     -- 石头
    }
    
    return obj
end

function MinecraftVoxelData:SetVoxel(x, y, z, blockType)
    local index = self:GetIndex(x, y, z)
    self.voxels[index] = blockType
end

function MinecraftVoxelData:GetVoxel(x, y, z)
    local index = self:GetIndex(x, y, z)
    return self.voxels[index]
end

function MinecraftVoxelData:IsEmpty(voxel)
    return voxel == 0
end

function MinecraftVoxelData:GetUVs(blockType, face)
    if blockType == 0 then
        return self:GetDefaultUVs()
    end
    
    local uvConfig = self.blockUVs[blockType]
    if not uvConfig then
        return self:GetDefaultUVs()
    end
    
    -- 根据面类型选择对应的纹理
    local textureIndex
    if face == VoxelFace.Top then
        textureIndex = uvConfig.top
    elseif face == VoxelFace.Bottom then
        textureIndex = uvConfig.bottom
    else
        textureIndex = uvConfig.side
    end
    
    return self:CalculateUVs(textureIndex)
end

function MinecraftVoxelData:CalculateUVs(textureIndex)
    local unit = self.textureUnit
    local x = (textureIndex % 16) * unit
    local y = math.floor(textureIndex / 16) * unit
    
    return {
        Vector2(x, y),
        Vector2(x, y + unit),
        Vector2(x + unit, y + unit),
        Vector2(x + unit, y)
    }
end

function MinecraftVoxelData:GetDefaultUVs()
    return {
        Vector2(0, 0),
        Vector2(0, 1),
        Vector2(1, 1),
        Vector2(1, 0)
    }
end

function MinecraftVoxelData:GetIndex(x, y, z)
    local sizeX = self.Size.x + 2
    local sizeY = self.Size.y + 2
    return x + y * sizeX + z * sizeX * sizeY + 1
end

-- ============================================================================
-- 测试函数：创建一个简单的立方体
-- ============================================================================
local function CreateSimpleCube()
    -- 创建3x3x3的体素数据
    local voxelData = SimpleVoxelData:new(3, 3, 3)
    
    -- 填充体素（创建一个空心立方体）
    for x = 1, 3 do
        for y = 1, 3 do
            for z = 1, 3 do
                -- 边缘位置填充实体，中心留空
                if x == 1 or x == 3 or y == 1 or y == 3 or z == 1 or z == 3 then
                    voxelData:SetVoxel(x, y, z, 1)  -- 1表示实体方块
                end
            end
        end
    end
    
    -- 构建Mesh
    local mesh = VoxelMeshBuilder:BuildMesh(voxelData)
    return mesh
end

-- ============================================================================
-- 测试函数：创建一个Minecraft风格的地形
-- ============================================================================
local function CreateMinecraftTerrain()
    local voxelData = MinecraftVoxelData:new(10, 5, 10)
    
    -- 创建简单的分层地形
    for x = 1, 10 do
        for z = 1, 10 do
            voxelData:SetVoxel(x, 1, z, 3)  -- 底层：石头
            voxelData:SetVoxel(x, 2, z, 2)  -- 中层：泥土
            voxelData:SetVoxel(x, 3, z, 2)  -- 中层：泥土
            voxelData:SetVoxel(x, 4, z, 1)  -- 顶层：草方块
        end
    end
    
    -- 在中间挖个洞
    for x = 4, 7 do
        for z = 4, 7 do
            for y = 1, 4 do
                voxelData:SetVoxel(x, y, z, 0)  -- 0表示空气
            end
        end
    end
    
    local mesh = VoxelMeshBuilder:BuildMesh(voxelData)
    return mesh
end

-- ============================================================================
-- 导出API供Unity C#调用
-- ============================================================================
return {
    -- 导出类
    SimpleVoxelData = SimpleVoxelData,
    MinecraftVoxelData = MinecraftVoxelData,
    VoxelMeshBuilder = VoxelMeshBuilder,
    VoxelFace = VoxelFace,
    
    -- 导出测试函数
    CreateSimpleCube = CreateSimpleCube,
    CreateMinecraftTerrain = CreateMinecraftTerrain
}
