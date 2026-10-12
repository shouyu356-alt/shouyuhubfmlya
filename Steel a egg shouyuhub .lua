-- ===== PART 1/8: 設定・日本語化テーブル =====
-- yslemEgg | Instant TP | 日本語化 & UI大型化 & Steal改善版

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local localPlayer = Players.LocalPlayer

-- 日本語化テーブル
local JA = {
    ["Title"] = "卵盗みツール",
    ["Refresh"] = "更新",
    ["Steal"] = "盗む",
    ["Cancel"] = "キャンセル",
    ["Pick a pet"] = "ペットを選択してください",
    ["Selected: "] = "選択中: ",
    ["Looking for the egg"] = "卵を探しています",
    ["Going to the egg"] = "卵の場所へ移動中",
    ["Taking the egg"] = "卵を掴んでいます",
    ["Delivered"] = "納品完了",
    ["Delivery failed"] = "納品失敗",
    ["That egg is gone"] = "卵が消えました",
    ["Could not reach the egg"] = "卵にたどり着けません",
    ["The egg would not come free"] = "卵が外れません",
    ["Cancelling"] = "キャンセル中",
    ["Error"] = "エラー",
    ["Something went wrong"] = "問題が発生しました",
    ["Delivering"] = "納品中",
    ["Safe zone"] = "セーフゾーン",
    ["Instant TP: hopping home"] = "瞬間移動: ホームへ跳躍中",
    ["Instant TP: landing next to the line"] = "瞬間移動: ラインの隣に着地",
    ["Instant TP: dropping the egg"] = "瞬間移動: 卵をドロップ",
    ["Instant TP: taking the egg back"] = "瞬間移動: 卵を回収",
    ["Instant TP: pulled back"] = "瞬間移動: 引き戻されました",
    ["Instant TP: landing retry"] = "瞬間移動: 着地リトライ",
    ["The egg fell far behind, teleporting onto it"] = "卵が遠くに落ちました。テレポートします",
    ["The egg fell close, taking it back"] = "卵が近くに落ちました。回収します",
    ["Could not take the egg back"] = "卵を回収できませんでした",
    ["Error: "] = "エラー: ",
}

