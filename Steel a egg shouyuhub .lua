-- ============================================================
-- ShouyuHub | Ultimate Steal (Guard-Hit Sync & Multi-Fire)
-- Part 1/5: Config / Helpers / Guard Detection
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local localPlayer       = Players.LocalPlayer

local CFG = {
    HopStep        = 95,
    HopDelay       = 0.0001,
    HopGapMin      = 0.0001,
    HopGapMax      = 0.2,
    HopRetries     = 10,
    SyncDistance   = 25,
    GrabInterval   = 0.03,
    GrabTimeout    = 3,
    SnapshotTTL    = 0.5,
    MaxRetries     = 3,
    BlockedSec     = 30,
    AutoRefresh    = 3,
}

local THEME = {
    Bg         = Color3.fromRGB(15, 20, 30),
    Panel      = Color3.fromRGB(25, 35, 50),
    Card       = Color3.fromRGB(35, 50, 70),
    Accent     = Color3.fromRGB(120, 220, 255),
    AccentSoft = Color3.fromRGB(200, 240, 255),
    AccentDeep = Color3.fromRGB(40, 100, 140),
    Text       = Color3.fromRGB(240, 245, 255),
    TextDim    = Color3.fromRGB(160, 190, 210),
    Stroke     = Color3.fromRGB(60, 100, 130),
    Danger     = Color3.fromRGB(255, 90, 90),
}

local function safeRequire(getter)
    local ok, result = pcall(function() return require(getter()) end)
    return ok and result or nil
end

local networkingFolder  = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState          = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets            = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations         = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(name) return networkingFolder:FindFirstChild(name) end
local function root() return localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") end
local function hum() return localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid") end

local statusLabel = nil
local guiRef = nil
local function status(text) if statusLabel then statusLabel.Text = tostring(text) end end

local state = { Carrying = false, Uid = nil, Busy = false, Cancel = false, Delivered = 0, PulledAt = 0, StealThread = nil }

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" then
    EggState.CarryChanged:Connect(function(arg)
        local carrying = type(arg) == "table" and arg.IsCarrying == true
        if carrying and arg.GuardDisabled == true then carrying = false end
        if carrying and type(arg.Uid) == "string" then state.Uid = arg.Uid end
        state.Carrying = carrying
    end)
end

pcall(function()
    local re = remote("RE/EggWorld/FieldEggRedeemVerdict")
    if re and re:IsA("RemoteEvent") then
        re.OnClientEvent:Connect(function() state.Delivered = os.clock() end)
    end
end)

pcall(function()
    local re = remote("RE/RigSync/Refresh")
    if re and re:IsA("RemoteEvent") then
        re.OnClientEvent:Connect(function(arg)
            if type(arg) == "table" and arg.Action == "Relocate" then
                state.PulledAt = os.clock()
            end
        end)
    end
end)

local function takeEgg(uid)
    if type(uid) == "string" and type(EggState) == "table" and type(EggState.CarryFieldEgg) == "function" then
        pcall(EggState.CarryFieldEgg, uid)
    end
end

local function dropEgg()
    if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
        pcall(EggState.DropFieldEgg, "PlayerRequest")
    end
end

local function money(value)
    value = tonumber(value) or 0
    local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, u in ipairs(units) do
        if value >= u[1] then return string.format("$%.2f%s/s", value / u[1], u[2]) end
    end
    return string.format("$%d/s", math.floor(value + 0.5))
end

