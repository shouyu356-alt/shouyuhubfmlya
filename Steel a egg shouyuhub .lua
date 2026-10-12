-- ============================================================
-- ShouyuHub Style UI + Chilli Hub Auto Steal
-- 水色テーマ / 速度1400 / CFrameフライ方式
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

------------------------------------------------------------------ 設定
local CFG = {
    Speed = 1400,
    GrabInterval = 0.03,
    GrabTimeout = 4,
    PromptRadius = 12,
    StealRadius = 61,
    DropDelay = 0.15,
    FlyTimeout = 20,
}

------------------------------------------------------------------ 色テーマ（ShouyuHub水色）
local THEME = {
    Bg          = Color3.fromRGB(10, 14, 20),
    Panel       = Color3.fromRGB(16, 22, 30),
    Card        = Color3.fromRGB(22, 30, 40),
    Accent      = Color3.fromRGB(0, 200, 255),      -- 水色
    AccentSoft  = Color3.fromRGB(100, 220, 255),
    AccentDark  = Color3.fromRGB(0, 120, 180),
    Text        = Color3.fromRGB(240, 250, 255),
    TextDim     = Color3.fromRGB(150, 180, 200),
    Stroke      = Color3.fromRGB(60, 100, 130),
    On          = Color3.fromRGB(0, 220, 140),
    Off         = Color3.fromRGB(80, 100, 120),
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
end)------------------------------------------------------------------ 卵情報
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
end------------------------------------------------------------------ 空中フライ移動
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

    while os.clock() - started < CFG.FlyTimeout do
        if flyState.Cancel then break end
        if type(onCancelCheck) == "function" and onCancelCheck() then break end

        local r = root()
        if not r or not r.Parent then break end

        local delta = target - r.Position
        local dist = delta.Magnitude
        if dist <= 2 then result = true; break end

        local dir = dist > 0.01 and delta.Unit or Vector3.zero
        local step = CFG.Speed * (1 / 60)
        if step > dist then step = dist end

        local nextPos = r.Position + dir * step

        pcall(function()
            r.CFrame = CFrame.new(nextPos) * r.CFrame.Rotation
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)

        if lastMark and (r.Position - lastMark).Magnitude < 1 then
            if os.clock() - lastClock > 0.5 then break end
        else
            lastMark = r.Position
            lastClock = os.clock()
        end

        RunService.Heartbeat:Wait()
    end

    if humanoid then
        pcall(function() humanoid.PlatformStand = false end)
    end

    return result
end

