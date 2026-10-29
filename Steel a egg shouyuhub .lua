-- ============================================================
-- ShouyuHub | Ultimate Steal (Improved Instant TP)
-- Part 1/5: Config / Dependencies / State / Events / Helpers
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local localPlayer       = Players.LocalPlayer

local CFG = {
    -- Hop engine (learned gap, velocity based)
    HopGapMin      = 0.06,
    HopGapMax      = 0.20,
    HopGapStart    = 0.06,
    HopRatio       = 1.515,
    HopMin         = 40,
    HopLift        = 42,
    HopRetries     = 6,
    LandOffset     = 14,
    LandSettle     = 0.08,
    DropDelay      = 0.05,

    -- Grab
    GrabRadius     = 15,
    GrabInterval   = 0.03,
    GrabTimeout    = 4,
    RegrabFar      = 40,

    -- Speed
    SpeedCap       = 1.15,
    CarryRatio     = 0.9,
    EasyRatio      = 1.3,
    Height         = 70,
    ClimbShare     = 0.5,

    -- Snapshot
    SnapshotTTL    = 0.5,

    -- Loop
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

-- ============================================================
-- State
-- ============================================================
local state = {
    Carrying = false, Uid = nil, Busy = false, Cancel = false, Delivered = 0,
    Mult = 1, PulledAt = 0, HeldSeen = 0, GuessedDrop = false, ReleaseCamera = nil,
}

-- ============================================================
-- Events
-- ============================================================
if type(EggState) == "table" and type(EggState.CarryChanged) == "table" then
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
    local re = remote("RE/EggWorld/FieldEggRedeemVerdict")
    if re and re:IsA("RemoteEvent") then
        re.OnClientEvent:Connect(function() state.Delivered = os.clock() end)
    end
end)

-- Relocate = the server pulled us back; the hop can simply retry from the same spot
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

-- Catch a missed carry signal via the egg's weld to our character
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

-- ============================================================
-- Helpers
-- ============================================================
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

local function lineInfo()
    local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
    world = world and world:FindFirstChild("Areas")
    world = world and world:FindFirstChild("SeparationLine")
    local ok = world and world:IsA("BasePart")
    return ok and world.Position.X or 552.2, ok and world.Position.Y or 67.67
end

-- ============================================================
-- Snapshot (fallback) + direct workspace read
-- ============================================================
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

-- Direct workspace read first (works even without a snapshot call)
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
end-- ============================================================
-- Part 2/5: Shield + Engine primitives
-- ============================================================

-- ============================================================
-- Humanoid Swap shield
-- ============================================================
local shield = { Original = nil, Clone = nil, Links = {}, Connection = nil, Added = nil }

local function walkSpeed()
    local character = localPlayer.Character
    local h = character and character:FindFirstChildOfClass("Humanoid")
    local speed = h and h.WalkSpeed or 16
    if shield.Original and shield.Original.Health > 0 then
        speed = math.min(speed, shield.Original.WalkSpeed)
    end
    return speed
end

local function shieldControls(h)
    pcall(function()
        local scripts = localPlayer:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if module then
            local controls = require(module):GetControls()
            if type(controls) == "table" then controls.humanoid = h end
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

local function grounded(h)
    if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
    return groundedStates[h:GetState()] == true
end

local function shieldSwap()
    local character = localPlayer.Character
    local h = character and character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return end
    if shield.Clone and shield.Clone.Parent == character then return end
    if not grounded(h) then return end

    local clone = h:Clone()
    h.Parent = nil
    clone.Parent = character
    workspace.CurrentCamera.CameraSubject = clone
    shieldControls(clone)
    shieldAnimate(character)
    shield.Original = h
    shield.Clone = clone

    table.insert(shield.Links, h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if clone.Parent ~= nil then clone.WalkSpeed = h.WalkSpeed end
    end))

    local animator = h:FindFirstChildOfClass("Animator")
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
        if current and h.Parent == nil then
            h.Parent = current
            workspace.CurrentCamera.CameraSubject = h
            shieldControls(h)
        end
        pcall(function() clone:Destroy() end)
        h.Health = 0
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