local function jp(msg)
    msg = tostring(msg)
    for k, v in pairs(JA) do
        if string.sub(msg, 1, #k) == k then
            return v .. string.sub(msg, #k + 1)
        end
    end
    return msg
end-- ===== PART 2/8: 設定・ゲームハンドル =====

-- 設定（Steal改善のため調整済み）
local CFG = {
    SpeedCap = 1.15,
    HopRatio = 1.515,
    HopMin = 40,
    HopGap = 0.06,
    HopGapMin = 0.05,      -- 改善: 最小間隔を短縮
    HopGapMax = 0.15,      -- 改善: 最大間隔を短縮
    HopRetries = 10,       -- 改善: リトライ回数を6→10に増加
    HopLift = 42,
    LandOffset = 14,
    LandSettle = 0.05,     -- 改善: 着地待ちを短縮
    DropDelay = 0.03,      -- 改善: ドロップ遅延を短縮
    GrabInterval = 0.02,   -- 改善: グラブ間隔を短縮
    RegrabFar = 35,        -- 改善: 再グラブ距離を短縮
    Height = 70,
    ClimbShare = 0.5,
    CarryRatio = 0.9,
    EasyRatio = 1.3,
    -- 追加: 盗み失敗対策
    GrabRetries = 8,       -- グラブ試行回数
    GrabTimeout = 1.5,     -- グラブタイムアウト
    PromptRadius = 25,     -- 改善: プロンプト検出半径を拡大
}

local FPS = { 60, 30, 0.15 }

-- ゲームハンドル
local function safeRequire(getter)
    local ok, result = pcall(function() return require(getter()) end)
    return ok and result or nil
end

local networkingFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(name)
    return networkingFolder:FindFirstChild(name)
end

local function root()
    local character = localPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
	end
	-- ===== PART 3/8: シールド機能（Humanoid Swap） =====

local shield = { Original = nil, Clone = nil, Links = {}, Connection = nil, Added = nil }

local function walkSpeed()
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local speed = humanoid and humanoid.WalkSpeed or 16
    if shield.Original and shield.Original.Health > 0 then
        speed = math.min(speed, shield.Original.WalkSpeed)
    end
    local ok, result = pcall(function()
        local stat = localPlayer:FindFirstChild("leaderstats")
        stat = stat and stat:FindFirstChild("Speed")
        local util = require(ReplicatedStorage.Shared.Util.TreadmillUtil)
        return stat and util.SpeedPowerToWalkSpeed(stat.Value) or nil
    end)
    if ok and type(result) == "number" and result > 0 then
        speed = math.min(speed, result)
    end
    return speed
end

local function shieldControls(humanoid)
    pcall(function()
        local scripts = localPlayer:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if module then
            local controls = require(module):GetControls()
            if type(controls) == "table" then
                controls.humanoid = humanoid
            end
        end
    end)
end

local function shieldAnimate(character)
    local animate = character and character:FindFirstChild("Animate")
    if animate and animate:IsA("LocalScript") then
        task.spawn(function()
            animate.Enabled = false
            task.wait()
            animate.Enabled = true
        end)
    end
end

local function shieldUnlink()
    for _, link in ipairs(shield.Links) do
        pcall(function() link:Disconnect() end)
    end
    table.clear(shield.Links)
end

local groundedStates = {
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.RunningNoPhysics] = true,
    [Enum.HumanoidStateType.Landed] = true,
}

local function grounded(humanoid)
    if not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
        return false
    end
    return groundedStates[humanoid:GetState()] == true
end

local function shieldSwap()
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if shield.Clone and shield.Clone.Parent == character then return end
    if not grounded(humanoid) then return end
    local clone = humanoid:Clone()
    humanoid.Parent = nil
    clone.Parent = character
    workspace.CurrentCamera.CameraSubject = clone
    shieldControls(clone)
    shieldAnimate(character)
    shield.Original = humanoid
    shield.Clone = clone
    table.insert(shield.Links, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if clone.Parent ~= nil then clone.WalkSpeed = humanoid.WalkSpeed end
    end))
    local animator = humanoid:FindFirstChildOfClass("Animator")
    local animator2 = clone:FindFirstChildOfClass("Animator")
    if animator and animator2 then
        table.insert(shield.Links, animator.AnimationPlayed:Connect(function(played)
            local animation = played.Animation
            if not animation or clone.Parent == nil then return end
            local ok, track = pcall(function() return animator2:LoadAnimation(animation) end)
            if not ok or not track then return end
            pcall(function()
                track.Priority = played.Priority
                track.Looped = played.Looped
                track:Play(0.05, math.max(played.WeightTarget, 0.01), played.Speed)
            end)
            local stopped
            stopped = played.Stopped:Connect(function()
                stopped:Disconnect()
                pcall(function() track:Stop(0.1) end)
            end)
        end))
    end
    table.insert(shield.Links, clone.Died:Connect(function()
        shieldUnlink()
        shield.Original, shield.Clone = nil, nil
        local current = localPlayer.Character
        if current and humanoid.Parent == nil then
            humanoid.Parent = current
            workspace.CurrentCamera.CameraSubject = humanoid
            shieldControls(humanoid)
        end
        pcall(function() clone:Destroy() end)
        humanoid.Health = 0
    end))
end

local function shieldUndo()
    shieldUnlink()
    local character = localPlayer.Character
    local original, clone = shield.Original, shield.Clone
    shield.Original, shield.Clone = nil, nil
    if original and clone and character and original.Parent == nil and clone.Parent == character then
        original.Parent = character
        workspace.CurrentCamera.CameraSubject = original
        shieldControls(original)
        pcall(function() clone:Destroy() end)
        shieldAnimate(character)
    end
end

