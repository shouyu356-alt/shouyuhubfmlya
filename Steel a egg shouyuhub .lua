-- ============================================================
-- Blood Moon Steal Hub - Rebuild
-- 血月テーマ / スマホ対応 / 自動更新 / 簡単開閉
-- Auto Steal / Instant Steal ロジック: 前回と完全同一
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

------------------------------------------------------------------ 基本設定
local CFG = {
    Speed = 1400,
    GrabInterval = 0.03,
    GrabTimeout = 4,
    PromptRadius = 12,
    StealRadius = 61,
    DropDelay = 0.15,
    FlyTimeout = 20,
    -- ★ 自動更新
    AutoRefreshInterval = 4,   -- 秒
}

------------------------------------------------------------------ ステルス設定
local STEALTH = {
    Enabled = true,
    SpeedJitter = 0.15,
    HopRandomMin = 8,
    HopRandomMax = 25,
    PauseMin = 0.02,
    PauseMax = 0.08,
    LandingJitter = 3,
    MicroJitter = 0.3,
    GrabDelayMin = 0.05,
    GrabDelayMax = 0.2,
    DeliverPause = 0.15,
}

local function rnd(min, max)
    return min + math.random() * (max - min)
end

local function rndJitter(amount)
    return (math.random() * 2 - 1) * amount
end

------------------------------------------------------------------ スマホ判定
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local IS_TABLET = UserInputService.TouchEnabled and UserInputService.MouseEnabled

------------------------------------------------------------------ Blood Moon テーマ
local THEME = {
    Bg          = Color3.fromRGB(12, 4, 6),
    Panel       = Color3.fromRGB(22, 8, 12),
    Card        = Color3.fromRGB(32, 10, 16),
    CardHover   = Color3.fromRGB(45, 15, 22),
    Accent      = Color3.fromRGB(220, 25, 40),
    AccentSoft  = Color3.fromRGB(255, 90, 100),
    AccentDark  = Color3.fromRGB(120, 12, 20),
    AccentDeep  = Color3.fromRGB(60, 5, 10),
    Text        = Color3.fromRGB(250, 235, 235),
    TextDim     = Color3.fromRGB(180, 140, 140),
    Stroke      = Color3.fromRGB(100, 30, 40),
    On          = Color3.fromRGB(240, 50, 60),
    Off         = Color3.fromRGB(90, 60, 65),
}

------------------------------------------------------------------ ゲームハンドル
local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")

local function safeRequire(getter)
    local ok, result = pcall(getter)
    return ok and result or nil
end

local EggState = safeRequire(function()
    return require(ReplicatedStorage.Client.EggState)
end)
local Assets = safeRequire(function()
    return require(ReplicatedStorage.Data.Assets)
end)
local Mutations = safeRequire(function()
    return require(ReplicatedStorage.Shared.Modules.Mutations)
end)

local function remote(name)
    return networking:FindFirstChild(name)
end

local function root()
    local character = localPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------------ 状態
local state = {
    Carrying = false,
    Uid = nil,
    Delivered = 0,
    Busy = false,
    Cancel = false,
    Mult = 1,
    PulledAt = 0,
}

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" then
    EggState.CarryChanged:Connect(function(arg)
        local carrying = type(arg) == "table" and arg.IsCarrying == true
        if carrying and arg.GuardDisabled == true then carrying = false end
        if carrying and type(arg.Uid) == "string" then
            state.Uid = arg.Uid
            local mult = tonumber(arg.SpeedMultiplier)
            if mult and mult > 0 then state.Mult = mult end
        end
        state.Carrying = carrying
    end)
end

pcall(function()
    local ev = remote("RE/EggWorld/FieldEggRedeemVerdict")
    if ev then ev.OnClientEvent:Connect(function()
        state.Delivered = os.clock()
    end) end
end)

pcall(function()
    local ev = remote("RE/RigSync/Refresh")
    if ev then ev.OnClientEvent:Connect(function(arg)
        if type(arg) == "table" and arg.Action == "Relocate" then
            state.PulledAt = os.clock()
        end
    end) end
end)
------------------------------------------------------------------ 卵情報
local function takeEgg(uid)
    if type(uid) == "string" and type(EggState) == "table"
        and type(EggState.CarryFieldEgg) == "function" then
        pcall(EggState.CarryFieldEgg, uid)
    end
end

local function dropEgg()
    if type(EggState) == "table"
        and type(EggState.DropFieldEgg) == "function" then
        pcall(EggState.DropFieldEgg, "PlayerRequest")
    end
