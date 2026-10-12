-- ============================================================
-- Blood Moon Steal Hub - PART 1/6
-- 設定・テーマ・ゲームハンドル・状態
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local CFG = {
    Speed = 1400,
    GrabInterval = 0.03,
    GrabTimeout = 4,
    PromptRadius = 12,
    StealRadius = 61,
    DropDelay = 0.15,
    FlyTimeout = 20,
    AutoRefreshInterval = 4,
}

local STEALTH = {
    Enabled = true,
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

local function rnd(a, b) return a + math.random() * (b - a) end
local function rndJ(a) return (math.random() * 2 - 1) * a end

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local THEME = {
    Bg = Color3.fromRGB(12, 4, 6),
    Panel = Color3.fromRGB(22, 8, 12),
    Card = Color3.fromRGB(32, 10, 16),
    Accent = Color3.fromRGB(220, 25, 40),
    AccentSoft = Color3.fromRGB(255, 90, 100),
    AccentDark = Color3.fromRGB(120, 12, 20),
    AccentDeep = Color3.fromRGB(60, 5, 10),
    Text = Color3.fromRGB(250, 235, 235),
    TextDim = Color3.fromRGB(180, 140, 140),
    Stroke = Color3.fromRGB(100, 30, 40),
    Off = Color3.fromRGB(90, 60, 65),
}

local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")

local function sreq(f)
    local ok, r = pcall(f)
    return ok and r or nil
end

local EggState = sreq(function() return require(ReplicatedStorage.Client.EggState) end)
local Assets = sreq(function() return require(ReplicatedStorage.Data.Assets) end)
local Mutations = sreq(function() return require(ReplicatedStorage.Shared.Modules.Mutations) end)

local function rem(n) return networking:FindFirstChild(n) end
local function root()
    local c = localPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local state = { Carrying = false, Uid = nil, Delivered = 0, Busy = false, Cancel = false }

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" then
    EggState.CarryChanged:Connect(function(arg)
        local carry = type(arg) == "table" and arg.IsCarrying == true
        if carry and arg.GuardDisabled == true then carry = false end
        if carry and type(arg.Uid) == "string" then state.Uid = arg.Uid end
        state.Carrying = carry
    end)
end

pcall(function()
    local ev = rem("RE/EggWorld/FieldEggRedeemVerdict")
    if ev then ev.OnClientEvent:Connect(function() state.Delivered = os.clock() end) end
end)
-- ============================================================
-- Blood Moon Steal Hub - PART 2/6
-- 卵情報・座標系
-- ============================================================

local function takeEgg(uid)
    if type(uid) == "string" and type(EggState) == "table"
        and type(EggState.CarryFieldEgg) == "function" then
        pcall(EggState.CarryFieldEgg, uid)
    end
end

local function dropEgg()
    if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
        pcall(EggState.DropFieldEgg, "PlayerRequest")
    end
end

local function snapshot()
    local list = {}
    local fn = rem("RF/EggWorld/AskFieldEggSnapshot")
    if not fn or not fn:IsA("RemoteFunction") then return list end
    local ok, result = pcall(function() return fn:InvokeServer() end)
    local records = ok and type(result) == "table" and result.Records or nil
    if type(records) ~= "table" then return list end
    for _, r in pairs(records) do
        if type(r) == "table" and type(r.Uid) == "string"
            and (r.State == "Slot" or r.State == "Dropped")
            and typeof(r.BottomCFrame) == "CFrame" then
            list[#list + 1] = r
        end
    end
    return list
end

local function eggPos(uid)
    for _, r in ipairs(snapshot()) do
        if r.Uid == uid then return r.BottomCFrame.Position end
    end
    return nil
end

local function eggNow(uid, cache)
    local node = workspace:FindFirstChild(uid)
    local slots = workspace:FindFirstChild("AreaEggSlotsClient")
    node = node or (slots and slots:FindFirstChild(uid))
    if node then
        local ok, p = pcall(function() return node:GetPivot().Position end)
        if ok and p then cache.Pos, cache.At = p, os.clock(); return p end
    end
    if os.clock() - cache.At >= 0.5 then
        cache.At = os.clock()
        cache.Pos = eggPos(uid) or cache.Pos
    end
    return cache.Pos
end

local function promptNear(pos, radius)
    local best, bd = nil, radius or 12
    for _, c in ipairs(workspace:GetChildren()) do
        if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
            local pr = c:FindFirstChild("CarryAreaEgg")
            if pr and pr:IsA("ProximityPrompt") then
                local d = (c.Position - pos).Magnitude
                if d < bd then best, bd = pr, d end
            end
        end
    end
    return best
end

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
        for _, name in ipairs(def[1]) do n = n and n:FindFirstChild(name) or nil end
        if n and n:IsA("BasePart") then return n.CFrame:PointToWorldSpace(def[2]) end
    end
    return Vector3.new(528.7, 70.57, -364.11)
end

local function describe(record)
    local dir = type(Assets) == "table" and Assets.Directory or nil
    local e = type(dir) == "table" and dir[tostring(record.AssetCategory)] or nil
    local info = { Uid = record.Uid, Name = tostring(record.AssetCategory), Icon = "", Rarity = 0, Value = 0 }
    if type(e) == "table" then
        info.Name = tostring(e.DisplayName or record.AssetCategory)
        local ic = e.Icon
        if ic ~= nil and tostring(ic) ~= "" then
            ic = tostring(ic)
            info.Icon = tonumber(ic) and ("rbxassetid://" .. ic) or ic
        end
        if type(e.Rarity) == "table" then
            info.Rarity = tonumber(e.Rarity.RarityNumber or e.Rarity.Rank) or 0
        end
        local sc = tonumber(record.AssetScale) or 1
        local f = sc > 5 and (sc / 5) ^ 1.2 * 19.637875755794113 or sc ^ 1.85
        local mut = 1
        if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
            local ok, r = pcall(Mutations.EarningsFor,
                type(record.Mutations) == "table" and record.Mutations or {})
            if ok and type(r) == "number" then mut = r end
        end
        info.Value = (tonumber(e.EarningRate) or 0) * f * mut
    end
    return info
end

local function money(v)
    local u = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, x in ipairs(u) do
        if v >= x[1] then return string.format("$%.2f%s/s", v / x[1], x[2]) end
    end
    return string.format("$%d/s", math.floor(v + 0.5))
end-- ============================================================
-- Blood Moon Steal Hub - PART 3/6
-- フライ移動・掴む・納品
-- ============================================================

local flyCancel = false

local function flyTo(target, cancelCheck)
    local char = localPlayer.Character
    local myRoot = root()
    if not char or not myRoot then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = true end) end

    local started = os.clock()
    local result = false
    local lastMark, lastClock, stuck = nil, 0, 0

    if STEALTH.Enabled then
        target = target + Vector3.new(rndJ(STEALTH.LandingJitter), 0, rndJ(STEALTH.LandingJitter))
    end

    while os.clock() - started < CFG.FlyTimeout do
        if flyCancel then break end
        if type(cancelCheck) == "function" and cancelCheck() then break end

        local r = root()
        if not r or not r.Parent then break end

        local delta = target - r.Position
        local dist = delta.Magnitude
        if dist <= 2 then result = true; break end

        local dir = dist > 0.01 and delta.Unit or Vector3.zero
        local step
        if STEALTH.Enabled then
            step = math.min(CFG.Speed * (1/60), rnd(STEALTH.HopRandomMin, STEALTH.HopRandomMax), dist)
        else
            step = math.min(CFG.Speed * (1/60), dist)
        end

        local jitter = STEALTH.Enabled
            and Vector3.new(rndJ(STEALTH.MicroJitter), 0, rndJ(STEALTH.MicroJitter))
            or Vector3.zero

        local nextPos = r.Position + dir * step + jitter

        pcall(function()
            r.CFrame = CFrame.new(nextPos) * r.CFrame.Rotation
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)

        if STEALTH.Enabled then
            local p = rnd(STEALTH.PauseMin, STEALTH.PauseMax)
            if p > 0.03 then task.wait(p) end
        end

        if lastMark and (r.Position - lastMark).Magnitude < 1 then
            stuck = stuck + 1
            if os.clock() - lastClock > 0.5 or stuck > 30 then break end
        else
            lastMark = r.Position
            lastClock = os.clock()
            stuck = 0
        end

        RunService.Heartbeat:Wait()
    end

    if hum then pcall(function() hum.PlatformStand = false end) end
    return result
end

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
        waited = waited + dt
        since = since + dt

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
                local pr = promptNear(egg - Vector3.new(0, 3, 0), CFG.PromptRadius)
                if pr and typeof(fireproximityprompt) == "function" then
                    pcall(function() pr.HoldDuration = 0 end)
                    pcall(fireproximityprompt, pr)
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

local function flyHome(lineX)
    local started = os.clock()
    local home = homePoint()
    local ok = flyTo(home + Vector3.new(0, 3, 0), function()
        return state.Delivered >= started or not state.Carrying
    end)
    if not ok and not state.Carrying then return state.Delivered >= started end
    if state.Carrying then
        task.wait(STEALTH.Enabled and (STEALTH.DeliverPause + rnd(0, 0.1)) or CFG.DropDelay)
        dropEgg()
        local w = 0
        while state.Delivered < started and w < 1.5 do
            w = w + RunService.Heartbeat:Wait()
        end
    end
    return state.Delivered >= started
	end-- ============================================================
-- Blood Moon Steal Hub - PART 4/6
-- メイン盗み・オートループ
-- ============================================================

local function stealAndDeliver(uid)
    if state.Busy then return end
    state.Busy = true
    state.Cancel = false
    flyCancel = false

    task.spawn(function()
        local ok, err = pcall(function()
            if STEALTH.Enabled then task.wait(rnd(0.1, 0.4)) end

            local egg = eggPos(uid)
            if not egg then return end

            if state.Carrying and state.Uid ~= uid then
                dropEgg()
                local w = 0
                while state.Carrying and w < 1 do w = w + RunService.Heartbeat:Wait() end
            end

            local offset
            if STEALTH.Enabled then
                local a = math.random() * math.pi * 2
                local rad = rnd(2.5, 4)
                offset = Vector3.new(math.cos(a) * rad, 3, math.sin(a) * rad)
            else
                offset = Vector3.new(0, 3, 0)
            end

            if not flyTo(egg + offset) then
                local live = eggNow(uid, { At = 0 })
                if live then flyTo(live + offset) end
            end

            if STEALTH.Enabled then task.wait(rnd(0.05, 0.15)) end

            if not grab(uid, CFG.GrabTimeout) then return end

            if STEALTH.Enabled then task.wait(rnd(0.1, 0.3)) end

            flyHome(lineInfo())
        end)

        if not ok then warn("[Steal] " .. tostring(err)) end
        state.Busy = false
    end)
end

local function pickTarget()
    local best, bv = nil, -1
    local myRoot = root()
    local myPos = myRoot and myRoot.Position
    for _, r in ipairs(snapshot()) do
        local info = describe(r)
        local dist = myPos and (r.BottomCFrame.Position - myPos).Magnitude or 0
        if dist <= CFG.StealRadius then
            if info.Value > bv then best, bv = r, info.Value end
        end
    end
    return best
end

local autoThread, autoEnabled = nil, false

local function startAutoSteal()
    if autoThread then return end
    autoEnabled = true
    autoThread = task.spawn(function()
        while autoEnabled do
            if not state.Busy then
                local t = pickTarget()
                if t then stealAndDeliver(t.Uid) end
            end
            task.wait(STEALTH.Enabled and rnd(0.25, 0.75) or 0.3)
        end
    end)
end

local function stopAutoSteal()
    autoEnabled = false
    state.Cancel = true
    flyCancel = true
    autoThread = nil
		end-- ============================================================
-- Blood Moon Steal Hub - PART 5/6
-- UI前半（GUI作成・ヘッダー）
-- ============================================================

print("[BloodMoon] ===== UI構築開始 =====")

local UI = {
    W = 340, H = 500, Scale = 1,
    Minimized = false, AutoRefresh = true,
}
local UI_W, UI_H = UI.W, UI.H
local UI_H_MIN = 68

local function getParentGui()
    if type(gethui) == "function" then
        local ok, r = pcall(gethui)
        if ok and typeof(r) == "Instance" then return r end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function createScreenGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BloodMoonUI_" .. tostring(math.random(1000, 9999))
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = true

    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    end

    local parent = getParentGui()
    if parent then
        local ok = pcall(function() gui.Parent = parent end)
        if not ok or not gui.Parent then
            local pg = localPlayer:WaitForChild("PlayerGui", 5)
            if pg then gui.Parent = pg end
        end
    end

    print("[BloodMoon] GUI Parent:", gui.Parent and gui.Parent:GetFullName() or "nil")
    return gui
end

local function makeUI()
    local gui = createScreenGui()
    if not gui then return nil end

    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    if IS_MOBILE then
        UI.Scale = math.min(vp.X * 0.92 / UI_W, vp.Y * 0.80 / UI_H, 1)
    end

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Size = UDim2.fromOffset(UI_W, UI_H)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.BackgroundColor3 = THEME.Bg
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.Parent = gui

    local us = Instance.new("UIScale")
    us.Scale = UI.Scale
    us.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Accent
    stroke.Thickness = 1.5
    stroke.Transparency = 0.25
    stroke.Parent = main

    local bgGrad = Instance.new("Frame")
    bgGrad.Size = UDim2.fromScale(1, 1)
    bgGrad.BackgroundColor3 = THEME.AccentDeep
    bgGrad.BackgroundTransparency = 0.85
    bgGrad.BorderSizePixel = 0
    bgGrad.ZIndex = 1
    bgGrad.Parent = main

    local bgC = Instance.new("UICorner")
    bgC.CornerRadius = UDim.new(0, 14)
    bgC.Parent = bgGrad

    local bgG = Instance.new("UIGradient")
    bgG.Rotation = 90
    bgG.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.AccentDeep),
        ColorSequenceKeypoint.new(0.5, THEME.Bg),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 2, 3)),
    })
    bgG.Parent = bgGrad

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, -16, 0, 52)
    header.Position = UDim2.fromOffset(8, 8)
    header.BackgroundColor3 = THEME.Panel
    header.BackgroundTransparency = 0.05
    header.BorderSizePixel = 0
    header.ZIndex = 5
    header.Parent = main

    local hC = Instance.new("UICorner")
    hC.CornerRadius = UDim.new(0, 10)
    hC.Parent = header

    local hS = Instance.new("UIStroke")
    hS.Color = THEME.AccentDark
    hS.Thickness = 1.2
    hS.Transparency = 0.35
    hS.Parent = header

    local moon = Instance.new("Frame")
    moon.Size = UDim2.fromOffset(30, 30)
    moon.Position = UDim2.fromOffset(12, 11)
    moon.BackgroundColor3 = THEME.Accent
    moon.BorderSizePixel = 0
    moon.ZIndex = 6
    moon.Parent = header

    local mC = Instance.new("UICorner")
    mC.CornerRadius = UDim.new(1, 0)
    mC.Parent = moon

    local mG = Instance.new("UIGradient")
    mG.Color = ColorSequence.new(THEME.AccentSoft, THEME.AccentDark)
    mG.Rotation = 135
    mG.Parent = moon

    local mS = Instance.new("UIStroke")
    mS.Color = THEME.AccentSoft
    mS.Thickness = 2
    mS.Transparency = 0.4
    mS.Parent = moon

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

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -140, 0, 14)
    sub.Position = UDim2.fromOffset(52, 30)
    sub.BackgroundTransparency = 1
    sub.Text = "STEAL AN EGG"
    sub.TextColor3 = THEME.TextDim
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.ZIndex = 6
    sub.Parent = header

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

    local mC2 = Instance.new("UICorner")
    mC2.CornerRadius = UDim.new(0, 8)
    mC2.Parent = minBtn

    local mS2 = Instance.new("UIStroke")
    mS2.Color = THEME.Accent
    mS2.Thickness = 1
    mS2.Transparency = 0.4
    mS2.Parent = minBtn

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

    local cC = Instance.new("UICorner")
    cC.CornerRadius = UDim.new(0, 8)
    cC.Parent = closeBtn

    local cS = Instance.new("UIStroke")
    cS.Color = THEME.Accent
    cS.Thickness = 1
    cS.Transparency = 0.4
    cS.Parent = closeBtn

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, -16, 1, -68)
    body.Position = UDim2.fromOffset(8, 68)
    body.BackgroundTransparency = 1
    body.ZIndex = 5
    body.Parent = main

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -110, 0, 22)
    status.Position = UDim2.fromOffset(6, 0)
    status.BackgroundTransparency = 1
    status.Text = "速度: " .. CFG.Speed .. " / 待機中"
    status.TextColor3 = THEME.TextDim
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 6
    status.Parent = body

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

    local lC = Instance.new("UICorner")
    lC.CornerRadius = UDim.new(0, 10)
    lC.Parent = list

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

    -- 6分割の続きへ（PART 6）
    return gui, main, body, header, status, list, minBtn, closeBtn
			end-- ============================================================