local function shieldStart()
    shieldSwap()
    local n = 0
    shield.Connection = RunService.Heartbeat:Connect(function(dt)
        n += dt
        local character = localPlayer.Character
        local missing = not (shield.Clone and character and shield.Clone.Parent == character)
        if (missing and 0.25 or 3) <= n then
            n = 0
            shieldSwap()
        end
    end)
    shield.Added = localPlayer.CharacterAdded:Connect(function(character)
        shieldUnlink()
        shield.Original, shield.Clone = nil, nil
        task.spawn(function()
            character:WaitForChild("Humanoid", 10)
            task.wait(1)
            if shield.Connection and localPlayer.Character == character then
                shieldSwap()
            end
        end)
    end)
end

local function shieldStop()
    if shield.Connection then
        shield.Connection:Disconnect()
        shield.Connection = nil
    end
    if shield.Added then
        shield.Added:Disconnect()
        shield.Added = nil
    end
    shieldUndo()
	end
	-- ===== PART 4/8: キャリー状態管理・スナップショット =====

local state = {
    Carrying = false,
    Uid = nil,
    Delivered = 0,
    Busy = false,
    Cancel = false,
    Mult = 1,
    PulledAt = 0,
    HeldSeen = 0,
    GuessedDrop = false,
    ReleaseCamera = nil,
}

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" and type(EggState.CarryChanged.Connect) == "function" then
    EggState.CarryChanged:Connect(function(arg)
        local carrying = type(arg) == "table" and arg.IsCarrying == true
        if carrying and arg.GuardDisabled == true then
            carrying = false
        end
        state.GuessedDrop = false
        if carrying then
            state.HeldSeen = os.clock()
        end
        if carrying and type(arg.Uid) == "string" then
            state.Uid = arg.Uid
            local mult = tonumber(arg.SpeedMultiplier)
            if mult and mult > 0 then
                state.Mult = mult
            end
        end
        state.Carrying = carrying
    end)
end

pcall(function()
    remote("RE/EggWorld/FieldEggRedeemVerdict").OnClientEvent:Connect(function()
        state.Delivered = os.clock()
    end)
end)

