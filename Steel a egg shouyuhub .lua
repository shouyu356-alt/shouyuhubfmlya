-- ============================================================
-- SHOUYU HUB - Steal An Egg 完全版
-- Part 1/3
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local localPlayer = Players.LocalPlayer

-- ============ 設定 ============
local RUN_SPEED = 3500
local GRAB_SPEED = 3500
local RETURN_SPEED = 3500
local REGRAB_INTERVAL = 0.5
local REGRAB_WAIT = 0.1
local HIGH_Y = 70
local FPS = { 60, 30, 0.15 }

-- ============ 色 ============
local T = {
    Bg     = Color3.fromRGB(13, 10, 14),
    Panel  = Color3.fromRGB(24, 16, 22),
    Card   = Color3.fromRGB(28, 18, 24),
    Deep   = Color3.fromRGB(80, 20, 30),
    Accent = Color3.fromRGB(255, 90, 90),
    Soft   = Color3.fromRGB(255, 170, 170),
    Stroke = Color3.fromRGB(120, 40, 50),
    Text   = Color3.fromRGB(240, 230, 235),
    Dim    = Color3.fromRGB(160, 140, 150),
}

-- ============ ユーティリティ ============
local function safeReq(g)
    local ok, r = pcall(function() return require(g()) end)
    return ok and r or nil
end

local function mk(cls, props)
    local i = Instance.new(cls)
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