------------------------------------------------------------------ 掴む
local function grab(uid, timeout)
    timeout = timeout or CFG.GrabTimeout
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
                local pace = 200
                local v = delta / math.max(0.08, dt)
                if v.Magnitude > pace then v = v.Unit * pace end
                pcall(function()
                    r.AssemblyLinearVelocity = v + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end
            if since >= CFG.GrabInterval then
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

------------------------------------------------------------------ 納品
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
        task.wait(CFG.DropDelay)
        dropEgg()
        local waited = 0
        while state.Delivered < started and waited < 1.5 do
            waited += RunService.Heartbeat:Wait()
        end
    end
    return state.Delivered >= started
	end------------------------------------------------------------------ メイン処理
local function stealAndDeliver(uid)
    if state.Busy then return end
    state.Busy = true
    state.Cancel = false
    resetFly()

    task.spawn(function()
        local ok, err = pcall(function()
            local egg = eggPosition(uid)
            if not egg then return end

            if state.Carrying and state.Uid ~= uid then
                dropEgg()
                local waited = 0
                while state.Carrying and waited < 1 do
                    waited += RunService.Heartbeat:Wait()
                end
            end

            if not flyTo(egg + Vector3.new(0, 3, 0)) then
                local live = eggNow(uid, { At = 0 })
                if live then flyTo(live + Vector3.new(0, 3, 0)) end
            end

            if not grab(uid, CFG.GrabTimeout) then return end

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

------------------------------------------------------------------ オートループ
local autoThread = nil
local autoEnabled = false

local function startAutoSteal()
    if autoThread then return end
    autoEnabled = true
    autoThread = task.spawn(function()
        while autoEnabled do
            if not state.Busy then
                local target = pickTarget()
                if target then stealAndDeliver(target.Uid) end
            end
            task.wait(0.3)
        end
    end)
end

local function stopAutoSteal()
    autoEnabled = false
    state.Cancel = true
    cancelFly()
    autoThread = nil
		end------------------------------------------------------------------ UI (ShouyuHub水色スタイル)
local function makeUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ShouyuStealUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local ok = pcall(function()
        if typeof(gethui) == "function" then gui.Parent = gethui()
        else gui.Parent = CoreGui end
    end)
    if not ok then gui.Parent = localPlayer:WaitForChild("PlayerGui") end

    local W, H = 360, 460
    local main = Instance.new("Frame")
    main.Size = UDim2.fromOffset(W, H)
    main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    main.BackgroundColor3 = THEME.Bg
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = main

    -- 外枠ストローク（水色グロー）
    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Accent
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = main

    -- 上部の水色ライン
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
    header.Size = UDim2.new(1, -16, 0, 44)
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
    hStroke.Transparency = 0.4
    hStroke.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.fromOffset(16, 0)
    title.BackgroundTransparency = 1
    title.Text = "SHOUYU STEAL HUB"
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

    -- ステータス
    local status = Instance.new("TextLabel")
    status.Name = "StatusLabel"
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.fromOffset(14, 56)
    status.BackgroundTransparency = 1
    status.Text = "速度: " .. CFG.Speed .. " / 待機中"
    status.TextColor3 = THEME.TextDim
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 6
    status.Parent = main

    -- 卵リスト
    local list = Instance.new("ScrollingFrame")
    list.Name = "EggList"
    list.Size = UDim2.new(1, -20, 1, -190)
    list.Position = UDim2.fromOffset(10, 82)
    list.BackgroundColor3 = THEME.Panel
    list.BackgroundTransparency = 0.15
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = THEME.Accent
    list.CanvasSize = UDim2.new()
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 5
    list.Parent = main

    local lCorner = Instance.new("UICorner")
    lCorner.CornerRadius = UDim.new(0, 10)
    lCorner.Parent = list

    local lStroke = Instance.new("UIStroke")
    lStroke.Color = THEME.Stroke
    lStroke.Thickness = 1
    lStroke.Transparency = 0.5
    lStroke.Parent = list

    local lLayout = Instance.new("UIListLayout")
    lLayout.Padding = UDim.new(0, 4)
    lLayout.SortOrder = Enum.SortOrder.LayoutOrder
    lLayout.Parent = list

    local lPad = Instance.new("UIPadding")
    lPad.PaddingTop = UDim.new(0, 6)
    lPad.PaddingBottom = UDim.new(0, 6)
    lPad.PaddingLeft = UDim.new(0, 6)
    lPad.PaddingRight = UDim.new(0, 8)
    lPad.Parent = list

    -- レアリティ色
    local RARITY = {
        Color3.fromRGB(190, 190, 190),
        Color3.fromRGB(110, 210, 110),
        Color3.fromRGB(90, 160, 255),
        Color3.fromRGB(190, 110, 255),
        Color3.fromRGB(255, 170, 50),
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(255, 90, 200),
        Color3.fromRGB(80, 235, 235),
    }

    local selectedUid = nil
    local rows = {}

    local function setSelected(uid)
        selectedUid = uid
        for rowUid, row in pairs(rows) do
            local on = rowUid == uid
            row.Stroke.Thickness = on and 2 or 1
            row.Stroke.Color = on and THEME.Accent or THEME.Stroke
            row.Stroke.Transparency = on and 0 or 0.6
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
            frame.Size = UDim2.new(1, 0, 0, 42)
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
            icon.Size = UDim2.fromOffset(34, 34)
            icon.Position = UDim2.fromOffset(4, 4)
            icon.BackgroundTransparency = 1
            icon.Image = info.Icon
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Parent = frame

            local name = Instance.new("TextLabel")
            name.Size = UDim2.new(1, -46, 0, 20)
            name.Position = UDim2.fromOffset(44, 3)
            name.BackgroundTransparency = 1
            name.Text = info.Name
            name.TextColor3 = RARITY[math.clamp(info.Rarity, 1, #RARITY)] or THEME.Text
            name.Font = Enum.Font.GothamBold
            name.TextSize = 14
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd
            name.Parent = frame

            local value = Instance.new("TextLabel")
            value.Size = UDim2.new(1, -46, 0, 15)
            value.Position = UDim2.fromOffset(44, 22)
            value.BackgroundTransparency = 1
            value.Text = money(info.Value)
            value.TextColor3 = THEME.AccentSoft
            value.Font = Enum.Font.GothamMedium
            value.TextSize = 12
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

    return gui, main, header, status, rebuild, function() return selectedUid end
			end------------------------------------------------------------------ UI ボタン・起動
local gui, main, header, statusLabel, rebuildList, getSelectedUid = makeUI()
local W, H = 360, 460

-- ボタン生成ヘルパー
local function makeButton(text, pos, size, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = THEME.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.AutoButtonColor = true
    btn.ZIndex = 6
    btn.Parent = parent

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 10)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = THEME.AccentDark
    bStroke.Thickness = 1
    bStroke.Transparency = 0.4
    bStroke.Parent = btn

    return btn, bStroke
end

local refreshBtn = makeButton("更新",
    UDim2.new(0, 10, 1, -70),
    UDim2.new(0.32, -12, 0, 44),
    THEME.Card, main)

local autoBtn = makeButton("自動盗み",
    UDim2.new(0.32, 0, 1, -70),
    UDim2.new(0.36, -6, 0, 44),
    Color3.fromRGB(30, 80, 60), main)

local instantBtn = makeButton("即盗み",
    UDim2.new(0.68, 6, 1, -70),
    UDim2.new(0.32, -16, 0, 44),
    Color3.fromRGB(30, 70, 100), main)

refreshBtn.MouseButton1Click:Connect(function()
    if not state.Busy then
        rebuildList()
        statusLabel.Text = "更新完了"
    end
end)

autoBtn.MouseButton1Click:Connect(function()
    if autoEnabled then
        stopAutoSteal()
        autoBtn.Text = "自動盗み"
        autoBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 60)
        statusLabel.Text = "自動盗み停止"
    else
        startAutoSteal()
        autoBtn.Text = "停止"
        autoBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
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

-- ドラッグ
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
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
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- 自動更新
task.spawn(function()
    while gui.Parent do
        task.wait(5)
        if not state.Busy and not autoEnabled then
            pcall(rebuildList)
        end
    end
end)

-- ボタン状態監視
task.spawn(function()
    while gui.Parent do
        task.wait(0.3)
        if state.Busy then
            instantBtn.Text = "実行中..."
            instantBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 30)
        else
            instantBtn.Text = "即盗み"
            instantBtn.BackgroundColor3 = Color3.fromRGB(30, 70, 100)
        end
    end
end)------------------------------------------------------------------ 起動
print("[Shouyu Steal Hub] 起動完了")
print("  速度: " .. CFG.Speed)
print("  テーマ: 水色")
print("  Auto Steal / Instant Steal 有効")
				