-- ============================================================
-- Velocity engine (PivotTo + AssemblyLinearVelocity + gravity comp)
-- ============================================================
local function pivotTo(pos, faceAt)
    local character = localPlayer.Character
    local r = root()
    if not character or not r then return end
    local rot
    if faceAt then
        local flat = Vector3.new(faceAt.X - pos.X, 0, faceAt.Z - pos.Z)
        rot = flat.Magnitude > 0.05 and CFrame.lookAt(Vector3.zero, flat.Unit) or r.CFrame.Rotation
    else
        rot = r.CFrame.Rotation
    end
    local cf = CFrame.new(pos) * rot
    pcall(function() character:PivotTo(cf) end)
    if (r.Position - pos).Magnitude > 3 then
        pcall(function() r.CFrame = cf end)
    end
end

local function setVelocity(vel, dt)
    local r = root()
    if not r then return end
    local g = workspace.Gravity * math.max(dt or 0, 1/240) * 0.5
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y + g, vel.Z)
        r.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function stopMotion()
    local r = root()
    if not r then return end
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ============================================================
-- FPS toggle (60/30 alternating)
-- ============================================================
local fpsGen = 0
local function fpsOn()
    if typeof(setfpscap) ~= "function" then return end
    fpsGen += 1
    local mine = fpsGen
    task.spawn(function()
        local high = true
        local started = os.clock()
        while fpsGen == mine and os.clock() - started < 60 do
            pcall(setfpscap, high and 60 or 30)
            high = not high
            task.wait(0.15)
        end
    end)
end

local function fpsOff()
    fpsGen += 1
    if typeof(setfpscap) == "function" then pcall(setfpscap, 240) end
end

-- ============================================================
-- Camera freeze (restore at the very end)
-- ============================================================
local function frozenCamera()
    local cam = workspace.CurrentCamera
    if not cam then return function() end end
    local oldType = cam.CameraType
    local frame = cam.CFrame
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = frame
    end)
    return function()
        pcall(function() cam.CameraType = oldType end)
    end
end

-- ============================================================
-- Decoy clone (stays at the egg position)
-- ============================================================
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

-- ============================================================
-- Danger zones (portals / arenas / teleporters)
-- ============================================================
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
        return string.find(name, "portal", 1, true) or string.find(name, "teleport", 1, true)
            or string.find(name, "mech", 1, true) or string.find(name, "arena", 1, true) or string.find(name, "scramble", 1, true)
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if (child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder")) and bad(child.Name) then
            if child:IsA("Folder") then
                for _, inner in ipairs(child:GetChildren()) do add(inner) end
            else add(child) end
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
	end-- ============================================================
-- Part 3/5: Movement + Grab + Instant TP
-- ============================================================

-- ============================================================
-- runToEgg: velocity ground run with danger avoidance + stuck jump
-- ============================================================
local function runToEgg(uid, egg)
    local lineX = lineInfo()
    local home = homePoint()
    local character = localPlayer.Character
    local h = character and character:FindFirstChildOfClass("Humanoid")
    if h then
        h.PlatformStand = false
        if character:FindFirstChildWhichIsA("Tool") then
            pcall(function() h:UnequipTools() end)
        end
    end

    local r = root()
    if not r then return false end

    local stage = "field"
    if r.Position.X < lineX - 2 and Vector3.new(r.Position.X - home.X, 0, r.Position.Z - home.Z).Magnitude > 20 then
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
        local speed = math.max(walkSpeed() * CFG.SpeedCap, 8)
        local v = unit * math.min(speed, flat.Magnitude / 0.05)
        setVelocity(v, RunService.Heartbeat:Wait())

        if os.clock() - lastCheck >= 1.5 then
            if (r.Position - lastPos).Magnitude < 3 and h and flatEgg.Magnitude > 15 then
                pcall(function() h.Jump = true end)
            end
            lastPos, lastCheck = r.Position, os.clock()
        end

        if stage == "field" and flatEgg.Magnitude <= 9 and os.clock() - lastTake > 0.1 then
            lastTake = os.clock()
            takeEgg(uid)
        end
    end

    r = root()
    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
            if h then h:Move(Vector3.zero, false) end
        end)
    end
    return state.Carrying or (r ~= nil and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
end

-- ============================================================
-- grab: 30ms interval, follows the egg
-- ============================================================
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
                local pace = math.max(walkSpeed() * CFG.SpeedCap, 16)
                local v = delta / math.max(0.08, dt)
                if v.Magnitude > pace then v = v.Unit * pace end
                setVelocity(v, dt)
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
    stopMotion()
    return state.Carrying and state.Uid == uid
end

local function regrab(uid)
    if state.Carrying then return true end
    local r = root()
    local egg = eggNow(uid, { At = 0 })
    if r and egg and Vector3.new(r.Position.X - egg.X, 0, r.Position.Z - egg.Z).Magnitude > CFG.RegrabFar then
        status("卵が遠くに落ちた、テレポートします")
        pivotTo(egg + Vector3.new(0, 3, 0))
    else
        status("卵が近くに落ちた、取り直します")
    end
    return grab(uid, 3)
end

-- ============================================================
-- Carry speed: distance-based plan (same as the hub)
-- ============================================================
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

-- ============================================================
-- runHome: rise above base, descend, drop fallback
-- ============================================================
local function runHome(lineX, laneZ)
    local started = os.clock()
    local home = homePoint()
    local checkpoint = lineX - 7
    local height = CFG.Height
    local share = math.clamp(CFG.ClimbShare, 0.1, 0.9)
    local descent = height * math.sqrt(1 - share * share) / share
    local character = localPlayer.Character
    local h = character and character:FindFirstChildOfClass("Humanoid")
    if h then h.PlatformStand = false end

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
        local dt = math.max(now - last, 1/240)
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
        local v = flat.Magnitude > 0.01 and flat.Unit * math.min(horizontal, flat.Magnitude / 0.05) or Vector3.zero
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
        end)
        RunService.Heartbeat:Wait()
    end

    if h then pcall(function() h:Move(Vector3.zero, false) end) end

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

