-- ==========================================================
-- Auto Steal + Instant Steal 単体版
-- Part 1/4 : セットアップ
-- ==========================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local localPlayer = Players.LocalPlayer
local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")

-- デバッグ出力
local fn = function(arg)
    local genv = typeof(getgenv) == "function" and getgenv() or _G
    if type(genv.ChilliDebugPrint) == "function" then
        pcall(genv.ChilliDebugPrint, arg)
    end
end

-- 安全require
local fn2 = function(getter)
    local ok, result = pcall(function() return require(getter()) end)
    return ok and result or nil
end

-- モジュールテーブル
local tbl = {
    EggState = fn2(function() return ReplicatedStorage.Client.EggState end),
    AreaEggs = fn2(function() return ReplicatedStorage.Shared.Types.AreaEggs end),
    ToolGameplayGuard = fn2(function() return ReplicatedStorage.Client.ToolGameplayGuard end),
    Assets = fn2(function() return ReplicatedStorage.Data.Assets end),
    Guards = fn2(function() return ReplicatedStorage.Data.Guards end),
    EggRecords = fn2(function() return ReplicatedStorage.Shared.Util.EggRecords end),
    Mutations = fn2(function() return ReplicatedStorage.Shared.Modules.Mutations end),
    Save = fn2(function() return ReplicatedStorage.Shared.Save end),
    FuseKernel = fn2(function() return ReplicatedStorage.Shared.Util.FuseKernel end),
    AreaEggCycle = fn2(function() return ReplicatedStorage.Shared.Util.AreaEggCycle end),
    AreaEggResetWall = fn2(function() return ReplicatedStorage.Client.AreaEggResetWall end),
    AreaEggResetCycle = fn2(function() return ReplicatedStorage.Data.AreaEggResetCycle end),
    Gears = fn2(function() return ReplicatedStorage.Data.Gears end),
    Areas = fn2(function() return ReplicatedStorage.Data.Areas end),
    LimitedEgg = fn2(function() return ReplicatedStorage.Data.LimitedEgg end),
    BrainrotEgg = fn2(function() return ReplicatedStorage.Data.BrainrotEgg end),
    MonsterEgg = fn2(function() return ReplicatedStorage.Data.MonsterEgg end),
}

-- Saveモジュールの互換パッチ
do
    local save = tbl.Save
    if type(save) == "table" and (type(save.Get) ~= "function" or type(save.FieldSignal) ~= "function") then
        tbl.Save = setmetatable({
            Get = type(save.Get) == "function" and save.Get or save.Peek,
            FieldSignal = type(save.FieldSignal) == "function" and save.FieldSignal or save.Watch,
        }, { __index = save })
    end
end

-- hui取得
local function fn9()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and typeof(result) == "Instance" then return result end
    end
    return CoreGui
end
local v3 = fn9()