local function homePoint()
    for _, def in ipairs({
        { { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
        { { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
        { { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
    }) do
        local node = workspace
        for _, name in ipairs(def[1]) do node = node and node:FindFirstChild(name) or nil end
        if node and node:IsA("BasePart") then return node.CFrame:PointToWorldSpace(def[2]) end
    end
    return Vector3.new(528.7, 70.57, -364.11)
end

local snapshotCache = { At = 0, List = {} }
local function snapshot(force)
    local now = os.clock()
    if not force and (now - snapshotCache.At) < CFG.SnapshotTTL then return snapshotCache.List end
    local list = {}
    local re = remote("RF/EggWorld/AskFieldEggSnapshot")
    if re and re:IsA("RemoteFunction") then
        local ok, result = pcall(re.InvokeServer, re)
        local records = ok and type(result) == "table" and result.Records or nil
        if type(records) == "table" then
            for _, record in pairs(records) do
                if type(record) == "table" and type(record.Uid) == "string"
                    and (record.State == "Slot" or record.State == "Dropped")
                    and typeof(record.BottomCFrame) == "CFrame" then
                    list[#list + 1] = record
                end
            end
        end
    end
    snapshotCache.At = now
    snapshotCache.List = list
    return list
end

local function eggNow(uid, cache)
    local node = workspace:FindFirstChild(uid)
    local slots = workspace:FindFirstChild("AreaEggSlotsClient")
    node = node or (slots and slots:FindFirstChild(uid))
    if node then
        local ok, pos = pcall(function() return node:GetPivot().Position end)
        if ok and pos then
            cache.Pos, cache.At = pos, os.clock()
            return pos
        end
    end
    if os.clock() - (cache.At or 0) >= 0.5 then
        cache.At = os.clock()
        for _, r in ipairs(snapshot(true)) do
            if r.Uid == uid then cache.Pos = r.BottomCFrame.Position; break end
        end
    end
    return cache.Pos
end

local function describe(record)
    local directory = type(Assets) == "table" and Assets.Directory or nil
    local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
    local info = { Uid = record.Uid, Name = tostring(record.AssetCategory), Icon = "", Rarity = 0, Value = 0 }
    if type(entry) == "table" then
        info.Name = tostring(entry.DisplayName or record.AssetCategory)
        local icon = entry.Icon
        if icon ~= nil and tostring(icon) ~= "" then info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or tostring(icon) end
        if type(entry.Rarity) == "table" then info.Rarity = tonumber(entry.Rarity.RarityNumber or entry.Rarity.Rank) or 0 end
        local scale = tonumber(record.AssetScale) or 1
        local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
        local mutation = 1
        if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
            local okM, resM = pcall(Mutations.EarningsFor, type(record.Mutations) == "table" and record.Mutations or {})
            if okM and type(resM) == "number" then mutation = resM end
        end
        info.Value = (tonumber(entry.EarningRate) or 0) * factor * mutation
    end
    return info
end

local function promptNear(pos, rad)
    local best, dist = nil, rad
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
            local p = c:FindFirstChild("CarryAreaEgg")
            if p and p:IsA("ProximityPrompt") and (c.Position - pos).Magnitude < dist then
                best, dist = p, (c.Position - pos).Magnitude
            end
        end
    end
    return best
end

-- ★ ガードの状態を検知する関数
local function getGuardState(areaId, eggPos)
    local guardModel = nil
    pcall(function()
        local areasRoot = workspace:FindFirstChild("__OBJECTS") and workspace.__OBJECTS:FindFirstChild("Areas") and workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
        if areasRoot and areaId then
            local areaFolder = areasRoot:FindFirstChild(areaId)
            if areaFolder then
                guardModel = areaFolder:FindFirstChild("Guard") or areaFolder:FindFirstChild("ForestGuardAuthored") or areaFolder:FindFirstChildWhichIsA("Model", true)
            end
        end
        if not guardModel and eggPos then
            local nearest, nd = nil, 1e9
            for _, m in ipairs(workspace:GetDescendants()) do
                if m:IsA("Model") and m.Name:lower():find("guard") and m.PrimaryPart then
                    local d = (m.PrimaryPart.Position - eggPos).Magnitude
                    if d < nd and d < 90 then nd = d; nearest = m end
                end
            end
            guardModel = nearest
        end
    end)

    if guardModel then
        local alert = guardModel:GetAttribute("Alert") or guardModel:GetAttribute("Alerted") or guardModel:GetAttribute("IsAlerted") or guardModel:GetAttribute("Chasing")
        local sleeping = guardModel:GetAttribute("Sleeping") or guardModel:GetAttribute("IsSleeping") or guardModel:GetAttribute("Asleep") or guardModel:GetAttribute("Sleep")
        local s = guardModel:GetAttribute("State")
        if sleeping == true then return true, guardModel end
        if alert == false or alert == nil then
            local h = guardModel:FindFirstChildOfClass("Humanoid")
            local hrp = guardModel.PrimaryPart or guardModel:FindFirstChild("HumanoidRootPart")
            if hrp and (not h or h.MoveDirection.Magnitude < 0.15) then return true, guardModel end
            if s and tostring(s):lower():find("sleep") then return true, guardModel end
        end
        local alertGui = guardModel:FindFirstChild("Alert", true)
        if alertGui and alertGui:IsA("BillboardGui") and alertGui.Enabled == false then return true, guardModel end
    end
    return false, guardModel
end-- ============================================================
-- Part 2/5: Movement Engine & Multi-Fire Grab
-- ============================================================
local function hopTo(targetPos, checkFn)
    local cam = workspace.CurrentCamera
    local oldCamType = cam.CameraType
    pcall(function() cam.CameraType = Enum.CameraType.Scriptable; cam.CFrame = cam.CFrame end)
    
    local character = localPlayer.Character
    local r = root()
    if not r then return false end
    
    local hopGap = CFG.HopGapMin
    local retries = 0
    local started = os.clock()
    
    while not state.Cancel and os.clock() - started < 60 do
        if checkFn and checkFn() then break end
        r = root()
        if not r then break end
        
        local flat = Vector3.new(targetPos.X - r.Position.X, 0, targetPos.Z - r.Position.Z)
        local dist = flat.Magnitude
        
        -- 最後の同期ゾーン（歩行）
        if dist <= CFG.SyncDistance then
            local h = hum()
            local speed = h and (h.WalkSpeed * 1.15) or 16
            local v = flat.Unit * math.min(speed, dist / 0.05)
            pcall(function()
                r.AssemblyLinearVelocity = v + Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
                if h then h:Move(flat.Unit, false) end
            end)
            task.wait(0.03)
        else
            -- 高速ワープゾーン
            local nextPos = r.Position + flat.Unit * CFG.HopStep + Vector3.new(0, 3, 0)
            local pulledBefore = state.PulledAt
            
            pcall(function()
                r.CFrame = CFrame.new(nextPos)
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end)
            
            task.wait(hopGap)
            
            local check = root()
            local pulled = state.PulledAt > pulledBefore or (check and (check.Position - nextPos).Magnitude > 30)
            
            if pulled then
                retries += 1
                hopGap = math.min(CFG.HopGapMax, hopGap + 0.01)
                if retries > CFG.HopRetries then break end
                task.wait(0.1)
            else
                hopGap = math.max(CFG.HopGapMin, hopGap - 0.001)
            end
        end
    end

    if hum() then hum():Move(Vector3.zero, false) end
    pcall(function() cam.CameraType = oldCamType end)
    return true
end

-- ★ 多重発火（プロンプト＋モジュール＋リモート）
local function multiFireGrab(uid, pos)
    local r = root()
    if r then
        pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
    end
    
    local slotKey = nil
    local AreaEggSlotIdentity = safeRequire(function() return ReplicatedStorage.Shared.Util.AreaEggSlotIdentity end)
    if AreaEggSlotIdentity and AreaEggSlotIdentity.LooksLikeFirstAreaUid and AreaEggSlotIdentity.LooksLikeFirstAreaUid(uid) then
        slotKey = AreaEggSlotIdentity.SlotKey("Forest", "Nest1") -- Fallback
    end

    local carryRemote = remote("RF/EggWorld/AskFieldEggCarry")
    if carryRemote and carryRemote:IsA("RemoteFunction") then
        pcall(function() carryRemote:InvokeServer({ Uid = uid, FirstAreaSlotKey = slotKey }) end)
    end
    
    pcall(function()
        if EggState and EggState.CarryFieldEgg then
            EggState.CarryFieldEgg(uid, slotKey)
        end
    end)

    local prompt = promptNear(pos, 15)
    if prompt and typeof(fireproximityprompt) == "function" then
        pcall(function() prompt.HoldDuration = 0 end)
        pcall(fireproximityprompt, prompt)
    end
    end-- ============================================================
-- Part 3/5: Guard-Hit Sync & Steal Logic
-- ============================================================
local function isPlayerCarryingEgg()
    local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
    local dropGui = pg and pg:FindFirstChild("DropHeldEgg")
    if dropGui and dropGui.Enabled == true then return true end

    local char = localPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                if t:GetAttribute("Uid") ~= nil or t:GetAttribute("AssetCategory") ~= nil then return true end
                local tName = t.Name:lower()
                if tName:find("egg") then return true end
            end
        end
    end
    return false
end

local function stealAndDeliver(uid, retry)
    if state.Busy then return false end
    state.Busy = true
    state.Cancel = false
    local attempts = retry and CFG.MaxRetries or 1
    local succeeded = false
    
    for attempt = 1, attempts do
        if state.Cancel then break end
        local started = os.clock()
        
        local targetRecord = nil
        for _, r in ipairs(snapshot(true)) do 
            if r.Uid == uid then targetRecord = r; break end 
        end
        
        if not targetRecord then status("卵が見つかりません"); break end
        local eggPos = targetRecord.BottomCFrame.Position
        
        status("卵へ移動中" .. (attempt > 1 and (" (" .. attempt .. ")") or ""))
        hopTo(eggPos, function() return state.Cancel end)
        
        if state.Cancel then break end

        -- 1. 最初の掴み（多重発火）
        status("掴み中...")
        local tStart = os.clock()
        local carried = false
        
        while os.clock() - tStart < CFG.GrabTimeout and not state.Cancel do
            multiFireGrab(uid, eggPos)
            task.wait(0.1)
            if isPlayerCarryingEgg() then carried = true; break end
        end
        
        if not carried then
            status("掴めませんでした")
        else
            -- ★ 2. ガードヒット同期（わざと殴られてサーバーと同期する）
            status("ガードヒット同期中...")
            local tGuardStart = os.clock()
            local startHealth = 100
            local h0 = hum()
            if h0 then startHealth = h0.Health end
            local wasHit = false

            -- 4秒間、卵を持ったままガードの近くで待つ
            while os.clock() - tGuardStart < 4.0 and not state.Cancel do
                if not isPlayerCarryingEgg() then wasHit = true; break end
                local h = hum()
                if h then
                    local hs = h:GetState()
                    if h.Health < startHealth - 1.5 or hs == Enum.HumanoidStateType.Physics or hs == Enum.HumanoidStateType.Ragdoll or hs == Enum.HumanoidStateType.FallingDown then
                        wasHit = true
                        -- ラグドール中は少し待つ
                        local tPost = os.clock()
                        while os.clock() - tPost < 0.85 and not state.Cancel do
                            if not isPlayerCarryingEgg() then break end
                            task.wait(0.05)
                        end
                        break
                    end
                end
                task.wait(0.05)
            end

            if wasHit then
                status("スタン解除待ち...")
                task.wait(0.65)
                
                -- ラグドール解除を待つ
                local tRag = os.clock()
                while os.clock() - tRag < 3.2 and not state.Cancel do
                    local h = hum()
                    if not h then break end
                    local hs = h:GetState()
                    if hs ~= Enum.HumanoidStateType.Physics and hs ~= Enum.HumanoidStateType.Ragdoll and hs ~= Enum.HumanoidStateType.FallingDown then break end
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                    task.wait(0.12)
                end
                
                task.wait(0.35)
                
                -- 位置を卵の前に戻す
                local hrpNow = root()
                if hrpNow and (hrpNow.Position - eggPos).Magnitude > 14 then
                    pcall(function()
                        hrpNow.CFrame = CFrame.new(eggPos + Vector3.new(0, 1.8, 0))
                        hrpNow.AssemblyLinearVelocity = Vector3.zero
                        hrpNow.AssemblyAngularVelocity = Vector3.zero
                    end)
                    task.wait(0.35)
                end

                -- 完全に立つまで待つ
                local tStand = os.clock()
                while os.clock() - tStand < 1.5 and not state.Cancel do
                    local h = hum()
                    if h and h:GetState() ~= Enum.HumanoidStateType.Physics and h:GetState() ~= Enum.HumanoidStateType.Ragdoll then break end
                    task.wait(0.08)
                end

                -- ガードが眠るのを待つ（再度掴むため）
                local tGuardSleep = os.clock()
                while os.clock() - tGuardSleep < 4.5 and not state.Cancel do
                    local asleep = getGuardState(targetRecord.AreaId, eggPos)
                    if asleep then break end
                    task.wait(0.14)
                end
                task.wait(0.08)

                -- 2回目の掴み（多重発火）
                status("再同期掴み...")
                local tPickup2 = os.clock()
                local reCarried = false
                while os.clock() - tPickup2 < 2.2 and not state.Cancel do
                    if isPlayerCarryingEgg() then reCarried = true; break end
                    multiFireGrab(uid, eggPos)
                    task.wait(0.08)
                end
                
                if isPlayerCarryingEgg() then reCarried = true end
                if not reCarried then
                    status("再掴み失敗")
                    carried = false
                else
                    status("同期成功、帰還中")
                    task.wait(0.12)
                end
            end
        end

        -- 3. 帰還
        if carried and not state.Cancel then
            status("帰還中...")
            hopTo(homePoint(), function() return state.Delivered >= started or not state.Carrying or state.Cancel end)
            
            if not state.Cancel then
                status("納品中...")
                task.wait(0.3)
                dropEgg()
                local waited = 0
                while state.Delivered < started and waited < 2 and not state.Cancel do 
                    waited += RunService.Heartbeat:Wait() 
                end
                if state.Delivered >= started then 
                    succeeded = true; status("納品完了"); break 
                end
            end
        end
        
        if attempt < attempts and not state.Cancel then task.wait(1) end
    end
    state.Busy = false
    return succeeded
end

local autoFilter = { MinRarity = 0, MinValue = 0 }
local blocked = {}
local autoLoop = { Active = false, Thread = nil }

local function pickBest()
    local list = snapshot(true)
    local best, bestVal = nil, -1
    local now = os.clock()
    for _, record in ipairs(list) do
        if not blocked[record.Uid] or now > blocked[record.Uid] then
            local info = describe(record)
            if (autoFilter.MinRarity <= 0 or info.Rarity >= autoFilter.MinRarity) and (autoFilter.MinValue <= 0 or info.Value >= autoFilter.MinValue) then
                if info.Value > bestVal then best, bestVal = record, info.Value end
            end
        end
    end
    return best
end

local function startAutoLoop()
    if autoLoop.Active then return end
    autoLoop.Active = true
    autoLoop.Thread = task.spawn(function()
        while autoLoop.Active and guiRef and guiRef.Parent do
            if not state.Busy then
                local best = pickBest()
                if best then
                    local ok = stealAndDeliver(best.Uid, true)
                    if not ok and not state.Cancel then blocked[best.Uid] = os.clock() + CFG.BlockedSec end
                else
                    status("条件に合う卵なし")
                    task.wait(1)
                end
            end
            task.wait(0.2)
        end
        autoLoop.Active = false
    end)
end

local function stopAutoLoop()
    autoLoop.Active = false
    if autoLoop.Thread then pcall(task.cancel, autoLoop.Thread); autoLoop.Thread = nil end
        end-- ============================================================
-- Part 4/5: UI Construction
-- ============================================================
print("[ShouyuHub] UI 構築開始")
local UI_W, UI_H, UI_H_MIN = 300, 440, 64
guiRef = Instance.new("ScreenGui")
guiRef.Name = "ShouyuHub_LightBlue"
guiRef.ResetOnSpawn = false
guiRef.IgnoreGuiInset = true
guiRef.DisplayOrder = 999999
guiRef.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
guiRef.Parent = localPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame", guiRef)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Size = UDim2.fromOffset(UI_W, UI_H)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = THEME.Bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
local us = Instance.new("UIScale", main)
us.Scale = 0.9
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", main)
stroke.Color = THEME.Accent
stroke.Thickness = 1.5
stroke.Transparency = 0.25

local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, -16, 0, 52)
header.Position = UDim2.fromOffset(8, 8)
header.BackgroundColor3 = THEME.Panel
header.BackgroundTransparency = 0.05
header.BorderSizePixel = 0
header.ZIndex = 5
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
local hS = Instance.new("UIStroke", header)
hS.Color = THEME.Accent
hS.Thickness = 1.2
hS.Transparency = 0.35

local avFrame = Instance.new("Frame", header)
avFrame.Size = UDim2.fromOffset(36, 36)
avFrame.Position = UDim2.fromOffset(8, 8)
avFrame.BackgroundColor3 = THEME.AccentDeep
avFrame.BorderSizePixel = 0
avFrame.ZIndex = 6
Instance.new("UICorner", avFrame).CornerRadius = UDim.new(1, 0)
local avImg = Instance.new("ImageLabel", avFrame)
avImg.Size = UDim2.fromScale(0.88, 0.88)
avImg.Position = UDim2.fromScale(0.06, 0.06)
avImg.BackgroundTransparency = 1
avImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150"
avImg.ZIndex = 7
Instance.new("UICorner", avImg).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -140, 0, 20)
title.Position = UDim2.fromOffset(52, 6)
title.BackgroundTransparency = 1
title.Text = "SHOUYU HUB (Guard Sync)"
title.TextColor3 = THEME.AccentSoft
title.Font = Enum.Font.GothamBlack
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.Position = UDim2.new(1, -70, 0.5, -14)
minBtn.BackgroundColor3 = THEME.AccentDeep
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = THEME.AccentSoft
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.ZIndex = 6
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = THEME.AccentDeep
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = THEME.AccentSoft
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.ZIndex = 6
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local body = Instance.new("Frame", main)
body.Size = UDim2.new(1, -16, 1, -68)
body.Position = UDim2.fromOffset(8, 68)
body.BackgroundTransparency = 1
body.ZIndex = 5

statusLabel = Instance.new("TextLabel", body)
statusLabel.Size = UDim2.new(1, -4, 0, 20)
statusLabel.Position = UDim2.fromOffset(4, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "待機中"
statusLabel.TextColor3 = THEME.TextDim
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 6

local list = Instance.new("ScrollingFrame", body)
list.Size = UDim2.new(1, -4, 1, -130)
list.Position = UDim2.fromOffset(2, 24)
list.BackgroundColor3 = THEME.Panel
list.BackgroundTransparency = 0.15
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.ScrollBarImageColor3 = THEME.Accent
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 5
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 10)
local lLayout = Instance.new("UIListLayout", list)
lLayout.Padding = UDim.new(0, 4)
lLayout.SortOrder = Enum.SortOrder.LayoutOrder

local RARITY_COLORS = {
    Color3.fromRGB(190, 190, 190), Color3.fromRGB(110, 210, 110),
    Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255),
    Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 235, 235),
}
local function rarityColor(n) return RARITY_COLORS[math.clamp(tonumber(n) or 1, 1, #RARITY_COLORS)] or THEME.Text end
local selectedUid = nil
local rows = {}

local function setSelected(uid)
    selectedUid = uid
    for rowUid, row in pairs(rows) do
        local on = rowUid == uid
        row.Stroke.Thickness = on and 2.2 or 1
        row.Stroke.Color = on and THEME.Accent or THEME.Stroke
        row.Stroke.Transparency = on and 0 or 0.6
        row.Frame.BackgroundColor3 = on and THEME.AccentDeep or THEME.Card
    end
end

local function createRow(info)
    local frame = Instance.new("TextButton", list)
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = THEME.Card
    frame.BorderSizePixel = 0
    frame.Text = ""
    frame.AutoButtonColor = true
    frame.LayoutOrder = info.Rarity or 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local fS = Instance.new("UIStroke", frame)
    fS.Color = THEME.Stroke
    fS.Thickness = 1
    fS.Transparency = 0.6
    local icon = Instance.new("ImageLabel", frame)
    icon.Size = UDim2.fromOffset(34, 34)
    icon.Position = UDim2.fromOffset(4, 5)
    icon.BackgroundTransparency = 1
    icon.Image = ""
    icon.ScaleType = Enum.ScaleType.Fit
    local name = Instance.new("TextLabel", frame)
    name.Size = UDim2.new(1, -46, 0, 20)
    name.Position = UDim2.fromOffset(44, 3)
    name.BackgroundTransparency = 1
    name.Text = ""
    name.TextColor3 = THEME.Text
    name.Font = Enum.Font.GothamBold
    name.TextSize = 13
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextTruncate = Enum.TextTruncate.AtEnd
    local value = Instance.new("TextLabel", frame)
    value.Size = UDim2.new(1, -46, 0, 16)
    value.Position = UDim2.fromOffset(44, 23)
    value.BackgroundTransparency = 1
    value.Text = ""
    value.TextColor3 = THEME.AccentSoft
    value.Font = Enum.Font.GothamMedium
    value.TextSize = 12
    value.TextXAlignment = Enum.TextXAlignment.Left
    local row = { Frame = frame, Stroke = fS, Icon = icon, Name = name, Value = value }
    frame.MouseButton1Click:Connect(function()
        setSelected(info.Uid)
        status("選択中: " .. tostring(name.Text))
    end)
    rows[info.Uid] = row
    return row
end

local function updateRow(row, info)
    if row.Name.Text ~= info.Name then row.Name.Text = info.Name end
    local c = rarityColor(info.Rarity)
    if row.Name.TextColor3 ~= c then row.Name.TextColor3 = c end
    local moneyStr = money(info.Value)
    if row.Value.Text ~= moneyStr then row.Value.Text = moneyStr end
    if info.Icon ~= "" and row.Icon.Image ~= info.Icon then row.Icon.Image = info.Icon end
end

local function rebuild()
    local infos = {}
    local ok, records = pcall(snapshot)
    if ok and type(records) == "table" then
        for _, record in ipairs(records) do
            local okD, info = pcall(describe, record)
            if okD and info then infos[#infos + 1] = info end
        end
    end
    table.sort(infos, function(a, b) return (a.Value or 0) > (b.Value or 0) end)
    local seen = {}
    for i, info in ipairs(infos) do
        seen[info.Uid] = true
        local row = rows[info.Uid]
        if not row then row = createRow(info) end
        updateRow(row, info)
        if row.Frame.LayoutOrder ~= i then row.Frame.LayoutOrder = i end
    end
    for uid, row in pairs(rows) do
        if not seen[uid] then row.Frame:Destroy(); rows[uid] = nil end
    end
    setSelected(selectedUid and rows[selectedUid] and selectedUid or nil)
end

local function mkBtn(text, pos, size, color)
    local b = Instance.new("TextButton", body)
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = THEME.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = true
    b.ZIndex = 6
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke", b)
    s.Color = THEME.Accent
    s.Thickness = 1.2
    s.Transparency = 0.4
    return b
end

local autoBtn    = mkBtn("自動盗み: OFF", UDim2.new(0, 0, 1, -144), UDim2.new(1, 0, 0, 44), THEME.Card)
local refreshBtn = mkBtn("更新",         UDim2.new(0, 0, 1, -96),  UDim2.new(0.4, -2, 0, 44), THEME.Card)
local instantBtn = mkBtn("即盗み",        UDim2.new(0.4, 2, 1, -96), UDim2.new(0.6, -2, 0, 44), THEME.AccentDeep)
local minValBtn  = mkBtn("Min価値: OFF", UDim2.new(0, 0, 1, -48),  UDim2.new(1, 0, 0, 44), THEME.Card)

autoBtn.MouseButton1Click:Connect(function()
    if autoLoop.Active then
        stopAutoLoop()
        autoBtn.Text = "自動盗み: OFF"
        autoBtn.BackgroundColor3 = THEME.Card
        status("自動盗み停止")
    else
        startAutoLoop()
        autoBtn.Text = "自動盗み: ON"
        autoBtn.BackgroundColor3 = THEME.AccentDeep
        status("自動盗み開始")
    end
end)

refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then rebuild(); status("更新完了") end
end)

instantBtn.MouseButton1Click:Connect(function()
    if state.Busy then
        state.Cancel = true
        if state.StealThread then
            pcall(task.cancel, state.StealThread)
            state.StealThread = nil
        end
        state.Busy = false
        instantBtn.Text = "即盗み"
        instantBtn.BackgroundColor3 = THEME.AccentDeep
        status("キャンセルしました")
        return
    end
    
    if selectedUid then 
        state.Cancel = false
        state.StealThread = task.spawn(function() stealAndDeliver(selectedUid, false) end)
    else 
        status("卵を選んでください") 
    end
end)

local valueSteps = { 0, 5e6, 5e7, 5e8, 5e9 }
local valueIdx = 1
minValBtn.MouseButton1Click:Connect(function()
    valueIdx = valueIdx % #valueSteps + 1
    autoFilter.MinValue = valueSteps[valueIdx]
    local label = autoFilter.MinValue == 0 and "OFF" or money(autoFilter.MinValue):gsub("/s", "")
    minValBtn.Text = "Min価値: " .. label
    status("Min価値: " .. label)
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(main, TweenInfo.new(0.25), { Size = UDim2.fromOffset(UI_W, UI_H_MIN) }):Play()
        task.delay(0.12, function() body.Visible = false end)
    else
        body.Visible = true
        TweenService:Create(main, TweenInfo.new(0.25), { Size = UDim2.fromOffset(UI_W, UI_H) }):Play()
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    if state.StealThread then pcall(task.cancel, state.StealThread) end
    state.Cancel = true
    stopAutoLoop()
    guiRef:Destroy()
end)

local drag, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = true; dragStart = input.Position; startPos = main.Position
    end
end)
header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if not drag then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end)-- ============================================================
-- Part 5/5: Init
-- ============================================================
task.spawn(function()
    while guiRef.Parent do
        task.wait(CFG.AutoRefresh)
        if not state.Busy then pcall(rebuild) end
    end
end)

task.spawn(function()
    while guiRef.Parent do
        task.wait(0.2)
        if state.Busy then
            instantBtn.Text = "キャンセル"
            instantBtn.BackgroundColor3 = THEME.Danger
        else
            instantBtn.Text = "即盗み"
            instantBtn.BackgroundColor3 = THEME.AccentDeep
        end
    end
end)

task.spawn(function()
    task.wait(0.3)
    pcall(rebuild)
    status("待機中")
end)

print("[ShouyuHub] 起動完了 (Guard-Hit Sync & Multi-Fire)")
