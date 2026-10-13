-- ============================================================
-- SHOUYU Steal - 完全新規版
-- Part 1/5 : セットアップ + Shield
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local localPlayer = Players.LocalPlayer

-- ★ 速度設定
local MOVE_SPEED = 3500      -- 走る速度（TPの1.515倍より遥かに速い）
local HOME_SPEED = 3500      -- 家に帰る速度
local HIGH_Y_OFFSET = 70     -- 上空の高さ

local THEME = {
    Bg          = Color3.fromRGB(13, 10, 14),
    Panel       = Color3.fromRGB(24, 16, 22),
    Card        = Color3.fromRGB(28, 18, 24),
    Accent      = Color3.fromRGB(255, 90, 90),
    AccentDeep  = Color3.fromRGB(80, 20, 30),
    AccentSoft  = Color3.fromRGB(255, 170, 170),
    Stroke      = Color3.fromRGB(120, 40, 50),
    Text        = Color3.fromRGB(240, 230, 235),
    TextDim     = Color3.fromRGB(160, 140, 150),
}

local function safeRequire(getter)
    local ok, result = pcall(function() return require(getter()) end)
    return ok and result or nil
end

local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(name) return networking:FindFirstChild(name) end
local function root()
    local c = localPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- 状態
local state = {
    Carrying = false, Uid = nil, Delivered = 0,
    Busy = false, Cancel = false,
    HeldSeen = 0, GuessedDrop = false,
}

-- Shield（Humanoid Swap）
local shield = { Original = nil, Clone = nil, Links = {}, Conn = nil, Added = nil }