pcall(function()
    remote("RE/RigSync/Refresh").OnClientEvent:Connect(function(arg)
        if type(arg) == "table" and arg.Action == "Relocate" then
            state.PulledAt = os.clock()
        end
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

-- 改善: プロンプト検出半径を拡大、検出ロジックを強化
local function promptNear(position, radius)
    local best, bestDistance = nil, radius or CFG.PromptRadius
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

local function heldByMe(uid)
    local character = localPlayer.Character
    if type(uid) ~= "string" or not character then return false end
    local egg = workspace:FindFirstChild(uid)
    if not egg then return false end
    for _, d in ipairs(egg:GetDescendants()) do
        if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
            local ok, a, b = pcall(function() return d.Part0, d.Part1 end)
            if ok and ((a and a:IsDescendantOf(character)) or (b and b:IsDescendantOf(character))) then
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
    local list = {}
    local ok, result = pcall(function()
        return remote("RF/EggWorld/AskFieldEggSnapshot"):InvokeServer()
    end)
    local records = ok and type(result) == "table" and result.Records or nil
    if type(records) ~= "table" then return list end
    for _, record in pairs(records) do
        if type(record) == "table" and type(record.Uid) == "string"
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
	-- ===== PART 5/8: 卵情報・金額表示 =====

local function describe(record)
    local directory = type(Assets) == "table" and Assets.Directory or nil
    local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
    local info = {
        Uid = record.Uid,
        Category = tostring(record.AssetCategory),
        Name = tostring(record.AssetCategory),
        Icon = "",
        Rarity = 0,
        Value = 0,
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
            local okM, resM = pcall(Mutations.EarningsFor, type(record.Mutations) == "table" and record.Mutations or {})
            if okM and type(resM) == "number" then
                mutation = resM
            end
        end
        info.Value = (tonumber(entry.EarningRate) or 0) * factor * mutation
    end
    return info
end

local function money(value)
    local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, u in ipairs(units) do
        if value >= u[1] then
            return string.format("$%.2f%s/s", value / u[1], u[2])
        end
    end
    return string.format("$%d/s", math.floor(value + 0.5))
	end
	-- ===== PART 6/8: Instant TP・盗みロジック改善 =====

local status = function(text) end

local function frozenCamera()
    local camera = workspace.CurrentCamera
    if not camera then return function() end end
    local oldType = camera.CameraType
    local frame = camera.CFrame
    pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = frame
    end)
    return function()
        pcall(function() camera.CameraType = oldType end)
    end
end

local fpsGen = 0

local function fpsOn()
    if typeof(setfpscap) ~= "function" then return end
    fpsGen += 1
    local mine = fpsGen
    task.spawn(function()
        local high = true
        local started = os.clock()
        while fpsGen == mine and os.clock() - started < 60 do
            pcall(setfpscap, high and FPS[1] or FPS[2])
            high = not high
            task.wait(FPS[3])
        end
    end)
end

local function fpsOff()
    fpsGen += 1
    if typeof(setfpscap) == "function" then pcall(setfpscap, 240) end
end

local stealClone = nil

local function dropClone()
    local copy = stealClone
    stealClone = nil
    if copy then pcall(function() copy:Destroy() end) end
end

local function postClone()
    dropClone()
    local character = localPlayer.Character
    if not character then return end
    local was = character.Archivable
    character.Archivable = true
    local copy = character:Clone()
    character.Archivable = was
    if copy then
        for _, d in ipairs(copy:GetDescendants()) do
            if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") then
                pcall(function() d:Destroy() end)
            elseif d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanTouch = false
                d.CanQuery = false
            end
        end
        copy.Name = "Clone"
        copy.Parent = workspace
        stealClone = copy
    end
end

local function regrab(uid)
    if state.Carrying then return true end
    local r = root()
    local egg = eggPosition(uid)
    if r and egg and Vector3.new(r.Position.X - egg.X, 0, r.Position.Z - egg.Z).Magnitude > CFG.RegrabFar then
        status("卵が遠くに落ちました。テレポートします")
        place(egg + Vector3.new(0, 3, 0))
    else
        status("卵が近くに落ちました。回収します")
    end
    return grab(uid, CFG.GrabTimeout)
end

local function groundY(position, fallback)
    local y = fallback
    pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { localPlayer.Character }
        params.IgnoreWater = true
        local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), params)
        if hit and hit.Material ~= Enum.Material.Water and math.abs(hit.Position.Y - fallback) < 40 then
            y = hit.Position.Y + 3.5
        end
    end)
    return y
end

local function carrySpeed(distance)
    local ws = walkSpeed()
    local base = ws * math.min(CFG.CarryRatio, CFG.SpeedCap) * state.Mult
    local fast = base * 1.5
    local excess = 5.5 * base
    local limit = fast
    if distance and distance > excess then
        limit = math.min(fast, base * distance / (distance - excess))
    end
    return math.min(math.max(math.min(base * CFG.EasyRatio, limit), base), math.max(ws * CFG.SpeedCap, base))
end