-- Blood Moon Steal Hub - PART 6/6
-- UI後半（リスト・ボタン・イベント・起動）
-- ============================================================

local okBuild, gui, main, body, header, statusLabel, list, minBtn, closeBtn = pcall(makeUI)

if not okBuild or not gui then
    warn("[BloodMoon] UI構築失敗: " .. tostring(gui))
    return
end

print("[BloodMoon] UI構築OK")

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
    for _, row in pairs(rows) do
        pcall(function() row.Frame:Destroy() end)
    end
    table.clear(rows)

    local infos = {}
    local ok, records = pcall(snapshot)
    if ok and type(records) == "table" then
        for _, record in ipairs(records) do
            local okD, info = pcall(describe, record)
            if okD and info then infos[#infos + 1] = info end
        end
    end
    table.sort(infos, function(a, b) return (a.Value or 0) > (b.Value or 0) end)

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

        local fC = Instance.new("UICorner")
        fC.CornerRadius = UDim.new(0, 8)
        fC.Parent = frame

        local fS = Instance.new("UIStroke")
        fS.Color = THEME.Stroke
        fS.Thickness = 1
        fS.Transparency = 0.6
        fS.Parent = frame

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.fromOffset(38, 38)
        icon.Position = UDim2.fromOffset(5, 5)
        icon.BackgroundTransparency = 1
        icon.Image = info.Icon or ""
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = frame

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -52, 0, 22)
        name.Position = UDim2.fromOffset(50, 4)
        name.BackgroundTransparency = 1
        name.Text = info.Name or "?"
        name.TextColor3 = RARITY[math.clamp(info.Rarity or 1, 1, #RARITY)] or THEME.Text
        name.Font = Enum.Font.GothamBold
        name.TextSize = 15
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = frame

        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(1, -52, 0, 16)
        value.Position = UDim2.fromOffset(50, 26)
        value.BackgroundTransparency = 1
        value.Text = money(info.Value or 0)
        value.TextColor3 = THEME.AccentSoft
        value.Font = Enum.Font.GothamMedium
        value.TextSize = 13
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.Parent = frame

        rows[info.Uid] = { Frame = frame, Stroke = fS }

        frame.MouseButton1Click:Connect(function()
            setSelected(info.Uid)
            statusLabel.Text = "選択中: " .. (info.Name or "?")
        end)
    end
    setSelected(still and selectedUid or nil)
end

-- 月のパルス
task.spawn(function()
    while gui.Parent do
        task.wait(0.05)
        local t = tick() * 1.5
        pcall(function()
            local moon = header:FindFirstChild("Frame")
        end)
    end
end)

-- ボタン生成
local function mkBtn(text, pos, size, color)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = THEME.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.AutoButtonColor = true
    b.ZIndex = 6
    b.Parent = body

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 12)
    bc.Parent = b

    local bs = Instance.new("UIStroke")
    bs.Color = THEME.Accent
    bs.Thickness = 1.2
    bs.Transparency = 0.4
    bs.Parent = b

    return b
end

local refreshBtn = mkBtn("更新", UDim2.new(0, 0, 1, -60), UDim2.new(0.32, -4, 0, 52), THEME.Card)
local autoBtn = mkBtn("自動盗み", UDim2.new(0.32, 2, 1, -60), UDim2.new(0.36, -4, 0, 52), Color3.fromRGB(60, 15, 20))
local instantBtn = mkBtn("即盗み", UDim2.new(0.68, 4, 1, -60), UDim2.new(0.32, -4, 0, 52), Color3.fromRGB(40, 10, 25))

-- 自動更新トグル
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

local atC = Instance.new("UICorner")
atC.CornerRadius = UDim.new(0, 6)
atC.Parent = autoToggle

-- イベント
refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then
        rebuild()
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
    if selectedUid then
        state.Busy = false
        stealAndDeliver(selectedUid)
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
    else
        autoToggle.Text = "自動更新 OFF"
        autoToggle.BackgroundColor3 = THEME.Off
    end
end)