-- ランダム文字列
local fn3
do
    local rng = Random.new()
    local str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    fn3 = function()
        local len = rng:NextInteger(12, 20)
        local out = table.create(len)
        for i = 1, len do
            local idx = rng:NextInteger(1, #str)
            out[i] = string.sub(str, idx, idx)
        end
        return table.concat(out)
    end
end

-- クリーンアップ登録
local tbl9Cleanups = {}
local fn4 = function(arg) table.insert(tbl9Cleanups, arg) end

local function runCleanups()
    for i = #tbl9Cleanups, 1, -1 do
        pcall(tbl9Cleanups[i])
    end
    table.clear(tbl9Cleanups)
end

do
    local genv = typeof(getgenv) == "function" and getgenv() or _G
    local oldCleanup = genv.ChilliHubSaeCleanup
    if type(oldCleanup) == "function" then pcall(oldCleanup) end
    genv.ChilliHubSaeCleanup = runCleanups
end

-- ==========================================================
-- tbl3 : スケジューラ（一定間隔でワーカーを回す）
-- ==========================================================
local tbl3
do
    local GAP = 0.35
    local IDLE = 5
    local workers = {}
    local wakeFlag = true

    tbl3 = {
        Add = function(runFn)
            local entry = { Run = runFn, Gap = GAP, Idle = IDLE, Repeat = false, Hold = 0 }
            table.insert(workers, entry)
            return entry
        end,
        Wake = function() wakeFlag = true end,
        Backoff = function(entry, hold)
            if entry then entry.Hold = tonumber(hold) or 6 end
        end,
    }

    local conn = RunService.Heartbeat:Connect(function(dt)
        local woken = wakeFlag
        wakeFlag = false
        for _, w in ipairs(workers) do
            w.Gap = w.Gap + dt
            w.Idle = w.Idle + dt
            if w.Hold > 0 then
                w.Hold = w.Hold - dt
            elseif w.Gap >= GAP and (woken or w.Repeat or w.Idle >= IDLE) then
                w.Gap = 0
                w.Idle = 0
                local ok, result = pcall(w.Run, w)
                w.Repeat = ok and result == true
            end
        end
    end)

    fn4(function() conn:Disconnect() end)
end

-- ==========================================================
-- Anti Guard / Shield / 移動権管理の骨組み（tbl4の土台）
-- ==========================================================
local tbl4 = {
    Steal = { Active = false, LastFinishedAt = 0, Carrying = false, CarryUid = nil, CarryAreaId = nil, Wanted = false },
    Movement = {
        Owner = nil,
        PlaceWanted = false,
        StealFirst = false,
        MutationWanted = false,
        FracturedWanted = false,
    },
    AntiGuard = {
        Enabled = false,
        Busy = false,
        BusySince = 0,
        HitArms = 0,
        HitArmedAt = 0,
        Handle = nil,
        Render = nil,
    },
    Treadmill = { Riding = false },
    Flying = false,
    Driving = 0,
    GodMode = function() end,
    GodTick = function() end,
    StopWalking = function() end,
}

-- Toggle互換
tbl4.Toggle = function(arg, arg2)
    if type(arg) ~= "table" then return arg2 == true end
    local ok, result = pcall(function()
        local controller = arg._controller
        return type(controller) == "table" and type(controller.GetValue) == "function" and controller.GetValue()
    end)
    if ok and type(result) == "boolean" then return result end
    for _, key in ipairs({ "Get", "GetValue" }) do
        local ok2, fnv = pcall(function() return arg[key] end)
        if ok2 and type(fnv) == "function" then
            local ok3, res3 = pcall(fnv, arg)
            if ok3 and type(res3) == "boolean" then return res3 end
        end
    end
    return arg2 == true
end

-- 移動権
tbl4.ClaimMovement = function(owner)
    local m = tbl4.Movement
    if m.Owner == nil or m.Owner == owner
        or (m.Owner == "treadmill" and owner ~= "treadmill")
        or (m.Owner == "scramble" and owner == "steal") then
        m.Owner = owner
        return true
    end
    return false
end

tbl4.ReleaseMovement = function(owner)
    if tbl4.Movement.Owner == owner then
        tbl4.Movement.Owner = nil
    end
end

-- ルート
tbl4.Root = function()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root:IsDescendantOf(workspace) and root or nil
end

tbl4.DistanceTo = function(pos)
    local root = tbl4.Root()
    if not root or not pos then return math.huge end
    return (root.Position - pos).Magnitude
end

-- 接地判定
do
    local groundedStates = {
        [Enum.HumanoidStateType.Running] = true,
        [Enum.HumanoidStateType.RunningNoPhysics] = true,
        [Enum.HumanoidStateType.Landed] = true,
    }
    tbl4.Grounded = function(h)
        if not h then
            local c = localPlayer.Character
            h = c and c:FindFirstChildOfClass("Humanoid")
        end
        if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
        return groundedStates[h:GetState()] == true
    end
end

-- 夜判定
tbl4.IsNight = function()
    local cycle = tbl.AreaEggCycle
    if type(cycle) ~= "table" or type(cycle.IsNightPhase) ~= "function" then return false end
    local ok, result = pcall(cycle.IsNightPhase, workspace:GetServerTimeNow())
    return ok and result == true
end

-- 壁判定
tbl4.WallSealed = function()
    local wall = tbl.AreaEggResetWall
    if type(wall) ~= "table" or type(wall.IsSealed) ~= "function" then return false end
    local ok, result = pcall(wall.IsSealed)
    return ok and result == true
end

tbl4.WallOpenDelay = function()
    local cycle = tbl.AreaEggResetCycle
    if type(cycle) ~= "table" then return 5 end
    return (tonumber(cycle.WallCountdownDelayAfterDayStartsSeconds) or 2)
        + (tonumber(cycle.WallCountdownSeconds) or 3)
end

-- ここまでが Part 1。Part 2 に続く。
print("[Part1/4] ロード完了")-- ==========================================================
-- Part 2/4 : Shield + Belt + 移動 (WalkTo / FlyTo)
-- ==========================================================

-- ==========================================================
-- Shield System (Humanoid Swap)
-- ==========================================================
local shieldMethods = { "Humanoid Swap", "Disable Monitor" }
tbl4.ShieldMethods = shieldMethods

do
    local activeMethod = shieldMethods[1]
    local shieldRequests = {}
    local disabledConns = {}
    local heartbeatConn = nil
    local charConn = nil
    local swapState = { Original = nil, Clone = nil, Links = {} }
    local humanoidWatchers = {}

    local function notifyHumanoidChanged()
        for _, cb in ipairs(humanoidWatchers) do
            task.defer(function() pcall(cb) end)
        end
    end

    tbl4.OnHumanoidChanged = function(cb)
        table.insert(humanoidWatchers, cb)
        local handle = { Connected = true }
        function handle:Disconnect()
            self.Connected = false
            local i = table.find(humanoidWatchers, cb)
            if i then table.remove(humanoidWatchers, i) end
        end
        return handle
    end

    local function rebindControls(humanoid)
        pcall(function()
            local ps = localPlayer:FindFirstChild("PlayerScripts")
            local module = ps and ps:FindFirstChild("PlayerModule")
            if module then
                local controls = require(module):GetControls()
                if type(controls) == "table" then controls.humanoid = humanoid end
            end
        end)
    end

    local function reloadAnim(character)
        local anim = character and character:FindFirstChild("Animate")
        if anim and anim:IsA("LocalScript") then
            task.spawn(function()
                anim.Enabled = false
                task.wait()
                anim.Enabled = true
            end)
        end
    end

    local function unlinkSwap()
        for _, link in ipairs(swapState.Links) do
            pcall(function() link:Disconnect() end)
        end
        table.clear(swapState.Links)
    end

    tbl4.UndoSwap = function()
        unlinkSwap()
        local character = localPlayer.Character
        local original = swapState.Original
        local clone = swapState.Clone
        swapState.Original = nil
        swapState.Clone = nil
        if original and clone and character and original.Parent == nil and clone.Parent == character then
            original.Parent = character
            workspace.CurrentCamera.CameraSubject = original
            rebindControls(original)
            pcall(function() clone:Destroy() end)
            reloadAnim(character)
            notifyHumanoidChanged()
        end
    end

    -- 接地状態
    local groundedStates = {
        [Enum.HumanoidStateType.Running] = true,
        [Enum.HumanoidStateType.RunningNoPhysics] = true,
        [Enum.HumanoidStateType.Landed] = true,
    }
    tbl4.Grounded = function(h)
        if not h then
            local c = localPlayer.Character
            h = c and c:FindFirstChildOfClass("Humanoid")
        end
        if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
        return groundedStates[h:GetState()] == true
    end

    tbl4.ShieldPaused = false

    local function doHumanoidSwap()
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        if swapState.Clone and swapState.Clone.Parent == character then return end
        if not tbl4.Grounded(humanoid) then return end

        local clone = humanoid:Clone()
        humanoid.Parent = nil
        clone.Parent = character
        workspace.CurrentCamera.CameraSubject = clone
        rebindControls(clone)
        reloadAnim(character)
        swapState.Original = humanoid
        swapState.Clone = clone
        notifyHumanoidChanged()

        local anim1 = humanoid:FindFirstChildOfClass("Animator")
        local anim2 = clone:FindFirstChildOfClass("Animator")
        if anim1 and anim2 then
            table.insert(swapState.Links, anim1.AnimationPlayed:Connect(function(played)
                local animation = played.Animation
                if not animation or clone.Parent == nil then return end
                local ok, track = pcall(function() return anim2:LoadAnimation(animation) end)
                if not ok or not track then return end
                pcall(function()
                    track.Priority = played.Priority
                    track.Looped = played.Looped
                    track:Play(0.05, math.max(played.WeightTarget, 0.01), played.Speed)
                end)
                local stoppedConn
                stoppedConn = played.Stopped:Connect(function()
                    stoppedConn:Disconnect()
                    pcall(function() track:Stop(0.1) end)
                end)
            end))
        end

        table.insert(swapState.Links, clone.Died:Connect(function()
            unlinkSwap()
            swapState.Original = nil
            swapState.Clone = nil
            local current = localPlayer.Character
            if current and humanoid.Parent == nil then
                humanoid.Parent = current
                workspace.CurrentCamera.CameraSubject = humanoid
                rebindControls(humanoid)
                notifyHumanoidChanged()
            end
            pcall(function() clone:Destroy() end)
            humanoid.Health = 0
        end))
    end

    -- 代替手段: UGI 系コネクションを止める
    local function doDisableMonitor()
        if type(getconnections) ~= "function" then return end
        for _, signal in ipairs({ RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation }) do
            local ok, conns = pcall(getconnections, signal)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local ok2, fnv = pcall(function() return c.Function end)
                    ok2 = ok2 and type(fnv) == "function"
                    local src = nil
                    if ok2 then
                        local ok3, res3 = pcall(debug.info, fnv, "s")
                        if ok3 then src = res3 end
                    end
                    if src and string.find(tostring(src), "UGI", 1, true) then
                        local ok4, enabled = pcall(function() return c.Enabled end)
                        if not ok4 or enabled ~= false then
                            if pcall(function() c:Disable() end) then
                                table.insert(disabledConns, c)
                            end
                        end
                    end
                end
            end
        end
    end

    local function restoreMonitor()
        if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
        if charConn then charConn:Disconnect(); charConn = nil end
        for _, c in ipairs(disabledConns) do
            pcall(function() c:Enable() end)
        end
        table.clear(disabledConns)
    end

    local function shieldTick()
        if tbl4.ShieldPaused then return end
        if activeMethod == shieldMethods[1] then
            doHumanoidSwap()
        else
            doDisableMonitor()
        end
    end

    local function startShieldLoop()
        shieldTick()
        local n = 0
        heartbeatConn = RunService.Heartbeat:Connect(function(dt)
            n = n + dt
            local character = localPlayer.Character
            local missing = activeMethod == shieldMethods[1]
                and not (swapState.Clone and character and swapState.Clone.Parent == character)
            if (missing and 0.25 or 3) <= n then
                n = 0
                shieldTick()
            end
        end)
        charConn = localPlayer.CharacterAdded:Connect(function(character)
            unlinkSwap()
            swapState.Original = nil
            swapState.Clone = nil
            if activeMethod ~= shieldMethods[1] then return end
            task.spawn(function()
                character:WaitForChild("Humanoid", 10)
                task.wait(1)
                if heartbeatConn and localPlayer.Character == character then
                    shieldTick()
                end
            end)
        end)
    end

    tbl4.Swapped = function()
        if activeMethod ~= shieldMethods[1] then return true end
        local character = localPlayer.Character
        return swapState.Clone ~= nil and character ~= nil and swapState.Clone.Parent == character
    end

    tbl4.Shield = function(key, on)
        shieldRequests[key] = on == true or nil
        if next(shieldRequests) == nil then
            restoreMonitor()
            return
        end
        if heartbeatConn then return end
        startShieldLoop()
    end

    tbl4.SetShieldMethod = function(method)
        if not table.find(shieldMethods, method) or method == activeMethod then return end
        local wasActive = heartbeatConn ~= nil
        restoreMonitor()
        activeMethod = method
        if wasActive and next(shieldRequests) ~= nil then
            startShieldLoop()
        end
    end

    fn4(restoreMonitor)
end

-- ロード時にShieldを有効化
tbl4.Shield("load", true)

-- ==========================================================
-- Belt（トレッドミル）取り扱い
-- ==========================================================
do
    local hiddenParts = {}
    local holdCount = 0

    local function collectBeltParts()
        local plot = tbl4.Plot()
        if not plot then return {} end
        local list = {}
        for _, name in ipairs({ "TreadmillBottom", "TreadmillUpgrade" }) do
            local node = plot:FindFirstChild(name)
            if node then
                if node:IsA("BasePart") then
                    table.insert(list, node)
                else
                    for _, d in ipairs(node:GetDescendants()) do
                        if d:IsA("BasePart") then table.insert(list, d) end
                    end
                end
            end
        end
        local renders = workspace:FindFirstChild("__ClientTreadmillRenders")
        renders = renders and renders:FindFirstChild("TreadmillRender_" .. plot.Name)
        if renders then
            for _, d in ipairs(renders:GetDescendants()) do
                if d:IsA("BasePart") then table.insert(list, d) end
            end
        end
        return list
    end

    local function hideBelt()
        for _, part in ipairs(collectBeltParts()) do
            if not hiddenParts[part] then
                hiddenParts[part] = {
                    CFrame = part.CFrame,
                    CanTouch = part.CanTouch,
                    CanCollide = part.CanCollide,
                    Transparency = part.Transparency,
                }
                pcall(function()
                    part.CanTouch = false
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CFrame = part.CFrame - Vector3.new(0, 120, 0)
                end)
            end
        end
    end

    local function restoreBelt()
        for part, saved in pairs(hiddenParts) do
            if part and part.Parent then
                pcall(function()
                    part.CFrame = saved.CFrame
                    part.CanTouch = saved.CanTouch
                    part.CanCollide = saved.CanCollide
                    part.Transparency = saved.Transparency
                end)
            end
        end
        table.clear(hiddenParts)
    end

    tbl4.HoldBelt = function() holdCount += 1; hideBelt() end
    tbl4.ReleaseBelt = function()
        holdCount = math.max(0, holdCount - 1)
        if holdCount == 0 then restoreBelt() end
    end
    tbl4.BeltHeld = function() return holdCount > 0 end
    tbl4.RefreshBeltHide = function() if holdCount > 0 then hideBelt() end end
    tbl4.ResetBelt = function() holdCount = 0; restoreBelt() end

    fn4(function() holdCount = 0; restoreBelt() end)

    tbl4.LeaveBelt = function()
        local rf = networking:FindFirstChild("RF/Treadmill/AskDoff")
        if rf and rf:IsA("RemoteFunction") then
            pcall(rf.InvokeServer, rf)
        end
    end

    tbl4.OnBelt = function()
        local belt = tbl4.Belt()
        if not belt or hiddenParts[belt] then return false end
        local root = tbl4.Root()
        if not root then return false end
        local local_ = belt.CFrame:PointToObjectSpace(root.Position)
        local hx = belt.Size.X / 2 + 2
        local hz = belt.Size.Z / 2 + 2
        return math.abs(local_.X) <= hx
            and math.abs(local_.Z) <= hz
            and local_.Y >= -2
            and local_.Y <= belt.Size.Y / 2 + 8
    end

    tbl4.ExitBelt = function()
        tbl4.Treadmill.Riding = false
        tbl4.LeaveBelt()
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function()
                humanoid.Jump = true
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
        task.wait(0.35)
    end
end

-- Plot/Belt取得（Auto Stealが依存）
local function fn10_placedPoints()
    local placedRenders = workspace:FindFirstChild("PlacedEggRenders")
    local list = {}
    if not placedRenders then return list end
    local uid = tostring(localPlayer.UserId)
    for _, child in ipairs(placedRenders:GetChildren()) do
        if string.find(child.Name, uid, 1, true) then
            local ok, cf = pcall(function()
                return child:IsA("Model") and child:GetPivot() or child.CFrame
            end)
            if ok then table.insert(list, cf.Position) end
        end
    end
    return list
end

tbl4.PlacedPoints = fn10_placedPoints

tbl4.OwnPlot = function()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, child in ipairs(plots:GetChildren()) do
        local sign = child:FindFirstChild("PlotSign")
        sign = sign and sign:FindFirstChild("PlayerPlotSign")
        sign = sign and sign:FindFirstChild("Frame")
        sign = sign and sign:FindFirstChild("PlayerName")
        if sign and sign:IsA("TextLabel") then
            local txt = string.lower(sign.Text)
            if txt == string.lower(localPlayer.Name) or txt == string.lower(localPlayer.DisplayName) then
                return child
            end
        end
    end
    return nil
end

tbl4.PenAnchor = function()
    local points = tbl4.PlacedPoints()
    if #points > 0 then
        local sum = Vector3.zero
        for _, p in ipairs(points) do sum += p end
        return sum / #points
    end
    local plot = tbl4.OwnPlot()
    if not plot then return nil end
    local toUpdate = plot:FindFirstChild("ToUpdate")
    local pen = toUpdate and toUpdate:FindFirstChild("StarterPen") or plot:FindFirstChild("CenterPoint")
    if not pen then return nil end
    local ok, cf = pcall(function()
        return pen:IsA("Model") and pen:GetPivot() or pen.CFrame
    end)
    return ok and cf.Position or nil
end

tbl4.Plot = function()
    local own = tbl4.OwnPlot()
    if own then return own end
    local plots = workspace:FindFirstChild("Plots")
    local points = tbl4.PlacedPoints()
    if not plots or #points == 0 then return nil end
    local avg = Vector3.zero
    for _, p in ipairs(points) do avg += p end
    avg = avg / #points
    local closest, closestDist = nil, math.huge
    for _, child in ipairs(plots:GetChildren()) do
        local ok, cf, size = pcall(function() return child:GetBoundingBox() end)
        if ok and cf and size then
            local local_ = cf:PointToObjectSpace(avg)
            if math.abs(local_.X) <= size.X / 2 and math.abs(local_.Z) <= size.Z / 2 then
                return child
            end
            local d = (cf.Position - avg).Magnitude
            if d < closestDist then closest, closestDist = child, d end
        end
    end
    if closest and closestDist <= 60 then return closest end
    return nil
end

tbl4.Belt = function()
    local plot = tbl4.Plot()
    if not plot then return nil end
    local bottom = plot:FindFirstChild("TreadmillBottom")
    if bottom and bottom:IsA("BasePart") then return bottom end
    local renders = workspace:FindFirstChild("__ClientTreadmillRenders")
    renders = renders and renders:FindFirstChild("TreadmillRender_" .. plot.Name)
    local part
    if renders then
        part = renders:FindFirstChild("BoundingBoxPart")
            or (renders:IsA("Model") and renders.PrimaryPart)
            or renders:FindFirstChildWhichIsA("BasePart")
    end
    if part then return part end
    local up = plot:FindFirstChild("TreadmillUpgrade")
    return up and up:FindFirstChildWhichIsA("BasePart") or nil
end

-- ==========================================================
-- Flight
-- ==========================================================
tbl4.BeginFlight = function()
    tbl4.Flying = true
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end)
    end
    return tbl4.Root() ~= nil