end

local function snapshot()
    local list = {}
    local fn = remote("RF/EggWorld/AskFieldEggSnapshot")
    if not fn or not fn:IsA("RemoteFunction") then return list end

    local ok, result = pcall(function() return fn:InvokeServer() end)
    local records = ok and type(result) == "table" and result.Records or nil
    if type(records) ~= "table" then return list end

    for _, record in pairs(records) do
        if type(record) == "table"
            and type(record.Uid) == "string"
            and (record.State == "Slot" or record.State == "Dropped")
            and typeof(record.BottomCFrame) == "CFrame" then
            list[#list + 1] = record
        end
    end
    return list
end

local function eggPosition(uid)
    for _, record in ipairs(snapshot()) do
        if record.Uid == uid then
            return record.BottomCFrame.Position
        end
    end
    return nil
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
    if os.clock() - cache.At >= 0.5 then
        cache.At = os.clock()
        cache.Pos = eggPosition(uid) or cache.Pos
    end
    return cache.Pos
end

local function promptNear(position, radius)
    local best, bestDistance = nil, radius or 12
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
            local prompt = child:FindFirstChild("CarryAreaEgg")
            if prompt and prompt:IsA("ProximityPrompt") then
                local distance = (child.Position - position).Magnitude
                if distance < bestDistance then
                    best, bestDistance = prompt, distance
                end
            end
        end
    end
    return best
end

------------------------------------------------------------------ 座標系
local function lineInfo()
    local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
    world = world and world:FindFirstChild("Areas")
    world = world and world:FindFirstChild("SeparationLine")
    local ok = world and world:IsA("BasePart")
    return ok and world.Position.X or 552.2,
           ok and world.Position.Y or 67.67
end

local function homePoint()
    for _, def in ipairs({
        { { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
        { { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
        { { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
    }) do
        local node = workspace
        for _, name in ipairs(def[1]) do
            node = node and node:FindFirstChild(name) or nil
        end
        if node and node:IsA("BasePart") then
            return node.CFrame:PointToWorldSpace(def[2])
        end
    end
    return Vector3.new(528.7, 70.57, -364.11)
end

local function describe(record)
    local directory = type(Assets) == "table" and Assets.Directory or nil
    local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
    local info = {
        Uid = record.Uid,
        Name = tostring(record.AssetCategory),
        Icon = "", Rarity = 0, Value = 0,
    }
    if type(entry) == "table" then
        info.Name = tostring(entry.DisplayName or record.AssetCategory)
        local icon = entry.Icon
        if icon ~= nil and tostring(icon) ~= "" then
            icon = tostring(icon)
            info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or icon
        end
        if type(entry.Rarity) == "table" then
            info.Rarity = tonumber(entry.Rarity.RarityNumber or entry.Rarity.Rank) or 0
        end
        local scale = tonumber(record.AssetScale) or 1
        local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
        local mutation = 1
        if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
            local okM, resM = pcall(Mutations.EarningsFor,
                type(record.Mutations) == "table" and record.Mutations or {})
            if okM and type(resM) == "number" then mutation = resM end
        end
        info.Value = (tonumber(entry.EarningRate) or 0) * factor * mutation
    end
    return info
end

local function money(value)
    local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, u in ipairs(units) do
        if value >= u[1] then return string.format("$%.2f%s/s", value / u[1], u[2]) end
    end
    return string.format("$%d/s", math.floor(value + 0.5))
end
------------------------------------------------------------------ 空中フライ移動（ステルス版）
local flyState = { Cancel = false }

local function cancelFly() flyState.Cancel = true end
local function resetFly() flyState.Cancel = false end

local function flyTo(target, onCancelCheck)
    local character = localPlayer.Character
    local myRoot = root()
    if not character or not myRoot then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid.PlatformStand = true end)
    end

    local started = os.clock()
    local result = false
    local lastMark = nil
    local lastClock = 0
    local stuckCount = 0

    if STEALTH.Enabled then
        target = target + Vector3.new(
            rndJitter(STEALTH.LandingJitter),
            0,
            rndJitter(STEALTH.LandingJitter)
        )
    end

    while os.clock() - started < CFG.FlyTimeout do
        if flyState.Cancel then break end
        if type(onCancelCheck) == "function" and onCancelCheck() then break end

        local r = root()
        if not r or not r.Parent then break end

        local delta = target - r.Position
        local dist = delta.Magnitude
        if dist <= 2 then result = true; break end

        local dir = dist > 0.01 and delta.Unit or Vector3.zero

        local step
        if STEALTH.Enabled then
            local baseStep = CFG.Speed * (1/60)
            local randomLimit = rnd(STEALTH.HopRandomMin, STEALTH.HopRandomMax)
            step = math.min(baseStep, randomLimit, dist)
        else
            step = math.min(CFG.Speed * (1/60), dist)
        end

        local jitterOffset = STEALTH.Enabled
            and Vector3.new(rndJitter(STEALTH.MicroJitter), 0, rndJitter(STEALTH.MicroJitter))
            or Vector3.zero

        local nextPos = r.Position + dir * step + jitterOffset

        pcall(function()
            r.CFrame = CFrame.new(nextPos) * r.CFrame.Rotation
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)

        if STEALTH.Enabled then
            local pause = rnd(STEALTH.PauseMin, STEALTH.PauseMax)
            if pause > 0.03 then
                task.wait(pause)
            end
        end

        if lastMark and (r.Position - lastMark).Magnitude < 1 then
            stuckCount = stuckCount + 1
            if os.clock() - lastClock > 0.5 or stuckCount > 30 then
                break
            end
        else
            lastMark = r.Position
            lastClock = os.clock()
            stuckCount = 0
        end

        RunService.Heartbeat:Wait()
    end

    if humanoid then
        pcall(function() humanoid.PlatformStand = false end)
    end

    return result
end

------------------------------------------------------------------ 掴む（ステルス版）
local function grab(uid, timeout)
    timeout = timeout or CFG.GrabTimeout
    local cache = { At = 0 }
    local waited, since = 0, 1

    if STEALTH.Enabled then
        task.wait(rnd(STEALTH.GrabDelayMin, STEALTH.GrabDelayMax))
    end

    while not state.Carrying and waited < timeout and not state.Cancel do
        local r = root()
        local egg = eggNow(uid, cache)
        local dt = math.max(RunService.Heartbeat:Wait(), 1/240)
        waited += dt
        since += dt

        if r and egg then
            local delta = egg - r.Position
            if delta.Magnitude > 2 then
                local pace = STEALTH.Enabled and 150 or 200
                local v = delta / math.max(0.08, dt)
                if v.Magnitude > pace then v = v.Unit * pace end
                pcall(function()
                    r.AssemblyLinearVelocity = v + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end

            local interval = STEALTH.Enabled
                and rnd(CFG.GrabInterval, CFG.GrabInterval * 3)
                or CFG.GrabInterval

            if since >= interval then
                since = 0
                local prompt = promptNear(egg - Vector3.new(0, 3, 0), CFG.PromptRadius)
                if prompt and typeof(fireproximityprompt) == "function" then
                    pcall(function() prompt.HoldDuration = 0 end)
                    pcall(fireproximityprompt, prompt)
                end
                task.spawn(takeEgg, uid)
            end
        elseif since >= CFG.GrabInterval then
            since = 0
            task.spawn(takeEgg, uid)
        end
    end

    local r = root()
    if r then pcall(function() r.AssemblyLinearVelocity = Vector3.zero end) end
    return state.Carrying and state.Uid == uid
end

------------------------------------------------------------------ 納品（ステルス版）
local function flyHome(lineX)
    local started = os.clock()
    local home = homePoint()

    local ok = flyTo(home + Vector3.new(0, 3, 0), function()
        return state.Delivered >= started or not state.Carrying
    end)

    if not ok and not state.Carrying then
        return state.Delivered >= started
    end

    if state.Carrying then
        if STEALTH.Enabled then
            task.wait(STEALTH.DeliverPause + rnd(0, 0.1))
        else
            task.wait(CFG.DropDelay)
        end

        dropEgg()
        local waited = 0
        while state.Delivered < started and waited < 1.5 do
            waited += RunService.Heartbeat:Wait()
        end
    end
    return state.Delivered >= started
end
------------------------------------------------------------------ メイン処理（安定化版・前回と同一）
local function stealAndDeliver(uid)
    if state.Busy then return end
    state.Busy = true
    state.Cancel = false
    resetFly()

    task.spawn(function()
        local ok, err = pcall(function()
            if STEALTH.Enabled then
                task.wait(rnd(0.1, 0.4))
            end

            local egg = eggPosition(uid)
            if not egg then return end

            if state.Carrying and state.Uid ~= uid then
                dropEgg()
                local waited = 0
                while state.Carrying and waited < 1 do
                    waited += RunService.Heartbeat:Wait()
                end
            end

            local approachOffset
            if STEALTH.Enabled then
                local angle = math.random() * math.pi * 2
                local radius = rnd(2.5, 4)
                approachOffset = Vector3.new(
                    math.cos(angle) * radius,
                    3,
                    math.sin(angle) * radius
                )
            else
                approachOffset = Vector3.new(0, 3, 0)
            end

            if not flyTo(egg + approachOffset) then
                local live = eggNow(uid, { At = 0 })
                if live then
                    flyTo(live + approachOffset)
                end
            end

            if STEALTH.Enabled then
                task.wait(rnd(0.05, 0.15))
            end

            if not grab(uid, CFG.GrabTimeout) then return end

            if STEALTH.Enabled then
                task.wait(rnd(0.1, 0.3))
            end

            local lineX = lineInfo()
            flyHome(lineX)
        end)

        if not ok then warn("[Steal] " .. tostring(err)) end
        state.Busy = false
    end)
end

------------------------------------------------------------------ ターゲット選択
local function pickTarget()
    local best, bestValue = nil, -1
    local myRoot = root()
    local myPos = myRoot and myRoot.Position

    for _, record in ipairs(snapshot()) do
        local info = describe(record)
        if myPos then
            local dist = (record.BottomCFrame.Position - myPos).Magnitude
            if dist > CFG.StealRadius then continue end
        end
        if info.Value > bestValue then
            best = record
            bestValue = info.Value
        end
    end
    return best
end

------------------------------------------------------------------ オートループ（前回と同一）
local autoThread = nil
local autoEnabled = false

local function startAutoSteal()
    if autoThread then return end
    autoEnabled = true
    autoThread = task.spawn(function()
        while autoEnabled do
            if not state.Busy then
                local target = pickTarget()
                if target then
                    stealAndDeliver(target.Uid)
                end
            end

            local wait_time
            if STEALTH.Enabled then
                wait_time = rnd(0.25, 0.75)
            else
                wait_time = 0.3
            end
            task.wait(wait_time)
        end
    end)
end

local function stopAutoSteal()
    autoEnabled = false
    state.Cancel = true
    cancelFly()
    autoThread = nil
end
------------------------------------------------------------------ UI
local UI = {
    W = 340,
    H = 500,
    Scale = 1,
    Minimized = false,
    AutoRefresh = true,
}

local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BloodMoonStealUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local ok = pcall(function()
        if typeof(gethui) == "function" then gui.Parent = gethui()
        else gui.Parent = CoreGui end
    end)
    if not ok then gui.Parent = localPlayer:WaitForChild("PlayerGui") end

    -- スケール計算
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    if IS_MOBILE then
        local maxW = viewport.X * 0.92
        local maxH = viewport.Y * 0.80
        UI.Scale = math.min(maxW / UI.W, maxH / UI.H, 1)
    else
        UI.Scale = 1
    end

    -- メインフレーム
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Size = UDim2.fromOffset(UI.W, UI.H)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.BackgroundColor3 = THEME.Bg
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.Parent = gui

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = UI.Scale
    uiScale.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Accent
    stroke.Thickness = 1.5
    stroke.Transparency = 0.25
    stroke.Parent = main

    -- 血の雰囲気背景
    local bgGrad = Instance.new("Frame")
    bgGrad.Size = UDim2.fromScale(1, 1)
    bgGrad.BackgroundColor3 = THEME.AccentDeep
    bgGrad.BackgroundTransparency = 0.85
    bgGrad.BorderSizePixel = 0
    bgGrad.ZIndex = 1
    bgGrad.Parent = main

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 14)
    bgCorner.Parent = bgGrad

    local bgGradient = Instance.new("UIGradient")
    bgGradient.Rotation = 90
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.AccentDeep),
        ColorSequenceKeypoint.new(0.5, THEME.Bg),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 2, 3)),
    })
    bgGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(1, 0.9),
    })
    bgGradient.Parent = bgGrad

    -- 上部ライン
    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, -40, 0, 2)
    topLine.Position = UDim2.new(0, 20, 0, 0)
    topLine.BackgroundColor3 = THEME.Accent
    topLine.BorderSizePixel = 0
    topLine.ZIndex = 4
    topLine.Parent = main

    local tlGrad = Instance.new("UIGradient")
    tlGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    tlGrad.Parent = topLine

    -- ヘッダー
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, -16, 0, 52)
    header.Position = UDim2.fromOffset(8, 8)
    header.BackgroundColor3 = THEME.Panel
    header.BackgroundTransparency = 0.05
    header.BorderSizePixel = 0
    header.ZIndex = 5
    header.Parent = main

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 10)
    hCorner.Parent = header

    local hStroke = Instance.new("UIStroke")
    hStroke.Color = THEME.AccentDark
    hStroke.Thickness = 1.2
    hStroke.Transparency = 0.35
    hStroke.Parent = header

    -- 血月マーク
    local moon = Instance.new("Frame")
    moon.Size = UDim2.fromOffset(30, 30)
    moon.Position = UDim2.fromOffset(12, 11)
    moon.BackgroundColor3 = THEME.Accent
    moon.BorderSizePixel = 0
    moon.ZIndex = 6
    moon.Parent = header

    local moonCorner = Instance.new("UICorner")
    moonCorner.CornerRadius = UDim.new(1, 0)
    moonCorner.Parent = moon

    local moonGrad = Instance.new("UIGradient")
    moonGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.AccentSoft),
        ColorSequenceKeypoint.new(1, THEME.AccentDark),
    })
    moonGrad.Rotation = 135
    moonGrad.Parent = moon

    local moonGlow = Instance.new("UIStroke")
    moonGlow.Color = THEME.AccentSoft
    moonGlow.Thickness = 2
    moonGlow.Transparency = 0.4
    moonGlow.Parent = moon

    -- タイトル
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -140, 0, 22)
    title.Position = UDim2.fromOffset(52, 8)
    title.BackgroundTransparency = 1
    title.Text = "BLOOD MOON HUB"
    title.TextColor3 = THEME.AccentSoft
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 6
    title.Parent = header

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.AccentSoft),
        ColorSequenceKeypoint.new(1, THEME.Accent),
    })
    titleGrad.Parent = title

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -140, 0, 14)
    subtitle.Position = UDim2.fromOffset(52, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "STEAL AN EGG"
    subtitle.TextColor3 = THEME.TextDim
    subtitle.Font = Enum.Font.GothamBold
    subtitle.TextSize = 10
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 6
    subtitle.Parent = header

    -- 最小化ボタン（－）
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(32, 32)
    minBtn.Position = UDim2.new(1, -78, 0.5, -16)
    minBtn.BackgroundColor3 = THEME.AccentDeep
    minBtn.BorderSizePixel = 0
    minBtn.Text = "−"
    minBtn.TextColor3 = THEME.AccentSoft
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 20
    minBtn.AutoButtonColor = true
    minBtn.ZIndex = 6
    minBtn.Parent = header

    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 8)
    mCorner.Parent = minBtn

    local mStroke = Instance.new("UIStroke")
    mStroke.Color = THEME.Accent
    mStroke.Thickness = 1
    mStroke.Transparency = 0.4
    mStroke.Parent = minBtn

    -- 閉じるボタン（×）
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(32, 32)
    closeBtn.Position = UDim2.new(1, -42, 0.5, -16)
    closeBtn.BackgroundColor3 = THEME.AccentDeep
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = THEME.AccentSoft
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.AutoButtonColor = true
    closeBtn.ZIndex = 6
    closeBtn.Parent = header

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = closeBtn

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = THEME.Accent
    cStroke.Thickness = 1
    cStroke.Transparency = 0.4
    cStroke.Parent = closeBtn

    -- ボディ（最小化時に隠す）
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, -16, 1, -68)
    body.Position = UDim2.fromOffset(8, 68)
    body.BackgroundTransparency = 1
    body.ZIndex = 5
    body.Parent = main

    -- ステータス
    local status = Instance.new("TextLabel")
    status.Name = "StatusLabel"
    status.Size = UDim2.new(1, -20, 0, 22)
    status.Position = UDim2.fromOffset(6, 0)
    status.BackgroundTransparency = 1
    status.Text = "速度: " .. CFG.Speed .. " / 待機中"
    status.TextColor3 = THEME.TextDim
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 6
    status.Parent = body

    -- 自動更新インジケーター
    local autoRefreshDot = Instance.new("Frame")
    autoRefreshDot.Size = UDim2.fromOffset(8, 8)
    autoRefreshDot.Position = UDim2.new(1, -20, 0, 7)
    autoRefreshDot.BackgroundColor3 = THEME.Accent
    autoRefreshDot.BorderSizePixel = 0
    autoRefreshDot.ZIndex = 6
    autoRefreshDot.Parent = body

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = autoRefreshDot

    -- 卵リスト
    local list = Instance.new("ScrollingFrame")
    list.Name = "EggList"
    list.Size = UDim2.new(1, -4, 1, -150)
    list.Position = UDim2.fromOffset(2, 26)
    list.BackgroundColor3 = THEME.Panel
    list.BackgroundTransparency = 0.15
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 5
    list.ScrollBarImageColor3 = THEME.Accent
    list.CanvasSize = UDim2.new()
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 5
    list.Parent = body

    local lCorner = Instance.new("UICorner")
    lCorner.CornerRadius = UDim.new(0, 10)
    lCorner.Parent = list

    local lStroke = Instance.new("UIStroke")
    lStroke.Color = THEME.Stroke
    lStroke.Thickness = 1
    lStroke.Transparency = 0.5
    lStroke.Parent = list

    local lLayout = Instance.new("UIListLayout")
    lLayout.Padding = UDim.new(0, 5)
    lLayout.SortOrder = Enum.SortOrder.LayoutOrder
    lLayout.Parent = list

    local lPad = Instance.new("UIPadding")
    lPad.PaddingTop = UDim.new(0, 6)
    lPad.PaddingBottom = UDim.new(0, 6)
    lPad.PaddingLeft = UDim.new(0, 6)
    lPad.PaddingRight = UDim.new(0, 8)
    lPad.Parent = list

    local RARITY = {
        Color3.fromRGB(200, 180, 180),
        Color3.fromRGB(110, 210, 110),
        Color3.fromRGB(90, 160, 255),
        Color3.fromRGB(190, 110, 255),
        Color3.fromRGB(255, 170, 50),
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(255, 90, 200),
        Color3.fromRGB(255, 100, 120),
    }

    local selectedUid = nil
    local rows = {}

    local function setSelected(uid)
        selectedUid = uid
        for rowUid, row in pairs(rows) do
            local on = rowUid == uid
            row.Stroke.Thickness = on and 2.5 or 1
            row.Stroke.Color = on and THEME.Accent or THEME.Stroke
            row.Stroke.Transparency = on and 0 or 0.6
            row.Frame.BackgroundColor3 = on and THEME.AccentDeep or THEME.Card
        end
    end

    local function rebuild()
        for _, row in pairs(rows) do row.Frame:Destroy() end
        table.clear(rows)

        local infos = {}
        for _, record in ipairs(snapshot()) do
            infos[#infos + 1] = describe(record)
        end
        table.sort(infos, function(a, b) return a.Value > b.Value end)

        local still = false
        for index, info in ipairs(infos) do
            still = still or info.Uid == selectedUid

            local frame = Instance.new("TextButton")
            frame.Size = UDim2.new(1, 0, 0, 48)
            frame.BackgroundColor3 = THEME.Card
            frame.BorderSizePixel = 0
            frame.Text = ""
            frame.LayoutOrder = index
            frame.AutoButtonColor = true
            frame.Parent = list

            local fCorner = Instance.new("UICorner")
            fCorner.CornerRadius = UDim.new(0, 8)
            fCorner.Parent = frame

            local fStroke = Instance.new("UIStroke")
            fStroke.Color = THEME.Stroke
            fStroke.Thickness = 1
            fStroke.Transparency = 0.6
            fStroke.Parent = frame

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.fromOffset(38, 38)
            icon.Position = UDim2.fromOffset(5, 5)
            icon.BackgroundTransparency = 1
            icon.Image = info.Icon
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Parent = frame

            local name = Instance.new("TextLabel")
            name.Size = UDim2.new(1, -52, 0, 22)
            name.Position = UDim2.fromOffset(50, 4)
            name.BackgroundTransparency = 1
            name.Text = info.Name
            name.TextColor3 = RARITY[math.clamp(info.Rarity, 1, #RARITY)] or THEME.Text
            name.Font = Enum.Font.GothamBold
            name.TextSize = 15
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd
            name.Parent = frame

            local value = Instance.new("TextLabel")
            value.Size = UDim2.new(1, -52, 0, 16)
            value.Position = UDim2.fromOffset(50, 26)
            value.BackgroundTransparency = 1
            value.Text = money(info.Value)
            value.TextColor3 = THEME.AccentSoft
            value.Font = Enum.Font.GothamMedium
            value.TextSize = 13
            value.TextXAlignment = Enum.TextXAlignment.Left
            value.Parent = frame

            rows[info.Uid] = { Frame = frame, Stroke = fStroke }

            frame.MouseButton1Click:Connect(function()
                setSelected(info.Uid)
                status.Text = "選択中: " .. info.Name
            end)
        end

        setSelected(still and selectedUid or nil)
    end

    -- 月のパルス
    task.spawn(function()
        while gui.Parent do
            task.wait(0.05)
            local t = tick() * 1.5
            moonGlow.Transparency = 0.4 + math.sin(t) * 0.15
            moonGrad.Rotation = (tick() * 20) % 360
        end
    end)

    -- 自動更新インジケーターの点滅
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            if UI.AutoRefresh then
                autoRefreshDot.BackgroundColor3 = THEME.Accent
                task.wait(0.5)
                autoRefreshDot.BackgroundColor3 = THEME.AccentDark
            else
                autoRefreshDot.BackgroundColor3 = THEME.Off
            end
        end
    end)

    return gui, main, body, header, status, rebuild,
           function() return selectedUid end,
           minBtn, closeBtn, autoRefreshDot
end

------------------------------------------------------------------ UI 組み立て
local gui, main, body, header, statusLabel, rebuildList, getSelectedUid,
      minBtn, closeBtn, autoRefreshDot = makeUI()

local UI_W, UI_H = 340, 500
local UI_H_MIN = 68

-- ボタン生成
local function makeButton(text, pos, size, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = THEME.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.AutoButtonColor = true
    btn.ZIndex = 6
    btn.Parent = parent

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 12)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = THEME.Accent
    bStroke.Thickness = 1.2
    bStroke.Transparency = 0.4
    bStroke.Parent = btn

    local pressScale = Instance.new("UIScale")
    pressScale.Scale = 1
    pressScale.Parent = btn

    btn.MouseButton1Down:Connect(function()
        TweenService:Create(pressScale, TweenInfo.new(0.08), {Scale = 0.95}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(pressScale, TweenInfo.new(0.12), {Scale = 1}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(pressScale, TweenInfo.new(0.12), {Scale = 1}):Play()
    end)

    return btn, bStroke
end

-- ボタン群
local refreshBtn = makeButton("更新",
    UDim2.new(0, 0, 1, -60),
    UDim2.new(0.32, -4, 0, 52),
    THEME.Card, body)

local autoBtn = makeButton("自動盗み",
    UDim2.new(0.32, 2, 1, -60),
    UDim2.new(0.36, -4, 0, 52),
    Color3.fromRGB(60, 15, 20), body)

local instantBtn = makeButton("即盗み",
    UDim2.new(0.68, 4, 1, -60),
    UDim2.new(0.32, -4, 0, 52),
    Color3.fromRGB(40, 10, 25), body)

-- ★ 自動更新トグル（小さなボタン）
local autoToggle = Instance.new("TextButton")
autoToggle.Size = UDim2.fromOffset(80, 22)
autoToggle.Position = UDim2.new(1, -94, 0, 2)
autoToggle.BackgroundColor3 = THEME.AccentDeep
autoToggle.BorderSizePixel = 0
autoToggle.Text = "自動更新 ON"
autoToggle.TextColor3 = THEME.AccentSoft
autoToggle.Font = Enum.Font.GothamBold
autoToggle.TextSize = 10
autoToggle.AutoButtonColor = true
autoToggle.ZIndex = 6
autoToggle.Parent = body

local atCorner = Instance.new("UICorner")
atCorner.CornerRadius = UDim.new(0, 6)
atCorner.Parent = autoToggle

local atStroke = Instance.new("UIStroke")
atStroke.Color = THEME.Accent
atStroke.Thickness = 1
atStroke.Transparency = 0.5
atStroke.Parent = autoToggle

-- イベント
refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then
        rebuildList()
        statusLabel.Text = "手動更新完了"
    end
end)

autoBtn.MouseButton1Click:Connect(function()
    if autoEnabled then
        stopAutoSteal()
        autoBtn.Text = "自動盗み"
        autoBtn.BackgroundColor3 = Color3.fromRGB(60, 15, 20)
        statusLabel.Text = "自動盗み停止"
    else
        startAutoSteal()
        autoBtn.Text = "停止"
        autoBtn.BackgroundColor3 = Color3.fromRGB(140, 20, 30)
        statusLabel.Text = "自動盗み開始"
    end
end)

instantBtn.MouseButton1Click:Connect(function()
    local uid = getSelectedUid()
    if uid then
        state.Busy = false
        stealAndDeliver(uid)
        statusLabel.Text = "即盗み実行中..."
    else
        statusLabel.Text = "卵を選択してください"
    end
end)

autoToggle.MouseButton1Click:Connect(function()
    UI.AutoRefresh = not UI.AutoRefresh
    if UI.AutoRefresh then
        autoToggle.Text = "自動更新 ON"
        autoToggle.BackgroundColor3 = THEME.AccentDeep
        statusLabel.Text = "自動更新 有効"
    else
        autoToggle.Text = "自動更新 OFF"
        autoToggle.BackgroundColor3 = THEME.Off
        statusLabel.Text = "自動更新 無効"
    end
end)

------------------------------------------------------------------ 最小化・閉じる
local bodyVisible = true

local function setMinimized(minimized)
    UI.Minimized = minimized
    bodyVisible = not minimized

    if minimized then
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(UI_W, UI_H_MIN)
        }):Play()
        task.delay(0.12, function()
            body.Visible = false
        end)
    else
        body.Visible = true
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(UI_W, UI_H)
        }):Play()
    end
