---
---  Author: 【杨浩】
---  AuthorID: 【149456】
---  CreateTime: 【2025-9-22 16:12:03】
--- 【FSync】
--- 【家园UGC】
---
local EventTriggerTypeNameSpace = CS.UnityEngine.EventSystems
local Util = require(MAIN_SCRIPTS_LOC .. "common/util")

local MessageKey = {
    [1] = {
        PARK_DECORATE_CHANGED = "PARK_DECORATE_CHANGED",
        HOME_COURTYARD_AUDIT_RESULT = "HOME_COURTYARD_AUDIT_RESULT"
    },
    [2] = {
        PARK_DECORATE_CHANGED = "FREE_DECORATE_CHANGED",
        HOME_COURTYARD_AUDIT_RESULT = "HOME_GARDEN_AUDIT_RESULT"
    },
    [3] = {
        PARK_DECORATE_CHANGED = "FREE_DECORATE_CHANGED",
        HOME_COURTYARD_AUDIT_RESULT = "HOME_MAP_AUDIT_RESULT"
    }
}

local SpecialGuid = {
    birthpoint_blue = "birthpoint_blue",
    birthpoint_red = "birthpoint_red",
    track_start_end = "track_start_end" -- 赛道起点终点
}

local rt_scale = 1

local move_step = 0.5
local camera_move_speed = 16
local obj_move_speed = 3
local DRAG_ROTATE_SENS = 0.18

local Layer_enum = {
    defaultLayer = 22, -- 默认的layer 不能响应点击
    furnitureLayer = 23, -- 放置的家具层 点击可以把家具拿起来
    trackLayer = 29, -- 赛道层
    wallLayer = 30, -- 阻挡移动家具的空气墙
    selectedLayer = 31 -- 选中家具的layer
}

Game_Type = { -- 特殊互动道具
    Question = 1, -- 答题宝箱
    End = 2, -- 终点旗帜
    Track = 9 -- 赛道
}

local ActionType = {
    Prop = 0,
    Camera = 1
}

local Action = {
    Forward = 0,
    Backward = 1,
    Left = 2,
    Right = 3,
    Up = 4,
    Down = 5,
    Rotate = 6
}

-- 运动器类型
local Move_Type = {
    None = 0,
    Jump = 1, -- 弹跳板
    Shoot = 2, -- 弹射板
    Trans = 3, -- 传送带
    Speed = 4 -- 加速鞋
}

-- 选中模式
local Select_Mode = {
    Single = 1, -- 单选
    Multi_Click = 2, -- 多选点选
    Multi_Frame = 3 -- 多选点选+框选
}

local Camera_Mode = {
    Normal = 1, -- 正常
    BirdEye = 2 -- 鸟瞰视角
}

UGC_MAP_TYPE = {
    ShootGame = 1, -- 枪战地图
    Free = 2, -- 自由地图
    KartGame = 3 -- 赛车地图
}

-- 相机缩放（视角）范围
local CAMERA_FOV_MIN = 25
local CAMERA_FOV_MAX = 75
local PINCH_FOV_SENS = 0.06

local Max_Question_Count = 10
local Max_End_Count = 1

local Camera_Gap = 2

local r1 = Quaternion.AngleAxis(-45, Vector3.forward);
local r2 = Quaternion.AngleAxis(-135, Vector3.forward);
local r3 = Quaternion.AngleAxis(-90, Vector3.forward);
local r4 = Quaternion.AngleAxis(45, Vector3.forward);
local r5 = Quaternion.AngleAxis(135, Vector3.forward);
local r6 = Quaternion.AngleAxis(90, Vector3.forward);
local r7 = Quaternion.AngleAxis(0, Vector3.forward);
local r8 = Quaternion.AngleAxis(180, Vector3.forward);

UGCSource = {
    Park = 1, -- 庭院UGC
    IsLand = 2, -- 岛屿UGC
    Custom = 3 -- 自定义UGC
}

local MaxPlace = {
    [1] = 8000,
    [2] = 40000,
    [3] = 40000
}

local TEST_LOCAL_CACHE = false

local TAG = "家园UGC"
local TEXT_SAVE_KEY = "commit_test" .. tostring(App.Uuid)
local KEY_HOME_DATA = "Yard_HomeData" .. tostring(App.Info.userId)
local HomeData_yard = "HomeData_" .. tostring(App.Uuid)

local editorPanel = nil

local class = require("middleclass")
local WBElement = require("mworld/worldBaseElement")

UGCEditor = class("UGCEditor", WBElement)

function UGCEditor:initialize(worldElement, UGCSourceType, BagType, logTag, usePhysics)
    UGCEditor.super.initialize(self, worldElement)

    g_Log("UGCEditor", "initialize", UGCSourceType, logTag)
    if App.IsUltraLowDevice and App.CameraRTScale then
        rt_scale = 0.75
    end

    if HOME_CONFIG_INFO.MapType and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
        camera_move_speed = 40
        obj_move_speed = 20
    end

    self.TAG = logTag or TAG
    self.TEXT_SAVE_KEY = TEXT_SAVE_KEY .. tostring(UGCSourceType) -- 存储发布的名字
    self.KEY_HOME_DATA = KEY_HOME_DATA .. tostring(UGCSourceType) -- 存储家园数据
    self.HomeData_yard = HomeData_yard .. tostring(UGCSourceType) -- Studio调试用

    self.UGCSourceType = UGCSourceType
    self.BagType = BagType
    self.usePhysics = usePhysics

    self.PARK_DECORATE_CHANGED = MessageKey[UGCSourceType].PARK_DECORATE_CHANGED or "PARK_DECORATE_CHANGED"
    self.HOME_COURTYARD_AUDIT_RESULT = MessageKey[UGCSourceType].HOME_COURTYARD_AUDIT_RESULT or
                                           "HOME_COURTYARD_AUDIT_RESULT"

    self:SubscribeMsgKey(self.PARK_DECORATE_CHANGED)
    if HOME_CONFIG_INFO.IsOwner then
        self:SubscribePeerMsgKey(self.HOME_COURTYARD_AUDIT_RESULT)
    end

    self.platformText = "寻宝"

    self.select_mode = Select_Mode.Single
    self.camera_mode = Camera_Mode.Normal

    self.avatarList = {}
    ---@type JoystickService
    self.joystickService = CourseEnv.ServicesManager:GetJoystickService()

    local ts_2024 = 1704038400000
    local curTs = CS.Tal.Statistic.TimeSynManager.S.currentLocalTimeStampInMillion

    self.IdStart = curTs - ts_2024
    if self.IdStart <= 0 then
        self.IdStart = 0
    end

    self.PlaceMap = {}

    self.allAvatarVisable = true

    self.isAppling = false
    self.lastFailed_location = nil

    self.game_questionCount = 0 -- 问题数量
    self.game_endCount = 0 -- 结束数量
    self.game_question_list = {} -- 问题列表

    self.finish_game_questionCount = 0

    self.gameStart = false -- 是否摆放玩法
    self.gameChallenging = false -- 是否开启挑战

    -- 创建一个弱引用数组
    self.weakRefArray = setmetatable({}, {
        __mode = "v"
    })

    -- 撤销还原栈
    self.undoStack = {}
    self.redoStack = {}
    self.stackSize = 100
    self.editCount = 0

    -- 选中信息
    self.selectedMap = {}
    self.selectedList = {}
    self.selectedBoxMap = {}

    self:InitListener()
    self:initView()
    self:InitColliderLayer()
end

function UGCEditor:ComputeRegionId(x, z)
    local cols = self.RegionCols or 10
    local rows = self.RegionRows or 10
    local x_min, x_max = self.X_MIN or 0, self.X_MAX or 0
    local z_min, z_max = self.Z_MIN or 0, self.Z_MAX or 0
    local x_len = x_max - x_min
    local z_len = z_max - z_min
    if cols <= 0 or rows <= 0 or x_len <= 0 or z_len <= 0 then
        return 1
    end
    local col_w = x_len / cols
    local row_h = z_len / rows
    local col = math.floor((x - x_min) / col_w) + 1
    local row = math.floor((z - z_min) / row_h) + 1
    if col < 1 then
        col = 1
    elseif col > cols then
        col = cols
    end
    if row < 1 then
        row = 1
    elseif row > rows then
        row = rows
    end
    return (row - 1) * cols + col
end

function UGCEditor:InitColliderLayer()
    if self.initedLayer then
        return
    end
    self.initedLayer = true

    self.wallRoot = self.VisElement.transform:Find("解锁区域")
    self.airWall = self.VisElement.transform:Find("空气墙")

    if not self.wallRoot then
        return
    end

    if not self.airWall then
        return
    end

    self.colliderService:SetLayerRecursively(self.wallRoot.gameObject, Layer_enum.wallLayer)
    self.colliderService:SetLayerRecursively(self.airWall.gameObject, Layer_enum.wallLayer)

    for i = 0, 31, 1 do
        if i == Layer_enum.wallLayer or i == Layer_enum.defaultLayer then
            -- 选中层只和空气墙碰
            CS.UnityEngine.Physics.IgnoreLayerCollision(Layer_enum.selectedLayer, i, false)
        else
            -- 选中层和所有层都不碰
            CS.UnityEngine.Physics.IgnoreLayerCollision(Layer_enum.selectedLayer, i, true)
        end

        -- 空气墙和人和选中都碰
        if i ~= Layer_enum.selectedLayer and i ~= 15 and i ~= 14 then
            CS.UnityEngine.Physics.IgnoreLayerCollision(Layer_enum.wallLayer, i, true)
        else
            CS.UnityEngine.Physics.IgnoreLayerCollision(Layer_enum.wallLayer, i, false)
        end
    end

    CS.UnityEngine.Physics.IgnoreLayerCollision(Layer_enum.trackLayer, 15, false)
    CS.UnityEngine.Physics.IgnoreLayerCollision(Layer_enum.trackLayer, 14, false)

    local island = GameObject.Find("自由建造空岛")
    if not island then
        return
    end

    self.colliderService:SetLayerRecursively(island, Layer_enum.defaultLayer)

    local gm = self.VisElement.transform:Find("解锁区域")
    if not gm then
        return
    end

    self.unlockGo = gm
    self.areaConfig = {}
    for i = 1, 5, 1 do
        local area1 = gm:Find("区域" .. i)

        local minX, maxX, minZ, maxZ = self:GetBoundGap(area1)
        self.areaConfig[i] = {
            minX = minX,
            maxX = maxX,
            minZ = minZ,
            maxZ = maxZ,
            unlocked = false,
            p = {
                x = area1.transform.position.x,
                y = area1.transform.position.y + 0.6,
                z = area1.transform.position.z
            }
        }
    end

end
function UGCEditor:GetBoundGap(gm)
    local renders = gm:GetComponentsInChildren(typeof(CS.UnityEngine.Renderer))
    -- 遍历计算render的bounds x,z的最大最小值
    local minX = 9999
    local maxX = -9999
    local minZ = 9999
    local maxZ = -9999
    for i = 0, renders.Length - 1 do
        local render = renders[i]
        local bounds = render.bounds
        local min = bounds.min
        local max = bounds.max
        if min.x < minX then
            minX = min.x
        end
        if max.x > maxX then
            maxX = max.x
        end
        if min.z < minZ then
            minZ = min.z
        end
        if max.z > maxZ then
            maxZ = max.z
        end
    end
    return minX, maxX, minZ, maxZ
end

function UGCEditor:FindNearestBirthPos()
    local cur = Camera.main.transform.position
    local nearestDistance = nil
    local nearestPos = nil
    for i, v in ipairs(self.areaConfig) do
        if v.unlocked then
            local p = v.p

            local distance = Vector3.Distance(cur, Vector3(p.x, p.y, p.z))
            if not nearestDistance or distance < nearestDistance then
                nearestDistance = distance
                nearestPos = p
            end

        end
    end

    return nearestPos

end

function UGCEditor:CheckArea(pos, w, h)
    local x = pos.x
    local z = pos.z

    -- 检查物体是否完全在任何一个解锁区域内
    local inUnlockedArea = false
    for i = 1, 5, 1 do
        local area = self.areaConfig[i]
        if area.unlocked then
            if x - w >= area.minX and x + w <= area.maxX and z - h >= area.minZ and z + h <= area.maxZ then
                inUnlockedArea = true
                break
            end
        end
    end

    -- 如果物体完全在一个解锁区域内，允许移动
    if inUnlockedArea then
        return true
    end

    -- 检查物体是否跨越两个相邻的解锁区域
    for i = 1, 5, 1 do
        for j = i + 1, 5, 1 do
            local area1 = self.areaConfig[i]
            local area2 = self.areaConfig[j]
            if area1.unlocked and area2.unlocked then
                -- 检查两个区域是否相邻
                if (math.abs(area1.maxX - area2.minX) < 0.1 or math.abs(area2.maxX - area1.minX) < 0.1) or
                    (math.abs(area1.maxZ - area2.minZ) < 0.1 or math.abs(area2.maxZ - area1.minZ) < 0.1) then
                    -- 检查物体是否只跨越这两个解锁区域
                    local minX = math.min(area1.minX, area2.minX) - 0.1
                    local maxX = math.max(area1.maxX, area2.maxX) + 0.1
                    local minZ = math.min(area1.minZ, area2.minZ) - 0.1
                    local maxZ = math.max(area1.maxZ, area2.maxZ) + 0.1
                    if x - w >= minX and x + w <= maxX and z - h >= minZ and z + h <= maxZ then
                        -- 额外检查：确保物体不在任何未解锁区域内
                        local inUnlockedAreaOnly = true
                        for k = 1, 5, 1 do
                            local area = self.areaConfig[k]
                            if not area.unlocked then
                                if x - w < area.maxX and x + w > area.minX and z - h < area.maxZ and z + h > area.minZ then
                                    inUnlockedAreaOnly = false
                                    break
                                end
                            end
                        end
                        if inUnlockedAreaOnly then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

function UGCEditor:InitListener()

    self.observerService:Watch("GAME_PROP_SHOP", function(key, args)

        if not self.isEditing then
            return
        end

        local param = args[0]
        if not param then
            return
        end

        local callback = param.callback

        self:SaveAndExit(callback)

    end)

    -- 放家具进来
    self.observerService:Watch("EVENT_HOME_CLICK_SKIN", function(key, args)

        if not self.isEditing then
            return
        end

        local param = args[0]
        if not param then
            return
        end

        local bagType = param.bagType
        if bagType and bagType ~= self.BagType then
            return
        end

        if not self:CanOperate() then
            return
        end

        g_Log(self.TAG, "EVENT_HOME_CLICK_SKIN", table.dump(param))

        local uaddress = param.uAddress or param.uaddress
        local id = param.id
        local cost = param.cost or 1
        local scale = param.scale or 1
        local typeJ = param.type
        local pos = param.pos
        if typeJ == 4 or typeJ == 5 then
            return
        end

        local gameType = param.gameType

        if gameType == 0 then
            gameType = nil
        end

        if gameType == Game_Type.Question then
            if self.game_questionCount >= Max_Question_Count then
                CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("最多设置10题")
                return
            end
            if App.IsStudioClient then
                uaddress = "954421734589490/assets/Prefabs/baoxiang.prefab"
                scale = 1
            end
        elseif gameType == Game_Type.End then
            if self.game_endCount >= Max_End_Count then
                CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("最多设置1个终点")
                return
            end
        end

        local mover_type = param.mover_type
        local mover_attributes = {}
        if type(param.mover_attributes) == "string" and param.mover_attributes ~= "" then
            mover_attributes = self.jsonService:decode(param.mover_attributes)
        end

        local img = param.img
        local level = param.level

        if string.startswith(img, "https://static0.xesimg.com") then
            -- 取代这个前缀节约存储空间
            img = string.gsub(img, "https://static0.xesimg.com", "")
        end

        self:AddProp(uaddress, id, cost, scale, gameType, mover_type, mover_attributes, img, level, pos)

        if self.extendMutiSelectMenu then
            self.multiBtn.onClick:Invoke()
        end

    end)

    self.observerService:Watch("EVETN_MAIN_PANEL_HIDE", function()

    end)

    self.observerService:Watch("EVETN_MAIN_PANEL_SHOW", function()

    end)

    self.observerService:Watch("EVENT_HOME_MODE_CHANGED", function()

        if not self.isEditing then
            return
        end

        self:SaveAndExit()
    end)
end

