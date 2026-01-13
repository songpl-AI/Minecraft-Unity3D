--[[
独立的体素Mesh构建器 - Lua版本（xLua）
可移植到任何Unity + xLua项目

【核心算法】
- 面剔除（Face Culling）：只渲染暴露在空气中的面
- Mesh合并：将所有体素合并为单个Mesh，减少Draw Call
- 顶点共享：通过索引数组共享顶点，节省内存

【性能优化】
- 只遍历实体体素，跳过空体素
- 使用table动态增长，避免预分配过大数组
- 每个面只在必要时生成（相邻是空才生成）

【使用方法】
1. 实现IVoxelData接口（Lua table）
2. 调用VoxelMeshBuilder:BuildMesh()方法
3. 将生成的Mesh应用到MeshFilter

【接口定义】voxelData 需要提供：
{
    Size = CS.UnityEngine.Vector3Int,  -- 渲染区域尺寸
    GetVoxel = function(x, y, z) end,  -- 获取体素
    IsEmpty = function(voxel) end,     -- 判断是否为空
    GetUVs = function(voxel, face) end -- 获取UV坐标
}

【版本】1.0（xLua）
【作者】AI Assistant
【日期】2026-01-13
]]

-- 导入Unity命名空间
local UnityEngine = CS.UnityEngine
local Vector3 = UnityEngine.Vector3
local Vector2 = UnityEngine.Vector2
local Mesh = UnityEngine.Mesh

-- 体素面枚举
local VoxelFace = {
    Top = 0,
    Bottom = 1,
    Front = 2,
    Back = 3,
    Right = 4,
    Left = 5
}

-- VoxelMeshBuilder 主类
local VoxelMeshBuilder = {}

--[[
构建体素Mesh（核心方法）

参数：
    voxelData: 体素数据访问器（实现了IVoxelData接口的table）
    
返回：
    生成的Mesh对象
]]
function VoxelMeshBuilder:BuildMesh(voxelData)
    -- 创建Mesh对象
    local mesh = Mesh()
    
    -- 创建数组容器（Lua table）
    local vertices = {}
    local triangles = {}
    local uvs = {}
    
    -- 获取体素区域尺寸
    local size = voxelData.Size
    
    -- 遍历所有体素位置
    -- 注意：假设体素数据包含边界层（+2），实际渲染区域从索引1开始
    for x = 1, size.x do
        for z = 1, size.z do
            for y = 1, size.y do
                -- 获取当前体素
                local voxel = voxelData:GetVoxel(x, y, z)
                
                -- 跳过空体素
                if not voxelData:IsEmpty(voxel) then
                    -- 计算体素在世界坐标中的位置（减1是因为边界层偏移）
                    local position = Vector3(x - 1, y - 1, z - 1)
                    
                    -- 检查6个方向，生成暴露的面
                    self:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                        voxel, x, y + 1, z, position, VoxelFace.Top)
                    
                    self:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                        voxel, x, y - 1, z, position, VoxelFace.Bottom)
                    
                    self:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                        voxel, x, y, z - 1, position, VoxelFace.Front)
                    
                    self:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                        voxel, x, y, z + 1, position, VoxelFace.Back)
                    
                    self:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                        voxel, x + 1, y, z, position, VoxelFace.Right)
                    
                    self:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                        voxel, x - 1, y, z, position, VoxelFace.Left)
                end
            end
        end
    end
    
    -- 将Lua table转换为C#数组
    local vertexArray = self:ToVector3Array(vertices)
    local triangleArray = self:ToIntArray(triangles)
    local uvArray = self:ToVector2Array(uvs)
    
    -- 组装Mesh
    mesh.vertices = vertexArray
    mesh.triangles = triangleArray
    mesh.uv = uvArray
    mesh:RecalculateNormals()  -- 自动计算法线
    
    return mesh
end