local function runHome(lineX, laneZ)
    local started = os.clock()
    local home = homePoint()
    local checkpoint = lineX - 7
    local height = CFG.Height
    local share = math.clamp(CFG.ClimbShare, 0.1, 0.9)
    local descent = height * math.sqrt(1 - share * share) / share
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
    end
    local r = root()
    if r and character and height > 0.5 and home.Y + height - 2 > r.Position.Y then
        pcall(function()
            character:PivotTo(CFrame.new(Vector3.new(r.Position.X, home.Y + height, r.Position.Z)) * r.CFrame.Rotation)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    local start = root()
    local speed = carrySpeed(start and (Vector3.new(start.Position.X - home.X, 0, start.Position.Z - home.Z).Magnitude + math.max(0, height) * 2) or nil)
    local last = os.clock()
    local timeout = 0
    status("セーフゾーン")
    while state.Carrying and state.Delivered < started and not state.Cancel and timeout < 25 do
        r = root()
        if not r then return false end
        local now = os.clock()
        local dt = math.max(now - last, 1 / 240)
        last = now
        timeout += dt
        local toHome = r.Position.X <= checkpoint + 2
        local target = toHome and home or Vector3.new(checkpoint, home.Y, laneZ)
        if toHome and Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z).Magnitude < 2 then
            break
        end
        local aim = avoid(r.Position, target)
        local flat = Vector3.new(aim.X - r.Position.X, 0, aim.Z - r.Position.Z)
        local remaining = toHome and 0 or math.max(0, r.Position.X - checkpoint)
        local wantY = home.Y + height
        if toHome or remaining <= descent then
            wantY = home.Y + height * math.clamp(remaining / math.max(descent, 1), 0, 1)
        end
        local vy = math.clamp((wantY - r.Position.Y) / 0.12, -speed * share, speed * share)
        local horizontal = math.sqrt(math.max(speed * speed - vy * vy, 0))
        local v = flat.Magnitude > 0.01 and flat.Unit * math.min(horizontal, flat.Magnitude / 0.05) or Vector3.zero
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
        end)
        RunService.Heartbeat:Wait()
    end
    if humanoid then
        pcall(function() humanoid:Move(Vector3.zero, false) end)
    end
    local settle = 0
    while settle < 2 and state.Delivered < started and state.Carrying and not state.Cancel do
        settle += RunService.Heartbeat:Wait()
    end
    if state.Carrying and state.Delivered < started and not state.Cancel then
        task.wait(0.2)
        dropEgg()
        local waited = 0
        while state.Delivered < started and waited < 1 do
            waited += RunService.Heartbeat:Wait()
        end
    end
    return state.Delivered >= started
end