local function shieldControls(h)
    pcall(function()
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        local module = ps and ps:FindFirstChild("PlayerModule")
        if module then
            local controls = require(module):GetControls()
            if type(controls) == "table" then controls.humanoid = h end
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
    if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
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

local function shieldUndo()
    shieldUnlink()
    local c = localPlayer.Character
    local o, cl = shield.Original, shield.Clone
    shield.Original, shield.Clone = nil, nil
    if o and cl and c and o.Parent == nil and cl.Parent == c then
        o.Parent = c
        workspace.CurrentCamera.CameraSubject = o
        shieldControls(o)
        pcall(function() cl:Destroy() end)
        shieldAnimate(c)
    end
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

local function shieldStop()
    if shield.Conn then shield.Conn:Disconnect(); shield.Conn = nil end
    if shield.Added then shield.Added:Disconnect(); shield.Added = nil end
    shieldUndo()
end

print("[SHOUYU] Part1 OK")-- ============================================================
-- Part 2/5 : Carry監視 + 卵ヘルパー
-- ============================================================

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" and type(EggState.CarryChanged.Connect) == "function" then
    EggState.CarryChanged:Connect(function(arg)
        local carrying = type(arg) == "table" and arg.IsCarrying == true
        if carrying and arg.GuardDisabled == true then carrying = false end
        state.GuessedDrop = false
        if carrying then state.HeldSeen = os.clock() end
        if carrying and type(arg.Uid) == "string" then state.Uid = arg.Uid end
        state.Carrying = carrying
    end)
end

pcall(function()
    remote("RE/EggWorld/FieldEggRedeemVerdict").OnClientEvent:Connect(function()
        state.Delivered = os.clock()
    end)
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

local function promptNear(position, radius)
    local best, bestD = nil, radius
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
            local p = c:FindFirstChild("CarryAreaEgg")
            if p and p:IsA("ProximityPrompt") then
                local d = (c.Position - position).Magnitude
                if d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end

local function heldByMe(uid)
    local c = localPlayer.Character
    if type(uid) ~= "string" or not c then return false end
    local egg = workspace:FindFirstChild(uid)
    if not egg then return false end
    for _, d in ipairs(egg:GetDescendants()) do
        if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
            local ok, a, b = pcall(function() return d.Part0, d.Part1 end)
            if ok and ((a and a:IsDescendantOf(c)) or (b and b:IsDescendantOf(c))) then
                return true
            end
        end
    end
    return false
end

task.spawn(function()
    while true do
        task.wait(0.2)
        if not state.Carrying then
            if state.GuessedDrop and heldByMe(state.Uid) then
                state.GuessedDrop, state.Carrying, state.HeldSeen = false, true, os.clock()
            end
        elseif heldByMe(state.Uid) then
            state.HeldSeen = os.clock()
        elseif os.clock() - state.HeldSeen > 0.8 then
            state.Carrying, state.GuessedDrop = false, true
        end
    end
end)

local function snapshot()
    local out = {}
    local ok, result = pcall(function()
        return remote("RF/EggWorld/AskFieldEggSnapshot"):InvokeServer()
    end)
    local records = ok and type(result) == "table" and result.Records or nil
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

local function eggPosition(uid)
    for _, r in ipairs(snapshot()) do
        if r.Uid == uid then return r.BottomCFrame.Position end
    end
    return nil
end

local function describe(r)
    local dir = type(Assets) == "table" and Assets.Directory or nil
    local e = type(dir) == "table" and dir[tostring(r.AssetCategory)] or nil
    local info = { Uid = r.Uid, Name = tostring(r.AssetCategory), Icon = "", Value = 0, Rarity = 0 }
    if type(e) == "table" then
        info.Name = tostring(e.DisplayName or r.AssetCategory)
        local icon = e.Icon
        if icon ~= nil and tostring(icon) ~= "" then
            icon = tostring(icon)
            info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or icon
        end
        if type(e.Rarity) == "table" then
            info.Rarity = tonumber(e.Rarity.RarityNumber or e.Rarity.Rank) or 0
        end
        local scale = tonumber(r.AssetScale) or 1
        local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
        local m = 1
        if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
            local ok, res = pcall(Mutations.EarningsFor, type(r.Mutations) == "table" and r.Mutations or {})
            if ok and type(res) == "number" then m = res end
        end
        info.Value = (tonumber(e.EarningRate) or 0) * factor * m
    end
    return info
end

local function money(v)
    local u = { {1e12,"T"}, {1e9,"B"}, {1e6,"M"}, {1e3,"K"} }
    for _, x in ipairs(u) do
        if v >= x[1] then return string.format("$%.2f%s/s", v/x[1], x[2]) end
    end
    return string.format("$%d/s", math.floor(v + 0.5))
end

local status = function() end

print("[SHOUYU] Part2 OK")-- ============================================================
-- Part 3/5 : 移動ロジック（走る + 帰る）
-- ============================================================

local function lineInfo()
    local w = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
    w = w and w:FindFirstChild("Areas")
    w = w and w:FindFirstChild("SeparationLine")
    local ok = w and w:IsA("BasePart")
    return ok and w.Position.X or 552.2, ok and w.Position.Y or 67.67
end

local function homePoint()
    for _, def in ipairs({
        { { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
        { { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
        { { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
    }) do
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

-- 卵の現在位置
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
    if os.clock() - cache.At >= 0.5 then
        cache.At = os.clock()
        cache.Pos = eggPosition(uid) or cache.Pos
    end
    return cache.Pos
end

-- ★ 走って卵まで行く（速度3500）
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

    local r = root()
    if not r then return false end
    local stage = "field"
    -- 自陣側にいるなら一旦セーフゾーン経由
    if r.Position.X < lineX - 2
        and Vector3.new(r.Position.X - home.X, 0, r.Position.Z - home.Z).Magnitude > 20 then
        stage = "safe"
    end

    local started = os.clock()
    local lastCheck, lastPos, lastTake = started, r.Position, 0

    while os.clock() - started < 120 and not state.Cancel do
        r = root()
        if not r then return false end

        local flatEgg = Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z)
        if stage == "field" and flatEgg.Magnitude <= 3 then break end

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
        -- ★ 速度3500で移動
        local v = unit * MOVE_SPEED
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, r.AssemblyLinearVelocity.Y, v.Z)
            if h and unit.Magnitude > 0 then h:Move(unit, false) end
        end)

        -- 詰まったらジャンプ
        if os.clock() - lastCheck >= 1.5 then
            if (r.Position - lastPos).Magnitude < 3 and h and flatEgg.Magnitude > 15 then
                pcall(function() h.Jump = true end)
            end
            lastPos, lastCheck = r.Position, os.clock()
        end

        -- 近づいたら取得リクエスト
        if stage == "field" and flatEgg.Magnitude <= 9 and os.clock() - lastTake > 0.1 then
            lastTake = os.clock()
            takeEgg(uid)
        end

        RunService.Heartbeat:Wait()
    end

    r = root()
    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
            if h then h:Move(Vector3.zero, false) end
        end)
    end
    return state.Carrying
        or (r ~= nil and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
end

-- ★ 卵を掴む（速度3500で接近）
local function grab(uid, timeout)
    local cache = { At = 0 }
    local waited, since = 0, 1
    while not state.Carrying and waited < timeout and not state.Cancel do
        local r = root()
        local egg = eggNow(uid, cache)
        local dt = math.max(RunService.Heartbeat:Wait(), 1/240)
        waited += dt
        since += dt

        if r and egg then
            local delta = egg - r.Position
            if delta.Magnitude > 2 then
                local v = delta / math.max(0.08, dt)
                if v.Magnitude > MOVE_SPEED then v = v.Unit * MOVE_SPEED end
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
    local r = root()
    if r then pcall(function() r.AssemblyLinearVelocity = Vector3.zero end) end
    return state.Carrying and state.Uid == uid
end

-- ★ 家まで実際に飛んで移動（TPなし、速度3500）
local function flyHome(uid)
    local started = os.clock()
    local home = homePoint()
    local r = root()
    if not r then return false end

    local c = localPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.PlatformStand = true end

    -- Step1: 上空へ上昇
    local highY = math.max(r.Position.Y, home.Y) + HIGH_Y_OFFSET
    local t1 = os.clock()
    while os.clock() - t1 < 10 and not state.Cancel do
        if not state.Carrying and state.Delivered < started then
            if h then h.PlatformStand = false end
            return false
        end
        r = root()
        if not r then
            if h then h.PlatformStand = false end
            return false
        end
        local d = Vector3.new(0, highY - r.Position.Y, 0)
        if d.Magnitude < 3 then break end
        local v = d.Unit * math.min(HOME_SPEED, d.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = v
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    -- Step2: 家の上空へ水平移動
    local t2 = os.clock()
    while os.clock() - t2 < 15 and not state.Cancel do
        if not state.Carrying and state.Delivered < started then
            if h then h.PlatformStand = false end
            return false
        end
        r = root()
        if not r then
            if h then h.PlatformStand = false end
            return false
        end
        local flat = Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z)
        if flat.Magnitude < 6 then break end
        local v = flat.Unit * math.min(HOME_SPEED, flat.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    -- Step3: 家へ降下
    local t3 = os.clock()
    while os.clock() - t3 < 15 and not state.Cancel do
        if not state.Carrying and state.Delivered < started then
            if h then h.PlatformStand = false end
            return false
        end
        r = root()
        if not r then
            if h then h.PlatformStand = false end
            return false
        end
        local d = home - r.Position
        if d.Magnitude < 5 then break end
        local v = d.Unit * math.min(HOME_SPEED, d.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = v
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if h then h.PlatformStand = false end
    task.wait(0.2)

    if state.Carrying then
        status("Dropping the egg")
        dropEgg()
        local waited = 0
        while state.Carrying and waited < 1 and not state.Cancel do
            waited += RunService.Heartbeat:Wait()
        end
    end

    return state.Delivered >= started or not state.Carrying
end

-- ============================================================
-- stealAndDeliver
-- ============================================================
local function stealAndDeliver(uid)
    if state.Busy then return end
    state.Busy = true
    state.Cancel = false
    task.spawn(function()
        local ok, err = pcall(function()
            status("Looking for the egg")
            local egg = eggPosition(uid)
            if not egg then
                status("That egg is gone")
                return
            end
            if state.Carrying and state.Uid ~= uid then
                dropEgg()
                local waited = 0
                while state.Carrying and waited < 1 do
                    waited += RunService.Heartbeat:Wait()
                end
            end

            status("Going to the egg")
            if not runToEgg(uid, egg) then
                status("Could not reach the egg")
                return
            end

            status("Taking the egg")
            if not grab(uid, 4) then
                status("The egg would not come free")
                return
            end

            status("Flying home")
            local delivered = flyHome(uid)
            status(delivered and "Delivered" or "Delivery failed")
        end)
        if not ok then
            status("Error: " .. tostring(err))
        end
        state.Busy = false
    end)
end

print("[SHOUYU] Part3 OK")-- ============================================================
-- Part 4/5 : SHOUYU UI 前半
-- ============================================================
local function parentGui()
    if typeof(gethui) == "function" then
        local ok, r = pcall(gethui)
        if ok and typeof(r) == "Instance" then return r end
    end
    return CoreGui
end

local function make(class, props)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

local function corner(p, r)
    make("UICorner", { CornerRadius = UDim.new(0, r or 8) }).Parent = p
end

local living = {}
local function bands(a, b)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, a),
        ColorSequenceKeypoint.new(0.25, b),
        ColorSequenceKeypoint.new(0.5, a),
        ColorSequenceKeypoint.new(0.75, b),
        ColorSequenceKeypoint.new(1, a),
    })
end

local function livingStroke(parent, thickness, bright)
    local s = make("UIStroke", {
        Thickness = thickness or 1,
        Color = bright and THEME.AccentSoft or THEME.Stroke,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    s.Parent = parent
    local g = make("UIGradient", {
        Rotation = 45,
        Color = bands(bright and THEME.AccentSoft or THEME.Stroke, THEME.Bg),
    })
    g.Parent = s
    living[#living + 1] = g
    return s, g
end

local function livingText(label)
    local g = make("UIGradient", { Color = bands(THEME.Text, THEME.AccentSoft) })
    g.Parent = label
    living[#living + 1] = g
    return g
end

local function txt(parent, props)
    local alive = props.Living ~= false
    props.Living = nil
    props.BackgroundTransparency = 1
    props.TextColor3 = props.TextColor3 or THEME.Text
    local l = make("TextLabel", props)
    l.Parent = parent
    if alive then livingText(l) end
    return l
end

local old = parentGui():FindFirstChild("ShouyuStealUI")
if old then old:Destroy() end

local gui = make("ScreenGui", {
    Name = "ShouyuStealUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
})
gui.Parent = parentGui()

local UI_W, UI_H, UI_H_MIN = 300, 420, 60
local window = make("Frame", {
    Size = UDim2.fromOffset(UI_W, UI_H),
    Position = UDim2.new(0.5, -UI_W/2, 0.5, -UI_H/2),
    BackgroundColor3 = THEME.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})
window.Parent = gui
corner(window, 14)
livingStroke(window, 2, true)

-- 回転アニメ
local tick, rot = 0, 0
local shineConn = RunService.Heartbeat:Connect(function(dt)
    tick += 1
    if tick % 2 ~= 0 then return end
    rot = (rot + dt * 60) % 360
    for _, g in ipairs(living) do
        if g.Parent then
            g.Rotation = g.Parent:IsA("UIStroke") and (45 + rot) % 360 or rot
        end
    end
end)

-- ヘッダー
local header = make("Frame", {
    Size = UDim2.new(1, -10, 0, 52),
    Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = THEME.Panel,
    BorderSizePixel = 0,
})
header.Parent = window
corner(header, 10)

local avatarFrame = make("Frame", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(7, 7),
    BackgroundColor3 = THEME.AccentDeep,
    BorderSizePixel = 0,
})
avatarFrame.Parent = header
corner(avatarFrame, 19)
local avatarImg = make("ImageLabel", {
    Size = UDim2.fromScale(0.88, 0.88),
    Position = UDim2.fromScale(0.06, 0.06),
    BackgroundTransparency = 1,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150",
    Parent = avatarFrame,
})
corner(avatarImg, 19)

txt(header, {
    Size = UDim2.new(1, -100, 0, 20),
    Position = UDim2.fromOffset(52, 6),
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "SHOUYU HUB",
    TextColor3 = THEME.AccentSoft,
    Living = false,
})
txt(header, {
    Size = UDim2.new(1, -100, 0, 14),
    Position = UDim2.fromOffset(52, 28),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "STEAL AN EGG - " .. MOVE_SPEED,
    TextColor3 = THEME.TextDim,
    Living = false,
})

local minBtn = make("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -66, 0.5, -14),
    BackgroundColor3 = THEME.AccentDeep,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = THEME.AccentSoft,
    Text = "−",
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
minBtn.Parent = header
corner(minBtn, 7)
livingStroke(minBtn, 1, false)

local closeBtn = make("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -34, 0.5, -14),
    BackgroundColor3 = THEME.AccentDeep,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = THEME.AccentSoft,
    Text = "×",
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
closeBtn.Parent = header
corner(closeBtn, 7)

-- ボディ
local body = make("Frame", {
    Size = UDim2.new(1, -10, 1, -67),
    Position = UDim2.fromOffset(5, 62),
    BackgroundTransparency = 1,
})
body.Parent = window

local statusLabel = txt(body, {
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.fromOffset(2, 0),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "Pick a pet",
    TextColor3 = THEME.TextDim,
})

local list = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -76),
    Position = UDim2.fromOffset(0, 20),
    BackgroundColor3 = THEME.Panel,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = THEME.Accent,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = body
corner(list, 10)
livingStroke(list, 1, false)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = list
make("UIPadding", {
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5),
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 6),
}).Parent = list

print("[SHOUYU] Part4 OK")-- ============================================================
-- Part 5/5 : SHOUYU UI 後半 + 起動
-- ============================================================
local RARITY_COLORS = {
    Color3.fromRGB(190, 190, 190), Color3.fromRGB(110, 210, 110),
    Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255),
    Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 235, 235),
}

local selectedUid = nil
local rows = {}

local function setSelected(uid)
    selectedUid = uid
    for rowUid, row in pairs(rows) do
        local on = rowUid == uid
        row.Stroke.Thickness = on and 2 or 1
        row.Stroke.Color = on and THEME.Accent or THEME.Stroke
        row.Frame.BackgroundColor3 = on and THEME.AccentDeep or THEME.Card
    end
end

local function rebuild()
    for _, row in pairs(rows) do
        pcall(function() row.Frame:Destroy() end)
    end
    table.clear(rows)
    for i = #living, 1, -1 do
        if not living[i].Parent then table.remove(living, i) end
    end

    local infos = {}
    for _, r in ipairs(snapshot()) do
        local ok, info = pcall(describe, r)
        if ok and info then infos[#infos + 1] = info end
    end
    table.sort(infos, function(a, b) return (a.Value or 0) > (b.Value or 0) end)

    local still = false
    for index, info in ipairs(infos) do
        still = still or info.Uid == selectedUid
        local frame = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = THEME.Card,
            LayoutOrder = index,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
        })
        frame.Parent = list
        corner(frame, 8)
        local rowStroke = livingStroke(frame, 1, false)

        make("ImageLabel", {
            Size = UDim2.fromOffset(34, 34),
            Position = UDim2.fromOffset(5, 5),
            BackgroundTransparency = 1,
            Image = info.Icon,
            ScaleType = Enum.ScaleType.Fit,
        }).Parent = frame

        txt(frame, {
            Size = UDim2.new(1, -48, 0, 18),
            Position = UDim2.fromOffset(44, 4),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = info.Name,
            TextColor3 = RARITY_COLORS[math.clamp(info.Rarity or 1, 1, #RARITY_COLORS)] or THEME.Text,
        })
        txt(frame, {
            Size = UDim2.new(1, -48, 0, 14),
            Position = UDim2.fromOffset(44, 24),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = money(info.Value or 0),
            TextColor3 = THEME.AccentSoft,
        })

        rows[info.Uid] = { Frame = frame, Stroke = rowStroke }
        frame.MouseButton1Click:Connect(function()
            setSelected(info.Uid)
            statusLabel.Text = "Selected: " .. info.Name
        end)
    end
    setSelected(still and selectedUid or nil)
    if #infos == 0 then statusLabel.Text = "No eggs on field" end
end

-- ステータス表示
status = function(msg)
    msg = tostring(msg)
    local PUBLIC = {
        ["Pick a pet"] = true,
        ["Looking for the egg"] = true,
        ["Going to the egg"] = true,
        ["Taking the egg"] = true,
        ["Flying home"] = true,
        ["Dropping the egg"] = true,
        ["Delivered"] = true,
        ["Delivery failed"] = true,
        ["That egg is gone"] = true,
        ["Could not reach the egg"] = true,
        ["The egg would not come free"] = true,
        ["Cancelling"] = true,
    }
    if PUBLIC[msg] or string.sub(msg, 1, 9) == "Selected:" then
        statusLabel.Text = msg
    elseif string.sub(msg, 1, 5) == "Error" then
        statusLabel.Text = "Something went wrong"
    elseif state.Busy then
        statusLabel.Text = "Working..."
    end
end

-- ボタン
local function mkBtn(text, pos, size, color)
    local b = make("TextButton", {
        Size = size, Position = pos,
        BackgroundColor3 = color,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = THEME.Text,
        Text = text,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    })
    b.Parent = body
    corner(b, 10)
    livingStroke(b, 1, true)
    return b
end

local refreshBtn = mkBtn("更新", UDim2.new(0, 0, 1, -44), UDim2.new(0.4, -3, 0, 38), THEME.Card)
local stealBtn   = mkBtn("Steal", UDim2.new(0.4, 3, 1, -44), UDim2.new(0.6, -3, 0, 38), THEME.AccentDeep)

refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then
        rebuild()
        statusLabel.Text = "Refreshed"
    end
end)

stealBtn.MouseButton1Click:Connect(function()
    if state.Busy then
        state.Cancel = true
        statusLabel.Text = "Cancelling"
        return
    end
    if not selectedUid then
        statusLabel.Text = "Pick a pet"
        return
    end
    stealAndDeliver(selectedUid)
end)

-- 最小化
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    window.Size = minimized and UDim2.fromOffset(UI_W, UI_H_MIN) or UDim2.fromOffset(UI_W, UI_H)
    minBtn.Text = minimized and "+" or "−"
end)

closeBtn.MouseButton1Click:Connect(function()
    state.Cancel = true
    shieldStop()
    shineConn:Disconnect()
    gui:Destroy()
end)

-- ドラッグ
do
    local dragging, startPos, startInput
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, window.Position, input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Stealボタン状態
task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        stealBtn.Text = state.Busy and "Cancel" or "Steal"
        stealBtn.BackgroundColor3 = state.Busy and Color3.fromRGB(140, 20, 30) or THEME.AccentDeep
    end
end)

-- 自動更新
task.spawn(function()
    while gui.Parent do
        task.wait(4)
        if not state.Busy and not minimized then
            pcall(rebuild)
        end
    end
end)

-- 起動
shieldStart()
task.spawn(function()
    task.wait(0.5)
    pcall(rebuild)
end)

print("[SHOUYU] 起動完了 / 移動速度 " .. MOVE_SPEED .. " / 帰宅速度 " .. HOME_SPEED)
-- ============================================================
-- Part 7 : 置いて拾い直しループ（検知対策）
-- 卵を持ってる間、0.5秒おきにドロップ→再取得を繰り返す
-- ============================================================
task.spawn(function()
    -- 家の座標
    local function getHome()
        for _, def in ipairs({
            { { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
            { { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
            { { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
        }) do
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

    local function getRoot()
        local c = localPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function takeEgg(uid)
        if type(uid) ~= "string" then return end
        local ok = pcall(function()
            local EggState = require(ReplicatedStorage.Client.EggState)
            if type(EggState) == "table" and type(EggState.CarryFieldEgg) == "function" then
                EggState.CarryFieldEgg(uid)
            end
        end)
    end

    local function dropEgg()
        pcall(function()
            local EggState = require(ReplicatedStorage.Client.EggState)
            if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
                EggState.DropFieldEgg("PlayerRequest")
            end
        end)
    end

    -- 状態
    local lastCarry = false
    local placeCycleAt = 0

    while true do
        task.wait(0.1)

        -- Part 2 の state を参照
        if type(state) ~= "table" then
            task.wait(1)
            continue
        end

        -- 卵を持ち始めた
        if state.Carrying and not lastCarry then
            placeCycleAt = os.clock() + 0.5
            lastCarry = true
        end
        -- 卵を離した
        if not state.Carrying and lastCarry then
            lastCarry = false
        end

        -- 卵を持ってる間だけ 0.5秒おきにループ
        if state.Carrying and state.Uid and os.clock() >= placeCycleAt then
            placeCycleAt = os.clock() + 0.5

            local r = getRoot()
            if r then
                local home = getHome()
                local distHome = (r.Position - home).Magnitude
                -- 家に近づいたら止める（納品直前を邪魔しない）
                if distHome > 15 then
                    -- ドロップ
                    dropEgg()
                    -- 0.08秒待つ
                    task.wait(0.08)
                    -- 再取得
                    if state.Uid then
                        takeEgg(state.Uid)
                    end
                end
            end
        end
    end
end)

print("[SEC] ★ 置いて拾い直しループ 起動 ★")
print("  卵を持ってる間、0.5秒おきにドロップ→再取得")
print("  家まで15 studs以内になったら停止（納品を邪魔しない）")