--[[
检查相邻体素，如果是空则添加该面

参数：
    voxelData: 体素数据访问器
    vertices: 顶点列表
    uvs: UV坐标列表
    triangles: 三角形索引列表
    currentVoxel: 当前体素
    neighborX, neighborY, neighborZ: 相邻体素坐标
    position: 当前体素世界坐标
    face: 要检查的面
]]
function VoxelMeshBuilder:CheckAndAddFace(voxelData, vertices, uvs, triangles,
                                          currentVoxel, neighborX, neighborY, neighborZ,
                                          position, face)
    -- 获取相邻体素
    local neighbor = voxelData:GetVoxel(neighborX, neighborY, neighborZ)
    
    -- 如果相邻不是空，则该面不需要渲染
    if not voxelData:IsEmpty(neighbor) then
        return
    end
    
    -- 添加该面的4个顶点
    self:AddFaceVertices(vertices, position, face)
    
    -- 添加UV坐标
    local faceUVs = voxelData:GetUVs(currentVoxel, face)
    for i = 1, #faceUVs do
        table.insert(uvs, faceUVs[i])
    end
    
    -- 添加三角形索引（2个三角形 = 6个索引）
    self:AddFaceTriangles(triangles, #vertices)
end

--[[
添加一个面的4个顶点

参数：
    vertices: 顶点列表
    position: 体素位置
    face: 面类型
]]
function VoxelMeshBuilder:AddFaceVertices(vertices, position, face)
    if face == VoxelFace.Top then
        -- 顶面 (Y+)
        table.insert(vertices, position + Vector3(0, 1, 0))
        table.insert(vertices, position + Vector3(0, 1, 1))
        table.insert(vertices, position + Vector3(1, 1, 1))
        table.insert(vertices, position + Vector3(1, 1, 0))
        
    elseif face == VoxelFace.Bottom then
        -- 底面 (Y-)
        table.insert(vertices, position + Vector3(0, 0, 0))
        table.insert(vertices, position + Vector3(1, 0, 0))
        table.insert(vertices, position + Vector3(1, 0, 1))
        table.insert(vertices, position + Vector3(0, 0, 1))
        
    elseif face == VoxelFace.Front then
        -- 前面 (Z-)
        table.insert(vertices, position + Vector3(0, 0, 0))
        table.insert(vertices, position + Vector3(0, 1, 0))
        table.insert(vertices, position + Vector3(1, 1, 0))
        table.insert(vertices, position + Vector3(1, 0, 0))
        
    elseif face == VoxelFace.Back then
        -- 后面 (Z+)
        table.insert(vertices, position + Vector3(1, 0, 1))
        table.insert(vertices, position + Vector3(1, 1, 1))
        table.insert(vertices, position + Vector3(0, 1, 1))
        table.insert(vertices, position + Vector3(0, 0, 1))
        
    elseif face == VoxelFace.Right then
        -- 右面 (X+)
        table.insert(vertices, position + Vector3(1, 0, 0))
        table.insert(vertices, position + Vector3(1, 1, 0))
        table.insert(vertices, position + Vector3(1, 1, 1))
        table.insert(vertices, position + Vector3(1, 0, 1))
        
    elseif face == VoxelFace.Left then
        -- 左面 (X-)
        table.insert(vertices, position + Vector3(0, 0, 1))
        table.insert(vertices, position + Vector3(0, 1, 1))
        table.insert(vertices, position + Vector3(0, 1, 0))
        table.insert(vertices, position + Vector3(0, 0, 0))
    end
end

--[[
添加一个面的三角形索引

参数：
    triangles: 三角形索引列表
    vertexCount: 当前顶点总数
]]
function VoxelMeshBuilder:AddFaceTriangles(triangles, vertexCount)
    local offset = vertexCount - 4
    
    -- 第一个三角形
    table.insert(triangles, offset + 0)
    table.insert(triangles, offset + 1)
    table.insert(triangles, offset + 2)
    
    -- 第二个三角形
    table.insert(triangles, offset + 0)
    table.insert(triangles, offset + 2)
    table.insert(triangles, offset + 3)
end

--[[
工具方法：将Lua table转换为C# Vector3数组
]]
function VoxelMeshBuilder:ToVector3Array(luaTable)
    local count = #luaTable
    local array = CS.System.Array.CreateInstance(typeof(Vector3), count)
    for i = 1, count do
        array:SetValue(luaTable[i], i - 1)  -- C#数组从0开始
    end
    return array
end

--[[
工具方法：将Lua table转换为C# int数组
]]
function VoxelMeshBuilder:ToIntArray(luaTable)
    local count = #luaTable
    local array = CS.System.Array.CreateInstance(typeof(CS.System.Int32), count)
    for i = 1, count do
        array:SetValue(luaTable[i], i - 1)  -- C#数组从0开始
    end
    return array
end

--[[
工具方法：将Lua table转换为C# Vector2数组
]]
function VoxelMeshBuilder:ToVector2Array(luaTable)
    local count = #luaTable
    local array = CS.System.Array.CreateInstance(typeof(Vector2), count)
    for i = 1, count do
        array:SetValue(luaTable[i], i - 1)  -- C#数组从0开始
    end
    return array
end

-- 导出模块
return {
    VoxelMeshBuilder = VoxelMeshBuilder,
    VoxelFace = VoxelFace
}