-- ============ ゲームハンドル ============
local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState = safeReq(function() return ReplicatedStorage.Client.EggState end)
local Assets = safeReq(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeReq(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function rem(n) return networking:FindFirstChild(n) end

local function getRoot()
    local c = localPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = localPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ============ 状態 ============
local state = {
    Carrying = false,
    Uid = nil,
    Delivered = 0,
    Busy = false,
    Cancel = false,
    HeldSeen = 0,
}

-- ============ Carry監視 ============
if type(EggState) == "table" and type(EggState.CarryChanged) == "table"
    and type(EggState.CarryChanged.Connect) == "function" then
    EggState.CarryChanged:Connect(function(a)
        local c = type(a) == "table" and a.IsCarrying == true
        if c and a.GuardDisabled == true then c = false end
        if c then state.HeldSeen = os.clock() end
        if c and type(a.Uid) == "string" then state.Uid = a.Uid end
        state.Carrying = c
    end)
end

pcall(function()
    local rf = rem("RE/EggWorld/FieldEggRedeemVerdict")
    if rf then
        rf.OnClientEvent:Connect(function()
            state.Delivered = os.clock()
        end)
    end
end)

-- ============ 卵操作 ============
local function takeEgg(uid)
    if type(uid) ~= "string" then return end
    if type(EggState) == "table" and type(EggState.CarryFieldEgg) == "function" then
        pcall(EggState.CarryFieldEgg, uid)
    end
end

local function dropEgg()
    if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
        pcall(EggState.DropFieldEgg, "PlayerRequest")
    end
end

-- ============ プロンプト検索 ============
local function promptNear(pos, radius)
    local best, bestD = nil, radius
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
            local p = c:FindFirstChild("CarryAreaEgg")
            if p and p:IsA("ProximityPrompt") then
                local d = (c.Position - pos).Magnitude
                if d < bestD then
                    best, bestD = p, d
                end
            end
        end
    end
    return best
end

-- ============ 卵スナップショット ============
local function snapshot()
    local out = {}
    local rf = rem("RF/EggWorld/AskFieldEggSnapshot")
    if not rf or not rf:IsA("RemoteFunction") then return out end
    local ok, res = pcall(rf.InvokeServer, rf)
    local records = ok and type(res) == "table" and res.Records or nil
    if type(records) ~= "table" then return out end
    for _, r in pairs(records) do
        if type(r) == "table" and type(r.Uid) == "string"
            and (r.State == "Slot" or r.State == "Dropped")
            and typeof(r.BottomCFrame) == "CFrame" then
            out[#out + 1] = r
        end
    end
    return out
end

local function eggPos(uid)
    for _, r in ipairs(snapshot()) do
        if r.Uid == uid then return r.BottomCFrame.Position end
    end
    return nil
end

-- ============ 卵情報 ============
local function describe(r)
    local dir = type(Assets) == "table" and Assets.Directory or nil
    local e = type(dir) == "table" and dir[tostring(r.AssetCategory)] or nil
    local info = {
        Uid = r.Uid,
        Name = tostring(r.AssetCategory),
        Icon = "",
        Value = 0,
        Rarity = 0,
    }
    if type(e) == "table" then
        info.Name = tostring(e.DisplayName or r.AssetCategory)
        local ic = e.Icon
        if ic ~= nil and tostring(ic) ~= "" then
            ic = tostring(ic)
            info.Icon = tonumber(ic) and ("rbxassetid://" .. ic) or ic
        end
        if type(e.Rarity) == "table" then
            info.Rarity = tonumber(e.Rarity.RarityNumber or e.Rarity.Rank) or 0
        end
        local s = tonumber(r.AssetScale) or 1
        local f = s > 5 and (s / 5) ^ 1.2 * 19.637875755794113 or s ^ 1.85
        local m = 1
        if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
            local ok, mr = pcall(Mutations.EarningsFor, type(r.Mutations) == "table" and r.Mutations or {})
            if ok and type(mr) == "number" then m = mr end
        end
        info.Value = (tonumber(e.EarningRate) or 0) * f * m
    end
    return info
end

local function money(v)
    local u = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, x in ipairs(u) do
        if v >= x[1] then
            return string.format("$%.2f%s/s", v / x[1], x[2])
        end
    end
    return string.format("$%d/s", math.floor(v + 0.5))
end

-- ============ 位置 ============
local function lineInfo()
    local w = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
    w = w and w:FindFirstChild("Areas")
    w = w and w:FindFirstChild("SeparationLine")
    local ok = w and w:IsA("BasePart")
    return ok and w.Position.X or 552.2, ok and w.Position.Y or 67.67
end

local function homePoint()
    local defs = {
        { { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
        { { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
        { { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
    }
    for _, def in ipairs(defs) do
        local n = workspace
        for _, name in ipairs(def[1]) do
            n = n and n:FindFirstChild(name) or nil
        end
        if n and n:IsA("BasePart") then
            return n.CFrame:PointToWorldSpace(def[2])
        end
    end
    return Vector3.new(528.7, 70.57, -364.11)
end

-- ============ Shield ============
local shield = { Original = nil, Clone = nil, Links = {}, Conn = nil, Added = nil }

local function shieldControls(h)
    pcall(function()
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        local m = ps and ps:FindFirstChild("PlayerModule")
        if m then
            local c = require(m):GetControls()
            if type(c) == "table" then c.humanoid = h end
        end
    end)
end

local function shieldAnimate(c)
    local a = c and c:FindFirstChild("Animate")
    if a and a:IsA("LocalScript") then
        task.spawn(function()
            a.Enabled = false
            task.wait()
            a.Enabled = true
        end)
    end
end

local function shieldUnlink()
    for _, l in ipairs(shield.Links) do
        pcall(function() l:Disconnect() end)
    end
    table.clear(shield.Links)
end

local groundedStates = {
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.RunningNoPhysics] = true,
    [Enum.HumanoidStateType.Landed] = true,
}

local function grounded(h)
    if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then
        return false
    end
    return groundedStates[h:GetState()] == true
end

local function shieldSwap()
    local c = localPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return end
    if shield.Clone and shield.Clone.Parent == c then return end
    if not grounded(h) then return end
    local clone = h:Clone()
    h.Parent = nil
    clone.Parent = c
    workspace.CurrentCamera.CameraSubject = clone
    shieldControls(clone)
    shieldAnimate(c)
    shield.Original = h
    shield.Clone = clone
    table.insert(shield.Links, clone.Died:Connect(function()
        shieldUnlink()
        shield.Original, shield.Clone = nil, nil
        local cur = localPlayer.Character
        if cur and h.Parent == nil then
            h.Parent = cur
            workspace.CurrentCamera.CameraSubject = h
            shieldControls(h)
        end
        pcall(function() clone:Destroy() end)
        h.Health = 0
    end))
end

local function shieldStart()
    shieldSwap()
    local n = 0
    shield.Conn = RunService.Heartbeat:Connect(function(dt)
        n += dt
        local c = localPlayer.Character
        local missing = not (shield.Clone and c and shield.Clone.Parent == c)
        if (missing and 0.25 or 3) <= n then
            n = 0
            shieldSwap()
        end
    end)
    shield.Added = localPlayer.CharacterAdded:Connect(function(c)
        shieldUnlink()
        shield.Original, shield.Clone = nil, nil
        task.spawn(function()
            c:WaitForChild("Humanoid", 10)
            task.wait(1)
            if shield.Conn and localPlayer.Character == c then
                shieldSwap()
            end
        end)
    end)
end

print("[SHOUYU] Part1 OK")-- ============================================================
-- Part 2/3 : 移動ロジック
-- ============================================================

local function fpsOn()
    if typeof(setfpscap) ~= "function" then return end
    if not _G.SHOUYU_FPS_GEN then _G.SHOUYU_FPS_GEN = 0 end
    _G.SHOUYU_FPS_GEN += 1
    local mine = _G.SHOUYU_FPS_GEN
    task.spawn(function()
        local high = true
        local s = os.clock()
        while _G.SHOUYU_FPS_GEN == mine and os.clock() - s < 60 do
            pcall(setfpscap, high and FPS[1] or FPS[2])
            high = not high
            task.wait(FPS[3])
        end
    end)
end

local function fpsOff()
    if not _G.SHOUYU_FPS_GEN then _G.SHOUYU_FPS_GEN = 0 end
    _G.SHOUYU_FPS_GEN += 1
    if typeof(setfpscap) == "function" then pcall(setfpscap, 240) end
end

-- ============ 走って卵へ（3500） ============
local function runToEgg(uid, egg)
    local lineX = lineInfo()
    local home = homePoint()
    local c = localPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then
        h.PlatformStand = false
        if c:FindFirstChildWhichIsA("Tool") then
            pcall(function() h:UnequipTools() end)
        end
    end

    local r = getRoot()
    if not r then return false end

    local stage = "field"
    if r.Position.X < lineX - 2
        and Vector3.new(r.Position.X - home.X, 0, r.Position.Z - home.Z).Magnitude > 20 then
        stage = "safe"
    end

    local started = os.clock()
    local lastCheck = os.clock()
    local lastPos = r.Position
    local lastTake = 0

    while os.clock() - started < 120 and not state.Cancel do
        r = getRoot()
        if not r then return false end
        local flatEgg = Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z)
        if stage == "field" and flatEgg.Magnitude <= 2.5 then break end

        local target = egg
        if stage == "safe" then
            if Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z).Magnitude <= 6 then
                stage = "field"
            else
                target = home
            end
        end

        local d = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
        local unit = d.Magnitude > 0.01 and d.Unit or Vector3.zero
        local v = unit * math.min(RUN_SPEED, d.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, r.AssemblyLinearVelocity.Y, v.Z)
        end)
        if unit.Magnitude > 0.01 then
            pcall(function()
                r.CFrame = CFrame.lookAt(r.Position, r.Position + unit)
            end)
        end

        if os.clock() - lastCheck >= 1.5 then
            if (r.Position - lastPos).Magnitude < 3 and h and flatEgg.Magnitude > 15 then
                pcall(function() h.Jump = true end)
            end
            lastPos = r.Position
            lastCheck = os.clock()
        end

        if stage == "field" and flatEgg.Magnitude <= 9 and os.clock() - lastTake > 0.1 then
            lastTake = os.clock()
            takeEgg(uid)
        end

        RunService.Heartbeat:Wait()
    end

    r = getRoot()
    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
        end)
    end
    return state.Carrying
        or (r and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
end

-- ============ 掴む（3500） ============
local function grab(uid, timeout)
    local cache = { At = 0, Pos = nil }
    local waited = 0
    local since = 1

    while not state.Carrying and waited < timeout and not state.Cancel do
        local r = getRoot()
        local egg = nil

        local node = workspace:FindFirstChild(uid)
        local slots = workspace:FindFirstChild("AreaEggSlotsClient")
        node = node or (slots and slots:FindFirstChild(uid))

        if node then
            local ok, pos = pcall(function() return node:GetPivot().Position end)
            if ok and pos then
                cache.Pos = pos
                cache.At = os.clock()
                egg = pos
            end
        end

        if not egg then
            if os.clock() - cache.At >= 0.5 then
                cache.At = os.clock()
                cache.Pos = eggPos(uid) or cache.Pos
            end
            egg = cache.Pos
        end

        local dt = math.max(RunService.Heartbeat:Wait(), 1 / 240)
        waited += dt
        since += dt

        if r and egg then
            local delta = egg - r.Position
            if delta.Magnitude > 2 then
                local v = delta / math.max(0.08, dt)
                if v.Magnitude > GRAB_SPEED then
                    v = v.Unit * GRAB_SPEED
                end
                pcall(function()
                    r.AssemblyLinearVelocity = v + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end

            if since >= 0.03 then
                since = 0
                local p = promptNear(egg - Vector3.new(0, 3, 0), 10)
                if p and typeof(fireproximityprompt) == "function" then
                    pcall(function() p.HoldDuration = 0 end)
                    pcall(fireproximityprompt, p)
                end
                task.spawn(takeEgg, uid)
            end
        elseif since >= 0.03 then
            since = 0
            task.spawn(takeEgg, uid)
        end
    end

    local r = getRoot()
    if r then
        pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
    end
    return state.Carrying and state.Uid == uid
end

-- ============ 家へ帰る（3500）+ 0.5秒おきに地面に置いて拾い直す ============
local function flyHomeWithRegrab(uid)
    local started = os.clock()
    local home = homePoint()
    local r = getRoot()
    if not r then return false end

    local h = getHum()
    if h then
        pcall(function()
            h.WalkSpeed = 0
            h.AutoRotate = false
            h.PlatformStand = true
        end)
    end

    local nextRegrab = os.clock() + REGRAB_INTERVAL
    local t = os.clock()

    while state.Carrying and not state.Cancel and os.clock() - t < 40 do
        r = getRoot()
        if not r then break end

        -- ★ 0.5秒おき：地面に置いて拾い直す
        if os.clock() >= nextRegrab then
            nextRegrab = os.clock() + REGRAB_INTERVAL

            -- 一時停止
            pcall(function()
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end)

            -- 地面に落とす
            dropEgg()
            task.wait(REGRAB_WAIT)

            -- 拾い直す
            local curUid = state.Uid or uid
            takeEgg(curUid)

            -- 拾うまで待つ
            local w = 0
            while not state.Carrying and w < 0.4 and not state.Cancel do
                w += RunService.Heartbeat:Wait()
            end
            task.wait(0.05)
        end

        -- 家へ移動
        local d = home - r.Position
        if d.Magnitude < 5 then break end
        local v = d.Unit * math.min(RETURN_SPEED, d.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = v
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        local flat = Vector3.new(d.X, 0, d.Z)
        if flat.Magnitude > 0.01 then
            pcall(function()
                r.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
            end)
        end

        RunService.Heartbeat:Wait()
    end

    r = getRoot()
    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if h then
        pcall(function()
            h.PlatformStand = false
            h.WalkSpeed = 16
            h.AutoRotate = true
        end)
    end
    task.wait(0.2)

    if state.Carrying then
        dropEgg()
        local w = 0
        while state.Carrying and w < 1 and not state.Cancel do
            w += RunService.Heartbeat:Wait()
        end
    end
    return state.Delivered >= started or not state.Carrying
end

-- ============ メイン処理 ============
local function stealAndDeliver(uid)
    if state.Busy then return end
    state.Busy = true-- ============================================================
-- Part 3/3 : UI + 起動
-- ============================================================
local LOGIC = _G.SHOUYU_LOGIC
local state = LOGIC.State

-- ============ ScreenGui配置 ============
local roots = { CoreGui }
if typeof(gethui) == "function" then
    local ok, hui = pcall(gethui)
    if ok and typeof(hui) == "Instance" then
        table.insert(roots, 1, hui)
    end
end
local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
if not pg then pg = localPlayer:WaitForChild("PlayerGui", 5) end
if pg then table.insert(roots, pg) end

for _, root in ipairs(roots) do
    for _, c in ipairs(root:GetChildren()) do
        if c.Name == "ShouyuStealUI" then
            pcall(function() c:Destroy() end)
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuStealUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 2147483647

local placed = false
if pg then
    local ok = pcall(function() gui.Parent = pg end)
    if ok and gui.Parent then placed = true end
end
if not placed then
    for _, root in ipairs(roots) do
        local ok = pcall(function() gui.Parent = root end)
        if ok and gui.Parent then
            placed = true
            break
        end
    end
end
if not placed then
    warn("[SHOUYU] UI配置失敗")
    return
end

print("[SHOUYU] UI親: " .. gui.Parent:GetFullName())

-- ============ ウィンドウ ============
local W, H = 300, 420
local win = mk("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = T.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
})
win.Parent = gui
corner(win, 14)

local ws = mk("UIStroke", {
    Thickness = 2,
    Color = T.Accent,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})
ws.Parent = win

-- ヘッダー
local header = mk("Frame", {
    Size = UDim2.new(1, -10, 0, 52),
    Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
})
header.Parent = win
corner(header, 10)

local avBox = mk("Frame", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(7, 7),
    BackgroundColor3 = T.Deep,
    BorderSizePixel = 0,
})
avBox.Parent = header
corner(avBox, 19)

local avImg = mk("ImageLabel", {
    Size = UDim2.fromScale(0.88, 0.88),
    Position = UDim2.fromScale(0.06, 0.06),
    BackgroundTransparency = 1,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150",
})
avImg.Parent = avBox
corner(avImg, 19)

local title = mk("TextLabel", {
    Size = UDim2.new(1, -100, 0, 20),
    Position = UDim2.fromOffset(52, 6),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "SHOUYU HUB",
    TextColor3 = T.Soft,
})
title.Parent = header

local subtitle = mk("TextLabel", {
    Size = UDim2.new(1, -100, 0, 14),
    Position = UDim2.fromOffset(52, 28),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "STEAL AN EGG - " .. RUN_SPEED,
    TextColor3 = T.Dim,
})
subtitle.Parent = header

local minBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -66, 0.5, -14),
    BackgroundColor3 = T.Deep,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = T.Soft,
    Text = "-",
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
minBtn.Parent = header
corner(minBtn, 7)

local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -34, 0.5, -14),
    BackgroundColor3 = T.Deep,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = T.Soft,
    Text = "X",
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
closeBtn.Parent = header
corner(closeBtn, 7)

-- ボディ
local body = mk("Frame", {
    Size = UDim2.new(1, -10, 1, -67),
    Position = UDim2.fromOffset(5, 62),
    BackgroundTransparency = 1,
})
body.Parent = win

local statusL = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.fromOffset(2, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "Pick a pet",
    TextColor3 = T.Dim,
})
statusL.Parent = body

local list = mk("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -76),
    Position = UDim2.fromOffset(0, 20),
    BackgroundColor3 = T.Panel,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = T.Accent,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = body
corner(list, 10)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 5)
pad.PaddingBottom = UDim.new(0, 5)
pad.PaddingLeft = UDim.new(0, 5)
pad.PaddingRight = UDim.new(0, 6)
pad.Parent = list

-- ボタン
local function mkBtn(text, xS, xO, wS, wO, color)
    local b = mk("TextButton", {
        Size = UDim2.new(wS, wO, 0, 38),
        Position = UDim2.new(xS, xO, 1, -44),
        BackgroundColor3 = color,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.Text,
        Text = text,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    })
    b.Parent = body
    corner(b, 10)
    return b
end

local refreshBtn = mkBtn("更新", 0, 0, 0.4, -3, T.Card)
local stealBtn = mkBtn("Steal", 0.4, 3, 0.6, -3, T.Deep)

-- ============ 卵リスト ============
local RARITY = {
    Color3.fromRGB(190, 190, 190), Color3.fromRGB(110, 210, 110),
    Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255),
    Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 235, 235),
}