end

tbl4.EndFlight = function()
    tbl4.Flying = false
    local root = tbl4.Root()
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = false end
end

-- ==========================================================
-- GodMode
-- ==========================================================
do
    local disabledStates = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.Physics,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.PlatformStanding,
    }
    local savedCollide = {}
    local active = false

    tbl4.GodMode = function(on)
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not humanoid then return end

        if on then
            active = true
            for _, state in ipairs(disabledStates) do
                pcall(function() humanoid:SetStateEnabled(state, false) end)
            end
            pcall(function() humanoid.BreakJointsOnDeath = false end)
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") and savedCollide[d] == nil then
                    savedCollide[d] = d.CanCollide
                    pcall(function() d.CanCollide = false end)
                end
            end
        elseif active then
            active = false
            for _, state in ipairs(disabledStates) do
                pcall(function() humanoid:SetStateEnabled(state, true) end)
            end
            for part, can in pairs(savedCollide) do
                if part and part.Parent then
                    pcall(function() part.CanCollide = can end)
                end
            end
            table.clear(savedCollide)
        end
    end

    tbl4.GodTick = function()
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health < humanoid.MaxHealth then
            pcall(function() humanoid.Health = humanoid.MaxHealth end)
        end
    end

    tbl4.StopWalking = function()
        local character = localPlayer.Character
        local root = character a    tbl4.StopWalking = function()
        local character = localPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and root then
            pcall(function()
                humanoid:MoveTo(root.Position)
                humanoid:Move(Vector3.zero, false)
            end)
        end
    end