end

minBtn.MouseButton1Click:Connect(function()
    setMinimized(not UI.Minimized)
end)

-- フローティングボタン（閉じた時に表示）
local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.fromOffset(60, 60)
floatBtn.Position = UDim2.new(0, 16, 0.4, 0)
floatBtn.BackgroundColor3 = THEME.Panel
floatBtn.BorderSizePixel = 0
floatBtn.Text = "🌙"
floatBtn.TextColor3 = THEME.AccentSoft
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 26
floatBtn.AutoButtonColor = true
floatBtn.Visible = false
floatBtn.ZIndex = 200
floatBtn.Parent = gui

local fbCorner = Instance.new("UICorner")
fbCorner.CornerRadius = UDim.new(1, 0)
fbCorner.Parent = floatBtn

local fbStroke = Instance.new("UIStroke")
fbStroke.Color = THEME.Accent
fbStroke.Thickness = 2
fbStroke.Transparency = 0.3
fbStroke.Parent = floatBtn

task.spawn(function()
    while gui.Parent do
        task.wait(0.05)
        local t = tick() * 2
        fbStroke.Transparency = 0.3 + math.sin(t) * 0.2
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
    floatBtn.Visible = true
end)

-- フローティングボタンのドラッグ＋タップ
local fbDrag = false
local fbStart = nil
local fbStartPos = nil
local fbMoved = 0

floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        fbDrag = true
        fbStart = input.Position
        fbStartPos = floatBtn.Position
        fbMoved = 0
    end
end)

floatBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        fbDrag = false
        if fbMoved < 8 then
            gui.Enabled = true
            flo        if fbMoved < 8 then
            gui.Enabled = true
            floatBtn.Visible = false
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not fbDrag then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local delta = input.Position - fbStart
    fbMoved = math.max(fbMoved, delta.Magnitude)
    floatBtn.Position = UDim2.new(
        fbStartPos.X.Scale, fbStartPos.X.Offset + delta.X,
        fbStartPos.Y.Scale, fbStartPos.Y.Offset + delta.Y
    )
end)

------------------------------------------------------------------ ヘッダードラッグ
local drag = false
local dragStart = nil
local startPos = nil

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        drag = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        drag = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not drag then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end)

------------------------------------------------------------------ ★ 自動更新ループ
task.spawn(function()
    while gui.Parent do
        task.wait(CFG.AutoRefreshInterval)
        if UI.AutoRefresh and not state.Busy and not autoEnabled then
            pcall(rebuildList)
        end
    end
end)

------------------------------------------------------------------ ボタン状態監視
task.spawn(function()
    while gui.Parent do
        task.wait(0.3)
        if state.Busy then
            instantBtn.Text = "実行中..."
            instantBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
        else
            instantBtn.Text = "即盗み"
            instantBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 25)
        end
    end
end)

-- 画面回転時スケール再計算
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local vp = workspace.CurrentCamera.ViewportSize
        if IS_MOBILE then
            local maxW = vp.X * 0.92
            local maxH = vp.Y * 0.80
            UI.Scale = math.min(maxW / UI_W, maxH / UI_H, 1)
        else
            UI.Scale = 1
        end
        local scale = main:FindFirstChildOfClass("UIScale")
        if scale then
            TweenService:Create(scale, TweenInfo.new(0.2), {Scale = UI.Scale}):Play()
        end
    end)
end

-- 初期構築
rebuildList()

print("[Blood Moon Steal Hub] 起動完了")
print("  テーマ: Blood Moon 血月赤")
print("  速度: " .. CFG.Speed)
print("  自動更新: " .. CFG.AutoRefreshInterval .. "秒")
print("  デバイス: " .. (IS_MOBILE and "スマホ" or IS_TABLET and "タブレット" or "PC"))
	