local selectedUid = nil
local rows = {}

local function setSel(uid)
    selectedUid = uid
    for ru, row in pairs(rows) do
        local on = ru == uid
        row.Stroke.Thickness = on and 2 or 1
        row.Stroke.Color = on and T.Accent or T.Stroke
        row.Frame.BackgroundColor3 = on and T.Deep or T.Card
    end
end

local function rebuild()
    for _, row in pairs(rows) do
        pcall(function() row.Frame:Destroy() end)
    end
    table.clear(rows)

    local infos = {}
    for _, r in ipairs(LOGIC.Snapshot()) do
        local ok, info = pcall(LOGIC.Describe, r)
        if ok and info then
            infos[#infos + 1] = info
        end
    end
    table.sort(infos, function(a, b)
        return (a.Value or 0) > (b.Value or 0)
    end)

    local still = false
    for i, info in ipairs(infos) do
        still = still or info.Uid == selectedUid
        local f = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = T.Card,
            LayoutOrder = i,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
        })
        f.Parent = list
        corner(f, 8)

        local fs = mk("UIStroke", {
            Thickness = 1,
            Color = T.Stroke,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        fs.Parent = f

        mk("ImageLabel", {
            Size = UDim2.fromOffset(34, 34),
            Position = UDim2.fromOffset(5, 5),
            BackgroundTransparency = 1,
            Image = info.Icon,
            ScaleType = Enum.ScaleType.Fit,
        }).Parent = f

        local nl = mk("TextLabel", {
            Size = UDim2.new(1, -48, 0, 18),
            Position = UDim2.fromOffset(44, 4),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = info.Name,
            TextColor3 = RARITY[math.clamp(info.Rarity or 1, 1, #RARITY)] or T.Text,
        })
        nl.Parent = f

        local vl = mk("TextLabel", {
            Size = UDim2.new(1, -48, 0, 14),
            Position = UDim2.fromOffset(44, 24),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = LOGIC.Money(info.Value or 0),
            TextColor3 = T.Soft,
        })
        vl.Parent = f

        rows[info.Uid] = { Frame = f, Stroke = fs }
        f.MouseButton1Click:Connect(function()
            setSel(info.Uid)
            statusL.Text = "Selected: " .. info.Name
        end)
    end

    setSel(still and selectedUid or nil)
    if #infos == 0 then
        statusL.Text = "No eggs on field"
    end
end

-- ============ 公開 ============
_G.SHOUYU_UI = {
    Gui = gui,
    SetStatus = function(s)
        statusL.Text = tostring(s)
    end,
}

-- ============ ボタン ============
refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then
        rebuild()
        statusL.Text = "Refreshed"
    end
end)

stealBtn.MouseButton1Click:Connect(function()
    if state.Busy then
        state.Cancel = true
        statusL.Text = "Cancelling"
        return
    end
    if not selectedUid then
        statusL.Text = "Pick a pet"
        return
    end
    LOGIC.Steal(selectedUid)
end)

-- ============ ドラッグ ============
do
    local dragging = false
    local startPos = nil
    local startInput = nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = win.Position
            startInput = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- ============ 最小化・閉じる ============
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    win.Size = minimized and UDim2.fromOffset(W, 60) or UDim2.fromOffset(W, H)
    minBtn.Text = minimized and "+" or "-"
end)

closeBtn.MouseButton1Click:Connect(function()
    state.Cancel = true
    gui:Destroy()
end)

-- ============ Stealボタン状態監視 ============
task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        stealBtn.Text = state.Busy and "Cancel" or "Steal"
        stealBtn.BackgroundColor3 = state.Busy
            and Color3.fromRGB(140, 20, 30)
            or T.Deep
    end
end)

-- ============ 自動更新 ============
task.spawn(function()
    while gui.Parent do
        task.wait(4)
        if not state.Busy and not minimized then
            pcall(rebuild)
        end
    end
end)

-- ============ 初回 ============
task.spawn(function()
    task.wait(0.5)
    pcall(rebuild)
end)

-- ============ Shield起動 ============
shieldStart()

print("[SHOUYU] ★ 起動完了 ★")
print("  走る速度: " .. RUN_SPEED)
print("  掴む速度: " .. GRAB_SPEED)
print("  帰り速度: " .. RETURN_SPEED)
print("  拾い直し間隔: " .. REGRAB_INTERVAL .. "秒")
    state.Cancel = false

    task.spawn(function()
        local ok, err = pcall(function()
            local egg = eggPos(uid)
            if not egg then
                if _G.SHOUYU_UI then _G.SHOUYU_UI.SetStatus("Egg not found") end
                return
            end
            if _G.SHOUYU_UI then _G.SHOUYU_UI.SetStatus("Going...") end
            if not runToEgg(uid, egg) then
                if _G.SHOUYU_UI then _G.SHOUYU_UI.SetStatus("Could not reach") end
                return
            end
            if _G.SHOUYU_UI then _G.SHOUYU_UI.SetStatus("Taking...") end
            if not grab(uid, 4) then
                if _G.SHOUYU_UI then _G.SHOUYU_UI.SetStatus("Could not grab") end
                return
            end
            if _G.SHOUYU_UI then _G.SHOUYU_UI.SetStatus("Returning...") end
            fpsOn()
            local delivered = flyHomeWithRegrab(uid)
            fpsOff()
            if _G.SHOUYU_UI then
                _G.SHOUYU_UI.SetStatus(delivered and "Delivered!" or "Failed")
            end
        end)
        if not ok then warn("[SHOUYU] " .. tostring(err)) end
        state.Busy = false
    end)
end

_G.SHOUYU_LOGIC = {
    State = state,
    Snapshot = snapshot,
    Describe = describe,
    Money = money,
    Steal = stealAndDeliver,
    EggPos = eggPos,
}

print("[SHOUYU] Part2 OK")
-- ============================================================
-- Part 3/3 : UI + 起動
-- ============================================================
local LOGIC = _G.SHOUYU_LOGIC
local state = LOGIC.State

-- ============ ScreenGui配置 ============
local roots = { CoreGui }
if typeof(gethui) == "function" then
    local ok, hui = pcall(gethui)
    if ok and typeof(hui) == "Instance" then
        table.insert(roots, 1, hui)
    end
end
local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
if not pg then pg = localPlayer:WaitForChild("PlayerGui", 5) end
if pg then table.insert(roots, pg) end

for _, root in ipairs(roots) do
    for _, c in ipairs(root:GetChildren()) do
        if c.Name == "ShouyuStealUI" then
            pcall(function() c:Destroy() end)
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuStealUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 2147483647

local placed = false
if pg then
    local ok = pcall(function() gui.Parent = pg end)
    if ok and gui.Parent then placed = true end
end
if not placed then
    for _, root in ipairs(roots) do
        local ok = pcall(function() gui.Parent = root end)
        if ok and gui.Parent then
            placed = true
            break
        end
    end
end
if not placed then
    warn("[SHOUYU] UI配置失敗")
    return
end

print("[SHOUYU] UI親: " .. gui.Parent:GetFullName())

-- ============ ウィンドウ ============
local W, H = 300, 420
local win = mk("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = T.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
})
win.Parent = gui
corner(win, 14)