-- ============================================================
-- instantTP: hop home (learned gap, Relocate aware) + land + drop + regrab + runHome
-- ============================================================
local function place(position)
    pivotTo(position)
    stopMotion()
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
    local hopGap = CFG.HopGapStart
    local releaseCamera = frozenCamera()
    state.ReleaseCamera = releaseCamera
    pcall(postClone)
    fpsOn()

    while x - hopStep > landing.X and not state.Cancel do
        local skipHop = false
        if not state.Carrying then
            if not regrab(uid) then break end
            local current = root()
            if current then x = math.min(x, current.Position.X) end
            skipHop = true
        end
        if not skipHop then
            local nextX = x - hopStep
            status(string.format("Instant TP: 帰還中 X %d", math.floor(nextX)))
            local pulledBefore = state.PulledAt
            local held = 0
            while held < hopGap do
                place(Vector3.new(nextX, hopY, laneZ))
                held += RunService.Heartbeat:Wait()
            end

            local check = root()
            local pulled = state.PulledAt > pulledBefore
                or (check ~= nil and (check.Position.X - nextX > 10 or check.AssemblyLinearVelocity.Magnitude > 150))
            if pulled and state.Carrying and not state.Cancel then
                retries += 1
                hopGap = math.min(CFG.HopGapMax, hopGap + 0.02)
                if retries > CFG.HopRetries then break end
                status(string.format("Instant TP: 引き戻し、再試行 %d/%d", retries, CFG.HopRetries))
                local settle = 0
                while settle < 0.12 and not state.Cancel do
                    place(Vector3.new(x, hopY, laneZ))
                    settle += RunService.Heartbeat:Wait()
                end
            else
                x = nextX
                hopGap = math.max(CFG.HopGapMin, hopGap - 0.01)
            end
        end
    end

    -- landing
    status("Instant TP: ライン付近に着地")
    local function land()
        local current = root()
        if current and current.Position.X <= landing.X + 1 and current.Position.Y > landing.Y - 25 then
            stopMotion()
            return
        end
        place(landing)
    end
    land()
    for attempt = 1, 3 do
        local settle = 0
        while settle < CFG.LandSettle and not state.Cancel do
            settle += RunService.Heartbeat:Wait()
        end
        local landed = root()
        if state.Carrying and landed and (landed.Position.X - landing.X > 12 or landed.Position.Y < landing.Y - 25) then
            status("Instant TP: 着地リトライ " .. attempt)
            land()
        else break end
    end
    dropClone()

    -- drop and regrab
    if state.Carrying and not state.Cancel then
        local delay = 0
        while delay < CFG.DropDelay do
            delay += RunService.Heartbeat:Wait()
        end
        status("Instant TP: 卵をドロップ")
        dropEgg()
        local waited = 0
        while state.Carrying and waited < 1 and not state.Cancel do
            waited += RunService.Heartbeat:Wait()
        end
        stopMotion()
        releaseCamera()
        dropClone()
        status("Instant TP: 卵を取り直し")
        if not grab(uid, 3) and not regrab(uid) then
            fpsOff()
            status("卵を取り直せませんでした")
            return false
        end
        dropClone()
    end
    releaseCamera()

    local ok = false
    if state.Carrying then ok = runHome(lineX, laneZ) end
    fpsOff()
    return ok or state.Delivered >= started
		end-- ============================================================
