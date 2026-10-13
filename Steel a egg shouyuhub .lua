-- ============================================================
-- SHOUYU HUB Steal (yslemEgg base)
-- Part 1/6 : セットアップ + Shield
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ★ 設定
local CFG = {
    RunSpeed      = 3500,  -- 卵へ走る速度
    GrabSpeed     = 3500,  -- 掴む時の接近速度
    SpeedCap      = 1.15,  -- 配達時の上限倍率（walkSpeed比）
    HopRatio      = 1.515,
    HopMin        = 40,
    HopGap        = 0.06,
    HopGapMin     = 0.06,
    HopGapMax     = 0.2,
    HopRetries    = 6,
    HopLift       = 42,
    LandOffset    = 14,
    LandSettle    = 0.08,
    DropDelay     = 0.05,
    GrabInterval  = 0.03,
    RegrabFar     = 40,
    Height        = 70,
    ClimbShare    = 0.5,
    CarryRatio    = 0.9,
    EasyRatio     = 1.3,
}
local FPS = { 60, 30, 0.15 }

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

local networkingFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(name) return networkingFolder:FindFirstChild(name) end
local function root()
    local character = localPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Shield
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
            if type(controls) == "table" then controls.humanoid = humanoid end
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
    if shield.Connection then shield.Connection:Disconnect(); shield.Connection = nil end
    if shield.Added then shield.Added:Disconnect(); shield.Added = nil end
    shieldUndo()
end