local ws = mk("UIStroke", {
    Thickness = 2,
    Color = T.Accent,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})
ws.Parent = win

-- ヘッダー
local header = mk("Frame", {
    Size = UDim2.new(1, -10, 0, 52),
    Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
})
header.Parent = win
corner(header, 10)

local avBox = mk("Frame", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(7, 7),
    BackgroundColor3 = T.Deep,
    BorderSizePixel = 0,
})
avBox.Parent = header
corner(avBox, 19)

local avImg = mk("ImageLabel", {
    Size = UDim2.fromScale(0.88, 0.88),
    Position = UDim2.fromScale(0.06, 0.06),
    BackgroundTransparency = 1,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150",
})
avImg.Parent = avBox
corner(avImg, 19)

local title = mk("TextLabel", {
    Size = UDim2.new(1, -100, 0, 20),
    Position = UDim2.fromOffset(52, 6),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "SHOUYU HUB",
    TextColor3 = T.Soft,
})
title.Parent = header

local subtitle = mk("TextLabel", {
    Size = UDim2.new(1, -100, 0, 14),
    Position = UDim2.fromOffset(52, 28),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "STEAL AN EGG - " .. RUN_SPEED,
    TextColor3 = T.Dim,
})
subtitle.Parent = header

local minBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -66, 0.5, -14),
    BackgroundColor3 = T.Deep,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = T.Soft,
    Text = "-",
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
minBtn.Parent = header
corner(minBtn, 7)