-- Part 4/5: Steal Logic
-- ============================================================

local function stealAndDeliver(uid, retry)
    if state.Busy then return false end
    state.Busy = true
    state.Cancel = false
    local attempts = retry and CFG.MaxRetries or 1
    local succeeded = false

    for attempt = 1, attempts do
        if state.Cancel then break end

        status("卵を探しています")
        local egg = eggNow(uid, { At = 0 })
        if not egg then
            status("卵が見つかりません")
            break
        end

        if state.Carrying and state.Uid ~= uid then
            dropEgg()
            local waited = 0
            while state.Carrying and waited < 1 do
                waited += RunService.Heartbeat:Wait()
            end
        end

        fpsOn()
        status("卵へ移動中" .. (attempt > 1 and (" (" .. attempt .. ")") or ""))
        local reached = runToEgg(uid, egg)
        if not reached then
            fpsOff()
            status("卵に届きませんでした")
        else
            status("掴み中")
            local got = grab(uid, CFG.GrabTimeout)
            if not got then
                fpsOff()
                status("卵を掴めませんでした")
            else
                local delivered = instantTP(uid)
                fpsOff()
                if delivered then
                    succeeded = true
                    status("納品完了")
                    break
                else
                    status("納品失敗")
                end
            end
        end

        if attempt < attempts and not state.Cancel then
            task.wait(1)
        end
    end

    fpsOff()
    dropClone()
    if state.ReleaseCamera then
        pcall(state.ReleaseCamera)
        state.ReleaseCamera = nil
    end

    state.Busy = false
    return succeeded
end

-- ============================================================
-- Auto loop
-- ============================================================
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
            if (autoFilter.MinRarity <= 0 or info.Rarity >= autoFilter.MinRarity)
                and (autoFilter.MinValue <= 0 or info.Value >= autoFilter.MinValue) then
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
                    if not ok and not state.Cancel then
                        blocked[best.Uid] = os.clock() + CFG.BlockedSec
                    end
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
-- ============================================================
-- Part 5/5: UI Construction + UI Logic + Init (unchanged)
-- ============================================================
print("[ShouyuHub] UI 構築開始")
local UI_W, UI_H, UI_H_MIN = 300, 440, 64
local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuHub_LightBlue"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = localPlayer:WaitForChild("PlayerGui")
guiRef = gui

local main = Instance.new("Frame", gui)
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
title.Text = "SHOUYU HUB"
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
        status("キャンセル中...")
        return
    end
    if selectedUid then task.spawn(function() stealAndDeliver(selectedUid, false) end)
    else status("卵を選んでください") end
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
    state.Cancel = true
    stopAutoLoop()
    gui:Destroy()
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
end)

-- ============================================================
-- Init
-- ============================================================
task.spawn(function()
    while gui.Parent do
        task.wait(CFG.AutoRefresh)
        if not state.Busy then pcall(rebuild) end
    end
end)

task.spawn(function()
    while gui.Parent do
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

-- Start the shield immediately so the whole run is protected
shieldStart()

print("[ShouyuHub] 起動完了")