print("[SHOUYU] Part1 OK")-- ============================================================
-- Part 2/6 : Carry監視 + 卵ヘルパー
-- ============================================================
local state = {
    Carrying = false, Uid = nil, Delivered = 0, Busy = false,
    Cancel = false, Mult = 1, PulledAt = 0, HeldSeen = 0, GuessedDrop = false,
}

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" and type(EggState.CarryChanged.Connect) == "function" then
    EggState.CarryChanged:Connect(function(arg)
        local carrying = type(arg) == "table" and arg.IsCarrying == true
        if carrying and arg.GuardDisabled == true then carrying = false end
        state.GuessedDrop = false
        if carrying then state.HeldSeen = os.clock() end
        if carrying and type(arg.Uid) == "string" then
            state.Uid = arg.Uid
            local mult = tonumber(arg.SpeedMultiplier)
            if mult and mult > 0 then state.Mult = mult end
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

local function promptNear(position, radius)
    local best, bestDistance = nil, radius
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

local function describe(record)
    local directory = type(Assets) == "table" and Assets.Directory or nil
    local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
    local info = { Uid = record.Uid, Category = tostring(record.AssetCategory), Name = tostring(record.AssetCategory), Icon = "", Rarity = 0, Value = 0 }
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

local status = function(text) end

print("[SHOUYU] Part2 OK")-- ============================================================
-- Part 3/6 : 移動ロジック
-- ============================================================

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

local function lineInfo()
    local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
    world = world and world:FindFirstChild("Areas")
    world = world and world:FindFirstChild("SeparationLine")
    local ok = world and world:IsA("BasePart")
    return ok and world.Position.X or 552.2, ok and world.Position.Y or 67.67
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

local function place(position)
    local r = root()
    if not r then return end
    pcall(function()
        r.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
end

local dangerCache, dangerAt = {}, 0
local function dangers()
    if os.clock() - dangerAt < 1 then return dangerCache end
    dangerAt = os.clock()
    local list = {}
    local function add(inst)
        local ok, cf, size = pcall(function()
            if inst:IsA("Model") then return inst:GetBoundingBox()
            elseif inst:IsA("BasePart") then return inst.CFrame, inst.Size end
        end)
        if ok and cf and size then
            local half = Vector3.new(math.abs(size.X), 0, math.abs(size.Z)) * 0.5
            local rot = (cf - cf.Position):VectorToWorldSpace(half)
            local rx = math.max(math.abs(rot.X), half.X, half.Z)
            local rz = math.max(math.abs(rot.Z), half.X, half.Z)
            list[#list + 1] = { MinX = cf.Position.X - rx, MaxX = cf.Position.X + rx, MinZ = cf.Position.Z - rz, MaxZ = cf.Position.Z + rz }
        end
    end
    local function bad(name)
        if name == "ScrambleLocalVisuals" or name == "DrScrambleEvent" then return false end
        name = string.lower(name)
        return string.find(name, "portal", 1, true)
            or string.find(name, "teleport", 1, true)
            or string.find(name, "mech", 1, true)
            or string.find(name, "arena", 1, true)
            or string.find(name, "scramble", 1, true)
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if (child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder")) and bad(child.Name) then
            if child:IsA("Folder") then
                for _, inner in ipairs(child:GetChildren()) do add(inner) end
            else
                add(child)
            end
        end
    end
    local build = workspace:FindFirstChild("World")
    build = build and build:FindFirstChild("Build")
    if build then
        for _, child in ipairs(build:GetChildren()) do
            if bad(child.Name) then
                for _, inner in ipairs(child:GetChildren()) do add(inner) end
            end
        end
    end
    dangerCache = list
    return list
end

local function avoid(from, to)
    for _, d in ipairs(dangers()) do
        local x0, x1, z0, z1 = d.MinX - 12, d.MaxX + 12, d.MinZ - 12, d.MaxZ + 12
        local inside = from.X >= x0 and from.X <= x1 and from.Z >= z0 and from.Z <= z1
        if not inside then
            local t0, t1, hit = 0, 1, true
            for _, axis in ipairs({ { from.X, to.X - from.X, x0, x1 }, { from.Z, to.Z - from.Z, z0, z1 } }) do
                local pos, delta, lo, hi = axis[1], axis[2], axis[3], axis[4]
                if math.abs(delta) < 1e-6 then
                    if pos < lo or pos > hi then hit = false end
                else
                    local ta, tb = (lo - pos) / delta, (hi - pos) / delta
                    if ta > tb then ta, tb = tb, ta end
                    t0, t1 = math.max(t0, ta), math.min(t1, tb)
                    if t0 > t1 then hit = false end
                end
            end
            if hit then
                local zLow, zHigh = z0 - 2, z1 + 2
                local z = math.abs(from.Z - zLow) <= math.abs(from.Z - zHigh) and zLow or zHigh
                if z < -440 or z > -290 then z = z == zLow and zHigh or zLow end
                local x = math.abs(from.X - x0) <= math.abs(from.X - x1) and x0 or x1
                if math.abs(from.Z - z) < 3 then
                    x = math.abs(to.X - x0) <= math.abs(to.X - x1) and x0 or x1
                end
                return Vector3.new(x, to.Y, z)
            end
        end
    end
    return to
end

-- ★ 走って行く速度 = 3500
local function runToEgg(uid, egg)
    local lineX = lineInfo()
    local home = homePoint()
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        if character:FindFirstChildWhichIsA("Tool") then
            pcall(function() humanoid:UnequipTools() end)
        end
    end

    local r = root()
    if not r then return false end
    local stage = "field"
    if r.Position.X < lineX - 2
        and Vector3.new(r.Position.X - home.X, 0, r.Position.Z - home.Z).Magnitude > 20 then
        stage = "safe"
    end

    local started, lastCheck, lastPos, lastTake = os.clock(), os.clock(), r.Position, 0
    while os.clock() - started < 120 and not state.Cancel do
        r = root()
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

        local waypoint = avoid(r.Position, target)
        local flat = Vector3.new(waypoint.X - r.Position.X, 0, waypoint.Z - r.Position.Z)
        local unit = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
        local speed = CFG.RunSpeed  -- ★ 3500
        local v = unit * math.min(speed, flat.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, r.AssemblyLinearVelocity.Y, v.Z)
            if humanoid and unit.Magnitude > 0 then
                humanoid:Move(unit, false)
            end
        end)

        if os.clock() - lastCheck >= 1.5 then
            if (r.Position - lastPos).Magnitude < 3 and humanoid and flatEgg.Magnitude > 15 then
                pcall(function() humanoid.Jump = true end)
            end
            lastPos, lastCheck = r.Position, os.clock()
        end

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
            if humanoid then humanoid:Move(Vector3.zero, false) end
        end)
    end
    return state.Carrying
        or (r ~= nil and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
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

-- ★ 掴む時の接近速度 = 3500
local function grab(uid, timeout)
    local cache = { At = 0 }
    local waited, since = 0, 1
    while not state.Carrying and waited < timeout and not state.Cancel do
        local r = root()
        local egg = eggNow(uid, cache)
        local dt = math.max(RunService.Heartbeat:Wait(), 1 / 240)
        waited += dt
        since += dt
        if r and egg then
            local delta = egg - r.Position
            if delta.Magnitude > 2 then
                local pace = CFG.GrabSpeed  -- ★ 3500
                local v = delta / math.max(0.08, dt)
                if v.Magnitude > pace then v = v.Unit * pace end
                pcall(function()
                    r.AssemblyLinearVelocity = v + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
                    r.AssemblyAngularVelocity = Vector3.zero
                end)
            end
            if since >= CFG.GrabInterval then
                since = 0
                local prompt = promptNear(egg - Vector3.new(0, 3, 0), 10)
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

local function regrab(uid)
    if state.Carrying then return true end
    local r = root()
    local egg = eggPosition(uid)
    if r and egg
        and Vector3.new(r.Position.X - egg.X, 0, r.Position.Z - egg.Z).Magnitude > CFG.RegrabFar then
        status("The egg fell far behind, teleporting onto it")
        place(egg + Vector3.new(0, 3, 0))
    else
        status("The egg fell close, taking it back")
    end
    return grab(uid, 3)
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
    if humanoid then humanoid.PlatformStand = false end

    local r = root()
    if r and character and height > 0.5 and home.Y + height - 2 > r.Position.Y then
        pcall(function()
            character:PivotTo(CFrame.new(Vector3.new(r.Position.X, home.Y + height, r.Position.Z)) * r.CFrame.Rotation)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local start = root()
    local speed = carrySpeed(start and (
        Vector3.new(start.Position.X - home.X, 0, start.Position.Z - home.Z).Magnitude
        + math.max(0, height) * 2
    ) or nil)

    local last = os.clock()
    local timeout = 0
    status("Safe zone")
    while state.Carrying and state.Delivered < started and not state.Cancel and timeout < 25 do
        r = root()
        if not r then return false end
        local now = os.clock()
        local dt = math.max(now - last, 1 / 240)
        last = now
        timeout += dt

        local toHome = r.Position.X <= checkpoint + 2
        local target = toHome and home or Vector3.new(checkpoint, home.Y, laneZ)
        if toHome and Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z).Magnitude < 2 then break end
        local aim = avoid(r.Position, target)
        local flat = Vector3.new(aim.X - r.Position.X, 0, aim.Z - r.Position.Z)
        local remaining = toHome and 0 or math.max(0, r.Position.X - checkpoint)
        local wantY = home.Y + height
        if toHome or remaining <= descent then
            wantY = home.Y + height * math.clamp(remaining / math.max(descent, 1), 0, 1)
        end
        local vy = math.clamp((wantY - r.Position.Y) / 0.12, -speed * share, speed * share)
        local horizontal = math.sqrt(math.max(speed * speed - vy * vy, 0))
        local v = flat.Magnitude > 0.01
            and flat.Unit * math.min(horizontal, flat.Magnitude / 0.05)
            or Vector3.zero
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
        end)
        RunService.Heartbeat:Wait()
    end

    if humanoid then pcall(function() humanoid:Move(Vector3.zero, false) end) end
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

print("[SHOUYU] Part3 OK")-- ============================================================
-- ============================================================
-- Part 4/6 (差し替え) : 移動配送 + stealAndDeliver
-- Instant TPをやめて、実際に飛んで家まで移動する
-- ============================================================

-- ★ 家まで飛んで移動（テレポートなし、速度3500）
local function flyHome(uid, lineX, laneZ)
    local started = os.clock()
    local home = homePoint()
    local r = root()
    if not r then return false end

    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = true end

    local speed = CFG.RunSpeed  -- 3500

    -- =========================================================
    -- Step 1: 上空へ上昇
    -- =========================================================
    local startPos = r.Position
    local highY = math.max(startPos.Y, home.Y) + CFG.Height
    local t1 = os.clock()
    while os.clock() - t1 < 10 and not state.Cancel do
        if not state.Carrying and state.Delivered < started then
            if humanoid then humanoid.PlatformStand = false end
            return false
        end
        r = root()
        if not r then return false end
        local d = Vector3.new(0, highY - r.Position.Y, 0)
        if d.Magnitude < 3 then break end
        local v = d.Unit * math.min(speed, d.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = v
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    -- =========================================================
    -- Step 2: 家の上空へ水平移動
    -- =========================================================
    local t2 = os.clock()
    while os.clock() - t2 < 15 and not state.Cancel do
        if not state.Carrying and state.Delivered < started then
            if humanoid then humanoid.PlatformStand = false end
            return false
        end
        r = root()
        if not r then return false end
        local flat = Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z)
        if flat.Magnitude < 6 then break end
        local v = flat.Unit * math.min(speed, flat.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    -- =========================================================
    -- Step 3: 家へ降下（ここでドロップ）
    -- =========================================================
    local t3 = os.clock()
    while os.clock() - t3 < 15 and not state.Cancel do
        if not state.Carrying and state.Delivered < started then
            if humanoid then humanoid.PlatformStand = false end
            return false
        end
        r = root()
        if not r then return false end
        local d = home - r.Position
        if d.Magnitude < 5 then break end
        local v = d.Unit * math.min(speed, d.Magnitude / 0.05)
        pcall(function()
            r.AssemblyLinearVelocity = v
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end

    -- 停止
    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if humanoid then humanoid.PlatformStand = false end
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
-- stealAndDeliver（移動配送版）
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

            fpsOn()

            status("Going to the egg")
            if not runToEgg(uid, egg) then
                fpsOff()
                status("Could not reach the egg")
                return
            end

            status("Taking the egg")
            if not grab(uid, 4) then
                fpsOff()
                status("The egg would not come free")
                return
            end

            status("Flying home")
            local lineX, lineY = lineInfo()
            local r = root()
            local laneZ = r and math.clamp(r.Position.Z, -425, -300) or -360
            local delivered = flyHome(uid, lineX, laneZ)

            status(delivered and "Delivered" or "Delivery failed")
        end)
        fpsOff()
        dropClone()
        if not ok then
            status("Error: " .. tostring(err))
        end
        state.Busy = false
    end)
end

print("[SHOUYU] Part4(移動配送) OK")
-- Part 5/6 : SHOUYU UI 前半
-- ============================================================
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

-- アバター
local avatarFrame = make("Frame", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(7, 7),
    BackgroundColor3 = THEME.AccentDeep,
    BorderSizePixel = 0,
})
avatarFrame.Parent = header
corner(avatarFrame, 19)
make("ImageLabel", {
    Size = UDim2.fromScale(0.88, 0.88),
    Position = UDim2.fromScale(0.06, 0.06),
    BackgroundTransparency = 1,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150",
    Parent = avatarFrame,
})
corner(avatarFrame:FindFirstChildOfClass("ImageLabel"), 19)

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
    Text = "STEAL AN EGG - " .. CFG.RunSpeed,
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

-- 卵リスト
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

print("[SHOUYU] Part5 OK")-- ============================================================
-- Part 6/6 : SHOUYU UI 後半 + 起動
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

-- ステータスコールバック
status = function(msg)
    msg = tostring(msg)
    local PUBLIC = {
        ["Pick a pet"] = true,
        ["Looking for the egg"] = true,
        ["Going to the egg"] = true,
        ["Taking the egg"] = true,
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
        statusLabel.Text = "Delivering"
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
    fpsOff()
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

-- Stealボタン状態監視
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

print("[SHOUYU] 起動完了 / 走行速度 " .. CFG.RunSpeed .. " / 掴み速度 " .. CFG.GrabSpeed)