local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -34, 0.5, -14),
    BackgroundColor3 = T.Deep,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = T.Soft,
    Text = "X",
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
closeBtn.Parent = header
corner(closeBtn, 7)

-- ボディ
local body = mk("Frame", {
    Size = UDim2.new(1, -10, 1, -67),
    Position = UDim2.fromOffset(5, 62),
    BackgroundTransparency = 1,
})
body.Parent = win

local statusL = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.fromOffset(2, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "Pick a pet",
    TextColor3 = T.Dim,
})
statusL.Parent = body

local list = mk("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -76),
    Position = UDim2.fromOffset(0, 20),
    BackgroundColor3 = T.Panel,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = T.Accent,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = body
corner(list, 10)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 5)
pad.PaddingBottom = UDim.new(0, 5)
pad.PaddingLeft = UDim.new(0, 5)
pad.PaddingRight = UDim.new(0, 6)
pad.Parent = list

-- ボタン
local function mkBtn(text, xS, xO, wS, wO, color)
    local b = mk("TextButton", {
        Size = UDim2.new(wS, wO, 0, 38),
        Position = UDim2.new(xS, xO, 1, -44),
        BackgroundColor3 = color,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.Text,
        Text = text,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    })
    b.Parent = body
    corner(b, 10)
    return b
