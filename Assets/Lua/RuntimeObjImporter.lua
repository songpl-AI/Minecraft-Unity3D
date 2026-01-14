local RuntimeObjImporter = {}

-- 获取 Unity 类型引用
local CS = CS or {}
local UnityEngine = CS.UnityEngine
local Vector3 = UnityEngine and UnityEngine.Vector3
local Vector2 = UnityEngine and UnityEngine.Vector2
local Mesh = UnityEngine and UnityEngine.Mesh
local IndexFormat = UnityEngine and UnityEngine.Rendering and UnityEngine.Rendering.IndexFormat

-- 如果不在 Unity 环境中，提供简单的 Mock 实现（防止报错，方便测试）
if not UnityEngine then
    Vector3 = { 
        zero = {x=0, y=0, z=0}, 
        up = {x=0, y=1, z=0},
        new = function(x,y,z) return {x=x, y=y, z=z} end 
    }
    setmetatable(Vector3, { __call = function(_, x,y,z) return Vector3.new(x,y,z) end })
    
    Vector2 = { 
        zero = {x=0, y=0},
        new = function(x,y) return {x=x, y=y} end 
    }
    setmetatable(Vector2, { __call = function(_, x,y) return Vector2.new(x,y) end })
    
    Mesh = { new = function() 
        return { 
            RecalculateNormals = function() end,
            RecalculateBounds = function() end
        } 
    end }
    IndexFormat = { UInt32 = 1 }
end

-- 字符串分割工具函数
local function SplitString(str, separator)
    local result = {}
    -- 使用 pattern 匹配分割
    -- 注意：特殊字符需要转义
    local pattern = "(.-)" .. separator
    for match in (str .. separator):gmatch(pattern) do
        table.insert(result, match)
    end
    return result
end

local function SplitByWhitespace(str)
    local result = {}
    for match in str:gmatch("%S+") do
        table.insert(result, match)
    end
    return result
end

-- 添加顶点数据辅助函数
local function AddVertexData(vIdx, tIdx, nIdx, sourceV, sourceT, sourceN, destV, destT, destN, destTriangles)
    -- Lua 数组从 1 开始，OBJ 索引从 1 开始
    -- sourceV[vIdx]
    if vIdx > 0 and vIdx <= #sourceV then
        table.insert(destV, sourceV[vIdx])
    else
        table.insert(destV, Vector3.zero)
    end

    if tIdx > 0 and tIdx <= #sourceT then
        table.insert(destT, sourceT[tIdx])
    elseif #destT > 0 or #sourceT > 0 then
        -- 如果有任何纹理坐标，保持数组对齐
        table.insert(destT, Vector2.zero)
    end

    if nIdx > 0 and nIdx <= #sourceN then
        table.insert(destN, sourceN[nIdx])
    elseif #destN > 0 or #sourceN > 0 then
        table.insert(destN, Vector3.up)
    end

    -- destV 的长度就是当前新顶点的 1-based 索引
    -- Unity Mesh.triangles 期望的是 0-based 索引
    table.insert(destTriangles, #destV - 1)
end

-- 主导入函数
function RuntimeObjImporter.Import(objContent)
    local vertices = {}
    local normals = {}
    local uv = {}
    
    local newVertices = {}
    local newNormals = {}
    local newUVs = {}
    local triangles = {}
    
    local mtlFileName = ""
    
    -- 按行处理
    for line in objContent:gmatch("[^\r\n]+") do
        local l = line:gsub("^%s*(.-)%s*$", "%1") -- Trim
        
        -- 跳过空行和注释
        if l ~= "" and not l:find("^#") then
            local parts = SplitByWhitespace(l)
            if #parts > 0 then
                local type = parts[1]
                
                if type == "mtllib" then
                    if #parts > 1 then
                        mtlFileName = parts[2]
                    end
                elseif type == "v" then
                    local x = tonumber(parts[2]) or 0
                    local y = tonumber(parts[3]) or 0
                    local z = tonumber(parts[4]) or 0
                    -- 坐标转换: new Vector3(-x, y, z)
                    table.insert(vertices, Vector3(-x, y, z))
                elseif type == "vn" then
                    local x = tonumber(parts[2]) or 0
                    local y = tonumber(parts[3]) or 0
                    local z = tonumber(parts[4]) or 0
                    -- 坐标转换: new Vector3(-x, y, z)
                    table.insert(normals, Vector3(-x, y, z))
                elseif type == "vt" then
                    local u = tonumber(parts[2]) or 0
                    local v = tonumber(parts[3]) or 0
                    table.insert(uv, Vector2(u, v))
                elseif type == "f" then
                    local vIndices = {}
                    local tIndices = {}
                    local nIndices = {}
                    
                    -- parts[1] 是 "f"，后续是索引数据
                    for i = 2, #parts do
                        local indexStr = parts[i]
                        local subParts = SplitString(indexStr, "/")
                        
                        -- v 索引
                        if #subParts >= 1 and subParts[1] ~= "" then
                            table.insert(vIndices, tonumber(subParts[1]))
                        else
                            -- OBJ 索引如果不合法通常设为0或者忽略，这里用0占位
                            table.insert(vIndices, 0)
                        end
                        
                        -- vt 索引
                        if #subParts >= 2 and subParts[2] ~= "" then
                            table.insert(tIndices, tonumber(subParts[2]))
                        else
                            table.insert(tIndices, 0)
                        end
                        
                        -- vn 索引
                        if #subParts >= 3 and subParts[3] ~= "" then
                            table.insert(nIndices, tonumber(subParts[3]))
                        else
                            table.insert(nIndices, 0)
                        end
                    end
                    
                    -- 三角剖分 (Triangulate)
                    -- 假设是凸多边形，使用扇形剖分
                    for i = 1, #vIndices - 2 do
                        AddVertexData(vIndices[1], tIndices[1], nIndices[1], vertices, uv, normals, newVertices, newUVs, newNormals, triangles)
                        AddVertexData(vIndices[i + 1], tIndices[i + 1], nIndices[i + 1], vertices, uv, normals, newVertices, newUVs, newNormals, triangles)
                        AddVertexData(vIndices[i + 2], tIndices[i + 2], nIndices[i + 2], vertices, uv, normals, newVertices, newUVs, newNormals, triangles)
                    end
                end
            end
        end
    end
    
    -- 创建 Mesh 对象
    local mesh = Mesh.new()
    
    -- 设置索引格式
    if #newVertices > 65000 then
        mesh.indexFormat = IndexFormat.UInt32
    end
    
    -- 赋值 Mesh 数据
    -- 注意: 具体赋值方式取决于 Lua 绑定库 (xLua, ToLua 等)
    -- 通常可以直接赋值 Lua Table 或者需要转为 C# Array/List
    -- 这里假设可以直接赋值
    mesh.vertices = newVertices
    
    if #newUVs > 0 then
        mesh.uv = newUVs
    end
    
    if #newNormals > 0 then
        mesh.normals = newNormals
    end
    
    mesh.triangles = triangles
    
    if #newNormals == 0 then
        mesh:RecalculateNormals()
    end
    
    mesh:RecalculateBounds()
    
    return { mesh = mesh, mtlFileName = mtlFileName }
end

return RuntimeObjImporter