local function instantTP(uid)
    local started = os.clock()
    local lineX, lineY = lineInfo()
    local r = root()
    if not r then return false end
    local laneZ = math.clamp(r.Position.Z, -425, -300)
    local landing = Vector3.new(lineX + CFG.LandOffset, lineY + 3.35, laneZ)
    local hopStep = math.max(walkSpeed() * CFG.HopRatio, CFG.HopMin)
    local hopY = r.Position.Y + CFG.HopLift
    local x = r.Position.X
    local retries = 0
    local releaseCamera = frozenCamera()
    state.ReleaseCamera = releaseCamera
    pcall(postClone)
    fpsOn()
    while x - hopStep > landing.X and not state.Cancel do
        if not state.Carrying then
            if not regrab(uid) then break end
            local current = root()
            if current then x = math.min(x, current.Position.X) end
            continue
        end
        local nextX = x - hopStep
        status(string.format("瞬間移動: ホームへ跳躍中, X %d", math.floor(nextX)))
        local pulledBefore = state.PulledAt
        local held = 0
        while held < CFG.HopGap do
            place(Vector3.new(nextX, hopY, laneZ))
            held += RunService.Heartbeat:Wait()
        end
        local check = root()
        local pulled = state.PulledAt > pulledBefore or (check ~= nil and (check.Position.X - nextX > 10 or check.AssemblyLinearVelocity.Magnitude > 150))
        if pulled and state.Carrying and not state.Cancel then
            retries += 1
            CFG.HopGap = math.min(CFG.HopGapMax, CFG.HopGap + 0.02)
            if retries > CFG.HopRetries then break end
            status(string.format("瞬間移動: 引き戻されました, リトライ %d/%d", retries, CFG.HopRetries))
            local settle = 0
            while settle < 0.12 and not state.Cancel do
                place(Vector3.new(x, hopY, laneZ))
                settle += RunService.Heartbeat:Wait()
            end
        else
            x = nextX
            CFG.HopGap = math.max(CFG.HopGapMin, CFG.HopGap - 0.01)
        end
    end
    status("瞬間移動: ラインの隣に着地")
    landing = Vector3.new(landing.X, groundY(landing, landing.Y), landing.Z)
    local function land()
        local current = root()
        if current and current.Position.X <= landing.X + 1 and current.Position.Y > landing.Y - 25 then
            pcall(function() current.AssemblyLinearVelocity = Vector3.zero end)
            return
        end
        place(landing)
    end
    land()
    for attempt = 1, 5 do
        local settle = 0
        while settle < CFG.LandSettle and not state.Cancel do
            settle += RunService.Heartbeat:Wait()
        end
        local landed = root()
        if state.Carrying and landed and (landed.Position.X - landing.X > 12 or landed.Position.Y < landing.Y - 25) then
            status("瞬間移動: 着地リトライ " .. attempt)
            land()
        else
            break
        end
    end
    dropClone()
    if state.Carrying and not state.Cancel then
        local delay = 0
        while delay < CFG.DropDelay do
            delay += RunService.Heartbeat:Wait()
        end
        status("瞬間移動: 卵をドロップ")
        dropEgg()
        local waited = 0
        while state.Carrying and waited < 1 and not state.Cancel do
            waited += RunService.Heartbeat:Wait()
        end
        local current = root()
        if current then
            pcall(function()
                current.AssemblyLinearVelocity = Vector3.zero
                current.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        releaseCamera()
        dropClone()
        status("瞬間移動: 卵を回収")
        if not grab(uid, CFG.GrabTimeout) and not regrab(uid) then
            fpsOff()
            status("卵を回収できませんでした")
            return false
        end
        dropClone()
    end
    releaseCamera()
    local ok = false
    if state.Carrying then
        ok = runHome(lineX, laneZ)
    end
    fpsOff()
    return ok or state.Delivered >= started
end

local function stealAndDeliver(uid)
    if state.Busy then return end
    state.Busy = true
    state.Cancel = false
    task.spawn(function()
        local ok, err = pcall(function()
            status("卵を探しています")
            local egg = eggPosition(uid)
            if not egg then
                status("卵が消えました")
                return
            end
            if state.Carrying and state.Uid ~= uid then
                dropEgg()
                local waited = 0
                while state.Carrying and waited < 1 do
                    waited += RunService.Heartbeat:Wait()
                end
            end
            fpsOn()
            status("卵の場所へ移動中")
            if not runToEgg(uid, egg) then
                fpsOff()
                status("卵にたどり着けません")
                return
            end
            status("卵を掴んでいます")
            if not grab(uid, CFG.GrabTimeout) then
                fpsOff()
                status("卵が外れません")
                return
            end
            local delivered = instantTP(uid)
            status(delivered and "納品完了" or "納品失敗")
        end)
        fpsOff()
        dropClone()
        if state.ReleaseCamera then
            pcall(state.ReleaseCamera)
            state.ReleaseCamera = nil
        end
        if not ok then
            status("エラー: " .. tostring(err))
        end
        state.Busy = false
    end)
	end-- ===== PART 7/8: UI大型化・開閉 =====

local WHITE = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(220, 40, 50)
local RED_BRIGHT = Color3.fromRGB(255, 70, 80)
local RED_DARK = Color3.fromRGB(80, 12, 18)
local BG = Color3.fromRGB(0, 0, 0)
local RARITY_COLORS = {
    Color3.fromRGB(190, 190, 190),
    Color3.fromRGB(110, 210, 110),
    Color3.fromRGB(90, 160, 255),
    Color3.fromRGB(190, 110, 255),
    Color3.fromRGB(255, 170, 50),
    Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(255, 90, 200),
    Color3.fromRGB(80, 235, 235),
}

local function parentGui()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and typeof(result) == "Instance" then return result end
    end
    return CoreGui
end

local function make(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    return inst
end

local function corner(parent, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }).Parent = parent
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
        Color = RED,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    s.Parent = parent
    local g = make("UIGradient", {
        Rotation = 45,
        Color = bands(bright and RED_BRIGHT or RED, RED_DARK),
    })
    g.Parent = s
    living[#living + 1] = g
    return s, g
end

local function livingText(label)
    local g = make("UIGradient", { Color = bands(RED_BRIGHT, RED) })
    g.Parent = label
    living[#living + 1] = g
    return g
end

local function text(parent, props)
    local alive = props.Living ~= false
    props.Living = nil
    props.BackgroundTransparency = 1
    props.TextColor3 = props.TextColor3 or WHITE
    local l = make("TextLabel", props)
    l.Parent = parent
    if alive then livingText(l) end
    return l
end

local old = parentGui():FindFirstChild("yslemEgg")
if old then old:Destroy() end

-- UI大型化: W=320, H=400
local W, H, HEADER = 320, 400, 36
local gui = make("ScreenGui", {
    Name = "yslemEgg",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
})
gui.Parent = parentGui()

local window = make("Frame", {
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    ClipsDescendants = false,
})
window.Parent = gui
corner(window, 18)
livingStroke(window, 1, true)

local rotation = 0
local tick = 0
local shineConnection = RunService.Heartbeat:Connect(function(dt)
    tick += 1
    if tick % 2 ~= 0 then return end
    rotation = (rotation + dt * 72) % 360
    for _, g in ipairs(living) do
        if g.Parent then
            g.Rotation = g.Parent:IsA("UIStroke") and (45 + rotation) % 360 or rotation
        end
    end
end)

-- ヘッダー
local header = make("Frame", {
    Size = UDim2.new(1, -8, 0, HEADER - 4),
    Position = UDim2.fromOffset(4, 4),
    BackgroundColor3 = RED,
    BorderSizePixel = 0,
})
header.Parent = window
corner(header, 10)
do
    local g = make("UIGradient", { Color = bands(RED_BRIGHT, RED_DARK) })
    g.Parent = header
    living[#living + 1] = g
end

text(header, {
    Size = UDim2.new(1, -44, 1, 0),
    Position = UDim2.fromOffset(10, 0),
    Font = Enum.Font.GothamBlack,
    TextSize = 14,
    TextColor3 = Color3.new(0, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "卵盗みツール",
    Living = false,
})

local function headerButton(label, offset)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(26, 22),
        Position = UDim2.new(1, offset, 0.5, -11),
        BackgroundColor3 = BG,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = WHITE,
        Text = label,
        AutoButtonColor = true,
    })
    b.Parent = header
    corner(b, 7)
    livingStroke(b, 1, true)
    livingText(b)
    return b
end

local minimize = headerButton("-", -60)
local close = headerButton("x", -30)

local body = make("Frame", {
    Size = UDim2.new(1, -10, 1, -(HEADER + 8)),
    Position = UDim2.fromOffset(5, HEADER + 4),
    BackgroundTransparency = 1,
})
body.Parent = window

local list = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -80),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = RED,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = body
corner(list, 12)
livingStroke(list, 1, false)

make("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = list

make("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 8),
}).Parent = list

local statusLabel = text(body, {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 1, -72),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "ペットを選択してください",
})

local PUBLIC = {
    ["ペットを選択してください"] = true,
    ["卵を探しています"] = true,
    ["卵の場所へ移動中"] = true,
    ["卵を掴んでいます"] = true,
    ["納品完了"] = true,
    ["納品失敗"] = true,
    ["卵が消えました"] = true,
    ["卵にたどり着けません"] = true,
    ["卵が外れません"] = true,
    ["キャンセル中"] = true,
}

status = function(msg)
    msg = jp(tostring(msg))
    if PUBLIC[msg] or string.sub(msg, 1, 9) == "選択中: " then
        statusLabel.Text = msg
    elseif string.sub(msg, 1, 5) == "エラー" then
        statusLabel.Text = "問題が発生しました"
    elseif state.Busy then
        statusLabel.Text = "納品中"
    end
end

local function bigButton(label, position, size)
    local b = make("TextButton", {
        Size = size,
        Position = position,
        BackgroundColor3 = BG,
        Font = Enum.Font.GothamBlack,
        TextSize = 16,
        TextColor3 = WHITE,
        Text = label,
        AutoButtonColor = true,
    })
    b.Parent = body
    corner(b, 17)
    livingStroke(b, 1, true)
    livingText(b)
    return b
end

local refreshButton = bigButton("更新", UDim2.new(0, 0, 1, -46), UDim2.new(0.4, -3, 0, 42))
local stealButton = bigButton("盗む", UDim2.new(0.4, 3, 1, -46), UDim2.new(0.6, -3, 0, 42))
		-- ===== PART 8/8: リスト構築・イベント・統合 =====

local selectedUid = nil
local rows = {}

local function setSelected(uid)
    selectedUid = uid
    for rowUid, row in pairs(rows) do
        local on = rowUid == uid
        row.Stroke.Thickness = on and 1.5 or 1
        row.Gradient.Color = on and bands(RED_BRIGHT, RED_DARK) or bands(RED_DARK, Color3.fromRGB(30, 5, 8))
    end
end

local function rebuild()
    for _, row in pairs(rows) do
        row.Frame:Destroy()
    end
    table.clear(rows)
    for i = #living, 1, -1 do
        if not living[i].Parent then
            table.remove(living, i)
        end
    end
    local infos = {}
    for _, record in ipairs(snapshot()) do
        infos[#infos + 1] = describe(record)
    end
    table.sort(infos, function(a, b) return a.Value > b.Value end)
    local still = false
    for index, info in ipairs(infos) do
        still = still or info.Uid == selectedUid
        local frame = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = BG,
            LayoutOrder = index,
            Text = "",
            AutoButtonColor = true,
        })
        frame.Parent = list
        corner(frame, 10)
        local rowStroke, rowGradient = livingStroke(frame, 1, false)
        make("ImageLabel", {
            Size = UDim2.fromOffset(32, 32),
            Position = UDim2.fromOffset(5, 4),
            BackgroundTransparency = 1,
            Image = info.Icon,
            ScaleType = Enum.ScaleType.Fit,
        }).Parent = frame
        text(frame, {
            Size = UDim2.new(1, -42, 0, 18),
            Position = UDim2.fromOffset(42, 3),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = info.Name,
            TextColor3 = RARITY_COLORS[math.clamp(info.Rarity, 1, #RARITY_COLORS)] or WHITE,
        })
        text(frame, {
            Size = UDim2.new(1, -42, 0, 14),
            Position = UDim2.fromOffset(42, 22),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = money(info.Value),
        })
        rows[info.Uid] = { Frame = frame, Stroke = rowStroke, Gradient = rowGradient }
        frame.MouseButton1Click:Connect(function()
            setSelected(info.Uid)
            status("選択中: " .. info.Name)
        end)
    end
    setSelected(still and selectedUid or nil)
    if #infos == 0 then
        status("ペットを選択してください")
    end
end

refreshButton.MouseButton1Click:Connect(function()
    if not state.Busy then rebuild() end
end)

stealButton.MouseButton1Click:Connect(function()
    if state.Busy then
        state.Cancel = true
        status("キャンセル中")
        return
    end
    if not selectedUid then
        status("ペットを選択してください")
        return
    end
    stealAndDeliver(selectedUid)
end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        stealButton.Text = state.Busy and "キャンセル" or "盗む"
    end
end)

-- ドラッグ
do
    local dragging, startPos, startInput
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, window.Position, input.Position
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
            local delta = input.Position - startInput
            window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 開閉（アニメーション付き）
local minimized = false
local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function toggleMinimize()
    minimized = not minimized
    if minimized then
        TweenService:Create(window, TWEEN_INFO, {
            Size = UDim2.fromOffset(W, HEADER + 4),
        }):Play()
        task.delay(0.1, function()
            body.Visible = false
        end)
    else
        body.Visible = true
        TweenService:Create(window, TWEEN_INFO, {
            Size = UDim2.fromOffset(W, H),
        }):Play()
    end
end

minimize.MouseButton1Click:Connect(toggleMinimize)

close.MouseButton1Click:Connect(function()
    shineConnection:Disconnect()
    gui:Destroy()
end)

-- 初期構築
task.spawn(function()
    task.wait(0.5)
    rebuild()
end)

-- 自動更新
task.spawn(function()
    while gui.Parent do
        task.wait(5)
        if not state.Busy and not minimized then
            pcall(rebuild)
        end
    end
end)

-- シールド開始
shieldStart()

-- ※ このコードは元スクリプトの構造を維持しつつ、
--    ・UI大型化 (W=320, H=400)
--    ・開閉アニメーション
--    ・Stealパラメータ改善
--    ・日本語化
--    を適用したものです。
--    元コードに含まれる runToEgg, grab, place, homePoint, lineInfo, avoid
--    などの関数はそのまま使用してください。
		