-- 最小化
minBtn.MouseButton1Click:Connect(function()
    UI.Minimized = not UI.Minimized
    if UI.Minimized then
        TweenService:Create(main, TweenInfo.new(0.25), {
            Size = UDim2.fromOffset(UI_W, UI_H_MIN)
        }):Play()
        task.delay(0.12, function() body.Visible = false end)
    else
        body.Visible = true
        TweenService:Create(main, TweenInfo.new(0.25), {
            Size = UDim2.fromOffset(UI_W, UI_H)
        }):Play()
    end
end)

-- フローティングボタン
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

local fbC = Instance.new("UICorner")
fbC.CornerRadius = UDim.new(1, 0)
fbC.Parent = floatBtn

local fbS = Instance.new("UIStroke")
fbS.Color = THEME.Accent
fbS.Thickness = 2
fbS.Transparency = 0.3
fbS.Parent = floatBtn

closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
    floatBtn.Visible = true
end)

local fbDrag, fbStart, fbStartPos, fbMoved = false, nil, nil, 0

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
            floatBtn.Visible = false
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not fbDrag then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - fbStart
    fbMoved = math.max(fbMoved, d.Magnitude)
    floatBtn.Position = UDim2.new(
        fbStartPos.X.Scale, fbStartPos.X.Offset + d.X,
        fbStartPos.Y.Scale, fbStartPos.Y.Offset + d.Y
    )
end)

-- ヘッダードラッグ
local drag, dragStart, startPos = false, nil, nil

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
    local d = input.Position - dragStart
    main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y
    )
end)

-- 自動更新
task.spawn(function()
    while gui.Parent do
        task.wait(CFG.AutoRefreshInterval)
        if UI.AutoRefresh and not state.Busy and not autoEnabled then
            pcall(rebuild)
        end
    end
end)

-- ボタン状態監視
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

task.spawn(function()
    task.wait(0.2)
    pcall(rebuild)
end)

print("[BloodMoon] ===== 起動完了 =====")
print("  速度: " .. CFG.Speed)
print("  GUI Parent: " .. tostring(gui.Parent and gui.Parent:GetFullName() or "nil"))