end

-- ==========================================================
-- WalkTo（地上歩行）
-- ==========================================================
local function walkFn(target, stopDist, timeout, cancelFn)
    local close = tonumber(stopDist) or 6
    local limit = tonumber(timeout) or 10
    local elapsed = 0
    local lastPos = nil
    local stuckTime = 0
    local jumpCooldown = 0

    while elapsed < limit do
        if type(cancelFn) == "function" and cancelFn() then
            tbl4.StopWalking()
            return false
        end
        local character = localPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then
            return false
        end
        if (root.Position - target).Magnitude <= close then
            tbl4.StopWalking()
            return true
        end

        stuckTime = (lastPos and (root.Position - lastPos).Magnitude < 1) and stuckTime + 0.2 or 0
        lastPos = root.Position
        jumpCooldown = math.max(0, jumpCooldown - 0.2)

        if stuckTime >= 0.8 and jumpCooldown <= 0 then
            tbl4.LeaveBelt()
            pcall(function() humanoid.Jump = true end)
            stuckTime = 0
            jumpCooldown = 1.5
        end

        humanoid:MoveTo(target)
        elapsed += task.wait(0.2)
    end

    tbl4.StopWalking()
    return tbl4.DistanceTo(target) <= close
end

tbl4.WalkTo = function(target, stopDist, timeout, cancelFn)
    tbl4.Driving += 1
    local ok, result = pcall(walkFn, target, stopDist, timeout, cancelFn)
    tbl4.Driving = math.max(0, tbl4.Driving - 1)
    return ok and result == true
end

-- ==========================================================
-- ★ 速度設定（ここだけが変更点）
-- ==========================================================
local n  = 2500   -- ★ 行く時の速度（元: 400）
local n2 = 2500   -- ★ 行く時の速度（元: 400）
local n10 = 6
local n11 = 0.6
local n12 = 20
local n13 = 90
local n14 = 6

