local ObjModelLoader = {}

-- 引入解析逻辑 (确保 RuntimeObjImporter.lua 在 require 路径中)
local RuntimeObjImporter = require("RuntimeObjImporter")

-- Unity 类型引用 (根据具体 Lua 绑定框架可能略有不同，如 xLua, ToLua, SLua)
local CS = CS or {}
local UnityEngine = CS.UnityEngine
local Resources = UnityEngine and UnityEngine.Resources
local GameObject = UnityEngine and UnityEngine.GameObject
local Vector3 = UnityEngine and UnityEngine.Vector3
local Quaternion = UnityEngine and UnityEngine.Quaternion
local Time = UnityEngine and UnityEngine.Time
local Debug = UnityEngine and UnityEngine.Debug
local TextAsset = UnityEngine and UnityEngine.TextAsset
local MeshFilter = UnityEngine and UnityEngine.MeshFilter
local MeshRenderer = UnityEngine and UnityEngine.MeshRenderer
local Material = UnityEngine and UnityEngine.Material
local Shader = UnityEngine and UnityEngine.Shader

-- 简单的 Mock 环境检测，防止在非 Unity 环境报错
if not UnityEngine then
    Vector3 = { one = {x=1,y=1,z=1}, zero = {x=0,y=0,z=0}, up = {x=0,y=1,z=0} }
    Debug = { Log = print, LogError = print }
    Resources = { Load = function() return nil end }
    Time = { deltaTime = 0.016 }
    Quaternion = { identity = {} }
end

-- 配置参数
ObjModelLoader.modelName = "decimated_1768202429"
ObjModelLoader.modelScale = Vector3.one
ObjModelLoader.autoRotate = true
ObjModelLoader.rotateSpeed = 30.0
ObjModelLoader.currentModel = nil

-- 组件生命周期: Start
function ObjModelLoader:Start()
    self:LoadModel()
end

-- 组件生命周期: Update
function ObjModelLoader:Update()
    if self.autoRotate and self.currentModel then
        -- 旋转模型
        local transform = self.currentModel.transform
        transform:Rotate(Vector3.up * self.rotateSpeed * Time.deltaTime)
    end
end

-- 核心业务逻辑: 加载模型
function ObjModelLoader:LoadModel()
    if not self.modelName or self.modelName == "" then
        Debug.LogError("模型名称为空！")
        return
    end

    -- 策略 1: 尝试使用 RuntimeObjImporter 加载 (OBJ 文本)
    -- 对应于用户提供的 Importer 脚本功能
    -- 假设 Resources 中有同名的 .txt 或 .obj (作为 TextAsset)
    local textAsset = Resources.Load(self.modelName, typeof(TextAsset))
    
    if textAsset then
        local content = textAsset.text
        -- 调用解析逻辑
        local result = RuntimeObjImporter.Import(content)
        
        if result and result.mesh then
            -- 清理旧模型
            if self.currentModel then
                UnityEngine.Object.Destroy(self.currentModel)
            end
            
            -- 创建新 GameObject
            self.currentModel = GameObject("LoadedObjModel")
            
            -- 设置 Transform
            local t = self.currentModel.transform
            t:SetParent(self.transform)
            t.localPosition = Vector3.zero
            t.localRotation = Quaternion.identity
            t.localScale = self.modelScale
            
            -- 添加 Mesh 组件
            local mf = self.currentModel:AddComponent(typeof(MeshFilter))
            local mr = self.currentModel:AddComponent(typeof(MeshRenderer))
            
            mf.mesh = result.mesh
            
            -- 设置默认材质 (否则模型不可见/粉色)
            local shader = Shader.Find("Standard") or Shader.Find("Diffuse")
            if shader then
                mr.material = Material(shader)
            end
            
            Debug.Log("成功通过 RuntimeObjImporter 加载 OBJ: " .. self.modelName)
            return
        end
    end

    -- 策略 2: 尝试作为 Prefab 加载 (原 C# ObjModelLoader 逻辑)
    local modelPrefab = Resources.Load(self.modelName)
    
    if not modelPrefab then
        Debug.LogError("无法在 Resources 目录下找到模型 (TextAsset 或 Prefab): " .. self.modelName)
        return
    end

    -- 清理旧模型
    if self.currentModel then
        UnityEngine.Object.Destroy(self.currentModel)
    end

    -- 实例化 Prefab
    self.currentModel = UnityEngine.Object.Instantiate(modelPrefab, self.transform.position, self.transform.rotation)
    
    local t = self.currentModel.transform
    t:SetParent(self.transform)
    t.localScale = self.modelScale
    t.localPosition = Vector3.zero
    
    Debug.Log("成功加载 Prefab 模型: " .. self.modelName)
end

return ObjModelLoader