function UGCEditor:initView()
    if self.inited then
        return
    end

    if editorPanel then
        local new = GameObject.Instantiate(editorPanel.gameObject)
        local old = self.VisElement.transform:Find("编辑面板")
        if old then
            GameObject.DestroyImmediate(old.gameObject)
        end

        new.transform:SetParent(self.VisElement.transform)
        new.transform.localPosition = Vector3.zero
        new.transform.localRotation = Quaternion.identity
        new.transform.localScale = Vector3.one
        new.name = "编辑面板"

    end

    self.clickAudio = self.configService:GetAssetByConfigKey(self.VisElement, "clickAudio")
    self.cameraAudio = self.configService:GetAssetByConfigKey(self.VisElement, "cameraAudio")

    self.cameraJoystickV3 = Vector3.zero
    self.moveJoystickV3 = Vector3.zero

    self.inited = true

    self.openView = self.VisElement.transform:Find("编辑面板")
    self.openView.gameObject:SetActive(false)

    self.goParent = self.VisElement.transform:Find("家具节点")

    self.root = self.openView.transform:Find("Asset/Canvas")
    self.canvas = self.root:GetComponent(typeof(CS.UnityEngine.Canvas))
    self.canvas.sortingOrder = 150

    self.touchPad = self.root:Find("touchPad")
    self.moveView = self.openView.transform:Find("Asset/Canvas/OpView")
    self.moveView.gameObject:SetActive(false)

    self.cameraView = self.openView.transform:Find("Asset/Canvas/cameraView")
    self.cametaSlider = self.cameraView.transform:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))

    self.cameraJoystick = self.cameraView.transform:Find("Joystick"):GetComponent(typeof(CS.ETCJoystick))
    self.moveJoystick = self.moveView.transform:Find("Joystick"):GetComponent(typeof(CS.ETCJoystick))
    self.moveJoystick_gray = self.moveView.transform:Find("Joystick_gray")

    self.updownBg = self.moveView.transform:Find("bg")
    self.updownBg_gray = self.moveView.transform:Find("bg_gray")

    self.cameraDir = self.cameraView.transform:Find("Joystick/dir")
    self.moveDir = self.moveView.transform:Find("Joystick/dir")

    -- 定位按钮
    self.locateBtn = self.moveView.transform:Find("locateBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.commitView = self.openView.transform:Find("Asset/Canvas/submitView")

    self.commitBtn = self.commitView:Find("finishBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.resetBtn = self.commitView:Find("resetBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.saveBtn = self.commitView:Find("saveBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.playBtn = self.commitView:Find("playBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.helpBtn = self.commitView:Find("helpBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.undoBtn = self.commitView:Find("back_forward/backBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.redoBtn = self.commitView:Find("back_forward/forwardBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.scanBtn = self.commitView:Find("scanBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    if self.UGCSourceType == UGCSource.IsLand then
        self.scanBtn.gameObject:SetActive(true)
    end

    self.redoUndoView = self.commitView:Find("back_forward")
    self.redoUndoView.transform:SetParent(self.root, false)
    -- 设置成子节点第5个
    self.redoUndoView.transform:SetSiblingIndex(5)

    -- if not App.IsStudioClient then
    self.playBtn.gameObject:SetActive(true)
    -- end
    self.shopBtn = self.openView.transform:Find("Asset/Canvas/shopBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    if self.UGCSourceType == UGCSource.Custom then
        self.shopBtn.gameObject:SetActive(true)
    else
        self.shopBtn.gameObject:SetActive(false)
    end

    self.swichCameraBtn = self.openView.transform:Find("Asset/Canvas/swichCameraBtn"):GetComponent(typeof(CS.UnityEngine
                                                                                                              .UI.Button))

    self.shotScreenView = self.openView.transform:Find("Asset/Canvas/shotView")
    self.shotExitBtn = self.shotScreenView:Find("exitBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.shotBtn = self.shotScreenView:Find("shotBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.shotImage = self.shotScreenView:Find("Image"):GetComponent(typeof(CS.UnityEngine.UI.Image))
    -- image的透明度改0.5
    self.shotImage.color = CS.UnityEngine.Color(1, 1, 1, 0.5)

    self.playView = self.openView.transform:Find("Asset/Canvas/playView")
    self.playBackBtn = self.playView:Find("backBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.cube = self.VisElement.transform:Find("Cube")
    self.y_minObj = self.VisElement.transform:Find("Y_MIN")
    self.y_maxObj = self.VisElement.transform:Find("Y_MAX")
    self.camera_y_minObj = self.VisElement.transform:Find("Camera_Y_MIN")
    self.camera_y_maxObj = self.VisElement.transform:Find("Camera_Y_MAX")
    self.camera_posObj = self.VisElement.transform:Find("Camera_Pos")
    self.play_posObj = self.VisElement.transform:Find("Play_Pos")

    self.arrowEffect = self.VisElement.transform:Find("arrow")

    self.guideView = self.openView.transform:Find("Asset/Canvas/guideView")

    self.guideView.gameObject:SetActive(false)

    self.plusOpView = self.openView.transform:Find("Asset/Canvas/copy_selectBg")

    self.copyBtn = self.plusOpView:Find("copyBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.multiBtn = self.plusOpView:Find("duoxuanBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.mutiSelectView = self.openView.transform:Find("Asset/Canvas/muti_select")
    -- 这个UI在当前基础上往下20
    local mutiSelectViewRect = self.mutiSelectView.gameObject:GetComponent(typeof(CS.UnityEngine.RectTransform))
    mutiSelectViewRect.anchoredPosition = Vector2(mutiSelectViewRect.anchoredPosition.x,
        mutiSelectViewRect.anchoredPosition.y - 40)

    self.mutiFrameView = self.openView.transform:Find("Asset/Canvas/kuang")
    self.muti_clickBtn = self.mutiSelectView:Find("singleBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.muti_frameBtn = self.mutiSelectView:Find("mutiBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.muti_list_btn = self.openView.transform:Find("Asset/Canvas/pickBtn"):GetComponent(typeof(CS.UnityEngine.UI
                                                                                                      .Button))
    self.muti_listView = self.openView.transform:Find("Asset/Canvas/rightSelectView")
    self.muti_clearBtn = self.muti_listView:Find("clearBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.muti_closeBtn = self.muti_listView:Find("closeBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.muti_empty = self.muti_listView:Find("empty")
    self.item = self.muti_listView:Find("Item")
    self.muti_list_scrollview = self.muti_listView:Find("Scroll View")
        :GetComponent(typeof(CS.UnityEngine.UI.ScrollRect))
    self.muti_listView.gameObject:SetActive(false)

    self.tipsView = self.openView.transform:Find("Asset/Canvas/tipsView")
    self.tipsHorLayout = self.tipsView:GetComponent(typeof(CS.UnityEngine.UI.HorizontalLayoutGroup))
    self.tipsText = self.tipsView:Find("Text (TMP)"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))

    -- guideview的image组件透明度黑色80%
    self.guideView:GetComponent(typeof(CS.UnityEngine.UI.Image)).color = CS.UnityEngine.Color(0, 0, 0, 0.85)
    self.guideCloseBtn = self.guideView:Find("closeBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.guideBtn = self.guideView:Find("btn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.X_MIN = self.cube.position.x - self.cube.localScale.x / 2
    self.X_MAX = self.cube.position.x + self.cube.localScale.x / 2

    self.Z_MIN = self.cube.position.z - self.cube.localScale.z / 2
    self.Z_MAX = self.cube.position.z + self.cube.localScale.z / 2

    -- 初始化区域分区映射（默认 10x10，可通过 RegionCols/RegionRows 覆盖）
    self.RegionCols = self.RegionCols or 10
    self.RegionRows = self.RegionRows or 10
    self.RegionMap = {}
    do
        local x_len = (self.X_MAX or 0) - (self.X_MIN or 0)
        local z_len = (self.Z_MAX or 0) - (self.Z_MIN or 0)
        if self.RegionCols > 0 and self.RegionRows > 0 and x_len > 0 and z_len > 0 then
            for row = 1, self.RegionRows do
                for col = 1, self.RegionCols do
                    local id = (row - 1) * self.RegionCols + col
                    self.RegionMap[id] = {
                        row = row,
                        col = col
                    }
                end
            end
        end
    end

    if self.y_minObj then
        self.Y_MIN = self.y_minObj.transform.position.y
    end

    if self.y_maxObj then
        self.Y_MAX = self.y_maxObj.transform.position.y
    end

    if self.camera_y_minObj then
        self.CAMERA_Y_MIN = self.camera_y_minObj.transform.position.y
    end

    if self.camera_y_maxObj then
        self.CAMERA_Y_MAX = self.camera_y_maxObj.transform.position.y
    end

    self:InitGameUI()
    self:InitMapGameUI()
    self:InitSubmitUI()
    self:InitGameSubmitUI()
    self:InitEvent()
    self:InitSelectUI()

    self:InitParamAdjustUI()

    -- 根据编辑类型，控制相关UI显隐
    if self.UGCSourceType == UGCSource.Custom then
        self.gameSetViewMap.gameObject:SetActive(true)
        self.gameSetView.gameObject:SetActive(false)
    else
        self.gameSetViewMap.gameObject:SetActive(false)
        self.gameSetView.gameObject:SetActive(true)
    end
end

function UGCEditor:InitGameUI()

    self.gameSetView = self.commitView:Find("gameSetView")

    self.gameSetTitle = self.gameSetView:Find("Text"):GetComponent(typeof(CS.UnityEngine.UI.Text))
    self.gameSetTitle.text = (self.UGCSourceType == UGCSource.Park and "庭院-" or "小岛") .. self.platformText ..
                                 "挑战"

    self.gameEntranceBtn = self.commitView:Find("gameBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.game_closeBtn = self.gameSetView:Find("closeBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.game_normalView = self.gameSetView:Find("normalView")
    self.game_startView = self.gameSetView:Find("startView")

    self.game_normalText = self.game_normalView:Find("Text"):GetComponent(typeof(CS.UnityEngine.UI.Text))
    self.game_normalText.text = "点击下方开启,摆放" .. self.platformText ..
                                    "挑战道具,即可完成我的关卡设置。"

    self.game_startBtn = self.game_normalView:Find("start"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.game_cancelBtn = self.game_startView:Find("cancelBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.game_startView:Find("Text1"):GetComponent(typeof(CS.UnityEngine.UI.Text)).text = "放置宝箱"
    self.game_startView:Find("Text2"):GetComponent(typeof(CS.UnityEngine.UI.Text)).text = "放置终点旗帜"

    self.game_tips1Text = self.game_startView:Find("tip1/Text"):GetComponent(typeof(CS.UnityEngine.UI.Text))
    self.game_tips2Text = self.game_startView:Find("tip2/Text"):GetComponent(typeof(CS.UnityEngine.UI.Text))

    self.game_tips1Icon = self.game_startView:Find("tip1/icon")
    self.game_tips2Icon = self.game_startView:Find("tip2/icon")

    self.game_tips1Layout = self.game_startView:Find("tip1"):GetComponent(
        typeof(CS.UnityEngine.UI.HorizontalLayoutGroup))
    self.game_tips2Layout = self.game_startView:Find("tip2"):GetComponent(
        typeof(CS.UnityEngine.UI.HorizontalLayoutGroup))

    -- 展开
    self.commonService:AddEventListener(self.gameEntranceBtn, "onClick", function()
        self.gameEntranceBtn.gameObject:SetActive(false)
        self.gameSetView.gameObject:SetActive(true)

    end)

    -- 收起
    self.commonService:AddEventListener(self.game_closeBtn, "onClick", function()
        self.gameSetView.gameObject:SetActive(false)
        self.gameEntranceBtn.gameObject:SetActive(true)
    end)

    -- 开启挑战
    self.commonService:AddEventListener(self.game_startBtn, "onClick", function()

        self:ShowGuide(function()

            self.observerService:Fire("GAME_PROP_NOT_ENOUGH", {
                callback = function()
                    self.isDirty = true
                    self:GameSwitch(true)
                    self.observerService:Fire("EDITOR_CHALLENGE_START")
                end
            })

        end)

    end)

    -- 关闭挑战
    self.commonService:AddEventListener(self.game_cancelBtn, "onClick", function()
        if self.game_questionCount > 0 or self.game_endCount > 0 then
            self:ShowAlert("",
                "是否取消挑战模式？取消后场景内的宝箱和旗帜不设有答题功能。", function()

                end, function()
                    self:GameSwitch(false)
                    self.isDirty = true
                end, "仍要取消", "暂不取消")
        else
            self:GameSwitch(false)
        end
    end)
end

function UGCEditor:InitMapGameUI()
    self.gameBtn = self.commitView:Find("gameBtn-game"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.gameBtn.gameObject:SetActive(false)
    self.gameBtnText = self.gameBtn.transform:Find("Text"):GetComponent(typeof(CS.UnityEngine.UI.Text))
    if HOME_CONFIG_INFO then
        if HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.ShootGame then
            self.gameBtnText.text = "精英行动"
        elseif HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.Free then
            self.gameBtnText.text = "自由游玩"
        elseif HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
            self.gameBtnText.text = "极速飞车"
        end
    end
    if self.UGCSourceType == UGCSource.Custom and HOME_CONFIG_INFO and HOME_CONFIG_INFO.IsNew == true then
        -- self.saveBtn.gameObject:SetActive(false)
        self.saveBtn.interactable = false
    end

    self.gameSetViewMap = self.commitView:Find("gameSetView-game")
    -- 关闭按钮
    self.gameSetView_closeBtn = self.gameSetViewMap:Find("closeBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.gameSetView_TitleText = self.gameSetViewMap:Find("Text"):GetComponent(typeof(CS.UnityEngine.UI.Text))
    -- free 区域
    self.gameSetView_free = self.gameSetViewMap:Find("free")
    self.gameSetView_free_birthPoint = self.gameSetView_free:Find("birthPoint")
    self.gameSetView_free_birthPointBtn = self.gameSetView_free_birthPoint:Find("Button"):GetComponent(typeof(
        CS.UnityEngine.UI.Button))

    self.gameSetView_free_track = self.gameSetView_free:Find("kartStartPoint")
    self.gameSetView_free_trackBtn = self.gameSetView_free_track:Find("Button"):GetComponent(typeof(CS.UnityEngine.UI
                                                                                                        .Button))

    -- game 区域
    self.gameSetView_game = self.gameSetViewMap:Find("game")
    self.gameSetView_game_birthPoint = self.gameSetView_game:Find("birthPoint")
    self.gameSetView_game_birthPoint_redBtn = self.gameSetView_game_birthPoint:Find("redButton"):GetComponent(typeof(
        CS.UnityEngine.UI.Button))
    self.gameSetView_game_birthPoint_blueBtn = self.gameSetView_game_birthPoint:Find("blueButton "):GetComponent(typeof(
        CS.UnityEngine.UI.Button))
    -- gun 区域
    self.gameSetView_game_gun = self.gameSetView_game:Find("gun")
    self.gameSetView_game_gunBtn = self.gameSetView_game_gun:Find("Button"):GetComponent(
        typeof(CS.UnityEngine.UI.Button))
    self.gameSetView_game_gunText = self.gameSetView_game_gun:Find("Text")
        :GetComponent(typeof(CS.TMPro.TextMeshProUGUI))
    -- self.gameSetView_game_gunText放到首个子节点
    self.gameSetView_game_gunText.transform:SetAsFirstSibling()
    self.gameSetViewMap.gameObject:SetActive(true)
    if HOME_CONFIG_INFO then
        if HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.Free then
            self.gameSetView_TitleText.text = "自由游玩"
            self.gameSetView_free.gameObject:SetActive(true)
            self.gameSetView_game.gameObject:SetActive(false)
        elseif HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.ShootGame then
            self.gameSetView_TitleText.text = "精英行动"
            self.gameSetView_free.gameObject:SetActive(false)
            self.gameSetView_game.gameObject:SetActive(true)
        elseif HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
            self.gameSetView_TitleText.text = "极速飞车"
            self.gameSetView_free.gameObject:SetActive(true)
            self.gameSetView_game.gameObject:SetActive(false)
            self.gameSetView_free_track.gameObject:SetActive(true)
        end
        -- 颜色改成红色
        self.gameSetView_game_gunText.color = CS.UnityEngine.Color(1, 0, 0, 1)
        self.gameSetView_game_gunText.text = " 未放置"
    end

    -- UI事件监听
    App:GetService("CommonService"):AddEventListener(self.gameBtn, "onClick", function()
        g_Log(TAG, "点击游戏")
        self.gameBtn.gameObject:SetActive(false)
        self.gameSetViewMap.gameObject:SetActive(true)
    end)

    App:GetService("CommonService"):AddEventListener(self.gameSetView_closeBtn, "onClick", function()
        g_Log(TAG, "点击关闭游戏")
        self.gameSetViewMap.gameObject:SetActive(false)
        self.gameBtn.gameObject:SetActive(true)
    end)

    App:GetService("CommonService"):AddEventListener(self.gameSetView_free_birthPointBtn, "onClick", function()
        g_Log(TAG, "点击自由模式出生点")

        -- 自由模式选中蓝色出生点物体
        local guid = SpecialGuid.birthpoint_blue
        local info = self.PlaceMap[guid]
        local go = self.goParent:Find(info.guid)
        self:AddSelection(go, info)
        self:LocateSelectedGo()
    end)

    App:GetService("CommonService"):AddEventListener(self.gameSetView_game_birthPoint_blueBtn, "onClick", function()
        g_Log(TAG, "点击蓝方出生点")
        -- self.gameSetView_game_birthPoint_blueBtn.gameObject:SetActive(false)
        -- self.gameSetView_game_birthPoint_redBtn.gameObject:SetActive(true)

        -- 选中蓝色出生点物体
        local guid = SpecialGuid.birthpoint_blue
        local info = self.PlaceMap[guid]
        local go = self.goParent:Find(info.guid)
        self:AddSelection(go, info)
        self:LocateSelectedGo()
    end)

    App:GetService("CommonService"):AddEventListener(self.gameSetView_game_birthPoint_redBtn, "onClick", function()
        g_Log(TAG, "点击红方出生点")
        -- self.gameSetView_game_birthPoint_redBtn.gameObject:SetActive(false)
        -- self.gameSetView_game_birthPoint_blueBtn.gameObject:SetActive(true)

        -- 选中红色出生点物体
        local guid = SpecialGuid.birthpoint_red
        local info = self.PlaceMap[guid]
        local go = self.goParent:Find(info.guid)
        self:AddSelection(go, info)
        self:LocateSelectedGo()
    end)

    App:GetService("CommonService"):AddEventListener(self.gameSetView_free_trackBtn, "onClick", function()
        g_Log(TAG, "点击赛道起点终点")
        local guid = SpecialGuid.track_start_end
        local info = self.PlaceMap[guid]
        local go = self.goParent:Find(info.guid)
        self:AddSelection(go, info)
        self:LocateSelectedGo()
    end)

    App:GetService("CommonService"):AddEventListener(self.gameSetView_game_gunBtn, "onClick", function()
        g_Log(TAG, "点击枪")
        self:Fire("EVENT_REQUEST_GUN_LIST")
    end)
end

function UGCEditor:InitSelectUI()

    self.mutilNormalSprite = self.multiBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite
    self.mutilShowSprite = self.multiBtn.transform:Find("select").gameObject:GetComponent(typeof(CS.UnityEngine
                                                                                                     .SpriteRenderer))
                               .sprite

    self.muti_singleSprite = self.muti_clickBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite
    self.muti_plusSprite = self.muti_frameBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite

    self.muti_singleSelectSprite = self.muti_clickBtn.transform:Find("select").gameObject:GetComponent(typeof(
        CS.UnityEngine.SpriteRenderer)).sprite
    self.muti_plusSelectSprite = self.muti_frameBtn.transform:Find("select").gameObject:GetComponent(typeof(
        CS.UnityEngine.SpriteRenderer)).sprite

    local ShowMutiSelectMenu = function(show)
        self.mutiSelectView.gameObject:SetActive(show)
        self.multiBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite =
            show and self.mutilShowSprite or self.mutilNormalSprite
    end

    self.ShowMutiSelectMenu = ShowMutiSelectMenu

    local RefreshMutiSelectMenu = function()
        self.muti_clickBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite = self.select_mode ==
                                                                                                 Select_Mode.Multi_Click and
                                                                                                 self.muti_singleSelectSprite or
                                                                                                 self.muti_singleSprite
        self.muti_frameBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite = self.select_mode ==
                                                                                                 Select_Mode.Multi_Frame and
                                                                                                 self.muti_plusSelectSprite or
                                                                                                 self.muti_plusSprite
    end

    self.RefreshMutiSelectMenu = RefreshMutiSelectMenu

    self.commonService:AddEventListener(self.copyBtn, "onClick", function()
        -- TODO 复制功能
        self:CopyAction()
        self.sno_copyCount = self.sno_copyCount + 1
    end)

    -- 是否展开多选功能菜单
    self.extendMutiSelectMenu = false
    -- 默认隐藏
    self.muti_list_btn.gameObject:SetActive(false)

    -- 打开/关闭多选功能菜单
    self.commonService:AddEventListener(self.multiBtn, "onClick", function()
        self.extendMutiSelectMenu = not self.extendMutiSelectMenu

        self.select_mode = self.extendMutiSelectMenu and Select_Mode.Multi_Click or Select_Mode.Single
        self.ShowMutiSelectMenu(self.extendMutiSelectMenu) -- 显示中间多选菜单
        self.RefreshMutiSelectMenu() -- 刷新多选菜单

        -- 切换多选的时候取消选中所有物体
        local count = #self.selectedList
        if count == 1 then
            local info = self.selectedList[1]
            if info.locked == 1 then -- 切多选的时候如果当前已经选中了一个解锁物体，取消选中
                self:ClearAllSelection()
            else -- 如果选择的非锁定物体，出现选择list
                if self.extendMutiSelectMenu and not self.muti_listView.gameObject.activeSelf then
                    self.muti_list_btn.onClick:Invoke()
                end
            end
        elseif count > 1 then
            self:ClearAllSelection()
        end

        -- 触发一下点击事件
        if not self.extendMutiSelectMenu and self.muti_listView.gameObject.activeSelf then
            self.muti_list_btn.onClick:Invoke()
        end

        self.muti_list_btn.gameObject:SetActive(self.extendMutiSelectMenu)
        self.sno_chooseCount = self.sno_chooseCount + 1
    end)

    -- 多选-点选
    self.commonService:AddEventListener(self.muti_clickBtn, "onClick", function()
        self.select_mode = Select_Mode.Multi_Click
        self.RefreshMutiSelectMenu()
    end)

    -- 多选-框选
    self.commonService:AddEventListener(self.muti_frameBtn, "onClick", function()
        self.select_mode = Select_Mode.Multi_Frame
        self.RefreshMutiSelectMenu()
    end)

    self.normalSprite = self.muti_list_btn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite
    self.selectSprite = self.muti_list_btn.transform:Find("select").gameObject:GetComponent(typeof(CS.UnityEngine
                                                                                                       .SpriteRenderer))
                            .sprite
    self.commonService:AddEventListener(self.muti_list_btn, "onClick", function()

        self.muti_listView.gameObject:SetActive(not self.muti_listView.gameObject.activeSelf)
        self.muti_list_btn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite = self.muti_listView
                                                                                                 .gameObject.activeSelf and
                                                                                                 self.selectSprite or
                                                                                                 self.normalSprite

        self:Fire("EVENT_BAG_SHOW_HIDE", {
            isShow = not self.muti_listView.gameObject.activeSelf
        })
        if self.muti_listView.gameObject.activeSelf then
            self.shouldRefreshMutiList = true
        else
            self.shouldRefreshMutiList = false
        end
        self:RefreshMutiList()
    end)

    self.commonService:AddEventListener(self.muti_closeBtn, "onClick", function()
        self.muti_list_btn.onClick:Invoke()
    end)

    self.commonService:AddEventListener(self.muti_clearBtn, "onClick", function()
        self:ClearAllSelection()
    end)
end

function UGCEditor:InitSubmitUI()
    self.submitAlert = self.commitView:Find("submitAlert")
    self.submitAlert:GetComponent(typeof(CS.UnityEngine.UI.Image)).color = CS.UnityEngine.Color(0, 0, 0, 0.85)

    self.submitCloseBtn = self.submitAlert:Find("bg/closeBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.submit_PostImage = self.submitAlert:Find("bg/targetImage"):GetComponent(typeof(CS.UnityEngine.UI.Image))
    self.submit_PostBtn = self.submitAlert:Find("bg/postBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.submit_commitBtn = self.submitAlert:Find("bg/finishBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.submit_inputField = self.submitAlert:Find("bg/InputView/InputField"):GetComponent(typeof(CS.UnityEngine.UI
                                                                                                      .InputField))
    self.submit_numText = self.submitAlert:Find("bg/InputView/numText"):GetComponent(typeof(CS.UnityEngine.UI.Text))

    self.commonService:AddEventListener(self.submit_inputField, "onValueChanged", function()

        local len = string.utf8len(self.submit_inputField.text)

        if len > 14 then
            self.submit_inputField.text = string.utf8sub(self.submit_inputField.text, 1, 14)
            len = 14
        end

        self.submit_commitBtn.interactable = len > 0

        self.submit_numText.text = "玩法介绍(" .. tostring(len) .. "/14)"

    end)

    self.commonService:AddEventListener(self.submitCloseBtn, "onClick", function()
        self.submitAlert.gameObject:SetActive(false)
        self.canvas.sortingOrder = 150
    end)

    self.commonService:AddEventListener(self.submit_PostBtn, "onClick", function()
        self:EnterShotMode(true)
    end)

    self.commonService:AddEventListener(self.submit_commitBtn, "onClick", function()

        self:CommitAction()
        self.canvas.sortingOrder = 150

        -- self.submit_inputField.text 存本地

        CS.UnityEngine.PlayerPrefs.SetString(self.TEXT_SAVE_KEY, self.submit_inputField.text)
        CS.UnityEngine.PlayerPrefs.Save()
    end)
end

function UGCEditor:InitGameSubmitUI()
    self.submitAlertGame = self.commitView:Find("submitAlert-game")
    self.submitAlertGame:GetComponent(typeof(CS.UnityEngine.UI.Image)).color = CS.UnityEngine.Color(0, 0, 0, 0.85)

    self.submitCloseBtnGame = self.submitAlertGame:Find("bg/closeBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.submit_PostImageGame = self.submitAlertGame:Find("bg/targetImage")
        :GetComponent(typeof(CS.UnityEngine.UI.Image))
    self.submit_PostBtnGame = self.submitAlertGame:Find("bg/postBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.submit_commitBtnGame = self.submitAlertGame:Find("bg/finishBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.submit_inputFieldGame = self.submitAlertGame:Find("bg/InputView/InputField"):GetComponent(typeof(CS.UnityEngine
                                                                                                              .UI
                                                                                                              .InputField))
    self.submit_numTextGame = self.submitAlertGame:Find("bg/InputView/numText"):GetComponent(typeof(CS.UnityEngine.UI
                                                                                                        .Text))
    self.schoolBattleRoot = self.submitAlertGame:Find("bg/schoolBattle")
    self.schoolBattle = self.schoolBattleRoot:Find("toggle"):GetComponent(typeof(CS.UnityEngine.UI.Toggle))
    self.schoolBattleRoot.gameObject:SetActive(false)

    self.commonService:AddEventListener(self.submit_inputFieldGame, "onValueChanged", function()

        local len = string.utf8len(self.submit_inputFieldGame.text)

        if len > 22 then
            self.submit_inputFieldGame.text = string.utf8sub(self.submit_inputFieldGame.text, 1, 22)
            len = 22
        end

        self.submit_numTextGame.text = tostring(len) .. "/22"
        self.submit_commitBtnGame.interactable = len > 0 and string.utf8len(self.mapName_inputFieldGame.text) > 0
    end)

    self.mapName_inputFieldGame = self.submitAlertGame:Find("bg/titleInputView/InputField"):GetComponent(typeof(
        CS.UnityEngine.UI.InputField))
    self.mapName_numTextGame = self.submitAlertGame:Find("bg/titleInputView/numText"):GetComponent(typeof(CS.UnityEngine
                                                                                                              .UI.Text))

    self.commonService:AddEventListener(self.mapName_inputFieldGame, "onValueChanged", function()
        local len = string.utf8len(self.mapName_inputFieldGame.text)

        if len > 10 then
            self.mapName_inputFieldGame.text = string.utf8sub(self.mapName_inputFieldGame.text, 1, 10)
            len = 10
        end

        self.mapName_numTextGame.text = tostring(len) .. "/10"
        self.submit_commitBtnGame.interactable = len > 0 and string.utf8len(self.submit_inputFieldGame.text) > 0
    end)

    self.commonService:AddEventListener(self.submitCloseBtnGame, "onClick", function()
        self.submitAlertGame.gameObject:SetActive(false)
        self.canvas.sortingOrder = 150
    end)

    self.commonService:AddEventListener(self.submit_PostBtnGame, "onClick", function()
        self:EnterShotMode(true)
    end)

    self.commonService:AddEventListener(self.submit_commitBtnGame, "onClick", function()
        self:Fire("EVENT_MAP_EDITOR_COMMIT_ACTION")
    end)
end

function UGCEditor:InitEvent()

    self.commonService:AddEventListener(self.undoBtn, "onClick", function()
        if not self:CanOperate() then
            return
        end
        self:UndoAction()
        self.sno_undoCount = self.sno_undoCount + 1
    end)
    self.commonService:AddEventListener(self.redoBtn, "onClick", function()
        if not self:CanOperate() then
            return
        end
        self:RedoAction()
        self.sno_redoCount = self.sno_redoCount + 1
    end)

    self.commonService:AddEventListener(self.helpBtn, "onClick", function()
        self:ShowHelp()
        self:Report("home_help_exposure", "家园UGC帮助", "", {})
    end)

    local LongPress = function(action, actType)
        if self.moveCor then
            self.moveCor:Stop()
            self.moveCor = nil
        end

        self.moveCor = self.commonService:StartCoroutine(function()
            coroutine.yield(CS.UnityEngine.WaitForSeconds(0.5))
            local interval = CS.UnityEngine.WaitForSeconds(0.08)
            while true do
                coroutine.yield(interval)

                if actType == ActionType.Prop then
                    self:ExecuteAction(action)
                end

            end
        end)
    end

    local EndLongPress = function()
        if self.moveCor then
            self.moveCor:Stop()
            self.moveCor = nil
        end
    end

    self.upBtn = self.moveView:Find("bg/up").gameObject
    local upTrigger = self.upBtn.gameObject:AddComponent(typeof(CS.Com.Tal.Unity.UI.EventTriggerHandler))
    upTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.PointerDown, function()
        LongPress(Action.Up, ActionType.Prop)
    end)
    upTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.PointerUp, function()
        EndLongPress()
        self:ExecuteAction(Action.Up)
        self.audioService:PlayClipOneShot(self.clickAudio)
    end)

    self.downBtn = self.moveView:Find("bg/down").gameObject
    local downTrigger = self.downBtn.gameObject:AddComponent(typeof(CS.Com.Tal.Unity.UI.EventTriggerHandler))
    downTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.PointerDown, function()
        LongPress(Action.Down, ActionType.Prop)
    end)
    downTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.PointerUp, function()
        EndLongPress()
        self:ExecuteAction(Action.Down)
        self.audioService:PlayClipOneShot(self.clickAudio)
    end)

    self.rotateBtn = self.moveView:Find("rotate").gameObject:GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.rotateBtn.gameObject:AddComponent(typeof(CS.Com.Tal.Unity.UI.EventTriggerHandler)):AddEvent(
        EventTriggerTypeNameSpace.EventTriggerType.PointerClick, function()

            -- 判断下按钮不可用的话 return
            if not self.rotateBtn.interactable then
                return
            end

            self:ExecuteAction(Action.Rotate)
            self.audioService:PlayClipOneShot(self.clickAudio)
        end)

    self.deleteBtn = self.moveView:Find("delete").gameObject:GetComponent(typeof(CS.UnityEngine.UI.Button))
    self.setBtn = self.moveView:Find("set")
    self.lockBtn = self.moveView:Find("lockBtn").gameObject:GetComponent(typeof(CS.UnityEngine.UI.Button))

    self.lockBtnNormalSprite = self.lockBtn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite
    self.lockBtnSelectedSprite = self.lockBtn.transform:Find("select").gameObject:GetComponent(typeof(CS.UnityEngine
                                                                                                          .SpriteRenderer))
                                     .sprite

    self.commonService:AddEventListener(self.lockBtn, "onClick", function()
        self:LockBtnClicked()
    end)

    self.commonService:AddEventListener(self.locateBtn, "onClick", function()
        self:LocateSelectedGo()
        self.sno_locateCount = self.sno_locateCount + 1
    end)

    self.deleteBtn.gameObject:AddComponent(typeof(CS.Com.Tal.Unity.UI.EventTriggerHandler)):AddEvent(
        EventTriggerTypeNameSpace.EventTriggerType.PointerClick, function()

            if not self.deleteBtn.interactable then
                return
            end

            if not self:CanOperate() then
                return
            end

            self:DeleteSelectedGo()

            self.audioService:PlayClipOneShot(self.clickAudio)
        end)

    self.setBtn.gameObject:AddComponent(typeof(CS.Com.Tal.Unity.UI.EventTriggerHandler)):AddEvent(
        EventTriggerTypeNameSpace.EventTriggerType.PointerClick, function()

        end)

    local width = CS.UnityEngine.Screen.width
    local height = CS.UnityEngine.Screen.height
    local referWidth = 1624
    local referHeight = 750
    self.touchPadTrigger = self.touchPad.gameObject:AddComponent(typeof(CS.Com.Tal.Unity.UI.EventTriggerHandler))

    -- 记录一次手势的按下位置，用于区分点击与拖拽
    self.touchPadTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.PointerDown, function(data)
        self.gestureDownPos = Input.mousePosition
        self.didDragThisGesture = false
    end)

    self.touchPadTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.BeginDrag, function(data)

        if self.isDragging then
            return
        end

        local inoutPoint = Input.mousePosition

        self.listTouchPosition = inoutPoint

        -- 当已选中物体时，准备进入拖拽移动模式（单指拖拽）
        self.dragMoveActive = false
        local hit, go = self:IsPointerOverSelected(inoutPoint)

        if #self.selectedList > 0 and data.currentInputModule and data.currentInputModule.input.touchCount < 2 and hit then

            local planeY = go.transform.position.y
            local startWorld = self:ScreenToPlane(inoutPoint, planeY)
            if startWorld then
                self.dragMoveActive = true
                self.dragStartWorld = startWorld
                self.dragObjStartPos = go.transform.position
                self.dragObj = go
            end
        end

        self.isDragging = true
        self.didDragThisGesture = true

        if not self.dragMoveActive and self.select_mode == Select_Mode.Multi_Frame and
            data.currentInputModule.input.touchCount < 2 then
            -- 进入框选模式
            self.isFrameSelectActive = true
            self.frameSelectStartPos = inoutPoint
            self.frameBeginScreenPos = self.frameSelectStartPos
            self.frameEndScreenPos = self.frameSelectStartPos
            self.mutiFrameView.gameObject:SetActive(true)
        end

    end)

    self.touchPadTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.Drag, function(data)

        -- 若从两指切到一指，但未调用到 HandlePinchZoom，这里兜底刷新手势状态
        local tc = 0
        if data.currentInputModule and data.currentInputModule.input then
            tc = data.currentInputModule.input.touchCount
        end
        if tc < 2 and self._pinching then
            self._pinching = false
            self._ignoreNextSingleDrag = true
            self._gestureCooldownEndTime = CS.UnityEngine.Time.time + 0.08
        end

        -- 双指缩放优先
        if tc >= 2 then
            self:HandlePinchZoom()
            self._pinching = true
            return
        end

        if not self.isDragging then
            self.listTouchPosition = nil
            return
        end

        local inoutPoint = Input.mousePosition

        -- 冷却时间内不响应单指拖拽（避免抖动），并重置拖拽基准
        if self._gestureCooldownEndTime and CS.UnityEngine.Time.time < self._gestureCooldownEndTime then
            self.listTouchPosition = inoutPoint
            return
        else
            self._gestureCooldownEndTime = nil
        end

        -- 若上一帧刚从两指切到一指，忽略一次相机/单指拖拽，避免跳变抖动
        if self._ignoreNextSingleDrag then
            self._ignoreNextSingleDrag = false
            self.listTouchPosition = inoutPoint
            return
        end

        -- 拖拽移动选中物体（优先级高于相机旋转）
        if self.dragMoveActive and self.dragObj then
            local planeY = self.dragObjStartPos and self.dragObjStartPos.y or self.dragObj.transform.position.y
            local currWorld = self:ScreenToPlane(inoutPoint, planeY)
            if currWorld and self.dragStartWorld and self.dragObjStartPos then
                local offsetWorld = currWorld - self.dragStartWorld
                local target = self.dragObjStartPos + offsetWorld
                self:SetSelectedPositionWithConstraints(target)
            end
            -- 当选中物体接近屏幕边缘时，自动平移相机以保持其可见
            self:AutoPanCameraToKeepSelectedVisible()
            return
        end

        if self.isFrameSelectActive then
            -- 获取当前鼠标位置和起始位置（屏幕坐标，原点左下角）
            local currentPos = inoutPoint
            local startPos = self.frameSelectStartPos

            -- 父Canvas与目标RectTransform
            local canvas = self.canvas
            local rectTransform = self.mutiFrameView:GetComponent(typeof(CS.UnityEngine.RectTransform))
            local canvasRT = canvas.transform:GetComponent(typeof(CS.UnityEngine.RectTransform))

            -- 将屏幕点转换到父Canvas的本地坐标（原点为Canvas的pivot，通常是中心）
            local okStart, startLocal = CS.UnityEngine.RectTransformUtility.ScreenPointToLocalPointInRectangle(canvasRT,
                CS.UnityEngine.Vector2(startPos.x, startPos.y), nil)
            local okCurr, currLocal = CS.UnityEngine.RectTransformUtility.ScreenPointToLocalPointInRectangle(canvasRT,
                CS.UnityEngine.Vector2(currentPos.x, currentPos.y), nil)
            if not okStart or not okCurr then
                return
            end

            -- 将以Canvas中心为原点的局部坐标，转换为以左下角为原点的坐标
            local halfW = canvasRT.rect.width * 0.5
            local halfH = canvasRT.rect.height * 0.5
            local startBL = CS.UnityEngine.Vector2(startLocal.x + halfW, startLocal.y + halfH)
            local currBL = CS.UnityEngine.Vector2(currLocal.x + halfW, currLocal.y + halfH)

            -- 保存屏幕坐标用于结束时命中判定
            self.frameBeginScreenPos = self.frameBeginScreenPos or inoutPoint
            self.frameEndScreenPos = inoutPoint

            -- 根据拖动方向动态选择左上角（anchors=左下，pivot=左上）
            local anchorX = math.min(startBL.x, currBL.x)
            local anchorY = math.max(startBL.y, currBL.y)
            rectTransform.anchoredPosition = CS.UnityEngine.Vector2(anchorX, anchorY)

            -- 计算尺寸（四象限通用）
            local width = math.abs(currBL.x - startBL.x)
            local height = math.abs(currBL.y - startBL.y)
            rectTransform.sizeDelta = CS.UnityEngine.Vector2(width, height)

            return
        end

        if not self.listTouchPosition then
            return
        end

        local offset = inoutPoint - self.listTouchPosition

        -- g_Log("xxx Drag", offset)

        local dx = math.abs(offset.x)
        local dy = math.abs(offset.y)

        if self.camera_mode == Camera_Mode.BirdEye then
            -- 仅允许Y轴旋转（水平拖动）
            if dx > dy then
                local ret = Camera.main.transform.localEulerAngles +
                                Vector3(0, DRAG_ROTATE_SENS * offset.x * referWidth / width, 0)
                -- 保持俯视锁定：X=90, Z=0
                ret.x = 90
                ret.z = 0
                Camera.main.transform.localEulerAngles = ret
            end
        else
            -- 普通模式下，X/Y旋转均可
            if dx > dy then
                local ret = Camera.main.transform.localEulerAngles +
                                Vector3(0, DRAG_ROTATE_SENS * offset.x * referWidth / width, 0)
                -- 消除滚转，避免累计误差导致倾斜
                ret.z = 0
                Camera.main.transform.localEulerAngles = ret
            elseif dy > dx then
                local ret = Camera.main.transform.localEulerAngles +
                                Vector3(-DRAG_ROTATE_SENS * offset.y * referHeight / height, 0, 0)
                -- 夹取俯仰角，避免超过俯视后“翻转”或穿地
                local x = ret.x
                if x > 180 then
                    x = x - 360
                end
                local MIN_P, MAX_P = 5, 85
                if x < MIN_P then
                    x = MIN_P
                elseif x > MAX_P then
                    x = MAX_P
                end
                ret.x = (x < 0) and (x + 360) or x
                -- 消除滚转
                ret.z = 0
                Camera.main.transform.localEulerAngles = ret
            end
        end
        self.listTouchPosition = inoutPoint
    end)

    self.touchPadTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.EndDrag, function(data)

        if data.currentInputModule.input.touchCount >= 2 and not self.cameraMoving then
            return
        end

        self.listTouchPosition = nil

        -- 结束拖拽
        if self.dragMoveActive then
            self.dragMoveActive = false
            self.dragObj = nil
            self:SaveSelectionInfo()
            self:PushSnapshot()

            self:TrackDropEnd()
        end

        self.isDragging = false
        -- g_Log("xxx EndDrag",os.time())

        if self.isFrameSelectActive then
            self.isFrameSelectActive = false
            self.frameSelectStartPos = nil
            self.mutiFrameView.gameObject:SetActive(false)
            -- 结束框选时，执行选择判定
            if self.frameEndScreenPos and self.frameBeginScreenPos then
                self:SelectObjectsInFrame(self.frameBeginScreenPos, self.frameEndScreenPos)
                self.frameBeginScreenPos = nil
                self.frameEndScreenPos = nil
            end
        end
    end)

    self.touchPadTrigger:AddEvent(EventTriggerTypeNameSpace.EventTriggerType.PointerUp, function()
        if self.isDragging then
            return
        end
        -- 若本次手势发生过拖拽（BeginDrag->EndDrag），则忽略本次抬起
        if self.didDragThisGesture then
            self.didDragThisGesture = false
            return
        end

        local inoutPoint = Input.mousePosition

        -- 位移阈值过滤，避免微小移动被当作点击
        if self.gestureDownPos then
            local move = inoutPoint - self.gestureDownPos
            if math.abs(move.x) > 6 or math.abs(move.y) > 6 then
                return
            end
        end
        -- g_Log("xxx PointerUp",os.time())
        self:RaycastTrigger()
    end)

    self.cameraJoystick.onMove:AddListener(function(v)
        self.cameraJoystickV3.x = v.x
        self.cameraJoystickV3.y = 0
        self.cameraJoystickV3.z = v.y
        self:ExecuteCameraMove(self.cameraJoystickV3)

        self.cameraMoving = true

        self.cameraDir.gameObject:SetActive(true)
        if v.x > 0 then
            if v.y > 0 then
                self.cameraDir.rotation = r1;
            elseif v.y < 0 then
                self.cameraDir.rotation = r2;
            elseif v.y == 0 then
                self.cameraDir.rotation = r3;
            end
        elseif v.x < 0 then
            if v.y > 0 then
                self.cameraDir.rotation = r4;
            elseif v.y < 0 then
                self.cameraDir.rotation = r5;
            elseif v.y == 0 then
                self.cameraDir.rotation = r6;
            end
        elseif v.x == 0 then
            if v.y > 0 then
                self.cameraDir.rotation = r7;
            elseif v.y < 0 then
                self.cameraDir.rotation = r8;
            end
        end
    end)

    self.cameraJoystick.onMoveEnd:AddListener(function(v)
        self.cameraMoving = false
        self.cameraDir.gameObject:SetActive(false)
    end)

    self.moveJoystick.onMove:AddListener(function(v)
        self.moveJoystickV3.x = v.x
        self.moveJoystickV3.y = 0
        self.moveJoystickV3.z = v.y
        self:ExecuteObjMove(self.moveJoystickV3)

        self.cameraMoving = true

        self.moveDir.gameObject:SetActive(true)
        if v.x > 0 then
            if v.y > 0 then
                self.moveDir.rotation = r1;
            elseif v.y < 0 then
                self.moveDir.rotation = r2;
            elseif v.y == 0 then
                self.moveDir.rotation = r3;
            end
        elseif v.x < 0 then
            if v.y > 0 then
                self.moveDir.rotation = r4;
            elseif v.y < 0 then
                self.moveDir.rotation = r5;
            elseif v.y == 0 then
                self.moveDir.rotation = r6;
            end
        elseif v.x == 0 then
            if v.y > 0 then
                self.moveDir.rotation = r7;
            elseif v.y < 0 then
                self.moveDir.rotation = r8;
            end
        end
    end)

    self.moveJoystick.onMoveEnd:AddListener(function(v)
        self.moveDir.gameObject:SetActive(false)

        self:SaveSelectionInfo()
        self:PushSnapshot()

        self:TrackDropEnd()
    end)

    App:GetService("CommonService"):AddEventListener(self.commitBtn, "onClick", function()
        -- 房间设置            
        self.audioService:PlayClipOneShot(self.clickAudio)

        -- 如果是地图编辑，则调用壳子保存逻辑
        if HOME_CONFIG_INFO.MapType or HOME_CONFIG_INFO.MapId then
            self:Fire("EVENT_MAP_EDITOR_COMMIT")
            return
        end

        if not self.isDirty then
            self:EndEditor()
            return
        end

        if self.gameStart and (self.game_questionCount < 1 or self.game_endCount < 1) then
            local text = "检测到你的" .. self.platformText ..
                             "挑战模式<color=#FF5A5A>缺失宝箱或终点旗帜</color>，发布后场景内的宝箱和旗帜不设有答题功能，是否仍要继续发布？"
            self:ShowAlert("", text, function()

            end, function()
                self:GameSwitch(false)
                self:ShowCommitAlert(function()

                end)
            end, "发布", "继续编辑")
        else
            self:ShowCommitAlert(function()

            end)
        end

    end)

    App:GetService("CommonService"):AddEventListener(self.resetBtn, "onClick", function()
        -- 房间设置            
        self.audioService:PlayClipOneShot(self.clickAudio)

        if not self:CanOperate() then
            return
        end

        self:ShowAlert("重新布置",
            "重新布置后将会恢复成当前家园内的布置，并清空当前所有的修改操作，是否确认重新布置？",
            function()
                g_Log(self.TAG, "重置确定")

                if #self.selectedList > 0 then
                    self:DeleteSelectedGo()

                end

                self:ResetAction()
                if not self.resetDirty then
                    self.isDirty = false
                end
                self.customPath = nil
            end, function()
                g_Log(self.TAG, "重置取消")

            end)
    end)

    App:GetService("CommonService"):AddEventListener(self.saveBtn, "onClick", function()

        -- 房间设置            
        self.audioService:PlayClipOneShot(self.clickAudio)

        -- 拍照
        -- self:EnterShotMode(true)

        if not self.isDirty then
            self:EndEditor()
            if HOME_CONFIG_INFO.MapType or HOME_CONFIG_INFO.MapId then
                self:Fire("EVENT_MAP_EDITOR_SAVE_AND_EXIT")
            end
            return
        end

        self:ShowAlert("保存", "是否保存当前布置方案？\n保存后方案将不会即时生效哦~",
            function()
                self:SaveAndExit(function()
                    if HOME_CONFIG_INFO.MapType or HOME_CONFIG_INFO.MapId then
                        self:Fire("EVENT_MAP_EDITOR_SAVE_AND_EXIT")
                    end
                end)
            end, function()

            end, "取消", "保存并退出")

    end)

    App:GetService("CommonService"):AddEventListener(self.shotExitBtn, "onClick", function()
        -- 房间设置            
        self.audioService:PlayClipOneShot(self.clickAudio)

        -- 拍照
        self:EnterShotMode(false)
    end)

    App:GetService("CommonService"):AddEventListener(self.shotBtn, "onClick", function()
        -- 房间设置            
        self.audioService:PlayClipOneShot(self.cameraAudio)

        -- 拍照
        self.observerService:Fire("CAMERA_SHOT_SAVE", {
            callback = function(path, sprite)
                CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("家园封面设置成功", 3)
                g_Log(self.TAG, "拍照成功", path)
                self.isDirty = true
                self.customPath = path
                self:EnterShotMode(false)

                if HOME_CONFIG_INFO.MapType or HOME_CONFIG_INFO.MapId then
                    self:Fire("EVENT_MAP_EDITOR_POST_IMAGE", {
                        sprite = sprite
                    })
                else
                    self.submit_PostImage.sprite = sprite
                end
            end,
            shotCallback = function(start)
                -- TODO截图前 隐藏掉一些不想被截进去的

            end
        })

    end)

    App:GetService("CommonService"):AddEventListener(self.cametaSlider, "onValueChanged", function()

        -- g_Log("xxxx",self.cametaSlider.value)
        if self.cametaSlider.value < 0 then
            self.cametaSlider.value = 0
        end

        local y = (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN) * self.cametaSlider.value + self.CAMERA_Y_MIN

        local pos = Camera.main.transform.position
        pos.y = y

        -- Camera.main.transform.transform:DOMove(pos, 0.15)

        Camera.main.transform.transform.position = pos

    end)

    App:GetService("CommonService"):AddEventListener(self.playBtn, "onClick", function()

        -- if true then
        --     self:TestCode()
        --     return
        -- end
        self.audioService:PlayClipOneShot(self.clickAudio)
        self.observerService:Fire("SHOW_CLOUD", {
            duration = 0.5,
            callback = function(isShow)
                if isShow then
                    self:EnterPlayMode(true)
                end
            end
        })
    end)

    App:GetService("CommonService"):AddEventListener(self.playBackBtn, "onClick", function()
        self.audioService:PlayClipOneShot(self.clickAudio)
        self:EnterPlayMode(false)
    end)

    App:GetService("CommonService"):AddEventListener(self.shopBtn, "onClick", function()
        g_Log(TAG, "点击商店")
        self:Fire("ABC_ZONE_SHOW_HOME_SHOP")
    end)

    App:GetService("CommonService"):AddEventListener(self.scanBtn, "onClick", function()
        self.audioService:PlayClipOneShot(self.clickAudio)
        self.observerService:Fire("HOME_FREE_AREA_SCAN")
    end)

    App:GetService("CommonService"):AddEventListener(self.guideCloseBtn, "onClick", function()
        self.audioService:PlayClipOneShot(self.clickAudio)
        self.guideView.gameObject:SetActive(false)
        self.canvas.sortingOrder = 150
    end)

    App:GetService("CommonService"):AddEventListener(self.guideBtn, "onClick", function()
        self.audioService:PlayClipOneShot(self.clickAudio)
        self.guideView.gameObject:SetActive(false)
        self.canvas.sortingOrder = 150
        if self.guideCallback then
            self.guideCallback()
        end
    end)

    App:GetService("CommonService"):AddEventListener(self.swichCameraBtn, "onClick", function()
        self:SwitchCameraMode()
    end)
end

function UGCEditor:InitParamAdjustUI()

    -- moverEdit根节点
    self.moverEdit = self.moveView:Find("moverEdit")
    if not self.moverEdit then
        g_LogError("未找到 moverEdit 节点")
        return
    end
    -- moverEdit下的title文本
    self.moverEdit_title = self.moverEdit:Find("title"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))

    -- item区域
    self.moverEdit_item = self.moverEdit:Find("item")
    if self.moverEdit_item then
        self.moverEdit_item_title = self.moverEdit_item:Find("title"):GetComponent(typeof(CS.UnityEngine.UI.Text))
        self.moverEdit_item_add = self.moverEdit_item:Find("add"):GetComponent(typeof(CS.UnityEngine.UI.Button))
        self.moverEdit_item_mus = self.moverEdit_item:Find("mus"):GetComponent(typeof(CS.UnityEngine.UI.Button))
        self.moverEdit_item_slider = self.moverEdit_item:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))
    end

    -- editors区域
    self.moverEdit_editors = self.moverEdit:Find("editors")
    self.moverEdit_editors_scrollRect = self.moverEdit_editors:GetComponent(typeof(CS.UnityEngine.UI.ScrollRect))
    self.moverEdit_editors_scrollRect.vertical = false
    if self.moverEdit_editors then
        self.moverEdit_editors_viewport = self.moverEdit_editors:Find("Viewport")
        if self.moverEdit_editors_viewport then
            self.moverEdit_editors_content = self.moverEdit_editors_viewport:Find("Content")
        end
    end
end

function UGCEditor:InitHomeInfo(param, callback)

    
    if self.HomeInited then
        return
    end

    self.initCallback = callback

    local courtyard_location = param.courtyard_location
    local auditFailed = param.auditFailed
    if auditFailed == true then
        g_Log(self.TAG, "EVENT_HOME_COURTYARD_INFO", "审核失败")
        self:AuditFaild()
    end

    if App.IsStudioClient and TEST_LOCAL_CACHE then
        local s = CS.UnityEngine.PlayerPrefs.GetString(self.HomeData_yard)
        if s and s ~= "" then
            courtyard_location = s
        end
    end

    self.courtyard_location = courtyard_location

    self.HomeInited = false

    g_Log(self.TAG, "EVENT_HOME_COURTYARD_INFO", table.dump(param))

    self:RequestPlaceData(function()
        -- 如果在初始化完成前就点了编辑  先根据这个现实loading
        self.HomeInited = true
        -- TODO 通知下背包用了哪些家具
        self:FurnitureCostEvent()
        g_Log(self.TAG, "家具初始化完成")

        self:ShotDoorImage()

        self:NotifyGameEvent()

        if self.initCallback then
            self.initCallback(self.PlaceMap)
            self.initCallback = nil
        end
    end, true)
end

function UGCEditor:BeginUGCEditor()
    if not self.HomeInited then
        self:ShowLoading(true)
        self.loadingCor = self.commonService:StartCoroutine(function()
            self.commonService:Yield(self.commonService:WaitUntil(function()
                return self.HomeInited == true
            end))
            self:ShowLoading(false)
            self.loadingCor = nil

            self:EnterEditor()
        end)
    else
        self:EnterEditor()
    end
end

function UGCEditor:ShowHelp()
    -- TODO 显示帮助
    self:Fire("HOME_EDIT_SHOW_HELP_PANEL")
end

function UGCEditor:CopyAction()
    if #self.selectedList == 0 then
        return
    end

    if not self:CanOperate() then
        return
    end

    -- TODO 复制

    local copyList = {}

    local copyIdMap = {}
    local gameTypeMap = {}
    for _, v in ipairs(self.selectedList) do

        local gameType = v.gameType
        if gameType == Game_Type.Question then
            gameTypeMap[Game_Type.Question] = (gameTypeMap[Game_Type.Question] or 0) + 1
        elseif gameType == Game_Type.End then
            gameTypeMap[Game_Type.End] = (gameTypeMap[Game_Type.End] or 0) + 1
        end

        if SpecialGuid[v.guid] ~= nil then
            -- TODO 特殊物品不能复制
        else
            local isSpecial = false
            if Special_Product_ID and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.ShootGame then
                for _, specialGuid in pairs(Special_Product_ID) do
                    if specialGuid == v.id then
                        -- 特殊物品不能复制
                        isSpecial = true
                    end
                end
            end
            if not isSpecial then
                local go = self.goParent:Find(v.guid)
                local copy_go = go.gameObject
                local copy_info = table.clone(v)
                copy_info.guid = self:GetGuid()
                copy_info.locked = 0

                local item = {
                    go = copy_go,
                    info = copy_info
                }
                table.insert(copyList, item)

                local idNumber = tonumber(v.id)
                if idNumber and idNumber > 0 then
                    local id = v.id
                    if not copyIdMap[id] then
                        copyIdMap[id] = 0
                    end
                    copyIdMap[id] = copyIdMap[id] + 1
                end
            end
        end
    end

    -- if gameType == Game_Type.Question then
    --     if self.game_questionCount >= Max_Question_Count then
    --         CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("最多设置10题")
    --         return
    --     end
    --     if App.IsStudioClient then
    --         uaddress = "954421734589490/assets/Prefabs/baoxiang.prefab"
    --         scale = 1
    --     end
    -- elseif gameType == Game_Type.End then
    --     if self.game_endCount >= Max_End_Count then
    --         CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("最多设置1个终点")
    --         return
    --     end
    -- end
    local questionCount = gameTypeMap[Game_Type.Question] or 0
    local endCount = gameTypeMap[Game_Type.End] or 0
    if questionCount + self.game_questionCount > Max_Question_Count then
        self:ShowTips("复制失败，最多设置10个宝箱")
        return
    end
    if endCount + self.game_endCount > Max_End_Count then
        self:ShowTips("复制失败，最多设置1个终点")
        return
    end

    self:ClearAllSelection()
    self:FurnitureCostEvent()

    self:ShowLoading(true)
    self:Fire("EVENT_BATCH_COPY", {
        idMaps = copyIdMap,
        callback = function(isEnough, isSuccess)
            self:ShowLoading(false)
            if isSuccess ~= 1 then
                self:ShowTips("复制失败,请稍后再试")
                return
            end

            if isEnough then

                for i, v in ipairs(copyList) do
                    local copyGo = GameObject.Instantiate(v.go)
                    copyGo.name = v.info.guid
                    copyGo.layer = Layer_enum.furnitureLayer
                    copyGo.transform:SetParent(self.goParent)
                    self:AddSelection(copyGo, v.info)
                    self.PlaceMap[v.info.guid] = v.info
                end

                self:SaveSelectionInfo()
                self:PushSnapshot()

                if #copyList > 0 then
                    self:ShowTips("已成功复制" .. tostring(#copyList) .. "个道具")
                    self:FurnitureCostEvent()
                else
                    self:ShowTips("特殊物品不能复制")
                end
            else
                self:ShowTips("数量不足,无法复制")
            end
        end
    })

end

function UGCEditor:UndoAction()
    local currentJsonData = self:GetHomeJsonData()
    table.insert(self.redoStack, currentJsonData)

    local undoData = table.remove(self.undoStack, #self.undoStack)
    local diffData = self:CheckDiffData(currentJsonData, undoData)

    self:ShowLoading(true)
    self:ApplyDiffData(diffData, function()
        self:ShowLoading(false)
    end)

    self:RefreshUndoState()
end

function UGCEditor:RedoAction()
    local currentJsonData = self:GetHomeJsonData()
    table.insert(self.undoStack, currentJsonData)

    local redoData = table.remove(self.redoStack, #self.redoStack)
    local diffData = self:CheckDiffData(currentJsonData, redoData)

    self:ShowLoading(true)
    self:ApplyDiffData(diffData, function()
        self:ShowLoading(false)

    end)

    self:RefreshUndoState()
end

function UGCEditor:PushSnapshot()
    local jsonData = self.lastSnapshot
    local curJsonData = self:GetHomeJsonData()

    -- g_Log(self.TAG, "PushSnapshots1", jsonData)
    --     g_Log(self.TAG, "PushSnapshots2", curJsonData)

    -- 如果没更改不入栈
    local diffData = self:CheckDiffData(curJsonData, jsonData)
    if #diffData.added == 0 and #diffData.removed == 0 and #diffData.changed == 0 then
        self:RefreshUndoState()
        return
    end

    if #diffData.changed > 0 and App.IsStudioClient then
        g_Log(self.TAG, "PushSnapshot1", jsonData)
        g_Log(self.TAG, "PushSnapshot2", curJsonData)
        g_Log(self.TAG, "PushSnapshot3", table.dump(diffData.changed[1]))
    end

    table.insert(self.undoStack, jsonData)
    if #self.undoStack > self.stackSize then
        table.remove(self.undoStack, 1)
    end

    self.lastSnapshot = curJsonData

    self:RefreshUndoState()
    self.editCount = self.editCount + 1
end

function UGCEditor:RefreshUndoState()
    self.undoBtn.interactable = #self.undoStack > 0
    self.redoBtn.interactable = #self.redoStack > 0
end

function UGCEditor:ApplyDiffData(diffData, callback)
    local addedList = diffData.added
    local removedList = diffData.removed
    local changedList = diffData.changed

    -- g_Log("diff added", table.dump(addedList))
    -- g_Log("diff removed", table.dump(removedList))
    -- g_Log("diff changed", table.dump(changedList))

    local taskCount = #addedList + #removedList + #changedList
    local taskIndex = 0
    local taskCallback = function()
        taskIndex = taskIndex + 1
        if taskIndex == taskCount then
            if callback then
                callback()
            end
            self.lastSelected = nil
        end
    end

    for _, v in ipairs(addedList) do
        self:AddObject(v, function(go)

            if self.lastSelected and self.lastSelected[v.guid] then
                -- g_Log("zzzz -- 找到了",v.guid)
                self:AddSelection(go, v)
            end
            taskCallback()
        end)
    end

    for _, v in ipairs(removedList) do
        self:RemoveObject(v)
        taskCallback()
    end
    for _, v in ipairs(changedList) do
        self:UpdateObject(v)
        taskCallback()
    end

    self.lastSnapshot = self:GetHomeJsonData()

    self:FurnitureCostEvent()
end

function UGCEditor:RemoveObject(v)
    self.PlaceMap[v.guid] = nil

    -- 检查是否在选中列表中，如果在则移除
    if self.selectedList and #self.selectedList > 0 then
        for i = #self.selectedList, 1, -1 do
            local info = self.selectedList[i]
            if info.guid == v.guid then
                table.remove(self.selectedList, i)
                break
            end
        end
    end
    self.selectedMap[v.guid] = nil

    local go = self.goParent:Find(v.guid)
    if go then
        GameObject.DestroyImmediate(go.gameObject)
    end

    if #self.selectedList == 0 then
        self:OpenEditorGmView(false)
    end
end

function UGCEditor:AddObject(v, callback)
    self.PlaceMap[v.guid] = {
        uaddress = v.uaddress,
        id = v.id,
        guid = v.guid,
        x = v.x,
        y = v.y,
        z = v.z,
        r = v.r,
        cost = v.cost or 1,
        scale = v.scale or 1,
        gameType = v.gameType,
        mover_type = v.mover_type,
        mover_id = v.mover_id,
        mover_attributes = v.mover_attributes or {},
        jump_speed = (v.mover_attributes and v.mover_attributes["jump_speed.def"]) or nil,
        jump_power = (v.mover_attributes and v.mover_attributes["jump_power.def"]) or nil,
        jump_angle = (v.mover_attributes and v.mover_attributes["jump_angle.def"]) or nil,
        trans_speed = (v.mover_attributes and v.mover_attributes["trans_speed.def"]) or nil,
        speed_duration = (v.mover_attributes and v.mover_attributes["speed_duration.def"]) or nil,
        locked = v.locked or 0,
        img = v.img,
        level = v.level
    }

    self:LoadPrefab(v.uaddress, function(go)

        if not go then
            if callback then
                callback(nil)
            end
            return
        end

        go.name = v.guid
        go.transform:SetParent(self.goParent)
        go.layer = Layer_enum.furnitureLayer
        go.transform.position = {
            x = v.x,
            y = v.y,
            z = v.z
        }
        go.transform.localScale = Vector3(v.scale or 1, v.scale or 1, v.scale or 1)
        go.transform.localEulerAngles = Vector3(0, v.r, 0)
        local collider = go:GetComponent(typeof(CS.UnityEngine.BoxCollider))
        if Util:IsNil(collider) then
            collider = go:AddComponent(typeof(CS.UnityEngine.BoxCollider))
            local size = self:CalculateTotalBounds(go)
            collider.size = size
            if not self.colliderList then
                self.colliderList = {}
            end
            table.insert(self.colliderList, collider)
        end

        if v.gameType then

            self:SpecialProp(go, v.gameType, v.id)
        end

        -- 判断是否是运动器，是的话设置运动器
        if v.mover_type == Move_Type.Jump then
            local id = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:RegisterMover({
                move_object = go,
                speedY = v.jump_speed,
                speedX = 0,
                speedZ = 0
            })
            CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:startMover(id)
            v.mover_id = id
        elseif v.mover_type == Move_Type.Shoot then
            -- 获取物体的当前旋转角度
            local rotationY = go.transform.localEulerAngles.y

            -- 使用新的计算函数计算速度分量
            local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(v.jump_power, v.jump_angle, rotationY)

            -- 调用运动服务，设置弹簧板
            local id = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:RegisterMover({
                move_object = go,
                speedY = y_speed,
                speedX = x_speed,
                speedZ = z_speed
            })
            CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:startMover(id)
            v.mover_id = id
        elseif v.mover_type == Move_Type.Trans then
            -- 获取物体的当前旋转角度
            local rotationY = go.transform.localEulerAngles.y
            local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(v.trans_speed, 0, rotationY)
            local id = CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:RegisterMover({
                move_object = go,
                speedX = x_speed,
                speedZ = z_speed
            })
            CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:startMover(id)
            v.mover_id = id
        elseif v.mover_type == Move_Type.Speed then
            local id = CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:RegisterMover({
                move_object = go,
                speedTime = v.speed_duration,
                cd = 3,
                speed = 1.5
            })
            CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:startMover(id)
            v.mover_id = id
        else
        end

        if callback then
            callback(go)
        end

    end)
end

function UGCEditor:UpdateObject(v)

    if not self.PlaceMap[v.guid] then
        return
    end

    self.PlaceMap[v.guid] = v
    local go = self.goParent:Find(v.guid)
    if go then
        go.transform.position = {
            x = v.x,
            y = v.y,
            z = v.z
        }
        go.transform.localScale = Vector3(v.scale or 1, v.scale or 1, v.scale or 1)
        go.transform.localEulerAngles = Vector3(0, v.r, 0)

    end

    -- 运动器特殊处理
    if self.selectedMap[v.guid] and #self.selectedList == 1 then
        local old = self.selectedList[1]
        self.selectedMap[v.guid] = v
        v.mover_id = old.mover_id

        for i, info in ipairs(self.selectedList) do
            if info.guid == v.guid then
                self.selectedList[i] = v
                break
            end
        end

        self:CheckAndShowMoverEditPanel()
    end

    self:RefreshOpLockState()
end

function UGCEditor:CheckDiffData(curData, targetData)
    local safeDecode = function(jsonStr)
        if type(jsonStr) == "string" and jsonStr ~= "" then
            local ok, dic = pcall(function()
                return self.jsonService:decode(jsonStr)
            end)
            if ok and type(dic) == "table" then
                return dic
            end
        end
        return {}
    end
    local curDic = safeDecode(curData)
    local targetDic = safeDecode(targetData)
    local curList = type(curDic.list) == "table" and curDic.list or {}
    local targetList = type(targetDic.list) == "table" and targetDic.list or {}

    local function isNumber(v)
        return type(v) == "number"
    end

    local function nearlyEqual(a, b, eps)
        if a == b then
            return true
        end
        if not (isNumber(a) and isNumber(b)) then
            return false
        end
        return math.abs(a - b) <= (eps or 0.01)
    end

    local function deepEqual(a, b)
        if a == b then
            return true
        end
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            return false
        end
        if ta ~= "table" then
            if isNumber(a) or isNumber(b) then
                return nearlyEqual(a, b, 0.01)
            end
            return a == b
        end
        -- table: compare lengths/keys quickly, then recurse
        local countA, countB = 0, 0
        for k in pairs(a) do
            countA = countA + 1
            if not deepEqual(a[k], b[k]) then
                return false
            end
        end
        for _ in pairs(b) do
            countB = countB + 1
        end
        return countA == countB
    end

    local function diffObject(oldObj, newObj, pathPrefix, changes)
        local prefix = pathPrefix and (pathPrefix .. ".") or ""
        local visited = {}
        for k, oldV in pairs(oldObj or {}) do
            if k ~= "guid" then
                visited[k] = true
                local newV = newObj and newObj[k]
                if not deepEqual(oldV, newV) then
                    table.insert(changes, {
                        key = prefix .. tostring(k),
                        from = oldV,
                        to = newV
                    })
                end
            end
        end
        for k, newV in pairs(newObj or {}) do
            if k ~= "guid" and not visited[k] then
                local oldV = oldObj and oldObj[k]
                if not deepEqual(oldV, newV) then
                    table.insert(changes, {
                        key = prefix .. tostring(k),
                        from = oldV,
                        to = newV
                    })
                end
            end
        end
    end

    local curMap = {}
    for _, v in ipairs(curList) do
        if v and v.guid then
            curMap[v.guid] = v
        end
    end
    local targetMap = {}
    for _, v in ipairs(targetList) do
        if v and v.guid then
            targetMap[v.guid] = v
        end
    end

    local diffResult = {
        added = {},
        removed = {},
        changed = {}
    }

    -- additions and updates
    for guid, newItem in pairs(targetMap) do
        local oldItem = curMap[guid]
        if not oldItem then
            table.insert(diffResult.added, newItem)
        else
            local changes = {}
            diffObject(oldItem, newItem, nil, changes)
            if #changes > 0 then
                -- 仅返回变更后的完整数据
                table.insert(diffResult.changed, newItem)
            end
        end
    end

    -- removals
    for guid, oldItem in pairs(curMap) do
        if not targetMap[guid] then
            table.insert(diffResult.removed, oldItem)
        end
    end

    -- g_Log(self.TAG, "ApplyDiffData", table.dump(diffResult))
    return diffResult
end

function UGCEditor:LockBtnClicked()

    if not self:CanOperate() then
        return
    end

    if #self.selectedList > 0 then
        for i, info in ipairs(self.selectedList) do
            local locked = info.locked or 0
            locked = locked == 0 and 1 or 0
            info.locked = locked
        end

        if #self.selectedList > 1 or self:IsMultiSelectMode() then
            self:ClearAllSelection()
        end
    end

    self:RefreshOpLockState()

    if self.lockBtn.image.sprite == self.lockBtnSelectedSprite then
        self:ShowTips("已锁定   ")
    else
        self:ShowTips("已解锁   ")
    end
    self:SaveSelectionInfo()
    self:PushSnapshot()

    self:CheckAndShowMoverEditPanel()
end

function UGCEditor:LocateSelectedGo(idx)
    if #self.selectedList == 0 then
        self:ShowTips("请先选择一个物体")
        return
    end

    if Util:IsNil(CS.UnityEngine.Camera.main) then
        return
    end

    local index = idx or #self.selectedList

    -- 定位到最后一个选择的物体上
    local info = self.selectedList[index]
    local go = self.goParent:Find(info.guid)

    local cam = CS.UnityEngine.Camera.main
    local camTf = cam.transform

    local selectedPos = go.transform.position
    local camPos = camTf.position

    -- 鸟瞰模式下：俯视定位（相机直接移到目标正上方，Y 取最高），朝向垂直向下但保留当前 Y 轴朝向
    if self.camera_mode == Camera_Mode.BirdEye then
        local targetPos = CS.UnityEngine.Vector3(selectedPos.x, self.CAMERA_Y_MAX or camPos.y, selectedPos.z)

        -- 约束相机在场景范围（仅 X/Z）
        if targetPos.x < self.X_MIN - Camera_Gap then
            targetPos.x = self.X_MIN - Camera_Gap
        elseif targetPos.x > self.X_MAX + Camera_Gap then
            targetPos.x = self.X_MAX + Camera_Gap
        end
        if targetPos.z < self.Z_MIN - Camera_Gap then
            targetPos.z = self.Z_MIN - Camera_Gap
        elseif targetPos.z > self.Z_MAX + Camera_Gap then
            targetPos.z = self.Z_MAX + Camera_Gap
        end

        camTf.position = targetPos
        local y = camTf.eulerAngles.y
        camTf.eulerAngles = Vector3(90, y, 0)

        -- 同步相机高度滑条UI
        if self.cametaSlider and self.CAMERA_Y_MIN and self.CAMERA_Y_MAX and self.CAMERA_Y_MAX ~= self.CAMERA_Y_MIN then
            local ratio = (camTf.position.y - self.CAMERA_Y_MIN) / (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN)
            if ratio < 0 then
                ratio = 0
            end
            if ratio > 1 then
                ratio = 1
            end
            self.cametaSlider.value = ratio
        end
        return
    end

    -- 仅在水平面上对齐到选中物体前方，保持当前相机高度与朝向
    -- 设置固定的俯视角度（45度）
    local viewAngle = 60
    local radians = math.rad(viewAngle)

    -- 依据物体包围盒自适应距离，避免大物体贴脸、小物体过远
    local distance = 20
    do
        local renders = go:GetComponentsInChildren(typeof(CS.UnityEngine.Renderer))
        if renders and renders.Length and renders.Length > 0 then
            local minX, maxX = math.huge, -math.huge
            local minY, maxY = math.huge, -math.huge
            local minZ, maxZ = math.huge, -math.huge
            for i = 0, renders.Length - 1 do
                local b = renders[i].bounds
                local mn = b.min
                local mx = b.max
                if mn.x < minX then
                    minX = mn.x
                end
                if mx.x > maxX then
                    maxX = mx.x
                end
                if mn.y < minY then
                    minY = mn.y
                end
                if mx.y > maxY then
                    maxY = mx.y
                end
                if mn.z < minZ then
                    minZ = mn.z
                end
                if mx.z > maxZ then
                    maxZ = mx.z
                end
            end
            local sizeX = math.max(0.1, maxX - minX)
            local sizeY = math.max(0.1, maxY - minY)
            local sizeZ = math.max(0.1, maxZ - minZ)
            local maxSize = math.max(sizeX, sizeZ)
            -- 基于尺寸的经验距离：水平距离覆盖物体宽度，留一定余量；限制在[min,max]内
            local fov = CS.UnityEngine.Camera.main and CS.UnityEngine.Camera.main.fieldOfView or 60
            local fovScale = 60 / math.max(10, math.min(90, fov))
            local base = maxSize * 1.8 * fovScale + sizeY * 0.2
            local MIN_D, MAX_D = 6, 80
            distance = math.max(MIN_D, math.min(MAX_D, base))
        else
            distance = 10
        end
    end
    local heightOffset = distance * math.sin(radians)
    local horizontalOffset = distance * math.cos(radians)

    -- 保持当前相机的水平方向
    local forward = camTf.forward
    local forwardXZ = CS.UnityEngine.Vector3(forward.x, 0, forward.z)
    if forwardXZ.magnitude < 0.001 then
        forwardXZ = CS.UnityEngine.Vector3.forward
    end
    forwardXZ = forwardXZ.normalized

    -- 计算目标位置：在物体位置基础上，向后偏移并抬高
    local targetPos = CS.UnityEngine.Vector3(selectedPos.x - forwardXZ.x * horizontalOffset,
        selectedPos.y + heightOffset, selectedPos.z - forwardXZ.z * horizontalOffset)

    -- 将相机抬高到物体顶部之上一定偏移，保证“刚好能看到”
    -- local topY = selectedPos.y
    -- local renders = go:GetComponentsInChildren(typeof(CS.UnityEngine.Renderer))
    -- if renders and renders.Length and renders.Length > 0 then
    -- 	local maxY = -999999
    -- 	local minY = 999999
    -- 	for i = 0, renders.Length - 1 do
    -- 		local b = renders[i].bounds
    -- 		if b.max.y > maxY then maxY = b.max.y end
    -- 		if b.min.y < minY then minY = b.min.y end
    -- 	end
    -- 	topY = maxY
    -- 	local height = math.max(0.01, maxY - minY)
    -- 	local yOffset = math.max(0.6, math.min(2, height * 0.5))
    -- 	targetPos.y = topY + yOffset
    -- else
    -- 	-- 无渲染器时，使用一个默认向上偏移
    -- 	targetPos.y = selectedPos.y + 1.0
    -- end

    -- 约束相机在场景范围
    if targetPos.x < self.X_MIN - Camera_Gap then
        targetPos.x = self.X_MIN - Camera_Gap
    elseif targetPos.x > self.X_MAX + Camera_Gap then
        targetPos.x = self.X_MAX + Camera_Gap
    end
    if targetPos.z < self.Z_MIN - Camera_Gap then
        targetPos.z = self.Z_MIN - Camera_Gap
    elseif targetPos.z > self.Z_MAX + Camera_Gap then
        targetPos.z = self.Z_MAX + Camera_Gap
    end

    -- Y 轴约束（若有边界）
    if self.Y_MIN then
        if targetPos.y < self.Y_MIN then
            targetPos.y = self.Y_MIN
        end
    end
    if self.Y_MAX then
        if targetPos.y > self.Y_MAX then
            targetPos.y = self.Y_MAX
        end
    end

    camTf.position = targetPos
    -- 垂直方向对准选中物体
    camTf:LookAt(selectedPos)

    -- 同步相机高度滑条UI
    if self.cametaSlider and self.CAMERA_Y_MIN and self.CAMERA_Y_MAX and self.CAMERA_Y_MAX ~= self.CAMERA_Y_MIN then
        local ratio = (camTf.position.y - self.CAMERA_Y_MIN) / (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN)
        if ratio < 0 then
            ratio = 0
        end
        if ratio > 1 then
            ratio = 1
        end
        self.cametaSlider.value = ratio
    end
end

function UGCEditor:SetLockBtnSelected(selected)
    self.lockBtn.image.sprite = selected and self.lockBtnSelectedSprite or self.lockBtnNormalSprite
end

function UGCEditor:RefreshOpLockState()

    if #self.selectedList > 0 then

        self.deleteBtn.interactable = true -- 先重置状态

        local info = self.selectedList[1]
        local locked = info.locked or 0
        self.updownBg.gameObject:SetActive(locked == 0)
        self.updownBg_gray.gameObject:SetActive(locked == 1)

        self.moveJoystick_gray.gameObject:SetActive(locked == 1)
        self.moveJoystick.gameObject:SetActive(locked == 0)

        self.rotateBtn.interactable = locked == 0
        self.deleteBtn.interactable = locked == 0
        self:SetLockBtnSelected(locked == 1)

    end

    if #self.selectedList == 1 then -- 只选中特殊道具 删除置灰
        local info = self.selectedList[1]
        if SpecialGuid[info.guid] ~= nil then
            self.deleteBtn.interactable = false
        end
    end

end

function UGCEditor:CreateCubeBox(size)
    -- 创建一个空的 GameObject 作为包围盒父节点
    local gameObject = CS.UnityEngine.GameObject("Polygon")

    -- 统一的材质与参数
    local shader = CS.UnityEngine.Shader.Find("UI/Default")
    local material = CS.UnityEngine.Material(shader)
    if HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
        -- 蓝色
        material.color = CS.UnityEngine.Color(0 / 255.0, 0 / 255.0, 255 / 255.0, 1)
    else
        material.color = CS.UnityEngine.Color(255 / 255.0, 245 / 255.0, 1 / 255.0, 1)
    end

    material.renderQueue = 3500

    local lineWidth = 0.08
    -- 需要这个线的宽度跟物体的size有关，但是有范围上线
    if size then
        local sx = math.abs(size.x or 0)
        local sy = math.abs(size.y or 0)
        local sz = math.abs(size.z or 0)
        local baseDim = math.max(sx, sy, sz)
        -- 按尺寸比例放大：系数可根据观感微调；并限制上下限
        local minWidth = 0.08
        local maxWidth = 0.4
        local scaleFactor = 0.02
        local w = baseDim * scaleFactor
        if w < minWidth then
            w = minWidth
        end
        if w > maxWidth then
            w = maxWidth
        end
        lineWidth = w
    end

    -- 立方体8个顶点（局部坐标）
    local points = {Vector3(-0.5, 0, -0.5), -- 1 底面左下
    Vector3(0.5, 0, -0.5), -- 2 底面右下
    Vector3(0.5, 0, 0.5), -- 3 底面右上
    Vector3(-0.5, 0, 0.5), -- 4 底面左上
    Vector3(-0.5, 1, -0.5), -- 5 顶面左下
    Vector3(0.5, 1, -0.5), -- 6 顶面右下
    Vector3(0.5, 1, 0.5), -- 7 顶面右上
    Vector3(-0.5, 1, 0.5) -- 8 顶面左上
    }

    -- 12条边（避免折线拼接导致的拐角尖刺，每条边单独渲染）
    local edges = {{1, 2}, {2, 3}, {3, 4}, {4, 1}, -- 底面四边
    {5, 6}, {6, 7}, {7, 8}, {8, 5}, -- 顶面四边
    {1, 5}, {2, 6}, {3, 7}, {4, 8} -- 四条立边
    }

    local createEdge = function(a, b, idx)
        local edge = CS.UnityEngine.GameObject("edge_" .. tostring(idx))
        edge.transform:SetParent(gameObject.transform, false)

        local lr = edge:AddComponent(typeof(CS.UnityEngine.LineRenderer))
        lr.useWorldSpace = false
        lr.positionCount = 2
        lr.startWidth = lineWidth
        lr.endWidth = lineWidth
        lr.numCapVertices = 4 -- 端帽平滑，避免交汇处尖刺
        lr.numCornerVertices = 0
        lr.material = material
        lr:SetPosition(0, points[a])
        lr:SetPosition(1, points[b])
    end

    for i, pair in ipairs(edges) do
        createEdge(pair[1], pair[2], i)
    end

    gameObject:SetActive(false)
    return gameObject
end

-- 计算考虑旋转角度的速度分量
function UGCEditor:CalculateVelocityComponents(power, angle, rotationY)
    -- power: 弹射力度
    -- angle: 弹射角度（与水平面的夹角）
    -- rotationY: 物体的Y轴旋转角度（度）

    -- if  not angle then
    --     g_Log("11111111111111",debug.traceback())
    -- end
    -- 首先计算不考虑旋转时的速度分量
    local y_speed = power * math.sin(angle * math.pi / 180)
    local horizontal_speed = power * math.cos(angle * math.pi / 180)

    -- 将水平速度分解到x和z轴（考虑旋转）
    local rotation_rad = rotationY * math.pi / 180
    local x_speed = horizontal_speed * math.sin(rotation_rad)
    local z_speed = horizontal_speed * math.cos(rotation_rad)

    return x_speed, y_speed, z_speed
end

-- 检查并显示运动器参数编辑面板
function UGCEditor:CheckAndShowMoverEditPanel()
    local count = #self.selectedList

    if count ~= 1 then -- 只能同时编辑1个
        self.moverEdit.gameObject:SetActive(false)
        for i, info in ipairs(self.selectedList) do
            if info.mover_type == Move_Type.Jump or info.mover_type == Move_Type.Shoot then
                CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(info.mover_id, false)
            end
        end
        return
    end

    local info = self.selectedList[1]

    local go = self.goParent:Find(info.guid)
    local attrs = info.mover_attributes or {}

    local delaySave = function()
        if self.delaysaveCor then
            self.delaysaveCor:Stop()
            self.delaysaveCor = nil
        end
        self.delaysaveCor = self:StartCoroutine(function()
            self.commonService:YieldSeconds(0.1)
            self:SaveSelectionInfo()
            self:PushSnapshot()
            self.delaysaveCor = nil
        end)
    end

    if info.mover_type == Move_Type.Jump then

        -- 调用运动服务，设置蹦床
        -- 已经注册过，则先删除
        if info.mover_id then
            local mover = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:GetMover(info.mover_id)
            if mover then
                CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:UnRegisterMover(info.mover_id)
                -- g_Log("zzzz -- 找到了id",info.mover_id)
            else
                -- g_Log("zzzz -- 没找到id",info.mover_id)
            end

        end
        local id = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:RegisterMover({
            move_object = go,
            speedY = info.jump_speed or (attrs and attrs["jump_speed.def"]) or 0,
            speedX = 0,
            speedZ = 0
        })
        -- g_Log("zzzz -- 注册了id",id)
        CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:startMover(id)
        CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(id, true)
        info.mover_id = id
        -- 设置参数调整面板
        self.moverEdit_title.text = "设置“蹦床”数值"
        -- 删除所有参数项
        for i = 0, self.moverEdit_editors_content.childCount - 1 do
            local child = self.moverEdit_editors_content:GetChild(i)
            if not Util:IsNil(child) then
                GameObject.Destroy(child.gameObject)
            end
        end
        -- self.moverEdit_editors_content.childCount = 0
        -- 添加蹦床相关参数配置
        if info.mover_attributes and info.mover_attributes["jump_speed.min"] and info.mover_attributes["jump_speed.max"] and
            info.mover_attributes["jump_speed.adj"] and info.mover_attributes["jump_speed.def"] then
            -- 添加一个参数项
            local paramItem = GameObject.Instantiate(self.moverEdit_item)
            paramItem.transform:SetParent(self.moverEdit_editors_content)
            paramItem.transform.localScale = Vector3.one
            paramItem.transform.localRotation = Quaternion.identity

            local title = paramItem:Find("title"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))
            local add = paramItem:Find("add"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local mus = paramItem:Find("mus"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local slider = paramItem:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))

            add.interactable = (info.locked or 0) ~= 1
            mus.interactable = (info.locked or 0) ~= 1
            slider.interactable = (info.locked or 0) ~= 1

            title.text = "跳跃速度：" .. info.jump_speed
            self.commonService:AddEventListener(add, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value + (attrs["jump_speed.adj"] or 0)

            end)
            self.commonService:AddEventListener(mus, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value - (attrs["jump_speed.adj"] or 0)

            end)
            slider.minValue = attrs["jump_speed.min"] or 0
            slider.maxValue = attrs["jump_speed.max"] or 0
            slider.value = info.jump_speed
            self.commonService:AddEventListener(slider, "onValueChanged", function()

                if not self:CanOperate() then
                    slider.value = info.jump_speed
                    title.text = "跳跃速度：" .. info.jump_speed
                    return
                end
                if info and (info.locked or 0) == 1 then
                    slider.value = info.jump_speed
                    title.text = "跳跃速度：" .. info.jump_speed
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                local value = slider.value
                if value % 1 == 0 then
                    value = math.floor(value)
                else
                    -- 四舍五入
                    value = math.floor(value * 10 + 0.5) / 10
                end
                if value < (attrs["jump_speed.min"] or 0) then
                    value = attrs["jump_speed.min"] or 0
                end
                if value > (attrs["jump_speed.max"] or 0) then
                    value = attrs["jump_speed.max"] or 0
                end
                slider.value = value
                title.text = "跳跃速度：" .. value
                if info.jump_speed ~= value then
                    info.jump_speed = value
                    -- 重新绘制轨迹线
                    local mover = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:GetMover(info.mover_id)
                    mover.speedY = value
                    CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(info.mover_id, true)
                end

                delaySave()

            end)
        end

        self.moverEdit.gameObject:SetActive(true)
    elseif info.mover_type == Move_Type.Shoot then
        self.moverEdit_title.text = "设置“弹簧板”数值"

        -- 获取物体的当前旋转角度
        local rotationY = go.transform.localEulerAngles.y

        -- 使用新的计算函数计算速度分量
        local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(info.jump_power, info.jump_angle, rotationY)

        if info.mover_id then
            local mover = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:GetMover(info.mover_id)
            if mover then
                CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:UnRegisterMover(info.mover_id)
            end
        end

        -- 调用运动服务，设置弹簧板
        local id = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:RegisterMover({
            move_object = go,
            speedY = y_speed,
            speedX = x_speed,
            speedZ = z_speed
        })
        CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:startMover(id)
        CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(id, true)
        info.mover_id = id
        -- 设置参数调整面板
        -- 删除所有参数项
        for i = 0, self.moverEdit_editors_content.childCount - 1 do
            local child = self.moverEdit_editors_content:GetChild(i)
            if not Util:IsNil(child) then
                GameObject.Destroy(child.gameObject)
            end
        end
        -- self.moverEdit_editors_content.childCount = 0
        -- 添加蹦床相关参数配置
        if info.mover_attributes and info.mover_attributes["jump_power.min"] and info.mover_attributes["jump_power.max"] and
            info.mover_attributes["jump_power.adj"] and info.mover_attributes["jump_power.def"] then
            -- 添加一个参数项
            local paramItem = GameObject.Instantiate(self.moverEdit_item)
            paramItem.transform:SetParent(self.moverEdit_editors_content)
            paramItem.transform.localScale = Vector3.one
            paramItem.transform.localRotation = Quaternion.identity

            local title = paramItem:Find("title"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))
            local add = paramItem:Find("add"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local mus = paramItem:Find("mus"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local slider = paramItem:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))

            add.interactable = (info.locked or 0) ~= 1
            mus.interactable = (info.locked or 0) ~= 1
            slider.interactable = (info.locked or 0) ~= 1

            title.text = "弹射力度：" .. info.jump_power
            self.commonService:AddEventListener(add, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value + ((attrs and attrs["jump_power.adj"]) or 0)
            end)
            self.commonService:AddEventListener(mus, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value - ((attrs and attrs["jump_power.adj"]) or 0)
            end)
            slider.minValue = (attrs and attrs["jump_power.min"]) or 0
            slider.maxValue = (attrs and attrs["jump_power.max"]) or 0
            slider.value = info.jump_power
            self.commonService:AddEventListener(slider, "onValueChanged", function()
                if not self:CanOperate() then
                    slider.value = info.jump_power
                    title.text = "弹射力度：" .. info.jump_power
                    return
                end
                if info and (info.locked or 0) == 1 then
                    slider.value = info.jump_power
                    title.text = "弹射力度：" .. info.jump_power
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                local value = slider.value
                if value % 1 == 0 then
                    value = math.floor(value)
                else
                    -- 四舍五入
                    value = math.floor(value * 10 + 0.5) / 10
                end
                if value < ((attrs and attrs["jump_power.min"]) or 0) then
                    value = (attrs and attrs["jump_power.min"]) or 0
                end
                if value > ((attrs and attrs["jump_power.max"]) or 0) then
                    value = (attrs and attrs["jump_power.max"]) or 0
                end
                slider.value = value
                title.text = "弹射力度：" .. value
                if info.jump_power ~= value then
                    info.jump_power = value

                    -- 获取物体的当前旋转角度
                    local rotationY = go.transform.localEulerAngles.y

                    -- 使用新的计算函数计算速度分量
                    local x_speed, y_speed, z_speed =
                        self:CalculateVelocityComponents(value, info.jump_angle, rotationY)

                    -- 重新绘制轨迹线
                    local mover = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:GetMover(info.mover_id)
                    mover.speedY = y_speed
                    mover.speedX = x_speed
                    mover.speedZ = z_speed
                    CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(info.mover_id, true)
                end

                delaySave()
            end)
        end
        if info.mover_attributes and info.mover_attributes["jump_angle.min"] and info.mover_attributes["jump_angle.max"] and
            info.mover_attributes["jump_angle.adj"] and info.mover_attributes["jump_angle.def"] then
            -- 添加一个参数项
            local paramItem = GameObject.Instantiate(self.moverEdit_item)
            paramItem.transform:SetParent(self.moverEdit_editors_content)
            paramItem.transform.localScale = Vector3.one
            paramItem.transform.localRotation = Quaternion.identity

            local title = paramItem:Find("title"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))
            local add = paramItem:Find("add"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local mus = paramItem:Find("mus"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local slider = paramItem:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))

            add.interactable = (info.locked or 0) ~= 1
            mus.interactable = (info.locked or 0) ~= 1
            slider.interactable = (info.locked or 0) ~= 1

            title.text = "弹射角度：" .. info.jump_angle
            self.commonService:AddEventListener(add, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value + ((attrs and attrs["jump_angle.adj"]) or 0)
            end)
            self.commonService:AddEventListener(mus, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value - ((attrs and attrs["jump_angle.adj"]) or 0)
            end)
            slider.minValue = (attrs and attrs["jump_angle.min"]) or 0
            slider.maxValue = (attrs and attrs["jump_angle.max"]) or 0
            slider.value = info.jump_angle
            self.commonService:AddEventListener(slider, "onValueChanged", function()
                if not self:CanOperate() then
                    slider.value = info.jump_angle
                    title.text = "弹射角度：" .. info.jump_angle
                    return
                end
                if info and (info.locked or 0) == 1 then
                    slider.value = info.jump_angle
                    title.text = "弹射角度：" .. info.jump_angle
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                local value = math.floor(slider.value)
                if value < ((attrs and attrs["jump_angle.min"]) or 0) then
                    value = (attrs and attrs["jump_angle.min"]) or 0
                end
                if value > ((attrs and attrs["jump_angle.max"]) or 0) then
                    value = (attrs and attrs["jump_angle.max"]) or 0
                end
                slider.value = value
                title.text = "弹射角度：" .. value
                if info.jump_angle ~= value then
                    info.jump_angle = value

                    local rotationY = go.transform.localEulerAngles.y
                    local x_speed, y_speed, z_speed =
                        self:CalculateVelocityComponents(info.jump_power, value, rotationY)
                    -- 重新绘制轨迹线
                    local mover = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:GetMover(info.mover_id)
                    mover.speedY = y_speed
                    mover.speedX = x_speed
                    mover.speedZ = z_speed
                    CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(info.mover_id, true)
                end

                delaySave()
            end)
        end

        self.moverEdit.gameObject:SetActive(true)
    elseif info.mover_type == Move_Type.Trans then
        self.moverEdit_title.text = "设置“传送带”数值"

        if info.mover_id then
            local mover = CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:GetMover(info.mover_id)
            if mover then
                CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:UnRegisterMover(info.mover_id)
            end
        end

        -- 获取物体的当前旋转角度
        local rotationY = go.transform.localEulerAngles.y
        local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(info.trans_speed, 0, rotationY)
        local id = CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:RegisterMover({
            move_object = go,
            speedX = x_speed,
            speedZ = z_speed
        })
        CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:startMover(id)
        info.mover_id = id

        -- 删除所有参数项
        for i = 0, self.moverEdit_editors_content.childCount - 1 do
            local child = self.moverEdit_editors_content:GetChild(i)
            if not Util:IsNil(child) then
                GameObject.Destroy(child.gameObject)
            end
        end
        -- 添加传送带速度参数配置
        if info.mover_attributes and info.mover_attributes["trans_speed.min"] and
            info.mover_attributes["trans_speed.max"] and info.mover_attributes["trans_speed.adj"] and
            info.mover_attributes["trans_speed.def"] then
            -- 添加一个参数项
            local paramItem = GameObject.Instantiate(self.moverEdit_item)
            paramItem.transform:SetParent(self.moverEdit_editors_content)
            paramItem.transform.localScale = Vector3.one
            paramItem.transform.localRotation = Quaternion.identity

            local title = paramItem:Find("title"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))
            local add = paramItem:Find("add"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local mus = paramItem:Find("mus"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local slider = paramItem:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))

            add.interactable = (info.locked or 0) ~= 1
            mus.interactable = (info.locked or 0) ~= 1
            slider.interactable = (info.locked or 0) ~= 1

            title.text = "传送带速度：" .. info.trans_speed
            self.commonService:AddEventListener(add, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value + ((attrs and attrs["trans_speed.adj"]) or 0)
            end)
            self.commonService:AddEventListener(mus, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value - ((attrs and attrs["trans_speed.adj"]) or 0)
            end)
            slider.minValue = (attrs and attrs["trans_speed.min"]) or 0
            slider.maxValue = (attrs and attrs["trans_speed.max"]) or 0
            slider.value = info.trans_speed
            self.commonService:AddEventListener(slider, "onValueChanged", function()
                if not self:CanOperate() then
                    slider.value = info.trans_speed
                    title.text = "传送带速度：" .. info.trans_speed
                    return
                end
                if info and (info.locked or 0) == 1 then
                    slider.value = info.trans_speed
                    title.text = "传送带速度：" .. info.trans_speed
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                -- 如果是整数，则取整，否则取一位小数
                local value = slider.value
                if value % 1 == 0 then
                    value = math.floor(value)
                else
                    -- 四舍五入
                    value = math.floor(value * 10 + 0.5) / 10
                end
                if value < ((attrs and attrs["trans_speed.min"]) or 0) then
                    value = (attrs and attrs["trans_speed.min"]) or 0
                end
                if value > ((attrs and attrs["trans_speed.max"]) or 0) then
                    value = (attrs and attrs["trans_speed.max"]) or 0
                end
                slider.value = value
                title.text = "传送带速度：" .. value
                if info.trans_speed ~= value then
                    info.trans_speed = value
                    -- 获取物体的当前旋转角度
                    local rotationY = go.transform.localEulerAngles.y
                    local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(value, 0, rotationY)
                    local mover = CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:GetMover(info.mover_id)
                    mover.speedX = x_speed
                    mover.speedZ = z_speed
                end

                delaySave()
            end)
        end
        -- 已经注册过，则先删除
        self.moverEdit.gameObject:SetActive(true)
    elseif info.mover_type == Move_Type.Speed then
        self.moverEdit_title.text = "设置“加速器”数值"

        -- 已经注册过，则先删除
        if info.mover_id then
            local mover = CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:GetMover(info.mover_id)
            if mover then
                CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:UnRegisterMover(info.mover_id)
            end
        end

        local id = CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:RegisterMover({
            move_object = go,
            speedTime = info.speed_duration,
            cd = 3,
            speed = 1.5
        })
        CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:startMover(id)
        info.mover_id = id

        -- 删除所有参数项
        for i = 0, self.moverEdit_editors_content.childCount - 1 do
            local child = self.moverEdit_editors_content:GetChild(i)
            if not Util:IsNil(child) then
                GameObject.Destroy(child.gameObject)
            end
        end
        -- 添加加速器持续时间参数配置
        if info.mover_attributes and info.mover_attributes["speed_duration.min"] and
            info.mover_attributes["speed_duration.max"] and info.mover_attributes["speed_duration.adj"] and
            info.mover_attributes["speed_duration.def"] then
            -- 添加一个参数项
            local paramItem = GameObject.Instantiate(self.moverEdit_item)
            paramItem.transform:SetParent(self.moverEdit_editors_content)
            paramItem.transform.localScale = Vector3.one
            paramItem.transform.localRotation = Quaternion.identity

            local title = paramItem:Find("title"):GetComponent(typeof(CS.TMPro.TextMeshProUGUI))
            local add = paramItem:Find("add"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local mus = paramItem:Find("mus"):GetComponent(typeof(CS.UnityEngine.UI.Button))
            local slider = paramItem:Find("Slider"):GetComponent(typeof(CS.UnityEngine.UI.Slider))

            add.interactable = (info.locked or 0) ~= 1
            mus.interactable = (info.locked or 0) ~= 1
            slider.interactable = (info.locked or 0) ~= 1

            title.text = "加速持续时间：" .. info.speed_duration
            self.commonService:AddEventListener(add, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value + ((attrs and attrs["speed_duration.adj"]) or 0)
            end)
            self.commonService:AddEventListener(mus, "onClick", function()
                if not self:CanOperate() then
                    return
                end
                if info and (info.locked or 0) == 1 then
                    if self.commonService and self.commonService.ShowTip then
                        self.commonService:ShowTip("已锁定，无法操作")
                    end
                    return
                end
                slider.value = slider.value - ((attrs and attrs["speed_duration.adj"]) or 0)
            end)
            slider.minValue = (attrs and attrs["speed_duration.min"]) or 0
            slider.maxValue = (attrs and attrs["speed_duration.max"]) or 0
            slider.value = info.speed_duration
            self.commonService:AddEventListener(slider, "onValueChanged", function()
                if not self:CanOperate() then
                    slider.value = info.speed_duration
                    title.text = "加速持续时间：" .. info.speed_duration
                    return
                end
                if info and (info.locked or 0) == 1 then
                    slider.value = info.speed_duration
                    title.text = "加速持续时间：" .. info.speed_duration
                    if self.ShowTips then
                        self:ShowTips("已锁定，无法操作")
                    end
                    return
                end
                local value = slider.value
                if value % 1 == 0 then
                    value = math.floor(value)
                else
                    -- 四舍五入
                    value = math.floor(value * 10 + 0.5) / 10
                end
                if value < ((attrs and attrs["speed_duration.min"]) or 0) then
                    value = (attrs and attrs["speed_duration.min"]) or 0
                end
                if value > ((attrs and attrs["speed_duration.max"]) or 0) then
                    value = (attrs and attrs["speed_duration.max"]) or 0
                end
                slider.value = value
                title.text = "加速持续时间：" .. value
                if info.speed_duration ~= value then
                    info.speed_duration = value
                    local mover = CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:GetMover(info.mover_id)
                    mover.speedTime = value
                end

                delaySave()
            end)
        end
        self.moverEdit.gameObject:SetActive(true)
    else
        self.moverEdit.gameObject:SetActive(false)
    end
end

function UGCEditor:ShowTips(tips)
    if not tips or tips == "" then
        return
    end

    if self.toastCoroutine then
        self.toastCoroutine:Stop()
        self.toastCoroutine = nil
    end

    self.toastCoroutine = self.commonService:StartCoroutine(function()
        self.tipsText.text = tips
        self.tipsView.gameObject:SetActive(true)
        -- 等一帧
        self.tipsHorLayout.childAlignment = 4
        self.commonService:YieldEndFrame()
        self.tipsHorLayout.childAlignment = 5

        self.commonService:YieldSeconds(1)
        self.tipsView.gameObject:SetActive(false)
        self.toastCoroutine = nil
    end)
end

function UGCEditor:SwitchCameraMode()
    self.camera_mode = self.camera_mode == Camera_Mode.Normal and Camera_Mode.BirdEye or Camera_Mode.Normal
    self.swichCameraBtn.transform:Find("normal").gameObject:SetActive(self.camera_mode == Camera_Mode.Normal)
    self.swichCameraBtn.transform:Find("select").gameObject:SetActive(self.camera_mode == Camera_Mode.BirdEye)

    if CS.UnityEngine.Camera.main == nil then
        return
    end

    local camTf = Camera.main.transform

    if self.camera_mode == Camera_Mode.BirdEye then
        -- 保存当前相机位姿
        self._prevCamPos = camTf.position
        self._prevCamEuler = camTf.eulerAngles

        -- 拉到最高的相机高度
        if self.CAMERA_Y_MAX then
            local pos = camTf.position
            pos.y = self.CAMERA_Y_MAX
            camTf.position = pos

            -- 完全俯视：相机垂直向下
            local curY = camTf.eulerAngles.y
            camTf.eulerAngles = Vector3(90, curY, 0)

            -- 同步高度滑条
            if self.cametaSlider and self.CAMERA_Y_MIN and self.CAMERA_Y_MAX and self.CAMERA_Y_MAX ~= self.CAMERA_Y_MIN then
                local ratio = (pos.y - self.CAMERA_Y_MIN) / (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN)
                self.cametaSlider.value = ratio
            end
        end
    else
        -- 还原进入鸟瞰前的相机位姿
        if self._prevCamPos and self._prevCamEuler then
            camTf.position = self._prevCamPos
            camTf.eulerAngles = self._prevCamEuler

            -- 同步高度滑条
            if self.cametaSlider and self.CAMERA_Y_MIN and self.CAMERA_Y_MAX and self.CAMERA_Y_MAX ~= self.CAMERA_Y_MIN then
                local ratio = (camTf.position.y - self.CAMERA_Y_MIN) / (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN)
                self.cametaSlider.value = ratio
            end
        end
    end
end
-- 家园挑战开关
function UGCEditor:GameSwitch(isStart)

    self.gameStart = isStart

    if not HOME_CONFIG_INFO.IsOwner then
        return
    end

    if isStart then
        self.game_startView.gameObject:SetActive(true)
        self.game_normalView.gameObject:SetActive(false)
        self:RefreshGameUI()
    else
        self.game_startView.gameObject:SetActive(false)
        self.game_normalView.gameObject:SetActive(true)
    end
end

-- 通知其他组件庭院挑战状态
function UGCEditor:NotifyGameEvent()
    -- if not self.gameStart then
    --     return
    -- end

    self.observerService:Fire("EVENT_GAME_OPEN", {
        mode = self.UGCSourceType == UGCSource.Park and "yard" or "island", -- 庭院
        questionCount = self.game_questionCount,
        endCount = self.game_endCount,
        isOpen = self.gameStart
    })

end

-- 刷新挑战面板旗帜、宝箱的摆放状态
function UGCEditor:RefreshGameUI()

    local questionCount = 0
    local endCount = 0
    self.game_question_list = {}
    for k, v in pairs(self.PlaceMap) do
        local gameType = v.gameType
        if gameType == Game_Type.Question then
            questionCount = questionCount + 1
            table.insert(self.game_question_list, v)
        elseif gameType == Game_Type.End then
            endCount = endCount + 1
            table.insert(self.game_question_list, v)
        end
    end

    self.game_questionCount = questionCount
    self.game_endCount = endCount

    if not HOME_CONFIG_INFO.IsOwner then
        return
    end

    if not self.game_startView.gameObject.activeSelf then
        return
    end

    self.game_tips1Layout.childAlignment = 1
    self.game_tips2Layout.childAlignment = 1
    App:GetService("CommonService"):DispatchNextFrame(function()
        self.game_tips1Layout.childAlignment = 5
        self.game_tips2Layout.childAlignment = 5
    end)

    self.game_tips1Icon.gameObject:SetActive(questionCount > 0)
    self.game_tips2Icon.gameObject:SetActive(endCount > 0)

    if questionCount > 0 then
        -- 颜色#4DFF7C
        self.game_tips1Text.color = CS.UnityEngine.Color(0.30588236, 1, 0.4862745, 1)
        self.game_tips1Text.text = "已设置" .. tostring(questionCount) .. "题"
    else
        -- 颜色#FFFFFF 透明度50%
        self.game_tips1Text.color = CS.UnityEngine.Color(1, 1, 1, 0.5)
        self.game_tips1Text.text = "未设置"
    end

    if endCount > 0 then
        self.game_tips2Text.color = CS.UnityEngine.Color(0.30588236, 1, 0.4862745, 1)
        self.game_tips2Text.text = "已设置"
    else
        self.game_tips2Text.color = CS.UnityEngine.Color(1, 1, 1, 0.5)
        self.game_tips2Text.text = "未设置"
    end
end

-- 显示发布确认弹窗
function UGCEditor:ShowCommitAlert(callback)

    self.canvas.sortingOrder = 1500
    self.submitAlert.gameObject:SetActive(true)
    self.submit_inputField.text = "完成全部题目即可获胜哦～"

    local len = string.utf8len(self.submit_inputField.text)

    self.submit_commitBtn.interactable = len > 0

    self.submit_numText.text = "玩法介绍(" .. tostring(len) .. "/14)"

    self:Fire("open_edit_grid", {
        isOpen = false
    })
    self.observerService:Fire("CAMERA_SHOT_GET_SPRITE", {
        callback = function(sprite)
            self.submit_PostImage.sprite = sprite
            self:Fire("open_edit_grid", {
                isOpen = true
            })
        end
    })

    local text = CS.UnityEngine.PlayerPrefs.GetString(self.TEXT_SAVE_KEY)
    if text and text ~= "" then
        self.submit_inputField.text = text
    end

end

function UGCEditor:ExecuteAction(action)

    if not self:CanOperate() then
        return
    end

    for i, info in ipairs(self.selectedList) do

        local go = self.goParent:Find(info.guid)

        local pos = go.transform.position
        local rotY = go.transform.localEulerAngles.y

        local rot = Camera.main.transform.rotation
        rot.x = 0
        rot.z = 0

        if action == Action.Up then
            pos = pos + Vector3.up * move_step
        elseif action == Action.Down then
            pos = pos + Vector3.down * move_step

        elseif action == Action.Rotate then
            rotY = (rotY + 30) % 360
        end

        -- 坐标在 x,y,z的 NIB-MAX之间
        if pos.x < self.X_MIN then
            pos.x = self.X_MIN
        elseif pos.x > self.X_MAX then
            pos.x = self.X_MAX
        elseif pos.z < self.Z_MIN then
            pos.z = self.Z_MIN
        elseif pos.z > self.Z_MAX then
            pos.z = self.Z_MAX
        elseif pos.y < self.Y_MIN then
            pos.y = self.Y_MIN
        elseif pos.y > self.Y_MAX then
            pos.y = self.Y_MAX
        end

        if self.usePhysics then
            local dir = pos - go.transform.position
            local moveControler = go.gameObject:GetComponent(typeof(CS.UnityEngine.CharacterController))
            moveControler:Move(dir)
        else
            -- go.transform.transform:DOMove(pos, 0.1)
            go.transform.position = pos
        end

        go.transform.localEulerAngles = Vector3(0, rotY, 0)

        -- 如果是弹簧板类型且发生了旋转，需要重新计算速度分量
        if info and info.mover_type == Move_Type.Shoot and info.mover_id and action == Action.Rotate then
            -- 获取物体的当前旋转角度
            local rotationY = rotY

            -- 使用新的计算函数计算速度分量
            local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(info.jump_power, info.jump_angle,
                rotationY)

            -- 更新运动器的速度
            local mover = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:GetMover(info.mover_id)
            if mover then
                mover.speedY = y_speed
                mover.speedX = x_speed
                mover.speedZ = z_speed
            end
        elseif info and info.mover_type == Move_Type.Trans and info.mover_id and action == Action.Rotate then
            local rotationY = rotY
            local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(info.trans_speed, 0, rotationY)
            local mover = CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:GetMover(info.mover_id)
            if mover then
                mover.speedX = x_speed
                mover.speedZ = z_speed
            end
        end
    end

    self:SaveSelectionInfo()
    self:PushSnapshot()
end

function UGCEditor:ExecuteCameraMove(moveOffset)

    local pos = Camera.main.transform.position

    -- 这里移动的方向 需要计算相对当前屏幕是左还是右
    local rot = Camera.main.transform.rotation
    rot.x = 0
    rot.z = 0

    local dir = rot.normalized * moveOffset

    local moveTarget = dir * camera_move_speed * Time.deltaTime
    pos = pos + moveTarget

    -- 坐标在 x,y,z的 NIB-MAX之间
    if pos.x < self.X_MIN - Camera_Gap then
        pos.x = self.X_MIN - Camera_Gap
    elseif pos.x > self.X_MAX + Camera_Gap then
        pos.x = self.X_MAX + Camera_Gap
    end

    if pos.z < self.Z_MIN - Camera_Gap then
        pos.z = self.Z_MIN - Camera_Gap
    elseif pos.z > self.Z_MAX + Camera_Gap then
        pos.z = self.Z_MAX + Camera_Gap
    end

    Camera.main.transform.position = pos
end

function UGCEditor:ExecuteObjMove(moveOffset)

    if not self:CanOperate() then
        return
    end

    -- 统一计算一次移动向量
    local rot = Camera.main.transform.rotation
    rot.x = 0
    rot.z = 0
    local dir = rot.normalized * moveOffset
    local moveTarget = dir * obj_move_speed * Time.deltaTime

    -- 预检测：按轴判断是否允许本次在该轴移动
    local allowX, allowZ = true, true
    for i, info in ipairs(self.selectedList) do
        local go = self.goParent:Find(info.guid)
        if Util:IsNil(go) then
            break
        end
        local targetPos = go.transform.position + moveTarget
        local box = self.selectedBoxMap[info.guid]
        if Util:IsNil(box) then
            break
        end
        local w = (box.transform.localScale.x * go.transform.localScale.x) / 2
        local h = (box.transform.localScale.z * go.transform.localScale.z) / 2
        local r = go.transform.localEulerAngles.y
        if r == 90 or r == 270 then
            local t = w
            w = h
            h = t
        end
        -- 判断各轴是否越界
        if targetPos.x < self.X_MIN + w or targetPos.x > self.X_MAX - w then
            allowX = false
        end
        if targetPos.z < self.Z_MIN + h or targetPos.z > self.Z_MAX - h then
            allowZ = false
        end
        if not allowX and not allowZ then
            break
        end
    end

    -- 按轴裁剪移动向量
    local finalMoveTarget = Vector3(allowX and moveTarget.x or 0, moveTarget.y, allowZ and moveTarget.z or 0)
    if finalMoveTarget.x == 0 and finalMoveTarget.y == 0 and finalMoveTarget.z == 0 then
        return
    end

    -- 通过预检：统一应用裁剪后的移动
    for i, info in ipairs(self.selectedList) do
        local go = self.goParent:Find(info.guid)
        if not Util:IsNil(go) then
            if self.usePhysics then
                local moveControler = go.gameObject:GetComponent(typeof(CS.UnityEngine.CharacterController))
                moveControler:Move(finalMoveTarget)
            else
                go.transform.position = go.transform.position + finalMoveTarget
            end
        end
    end

end

-- 将屏幕坐标投射到 y=planeY 的水平面
function UGCEditor:ScreenToPlane(screenPos, planeY)
    screenPos = screenPos * rt_scale
    if CS.UnityEngine.Camera.main == nil then
        return nil
    end
    local ray = Camera.main:ScreenPointToRay(screenPos)
    local ori = ray.origin
    local dir = ray.direction
    if math.abs(dir.y) < 1e-6 then
        return nil
    end
    local t = (planeY - ori.y) / dir.y
    if t < 0 then
        return nil
    end
    return ori + dir * t
end

-- 指针是否命中当前选中物体（或其子节点）
function UGCEditor:IsPointerOverSelected(screenPos)
    if #self.selectedList == 0 then
        return false
    end

    if CS.UnityEngine.Camera.main == nil then
        return false
    end

    screenPos = screenPos * rt_scale

    local ray = Camera.main:ScreenPointToRay(screenPos)

    -- 兼容已放置到家具层的情况
    local furnitureLayer = 1 << Layer_enum.furnitureLayer
    local selectedLayer = 1 << Layer_enum.selectedLayer
    local hits = CS.UnityEngine.Physics.RaycastAll(ray, 1000, furnitureLayer | selectedLayer)
    if hits and hits.Length > 0 then
        for i = 0, hits.Length - 1, 1 do
            local go = hits[i].collider.gameObject

            local guid = go.name
            local info = self.selectedMap[guid]

            if info and info.locked ~= 1 then
                return true, go
            end
        end
    end
    return false
end

-- 约束并设置选中物体位置，同时刷新运动器轨迹/速度
function UGCEditor:SetSelectedPositionWithConstraints(target)
    if not self.dragObj then
        return
    end

    if not self:CanOperate() then
        return
    end

    local dPos = target - self.dragObj.transform.position

    -- 预检：按轴判定，某轴任一越界则该轴不动（不进行夹取）
    local allowX, allowY, allowZ = true, true, true
    for i, info in ipairs(self.selectedList) do
        local guid = info.guid
        local go = self.goParent:Find(guid)
        local boxgo = self.selectedBoxMap[guid]

        local targetPos = go.transform.position + dPos

        -- 计算包围盒在XZ上的半宽半高（与 ExecuteObjMove 一致）
        local w = (boxgo.transform.localScale.x * go.transform.localScale.x) / 2
        local h = (boxgo.transform.localScale.z * go.transform.localScale.z) / 2

        local r = go.transform.localEulerAngles.y
        if r == 90 or r == 270 then
            local t = w
            w = h
            h = t
        end

        if targetPos.x < self.X_MIN + w or targetPos.x > self.X_MAX - w then
            allowX = false
        end
        if targetPos.z < self.Z_MIN + h or targetPos.z > self.Z_MAX - h then
            allowZ = false
        end
        if targetPos.y < self.Y_MIN or targetPos.y > self.Y_MAX then
            allowY = false
        end
        if not allowX and not allowY and not allowZ then
            break
        end
    end

    if not allowX and not allowY and not allowZ then
        return
    end

    -- 应用：统一执行裁剪后的 dPos
    local finalDPos = Vector3(allowX and dPos.x or 0, allowY and dPos.y or 0, allowZ and dPos.z or 0)
    if finalDPos.x == 0 and finalDPos.y == 0 and finalDPos.z == 0 then
        return
    end
    for i, info in ipairs(self.selectedList) do
        local guid = info.guid
        local go = self.goParent:Find(guid)
        if self.usePhysics then
            local moveControler = go.gameObject:GetComponent(typeof(CS.UnityEngine.CharacterController))
            moveControler:Move(finalDPos)
        else
            go.transform.position = go.transform.position + finalDPos
        end
    end
end

-- 拖拽时若选中物体接近屏幕边缘，则平移相机保持物体在安全可视范围
function UGCEditor:AutoPanCameraToKeepSelectedVisible()
    if not self.dragObj or CS.UnityEngine.Camera.main == nil then
        return
    end

    if not self:CanOperate() then
        return
    end

    local cam = Camera.main
    local w = CS.UnityEngine.Screen.width
    local h = CS.UnityEngine.Screen.height

    -- 计算选中物体的屏幕包围盒
    local minX, maxX, minY, maxY = self:GetSelectedScreenRect()
    if not minX then
        return
    end

    -- 边缘安全区（像素）
    local margin = 250

    local dx = 0
    local dy = 0
    if minX < margin then
        dx = minX - margin
    elseif maxX > w - margin then
        dx = maxX - (w - margin)
    end

    if minY < margin then
        dy = minY - margin
    elseif maxY > h - margin then
        dy = maxY - (h - margin)
    end

    if dx == 0 and dy == 0 then
        return
    end

    -- 将屏幕位移转换为相机移动方向：沿相机水平面 (绕 Y) 的前/右方向平移
    local move = Vector3.zero
    local referWidth = w
    local referHeight = h

    -- 根据屏幕偏差映射到世界空间的方向（与相机旋转控制同一比例系数）
    local rightFactor = (dx / referWidth)
    local upFactor = (dy / referHeight)

    local rot = cam.transform.rotation
    rot.x = 0
    rot.z = 0
    local rightDir = rot * Vector3.right
    local forwardDir = rot * Vector3.forward

    -- 映射移动量（速度系数可调）：与屏幕偏移同向，增加增益保证更快入框
    local panSpeed = camera_move_speed * 2
    local gain = 6.0 * 2
    move = (rightDir * rightFactor + forwardDir * upFactor) * panSpeed * gain * Time.deltaTime

    local pos = cam.transform.position + move

    -- 约束相机在场景范围（复用 ExecuteCameraMove 的边界逻辑）
    if pos.x < self.X_MIN - Camera_Gap then
        pos.x = self.X_MIN - Camera_Gap
    elseif pos.x > self.X_MAX + Camera_Gap then
        pos.x = self.X_MAX + Camera_Gap
    end
    if pos.z < self.Z_MIN - Camera_Gap then
        pos.z = self.Z_MIN - Camera_Gap
    elseif pos.z > self.Z_MAX + Camera_Gap then
        pos.z = self.Z_MAX + Camera_Gap
    end

    cam.transform.position = pos
end

-- 双指缩放（调节相机FOV）
function UGCEditor:HandlePinchZoom()
    if CS.UnityEngine.Camera.main == nil then
        return
    end
    local input = CS.UnityEngine.Input

    -- 编辑器/PC 调试手势：滚轮 或 Ctrl/Command + 右键上下拖动
    if (App.IsStudioClient or CS.UnityEngine.Application.isEditor) then
        local cam = Camera.main
        local fov = cam.fieldOfView
        local scroll = input.mouseScrollDelta.y
        if scroll ~= 0 then
            fov = fov - scroll * 2.0
            if fov < CAMERA_FOV_MIN then
                fov = CAMERA_FOV_MIN
            end
            if fov > CAMERA_FOV_MAX then
                fov = CAMERA_FOV_MAX
            end
            cam.fieldOfView = fov
            -- g_Log(self.TAG, "PC Zoom by Scroll", scroll, fov)
            return
        end

        if input.GetMouseButton and input.GetMouseButton(1) and
            (input.GetKey(CS.UnityEngine.KeyCode.LeftControl) or input.GetKey(CS.UnityEngine.KeyCode.LeftCommand)) then
            local dy = input.GetAxis and input.GetAxis("Mouse Y") or 0
            fov = fov - dy * 3.0
            if fov < CAMERA_FOV_MIN then
                fov = CAMERA_FOV_MIN
            end
            if fov > CAMERA_FOV_MAX then
                fov = CAMERA_FOV_MAX
            end
            cam.fieldOfView = fov
            -- g_Log(self.TAG, "PC Zoom by Drag", dy, fov)
            return
        end
    end
    if input.touchCount < 2 then
        -- g_Log(self.TAG, "Pinch: touchCount<2", input.touchCount)
        return
    end
    local t0 = input.GetTouch(0)
    local t1 = input.GetTouch(1)
    -- 只要两指任一移动就缩放
    if t0.phase == CS.UnityEngine.TouchPhase.Moved or t1.phase == CS.UnityEngine.TouchPhase.Moved then
        local prevPos0 = t0.position - t0.deltaPosition
        local prevPos1 = t1.position - t1.deltaPosition
        local prevDist = (prevPos0 - prevPos1).magnitude
        local currDist = (t0.position - t1.position).magnitude
        local delta = currDist - prevDist
        local cam = Camera.main
        local fov = cam.fieldOfView
        fov = fov - delta * PINCH_FOV_SENS
        if fov < CAMERA_FOV_MIN then
            fov = CAMERA_FOV_MIN
        end
        if fov > CAMERA_FOV_MAX then
            fov = CAMERA_FOV_MAX
        end
        cam.fieldOfView = fov
        -- g_Log(self.TAG, "Pinch: moved", "delta=", delta, "fov=", fov, "t0.phase=", tostring(t0.phase), "t1.phase=", tostring(t1.phase))
    else
        -- g_Log(self.TAG, "Pinch: no move", tostring(t0.phase), tostring(t1.phase))
    end
end

-- 获取当前选中物体的屏幕包围盒（minX, maxX, minY, maxY）
function UGCEditor:GetSelectedScreenRect()
    if not self.dragObj or CS.UnityEngine.Camera.main == nil then
        return nil
    end
    local cam = Camera.main
    local collider = self.dragObj:GetComponent(typeof(CS.UnityEngine.Collider))
    if Util:IsNil(collider) then
        return nil
    end
    local b = collider.bounds
    local c = b.center
    local e = b.extents
    -- 8 个角
    local corners = {Vector3(c.x - e.x, c.y - e.y, c.z - e.z), Vector3(c.x - e.x, c.y - e.y, c.z + e.z),
                     Vector3(c.x - e.x, c.y + e.y, c.z - e.z), Vector3(c.x - e.x, c.y + e.y, c.z + e.z),
                     Vector3(c.x + e.x, c.y - e.y, c.z - e.z), Vector3(c.x + e.x, c.y - e.y, c.z + e.z),
                     Vector3(c.x + e.x, c.y + e.y, c.z - e.z), Vector3(c.x + e.x, c.y + e.y, c.z + e.z)}
    local minX = math.huge
    local maxX = -math.huge
    local minY = math.huge
    local maxY = -math.huge
    for i = 1, #corners do
        local sp = cam:WorldToScreenPoint(corners[i])
        minX = math.min(minX, sp.x)
        maxX = math.max(maxX, sp.x)
        minY = math.min(minY, sp.y)
        maxY = math.max(maxY, sp.y)
    end
    return minX, maxX, minY, maxY
end

-- 框选：根据屏幕矩形选择物体
function UGCEditor:SelectObjectsInFrame(startScreenPos, endScreenPos)
    local cam = CS.UnityEngine.Camera.main
    if cam == nil then
        return
    end

    local minX = math.min(startScreenPos.x, endScreenPos.x)
    local maxX = math.max(startScreenPos.x, endScreenPos.x)
    local minY = math.min(startScreenPos.y, endScreenPos.y)
    local maxY = math.max(startScreenPos.y, endScreenPos.y)

    -- 框选前清空旧选择
    self:ClearAllSelection()

    -- 预计算视锥平面，用于快速剔除不在相机视野内的物体
    local GeometryUtility = CS.UnityEngine.GeometryUtility
    local planes = GeometryUtility.CalculateFrustumPlanes(cam)

    for guid, info in pairs(self.PlaceMap) do
        if info and info.locked ~= 1 then
            local go = self.goParent:Find(guid)
            if not Util:IsNil(go) and go.gameObject.activeSelf then
                local collider = go:GetComponent(typeof(CS.UnityEngine.Collider))
                if not Util:IsNil(collider) then
                    local b = collider.bounds

                    -- 先做视锥体裁剪：不在视野内的直接跳过
                    if not GeometryUtility.TestPlanesAABB(planes, b) then
                        -- 跳过
                    else
                        local c = b.center
                        local e = b.extents
                        local corners = {Vector3(c.x - e.x, c.y - e.y, c.z - e.z),
                                         Vector3(c.x - e.x, c.y - e.y, c.z + e.z),
                                         Vector3(c.x - e.x, c.y + e.y, c.z - e.z),
                                         Vector3(c.x - e.x, c.y + e.y, c.z + e.z),
                                         Vector3(c.x + e.x, c.y - e.y, c.z - e.z),
                                         Vector3(c.x + e.x, c.y - e.y, c.z + e.z),
                                         Vector3(c.x + e.x, c.y + e.y, c.z - e.z),
                                         Vector3(c.x + e.x, c.y + e.y, c.z + e.z)}

                        local ominX = math.huge
                        local omaxX = -math.huge
                        local ominY = math.huge
                        local omaxY = -math.huge
                        for i = 1, #corners do
                            local sp = cam:WorldToScreenPoint(corners[i]) / (rt_scale > 0 and rt_scale or 1)

                            ominX = math.min(ominX, sp.x)
                            omaxX = math.max(omaxX, sp.x)
                            ominY = math.min(ominY, sp.y)
                            omaxY = math.max(omaxY, sp.y)
                        end

                        local overlap = not (omaxX < minX or ominX > maxX or omaxY < minY or ominY > maxY)
                        if overlap then
                            self:AddSelection(go, info)
                        end
                    end
                end
            end
        end
    end
end

function UGCEditor:ShowGuide(callback)

    local key = "editor_guide" .. tostring(App.Info.userId)

    if CS.UnityEngine.PlayerPrefs.GetString(key) == "1" then
        if callback then
            callback()
        end
        return
    end

    CS.UnityEngine.PlayerPrefs.SetString(key, "1")
    CS.UnityEngine.PlayerPrefs.Save()

    self.canvas.sortingOrder = 1500
    self.guideView.gameObject:SetActive(true)
    local func = function()
        if callback then
            callback()
        end
        self.guideCallback = nil
    end
    self.guideCallback = func
end

function UGCEditor:EnterPlayMode(open)
    self.commitView.gameObject:SetActive(not open)
    self.playView.gameObject:SetActive(open)
    self.cameraView.gameObject:SetActive(not open)
    self.redoUndoView.gameObject:SetActive(not open)
    self.shopBtn.gameObject:SetActive(not open)
    self.swichCameraBtn.gameObject:SetActive(not open)

    -- 退出编辑时退出鸟瞰模式并恢复相机
    if self.camera_mode == Camera_Mode.BirdEye then
        self:SwitchCameraMode()
    end

    self.observerService:Fire("GLOBAL_NEED_CTRL_CHAT_CLOSE_OR_OPEN", {
        isOpen = open
    })
    self.playMode = open

    if open then

        if self.extendMutiSelectMenu then
            self.multiBtn.onClick:Invoke()
        end
        if self.muti_listView.gameObject.activeSelf then
            self.muti_list_btn.onClick:Invoke()
        end

        self.plusOpView.gameObject:SetActive(false)
        self.muti_list_btn.gameObject:SetActive(false)

        self.observerService:Fire("NEXT_QUESTION_HIDE")
        self.observerService:Fire("ABC_ZONE_HIDE_HOME_DRESS")

        self:LockCamera(false)

        self.selfAvatar.Body.gameObject:SetActive(true)

        self.joystickService:setVisibleJumpWithID(self.hideJumpId)
        self.joystickService:setVisibleJoyWithID(self.hideJoyId)
        -- self.uiService:SetVisibleHidenVoiceBtnWithID(self.hideMicId)

        self.hideJumpId = nil
        self.hideJoyId = nil

        self.touchPad.gameObject:SetActive(false)

        self.selfAvatar:TeleportAndNotice(self.play_posObj.transform.position)
        self.selfAvatar.BodyTrans.eulerAngles = Vector3(0, self.play_posObj.transform.localEulerAngles.y, 0)
        local rotation = self.selfAvatar.BodyTrans.localRotation
        self.selfAvatar.LookRotation.transform.localRotation = rotation

        self:EnableFurnitureBoxCollider(false)

        if self.UGCSourceType == UGCSource.IsLand then
            HOME_CONFIG_INFO.CommonFunc.SceneChanged(HOME_SCENE.Island)
        else
            HOME_CONFIG_INFO.CommonFunc.SceneChanged(HOME_SCENE.Yard)
        end

        self.selfAvatar.characterCtrl.ign = true
    else

        self.observerService:Fire("ABC_ZONE_SHOW_HOME_DRESS", {
            type = self.BagType
        })

        self:LockCamera(true)
        self.selfAvatar.Body.gameObject:SetActive(false)
        -- 隐藏摇杆等UI
        self.hideJumpId = self.joystickService:setHidenJumpWithID()
        self.hideJoyId = self.joystickService:setHidenJoyWithID()
        -- self.hideMicId = self.uiService:SetHidenVoiceBtnWithID()

        self.touchPad.gameObject:SetActive(true)
        self:EnableFurnitureBoxCollider(true)
        self:ClearWeakRef()

        self.selfAvatar.characterCtrl.ign = false
        self.observerService:Fire("EVETN_MAIN_PANEL_HIDE")

        self.plusOpView.gameObject:SetActive(true)
        self.muti_list_btn.gameObject:SetActive(true)
    end

end

function UGCEditor:ClearWeakRef()
    for k, v in pairs(self.weakRefArray) do
        if not Util:IsNil(v) then
            v.gameObject:SetActive(true)
        end
        self.weakRefArray[k] = nil
    end

    self.finish_game_questionCount = 0

end

function UGCEditor:EnterShotMode(open)
    -- self.moveView.gameObject:SetActive(not open)
    self.commitView.gameObject:SetActive(not open)
    self.shotScreenView.gameObject:SetActive(open)
    self.redoUndoView.gameObject:SetActive(not open)
    self.shopBtn.gameObject:SetActive(not open)
    self.swichCameraBtn.gameObject:SetActive(not open)

    -- 退出编辑时退出鸟瞰模式并恢复相机
    if self.camera_mode == Camera_Mode.BirdEye then
        self:SwitchCameraMode()
    end

    self:Fire("open_edit_grid", {
        isOpen = not open
    })

    if open then
        self.observerService:Fire("NEXT_QUESTION_HIDE")
        self.observerService:Fire("ABC_ZONE_HIDE_HOME_DRESS")

        if self.extendMutiSelectMenu then
            self.multiBtn.onClick:Invoke()
        end
        if self.muti_listView.gameObject.activeSelf then
            self.muti_list_btn.onClick:Invoke()
        end

        self.plusOpView.gameObject:SetActive(false)
        self.muti_list_btn.gameObject:SetActive(false)

    else

        self.observerService:Fire("ABC_ZONE_SHOW_HOME_DRESS", {
            type = self.BagType
        })

        self.plusOpView.gameObject:SetActive(true)
        self.muti_list_btn.gameObject:SetActive(true)
    end

end

function UGCEditor:GetHomeJsonData()
    local dic = {}
    self.fur_ids = {}
    for k, v in pairs(self.PlaceMap) do
        local _rid = nil
        local numId = tonumber(v.id) or 0
        if numId > 0 then
            _rid = self:ComputeRegionId(v.x, v.z)
        end
        local info = {
            x = v.x,
            y = v.y,
            z = v.z,
            r = v.r,
            uaddress = v.uaddress,
            id = v.id,
            guid = k,
            cost = v.cost,
            scale = v.scale,
            gameType = v.gameType,
            mover_type = v.mover_type,
            mover_id = v.mover_id,
            mover_attributes = v.mover_attributes,
            jump_speed = v.jump_speed,
            jump_power = v.jump_power,
            jump_angle = v.jump_angle,
            trans_speed = v.trans_speed,
            speed_duration = v.speed_duration,
            locked = v.locked or 0,
            img = v.img,
            region_id = _rid,
            level = v.level
        }
        table.insert(dic, info)
        table.insert(self.fur_ids, v.id)
    end

    local data = {
        version = 1.0,
        gameStart = self.gameStart,
        list = dic
    }

    local json = self.jsonService:encode(data)
    return json
end

function UGCEditor:GenerateHomePostImage(callback)
    if self.customPath then

        self.observerService:Fire("IMAGE_UPLOAD", {
            path = self.customPath,
            callback = function(url)
                self.customPath = nil
                if not url then
                    g_Log(self.TAG, "上传GenerateHomePostImage url为空")
                end
                callback(url, true)
            end
        })
    else
        self.observerService:Fire("CAMARA_SHOT_UPLOAD", {
            callback = function(url)
                callback(url)
            end,
            shotCallback = function(start)
                -- TODO截图前 隐藏掉一些不想被截进去的
                self:Fire("open_edit_grid", {
                    isOpen = not start
                })
            end
        })
    end
end

function UGCEditor:CommitAction()

    g_Log(self.TAG, "点击保存开始上传封面")
    self:ShowLoading(true)
    -- 获取封面截图
    self:GenerateHomePostImage(function(url, isCover)
        g_Log(self.TAG, "上传封面", url)
        if not url then
            self:ShowLoading(false)
            return
        end

        local picPath = self:shotScreenImage()
        if not picPath then
            self:ShowLoading(false)
            return
        end

        self.observerService:Fire("IMAGE_UPLOAD", {
            path = picPath,
            callback = function(url2)
                if not url2 then
                    -- self:ShowLoading(false)
                    -- return
                    g_Log(self.TAG, "上传审核图url2为空")
                    url2 = url
                end

                g_Log(self.TAG, "上传审核图成功", url2)
                local json = self:GetHomeJsonData()
                local c = self:CompressString(json)
                g_Log(self.TAG, "提交数据", json, c)

                self.jsonData = json

                self:SaveHomeSet(url, url2, c, isCover, function(success, errorMsg)
                    self:ShowLoading(false)

                    -- success = false
                    -- errorMsg = "12331313"
                    if not success then
                        -- CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast(errorMsg or "保存失败，请稍后再试",
                        --     3)
                        self.observerService:Fire("ABCZONE_COMMON_TOAST", {
                            content = errorMsg
                        })
                        return
                    end

                    self:EndEditor()
                    self.isDirty = false
                    self.resetDirty = false

                    CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("发布成功", 3)

                    if App.IsStudioClient and TEST_LOCAL_CACHE then
                        CS.UnityEngine.PlayerPrefs.SetString(self.HomeData_yard, c)
                    end

                    self.courtyard_location = c;
                    self.submitAlert.gameObject:SetActive(false)
                    self:SendMessage(self.PARK_DECORATE_CHANGED, {
                        uuid = App.Uuid
                    }, 1)

                    self:ClearLocalCache()

                    self:NotifyGameEvent()
                end)

            end
        })

    end)

    self:Report("park_editor_finish", "进入庭院摆放", "", {
        param_one = self.gameStart and 1 or 0
    })

    self:Report("home_map_release", "庭院发布", "", {
        param_one = 3
    })

    -- 一个image 用dotween实现放大再缩小

end

function UGCEditor:ResetAction(callback)
    self:ShowLoading(true)
    self:ApplyPlaceData(self.jsonData, function()
        self:ShowLoading(false)

        self:FurnitureCostEvent()

        if callback then
            callback()
        end

    end, true)
end

function UGCEditor:FurnitureCostEvent()

    if not HOME_CONFIG_INFO.IsOwner then
        return
    end

    local costMap = {}

    local placeCost = 0

    -- 检查是否是枪的数量
    local gunCount = 0
    for k, v in pairs(self.PlaceMap) do

        if v.id then
            local num = costMap[v.id] or 0
            costMap[v.id] = num + 1
        end

        if v.cost then
            placeCost = placeCost + v.cost
        else
            placeCost = placeCost + 1
        end

        if v.id == Special_Product_ID.Jujiqiang or v.id == Special_Product_ID.Zidanqiang or v.id ==
            Special_Product_ID.Buqiqiang or v.id == Special_Product_ID.Liudanpao then
            gunCount = gunCount + 1
        end

        if gunCount > 0 then
            self.gameSetView_game_gunText.color = CS.UnityEngine.Color(0, 1, 125 / 255, 1)
            self.gameSetView_game_gunText.text = " 已放置:" .. gunCount
        else
            self.gameSetView_game_gunText.color = CS.UnityEngine.Color(1, 0, 0, 1)
            self.gameSetView_game_gunText.text = " 未放置"
        end

    end

    xpcall(function()
        self.observerService:Fire("EVENT_HOME_FURNITURE_COST", {
            cost = costMap,
            placeCost = placeCost,
            from = self.BagType
        })

        g_Log(self.TAG, "家具花费", table.dump(costMap), placeCost)
    end, function(err)
        g_LogError(err)
    end)

end

function UGCEditor:EnableFurnitureBoxCollider(enable)

    if not self.colliderList then
        return
    end

    for i, v in ipairs(self.colliderList) do
        if not Util:IsNil(v) then
            v.enabled = enable
        end
    end
end

function UGCEditor:StartQuestion(callback, isGame)

    -- if App.IsStudioClient and not isGame then
    --     callback(true)
    --     return
    -- end

    if App.modPlatform == MOD_PLATFORM.Math or App.modPlatform == MOD_PLATFORM.Science then
        self.isAnswering = true
        self.uiPointDown = true
        g_Log(self.TAG, "开始答题1")
        self.observerService:Fire("Show_A_Math_Question_Event", {
            status = 1,
            propId = "-1",
            greatText = isGame and "太棒了，你已通过当前宝箱！" or nil,
            fightText = isGame and "未达标，当前宝箱挑战未成功" or nil,
            callBack = function(score, isFinal, isNoSpeaking, isPass)
                if not isFinal then
                    return
                end
                self.isAnswering = false
                local success = isPass
                g_Log(self.TAG, "答题结束1", score, isFinal, isNoSpeaking, isPass)
                self.uiPointDown = false
                callback(success)

                if not self.isEditing then
                    self.observerService:Fire("HOME_ADD_ENERGY")
                end
            end
        })
    elseif App.modPlatform == MOD_PLATFORM.ABCZone or App.modPlatform == MOD_PLATFORM.RealChinese then
        self.isAnswering = true
        self.uiPointDown = true
        g_Log(self.TAG, "开始答题")
        self.observerService:Fire("EVENT_BUSINESS_PROP_ANSWER_QUESTION", {
            status = 1,
            showAwardType = 7,
            noChangeChat = true,
            needInterception = true,
            passText = isGame and "太棒了，你已通过当前宝箱！" or nil,
            notPassText = isGame and "未达标，当前宝箱挑战未成功" or nil,
            highScore = 100,
            reTryCount = 1, -- 0或1 0答一次 1 答两次
            callBack = function(score, isFinal, isNoSpeaking, isPass)
                if not isFinal then
                    return
                end
                self.isAnswering = false
                local success = isPass
                g_Log(self.TAG, "答题结束", score, isFinal, isNoSpeaking, isPass)
                self.uiPointDown = false
                callback(success)

                if not self.isEditing then
                    self.observerService:Fire("HOME_ADD_ENERGY", {
                        score = score
                    })
                end
            end
        })
    elseif App.modPlatform == MOD_PLATFORM.Chinese then
        self.isAnswering = true
        self.uiPointDown = true
        g_Log(self.TAG, "开始答题3")
        self:Fire("EVENT_SHOW_CHINESE_ANSWER_PANEL", {
            passText = isGame and "太棒了，你已通过当前宝箱！" or nil,
            notPassText = isGame and "未达标，当前宝箱挑战未成功" or nil,
            callBack = function(result)
                self.isAnswering = false
                self.uiPointDown = false
                callback(result.isCorrect)
                if not self.isEditing then
                    self.observerService:Fire("HOME_ADD_ENERGY")
                end
            end
        })
    end

end
----多选相关

-- 是否多选模式
function UGCEditor:IsMultiSelectMode()
    return self.select_mode == Select_Mode.Multi_Click or self.select_mode == Select_Mode.Multi_Frame
end

-- 添加选中信息
function UGCEditor:AddSelection(go, info)

    if Util:IsNil(go) then
        return
    end

    local guid = go.name
    if self.selectedMap[guid] then
        -- 已经选中了，则取消选中
        self:RemoveSelection(go, info)
        return
    end

    -- g_Log("选中物品",table.dump(info))

    go.gameObject.layer = Layer_enum.furnitureLayer

    local selectGo = function(go, guid, info)
        self.selectedMap[guid] = info
        table.insert(self.selectedList, info)

        local lastBox = go.transform:Find("Polygon")
        if lastBox then
            GameObject.DestroyImmediate(lastBox.gameObject)
        end

        local size = self:CalculateTotalBounds(go)
        local selCollider = go:GetComponent(typeof(CS.UnityEngine.BoxCollider))
        if Util:IsNil(selCollider) then
            selCollider = go:AddComponent(typeof(CS.UnityEngine.BoxCollider))
            -- local size = self:CalculateTotalBounds(go)
            selCollider.size = size
            selCollider.isTrigger = true
        end

        local box = self:CreateCubeBox(size)
        box.gameObject:SetActive(true)
        box.transform:SetParent(go.transform)

        box.transform.localScale = Vector3(size.x + 0.2, size.y + 0.1, size.z + 0.2)
        box.transform.localPosition = Vector3(0, 0, 0)
        box.transform.localEulerAngles = Vector3(0, 0, 0)
        self.selectedBoxMap[guid] = box

        -- 选中就从map里删了 TODO 后面改一下
        -- self.PlaceMap[guid] = nil

        local moveControler = go.gameObject:GetComponent(typeof(CS.UnityEngine.CharacterController))
        if Util:IsNil(moveControler) and self.usePhysics then
            moveControler = go.gameObject:AddComponent(typeof(CS.UnityEngine.CharacterController))
            -- 坡度0
            moveControler.slopeLimit = 0
            -- height
            moveControler.height = size.y
            -- radius
            moveControler.radius = math.min(size.x, size.z) / 2
            -- center
            moveControler.center = Vector3(0, size.y / 2, 0)

            go.gameObject.layer = Layer_enum.selectedLayer
        end
    end

    if self:IsMultiSelectMode() then
        if info.locked == 1 then
            self:ShowTips("多选模式下，锁定状态的物体无法选中")
            return
        end
        selectGo(go, guid, info)
    else -- 单选模式
        -- 先把前面的选中列表清空了
        for i, info in ipairs(self.selectedList) do
            local guid = info.guid
            local go = self.goParent:Find(guid)
            if go then
                self:RemoveSelection(go, info)
            end
        end

        selectGo(go, guid, info)
    end
    self:OpenEditorGmView(#self.selectedList > 0)

    -- self:FurnitureCostEvent()

    -- 检查是否是运动器类型，如果是则打开参数编辑面板，如果不是则关闭
    self:CheckAndShowMoverEditPanel()

    if self:IsMultiSelectMode() or self.muti_listView.gameObject.activeSelf then
        self.shouldRefreshMutiList = true
    end
end

-- 取消选中
function UGCEditor:RemoveSelection(go, info)

    if Util:IsNil(go) then
        return
    end

    local guid = go.name
    if not self.selectedMap[guid] then
        return
    end

    self.selectedMap[guid] = nil
    for i, v in ipairs(self.selectedList) do
        if v.guid == guid then
            table.remove(self.selectedList, i)
            break
        end
    end

    go.transform:SetParent(self.goParent)
    go.gameObject.layer = Layer_enum.furnitureLayer

    self.PlaceMap[guid] = {
        uaddress = info.uaddress,
        id = info.id,
        guid = info.guid,
        cost = info.cost,
        scale = info.scale,
        x = self:_GetPreciseDecimal(go.transform.position.x, 2),
        y = self:_GetPreciseDecimal(go.transform.position.y, 2),
        z = self:_GetPreciseDecimal(go.transform.position.z, 2),
        r = self:_GetPreciseDecimal(go.transform.localEulerAngles.y, 2),
        gameType = info.gameType,
        mover_type = info.mover_type,
        mover_id = info.mover_id,
        mover_attributes = info.mover_attributes,
        jump_speed = info.jump_speed or ((info.mover_attributes and info.mover_attributes["jump_speed.def"]) or nil),
        jump_power = info.jump_power or ((info.mover_attributes and info.mover_attributes["jump_power.def"]) or nil),
        jump_angle = info.jump_angle or ((info.mover_attributes and info.mover_attributes["jump_angle.def"]) or nil),
        trans_speed = info.trans_speed or ((info.mover_attributes and info.mover_attributes["trans_speed.def"]) or nil),
        speed_duration = info.speed_duration or
            ((info.mover_attributes and info.mover_attributes["speed_duration.def"]) or nil),
        locked = info.locked and info.locked or 0,
        img = info.img,
        level = info.level
    }

    -- 如果是运动器，取消画线
    if info.mover_type == Move_Type.Jump or info.mover_type == Move_Type.Shoot then
        CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:DrawMoveLine(info.mover_id, false)
    end

    local collider = go:GetComponent(typeof(CS.UnityEngine.BoxCollider))
    if Util:IsNil(collider) then
        collider = go:AddComponent(typeof(CS.UnityEngine.BoxCollider))
        local size = self:CalculateTotalBounds(go)
        collider.size = size
        if not self.colliderList then
            self.colliderList = {}
        end
        table.insert(self.colliderList, collider)
    end

    local box = self.selectedBoxMap[guid]
    if box then
        GameObject.DestroyImmediate(box)
        self.selectedBoxMap[guid] = nil
    end

    local moveControler = go.gameObject:GetComponent(typeof(CS.UnityEngine.CharacterController))
    if not Util:IsNil(moveControler) then
        GameObject.DestroyImmediate(moveControler)
    end

    self:OpenEditorGmView(#self.selectedList > 0)

    self.isDirty = true
    -- self:FurnitureCostEvent()

    self:CheckAndShowMoverEditPanel()

    if info.gameType and App:IsHome() then
        self:SpecialProp(go, info.gameType, info.id)
        -- 检测开启挑战

        if not self.gameStart and not self.ShowGameTips then
            self.ShowGameTips = true
            self:ShowAlert("",
                "您已放置" .. self.platformText .. "挑战道具，是否在家园开启" .. self.platformText ..
                    "挑战？不开启场景内的宝箱和旗帜不设有答题功能。", function()
                    self.game_startBtn.onClick:Invoke()
                end, function()

                end, "暂不开启", "立即开启")
        end

    end

    if self:IsMultiSelectMode() or self.muti_listView.gameObject.activeSelf then
        self.shouldRefreshMutiList = true
    end

    -- if self.gameStart then
    self:RefreshGameUI()
    -- end

    if not self._isClearingSelection then
        self:TrackAutoClosedCheck(guid)
        self:CheckTrackOverlap()
    end
end
-- 放下所有选中
function UGCEditor:ClearAllSelection()

    if #self.selectedList == 0 then
        return
    end

    -- 预先收集当前选中的赛道 guid，用于批量吸附
    local trackGuids = {}
    for i, info in pairs(self.selectedMap) do
        if info and info.gameType == Game_Type.Track then
            table.insert(trackGuids, info.guid)
        end
    end

    self._isClearingSelection = true
    for i, info in pairs(self.selectedMap) do
        local guid = i
        local go = self.goParent:Find(guid)
        if go then
            self:RemoveSelection(go, info)
        end
    end
    self._isClearingSelection = false

    -- 批量放下后，进行一次整体赛道吸附和重叠检测
    if #trackGuids > 1 then
        self:TrackGroupAutoClosedCheck(trackGuids)
    elseif #trackGuids == 1 then
        self:TrackAutoClosedCheck(trackGuids[1])
    end
    self:CheckTrackOverlap()
end

function UGCEditor:SaveSelectionInfo()
    for i, info in pairs(self.selectedMap) do
        local guid = i
        local go = self.goParent:Find(guid)

        self.PlaceMap[info.guid] = {
            uaddress = info.uaddress,
            id = info.id,
            guid = info.guid,
            cost = info.cost,
            scale = info.scale,
            x = self:_GetPreciseDecimal(go.transform.position.x, 2),
            y = self:_GetPreciseDecimal(go.transform.position.y, 2),
            z = self:_GetPreciseDecimal(go.transform.position.z, 2),
            r = self:_GetPreciseDecimal(go.transform.localEulerAngles.y, 2),
            gameType = info.gameType,
            mover_type = info.mover_type,
            mover_id = info.mover_id,
            mover_attributes = info.mover_attributes,
            jump_speed = info.jump_speed or ((info.mover_attributes and info.mover_attributes["jump_speed.def"]) or nil),
            jump_power = info.jump_power or ((info.mover_attributes and info.mover_attributes["jump_power.def"]) or nil),
            jump_angle = info.jump_angle or ((info.mover_attributes and info.mover_attributes["jump_angle.def"]) or nil),
            trans_speed = info.trans_speed or
                ((info.mover_attributes and info.mover_attributes["trans_speed.def"]) or nil),
            speed_duration = info.speed_duration or
                ((info.mover_attributes and info.mover_attributes["speed_duration.def"]) or nil),
            locked = info.locked and info.locked or 0,
            img = info.img,
            level = info.level
        }
    end
end

function UGCEditor:RefreshMutiList()
    if not self.shouldRefreshMutiList then
        return
    end
    self.shouldRefreshMutiList = false
    self.muti_listView.gameObject:SetActive(true)

    self.muti_list_btn.gameObject:GetComponent(typeof(CS.UnityEngine.UI.Image)).sprite = self.muti_listView.gameObject
                                                                                             .activeSelf and
                                                                                             self.selectSprite or
                                                                                             self.normalSprite
    self:Fire("EVENT_BAG_SHOW_HIDE", {
        isShow = false
    })

    self:RefreshMutiListData()
end

function UGCEditor:RefreshMutiListData()
    self.muti_empty.gameObject:SetActive(#self.selectedList == 0)
    -- 清空scrollview的content
    local content = self.muti_list_scrollview.content
    for i = content.transform.childCount - 1, 0, -1 do
        GameObject.DestroyImmediate(content.transform:GetChild(i).gameObject)
    end

    for i, info in ipairs(self.selectedList) do

        local item = GameObject.Instantiate(self.item.gameObject, content.transform).transform
        local img = info.img and info.img ~= "" and ("https://static0.xesimg.com" .. info.img) or nil
        local level = info.level or 10

        local clickBtn = item:GetComponent(typeof(CS.UnityEngine.UI.Button))
        self.commonService:AddEventListener(clickBtn, "onClick", function()
            -- 定位 重新获取一下index，因为前面的可能被删掉了
            local index = i
            for j = 1, #self.selectedList do
                if self.selectedList[j] == info then
                    index = j
                    break
                end
            end
            self:LocateSelectedGo(index)
        end)

        local closeBtn = item:Find("clostBtn"):GetComponent(typeof(CS.UnityEngine.UI.Button))
        self.commonService:AddEventListener(closeBtn, "onClick", function()
            local go = self.goParent:Find(info.guid)
            self:RemoveSelection(go, info)
        end)

        if img then
            local image = item:Find("iconImage"):GetComponent(typeof(CS.UnityEngine.UI.Image))
            self.httpService:LoadNetWorkTexture(img .. "?x-oss-process=image/resize,w_108,h_108/quality,q_80",
                function(sprite)
                    if not sprite then
                        return
                    end
                    image.sprite = sprite
                end)
        end

        local level40 = item:Find("level/40")
        local level30 = item:Find("level/30")
        local level20 = item:Find("level/20")
        local level10 = item:Find("level/10")
        level40.gameObject:SetActive(level == 40)
        level30.gameObject:SetActive(level == 30)
        level20.gameObject:SetActive(level == 20)
        level10.gameObject:SetActive(level == 10)

    end
end

-- 打开选中物体的操作面板，isOpen为true时打开，为false时关闭
function UGCEditor:OpenEditorGmView(isOpen)
    -- if isOpen == self.moveView.gameObject.activeSelf then
    --     return
    -- end
    self.moveView.gameObject:SetActive(isOpen)
    self.commitView.gameObject:SetActive(not isOpen)

    self.copyBtn.interactable = isOpen

    self:RefreshOpLockState()
end

-- 删除手中的物体
function UGCEditor:DeleteSelectedGo()

    self.lastSelected = {}

    for i = #self.selectedList, 1, -1 do
        local info = self.selectedList[i]
        local go = self.goParent:Find(info.guid)
        if SpecialGuid[info.guid] ~= nil then -- 特殊道具不能删除 取消选中即可
            self:RemoveSelection(go, info)
        else
            GameObject.DestroyImmediate(go.gameObject)
            self.PlaceMap[info.guid] = nil
        end
        self.lastSelected[info.guid] = true
    end

    self.selectedList = {}
    self.selectedMap = {}
    self.selectedBoxMap = {}
    self.colliderList = {}

    self:OpenEditorGmView(false)

    self.isDirty = true

    self:FurnitureCostEvent()

    -- 触发一下点击事件
    if self.muti_listView.gameObject.activeSelf then
        self.muti_list_btn.onClick:Invoke()
    end

    self:PushSnapshot()

    -- if self.gameStart then
    self:RefreshGameUI()
    -- end

    self:CheckTrackOverlap()
end

function UGCEditor:RaycastTrigger()
    if CS.UnityEngine.Camera.main == nil then
        return
    end

    if self.shotScreenView.gameObject.activeSelf then
        return
    end

    ---触摸按下
    -- local touching = Input.GetMouseButtonDown(0)

    -- if touching then

    -- end

    if self.uiPointDown then
        return
    end

    local position = Input.mousePosition

    position = position * rt_scale

    local furnitureLayer = 1 << Layer_enum.furnitureLayer
    local selectedLayer = 1 << Layer_enum.selectedLayer

    local mask = (furnitureLayer) | (selectedLayer)
    -- local mask = (furnitureLayer)

    self:Raycast(position, mask, function(hit)
        if not hit then
            g_Log(self.TAG, "点击到空白区域，清空选中列表")
            -- 点到空白区域，则清空选中列表
            self:ClearAllSelection()
        end
    end)
end

function UGCEditor:GetNearGm(hits)
    if hits.Length == 0 then
        return nil
    end

    local min = 9999

    local pos = Camera.main.transform.position

    local gm = nil
    for i = 0, hits.Length - 1, 1 do
        local pos2 = hits[i].collider.gameObject.transform.position
        local dis = Vector3.Distance(pos, pos2)
        if dis < min then
            min = dis
            gm = hits[i].collider.gameObject
        end
    end

    return gm
end

-- 处理点击事件
function UGCEditor:Raycast(position, layerMask, callback)
    local ray = Camera.main:ScreenPointToRay(position)
    local Physics = CS.UnityEngine.Physics
    if (Physics.Raycast(ray) == false) then
        if callback then
            callback(false)
        end
        return;
    end

    if not layerMask then
        if callback then
            callback(false)
        end
        return
    end

    -- 只和editorLayer和unlockLayer层的物体射线检测
    local hits = Physics.RaycastAll(ray, 1000, layerMask)

    if hits.Length == 0 then
        if callback then
            callback(false)
        end
        return nil
    end

    local gm = self:GetNearGm(hits)
    if not gm then
        if callback then
            callback(false)
        end
        return
    end

    -- local hit = hits[0]
    -- local gm = hit.collider.gameObject

    if gm.layer == Layer_enum.furnitureLayer or gm.layer == Layer_enum.selectedLayer then

        local guid = gm.name
        local info = self.PlaceMap[guid]

        if info then
            g_Log(self.TAG, "点到了家具", gm.name, table.dump(info))

            self:AddSelection(gm, info)

            if callback then
                callback(true)
            end
        else

            -- 再次点击相同选中物体，放下物体
            if self.selectedMap[guid] then
                self:RemoveSelection(gm, self.selectedMap[guid])
                if callback then
                    callback(true)
                end
                return
            end
            if callback then
                callback(false)
            end
        end

    end

end

function UGCEditor:EnterEditor()

    if not App.IsStudioClient then
        if self.auditing then
            CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("上传中，请稍后再试", 3)
            return
        end
    end

    -- 埋点统计次数
    self.sno_undoCount = 0
    self.sno_redoCount = 0
    self.sno_copyCount = 0
    self.sno_chooseCount = 0
    self.sno_locateCount = 0

    self.ShowGameTips = false

    self.isEditing = true
    self.openView.gameObject:SetActive(true)
    self.commitView.gameObject:SetActive(true)

    self:LockCamera(true)

    -- 隐藏摇杆等UI
    self.hideJumpId = self.joystickService:setHidenJumpWithID()
    self.hideJoyId = self.joystickService:setHidenJoyWithID()
    self.hideMicId = self.uiService:SetHidenVoiceBtnWithID()
    self.observerService:Fire("EVETN_MAIN_PANEL_HIDE")

    -- self.cube.gameObject:SetActive(true)

    self.observerService:Fire("ABC_ZONE_SHOW_HOME_DRESS", {
        type = self.BagType,
        max = MaxPlace[self.UGCSourceType]
    })

    self:EnableFurnitureBoxCollider(true)

    self:SetAllAvatarVisable(false)

    if self.lastFailed_location and self.lastFailed_location ~= "" then
        self.observerService:Fire("COMMON_ALERT_SHOW", {
            title = "",
            content = "是否从上次发布内容开始编辑",
            buttons = {{
                text = "否"
            }, {
                text = "开始编辑"
            }},
            callback = function(index)
                if index == 2 then
                    self.isDirty = true
                    self.resetDirty = true
                    self:ShowLoading(true)
                    self.commonService:StartCoroutine(function()
                        self.commonService:Yield(self.commonService:WaitUntil(function()
                            return self.isAppling == false
                        end))
                        -- 记录应用草稿之前家具花费
                        local usedCostByMap = {}
                        for i, v in pairs(self.PlaceMap) do
                            if not usedCostByMap[v.id] then
                                usedCostByMap[v.id] = 0
                            end
                            usedCostByMap[v.id] = usedCostByMap[v.id] + 1
                        end
                        self:Fire("Update_UsedCostByMap", {
                            usedCostByMap = usedCostByMap
                        })
                        self:FurnitureCostEvent()

                        self.courtyard_location = self.lastFailed_location
                        self:RequestPlaceData(function()
                            self:FurnitureCostEvent() -- 刷新一下使用数量   
                            self:ShowLoading(false)
                        end, true)
                        self.lastFailed_location = nil
                    end)

                    self:ClearLocalCache()
                else
                    self.lastFailed_location = nil

                    self:LoadFromLocal(function(isLoad)
                        if not isLoad then
                            self:ClearLocalCache(function()
                                local usedCostByMap = {}
                                for i, v in pairs(self.PlaceMap) do
                                    if not usedCostByMap[v.id] then
                                        usedCostByMap[v.id] = 0
                                    end
                                    usedCostByMap[v.id] = usedCostByMap[v.id] + 1
                                end
                                self:Fire("Update_UsedCostByMap", {
                                    usedCostByMap = usedCostByMap
                                })
                                self:FurnitureCostEvent()
                            end)
                        end
                    end)
                end

            end
        })
    else
        self:LoadFromLocal(function(isLoad)
            if not isLoad then
                self:ClearLocalCache(function()
                    local usedCostByMap = {}
                    for i, v in pairs(self.PlaceMap) do
                        if not usedCostByMap[v.id] then
                            usedCostByMap[v.id] = 0
                        end
                        usedCostByMap[v.id] = usedCostByMap[v.id] + 1
                    end
                    self:Fire("Update_UsedCostByMap", {
                        usedCostByMap = usedCostByMap
                    })
                    self:FurnitureCostEvent()
                end)
            end
        end)
    end

    self:Report("park_editor_enter", "进入庭院摆放", "", {})

    self.observerService:Fire("EVENT_EDITOR_MODE_CHANGED", {
        isEditor = true
    })

    self:ClearWeakRef()

    if self.gameStart then
        self:RefreshGameUI()
    end

    self.uiService:HideOperationArea()

    self.undoStack = {}
    self.redoStack = {}
    self.editCount = 0
    self:RefreshUndoState()
    self.lastSnapshot = self:GetHomeJsonData()

    local height = 0.2
    if self.UGCSourceType == UGCSource.IsLand then
        -- height = 152.2
    end
    self:Fire("open_edit_grid", {
        isOpen = true,
        height = height
    })

    -- 启动自动保存（每10分钟一次）
    if self.autoSaveCor then
        self.autoSaveCor:Stop()
        self.autoSaveCor = nil
    end
    self.autoSaveCor = self.commonService:StartCoroutine(function()
        while self.isEditing do
            self.commonService:YieldSeconds(600)
            if not self.isEditing then
                break
            end
            self:SaveToLocal(function(ok)
                if ok then
                    self:ShowTips("已自动保存草稿")
                end
            end)
        end
    end)

    g_Log("UGC_EDITOR_ENTER_EDITOR1")
    self.commonService:DispatchAfter(0.1, function()
        g_Log("UGC_EDITOR_ENTER_EDITOR2")
        self.observerService:Fire("UGC_EDITOR_ENTER_EDITOR", {
            obj = self
        })
    end)

end

function UGCEditor:EndEditor()

    self.isEditing = false

    -- 退出编辑时退出鸟瞰模式并恢复相机
    if self.camera_mode == Camera_Mode.BirdEye then
        self:SwitchCameraMode()
    end

    self.openView.gameObject:SetActive(false)

    if self.extendMutiSelectMenu then
        self.multiBtn.onClick:Invoke()
    end
    if self.muti_listView.gameObject.activeSelf then
        self.muti_list_btn.onClick:Invoke()
    end

    self:LockCamera(false)
    -- self.selfAvatar.joystick:SetLookAt(self.selfAvatar.LookRotation.transform)

    self.joystickService:setVisibleJumpWithID(self.hideJumpId)
    self.joystickService:setVisibleJoyWithID(self.hideJoyId)
    self.uiService:SetVisibleHidenVoiceBtnWithID(self.hideMicId)

    self.hideJumpId = nil
    self.hideJoyId = nil
    self.hideMicId = nil
    self.observerService:Fire("EVETN_MAIN_PANEL_SHOW")

    self.cube.gameObject:SetActive(false)

    self.observerService:Fire("ABC_ZONE_HIDE_HOME_DRESS")

    self:EnableFurnitureBoxCollider(false)

    self.observerService:Fire("NEXT_QUESTION_HIDE")

    self:SetAllAvatarVisable(true)

    self.observerService:Fire("EVENT_EDITOR_MODE_CHANGED", {
        isEditor = false
    })

    self.uiService:ShowOperationArea()

    self:Fire("open_edit_grid", {
        isOpen = false
    })

    self:Report("home_edit_info", "退出编辑", "", {
        param_one = self.editCount
    })

    self:Report("home_quash_num", "撤销次数", "", {
        param_one = self.sno_undoCount
    })
    self:Report("home_restore_num", "还原次数", "", {
        param_one = self.sno_redoCount
    })
    self:Report("home_copy_num", "复制次数", "", {
        param_one = self.sno_copyCount
    })
    self:Report("home_choice_num", "多选次数", "", {
        param_one = self.sno_chooseCount
    })
    self:Report("home_positioning_num", "定位次数", "", {
        param_one = self.sno_locateCount
    })

    -- 停止自动保存
    if self.autoSaveCor then
        self.autoSaveCor:Stop()
        self.autoSaveCor = nil
    end

end

--- 向编辑器中添加一个道具实例
--- @param uaddress string 资源地址（资源路径或uAddress）
--- @param id number 道具ID（家具/物品ID）
--- @param cost number 道具消耗数量（默认为1）
--- @param scale number 道具缩放比例（默认为1）
--- @param gameType number|nil 游戏类型（可选参数，区分不同玩法类型，如竞速、竞答等）
--- @param mover_type number|nil 运动器类型（可选参数，对应特定动态装置类型）
--- @param mover_attributes table|string|nil 运动器属性（table或支持解码的json字符串，存储运动特性）
--- @param img string|nil 道具图片（可选，资源icon url）
--- @param level number|nil 等级（可选，未必使用）
--- @param pos table|nil 放置坐标位置（可选参数）
--- @param noSelect boolean|nil 添加后是否不选中，默认false（可选参数）
--- @param callback function|nil 回调，参数形式 callback(go, info)（可选参数）
function UGCEditor:AddProp(uaddress, id, cost, scale, gameType, mover_type, mover_attributes, img, level, pos, noSelect,
    callback)

    if not cost then
        cost = 1
    end

    if not scale then
        scale = 1
    end

    if scale <= 0 then
        scale = 1
    end

    self.moveView.gameObject:SetActive(true)
    self.commitView.gameObject:SetActive(false)

    self:ShowLoading(true)
    self:LoadPrefab(uaddress, function(go)
        self:ShowLoading(false)
        if not go then
            return
        end

        go.transform:SetParent(self.goParent)

        local selectCount = #self.selectedList

        local autoClosedGuid = nil
        if selectCount == 1 and self.selectedList[1].gameType == Game_Type.Track and gameType == Game_Type.Track then
            autoClosedGuid = self.selectedList[1].guid
        end

        if selectCount > 0 then
            self._notCheckTrackClosed = true
            self:ClearAllSelection()
            self._notCheckTrackClosed = false
        end

        local guid = self:GetGuid()
        go.name = guid

        local info = {
            uaddress = uaddress, -- 资源地址
            id = id, -- 家具id
            guid = guid, -- 摆放guid
            cost = cost, -- 使用数量
            scale = scale, -- 缩放
            gameType = gameType, -- 游戏类型
            mover_type = mover_type, -- 运动器类型
            mover_attributes = mover_attributes, -- 运动器属性
            jump_speed = (mover_attributes and mover_attributes["jump_speed.def"]) or nil,
            jump_power = (mover_attributes and mover_attributes["jump_power.def"]) or nil,
            jump_angle = (mover_attributes and mover_attributes["jump_angle.def"]) or nil,
            trans_speed = (mover_attributes and mover_attributes["trans_speed.def"]) or nil,
            speed_duration = (mover_attributes and mover_attributes["speed_duration.def"]) or nil,
            locked = 0, -- 锁定状态
            img = img,
            x = self:_GetPreciseDecimal(go.transform.position.x, 2),
            y = self:_GetPreciseDecimal(go.transform.position.y, 2),
            z = self:_GetPreciseDecimal(go.transform.position.z, 2),
            r = self:_GetPreciseDecimal(go.transform.localEulerAngles.y, 2),
            level = level
        }
        self:AddSelection(go, info)

        self.copyBtn.interactable = true

        local boxGo = self.selectedBoxMap[guid]

        local cameraForward = Camera.main.transform.forward
        local cameraDown = Vector3.down
        local cameraPosition = Camera.main.transform.position + cameraDown * 2
        local desiredPosition = cameraPosition + cameraForward * 8

        if pos then
            -- 打个射线 碰到第一个物体 设置desiredPosition（XLua下反射调用 Raycast(Ray, out RaycastHit, float, int)）
            pos = pos * rt_scale
            local ray = Camera.main:ScreenPointToRay(pos)
            if not self._raycastFunc then
                local physicsType = typeof(CS.UnityEngine.Physics)
                local typeArray = CS.System.Array.CreateInstance(typeof(CS.System.Type), 4)
                typeArray[0] = typeof(CS.UnityEngine.Ray)
                typeArray[1] = typeof(CS.UnityEngine.RaycastHit):MakeByRefType()
                typeArray[2] = typeof(CS.System.Single)
                typeArray[3] = typeof(CS.System.Int32)
                local methodInfo = physicsType:GetMethod("Raycast", typeArray)
                self._raycastFunc = xlua.tofunction(methodInfo)
            end
            local layerMask = CS.UnityEngine.LayerMask.GetMask("Default")
            local hasHit, hitInfo = self._raycastFunc(ray, 1000, layerMask)
            if hasHit and hitInfo then
                desiredPosition = hitInfo.point
            end
        end

        desiredPosition.y = math.min(self.Y_MAX, math.max(self.Y_MIN, desiredPosition.y))

        local w = (boxGo.transform.localScale.x * go.transform.localScale.x) / 2
        local h = (boxGo.transform.localScale.z * go.transform.localScale.z) / 2
        -- 需要校验下desiredPosition 是否在合法范围内
        desiredPosition = self:FindNearestLegalPosition(desiredPosition, w, h)

        -- desiredPosition的y值需要是向上移动的move_step整数倍
        desiredPosition.y = math.ceil((desiredPosition.y - self.Y_MIN) / move_step) * move_step + self.Y_MIN

        go.transform.position = desiredPosition
        go.transform.localScale = Vector3(scale, scale, scale)
        go.transform.localEulerAngles = Vector3(0, 180, 0)

        info.x = self:_GetPreciseDecimal(go.transform.position.x, 2)
        info.y = self:_GetPreciseDecimal(go.transform.position.y, 2)
        info.z = self:_GetPreciseDecimal(go.transform.position.z, 2)
        info.r = self:_GetPreciseDecimal(go.transform.localEulerAngles.y, 2)

        if info.mover_type == Move_Type.Jump then
            info.jump_speed = (info.mover_attributes and info.mover_attributes["jump_speed.def"]) or nil
            self:Report("editor_upload_failed", "添加运动器", "", {
                param_one = info.mover_type
            })
        elseif info.mover_type == Move_Type.Shoot then
            info.jump_power = (info.mover_attributes and info.mover_attributes["jump_power.def"]) or nil
            info.jump_angle = (info.mover_attributes and info.mover_attributes["jump_angle.def"]) or nil
            self:Report("editor_upload_failed", "添加运动器", "", {
                param_one = info.mover_type
            })
        elseif info.mover_type == Move_Type.Trans then
            info.trans_speed = (info.mover_attributes and info.mover_attributes["trans_speed.def"]) or nil
            self:Report("editor_upload_failed", "添加运动器", "", {
                param_one = info.mover_type
            })
        elseif info.mover_type == Move_Type.Speed then
            info.speed_duration = (info.mover_attributes and info.mover_attributes["speed_duration.def"]) or nil
            self:Report("editor_upload_failed", "添加运动器", "", {
                param_one = info.mover_type
            })
        end

        self.PlaceMap[guid] = info

        self:RefreshGameUI()

        self:FurnitureCostEvent()

        -- TODO如果当前选中一个未拼接完成的赛车赛道，拖进来的也是赛道就自动吸附到对应的位置上
        if autoClosedGuid then
            self:TrackAutoToClosed(autoClosedGuid, guid)
        end
        self:PushSnapshot()

        if callback then
            callback(go, info)
        end

        if noSelect then
            self:ClearAllSelection()
        end

    end)

end

function UGCEditor:GuideToNextQuestion()

    self:ShowPropXrayEffect(self.gameChallenging)

    if not self.gameChallenging then
        self.arrowEffect.gameObject:SetActive(false)
        self.nearestGo = nil
        return
    end

    local avatar = self.selfAvatar.VisElement.transform
    local targetNode = avatar:Find("arrow")
    if not targetNode then
        self.arrowEffect.transform:SetParent(avatar)
        self.arrowEffect.name = "arrow"
        self.arrowEffect.transform.localPosition = {
            x = 0,
            y = 0.1,
            z = 0
        }
        self.arrowEffect.transform.localScale = {
            x = 0.4,
            y = 0.4,
            z = 0.4
        }
    end

    self.arrowEffect.gameObject:SetActive(true)

    -- 先找题版,再找终点
    local nearestDist = math.huge
    local nearestGo = nil

    -- 优先遍历找题版
    for i, v in ipairs(self.game_question_list) do
        if v.gameType == Game_Type.Question then
            local go = self.goParent:Find(v.guid)
            if not Util:IsNil(go) and go.gameObject.activeSelf then
                local dist = Vector3.Distance(avatar.position, go.position)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestGo = go
                end
            end
        end
    end

    -- 如果没找到题版,再找终点
    if not nearestGo then
        for i, v in ipairs(self.game_question_list) do
            if v.gameType == Game_Type.End then
                local go = self.goParent:Find(v.guid)
                if not Util:IsNil(go) and go.gameObject.activeSelf then
                    local dist = Vector3.Distance(avatar.position, go.position)
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestGo = go
                    end
                end
            end
        end
    end

    if nearestGo then
        self.nearestGo = nearestGo
    end
end

function UGCEditor:ShowPropXrayEffect(isShow)

    if self.ShowXray == isShow then
        return
    end

    self.ShowXray = isShow

    for i, v in ipairs(self.game_question_list) do
        local go = self.goParent:Find(v.guid)
        if not Util:IsNil(go) then
            if isShow then
                self:ShowXrayEffect(go.gameObject, CS.UnityEngine.Color.yellow)
            else
                self:HideXrayEffect(go.gameObject)
            end
        end
    end
end

function UGCEditor:Tick()
    -- if App.IsStudioClient then
    --     --Studio环境模拟
    --     self:HandlePinchZoom()
    -- end

    if self.shouldRefreshMutiList then
        self:RefreshMutiList()
    end

    if Util:IsNil(self.nearestGo) or not self.gameChallenging then
        return
    end

    if not self.lookAtTarget then
        self.lookAtTarget = Vector3.zero
    end

    local avatar = self.selfAvatar.VisElement.transform
    self.lookAtTarget.x = self.nearestGo.position.x
    self.lookAtTarget.y = avatar.position.y -- 保持与avatar同样的y值
    self.lookAtTarget.z = self.nearestGo.position.z

    self.arrowEffect.transform:LookAt(self.lookAtTarget)
end

function UGCEditor:ShowXrayEffect(go, color, isFront)
    local outlinable = go:GetComponent(typeof(CS.EPOOutline.Outlinable))

    if outlinable == nil then
        outlinable = go:AddComponent(typeof(CS.EPOOutline.Outlinable))
        outlinable.FrontParameters.Enabled = false
        outlinable.BackParameters.Enabled = false
        if self.InterlacedShader == nil then
            self.InterlacedShader = CS.UnityEngine.Resources.Load("Easy performant outline/Shaders/Fills/Interlaced");
        end
        outlinable.enabled = false
    end

    -- 根据 isFront 切换渲染样式
    if isFront then
        -- 正面描边/填充
        outlinable.RenderStyle = 1 -- Front
        outlinable.FrontParameters.Enabled = true
        outlinable.BackParameters.Enabled = false
        outlinable.FrontParameters.FillPass.Shader = self.InterlacedShader
        local c = color or CS.UnityEngine.Color.green
        outlinable.FrontParameters.Color = c
        outlinable.FrontParameters.FillPass:SetColor("_PublicColor", c)
        outlinable.FrontParameters.FillPass:SetColor("_PublicGapColor", CS.UnityEngine.Color.clear)
    else
        -- 默认XRay：背面填充
        outlinable.RenderStyle = 2 -- Back
        outlinable.FrontParameters.Enabled = false
        outlinable.BackParameters.Enabled = true
        outlinable.BackParameters.FillPass.Shader = self.InterlacedShader
        local c = color or CS.UnityEngine.Color.green
        outlinable.BackParameters.Color = c
        outlinable.BackParameters.FillPass:SetColor("_PublicColor", c)
        outlinable.BackParameters.FillPass:SetColor("_PublicGapColor", CS.UnityEngine.Color.clear)
    end

    -- 使用按位或运算符组合两种渲染器类型
    local renderMode = CS.EPOOutline.RenderersAddingMode.SkinnedMeshRenderer |
                           CS.EPOOutline.RenderersAddingMode.MeshRenderer
    outlinable:AddAllChildRenderersToRenderingList(renderMode)

    outlinable.enabled = true
end

function UGCEditor:HideXrayEffect(go)
    local outlinable = go:GetComponent(typeof(CS.EPOOutline.Outlinable))
    if outlinable then
        outlinable.enabled = false
    end
end

function UGCEditor:SpecialProp(go, gameType, id)
    -- 给go节点加个子节点空GameObject并且添加一个boxCollider
    -- 判断下如果有这个名字的节点 不创建了

    if not gameType then
        return
    end

    if not go then
        return
    end

    if not id then
        return
    end

    if gameType == Game_Type.Track then
        return
    end

    if HOME_CONFIG_INFO.MapType then
        return
    end

    local child = go.transform:Find("SpecialProp")
    if not Util:IsNil(child) then
        self:RefreshGameUI()
        return
    end

    -- 创建一个Cube
    -- local child = GameObject.CreatePrimitive(CS.UnityEngine.PrimitiveType.Cube)

    child = GameObject("SpecialProp")
    child.transform:SetParent(go.transform)
    child.transform.localPosition = Vector3.zero
    child.transform.localScale = Vector3.one
    child.transform.localEulerAngles = Vector3.zero
    -- 先获取 没有才添加
    local collider = child:GetComponent(typeof(CS.UnityEngine.BoxCollider))
    if not collider then
        collider = child:AddComponent(typeof(CS.UnityEngine.BoxCollider))
    end
    local size = self:CalculateTotalBounds(go)

    collider.size = {
        x = size.x + 0.3,
        y = size.y + 0.3,
        z = size.z + 0.3
    }
    collider.isTrigger = true

    self.colliderService:RegisterColliderEnterListener(child, function(other)
        if self.selfAvatar and other.name == self.selfAvatar.VisElement.gameObject.name then

            if not self.selfAvatar.Body.gameObject.activeSelf then
                return
            end

            if self.isAnswering then
                return
            end

            -- if not self.gameStart then
            --     return
            -- end

            local animator = go:GetComponent(typeof(CS.UnityEngine.Animator))
            if not Util:IsNil(animator) then
                -- 如果open是true就return
                if animator:GetBool("open") == true then
                    return
                end
            end

            g_Log(self.TAG, "碰到题版", os.time())

            if self.finish_game_questionCount < self.game_questionCount and gameType == Game_Type.End then
                -- 答完所有题版前不触发宝箱
                return
            end

            local func = function()

                local lastStatus = self.gameChallenging
                self:StartQuestion(function(success)

                    if lastStatus ~= self.gameChallenging then
                        -- 如果状态变了 不触发
                        return
                    end

                    if success then

                        -- local animator = go:GetComponent(typeof(CS.UnityEngine.Animator))
                        if not Util:IsNil(animator) then
                            animator:SetBool("open", true)
                            self.commonService:DispatchAfter(1.7, function()
                                if lastStatus ~= self.gameChallenging then
                                    -- 如果状态变了 不触发
                                    animator:SetBool("open", false)
                                    return
                                end

                                if self.isEditing and not self.playMode then
                                    animator:SetBool("open", false)
                                    return
                                end
                                go.gameObject:SetActive(false)
                                animator:SetBool("open", false)
                                self:GuideToNextQuestion()
                            end)
                        else
                            go.gameObject:SetActive(false)
                            self:GuideToNextQuestion()
                        end

                        self.finish_game_questionCount = self.finish_game_questionCount + 1
                        if gameType == Game_Type.Question then
                            -- 下一题

                            self.observerService:Fire("EVENT_QUESTION_FINISH", {
                                mode = self.UGCSourceType == UGCSource.IsLand and "island" or "yard",
                                Type = Game_Type.Question
                            })

                        elseif gameType == Game_Type.End then

                            if self.gameChallenging then
                                self:Report("park_game_finish", "口语挑战", "", {})
                            end

                            -- 结束

                            self.observerService:Fire("EVENT_QUESTION_FINISH", {
                                mode = self.UGCSourceType == UGCSource.IsLand and "island" or "yard",
                                Type = Game_Type.End
                            })

                        end

                        table.insert(self.weakRefArray, go)
                    else
                        self:Fire("EVENT_QUESTION_FINISH_FAILED")
                    end
                end, self.gameChallenging)
            end

            if not HOME_CONFIG_INFO.IsOwner and not self.gameChallenging and not self.showChallengeTips and
                self.gameStart then

                self:ShowAlert("", "您已触发家园" .. self.platformText .. "挑战， 是否开始挑战？",
                    function()
                        self.showChallengeTips = true
                        self.observerService:Fire("GAME_CHALLENGE_AUTO_START", {
                            callback = function()
                                func()
                            end
                        })
                    end, function()
                        self.showChallengeTips = true
                    end, "取消挑战", "开始挑战")
                return
            end

            func()

        end
    end)

    self:RefreshGameUI()
end

function UGCEditor:FindNearestLegalPosition(pos, w, h)

    if self.areaConfig then
        pos = self:FindNearestBirthPos()
        return pos
    end

    -- pos 算上宽高  需要在范围内 X_MIN X_MAX Z_MIN Z_MAX
    local minX = self.X_MIN + w
    local maxX = self.X_MAX - w
    local minZ = self.Z_MIN + h
    local maxZ = self.Z_MAX - h

    pos.x = math.min(maxX, math.max(minX, pos.x))
    pos.z = math.min(maxZ, math.max(minZ, pos.z))

    return pos
end

function UGCEditor:LockCamera(start)
    if start then

        Camera.main.transform.position = self.camera_posObj.transform.position

        local ratio = (self.camera_posObj.transform.position.y - self.CAMERA_Y_MIN) /
                          (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN)
        self.cametaSlider.value = ratio

        local x = self.camera_posObj.transform.localEulerAngles.x
        local y = self.camera_posObj.transform.localEulerAngles.y
        local z = self.camera_posObj.transform.localEulerAngles.z
        Camera.main.transform.eulerAngles = Vector3(x, y, z)
        self.selfAvatar.joystick:SetLookAt(nil)
    else
        self.selfAvatar.joystick:SetLookAt(self.selfAvatar.LookRotation.transform)
    end
end

function UGCEditor:SaveAndExit(callback)

    -- if not self.isAppling then
    --     self:EndEditor()

    --     if callback then
    --         callback()
    --     end
    --     return
    -- end

    if not self.isDirty then
        self:EndEditor()

        if callback then
            callback()
        end
        return
    end

    self:ShowLoading(true)
    self:SaveToLocal(function()
        self:RequestPlaceData(function()
            self:EndEditor()
            self:ShowLoading(false)
            if callback then
                callback()
            end
        end)
    end)

end

-- 自动保存到本地
function UGCEditor:SaveToLocal(callback)
    -- TODO调用3次保存一次
    local json = self:GetHomeJsonData()
    local compressed = self:CompressString(json)

    local type = 0
    if self.UGCSourceType == UGCSource.IsLand then
        type = 1
    else
        if HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.ShootGame then
            type = 2
        elseif HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.Free then
            type = 3
        elseif HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
            type = 4
        end
    end

    -- 保存到服务器
    local param = {
        ["home_location"] = compressed,
        ["yard_type"] = type,
        ["map_id"] = HOME_CONFIG_INFO.MapId or 0
    }

    self:HttpRequest("/v3/home/save-home-location", param, function(resp)
        g_Log(self.TAG, "save-home-location 请求成功", resp)
        local msg = self.jsonService:decode(resp)
        if msg and msg.code == 0 then
            -- 同时保存到本地作为备份
            CS.UnityEngine.PlayerPrefs.SetString(self.KEY_HOME_DATA, compressed)
            CS.UnityEngine.PlayerPrefs.Save()

            if callback then
                callback(true)
            end
        else
            -- 保存失败时仍然保存到本地
            CS.UnityEngine.PlayerPrefs.SetString(self.KEY_HOME_DATA, compressed)
            CS.UnityEngine.PlayerPrefs.Save()

            if callback then
                callback(false)
            end
        end
    end, function(res)
        g_Log(self.TAG, "save-home-location 请求失败", table.dump(res))
        -- 请求失败时仍然保存到本地
        CS.UnityEngine.PlayerPrefs.SetString(self.KEY_HOME_DATA, compressed)
        CS.UnityEngine.PlayerPrefs.Save()

        if callback then
            callback(false)
        end
    end)
end

-- 清除本地缓存
function UGCEditor:ClearLocalCache(callback)
    -- 清除本地缓存
    CS.UnityEngine.PlayerPrefs.DeleteKey(self.KEY_HOME_DATA)
    CS.UnityEngine.PlayerPrefs.Save()

    local type = 0
    if self.UGCSourceType == UGCSource.IsLand then
        type = 1
    else
        if HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.ShootGame then
            type = 2
        elseif HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.Free then
            type = 3
        elseif HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
            type = 4
        end
    end

    -- 清除服务器缓存
    local param = {
        ["yard_type"] = type,
        ["map_id"] = HOME_CONFIG_INFO.MapId or 0
    }

    self:HttpRequest("/v3/home/del-home-location", param, function(resp)
        g_Log(self.TAG, "del-home-location 请求成功", resp)
        local msg = self.jsonService:decode(resp)
        if msg and msg.code == 0 then
            g_Log(self.TAG, "服务器缓存清除成功")
            if callback then
                callback()
            end
        else
            g_Log(self.TAG, "服务器缓存清除失败", msg.msg)
        end
    end, function(res)
        g_Log(self.TAG, "del-home-location 请求失败", table.dump(res))
    end)
end

-- 从本地加载
function UGCEditor:LoadFromLocal(callback)

    local showAlert = function(compressed)
        local text = "<size=28><color=#333333>是否从上次保存内容开始编辑？ </color></size>"
        self:ShowAlert("提示", text, function()
            g_Log(self.TAG, "LoadFromLocal确定")

            local json = self:DecompressString(compressed)
            self.isDirty = true
            self.resetDirty = true
            self:ShowLoading(true)

            self.commonService:StartCoroutine(function()
                self.commonService:Yield(self.commonService:WaitUntil(function()
                    return self.isAppling == false
                end))

                -- 记录应用草稿之前家具花费
                local usedCostByMap = {}
                for i, v in pairs(self.PlaceMap) do
                    if not usedCostByMap[v.id] then
                        usedCostByMap[v.id] = 0
                    end
                    usedCostByMap[v.id] = usedCostByMap[v.id] + 1
                end
                self:Fire("Update_UsedCostByMap", {
                    usedCostByMap = usedCostByMap
                })
                self:FurnitureCostEvent()

                self:ApplyPlaceData(json, function()
                    self:ClearLocalCache()
                    self:FurnitureCostEvent() -- 刷新一下使用数量   
                    self:ShowLoading(false)
                    self.lastSnapshot = self:GetHomeJsonData()
                    callback(true)

                end, true)
            end)

        end, function()
            g_Log(self.TAG, "LoadFromLocal取消")
            callback(false)
        end)

    end

    -- 先尝试从服务器获取

    local type = 0
    if self.UGCSourceType == UGCSource.IsLand then
        type = 1
    else
        if HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.ShootGame then
            type = 2
        elseif HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.Free then
            type = 3
        elseif HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType == UGC_MAP_TYPE.KartGame then
            type = 4
        end
    end

    if self.UGCSourceType == UGCSource.Custom and not HOME_CONFIG_INFO.MapId then
        callback(false)
        return
    end

    local param = {
        ["yard_type"] = type,
        ["map_id"] = HOME_CONFIG_INFO.MapId or 0
    }

    self:HttpRequest("/v3/home/get-home-location", param, function(resp)
        g_Log(self.TAG, "get-home-location 请求成功", resp)
        local msg = self.jsonService:decode(resp)
        if msg and msg.code == 0 and msg.data and msg.data.home_location and msg.data.home_location ~= "" then
            local compressed = msg.data.home_location
            showAlert(compressed)
        else
            callback(false)
        end
    end, function(res)
        g_Log(self.TAG, "get-home-location 请求失败", table.dump(res))
        callback(false)
    end)
end

-- 请求庭院摆放数据
function UGCEditor:RequestPlaceData(callback, recordUsetByMap)

    local data = [[
        {"list":[],"version":1.0}
    ]]
    self.jsonData = data

    if self.courtyard_location and self.courtyard_location ~= '' then
        data = self:DecompressString(self.courtyard_location)
    end

    self:ApplyPlaceData(data, callback, recordUsetByMap)
end

function UGCEditor:ClearAllPlace()
    for k, v in pairs(self.PlaceMap) do
        local guid = k
        local gm = self.goParent:Find(guid)
        -- 排除出生点
        if SpecialGuid[v.id] ~= nil then
            goto continue
        end
        if gm ~= nil then
            GameObject.DestroyImmediate(gm.gameObject)
        end
        ::continue::
    end
    self.PlaceMap = {}

    for i = self.goParent.transform.childCount - 1, 0, -1 do
        local name = self.goParent.transform:GetChild(i).gameObject.name
        if SpecialGuid[name] ~= nil then
            -- TODO
        else
            GameObject.DestroyImmediate(self.goParent.transform:GetChild(i).gameObject)
        end

    end
end

function UGCEditor:ApplyPlaceData(data, callback, noFire)

    g_Log(self.TAG, "ApplyPlaceData", data)

    -- data = [[
    -- {"birthPoints":[{"scale":1,"x":-15.63,"y":1,"z":0,"birthPointType":"blue","isBirthPoint":true,"id":"birthpoint_blue","uaddress":"birthpoint_blue","cost":0,"r":0,"guid":"birthpoint_blue"},{"scale":1,"x":15.8,"y":1,"z":0,"birthPointType":"red","isBirthPoint":true,"id":"birthpoint_red","uaddress":"birthpoint_red","cost":0,"r":0,"guid":"birthpoint_red"}],"version":1,"list":[{"cost":50,"mover_attributes":{},"guid":"53438074139","r":180,"scale":1,"x":0.52,"y":0.05,"z":-3.36,"id":-2,"uaddress":"992401744180135/assets/Prefabs/M_zidanqiang_rig.prefab"},{"cost":10,"mover_attributes":{"jump_speed.def":16,"jump_speed.min":5,"jump_speed.adj":0.1,"jump_speed.max":20},"guid":"53438074140","r":180,"scale":1,"mover_type":1,"x":-1.91,"y":0.05,"z":-3.2,"id":494,"uaddress":"1051391755500450/assets/Prefabs/M_taban_top.prefab","jump_speed":16},{"cost":100,"mover_attributes":{},"guid":"53445948639","r":180,"scale":1,"mover_type":0,"x":-1.63,"y":0.05,"z":-6.66,"id":442,"uaddress":"973961740021174/assets/Prefabs/M_jinglinga.prefab"},{"cost":80,"mover_attributes":{},"guid":"54147078764","r":180,"scale":0.3,"mover_type":0,"x":1.37,"y":0.05,"z":-2.64,"id":253,"uaddress":"796201695796477/assets/Prefabs/p_yuebingbaijian.prefab"}],"gameStart":false}
    -- ]]

    local dic = self.jsonService:decode(data)
    local version = dic.version
    local list = dic.list
    self.gameStart = dic.gameStart and true or false
    if not version or not list then
        if callback then
            callback(false)
        end
        return
    end

    local birthPoints = dic.birthPoints

    if birthPoints and type(birthPoints) == "table" then
        for i, v in ipairs(birthPoints) do
            table.insert(list, v)
        end
    end

    self.isAppling = true

    local count = #list

    self:ClearAllPlace()

    self.jsonData = data

    local success = function()

        self.isAppling = false
        g_Log(self.TAG, "ApplyPlaceData succusee", data)

        if self.gameStart then
            self:GameSwitch(true)
        else
            self:GameSwitch(false)
            self:RefreshGameUI()
        end

        if callback then
            callback(true)
        end

        if not self.isEditing then
            self:EnableFurnitureBoxCollider(false)
        end
    end

    if count == 0 then
        success()
        return
    end

    local idx = 0
    local usedCostByMap = {}

    -- 先找出生点位置
    local birthPointPos = nil
    for i, v in ipairs(list) do
        if v.id == "birthpoint_blue" then
            birthPointPos = {
                x = v.x,
                y = v.y,
                z = v.z
            }

        end
    end

    -- 基于出生点区域的分区加载：先加载出生点所在区域，再加载其周围一圈的区域，最后加载其余
    local orderedList = list
    if birthPointPos then
        local birthRegionId = self:ComputeRegionId(birthPointPos.x, birthPointPos.z)
        if birthRegionId and self.RegionMap and self.RegionMap[birthRegionId] then
            local cols = self.RegionCols or 10
            local rows = self.RegionRows or 10
            local rc = self.RegionMap[birthRegionId]
            local neighborSet = {}
            -- 计算八邻域
             for dr = -1, 1 do
                for dc = -1, 1 do
                    local nr = rc.row + dr
                    local nc = rc.col + dc
                    if nr >= 1 and nr <= rows and nc >= 1 and nc <= cols then
                        local id = (nr - 1) * cols + nc
                        if not (dr == 0 and dc == 0) then
                            neighborSet[id] = true
                        end
                    end
                end
            end
            -- 重排加载顺序
            local special, first, second, third = {}, {}, {}, {}
            for _, v in ipairs(list) do
                local rid = v.region_id
                if rid == nil then
                    table.insert(special, v)
                elseif rid == birthRegionId then
                    table.insert(first, v)
                elseif neighborSet[rid] then
                    table.insert(second, v)
                else
                    table.insert(third, v)
                end
            end
            orderedList = {}
            for _, v in ipairs(special) do table.insert(orderedList, v) end
            for _, v in ipairs(first) do table.insert(orderedList, v) end
            for _, v in ipairs(second) do table.insert(orderedList, v) end
            for _, v in ipairs(third) do table.insert(orderedList, v) end
        end
    end
    
    for i, v in ipairs(orderedList) do
        if not usedCostByMap[v.id] then
            usedCostByMap[v.id] = 0
        end
        usedCostByMap[v.id] = usedCostByMap[v.id] + 1
        self:LoadData(v, function()
            idx = idx + 1
            if idx == count then
                success()
            end
        end)
    end

    if not noFire then
        self:Fire("Update_UsedCostByMap", {
            usedCostByMap = usedCostByMap
        })
    end
end

function UGCEditor:LoadData(v, callback)
    self.PlaceMap[v.guid] = {
        uaddress = v.uaddress,
        id = v.id,
        guid = v.guid,
        x = v.x,
        y = v.y,
        z = v.z,
        c = v.c,
        r = v.r,
        cost = v.cost or 1,
        scale = v.scale or 1,
        gameType = v.gameType,
        mover_type = v.mover_type,
        mover_id = v.mover_id,
        mover_attributes = v.mover_attributes,
        jump_speed = v.jump_speed,
        jump_power = v.jump_power,
        jump_angle = v.jump_angle,
        trans_speed = v.trans_speed,
        speed_duration = v.speed_duration,
        locked = v.locked and v.locked or 0,
        img = v.img,
        level = v.level
    }

    self:LoadPrefab(v.uaddress, function(go)

        -- g_Log("load ------",v.uaddress,go)

        if not go then
            callback(nil)
            return
        end

        go.name = v.guid
        go.transform:SetParent(self.goParent)
        go.layer = Layer_enum.furnitureLayer
        go.transform.position = {
            x = v.x,
            y = v.y,
            z = v.z
        }
        go.transform.localScale = Vector3(v.scale or 1, v.scale or 1, v.scale or 1)
        go.transform.localEulerAngles = Vector3(0, v.r, 0)

        if v.c and v.c ~= "" then
            local Color = require("common/colorise")
            local r, g, b = Color.hex2rgb(v.c)
            local color = CS.UnityEngine.Color(r, g, b)
            go.transform:GetComponent(typeof(CS.UnityEngine.Renderer)).material.color = color
        end

        local collider = go:GetComponent(typeof(CS.UnityEngine.BoxCollider))
        if Util:IsNil(collider) then
            collider = go:AddComponent(typeof(CS.UnityEngine.BoxCollider))
            local size = self:CalculateTotalBounds(go)
            collider.size = size
            if not self.colliderList then
                self.colliderList = {}
            end
            table.insert(self.colliderList, collider)
        end

        if v.gameType then

            self:SpecialProp(go, v.gameType, v.id)
        end

        -- 判断是否是运动器，是的话设置运动器
        if v.mover_type == Move_Type.Jump then
            local id = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:RegisterMover({
                move_object = go,
                speedY = v.jump_speed,
                speedX = 0,
                speedZ = 0
            })
            CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:startMover(id)
            v.mover_id = id
        elseif v.mover_type == Move_Type.Shoot then
            -- 获取物体的当前旋转角度
            local rotationY = go.transform.localEulerAngles.y

            -- 使用新的计算函数计算速度分量
            local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(v.jump_power, v.jump_angle, rotationY)

            -- 调用运动服务，设置弹簧板
            local id = CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:RegisterMover({
                move_object = go,
                speedY = y_speed,
                speedX = x_speed,
                speedZ = z_speed
            })
            CourseEnv.ServicesManager:GetMoveService().jumpMoveCtrl:startMover(id)
            v.mover_id = id
        elseif v.mover_type == Move_Type.Trans then
            -- 获取物体的当前旋转角度
            local rotationY = go.transform.localEulerAngles.y
            local x_speed, y_speed, z_speed = self:CalculateVelocityComponents(v.trans_speed, 0, rotationY)
            local id = CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:RegisterMover({
                move_object = go,
                speedX = x_speed,
                speedZ = z_speed
            })
            CourseEnv.ServicesManager:GetMoveService().transMoveCtrl:startMover(id)
            v.mover_id = id
        elseif v.mover_type == Move_Type.Speed then
            local id = CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:RegisterMover({
                move_object = go,
                speedTime = v.speed_duration,
                cd = 3,
                speed = 1.5
            })
            CourseEnv.ServicesManager:GetMoveService().speedMoveCtrl:startMover(id)
            v.mover_id = id
        else
        end

        callback(go)

    end)
end

local defaultMaxLoadConcurrency = 15

function UGCEditor:EnqueueLoadPrefab(uaddress, callback)
    if not self.loadQueue then
        self.loadQueue = {} -- 加载队列
        self.isLoading = false
        self.currentLoadingCount = self.currentLoadingCount or 0
        self.maxLoadConcurrency = self.maxLoadConcurrency or defaultMaxLoadConcurrency
    end

    table.insert(self.loadQueue, {
        uaddress = uaddress,
        callback = callback
    })

    -- 触发调度，填满并发额度
    self:ProcessLoadQueue()
end

function UGCEditor:ProcessLoadQueue()
    -- 如果队列为空，且没有进行中的任务，则标记空闲
    if #self.loadQueue == 0 then
        if (self.currentLoadingCount or 0) == 0 then
            self.isLoading = false
        end
        return
    end

    self.isLoading = true

    local maxConcurrency = self.maxLoadConcurrency or defaultMaxLoadConcurrency
    local inFlight = self.currentLoadingCount or 0
    local available = maxConcurrency - inFlight
    if available <= 0 then
        return
    end

    local toStart = math.min(available, #self.loadQueue)
    for i = 1, toStart do
        local current = table.remove(self.loadQueue, 1)
        self.currentLoadingCount = (self.currentLoadingCount or 0) + 1

        local function onFinish()
            self.currentLoadingCount = self.currentLoadingCount - 1
            if #self.loadQueue == 0 and self.currentLoadingCount == 0 then
                self.isLoading = false
            end
            -- 尝试继续填满并发额度
            self:ProcessLoadQueue()
        end

        if string.startswith(current.uaddress, "local://") then
            local path = string.gsub(current.uaddress, "local://", "")
            g_Log(self.TAG, "准备加载local://", path)
            local go = self.VisElement.transform.parent:Find(path)
            if go then
                local newGo = GameObject.Instantiate(go.gameObject)
                if App.ModName == "VOJyaNXRCUCNmFufyNUwww" then
                    -- 先这么判断编辑态
                    local asset = newGo.transform:Find("Asset")
                    if asset then
                        asset.gameObject.layer = Layer_enum.trackLayer
                    end
                end
                current.callback(newGo)
            else
                current.callback(nil)
            end
            onFinish()
        else
            local url, package = self:GetUrlAndPackageByUaddress(current.uaddress)

            if not url then
                current.callback(nil)
                onFinish()
            else
                App:GetService("Avatar"):LoadAvatarSkin(package, url, "", 100, function(status, pkgName)
                    if status == "success" and self:PackageValid(pkgName) then
                        local uAddress = "modules/" .. current.uaddress
                        ImportAsync(pkgName, function(p)
                            ResourceManager:LoadGameObjectWithExName(uAddress, function(gameGo)
                                if not gameGo then
                                    current.callback(nil)
                                    onFinish()
                                    return
                                end
                                local go = GameObject.Instantiate(gameGo)
                                -- g_Log(self.TAG, "加载完成~", package, url, go)
                                current.callback(go)
                                onFinish()
                            end)

                        end)
                    else
                        g_Log(self.TAG, "下载失败", status, package)
                        current.callback(nil)
                        onFinish()
                    end
                end)
            end
        end
    end
end

function UGCEditor:SetLoadQueueConcurrency(n)
    if type(n) == "number" and n >= 1 then
        self.maxLoadConcurrency = math.floor(n)
        -- 并发变更后尝试填充
        self:ProcessLoadQueue()
    end
end

function UGCEditor:LoadPrefab(uaddress, callback)

    -- g_Log(self.TAG, "准备加载0~", uaddress)

    if SpecialGuid[uaddress] ~= nil then
        local go = self.goParent.transform:Find(uaddress)
        if go then
            callback(go.gameObject)
        else
            callback(nil)
        end
        return
    end

    self:EnqueueLoadPrefab(uaddress, callback)
end

function UGCEditor:PackageValid(packageName)
    local dir = App:GetPackageCachePath(packageName)
    if dir == nil then
        return false
    end
    -- g_Log(self.TAG, "PackageValid", dir)
    return true
end

-- 收到/恢复IRC消息
-- @param key  订阅的消息key
-- @param value  消息集合体
-- @param isResume  是否为恢复消息
function UGCEditor:ReceiveMessage(key, value, isResume)
    -- TODO:

    if isResume then
        return
    end
    if key == self.PARK_DECORATE_CHANGED then
        local data = self.jsonService:decode(value[#value])

        local uid = data.uuid
        if uid == App.Uuid then
            return
        end

        self:RequestHomeInfo(function(courtyard_location)
            if courtyard_location ~= self.courtyard_location then
                self.commonService:StartCoroutine(function()

                    self.commonService:Yield(self.commonService:WaitUntil(function()
                        return self.isAppling == false
                    end))
                    self.courtyard_location = courtyard_location
                    self:RequestPlaceData(function()
                        self:NotifyGameEvent()
                    end)
                end)
            end
        end)
    end
end

---接收私聊消息
---@param key     string   私聊key
---@param message string   私聊内容
---@param from    string   私聊发送者
function UGCEditor:ReceivePeerMessage(key, message, from)
    if key == self.HOME_COURTYARD_AUDIT_RESULT then
        g_Log(self.TAG, "收到peer:", message, from)

        if not HOME_CONFIG_INFO.IsOwner then
            return
        end

        if self.isEditing then
            return
        end

        -- if not self.auditing then
        --     return
        -- end

        local data = self.jsonService:decode(message)
        if data and type(data) == "table" then

            local success = data.SUCCESS
            if success then
                -- g_Log(self.TAG, "审核通过")
            else
                g_Log(self.TAG, "审核失败1")
                self:AuditFaild(true and not self.isEditing)
            end

        end
    end
end

function UGCEditor:AuditFaild(rollback)
    -- TODO 回滚到上一次
    -- 0未提交 1审核中 2通过 3失败
    self:ShowAuditFailed()
    if rollback then
        self:RequestHomeInfo(function(courtyard_location)
            if courtyard_location ~= self.courtyard_location then
                self.commonService:StartCoroutine(function()
                    self.courtyard_location = courtyard_location
                    self.commonService:Yield(self.commonService:WaitUntil(function()
                        return self.isAppling == false
                    end))
                    self:RequestPlaceData(function()
                        self:FurnitureCostEvent() -- 刷新一下使用数量   
                        self:NotifyGameEvent()
                    end)
                end)

                self:SendMessage(self.PARK_DECORATE_CHANGED, {
                    uuid = App.Uuid
                }, 1)
            end
        end)
    end

    self:RequestAuditResult(function(lastFailed_location)
        self.lastFailed_location = lastFailed_location
        self:UpdateYardStatus() -- 标记为已读
    end)
end

function UGCEditor:ShowAuditFailed(cb)

    if not HOME_CONFIG_INFO.IsOwner then
        return
    end

    local text =
        "<size=28><color=#333333>发现您的家园布置与平台风格有一定的差异，请您重新布置一下吧！</color></size>"
    self.observerService:Fire("COMMON_ALERT_SHOW", {
        title = "上传失败",
        content = text,
        buttons = {{
            text = "知道啦"
        }},
        callback = function(index)
            if cb then
                cb()
            end
            self:UpdateYardStatus() -- 标记为已读
        end
    })
    self:Report("editor_upload_failed", "庭院摆放送审不通过", "", {})

end

-- 发送KEY-VALUE 消息 
-- @param key 自定义/协议key
-- @param body  table 消息体
function UGCEditor:SendCustomMessage(key, body)
    self:SendMessage(key, body)
end

-- 自己avatar对象创建完成
-- @param avatar 对应自己的Fsync_avatar对象
function UGCEditor:SelfAvatarCreated(avatar)
    self.selfAvatar = avatar
    if not HOME_CONFIG_INFO.IsOwner then
        return
    end

end

-- 自己avatar对象人物模型加载完成ba
-- @param avatar 对应自己的Fsync_avatar对象
function UGCEditor:SelfAvatarPrefabLoaded(avatar)
    -- TEST

end

-- avatar对象创建完成，包含他人和自己
-- @param avatar 对应自己的Fsync_avatar对象
function UGCEditor:AvatarCreated(avatar)
    table.insert(self.avatarList, avatar)
    if not self.allAvatarVisable then
        avatar.Body.gameObject:SetActive(false)
    end
end

------------------------蓝图组件相应方法---------------------------------------------
-- 是否是异步恢复如果是需要改成true
function UGCEditor:LogicMapIsAsyncRecorver()
    return false
end
-- 开始恢复方法（断线重连的时候用）
function UGCEditor:LogicMapStartRecover()
    UGCEditor.super:LogicMapStartRecover()
    -- TODO
end
-- 结束恢复方法 (断线重连的时候用)
function UGCEditor:LogicMapEndRecover()
    UGCEditor.super:LogicMapEndRecover(self)
    -- TODO
end
-- 所有的组件恢复完成
function UGCEditor:LogicMapAllComponentRecoverComplete()
end

-- 收到Trigger事件
function UGCEditor:OnReceiveTriggerEvent(interfaceId)
end
-- 收到GetData事件
function UGCEditor:OnReceiveGetDataEvent(interfaceId)
    return nil
end

function UGCEditor:SaveHomeSet(yard_img, audit_img, jsonData, isCover, callback)

    local cover = isCover == true
    local pos = self:GetAllPos()

    local param = {
        ["yard_img"] = yard_img,
        ["audit_img"] = audit_img,
        ["courtyard_location"] = jsonData,
        ["fur_ids"] = self.jsonService:encode(self.fur_ids),
        ["default_cover"] = cover,
        ["position"] = pos,
        ["playing_desc"] = self.submit_inputField.text,
        ["open_speak_board"] = self.gameStart and true or false
    }

    local url = "/v3/home/save-home-yard"
    if self.UGCSourceType == UGCSource.IsLand then
        url = "/v3/home/save-home-garden"
        param = {
            ["garden_cover_img"] = yard_img,
            ["garden_audit_img"] = audit_img,
            ["garden_location"] = jsonData,
            ["fur_ids"] = self.jsonService:encode(self.fur_ids),
            ["default_cover"] = cover,
            ["position"] = pos,
            ["playing_desc"] = self.submit_inputField.text,
            ["open_speak_board"] = self.gameStart and true or false
        }
    end

    self:HttpRequest(url, param, function(resp)
        g_Log(self.TAG, "save-home-yard 请求成功", resp)
        local msg = self.jsonService:decode(resp)
        if msg and msg.code == 0 then

            callback(true, nil)

            g_Log(self.TAG, "审核坐标数据", pos)
            self:Report("editor_upload_start", "庭院摆放送审", "", {
                url = audit_img,
                p = pos
            })
        else
            callback(false, msg.msg)
        end
    end, function(res)
        g_Log(self.TAG, "save-home-yard 请求失败", table.dump(res))
        callback(false, res.error)
    end)
end

function UGCEditor:GetAllPos()

    -- return self:GetAllPos1()

    local list = {}
    for k, v in pairs(self.PlaceMap) do
        local info = {
            x = v.x,
            y = v.y,
            z = v.z
        }
        table.insert(list, info)

        local go = self.goParent:Find(v.guid)
        if not Util:IsNil(go) and go.gameObject.activeSelf then
            --这里我需要获取go的中心点  已经4个角的中心点。 
        end
    end
    local s = self.jsonService:encode(list)
    return s
end

function UGCEditor:RequestAuditResult(callback)

    if not HOME_CONFIG_INFO.IsOwner then
        return
    end

    local url = "/v3/home/get-audit-yard"
    if self.UGCSourceType == UGCSource.IsLand then
        url = "/v3/home/get-garden-failed"
    end

    self:HttpRequest(url, {
        map_id = HOME_CONFIG_INFO.MapId
    }, function(resp)
        g_Log(self.TAG, "get-audit-yard 请求成功", resp)
        local msg = self.jsonService:decode(resp)
        if msg and msg.code == 0 then
            callback(msg.data.courtyard_location)
            -- 0未提交 1审核中 2通过 3失败

        else
            -- callback(nil)
        end
    end, function(res)
        g_Log(self.TAG, "get-audit-yard 请求失败", table.dump(res))
        -- callback(nil)
    end)

end

------------------------------------------TOOL----------
-- http请求地址封装
function UGCEditor:HttpRequest(request, params, success, fail)
    local url = "https://app.chuangjing.com/abc-api" .. request
    if App.IsStudioClient then
        url = "https://yapi.xesv5.com/mock/2041" .. request
        self.httpService:PostForm(url, params, {}, success, fail)
    else
        APIBridge.RequestAsync('api.httpclient.request', {
            ["url"] = url,
            ["headers"] = {
                ["Content-Type"] = "application/json"
            },
            ["data"] = params
        }, function(res)
            if res ~= nil and res.responseString ~= nil and res.isSuccessed then
                local resp = res.responseString
                success(resp)
            else
                fail(res)
            end
        end)
    end
end

function UGCEditor:GetUrlAndPackageByUaddress(uaddress)
    local list = string.split(uaddress, "/")
    if #list == 0 then
        return nil
    end
    local packageName = list[1]
    local urlPrefix = "https://static0.xesimg.com/next-studio-pub/"
    local url = ""
    if CS.UnityEngine.Application.platform == CS.UnityEngine.RuntimePlatform.Android then
        url = urlPrefix .. "android_bundle/"
    else
        url = urlPrefix .. "ios_bundle/"
    end

    if App.IsStudioClient then
        url = urlPrefix .. "mac_bundle/"
    end

    url = url .. packageName .. ".zip"

    return url, packageName
end

local Camera = CS.UnityEngine.Camera
local RenderTexture = CS.UnityEngine.RenderTexture
local Texture2D = CS.UnityEngine.Texture2D
local mainCamera = Camera.main
local Screen = CS.UnityEngine.Screen
local Object = CS.UnityEngine.Object
local Application = CS.UnityEngine.Application
local TextureFormat = CS.UnityEngine.TextureFormat
local Rect = CS.UnityEngine.Rect
local File
---hotFixCode
if CS.System.IO ~= nil then
    ---@type CS.System.IO.File
    File = CS.System.IO.File
else
    File = CS.XLua.CustomExtensions.CustomSystemFile
end

local count = 5
local sizeW = 800 * 1.5
local sizeH = 600 * 1.5

function UGCEditor:ShotDoorImage()
    if self.hasShotDoorImage then
        return
    end
    self.hasShotDoorImage = true

    self.observerService:Fire("SHOT_IMAGE_WITH_PARAM", {
        position = Vector3(-9.19999981, 12, -19.7999992),
        rotation = Vector3(28.4486885, 25.0192394, 1.45654701e-06),
        width = sizeW,
        height = sizeH,
        callback = function(texture2d)

            local doorGo = GameObject.Find("小岛/云朵兔子门出口/Asset/dise")
            if doorGo then
                local meshRender = doorGo:GetComponent(typeof(CS.UnityEngine.MeshRenderer))
                local material = meshRender.material

                if material:HasProperty("_BaseTex") then
                    material:SetTexture("_BaseTex", texture2d)
                end
            end

        end
    })
end

function UGCEditor:shotScreenImage()
    if not self.cameraRoot then
        self.cameraRoot = self.VisElement.transform:Find("相机位置")
    end

    self.cameraRoot.gameObject:SetActive(true)

    local tex = Texture2D(count * sizeW, sizeH, TextureFormat.ARGB4444, false)

    for i = 1, count, 1 do
        local pos1 = self.cameraRoot:Find("相机" .. tostring(i))
        self:Shot(pos1.gameObject, tex, (i - 1) * sizeW, 0)
    end

    tex:Apply()

    local finalPath = Application.persistentDataPath .. "/testImage1.jpg"
    File.WriteAllBytes(finalPath, tex:EncodeToJPG())

    Object.Destroy(tex)

    g_Log(self.TAG, "save --", finalPath)

    self.cameraRoot.gameObject:SetActive(false)

    return finalPath
end

function UGCEditor:Shot(go, texture2d, x, y)
    -- go 没相机就加个相机
    local camera = go:GetComponent(typeof(CS.UnityEngine.Camera))
    if not camera then
        camera = go:AddComponent(typeof(CS.UnityEngine.Camera))
    end
    -- 创建一个200 200 的 texture
    local rt = RenderTexture(sizeW, sizeH, 16)
    -- 设置相机的渲染目标
    camera.targetTexture = rt
    -- 渲染相机
    camera:Render()
    -- 激活渲染纹理
    RenderTexture.active = rt

    texture2d:ReadPixels(Rect(0, 0, sizeW, sizeH), x, 0)

    -- 重置回去
    camera.targetTexture = nil
    RenderTexture.active = nil

    Object.Destroy(rt)

    GameObject.Destroy(camera)
end

function UGCEditor:ShowLoading(show)
    if show then
        self.uiPointDown = true

    else
        self.uiPointDown = false
    end

    self.observerService:Fire("ABCZONE_YAYA_LOADING", {
        show = show
    })
end

function UGCEditor:CalculateTotalBounds(parentObj)
    local meshFilters = parentObj:GetComponentsInChildren(typeof(CS.UnityEngine.MeshFilter));

    local size = Vector3(0, 0, 0)
    for i = 0, meshFilters.Length - 1, 1 do
        local mesh = meshFilters[i].mesh
        local meshSize = mesh.bounds.size
        size.x = math.max(size.x, meshSize.x)
        size.y = math.max(size.y, meshSize.y)
        size.z = math.max(size.z, meshSize.z)

    end

    local meshRenders = parentObj:GetComponentsInChildren(typeof(CS.UnityEngine.SkinnedMeshRenderer));
    for i = 0, meshRenders.Length - 1, 1 do
        local mesh = meshRenders[i].sharedMesh
        local meshSize = mesh.bounds.size
        size.x = math.max(size.x, meshSize.x)
        size.y = math.max(size.y, meshSize.y)
        size.z = math.max(size.z, meshSize.z)
    end

    if size.x <= 0.5 then
        size.x = 1
    end

    if size.y <= 0.5 then
        size.y = 1
    end

    if size.z <= 0.5 then
        size.z = 1
    end

    return size;
end

function UGCEditor:ShowAlert(title, content, sureCallback, cancelCallback, text1, text2)

    self.observerService:Fire("COMMON_ALERT_SHOW", {
        title = title,
        content = content,
        buttons = {{
            text = text1 or "取消"
        }, {
            text = text2 or "确定"
        }},
        callback = function(index)
            if index == 2 then
                sureCallback()
            else
                cancelCallback()
            end

        end
    })

    if true then
        return
    end

    if App.IsStudioClient then
        self.uiPointDown = true
        self.observerService:Fire("EVENT_UNIVERSALOPUP_SHOW_PANEL", {
            title = "",
            content = content,
            showType = 1,
            rightBtnText = "确定",
            cancelBtnText = "取消",
            callbackRight = function()
                self.uiPointDown = false
                sureCallback()
            end,
            callbackCancel = function()
                self.uiPointDown = false
                cancelCallback()
            end

        })
    else
        APIBridge.RequestAsync('app.ui.alert', {
            style = 0,
            title = "",
            message = content,
            button = {{
                title = "确定"
            }, {
                title = "取消"
            }}
        }, function(msg)

            if msg.buttonIndex == 1 then
                cancelCallback()
            elseif msg.buttonIndex == 0 then
                sureCallback()
            end

        end)
    end
end

-- 兼容一下旧版本 保留小数后n位
---@param nNum number 数字
---@param n number 保留位数
function UGCEditor:_GetPreciseDecimal(nNum, n)
    if type(nNum) ~= "number" then
        return nNum;
    end
    local fmt = '%.' .. n .. 'f'
    local nRet = tonumber(string.format(fmt, nNum))
    if nRet == nil then
        g_LogError("保留小数异常：" .. tostring(nNum) .. " " .. tostring(n))
    end
    return nRet;
end

function UGCEditor:GetGuid()
    self.IdStart = self.IdStart + 1
    return tostring(self.IdStart)
end

function UGCEditor:CompressString(str)

    if not str then
        return nil
    end

    cast(CS.System.Text.Encoding.UTF8, typeof(CS.System.Text.Encoding))
    local bytes = CS.System.Text.Encoding.UTF8:GetBytes(str);
    local length = #bytes

    local memoryStream = CS.System.IO.MemoryStream()

    local gzipStream = CS.System.IO.Compression.GZipStream(memoryStream,
        CS.System.IO.Compression.CompressionMode.Compress, true)
    gzipStream:Write(bytes, 0, length)

    gzipStream:Close()

    memoryStream.Position = 0

    local compressData = memoryStream:ToArray()
    local retString = CS.System.Convert.ToBase64String(compressData)

    gzipStream:Dispose()
    memoryStream:Dispose()

    return retString
end

function UGCEditor:DecompressString(str)

    if not str then
        return nil
    end
    cast(CS.System.Text.Encoding.UTF8, typeof(CS.System.Text.Encoding))
    local compressData = CS.System.Convert.FromBase64String(str)
    local memoryStream = CS.System.IO.MemoryStream(compressData)

    local gzipStream = CS.System.IO.Compression.GZipStream(memoryStream,
        CS.System.IO.Compression.CompressionMode.Decompress, true)

    local decompressedMemoryStream = CS.System.IO.MemoryStream()
    local bufferSize = 81920
    gzipStream:CopyTo(decompressedMemoryStream, bufferSize)

    local decompressedData = decompressedMemoryStream:ToArray()

    local retString = CS.System.Text.Encoding.UTF8:GetString(decompressedData)

    gzipStream:Dispose()
    memoryStream:Dispose()
    decompressedMemoryStream:Dispose()

    return retString
end

function UGCEditor:RequestHomeInfo(callback)

    if App.IsStudioClient and TEST_LOCAL_CACHE then
        local s = CS.UnityEngine.PlayerPrefs.GetString(self.HomeData_yard)
        if s and s ~= "" then
            local courtyard_location = s
            callback(courtyard_location)
            return
        end
    end

    local userId = HOME_CONFIG_INFO.UnionId
    self:HttpRequest("/v3/home/stu-home-info", {
        at_home_union_id = tostring(userId)
    }, function(resp)
        g_Log(self.TAG, "RequestHomeInfo resp", userId, resp)
        if resp and resp ~= "" then
            local msg = nil
            if type(resp) == "string" then
                msg = self.jsonService:decode(resp)
            end
            if msg and msg.code == 0 then
                local data = msg.data
                local courtyard_location = data.courtyard_location
                if self.UGCSourceType == UGCSource.IsLand then
                    courtyard_location = data.garden_location
                end

                if courtyard_location and courtyard_location ~= '' then
                    callback(courtyard_location)
                end

                return
            end
        end
        g_Log(self.TAG, "RequestHomeInfo1 error", resp)
    end, function(res)
        g_Log(self.TAG, "RequestHomeInfo2 error", res)
    end)
end

function UGCEditor:SetAllAvatarVisable(show)
    self.allAvatarVisable = show
    for i, v in ipairs(self.avatarList) do
        v.Body.gameObject:SetActive(show)
    end

    if not self.PetRoot then
        self.PetRoot = GameObject.Find("PET_CONTAINER")
    end

    if self.PetRoot then
        self.PetRoot.gameObject:SetActive(show)
    end
end

-- 标记审核状态为已读
function UGCEditor:UpdateYardStatus()
    local type = 0
    if self.UGCSourceType == UGCSource.IsLand then
        type = 1
    else
        type = nil
    end
    self:HttpRequest("/v3/home/yard-status", {
        yard_type = type,
        map_id = HOME_CONFIG_INFO.MapId
    }, function(resp)

    end, function(res)

        g_Log(self.TAG, "请求UpdateYardStatus失败！！")

    end)
end

------------------------蓝图组件相应方法End---------------------------------------------

-- 脚本释放
function UGCEditor:Exit()
    UGCEditor.super.Exit(self)

    if self.cameraJoystick.onMove then
        self.cameraJoystick.onMove:RemoveAllListeners()
        self.cameraJoystick.onMove = nil
    end

    if self.cameraJoystick.onMoveEnd then
        self.cameraJoystick.onMoveEnd:RemoveAllListeners()
        self.cameraJoystick.onMoveEnd = nil
    end

    if self.moveJoystick.onMove then
        self.moveJoystick.onMove:RemoveAllListeners()
        self.moveJoystick.onMove = nil
    end

    if self.moveJoystick.onMoveEnd then
        self.moveJoystick.onMoveEnd:RemoveAllListeners()
        self.moveJoystick.onMoveEnd = nil
    end

    if self.touchPadTrigger then
        self.touchPadTrigger:ClearAll()
    end
end

function UGCEditor:Report(event, label, action, value)
    if not value then
        value = {}
    end
    NextStudioComponentStatisticsAPI.ComponentStatisticsWithParam(event, "74226", "Special-Interaction", label, action,
        value)
end

-- 获取摆放审核信息
function UGCEditor:GetAllPos1()
    local list = {}

    -- 创建一个临时物体用于计算旋转
    local tempGO = GameObject("TempCornerCalculator")

    for k, v in pairs(self.PlaceMap) do
        local go = self.goParent:Find(v.guid)
        if not Util:IsNil(go) and go.gameObject.activeSelf then
            -- 获取物体的中心点
            local centerPos = {
                x = v.x,
                y = v.y,
                z = v.z
            }

            -- 计算物体的大小
            local size = self:CalculateTotalBounds(go)
            local halfWidth = size.x * go.transform.localScale.x / 2
            local halfHeight = size.y * go.transform.localScale.y / 2
            local halfDepth = size.z * go.transform.localScale.z / 2

            -- 设置临时物体的位置和旋转
            tempGO.transform.position = Vector3(centerPos.x, centerPos.y, centerPos.z)
            tempGO.transform.eulerAngles = Vector3(0, v.r, 0)

            -- 定义四个角的相对位置（未旋转前）
            local relativeCorners = {Vector3(-halfWidth, 0, halfDepth), -- 左前
            Vector3(halfWidth, 0, halfDepth), -- 右前
            Vector3(-halfWidth, 0, -halfDepth), -- 左后
            Vector3(halfWidth, 0, -halfDepth) -- 右后
            }

            -- 添加中心点
            table.insert(list, centerPos)

            -- 使用Transform.TransformPoint计算旋转后的世界坐标
            for _, relativePos in ipairs(relativeCorners) do
                local worldPos = tempGO.transform:TransformPoint(relativePos)

                -- 添加角点位置
                table.insert(list, {
                    x = self:_GetPreciseDecimal(worldPos.x, 2),
                    y = self:_GetPreciseDecimal(worldPos.y, 2),
                    z = self:_GetPreciseDecimal(worldPos.z, 2)
                })
            end
        else
            -- 如果物体不存在或不活跃，只添加记录的位置
            local info = {
                x = self:_GetPreciseDecimal(v.x, 2),
                y = self:_GetPreciseDecimal(v.y, 2),
                z = self:_GetPreciseDecimal(v.z, 2)
            }
            table.insert(list, info)
        end
    end

    -- 处理完所有家具后销毁临时物体
    GameObject.DestroyImmediate(tempGO)

    local s = self.jsonService:encode(list)
    return s
end

-- 检查能量是否可以操作
function UGCEditor:CanOperate()

    if App.IsStudioClient then
        return true
    end

    local ret = true
    self:Fire("EVENT_GET_CURRENT_ENERGY", {
        callBack = function(canPlace)
            if not canPlace then
                -- CourseEnv.ServicesManager:GetUIService().commonMenu:ShowToast("能量不足", 1)
                ret = false
            end
        end
    })
    return ret
end

---------------------赛车游戏特殊逻辑-----------------------------------------------
-- 赛道重叠检测
function UGCEditor:CheckTrackOverlap()

    if not self.lastCheckTime then
        self.lastCheckTime = Time.time
    end

    if self.lastCheckTime then --
        if Time.time - self.lastCheckTime < 0.1 then
            return
        end

        self.lastCheckTime = Time.time
    end

    if HOME_CONFIG_INFO.MapType ~= UGC_MAP_TYPE.KartGame then
        return false, {}
    end

    if not self.PlaceMap or not self.goParent then
        return false, {}
    end

    local MeshCollider = CS.UnityEngine.MeshCollider

    local function getPlanarNormalized(v)
        if not v then
            return nil
        end
        local p = Vector3(v.x, 0, v.z)
        if p.sqrMagnitude < 1e-6 then
            return nil
        end
        return p.normalized
    end

    -- 2D OBB 检测：在 XZ 平面做分离轴测试，减少AABB旋转带来的误报
    local function dotXZ(a, b)
        return a.x * b.x + a.z * b.z
    end

    local function normalizePlanar(v)
        local p = Vector3(v.x, 0, v.z)
        local m2 = p.sqrMagnitude
        if m2 < 1e-6 then
            return nil
        end
        return p.normalized
    end

    local function buildOBB2D(col, shrink)
        local tf = col.transform
        local u = normalizePlanar(tf.right) or Vector3.right -- 近似退化处理
        local v = normalizePlanar(tf.forward) or Vector3.forward
        local sx, szHalf, centerW
        local shrinkVal = (shrink or 0)
        -- BoxCollider 直接使用 local center/size
        if col.center ~= nil and col.size ~= nil then
            local okCenter = col.center ~= nil
            local okSize = col.size ~= nil
            if okCenter and okSize then
                centerW = tf:TransformPoint(col.center)
                local size = col.size
                sx = math.abs(tf.lossyScale.x) * size.x * 0.5 - shrinkVal
                szHalf = math.abs(tf.lossyScale.z) * size.z * 0.5 - shrinkVal
            end
        end
        -- MeshCollider 使用 sharedMesh.bounds（局部），再变换到世界
        if not centerW then
            local meshCol = col
            local mesh = meshCol.sharedMesh
            if mesh ~= nil then
                local localCenter = mesh.bounds.center
                local localSize = mesh.bounds.size
                centerW = tf:TransformPoint(localCenter)
                sx = math.abs(tf.lossyScale.x) * localSize.x * 0.5 - shrinkVal
                szHalf = math.abs(tf.lossyScale.z) * localSize.z * 0.5 - shrinkVal
            end
        end
        -- 仍获取不到则回退到 world AABB
        if not centerW then
            local b = col.bounds
            centerW = b.center
            sx = b.extents.x - shrinkVal
            szHalf = b.extents.z - shrinkVal
        end
        if sx < 0 then
            sx = 0
        end
        if szHalf < 0 then
            szHalf = 0
        end
        return centerW, u, v, sx, szHalf
    end

    local function obb2dOverlap(colA, colB, shrink)
        local eps = 1e-4
        local c1, u1, v1, ex1, ez1 = buildOBB2D(colA, shrink)
        local c2, u2, v2, ex2, ez2 = buildOBB2D(colB, shrink)
        local centerDelta = Vector3(c2.x - c1.x, 0, c2.z - c1.z)
        local axes = {u1, v1, u2, v2}
        local minPen = math.huge
        for ai = 1, 4 do
            local ax = axes[ai]
            local projDist = math.abs(dotXZ(centerDelta, ax))
            local r1 = ex1 * math.abs(dotXZ(u1, ax)) + ez1 * math.abs(dotXZ(v1, ax))
            local r2 = ex2 * math.abs(dotXZ(u2, ax)) + ez2 * math.abs(dotXZ(v2, ax))
            local gap = r1 + r2 - projDist
            if gap < minPen then
                minPen = gap
            end
            if gap < -eps then
                return false, 0
            end
        end
        return true, minPen
    end

    local function verticalGap(boundsA, boundsB)
        local minA, maxA = boundsA.min, boundsA.max
        local minB, maxB = boundsB.min, boundsB.max
        if maxA.y < minB.y then
            return minB.y - maxA.y
        elseif maxB.y < minA.y then
            return minA.y - maxB.y
        else
            return 0
        end
    end

    -- 计算 BoxCollider 在世界空间的顶部四个角（考虑旋转/缩放）
    local function getTopCornersFromBox(box)
        if Util:IsNil(box) then
            return {}
        end
        local tf = box.transform
        local c = box.center
        local s = box.size
        local hx, hy, hz = s.x * 0.5, s.y * 0.5, s.z * 0.5
        local lc = {Vector3(c.x - hx, c.y + hy, c.z - hz), Vector3(c.x + hx, c.y + hy, c.z - hz),
                    Vector3(c.x + hx, c.y + hy, c.z + hz), Vector3(c.x - hx, c.y + hy, c.z + hz),
                    Vector3(c.x - hx, c.y - hy, c.z - hz), Vector3(c.x + hx, c.y - hy, c.z - hz),
                    Vector3(c.x + hx, c.y - hy, c.z + hz), Vector3(c.x - hx, c.y - hy, c.z + hz)}
        local wc = {}
        for i = 1, #lc do
            wc[i] = tf:TransformPoint(lc[i])
        end
        local topY = -math.huge
        for i = 1, #wc do
            if wc[i].y > topY then
                topY = wc[i].y
            end
        end
        local eps = 1e-3
        local tops = {}
        for i = 1, #wc do
            if wc[i].y >= topY - eps then
                table.insert(tops, wc[i])
            end
        end
        if #tops < 4 then
            table.sort(wc, function(a, b)
                return a.y > b.y
            end)
            for i = 1, math.min(4, #wc) do
                table.insert(tops, wc[i])
            end
        end
        -- 顶点向物体中心点微偏移，降低“卡边缘”敏感度
        local worldCenter = tf:TransformPoint(c)
        local maxXZ = math.max(math.abs(s.x), math.abs(s.z))
        local offsetDist = maxXZ * 0.05
        if offsetDist < 0.02 then
            offsetDist = 0.02
        end
        if offsetDist > 0.3 then
            offsetDist = 0.3
        end
        local adjusted = {}
        for i = 1, #tops do
            local dir = worldCenter - tops[i]
            local len = dir.magnitude
            if len > 1e-6 then
                dir = dir / len
                adjusted[i] = tops[i] + dir * offsetDist
            else
                adjusted[i] = tops[i]
            end
        end
        return adjusted
    end

    -- 收集所有赛道段（根节点 BoxCollider）和端点、方向
    local trackList = {}
    local trackMeta = {}
    for guid, info in pairs(self.PlaceMap) do
        if info and info.gameType == Game_Type.Track then
            local go = self.goParent:Find(guid)
            if go and not Util:IsNil(go) and go.gameObject.activeInHierarchy then
                local rootBox = go:GetComponent(typeof(CS.UnityEngine.BoxCollider))
                if rootBox and rootBox.enabled then
                    local b = rootBox.bounds
                    local aabb = {
                        cx = (b.min.x + b.max.x) * 0.5,
                        cz = (b.min.z + b.max.z) * 0.5,
                        ex = (b.max.x - b.min.x) * 0.5,
                        ez = (b.max.z - b.min.z) * 0.5,
                        minY = b.min.y,
                        maxY = b.max.y
                    }
                    table.insert(trackList, {
                        guid = guid,
                        go = go,
                        box = rootBox,
                        aabb = aabb
                    })
                end

                -- 端点与方向
                local sTf = go:Find("trigger/start")
                local eTf = go:Find("trigger/end")
                local s1 = go:Find("dir/start/1")
                local s2 = go:Find("dir/start/2")
                local e1 = go:Find("dir/end/1")
                local e2 = go:Find("dir/end/2")
                if sTf and eTf and s1 and s2 and e1 and e2 then
                    trackMeta[guid] = {
                        startPos = sTf.position,
                        endPos = eTf.position,
                        startDir = getPlanarNormalized(s2.position - s1.position),
                        endDir = getPlanarNormalized(e2.position - e1.position)
                    }
                end
            end
        end
    end

    local overlappedSet = {}
    for i = 1, #trackList do
        local a = trackList[i]
        for j = i + 1, #trackList do
            local b = trackList[j]

            -- 若两段只是端点正确连接（闭合/拼接）则忽略这对的重叠判断
            local ma, mb = trackMeta[a.guid], trackMeta[b.guid]
            local pairIsConnected = false
            if ma and mb then
                local POS_CONN = 1.5
                local ANGLE_CONN = 15 -- 度
                -- a.end -> b.start
                if Vector3.Distance(ma.endPos, mb.startPos) <= POS_CONN then
                    local ang = 999
                    if ma.endDir and mb.startDir then
                        ang = math.abs(Vector3.SignedAngle(ma.endDir, mb.startDir, Vector3.up))
                    end
                    if ang <= ANGLE_CONN then
                        pairIsConnected = true
                    end
                end
                -- b.end -> a.start
                if not pairIsConnected and Vector3.Distance(mb.endPos, ma.startPos) <= POS_CONN then
                    local ang2 = 999
                    if mb.endDir and ma.startDir then
                        ang2 = math.abs(Vector3.SignedAngle(mb.endDir, ma.startDir, Vector3.up))
                    end
                    if ang2 <= ANGLE_CONN then
                        pairIsConnected = true
                    end
                end
                if pairIsConnected then
                    goto continue_pair
                end
            end

            -- 赛道级别的平面AABB粗过滤：XZ不相交或竖直间隙过大则直接跳过该对
            local PLANAR_PAD = 0.05
            local Y_GAP_MAX = 0.15
            if a.aabb and b.aabb then
                local dx = math.abs(a.aabb.cx - b.aabb.cx)
                local dz = math.abs(a.aabb.cz - b.aabb.cz)
                local dyGapPair = 0
                if a.aabb.maxY < b.aabb.minY then
                    dyGapPair = b.aabb.minY - a.aabb.maxY
                elseif b.aabb.maxY < a.aabb.minY then
                    dyGapPair = a.aabb.minY - b.aabb.maxY
                end
                if dx > (a.aabb.ex + b.aabb.ex + PLANAR_PAD) or dz > (a.aabb.ez + b.aabb.ez + PLANAR_PAD) or dyGapPair >
                    Y_GAP_MAX then
                    goto continue_pair
                end
            end
            -- 根节点 BoxCollider 判定 + 二次射线校验
            do
                local ca = a.box
                local cb = b.box
                if ca and cb and ca.enabled and cb.enabled then
                    local ba = ca.bounds
                    local bb = cb.bounds
                    local dyGap = verticalGap(ba, bb)
                    local Y_GAP_MAX = 0.15
                    if dyGap <= Y_GAP_MAX then
                        local overlapped = false
                        local minPen = 0
                        local ok, dir, dist = CS.UnityEngine.Physics.ComputePenetration(ca, ca.transform.position,
                            ca.transform.rotation, cb, cb.transform.position, cb.transform.rotation)
                        local MIN_PEN = 0.05
                        if ok == true and dist and dist > MIN_PEN then
                            overlapped = true
                            minPen = dist or 0
                        else
                            -- 退化到 OBB2D（仅使用 BoxCollider 参数）
                            local hit, pen = obb2dOverlap(ca, cb, 0.05)
                            overlapped = hit and (pen or 0) > MIN_PEN
                            minPen = pen or 0
                        end
                        -- 二次射线校验（仅 trackLayer），使用 A 与 B 的包围盒顶部四角（共8个点）
                        if overlapped then
                            -- 使用 OBB 顶部四角，避免 Y 轴旋转导致 AABB 顶点失真
                            local aTop = getTopCornersFromBox(ca)
                            local bTop = getTopCornersFromBox(cb)
                            local corners = {}
                            for i = 1, #aTop do
                                table.insert(corners, aTop[i])
                            end
                            for i = 1, #bTop do
                                table.insert(corners, bTop[i])
                            end
                            local mask = (1 << Layer_enum.trackLayer)
                            local anyOk = false

                            for ci = 1, #corners do
                                local origin = corners[ci] + Vector3.up * 10
                                local ray = CS.UnityEngine.Ray(origin, Vector3.down)
                                local hits = CS.UnityEngine.Physics.RaycastAll(ray, 1000, mask)
                                local hitA, hitB = false, false
                                if hits and hits.Length > 0 then
                                    for hi = 0, hits.Length - 1 do
                                        local h = hits[hi]
                                        local tf = h and h.collider and h.collider.transform
                                        tf = tf.parent or tf

                                        if tf == a.go.transform then
                                            hitA = true
                                        elseif tf == b.go.transform then
                                            hitB = true
                                        end

                                        if hitA and hitB then
                                            break
                                        end
                                    end
                                end
                                if hitA and hitB then
                                    anyOk = true
                                    -- self.debugTrackOverlapRays = true
                                    if (self and (self.debugTrackOverlapRays or App.IsStudioClient)) then
                                        local col = CS.UnityEngine.Color(0, 1, 0, 1)
                                        self:_DrawDebugRay(origin, Vector3.down * 1000, col, 3.0)
                                    end
                                    break
                                end
                                if (self and (self.debugTrackOverlapRays or App.IsStudioClient)) then
                                    local col = CS.UnityEngine.Color(1, 0, 0, 1)
                                    self:_DrawDebugRay(origin, Vector3.down * 1000, col, 3.0)
                                end
                            end
                            if not anyOk then
                                overlapped = false
                            end
                        end
                        if overlapped then
                            -- 对连接对：若最小穿透很小，则认为是拼接缝隙，忽略
                            local SMALL_SEAM = 0.08
                            if pairIsConnected and minPen <= SMALL_SEAM then
                                -- 忽略微小拼接
                            else
                                overlappedSet[a.guid] = true
                                overlappedSet[b.guid] = true
                            end
                        end
                    end
                end
            end
            ::continue_pair::
        end
    end

    local overlappedGuids = {}
    for g, _ in pairs(overlappedSet) do
        table.insert(overlappedGuids, g)
    end

    -- 高亮重叠物体为红色（MPB方案），未重叠物体清除高亮
    for i = 1, #trackList do
        local item = trackList[i]
        local isOverlap = overlappedSet[item.guid] == true
        if isOverlap then
            self:ApplyOverlapHighlightMPB(item.go.gameObject, CS.UnityEngine.Color(1, 0, 0, 0.7), 2.5)
        else
            self:ClearOverlapHighlightMPB(item.go.gameObject)
        end
    end

    -- 打印重叠
    g_Log(self.TAG, "CheckTrackOverlap", #overlappedGuids, table.dump(overlappedGuids))
    self.isOverlap = #overlappedGuids > 0
    if self.isOverlap then
        -- self.trackOverlapGuids判断这个内容发生变化才弹出tips
        if not self.trackOverlapGuids then
            self.trackOverlapGuids = {}
        end
        if table.dump(self.trackOverlapGuids) ~= table.dump(overlappedGuids) then

            self:ShowTips("赛道拼接不正确，请修改后重试")
        end
    end
    self.trackOverlapGuids = overlappedGuids
    return self.isOverlap, overlappedGuids
end

-- 选中赛道1 新放下赛道2的时候  赛道2自动吸附到赛道1的终点
function UGCEditor:TrackAutoToClosed(guid1, guid2)

    if HOME_CONFIG_INFO.MapType ~= UGC_MAP_TYPE.KartGame then
        return
    end

    if not guid1 or not guid2 or guid1 == guid2 then
        return
    end

    if not self.PlaceMap or not self.goParent then
        return
    end

    local info1 = self.PlaceMap[guid1]
    local info2 = self.PlaceMap[guid2]

    if not info1 or not info2 or info1.gameType ~= Game_Type.Track or info2.gameType ~= Game_Type.Track then
        return
    end

    local go1 = self.goParent:Find(guid1)
    local go2 = self.goParent:Find(guid2)
    if Util:IsNil(go1) or Util:IsNil(go2) or not go1.gameObject.activeSelf or not go2.gameObject.activeSelf then
        return
    end

    -- 端点与方向
    local e1Tf = go1:Find("trigger/end")
    local s2Tf = go2:Find("trigger/start")
    local e1d1 = go1:Find("dir/end/1")
    local e1d2 = go1:Find("dir/end/2")
    local s2d1 = go2:Find("dir/start/1")
    local s2d2 = go2:Find("dir/start/2")
    if Util:IsNil(e1Tf) or Util:IsNil(s2Tf) or Util:IsNil(e1d1) or Util:IsNil(e1d2) or Util:IsNil(s2d1) or
        Util:IsNil(s2d2) then
        return
    end

    local function planar(v)
        local p = Vector3(v.x, 0, v.z)
        if p.sqrMagnitude < 1e-6 then
            return nil
        end
        return p.normalized
    end
    local t1EndDir = planar(e1d2.position - e1d1.position)
    local t2StartDir = planar(s2d2.position - s2d1.position)
    if not t1EndDir or not t2StartDir then
        return
    end

    -- 若赛道1的结束点已与“其他赛道”的起始点连接，则不再进行自动吸附
    local POS_CONN = 1.5
    local ANGLE_CONN = 15
    for oguid, oinfo in pairs(self.PlaceMap) do
        if oguid ~= guid1 and oinfo and oinfo.gameType == Game_Type.Track then
            local ogo = self.goParent:Find(oguid)
            if ogo and not Util:IsNil(ogo) and ogo.gameObject.activeSelf then
                local osTf = ogo:Find("trigger/start")
                local os1 = ogo:Find("dir/start/1")
                local os2 = ogo:Find("dir/start/2")
                if osTf and os1 and os2 then
                    local oStartDir = planar(os2.position - os1.position)
                    if oStartDir then
                        if Vector3.Distance(e1Tf.position, osTf.position) <= POS_CONN then
                            local ang = math.abs(Vector3.SignedAngle(t1EndDir, oStartDir, Vector3.up))
                            if ang <= ANGLE_CONN then
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- 先旋转赛道2使其起始方向对齐赛道1的结束方向（仅绕Y轴）
    local EPS_ANGLE = 0.1
    local didSnap = false
    local angleY = Vector3.SignedAngle(t2StartDir, t1EndDir, Vector3.up)
    if math.abs(angleY) > EPS_ANGLE then
        local e = go2.transform.localEulerAngles
        e.y = e.y + angleY
        go2.transform.localEulerAngles = e
        didSnap = true
    end

    -- 边界检查：若吸附后的赛道2超出地图范围，则不进行吸附
    local offset = e1Tf.position - s2Tf.position
    local desiredPos = go2.transform.position + offset
    if self.X_MIN and self.X_MAX and self.Z_MIN and self.Z_MAX then
        local collider = go2:GetComponent(typeof(CS.UnityEngine.Collider))
        if Util:IsNil(collider) then
            collider = go2:AddComponent(typeof(CS.UnityEngine.BoxCollider))
            local size = self:CalculateTotalBounds(go2)
            collider.size = size
            collider.isTrigger = true
        end
        local b = collider.bounds
        local ex = b.extents.x
        local ez = b.extents.z
        if desiredPos.x - ex < self.X_MIN or desiredPos.x + ex > self.X_MAX or desiredPos.z - ez < self.Z_MIN or
            desiredPos.z + ez > self.Z_MAX then
            return
        end
    end

    -- 平移赛道2，使其起点与赛道1终点重合
    if offset.sqrMagnitude > 0.0001 then
        go2.transform.position = go2.transform.position + offset
        didSnap = true
    end

    -- 同步赛道2坐标到 PlaceMap
    local cur = self.PlaceMap[guid2]
    if cur then
        cur.x = self:_GetPreciseDecimal(go2.transform.position.x, 2)
        cur.y = self:_GetPreciseDecimal(go2.transform.position.y, 2)
        cur.z = self:_GetPreciseDecimal(go2.transform.position.z, 2)
        cur.r = self:_GetPreciseDecimal(go2.transform.localEulerAngles.y, 2)
        self.PlaceMap[guid2] = cur
    end

    if didSnap then
        if not self.autoClosedAudio then
            self.raceClosedAudio = self.configService:GetAssetByConfigKey(self.VisElement, "raceCloseAudio")
            self.raceFinishAudio = self.configService:GetAssetByConfigKey(self.VisElement, "raceFinishAudio")
            self.raceClosedEffect = self.VisElement.transform:Find("跑道拼接特效")
        end
        if self.audioService and self.raceClosedAudio then
            self.audioService:PlayClipOneShot(self.raceClosedAudio)
        end
        if self.raceClosedEffect and e1Tf then
            local effectTf = self.raceClosedEffect.transform or self.raceClosedEffect
            effectTf.position = e1Tf.position
            effectTf.rotation = e1Tf.rotation
            self.raceClosedEffect.gameObject:SetActive(true)
            if self.commonService and self.commonService.DispatchAfter then
                self.commonService:DispatchAfter(1.0, function()
                    self.raceClosedEffect.gameObject:SetActive(false)
                end)
            end
        end

        self:CheckRaceFinish(true)
    end

end

function UGCEditor:TrackDropEnd()

    if HOME_CONFIG_INFO.MapType ~= UGC_MAP_TYPE.KartGame then
        return
    end

    local selectCount = #self.selectedList
    if selectCount == 1 and self.selectedList[1].gameType == Game_Type.Track then
        self:TrackAutoClosedCheck(self.selectedList[1].guid)
    end
end

-- 选中赛道放下的时候自动吸附到最近可吸附的赛道
function UGCEditor:TrackAutoClosedCheck(guid)

    if self.debugTrackOverlapRays and App.IsStudioClient then
        return
    end

    if HOME_CONFIG_INFO.MapType ~= UGC_MAP_TYPE.KartGame then
        return
    end

    -- 赛道自动吸附闭合：将当前赛道的起点或终点吸附到场景中最近的赛道终点或起点
    if not guid then
        return
    end

    if not self.autoClosedAudio then
        self.raceClosedAudio = self.configService:GetAssetByConfigKey(self.VisElement, "raceCloseAudio")
        self.raceFinishAudio = self.configService:GetAssetByConfigKey(self.VisElement, "raceFinishAudio")
        self.raceClosedEffect = self.VisElement.transform:Find("跑道拼接特效")
    end

    local info = self.PlaceMap and self.PlaceMap[guid]
    if not info or info.gameType ~= Game_Type.Track then
        return
    end

    local go = self.goParent and self.goParent:Find(guid)
    if Util:IsNil(go) then
        return
    end

    local startPoint = go:Find("trigger/start") -- 当前放下赛道的起始点（子节点）
    local endPoint = go:Find("trigger/end") -- 当前放下赛道的结束点（子节点）

    local startDirPoint1 = go:Find("dir/start/1")
    local startDirPoint2 = go:Find("dir/start/2")
    local startDir = startDirPoint2.position - startDirPoint1.position

    local endDirPoint1 = go:Find("dir/end/1")
    local endDirPoint2 = go:Find("dir/end/2")

    local endDir = endDirPoint2.position - endDirPoint1.position

    if Util:IsNil(startPoint) or Util:IsNil(endPoint) then
        return
    end

    -- 吸附阈值：单位与场景单位一致，过大可能造成误吸附
    local SNAP_DISTANCE = 16
    -- 判断端点是否已被其它赛道占用（已有正确拼接）
    local function endpointIsOccupied(ownerGuid, ownerGo, which)
        local function planar(v)
            local p = Vector3(v.x, 0, v.z)
            if p.sqrMagnitude < 1e-6 then
                return nil
            end
            return p.normalized
        end
        local targetTf, od1, od2
        local isEnd = (which == "end")
        if isEnd then
            targetTf = ownerGo:Find("trigger/end")
            od1 = ownerGo:Find("dir/end/1")
            od2 = ownerGo:Find("dir/end/2")
        else
            targetTf = ownerGo:Find("trigger/start")
            od1 = ownerGo:Find("dir/start/1")
            od2 = ownerGo:Find("dir/start/2")
        end
        if not targetTf or not od1 or not od2 then
            return false
        end
        local targetDir = planar(od2.position - od1.position)
        if not targetDir then
            return false
        end
        local POS_CONN = 0.25
        local ANGLE_CONN = 15
        for cg, cinfo in pairs(self.PlaceMap) do
            if cg ~= ownerGuid and cg ~= guid and cinfo and cinfo.gameType == Game_Type.Track then
                local cgo = self.goParent:Find(cg)
                if cgo and not Util:IsNil(cgo) and cgo.gameObject.activeSelf then
                    local cTf, cd1, cd2
                    if isEnd then
                        -- 其他赛道的 start 占用 owner 的 end
                        cTf = cgo:Find("trigger/start")
                        cd1 = cgo:Find("dir/start/1")
                        cd2 = cgo:Find("dir/start/2")
                    else
                        -- 其他赛道的 end 占用 owner 的 start
                        cTf = cgo:Find("trigger/end")
                        cd1 = cgo:Find("dir/end/1")
                        cd2 = cgo:Find("dir/end/2")
                    end
                    if cTf and cd1 and cd2 then
                        local cdir = planar(cd2.position - cd1.position)
                        if cdir then
                            if Vector3.Distance(targetTf.position, cTf.position) <= POS_CONN then
                                local ang = math.abs(Vector3.SignedAngle(targetDir, cdir, Vector3.up))
                                if ang <= ANGLE_CONN then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    local best = {
        dist = math.huge,
        attach = nil, -- "start_to_end" | "end_to_start"
        targetTf = nil -- 目标触发器 Transform（对端赛道的 start 或 end）
    }

    for otherGuid, other in pairs(self.PlaceMap) do
        if otherGuid ~= guid and other and other.gameType == Game_Type.Track then
            local otherGo = self.goParent:Find(otherGuid)
            if not Util:IsNil(otherGo) and otherGo.gameObject.activeSelf then
                local oStart = otherGo:Find("trigger/start")
                local oEnd = otherGo:Find("trigger/end")

                if not Util:IsNil(oStart) and not Util:IsNil(oEnd) then

                    -- 当前起点 对 其它终点（需确保该终点未被占用）
                    if not endpointIsOccupied(otherGuid, otherGo, "end") then
                        local d1 = Vector3.Distance(startPoint.position, oEnd.position)
                        if d1 < best.dist then
                            best.dist = d1
                            best.attach = "start_to_end"
                            best.targetTf = oEnd
                        end
                    end

                    -- 当前终点 对 其它起点（需确保该起点未被占用）
                    if not endpointIsOccupied(otherGuid, otherGo, "start") then
                        local d2 = Vector3.Distance(endPoint.position, oStart.position)
                        if d2 < best.dist then
                            best.dist = d2
                            best.attach = "end_to_start"
                            best.targetTf = oStart
                        end
                    end
                end
            end
        end
    end

    -- g_Log(TAG, "TrackAutoClosedCheck", guid, best.targetTf, best.dist)

    if not best.targetTf or best.dist > SNAP_DISTANCE then
        return
    end

    -- 方向对齐：将当前被吸附端的方向，与目标端方向在水平面保持一致
    local function getPlanarDir(v)
        if not v then
            return nil
        end
        local p = Vector3(v.x, 0, v.z)
        if p.sqrMagnitude < 1e-6 then
            return nil
        end
        return p.normalized
    end

    local currentDir = nil
    local targetDir = nil

    if best.attach == "start_to_end" then
        -- 当前起点对齐 目标赛道的终点方向
        currentDir = startDir
        local otherRoot = best.targetTf.parent and best.targetTf.parent.parent or nil -- trigger/end 的上两级为赛道根
        if otherRoot then
            local od1 = otherRoot:Find("dir/end/1")
            local od2 = otherRoot:Find("dir/end/2")
            if od1 and od2 then
                targetDir = od2.position - od1.position
            end
        end
    elseif best.attach == "end_to_start" then
        -- 当前终点对齐 目标赛道的起点方向
        currentDir = endDir
        local otherRoot = best.targetTf.parent and best.targetTf.parent.parent or nil -- trigger/start 的上两级为赛道根
        if otherRoot then
            local od1 = otherRoot:Find("dir/start/1")
            local od2 = otherRoot:Find("dir/start/2")
            if od1 and od2 then
                targetDir = od2.position - od1.position
            end
        end
    end

    local curPlanar = getPlanarDir(currentDir)
    local tgtPlanar = getPlanarDir(targetDir)
    local didSnap = false
    local EPS_ANGLE = 0.1
    local EPS_POS_SQR = 0.0001
    if curPlanar and tgtPlanar then
        -- 仅绕Y轴旋转，使两个方向在水平面一致
        local angleY = Vector3.SignedAngle(curPlanar, tgtPlanar, Vector3.up)
        if math.abs(angleY) > EPS_ANGLE then
            local e = go.transform.localEulerAngles
            e.y = e.y + angleY
            go.transform.localEulerAngles = e
            didSnap = true
        end
    end

    -- 位置吸附：在旋转完成后再对齐位置，避免旋转造成端点偏移
    if best.attach == "start_to_end" then
        local offset = best.targetTf.position - startPoint.position
        if offset.sqrMagnitude > EPS_POS_SQR then
            go.transform.position = go.transform.position + offset
            didSnap = true
        end
    elseif best.attach == "end_to_start" then
        local offset = best.targetTf.position - endPoint.position
        if offset.sqrMagnitude > EPS_POS_SQR then
            go.transform.position = go.transform.position + offset
            didSnap = true
        end
    end

    -- 同步坐标信息到 PlaceMap，并记录快照
    local cur = self.PlaceMap[guid]
    if cur then
        cur.x = self:_GetPreciseDecimal(go.transform.position.x, 2)
        cur.y = self:_GetPreciseDecimal(go.transform.position.y, 2)
        cur.z = self:_GetPreciseDecimal(go.transform.position.z, 2)
        cur.r = self:_GetPreciseDecimal(go.transform.localEulerAngles.y, 2)
        self.PlaceMap[guid] = cur
    end

    local ret = self:CheckRaceFinish(true)
    if didSnap then
        self.audioService:PlayClipOneShot(self.raceClosedAudio)

        g_Log(self.TAG, "TrackGroupAutoClosedCheck", table.dump(best), self.raceClosedEffect)
        -- 在拼接点定位特效
        if self.raceClosedEffect and best and best.targetTf then

            local effectTf = self.raceClosedEffect.transform or self.raceClosedEffect
            effectTf.position = best.targetTf.position
            effectTf.rotation = best.targetTf.rotation
            -- 在拼接的位置播放一下这个特效
            self.raceClosedEffect.gameObject:SetActive(true)
            self.commonService:DispatchAfter(1.0, function()
                self.raceClosedEffect.gameObject:SetActive(false)
            end)
        end
    end
end

-- 多选赛道整体吸附：将一组赛道作为刚体整体，与场景内其它赛道进行端点吸附
function UGCEditor:TrackGroupAutoClosedCheck(guidList)

    if HOME_CONFIG_INFO.MapType ~= UGC_MAP_TYPE.KartGame then
        return
    end

    if not guidList or #guidList == 0 then
        return
    end

    if not self.PlaceMap or not self.goParent then
        return
    end

    local groupSet = {}
    local candidates = {}
    for i = 1, #guidList do
        local guid = guidList[i]
        groupSet[guid] = true
        local info = self.PlaceMap[guid]
        if info and info.gameType == Game_Type.Track then
            local go = self.goParent:Find(guid)
            if go and not Util:IsNil(go) and go.gameObject.activeSelf then
                local sTf = go:Find("trigger/start")
                local eTf = go:Find("trigger/end")
                local s1 = go:Find("dir/start/1")
                local s2 = go:Find("dir/start/2")
                local e1 = go:Find("dir/end/1")
                local e2 = go:Find("dir/end/2")
                if sTf and eTf and s1 and s2 and e1 and e2 then
                    table.insert(candidates, {
                        guid = guid,
                        which = "start",
                        triggerTf = sTf,
                        dir1 = s1,
                        dir2 = s2
                    })
                    table.insert(candidates, {
                        guid = guid,
                        which = "end",
                        triggerTf = eTf,
                        dir1 = e1,
                        dir2 = e2
                    })
                end
            end
        end
    end

    if #candidates == 0 then
        return
    end

    local SNAP_DISTANCE = 16
    local best = {
        dist = math.huge,
        attach = nil, -- "start_to_end" | "end_to_start"
        targetTf = nil,
        candidate = nil
    }

    for otherGuid, other in pairs(self.PlaceMap) do
        if other and other.gameType == Game_Type.Track and not groupSet[otherGuid] then
            local otherGo = self.goParent:Find(otherGuid)
            if otherGo and not Util:IsNil(otherGo) and otherGo.gameObject.activeSelf then
                local oStart = otherGo:Find("trigger/start")
                local oEnd = otherGo:Find("trigger/end")
                if oStart and oEnd then
                    for _, c in ipairs(candidates) do
                        if c.which == "start" then
                            local d = Vector3.Distance(c.triggerTf.position, oEnd.position)
                            if d < best.dist then
                                best.dist = d
                                best.attach = "start_to_end"
                                best.targetTf = oEnd
                                best.candidate = c
                            end
                        else
                            local d = Vector3.Distance(c.triggerTf.position, oStart.position)
                            if d < best.dist then
                                best.dist = d
                                best.attach = "end_to_start"
                                best.targetTf = oStart
                                best.candidate = c
                            end
                        end
                    end
                end
            end
        end
    end

    if not best.targetTf or best.dist > SNAP_DISTANCE then
        return
    end

    local function getPlanarDirFrom(c)
        local v = (c.dir2.position - c.dir1.position)
        local p = Vector3(v.x, 0, v.z)
        if p.sqrMagnitude < 1e-6 then
            return nil
        end
        return p.normalized
    end

    local function getTargetPlanarDir(targetTf, attach)
        local otherRoot = targetTf.parent and targetTf.parent.parent or nil
        if not otherRoot then
            return nil
        end
        if attach == "start_to_end" then
            local od1 = otherRoot:Find("dir/end/1")
            local od2 = otherRoot:Find("dir/end/2")
            if od1 and od2 then
                local v = od2.position - od1.position
                local p = Vector3(v.x, 0, v.z)
                if p.sqrMagnitude < 1e-6 then
                    return nil
                end
                return p.normalized
            end
        else
            local od1 = otherRoot:Find("dir/start/1")
            local od2 = otherRoot:Find("dir/start/2")
            if od1 and od2 then
                local v = od2.position - od1.position
                local p = Vector3(v.x, 0, v.z)
                if p.sqrMagnitude < 1e-6 then
                    return nil
                end
                return p.normalized
            end
        end
        return nil
    end

    local curPlanar = getPlanarDirFrom(best.candidate)
    local tgtPlanar = getTargetPlanarDir(best.targetTf, best.attach)

    local didSnap = false
    local EPS_ANGLE = 0.1
    local EPS_POS_SQR = 0.0001
    local angleY = 0
    if curPlanar and tgtPlanar then
        angleY = Vector3.SignedAngle(curPlanar, tgtPlanar, Vector3.up)
    end

    local pivotPos = best.candidate.triggerTf.position
    if math.abs(angleY) > EPS_ANGLE then
        local rot = CS.UnityEngine.Quaternion.AngleAxis(angleY, Vector3.up)
        for i = 1, #guidList do
            local g = guidList[i]
            local go = self.goParent:Find(g)
            if go and not Util:IsNil(go) then
                local e = go.transform.localEulerAngles
                e.y = e.y + angleY
                go.transform.localEulerAngles = e
                local delta = go.transform.position - pivotPos
                local rotated = rot * delta
                go.transform.position = pivotPos + rotated
            end
        end
        didSnap = true
    end

    local currentTf = best.candidate.triggerTf
    local offset = best.targetTf.position - currentTf.position
    if offset.sqrMagnitude > EPS_POS_SQR then
        for i = 1, #guidList do
            local g = guidList[i]
            local go = self.goParent:Find(g)
            if go and not Util:IsNil(go) then
                go.transform.position = go.transform.position + offset
            end
        end
        didSnap = true
    end

    for i = 1, #guidList do
        local g = guidList[i]
        local cur = self.PlaceMap[g]
        local go = self.goParent:Find(g)
        if cur and go and not Util:IsNil(go) then
            cur.x = self:_GetPreciseDecimal(go.transform.position.x, 2)
            cur.y = self:_GetPreciseDecimal(go.transform.position.y, 2)
            cur.z = self:_GetPreciseDecimal(go.transform.position.z, 2)
            cur.r = self:_GetPreciseDecimal(go.transform.localEulerAngles.y, 2)
            self.PlaceMap[g] = cur
        end
    end

    local ret = self:CheckRaceFinish(true)
    if didSnap and not ret then
        if not self.autoClosedAudio then
            self.raceClosedAudio = self.configService:GetAssetByConfigKey(self.VisElement, "raceCloseAudio")
            self.raceFinishAudio = self.configService:GetAssetByConfigKey(self.VisElement, "raceFinishAudio")
            self.raceClosedEffect = self.VisElement.transform:Find("跑道拼接特效")
        end
        self.audioService:PlayClipOneShot(self.raceClosedAudio)
    end
end

function UGCEditor:CheckRaceFinish(playAudio)

    if self._notCheckTrackClosed then
        return false
    end

    -- 检测赛道是否闭环（单一闭环，所有赛道片段构成一个环）
    if HOME_CONFIG_INFO and HOME_CONFIG_INFO.MapType ~= UGC_MAP_TYPE.KartGame then
        return false
    end

    if not self.PlaceMap or not self.goParent then
        return false
    end

    local function getPlanarNormalized(v)
        if not v then
            return nil
        end
        local p = Vector3(v.x, 0, v.z)
        if p.sqrMagnitude < 1e-6 then
            return nil
        end
        return p.normalized
    end

    local tracks = {}
    for guid, info in pairs(self.PlaceMap) do
        if info and info.gameType == Game_Type.Track then
            local go = self.goParent:Find(guid)
            if go and not Util:IsNil(go) and go.gameObject.activeSelf then
                local sTf = go:Find("trigger/start")
                local eTf = go:Find("trigger/end")
                local s1 = go:Find("dir/start/1")
                local s2 = go:Find("dir/start/2")
                local e1 = go:Find("dir/end/1")
                local e2 = go:Find("dir/end/2")
                if sTf and eTf and s1 and s2 and e1 and e2 then
                    local startDir = getPlanarNormalized(s2.position - s1.position)
                    local endDir = getPlanarNormalized(e2.position - e1.position)
                    if startDir and endDir then
                        table.insert(tracks, {
                            guid = guid,
                            startPos = sTf.position,
                            endPos = eTf.position,
                            startDir = startDir,
                            endDir = endDir
                        })
                    end
                end
            end
        end
    end

    local n = #tracks
    if n == 0 then
        return false
    end

    -- 阈值：位置和朝向
    local POS_EPS = 1.5
    local ANGLE_EPS = 10 -- 度

    local nextIdx = {}
    local prevIdx = {}
    local inCnt = {}
    local outCnt = {}
    for i = 1, n do
        inCnt[i] = 0;
        outCnt[i] = 0
    end

    local function locateToUnclosedTrack()
        if not playAudio then

            -- 相机定位到最近一个未闭环的赛道上
            local cam = CS.UnityEngine.Camera.main
            if not Util:IsNil(cam) then
                local camTf = cam.transform
                local candidates = {}
                for i = 1, n do
                    local hasPrev = prevIdx[i] ~= nil
                    local hasNext = nextIdx[i] ~= nil
                    local degreeOk = (inCnt[i] == 1 and outCnt[i] == 1)
                    if not (hasPrev and hasNext and degreeOk) then
                        local c = (tracks[i].startPos + tracks[i].endPos) * 0.5
                        local d = Vector3.Distance(c, camTf.position)
                        table.insert(candidates, {
                            idx = i,
                            pos = c,
                            dist = d
                        })
                    end
                end
                if #candidates > 0 then
                    table.sort(candidates, function(a, b)
                        return a.dist < b.dist
                    end)
                    local best = candidates[1]
                    local gid = tracks[best.idx].guid
                    local go = self.goParent:Find(gid)
                    if go and not Util:IsNil(go) then
                        local center = best.pos
                        local viewAngle = 60
                        local radians = math.rad(viewAngle)
                        local distance = 20
                        do
                            local renders = go:GetComponentsInChildren(typeof(CS.UnityEngine.Renderer))
                            if renders and renders.Length and renders.Length > 0 then
                                local minX, maxX = math.huge, -math.huge
                                local minY, maxY = math.huge, -math.huge
                                local minZ, maxZ = math.huge, -math.huge
                                for i = 0, renders.Length - 1 do
                                    local b = renders[i].bounds
                                    local mn = b.min
                                    local mx = b.max
                                    if mn.x < minX then
                                        minX = mn.x
                                    end
                                    if mx.x > maxX then
                                        maxX = mx.x
                                    end
                                    if mn.y < minY then
                                        minY = mn.y
                                    end
                                    if mx.y > maxY then
                                        maxY = mx.y
                                    end
                                    if mn.z < minZ then
                                        minZ = mn.z
                                    end
                                    if mx.z > maxZ then
                                        maxZ = mx.z
                                    end
                                end
                                local sizeX = math.max(0.1, maxX - minX)
                                local sizeY = math.max(0.1, maxY - minY)
                                local sizeZ = math.max(0.1, maxZ - minZ)
                                local maxSize = math.max(sizeX, sizeZ)
                                local fov = cam.fieldOfView or 60
                                local fovScale = 60 / math.max(10, math.min(90, fov))
                                local base = maxSize * 1.8 * fovScale + sizeY * 0.2
                                local MIN_D, MAX_D = 6, 80
                                distance = math.max(MIN_D, math.min(MAX_D, base))
                            end
                        end
                        local heightOffset = distance * math.sin(radians)
                        local horizontalOffset = distance * math.cos(radians)
                        local forward = camTf.forward
                        local forwardXZ = CS.UnityEngine.Vector3(forward.x, 0, forward.z)
                        if forwardXZ.magnitude < 0.001 then
                            forwardXZ = CS.UnityEngine.Vector3.forward
                        end
                        forwardXZ = forwardXZ.normalized
                        local targetPos = CS.UnityEngine.Vector3(center.x - forwardXZ.x * horizontalOffset,
                            center.y + heightOffset, center.z - forwardXZ.z * horizontalOffset)
                        if self.X_MIN and self.X_MAX and self.Z_MIN and self.Z_MAX then
                            if targetPos.x < self.X_MIN - Camera_Gap then
                                targetPos.x = self.X_MIN - Camera_Gap
                            elseif targetPos.x > self.X_MAX + Camera_Gap then
                                targetPos.x = self.X_MAX + Camera_Gap
                            end
                            if targetPos.z < self.Z_MIN - Camera_Gap then
                                targetPos.z = self.Z_MIN - Camera_Gap
                            elseif targetPos.z > self.Z_MAX + Camera_Gap then
                                targetPos.z = self.Z_MAX + Camera_Gap
                            end
                        end
                        camTf.position = targetPos
                        if self.cametaSlider and self.CAMERA_Y_MIN and self.CAMERA_Y_MAX and self.CAMERA_Y_MAX ~=
                            self.CAMERA_Y_MIN then
                            local ratio = (camTf.position.y - self.CAMERA_Y_MIN) /
                                              (self.CAMERA_Y_MAX - self.CAMERA_Y_MIN)
                            if ratio < 0 then
                                ratio = 0
                            end
                            if ratio > 1 then
                                ratio = 1
                            end
                            self.cametaSlider.value = ratio
                        end
                    end
                end
            end
        end
    end

    -- 标红“未连接”的赛道段（仅当 playAudio ~= true 时）：
    -- 规则：如果某赛道段的 start 或 end 任何一端未找到合法连接（prevIdx/nextIdx 缺失，或入/出度不为1），则标红；
    -- 若该赛道段的两端都已连接（prevIdx 和 nextIdx 同时存在，且入/出度均为1），则不标红。
    local function highlightUnconnectedTracks()
        if playAudio ~= true then
            for i = 1, n do
                local hasPrev = prevIdx[i] ~= nil
                local hasNext = nextIdx[i] ~= nil
                local degreeOk = (inCnt[i] == 1 and outCnt[i] == 1)
                if not (hasPrev and hasNext and degreeOk) then
                    local gid = tracks[i].guid
                    local go = self.goParent:Find(gid)
                    if go and not Util:IsNil(go) then
                        self:ApplyOverlapHighlightMPB(go)
                    end
                end
            end

        end

        locateToUnclosedTrack()
    end

    -- 为每个赛道查找：end -> start 的后继；以及 start <- end 的前驱
    for i = 1, n do
        local bestJ, bestDist = nil, math.huge
        for j = 1, n do
            if j ~= i then
                local d = Vector3.Distance(tracks[i].endPos, tracks[j].startPos)
                if d < bestDist and d <= POS_EPS then
                    local angle = math.abs(Vector3.SignedAngle(tracks[i].endDir, tracks[j].startDir, Vector3.up))
                    if angle <= ANGLE_EPS then
                        bestDist = d
                        bestJ = j
                    end
                end
            end
        end
        nextIdx[i] = bestJ
        if bestJ then
            outCnt[i] = outCnt[i] + 1;
            inCnt[bestJ] = inCnt[bestJ] + 1
        end

        local bestK, bestDistK = nil, math.huge
        for k = 1, n do
            if k ~= i then
                local d2 = Vector3.Distance(tracks[i].startPos, tracks[k].endPos)
                if d2 < bestDistK and d2 <= POS_EPS then
                    local angle2 = math.abs(Vector3.SignedAngle(tracks[k].endDir, tracks[i].startDir, Vector3.up))
                    if angle2 <= ANGLE_EPS then
                        bestDistK = d2
                        bestK = k
                    end
                end
            end
        end
        prevIdx[i] = bestK
    end

    -- 每段必须恰好有一个前驱和一个后继
    for i = 1, n do
        if not nextIdx[i] or not prevIdx[i] then
            highlightUnconnectedTracks()
            return false
        end
        if inCnt[i] ~= 1 or outCnt[i] ~= 1 then
            highlightUnconnectedTracks()
            return false
        end
    end

    -- 验证是单一闭环：从任意一点遍历 n 步正好回到起点，且覆盖全部
    local visited = {}
    local count = 0
    local cur = 1
    while cur and not visited[cur] and count <= n do
        visited[cur] = true
        count = count + 1
        cur = nextIdx[cur]
    end

    local closed = (count == n) and (cur == 1)

    if closed and playAudio and self.audioService and self.raceFinishAudio then
        self.audioService:PlayClipOneShot(self.raceFinishAudio)
        self:ShowTips("赛道已闭合")
    end
    if not closed then
        highlightUnconnectedTracks()
    end

    self.traceClosed = closed

    return closed
end

-- MPB 方案：对渲染器施加临时颜色/自发光，不改材质
function UGCEditor:ApplyOverlapHighlightMPB(rootGo, color, emissionIntensity)
    if Util:IsNil(rootGo) then
        return
    end
    local Renderer = CS.UnityEngine.Renderer
    local Color = CS.UnityEngine.Color
    local MPB = CS.UnityEngine.MaterialPropertyBlock
    local renderers = rootGo:GetComponentsInChildren(typeof(Renderer))
    if not renderers or renderers.Length == 0 then
        return
    end
    for i = 0, renderers.Length - 1 do
        local r = renderers[i]
        if not Util:IsNil(r) and r.gameObject.activeInHierarchy then
            local mat = r.sharedMaterial
            local mpb = MPB()
            r:GetPropertyBlock(mpb)
            local c = color or Color(1, 0, 0, 0.6)
            if mat and mat:HasProperty("_BaseColor") then
                mpb:SetColor("_BaseColor", c)
            elseif mat and mat:HasProperty("_Color") then
                mpb:SetColor("_Color", c)
            end
            if mat and mat:HasProperty("_EmissionColor") then
                local e = Color(c.r, c.g, c.b, 1) * (emissionIntensity or 2.0)
                mpb:SetColor("_EmissionColor", e)
            end
            r:SetPropertyBlock(mpb)
        end
    end
end

function UGCEditor:ClearOverlapHighlightMPB(rootGo)
    if Util:IsNil(rootGo) then
        return
    end
    local Renderer = CS.UnityEngine.Renderer
    local MPB = CS.UnityEngine.MaterialPropertyBlock
    local renderers = rootGo:GetComponentsInChildren(typeof(Renderer))
    if not renderers or renderers.Length == 0 then
        return
    end
    for i = 0, renderers.Length - 1 do
        local r = renderers[i]
        if not Util:IsNil(r) and r.gameObject.activeInHierarchy then
            local mpb = MPB() -- 空 block 清空
            r:SetPropertyBlock(mpb)
        end
    end
end

-- 真机可见的射线绘制（编辑器下同时调用 Debug.DrawRay）
function UGCEditor:_DrawDebugRay(origin, dir, color, duration)
    local Color = CS.UnityEngine.Color
    local col = color or Color(1, 0, 0, 1)
    local dur = duration or 1.0

    local Application = CS.UnityEngine.Application
    if Application and Application.isEditor then
        CS.UnityEngine.Debug.DrawRay(origin, dir, col, dur, true)
    end

    local go = CS.UnityEngine.GameObject("DebugRay")
    local lr = go:AddComponent(typeof(CS.UnityEngine.LineRenderer))
    lr.useWorldSpace = true
    lr.positionCount = 2
    lr.startWidth = 0.5
    lr.endWidth = 0.5
    local mat = CS.UnityEngine.Material(CS.UnityEngine.Shader.Find("UI/Default"))
    mat.color = col
    lr.material = mat
    lr:SetPosition(0, origin)
    lr:SetPosition(1, origin + dir)

    if self.commonService and self.commonService.DispatchAfter then
        self.commonService:DispatchAfter(dur, function()
            if not Util:IsNil(go) then
                CS.UnityEngine.GameObject.Destroy(go)
            end
        end)
    end
end

g_Log("初始化地图工具")

----测试代码----
function UGCEditor:TestCode()
    local testList = ""

    local str = [[
    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
    ]]

    testList = self:DecompressString(str)

    g_Log("解析json", testList)

    local data = {
        list = {},
        version = 1.0
    }

    local list = self.jsonService:decode(testList)
    for i, v in ipairs(list) do
        table.insert(data.list, {
            x = v.x,
            y = v.y,
            z = v.z,
            c = v.c,
            r = 0,
            id = 10001,
            guid = self:GetGuid(),
            level = 10,
            img = "/next-scm/resource/source-1724912029133-46.png",
            locked = 0,
            mover_attributes = {},
            cost = 4,
            uaddress = "1101251764581130/assets/Prefabs/Cube.prefab",
            scale = 1,
            mover_type = 0
        })
    end

    self.jsonData = self.jsonService:encode(data)

    self:ApplyPlaceData(data, function()

    end)
end

-----------------------------------------下面用不上-----------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

---@class unusedElement : WorldBaseElement
local unusedElement = class("fsync_f8f9c77d-812f-4785-af44-d0d8ffd433fd", WBElement)

---@param worldElement CS.Tal.framesync.WorldElement
function unusedElement:initialize(worldElement)
    unusedElement.super.initialize(self, worldElement)

    editorPanel = self.VisElement.transform:Find("编辑面板")

end

return unusedElement