-- ==========================================================
-- FlyTo
-- ==========================================================
local function flyStep(root, target, speed, dt, state)
    local delta = target - root.Position
    local dist = delta.Magnitude
    local clampedDt = math.max(dt, 0.0041666666666666666)
    local vel = Vector3.zero
    if dist > 0.01 then
        vel = delta.Unit * math.min(speed, dist / clampedDt)
    end
    local assembly = vel + Vector3.new(0, workspace.Gravity * clampedDt * 0.5, 0)

    if dist > 2 then
        if not state.mark then
            state.mark = dist
            state.clock = 0
        end
        state.clock = state.clock + dt
        if state.clock >= 0.4 then
            if state.mark - dist < speed * 0.1 then
                pcall(function()
                    root.CFrame = root.CFrame + delta.Unit * math.min(dist, speed * clampedDt)
                end)
            end
            state.mark = dist
            state.clock = 0
        end
    else
        state.mark = nil
    end

    pcall(function()
        root.AssemblyLinearVelocity = assembly
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    return dist <= 0.5
end

local flightState = {}
local flightConn, flightPreConn

local function stopFlight()
    if flightConn then flightConn:Disconnect(); flightConn = nil end
    if flightPreConn then flightPreConn:Disconnect(); flightPreConn = nil end
end

fn4(stopFlight)

local function flyTo(target, cancelFn, speedOverride)
    local root = tbl4.Root()
    if not root then return false end
    local speed = speedOverride or n2
    local character = localPlayer.Character
    if not character then return false end

    local finished = false
    local failed = false
    local elapsed = 0
    local lastPos = root.Position
    local state = {}

    flightConn = RunService.Heartbeat:Connect(function(dt)
        if finished or failed then return end
        local r = tbl4.Root()
        if not r or localPlayer.Character ~= character then
            failed = true
            return
        end
        if type(cancelFn) == "function" and cancelFn() then
            failed = true
            return
        end
        elapsed = elapsed + dt
        if elapsed >= 25 then failed = true; return end
        if (r.Position - lastPos).Magnitude > n10 * 2
            and (r.Position - target).Magnitude > (lastPos - target).Magnitude + 5 then
            lastPos = r.Position
        end
        if flyStep(r, target, speed, dt, state) then
            finished = true
        end
    end)

    while not finished and not failed do
        RunService.Heartbeat:Wait()
    end

    if flightConn then flightConn:Disconnect(); flightConn = nil end
    if root and root.Parent then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    return finished
end

tbl4.FlyTo = flyTo
tbl4.AntiGuard.Busy = false

print("[Part2/4] 完了 — 速度: n=2500, n2=2500")
        -- ==========================================================
-- Part 3/4 : 卵検索 + 取得 + 配達 + メインループ
-- ==========================================================

-- ==========================================================
-- 内部定数（元コード準拠、速度以外は変更なし）
-- ==========================================================
local tbl11 = { "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" }
local v15 = tbl11[4]  -- Steal Priority（既定: Highest Value）
local n3 = 0          -- Min Rarity
local n4 = 0          -- Min Value
local flag = false    -- Index mode on
local tbl17 = {}      -- 卵ごとのIndex
local uid = nil       -- 現在のターゲットUID
local tbl18 = {}      -- クールダウン
local tbl12 = {}      -- Target Areas
local tbl13 = {}      -- Target Specific Eggs
local tbl14 = {}      -- 優先キュー
local tbl15 = {}      -- 優先キュー（1回だけ）
local tbl16 = {}      -- キャンセル済み
local flag2 = false   -- 実行中フラグ
local n6 = 0          -- 実行世代
local n7 = 20         -- クールダウン秒
local str = "None"    -- ターゲット表示
local str2 = "Idle"   -- ステータス

-- ミューテーションラベル
local mutationLabels = {
    Boss = "Fractured",
    GreatBloom = "Spirit Bloom",
    Sakura = "Bloom",
    Monstrous = "Parasite",
}
do
    local mutations = tbl.Mutations
    local ok, result = pcall(function() return mutations.All() end)
    if ok and type(result) == "table" then
        for k, v in pairs(result) do
            local id, label
            if type(v) == "table" then
                id = v.Id or k
                label = v.Label
            end
            if id ~= nil and type(label) == "string" and label ~= "" then
                mutationLabels[tostring(id)] = label
            end
        end
    end
end
local fn7 = function(id) return mutationLabels[tostring(id)] or tostring(id) end

-- ==========================================================
-- 変位ユーティリティ（元コード同様）
-- ==========================================================
local function fn10_avgPlaced()
    local points = tbl4.PlacedPoints()
    if #points == 0 then return nil end
    local sum = Vector3.zero
    for _, p in ipairs(points) do sum += p end
    return sum / #points
end

local function fn13_check(gen)
    return gen ~= n6 or not tbl4.Toggle(nil, false)
end

-- ==========================================================
-- fn19 : フィールドの卵をスキャンしてターゲット候補を返す
-- ==========================================================
local function scanFieldEggs(includeCarried, excludeCarried)
    local records = nil
    local eggState = tbl.EggState
    if type(eggState) == "table" and type(eggState.ReadFieldEggs) == "function" then
        task.spawn(function()
            local ok, result = pcall(eggState.ReadFieldEggs)
            if ok and type(result) == "table" and type(result.Records) == "table" and next(result.Records) ~= nil then
                records = result.Records
            end
        end)
    end

    if not records then
        local rf = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
        if not rf or not rf:IsA("RemoteFunction") then return {} end
        local ok, result = pcall(rf.InvokeServer, rf)
        records = ok and type(result) == "table" and result.Records or nil
    end

    if type(records) ~= "table" then return {} end

    local list = {}
    local liveUids = {}

    for _, record in pairs(records) do
        local uid2 = type(record) == "table" and record.Uid or nil
        if uid2 and record.State ~= "Claimed" then
            liveUids[uid2] = true
        end

        local carried = record.State == "Carried" and excludeCarried == true and includeCarried ~= true
            and not (tbl4.Steal.Carrying and uid2 == tbl4.Steal.CarryUid)
        local validState = uid2 and (record.State == "Slot" or record.State == "Dropped" or carried)
        local cd = uid2 and tbl14[uid2] or nil
        local once = uid2 and tbl15[uid2] == true or false
        local indexWanted = includeCarried ~= true and flag and uid2 and tbl17[tostring(record.AssetCategory)] or nil
        local riftWanted = includeCarried ~= true and tbl4.Steal.RiftPriority == true
            and uid2 ~= nil and tbl4.Steal.RiftNeeds[tostring(record.AssetCategory)] == true
        local areaOK = includeCarried == true or cd ~= nil or once or riftWanted
            or indexWanted ~= nil or tbl12[tostring(record.AreaId)] == true
        local cancelled = includeCarried ~= true and cd == nil and tbl16[uid2] == true
        local nightHold = tbl19Active ~= nil and tbl19Active[uid2] == true
        validState = validState and typeof(record.BottomCFrame) == "CFrame"

        if validState then
            validState = (tbl18[uid2] or 0) <= os.clock()
        end

        if validState and areaOK and not cancelled and not nightHold then
            local rarity = getRarity(record.AssetCategory)
            local catKey = tostring(record.AssetCategory)
            local rarityOK = rarity.RarityNumber >= n3
            local specificOK = next(tbl13) == nil or tbl13[catKey] == true
            local scale = tonumber(record.AssetScale) or 1
            local mult = mutationMult(record.Mutations)
            local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
            local valueOK = n4 <= 0 or rarity.EarningRate * factor * mult >= n4
            local pass = rarityOK and specificOK and valueOK
            local riftOnly = riftWanted and not pass and not once and cd == nil and indexWanted == nil

            if includeCarried == true or cd or once or riftWanted or indexWanted ~= nil or pass then
                table.insert(list, {
                    Uid = uid2,
                    Category = catKey,
                    Scale = scale,
                    State = record.State,
                    Rarity = rarity.RarityNumber,
                    Weight = getWeight(record.AssetCategory, scale),
                    Mutation = mult,
                    Value = rarity.EarningRate * factor * mult,
                    CFrame = record.BottomCFrame,
                    AreaId = tostring(record.AreaId),
                    Rift = includeCarried ~= true and riftWanted,
                    RiftOnly = includeCarried ~= true and riftOnly,
                    Index = indexWanted,
                    Forced = includeCarried ~= true and cd and cd.At or nil,
                    Priority = includeCarried ~= true and once,
                })
            end
        end
    end

    -- 消えた卵のキャッシュ削除
    if next(liveUids) ~= nil then
        for k in pairs(tbl14) do
            if not liveUids[k] then tbl14[k] = nil end
        end
        for k in pairs(tbl15) do
            if not liveUids[k] then tbl15[k] = nil end
        end
        for k in pairs(tbl16) do
            if not liveUids[k] then tbl16[k] = nil end
        end
    end

    -- ソート
    table.sort(list, function(a, b)
        if (a.Forced ~= nil) ~= (b.Forced ~= nil) then return a.Forced ~= nil end
        if a.Forced and b.Forced and a.Forced ~= b.Forced then return a.Forced < b.Forced end
        if a.Priority ~= b.Priority then return a.Priority == true end
        if a.RiftOnly ~= b.RiftOnly then return b.RiftOnly == true end
        if (a.Index ~= nil) ~= (b.Index ~= nil) then return a.Index ~= nil end
        if a.Index and b.Index and a.Index ~= b.Index then return a.Index > b.Index end
        if v15 == tbl11[2] and a.Weight ~= b.Weight then return a.Weight > b.Weight end
        if v15 == tbl11[3] and a.Mutation ~= b.Mutation then return a.Mutation > b.Mutation end
        if v15 == tbl11[4] and a.Value ~= b.Value then return a.Value > b.Value end
        if v15 == tbl11[5] and a.Value ~= b.Value then return a.Value < b.Value end
        if a.Rarity ~= b.Rarity then return a.Rarity > b.Rarity end
        if a.Value ~= b.Value then return a.Value > b.Value end
        return tostring(a.Uid) < tostring(b.Uid)
    end)

    return list
end
local fn19 = scanFieldEggs

-- ==========================================================
-- Rarity / Weight / Mutation ヘルパー
-- ==========================================================
function getRarity(category)
    local dir = tbl.Assets and tbl.Assets.Directory
    local entry = type(dir) == "table" and dir[tostring(category)] or nil
    local rarity = type(entry) == "table" and type(entry.Rarity) == "table" and entry.Rarity or nil
    local num = rarity and tonumber(rarity.RarityNumber or rarity.Rank) or 0
    return {
        RarityNumber = num,
        EarningRate = type(entry) == "table" and tonumber(entry.EarningRate) or 0,
    }
end

function getWeight(category, scale)
    local eggRecords = tbl.EggRecords
    if type(eggRecords) == "table" and type(eggRecords.WeightKgForScale) == "function" then
        local ok, result = pcall(eggRecords.WeightKgForScale, category, scale)
        if ok and type(result) == "number" then return result end
    end
    return 0
end

function mutationMult(mutations)
    local m = tbl.Mutations
    if type(m) == "table" and type(m.EarningsFor) == "function" then
        local ok, result = pcall(m.EarningsFor, type(mutations) == "table" and mutations or {})
        if ok and type(result) == "number" then return result end
    end
    return 1
end

-- ==========================================================
-- フィールドの卵を掴む
-- ==========================================================
local function carryFieldEgg(uid2)
    local eggState = tbl.EggState
    if type(uid2) == "string" and type(eggState) == "table" and type(eggState.CarryFieldEgg) == "function" then
        pcall(eggState.CarryFieldEgg, uid2)
    end
end

local function dropFieldEgg()
    local eggState = tbl.EggState
    if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
        pcall(eggState.DropFieldEgg, "PlayerRequest")
    end
end

-- 近くのSmartPromptPartからプロンプト取得
local function findPromptNear(position, uidFilter, radius)
    local best, bestDist, bestPart = nil, radius or 14, nil
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
            local prompt = child:FindFirstChild("CarryAreaEgg")
            if prompt and prompt:IsA("ProximityPrompt") then
                local d = (child.Position - position).Magnitude
                if d < bestDist then
                    -- uidFilter があればその卵かどうかをチェック（fn26相当の簡易版）
                    local ok = true
                    if type(uidFilter) == "string" then
                        ok = true  -- 簡易: 位置優先
                    end
                    if ok then
                        best, bestDist, bestPart = prompt, d, child
                    end
                end
            end
        end
    end
    return best, bestPart
end

-- 卵をつかむ（プロンプト経由、時間制限つき）
local function grabAt(egg, cancelGen, timeout)
    local position = typeof(egg.CFrame) == "CFrame" and egg.CFrame.Position or nil
    if not position then return false end
    local elapsed = 0
    local sinceFire = 1

    while elapsed < (timeout or 1.5) do
        if fn13_check(cancelGen) then return false end
        if tbl4.Steal.Carrying then return true end

        if sinceFire >= 0.06 then
            local prompt = findPromptNear(egg.Uid and position or position, egg.Uid, 14)
            if prompt then
                pcall(function() prompt.HoldDuration = 0 end)
                if typeof(fireproximityprompt) == "function" then
                    pcall(fireproximityprompt, prompt)
                end
            else
                -- プロンプトが見つからない: 直接リクエスト
                if type(tbl.EggState) == "table" and type(tbl.EggState.CarryFieldEgg) == "function" then
                    pcall(tbl.EggState.CarryFieldEgg, egg.Uid)
                end
            end
            sinceFire = 0
        end

        local dt = RunService.Heartbeat:Wait()
        elapsed += dt
        sinceFire += dt
    end
    return tbl4.Steal.Carrying == true
end

-- その場ジャンプして卵を取る（fn45）
local function jumpAndTake(egg, cancelGen, cancelFn)
    local position = typeof(egg.CFrame) == "CFrame" and egg.CFrame.Position or nil
    if not position then return false end

    local target = position + Vector3.new(0, 3, 0)
    local root = tbl4.Root()
    if root and (target - root.Position).Magnitude > n13 then
        if not flyTo(target, cancelFn or function() return fn13_check(cancelGen) end, n2) then
            return false
        end
    elseif root then
        pcall(function()
            local rotation = root.CFrame.Rotation
            root.CFrame = CFrame.new(target) * rotation
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if fn13_check(cancelGen) then return false end
    return grabAt(egg, cancelGen, 1.5)
end

-- ==========================================================
-- 一番近い卵を選ぶ
-- ==========================================================
local function closestEgg(list)
    local root = tbl4.Root()
    if not root then return nil end
    local closest, minDist = nil, math.huge
    for _, egg in ipairs(list) do
        local pos = typeof(egg.CFrame) == "CFrame" and egg.CFrame.Position
        if pos then
            local d = (root.Position - pos).Magnitude
            if d < minDist then closest, minDist = egg, d end
        end
    end
    return closest
end

-- ==========================================================
-- 卵を追いかけて取る（別プレイヤーが運んでる場合）
-- ==========================================================
local function followEgg(uid2, cancelGen)
    local elapsed = 0
    local limit = 30
    local lastCarryUid = nil

    while elapsed < limit do
        if fn13_check(cancelGen) then return false end
        if tbl4.Steal.Carrying then return true end

        local root = tbl4.Root()
        if not root then return false end

        -- 現在位置を取得
        local pos = nil
        local node = workspace:FindFirstChild(uid2)
        if node then
            local ok, p = pcall(function() return node:GetPivot().Position end)
            if ok then pos = p end
        end

        if not pos then
            -- snapshot から探す
            local rf = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
            if rf and rf:IsA("RemoteFunction") then
                local ok, result = pcall(rf.InvokeServer, rf)
                local records = ok and type(result) == "table" and result.Records or nil
                if type(records) == "table" then
                    for _, r in pairs(records) do
                        if type(r) == "table" and r.Uid == uid2 and typeof(r.BottomCFrame) == "CFrame" then
                            pos = r.BottomCFrame.Position
                            break
                        end
                    end
                end
            end
        end

        if pos then
            local target = pos + Vector3.new(0, 3, 0)
            if (root.Position - target).Magnitude > 6 then
                flyTo(target, function() return fn13_check(cancelGen) end, n2)
            else
                -- 近くのプロンプトを叩く
                local prompt = findPromptNear(pos - Vector3.new(0, 3, 0), uid2, 8)
                if prompt then
                    pcall(function() prompt.HoldDuration = 0 end)
                    if typeof(fireproximityprompt) == "function" then
                        pcall(fireproximityprompt, prompt)
                    end
                end
            end
        end

        elapsed += RunService.Heartbeat:Wait()
    end

    return tbl4.Steal.Carrying == true
end

-- ==========================================================
-- 家に帰る（配達）
-- ==========================================================
local function deliverHome(cancelGen)
    local stealHome = tbl4.StealHome and tbl4.StealHome() or Vector3.new(528.7, 70.57, -364.11)
    if not stealHome then return false end

    local elapsed = 0
    local limit = 30
    local root = tbl4.Root()
    if not root then return false end

    -- まずセーフゾーンへ
    local highY = math.max(root.Position.Y, stealHome.Y) + 27.4
    local stage = "rise"
    local last = os.clock()

    while elapsed < limit do
        if fn13_check(cancelGen) then return false end

        root = tbl4.Root()
        if not root then return false end

        local target
        if stage == "rise" then
            target = Vector3.new(root.Position.X, highY, root.Position.Z)
            if math.abs(root.Position.Y - highY) < 4 then
                stage = "toBase"
            end
        elseif stage == "toBase" then
            target = Vector3.new(stealHome.X, highY, stealHome.Z)
            local flat = Vector3.new(root.Position.X - stealHome.X, 0, root.Position.Z - stealHome.Z)
            if flat.Magnitude < 6 then
                stage = "descend"
            end
        else
            target = stealHome
        end

        flyTo(target, function() return fn13_check(cancelGen) end, n2)

        if (root.Position - stealHome).Magnitude <= 4 and stage == "descend" then
            break
        end

        if not tbl4.Steal.Carrying then
            return false
        end

        elapsed += os.clock() - last
        last = os.clock()
    end

    -- 降りてドロップ
    if tbl4.Steal.Carrying then
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.PlatformStand = false end
        task.wait(0.2)
        if tbl4.Steal.Carrying then
            dropFieldEgg()
            local waited = 0
            while tbl4.Steal.Carrying and waited < 1 do
                waited += RunService.Heartbeat:Wait()
            end
        end
    end
    return true
end

-- ==========================================================
-- メインスティールルーチン（fn57）
-- ==========================================================
local function stealRoutine()
    local gen = n6
    tbl4.Steal.Active = true
    tbl4.Steal.Carrying = tbl4.Steal.Carrying == true

    if not tbl4.Steal.Carrying then
        tbl4.Steal.CarryUid = nil
    end

    -- ターゲットリスト取得
    local list = fn19(false, true)
    local best, waiting = nil, nil
    for _, egg in ipairs(list) do
        if egg.State == "Carried" then
            waiting = waiting or egg
        else
            best = egg
            break
        end
    end

    uid = best and best.Uid or nil
    str = "None"
    if best then
        str = string.format("%s  %.2fx  value %.2f", best.Category, best.Scale, best.Value)
    end

    if not best then
        tbl4.Steal.Active = false
        str2 = waiting and "Best egg carried, waiting" or "No egg matches"
        return false
    end

    if not tbl4.ClaimMovement("steal") then
        tbl4.Steal.Active = false
        str2 = "Waiting for Auto Place"
        return false
    end

    if tbl4.Treadmill.Riding or tbl4.OnBelt() then
        tbl4.ExitBelt()
    end

    tbl4.HoldBelt()
    tbl4.Steal.LastFinishedAt = os.clock()

    local success = false

    -- 近くに卵があれば即取り
    local root = tbl4.Root()
    local pos = typeof(best.CFrame) == "CFrame" and best.CFrame.Position
    if root and pos then
        if (pos - root.Position).Magnitude <= n13 then
            str2 = "Target is right here"
            success = jumpAndTake(best, gen)
            if success then
                deliverHome(gen)
            end
        end
    end

    if not success then
        str2 = "Going to the egg"
        local result = jumpAndTake(best, gen)
        if result then
            str2 = "Delivering"
            deliverHome(gen)
            success = true
        end
    end

    tbl4.ReleaseBelt()
    tbl4.Steal.Active = false
    tbl4.Steal.LastFinishedAt = os.clock()
    str2 = success and "Delivered" or "Run ended"
    return true
end

-- ==========================================================
-- Instant Steal（テレポートで卵の位置へ飛ぶ）
-- ==========================================================
local function instantSteal(uid2, cancelGen)
    local list = fn19(false, true)
    loca-- ==========================================================
-- Instant Steal（テレポートで卵の位置へ飛ぶ）
-- ==========================================================
local function instantSteal(uid2, cancelGen)
    local list = fn19(false, true)
    local egg = nil
    for _, e in ipairs(list) do
        if e.Uid == uid2 then egg = e; break end
    end
    if not egg then return false end

    local pos = typeof(egg.CFrame) == "CFrame" and egg.CFrame.Position
    if not pos then return false end

    str2 = "Instant TP: teleporting to egg"
    local root = tbl4.Root()
    if root then
        pcall(function()
            root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    task.wait(0.05)
    return grabAt(egg, cancelGen, 1.5)
end

-- ==========================================================
-- Auto Steal ワーカー登録（tbl3）
-- ==========================================================
tbl3.Add(function()
    if not tbl4.Toggle(nil, false) then
        return false
    end
    if flag2 then return true end
    if os.clock() < n7 and tbl4.Steal.LastFinishedAt > 0 then return false end
    if tbl4.Movement.PlaceWanted and not tbl4.Movement.StealFirst then return false end
    if tbl4.Movement.Owner and tbl4.Movement.Owner ~= "steal"
        and tbl4.Movement.Owner ~= "treadmill"
        and tbl4.Movement.Owner ~= "scramble" then
        return false
    end

    tbl4.Movement.StealFirst = false
    flag2 = true

    task.spawn(function()
        local ok = pcall(stealRoutine)
        if not ok then
            tbl4.Steal.Active = false
        end
        tbl4.ReleaseMovement("steal")
        flag2 = false
        n6 += 1
        tbl3.Wake()
    end)

    return true
end)

-- ==========================================================
-- 外部API
-- ==========================================================
tbl4.CancelSteal = function(uid2)
    if type(uid2) ~= "string" then return end
    tbl14[uid2] = nil
    tbl15[uid2] = nil
    tbl16[uid2] = true
    n6 += 1
    tbl4.Steal.Active = false
    tbl3.Wake()
end

tbl4.PrioritizeSteal = function(uid2)
    if type(uid2) ~= "string" then return end
    local minAt = 0
    for _, v in pairs(tbl14) do
        if v.At < minAt then minAt = v.At end
    end
    tbl14[uid2] = { At = minAt - 1, Once = false }
    tbl16[uid2] = nil
    tbl18[uid2] = nil
    n6 += 1
    tbl3.Wake()
end

tbl4.StealNow = function(uid2, once)
    if type(uid2) ~= "string" then return end
    if not tbl14[uid2] then
        local maxAt = 0
        for _, v in pairs(tbl14) do
            if v.At > maxAt then maxAt = v.At end
        end
        tbl14[uid2] = { At = maxAt + 1, Once = once == true }
    end
    tbl16[uid2] = nil
    tbl18[uid2] = nil
    n6 += 1
    tbl3.Wake()
end

tbl4.StealPlan = function()
    if tbl4.IsNight() then return {}, nil end
    local list = {}
    if uid then table.insert(list, uid) end
    local ok, result = pcall(fn19, false, true)
    if ok and type(result) == "table" then
        for _, e in ipairs(result) do
            if e.Uid ~= uid then
                table.insert(list, e.Uid)
            end
        end
    end
    return list, uid
end

tbl4.MoveInPlan = function(uid2, dir)
    if type(uid2) ~= "string" or (dir ~= -1 and dir ~= 1) then return end
    local plan = tbl4.StealPlan()
    local idx = table.find(plan, uid2)
    if not idx then return end
    local newIdx = idx + dir
    if newIdx < 1 or newIdx > #plan then return end
    table.remove(plan, idx)
    table.insert(plan, newIdx, uid2)
    for i, u in ipairs(plan) do
        local entry = tbl14[u]
        if entry then
            entry.At = i
        else
            tbl14[u] = { At = i, Once = false }
        end
        tbl16[u] = nil
    end
    n6 += 1
    tbl3.Wake()
end

tbl4.StealQueue = function()
    local list = {}
    for k in pairs(tbl14) do
        table.insert(list, k)
    end
    table.sort(list, function(a, b)
        local at1, at2 = tbl14[a].At, tbl14[b].At
        if at1 ~= at2 then return at1 < at2 end
        return a < b
    end)
    return list
end

-- フィールドのキャッシュ関連
local tbl19Active = nil

-- RiftNeeds プレースホルダ
tbl4.Steal.RiftPriority = false
tbl4.Steal.RiftNeeds = {}

-- StealHome 定義
do
    local defs = {
        { Path = { "GearGiver_Slap", "Podium" }, Offset = Vector3.new(-16.415, 21.072, -6.106) },
        { Path = { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Offset = Vector3.new(-26.776, 1.75, 18.665) },
        { Path = { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Offset = Vector3.new(-26.776, 1.75, 18.665) },
    }
    tbl4.StealHome = function()
        for _, def in ipairs(defs) do
            local node = workspace
            for _, name in ipairs(def.Path) do
                node = node and node:FindFirstChild(name) or nil
            end
            if node and node:IsA("BasePart") then
                return node.CFrame:PointToWorldSpace(def.Offset)
            end
        end
        return Vector3.new(528.7, 70.57, -364.11)
    end
end

-- Auto Steal オン・オフ制御用ハンドル
local autoStealOn = false
function tbl4.SetAutoSteal(on)
    autoStealOn = on == true
end
-- tbl4.Toggle(nil, false) は autoStealOn を返すよう上書き
local oldToggle = tbl4.Toggle
tbl4.Toggle = function(arg, arg2)
    if arg == nil then return autoStealOn end
    return oldToggle(arg, arg2)
end

-- Instant Steal 実行公開API
tbl4.RunInstantSteal = function(uid2)
    if type(uid2) ~= "string" then return false end
    local gen = n6
    n6 += 1
    return instantSteal(uid2, gen)
end

print("[Part3/4] 完了 — Auto Steal / Instant Steal ロジック準備完了")-- ==========================================================
-- Part 4/4 : UI + オートエグゼキューター + 起動
-- ==========================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer

-- ==========================================================
-- 月の色（Moon Theme）
-- ==========================================================
local MOON_BG      = Color3.fromRGB(13, 17, 30)     -- 深宇宙
local MOON_CARD    = Color3.fromRGB(22, 27, 45)     -- カード
local MOON_STROKE  = Color3.fromRGB(180, 190, 210)  -- 月明かりシルバー
local MOON_TEXT    = Color3.fromRGB(230, 235, 245)
local MOON_ACCENT  = Color3.fromRGB(200, 210, 230)
local MOON_GLOW    = Color3.fromRGB(255, 250, 230)  -- 月の光

-- ==========================================================
-- UI ヘルパー
-- ==========================================================
local living = {}

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
        Color = MOON_STROKE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    s.Parent = parent
    local g = make("UIGradient", {
        Rotation = 45,
        Color = bands(bright and MOON_GLOW or MOON_STROKE, MOON_BG),
    })
    g.Parent = s
    table.insert(living, g)
    return s, g
end

local function livingText(label)
    local g = make("UIGradient", { Color = bands(MOON_TEXT, MOON_STROKE) })
    g.Parent = label
    table.insert(living, g)
    return g
end

local function text(parent, props)
    local alive = props.Living ~= false
    props.Living = nil
    props.BackgroundTransparency = 1
    props.TextColor3 = props.TextColor3 or MOON_TEXT
    local l = make("TextLabel", props)
    l.Parent = parent
    if alive then livingText(l) end
    return l
end

-- ==========================================================
-- UI 本体（月の色 + 卵リスト）
-- ==========================================================
local gui = make("ScreenGui", {
    Name = "MoonStealHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
})
gui.Parent = parentGui()

local W, H = 240, 340
local window = make("Frame", {
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = MOON_BG,
    BorderSizePixel = 0,
})
window.Parent = gui
corner(window, 14)
livingStroke(window, 1.2, true)

-- ヘッダー
local header = make("Frame", {
    Size = UDim2.new(1, -10, 0, 26),
    Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = MOON_STROKE,
    BorderSizePixel = 0,
})
header.Parent = window
corner(header, 9)
livingStroke(header, 0.8, false)

-- 月アイコン（簡易: 円形フレームを月に見立てる）
local moonIcon = make("Frame", {
    Size = UDim2.fromOffset(18, 18),
    Position = UDim2.fromOffset(5, 4),
    BackgroundColor3 = MOON_GLOW,
    BorderSizePixel = 0,
})
moonIcon.Parent = header
corner(moonIcon, 9)
make("Frame", {
    Size = UDim2.fromOffset(16, 16),
    Position = UDim2.fromOffset(5, 0),
    BackgroundColor3 = MOON_STROKE,
    BorderSizePixel = 0,
}).Parent = moonIcon
-- 月の三日月効果
local moonCut = make("Frame", {
    Size = UDim2.fromOffset(14, 14),
    Position = UDim2.fromOffset(7, 0),
    BackgroundColor3 = MOON_STROKE,
    BorderSizePixel = 0,
})
moonCut.Parent = moonIcon
corner(moonCut, 8)

text(header, {
    Size = UDim2.new(1, -30, 1, 0),
    Position = UDim2.fromOffset(28, 0),
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(0, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Moon Steal Hub",
    Living = false,
})

-- 卵リスト（スクロール）
local list = make("ScrollingFrame", {
    Size = UDim2.new(1, -10, 1, -130),
    Position = UDim2.fromOffset(5, 36),
    BackgroundColor3 = MOON_BG,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = MOON_STROKE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = window
corner(list, 9)
livingStroke(list, 0.8, false)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = list
make("UIPadding", {
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5),
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 5),
}).Parent = list

-- ステータスバー
local statusLabel = text(window, {
    Size = UDim2.new(1, -10, 0, 14),
    Position = UDim2.new(0, 5, 1, -58),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "Idle",
})

-- ボタン
local function bigButton(label, position, size)
    local b = make("TextButton", {
        Size = size,
        Position = position,
        BackgroundColor3 = MOON_CARD,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextColor3 = MOON_TEXT,
        Text = label,
        AutoButtonColor = true,
    })
    b.Parent = window
    corner(b, 8)
    livingStroke(b, 1, true)
    livingText(b)
    return b
end

local refreshButton = bigButton("Refresh", UDim2.new(0, 5, 1, -40), UDim2.new(0.42, -7, 0, 34))
local instantButton = bigButton("Instant Steal", UDim2.new(0.42, 2, 1, -40), UDim2.new(0.58, -7, 0, 34))

-- 速度スライダー表示（Auto Stealの行き速度）
local speedLabel = text(window, {
    Size = UDim2.new(0.5, 0, 0, 14),
    Position = UDim2.new(0, 5, 1, -20),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Tween Speed: 2500",
})
local toggleAuto = make("TextButton", {
    Size = UDim2.new(0.5, -5, 0, 18),
    Position = UDim2.new(0.5, 0, 1, -22),
    BackgroundColor3 = MOON_CARD,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = MOON_TEXT,
    Text = "Auto Steal: OFF",
    AutoButtonColor = true,
})
toggleAuto.Parent = window
corner(toggleAuto, 6)
livingStroke(toggleAuto, 0.8, false)
livingText(toggleAuto)

-- ==========================================================
-- 卵リスト構築（2つ目のファイルの describe / snapshot 相当）
-- ==========================================================
local rows = {}
local selectedUid = nil

local function describe(record)
    local Assets = tbl.Assets
    local directory = type(Assets) == "table" and Assets.Directory or nil
    local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
    local info = { Uid = record.Uid, Name = tostring(record.AssetCategory), Icon = "", Value = 0 }
    if type(entry) == "table" then
        info.Name = tostring(entry.DisplayName or record.AssetCategory)
        local icon = entry.Icon
        if icon ~= nil and tostring(icon) ~= "" then
            info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or tostring(icon)
        end
        local scale = tonumber(record.AssetScale) or 1
        local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
        info.Value = (tonumber(entry.EarningRate) or 0) * factor * mutationMult(record.Mutations)
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

local function setSelected(uid)
    selectedUid = uid
    for rowUid, row in pairs(rows) do
        local on = rowUid == uid
        row.Stroke.Thickness = on and 1.5 or 0.8
        row.Gradient.Color = on and bands(MOON_GLOW, MOON_BG) or bands(MOON_STROKE, MOON_BG)
    end
end

local function rebuild()
    for _, row in pairs(rows) do row.Frame:Destroy() end
    table.clear(rows)
    for i = #living, 1, -1 do
        if not living[i].Parent then table.remove(living, i) end
    end

    local infos = {}
    for _, record in ipairs(fn19(false, false) or {}) do
        table.insert(infos, describe(record))
    end
    table.sort(infos, function(a, b) return a.Value > b.Value end)

    local still = false
    for index, info in ipairs(infos) do
        if info.Uid == selectedUid then still = true end

        local frame = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = MOON_CARD,
            LayoutOrder = index,
            Text = "",
            AutoButtonColor = true,
        })
        frame.Parent = list
        corner(frame, 8)
        local rowStroke, rowGradient = livingStroke(frame, 0.8, false)

        make("ImageLabel", {
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.fromOffset(5, 5),
            BackgroundTransparency = 1,
            Image = info.Icon,
            ScaleType = Enum.ScaleType.Fit,
        }).Parent = frame

        text(frame, {
            Size = UDim2.new(1, -45, 0, 15),
            Position = UDim2.fromOffset(40, 4),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = info.Name,
        })
        text(frame, {
            Size = UDim2.new(1, -45, 0, 13),
            Position = UDim2.fromOffset(40, 22),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = money(info.Value),
            TextColor3 = MOON_ACCENT,
        })

        rows[info.Uid] = { Frame = frame, Stroke = rowStroke, Gradient = rowGradient }

        frame.MouseButton1Click:Connect(function()
            setSelected(info.Uid)
            statusLabel.Text = "Selected: " .. info.Name
        end)
    end

    if not still then selectedUid = nil end
    setSelected(selectedUid)
end

-- ==========================================================
-- 回転エフェクト（生きてる感じ）
-- ==========================================================
local tick = 0
local rotation = 0
RunService.Heartbeat:Connect(function(dt)
    tick = tick + 1
    if tick % 2 ~= 0 then return end
    rotation = (rotation + dt * 72) % 360
    for _, g in ipairs(living) do
        if g.Parent then
            g.Rotation = g.Parent:IsA("UIStroke") and (45 + rotation) % 360 or rotation
        end
    end
end)

-- ==========================================================
-- ボタン動作
-- ==========================================================
refreshButton.MouseButton1Click:Connect(function()
    rebuild()
end)

instantButton.MouseButton1Click:Connect(function()
    if not selectedUid then
        statusLabel.Text = "Pick an egg first"
        return
    end
    statusLabel.Text = "Instantly stealing..."
    task.spawn(function()
        local ok = tbl4.RunInstantSteal(selectedUid)
        if ok then
            statusLabel.Text = "Grabbed. Delivering..."
            -- そのまま配達
            local gen = 0
            local delivered = pcall(function()
                local start = os.clock()
                while tbl4.Steal.Carrying and os.clock() - start < 30 do
                    RunService.Heartbeat:Wait()
                end
            end)
            statusLabel.Text = delivered and "Delivered" or "Failed"
        else
            statusLabel.Text = "Could not grab"
        end
    end)
end)

toggleAuto.MouseButton1Click:Connect(function()
    local on = not tbl4.Toggle(nil, false)
    tbl4.SetAutoSteal(on)
    toggleAuto.Text = on and "Auto Steal: ON" or "Auto Steal: OFF"
    statusLabel.Text = on and "Auto Steal enabled" or "Auto Steal disabled"
    tbl3.Wake()
end)

-- ==========================================================
-- ドラッグ移動
-- ==========================================================
do
    local dragging, startPos, startInput
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = window.Position
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
            local delta = input.Position - startInput
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ==========================================================
-- オートエグゼキューター（再実行）
-- ==========================================================
local SCRIPT_URL = "https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua"

local function getQueueOnTeleport()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if type(queueonteleport) == "function" then return queueonteleport end
    if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then return syn.queue_on_teleport end
    if type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then return fluxus.queue_on_teleport end
    return nil
end

local function installAutoExec()
    local queue = getQueueOnTeleport()
    if not queue then
        warn("[AutoExec] queue_on_teleport 未対応のエグゼキューターです")
        return false
    end
    pcall(function()
        TeleportService:SetTeleportSetting("__ChilliAutoLoadScriptEnabled", true)
    end)
    if rawget(_G, "__MoonStealAutoQueued") == true then return true end

    local ok = pcall(queue, [[
local TeleportService = game:GetService("TeleportService")
local enabled = true
pcall(function()
    enabled = TeleportService:GetTeleportSetting("__ChilliAutoLoadScriptEnabled") == true
end)
if enabled then
    if not game:IsLoaded() then game.Loaded:Wait() end
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        if player and not player.Character then player.CharacterAdded:Wait() end
    end)
    task.wait(1.5)
    local ok, source = pcall(function()
        return game:HttpGet("]] .. SCRIPT_URL .. [[")
    end)
    if ok and type(source) == "string" then
        local chunk = loadstring(source)
        if chunk then chunk() end
    end
end
]])

    if ok then
        _G.__MoonStealAutoQueued = true
        return true
    end
    return false
end

installAutoExec()

-- ==========================================================
-- 起動
-- ==========================================================
tbl3.Wake()
rebuild()

-- 定期的にリストを再構築
task.spawn(function()
    while gui.Parent do
        task.wait(5)
        pcall(rebuild)
    end
end)

-- ステータス表示更新
task.spawn(function()
    while gui.Parent do
        task.wait(0.3)
        if str2 and str2 ~= "" then
            statusLabel.Text = str2
        end
    end
end)

-- クリーンアップ
fn4(function()
    pcall(function() gui:Destroy() end)
end)

print("[Moon Steal Hub] 起動完了 — 速度: 2500 / Auto Steal + Instant Steal ready")