end

local refreshBtn = mkBtn("更新", 0, 0, 0.4, -3, T.Card)
local stealBtn = mkBtn("Steal", 0.4, 3, 0.6, -3, T.Deep)

-- ============ 卵リスト ============
local RARITY = {
    Color3.fromRGB(190, 190, 190), Color3.fromRGB(110, 210, 110),
    Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255),
    Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 235, 235),
}

local selectedUid = nil
local rows = {}

local function setSel(uid)
    selectedUid = uid
    for ru, row in pairs(rows) do
        local on = ru == uid
        row.Stroke.Thickness = on and 2 or 1
        row.Stroke.Color = on and T.Accent or T.Stroke
        row.Frame.BackgroundColor3 = on and T.Deep or T.Card
    end
end

local function rebuild()
    for _, row in pairs(rows) do
        pcall(function() row.Frame:Destroy() end)
    end
    table.clear(rows)

    local infos = {}
    for _, r in ipairs(LOGIC.Snapshot()) do
        local ok, info = pcall(LOGIC.Describe, r)
        if ok and info then
            infos[#infos + 1] = info
        end
    end
    table.sort(infos, function(a, b)
        return (a.Value or 0) > (b.Value or 0)
    end)

    local still = false
    for i, info in ipairs(infos) do
        still = still or info.Uid == selectedUid
        local f = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = T.Card,
            LayoutOrder = i,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
        })
        f.Parent = list
        corner(f, 8)

        local fs = mk("UIStroke", {
            Thickness = 1,
            Color = T.Stroke,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        fs.Parent = f

        mk("ImageLabel", {
            Size = UDim2.fromOffset(34, 34),
            Position = UDim2.fromOffset(5, 5),
            BackgroundTransparency = 1,
            Image = info.Icon,
            ScaleType = Enum.ScaleType.Fit,
        }).Parent = f

        local nl = mk("TextLabel", {
            Size = UDim2.new(1, -48, 0, 18),
            Position = UDim2.fromOffset(44, 4),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = info.Name,
            TextColor3 = RARITY[math.clamp(info.Rarity or 1, 1, #RARITY)] or T.Text,
        })
        nl.Parent = f

        local vl = mk("TextLabel", {
            Size = UDim2.new(1, -48, 0, 14),
            Position = UDim2.fromOffset(44, 24),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = LOGIC.Money(info.Value or 0),
            TextColor3 = T.Soft,
        })
        vl.Parent = f

        rows[info.Uid] = { Frame = f, Stroke = fs }
        f.MouseButton1Click:Connect(function()
            setSel(info.Uid)
            statusL.Text = "Selected: " .. info.Name
        end)
    end

    setSel(still and selectedUid or nil)
    if #infos == 0 then
        statusL.Text = "No eggs on field"
    end
end

-- ============ 公開 ============
_G.SHOUYU_UI = {
    Gui = gui,
    SetStatus = function(s)
        statusL.Text = tostring(s)
    end,
}

-- ============ ボタン ============
refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then
        rebuild()
        statusL.Text = "Refreshed"
    end
end)

stealBtn.MouseButton1Click:Connect(function()
    if state.Busy then
        state.Cancel = true
        statusL.Text = "Cancelling"
        return
    end
    if not selectedUid then
        statusL.Text = "Pick a pet"
        return
    end
    LOGIC.Steal(selectedUid)
end)

-- ============ ドラッグ ============
do
    local dragging = false
    local startPos = nil
    local startInput = nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = win.Position
            startInput = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- ============ 最小化・閉じる ============
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    win.Size = minimized and UDim2.fromOffset(W, 60) or UDim2.fromOffset(W, H)
    minBtn.Text = minimized and "+" or "-"
end)

closeBtn.MouseButton1Click:Connect(function()
    state.Cancel = true
    gui:Destroy()
end)

-- ============ Stealボタン状態監視 ============
task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        stealBtn.Text = state.Busy and "Cancel" or "Steal"
        stealBtn.BackgroundColor3 = state.Busy
            and Color3.fromRGB(140, 20, 30)
            or T.Deep
    end
end)

-- ============ 自動更新 ============
task.spawn(function()
    while gui.Parent do
        task.wait(4)
        if not state.Busy and not minimized then
            pcall(rebuild)
        end
    end
end)

-- ============ 初回 ============
task.spawn(function()
    task.wait(0.5)
    pcall(rebuild)
end)

-- ============ Shield起動 ============
shieldStart()

print("[SHOUYU] ★ 起動完了 ★")
print("  走る速度: " .. RUN_SPEED)
print("  掴む速度: " .. GRAB_SPEED)
print("  帰り速度: " .. RETURN_SPEED)
print("  拾い直し間隔: " .. REGRAB_INTERVAL .. "秒")
