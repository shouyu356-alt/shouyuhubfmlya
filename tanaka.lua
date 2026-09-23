-- shouyuhub | Steal An Egg
-- Obsidian UI + Full Feature Port

-- ============ Executor Check ============
for _, obj in getgc(true) do
    if typeof(obj) ~= "table" or getrawmetatable(obj) then continue end
    local mainrun = false
    for _, v in obj do
        if v == obj then mainrun = true break end
    end
    if not mainrun then continue end
    for _, v in obj do
        if typeof(v) == "number" and v >= 1 and v <= 3 and obj[v] == nil then
            setmetatable(obj, {__newindex = function() end})
            break
        end
    end
end

local _chk_Players = game:GetService("Players")
local _chk_TweenService = game:GetService("TweenService")
local _chk_CoreGui = game:GetService("CoreGui")
local _chk_player = _chk_Players.LocalPlayer

local REQUIRED_FUNCS = {
    { Name = "loadstring", Test = function() return type(loadstring) == "function" end },
    { Name = "HTTP", Test = function()
        if type(game.HttpGet) == "function" then return true end
        if type(request) == "function" or type(http_request) == "function" then return true end
        if type(syn) == "table" and type(syn.request) == "function" then return true end
        return false
    end },
}

local missing = {}
for _, item in ipairs(REQUIRED_FUNCS) do
    local ok = pcall(item.Test)
    if not ok then table.insert(missing, item.Name) end
end

local function showWarning(msg)
    local sg = Instance.new("ScreenGui")
    sg.Name = "ExecutorCompatWarning"
    sg.ResetOnSpawn = false
    pcall(function() sg.Parent = _chk_CoreGui end)
    if not sg.Parent then sg.Parent = _chk_player:WaitForChild("PlayerGui") end
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 340, 0, 160)
    card.Position = UDim2.new(0.5, -170, 0.5, -80)
    card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", card)
    stroke.Color = Color3.fromRGB(255, 80, 80); stroke.Thickness = 2
    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -24, 0, 24); title.Position = UDim2.new(0, 12, 0, 40)
    title.BackgroundTransparency = 1; title.Text = "Executor Not Supported"
    title.TextSize = 17; title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(240, 240, 245)
    local body = Instance.new("TextLabel", card)
    body.Size = UDim2.new(1, -24, 0, 60); body.Position = UDim2.new(0, 12, 0, 70)
    body.BackgroundTransparency = 1; body.Text = msg; body.TextSize = 12
    body.Font = Enum.Font.Gotham; body.TextColor3 = Color3.fromRGB(180, 180, 190)
    body.TextWrapped = true
end

if #missing > 0 then
    showWarning("Missing: " .. table.concat(missing, ", "))
    return
end

-- ============ Load Obsidian (MASA UI) ============
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()
if not Library then
    warn("[shouyuhub] Obsidian failed to load")
    return
end

-- ============ Services ============
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- ============ Memory ============
local Memory = getgenv().MergedUtilityMemory
if not Memory then
    Memory = {
        SpeedEnabled = true, DesiredSpeed = 500,
        SpeedBypassMethod = "Humanoid Clone",
        AntiKnockbackEnabled = false, AntiRagdollEnabled = false,
        InstantAccelerationEnabled = false, AntiRejoinEnabled = false,
        FlyEnabled = false, FlySpeed = 50,
        EggEspEnabled = false, EggAutoStealEnabled = false,
        EggRarityFilter = "All", EggBigOnly = false,
        AntiTrapEnabled = false, AutoSellEnabled = false,
        AutoSellRarities = {"Common", "Uncommon", "Rare", "Epic"},
        AutoPlaceAll = false, AutoHatch = false,
        AutoEnterAbyss = false, AutoClaim = false,
        AutoUpgradeBase = false, AutoUpgradeTreadmill = false,
        AutoBuyTrail = false,
    }
    getgenv().MergedUtilityMemory = Memory
end

local DesiredSpeed = Memory.DesiredSpeed or 500
local SpeedEnabled = Memory.SpeedEnabled or false
local SpeedBypassMethod = Memory.SpeedBypassMethod or "Humanoid Clone"
local AntiKnockbackEnabled = Memory.AntiKnockbackEnabled or false
local AntiRagdollEnabled = Memory.AntiRagdollEnabled or false
local InstantAccelerationEnabled = Memory.InstantAccelerationEnabled or false
local AntiRejoinEnabled = Memory.AntiRejoinEnabled or false
local FlyEnabled = Memory.FlyEnabled or false
local FlySpeed = Memory.FlySpeed or 50
local AntiTrapEnabled = Memory.AntiTrapEnabled or false
local AutoSellEnabled = Memory.AutoSellEnabled or false
local AutoSellRarities = Memory.AutoSellRarities or {"Common", "Uncommon", "Rare", "Epic"}

local FlyBodyVelocity, FlyBodyGyro, FlyConnection
local CurrentHumanoid
local ragdollConnection = nil
local joints = {}

-- ============ safeRequire ============
local function safeRequire(parent, ...)
    local current = parent
    for _, name in ipairs({...}) do
        local child = current:FindFirstChild(name)
        if not child then
            local success, result = pcall(function() return current:WaitForChild(name, 5) end)
            if success and result then child = result else return nil end
        end
        current = child
    end
    if not current:IsA("ModuleScript") then return nil end
    local success, result = pcall(require, current)
    return success and result or nil
end

local EggState = safeRequire(ReplicatedStorage, "Client", "EggState")
local Assets = safeRequire(ReplicatedStorage, "Data", "Assets")
local WorkspaceEggVisibility = nil
pcall(function()
    WorkspaceEggVisibility = require(LocalPlayer.PlayerScripts.Game.AreaEggs.WorkspaceEggVisibility)
end)

-- ============ Rarity ============
local RarityColors = {
    Common = Color3.fromRGB(150,150,150), Uncommon = Color3.fromRGB(100,200,100),
    Rare = Color3.fromRGB(100,150,255), SuperRare = Color3.fromRGB(80,120,255),
    Epic = Color3.fromRGB(180,80,255), Legendary = Color3.fromRGB(255,200,50),
    Mythic = Color3.fromRGB(255,100,200), Mythical = Color3.fromRGB(255,100,200),
    Divine = Color3.fromRGB(255,50,50), Secret = Color3.fromRGB(255,30,30),
    BrainrotGod = Color3.fromRGB(255,0,0), God = Color3.fromRGB(255,0,0),
    Exclusive = Color3.fromRGB(255,100,50), Limited = Color3.fromRGB(255,150,50),
    Prismatic = Color3.fromRGB(255,100,255), Transcendent = Color3.fromRGB(200,50,255),
    Eternal = Color3.fromRGB(100,255,255), Exotic = Color3.fromRGB(255,200,100),
    Rainbow = Color3.fromRGB(255,100,255), Superior = Color3.fromRGB(255,80,80),
    Titan = Color3.fromRGB(255,120,50), Celestial = Color3.fromRGB(100,200,255),
    Cosmic = Color3.fromRGB(150,100,255), Admin = Color3.fromRGB(255,0,0),
}

local RarityPriority = {
    ["admin"] = 100, ["secret"] = 99, ["brainrotgod"] = 98,
    ["divine"] = 97, ["god"] = 96,
    ["eternal"] = 90, ["transcendent"] = 89, ["prismatic"] = 88,
    ["celestial"] = 87, ["cosmic"] = 86, ["titan"] = 85,
    ["mythical"] = 80, ["mythic"] = 79, ["superior"] = 78,
    ["exclusive"] = 77, ["limited"] = 76,
    ["legendary"] = 60,
    ["epic"] = 50, ["exotic"] = 49, ["rainbow"] = 48,
    ["superrare"] = 30, ["rare"] = 20, ["uncommon"] = 10, ["common"] = 1,
}

-- ============ Egg Tracking State ============
local espEnabled = Memory.EggEspEnabled or false
local autoStealEnabled = Memory.EggAutoStealEnabled or false
local eggRarityFilter = Memory.EggRarityFilter or "All"
local eggBigOnly = Memory.EggBigOnly or false
local trackedEggs = {}
local bestEggUid = nil
local espBeam, espPlayerAttach, espEggAttach
local modelCache, promptCache = {}, {}
local espLoopRunning, autoLoopRunning = false, false
local bigOnlyAutoStealEnabled, bigOnlyLoopRunning = false, false
-- ============ Egg Model Helpers ============
local function findEggModel(uid)
    local cached = modelCache[uid]
    if cached and cached.Parent then return cached end
    if WorkspaceEggVisibility and WorkspaceEggVisibility.ResolveModel then
        local s, r = pcall(function() return WorkspaceEggVisibility.ResolveModel(uid) end)
        if s and r and r:IsA("Model") then modelCache[uid] = r; return r end
    end
    local m = Workspace:FindFirstChild(uid)
    if m and m:IsA("Model") then modelCache[uid] = m; return m end
    local aesc = Workspace:FindFirstChild("AreaEggSlotsClient")
    if aesc then
        m = aesc:FindFirstChild(uid)
        if m and m:IsA("Model") then modelCache[uid] = m; return m end
    end
    return nil
end

local function getModelBasePart(model)
    if not model then return nil end
    if model.PrimaryPart then return model.PrimaryPart end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function getModelPrompt(model)
    if not model then return nil end
    local cached = promptCache[model]
    if cached and cached.Parent then return cached end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" then
            promptCache[model] = d; return d
        end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then promptCache[model] = d; return d end
    end
    return nil
end

local function getRarityColor(category)
    local info = Assets and Assets.Directory and Assets.Directory[category]
    local r = info and info.Rarity
    if not r or not r.Name then return Color3.fromRGB(150,150,150) end
    return RarityColors[tostring(r.Name)] or Color3.fromRGB(150,150,150)
end

local rarityNameCache = {}
local function getEggRarityName(record)
    if not record then return "Unknown" end
    local cat = record.AssetCategory
    if not cat then return "Unknown" end
    local cached = rarityNameCache[cat]
    if cached then return cached end
    local info = Assets and Assets.Directory and Assets.Directory[cat]
    local r = info and info.Rarity
    if not r then rarityNameCache[cat] = "Unknown"; return "Unknown" end
    local name = "Unknown"
    if r.Name ~= nil then name = tostring(r.Name)
    elseif type(r) == "string" then name = r end
    rarityNameCache[cat] = name
    return name
end

local function getModelSizeScore(model)
    if not model or not model.Parent then return 0 end
    local success, size = pcall(function() return model:GetExtentsSize() end)
    if success and size then
        return math.floor(math.max(size.X, size.Y, size.Z) * 100)
    end
    return 0
end

local function getEggRarityPriority(record)
    local info = Assets and Assets.Directory and Assets.Directory[record.AssetCategory]
    local r = info and info.Rarity
    if not r then return 0 end
    local name = r.Name and tostring(r.Name):lower() or ""
    local priority = RarityPriority[name] or 0
    if priority == 0 and record.AssetCategory then
        local catName = tostring(record.AssetCategory):lower()
        for rarityName, p in pairs(RarityPriority) do
            if catName:find(rarityName) then priority = p; break end
        end
    end
    return priority
end

local function scoreEgg(data)
    local record = data.record
    local sizeScore = getModelSizeScore(data.model)
    if eggBigOnly then return sizeScore end
    local priority = getEggRarityPriority(record)
    local info = Assets and Assets.Directory and Assets.Directory[record.AssetCategory]
    local r = info and info.Rarity
    local rarityNumber = (r and r.RarityNumber) or 0
    if eggRarityFilter ~= "All" then
        return (sizeScore * 100000000) + rarityNumber
    end
    return (priority * 100000000) + (rarityNumber * 10000) + sizeScore
end

-- ============ Carried Check ============
local function isEggCarriedByOtherPlayer(uid)
    local data = trackedEggs[uid]
    if not data then return false end
    local model = data.model
    if not model then return false end
    local parent = model.Parent
    if parent then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and parent:IsDescendantOf(plr.Character) then
                return true, plr
            end
        end
    end
    local record = data.record
    local eggName = nil
    if record and record.AssetCategory then
        eggName = tostring(record.AssetCategory):lower()
    end
    local modelName = model.Name:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            if char then
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        local tName = tool.Name:lower()
                        if tName:find("area egg") or tName:find("carryareaegg") or
                           tName == "egg" or tName:find("^egg_") or tName:find("_egg$") then
                            if eggName and (tName:find(eggName) or modelName:find(tName) or tName:find(modelName)) then
                                return true, plr
                            elseif not eggName then
                                return true, plr
                            end
                        end
                    end
                end
            end
            local backpack = plr:FindFirstChild("Backpack")
            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") then
                        local tName = tool.Name:lower()
                        if tName:find("area egg") or tName:find("carryareaegg") or
                           tName == "egg" or tName:find("^egg_") or tName:find("_egg$") then
                            if eggName and (tName:find(eggName) or modelName:find(tName) or tName:find(modelName)) then
                                return true, plr
                            elseif not eggName then
                                return true, plr
                            end
                        end
                    end
                end
            end
        end
    end
    local prompt = getModelPrompt(model)
    if prompt and prompt.Enabled == false then return true, nil end
    local carrierAttr = model:GetAttribute("Carrier")
    if carrierAttr and carrierAttr ~= player.UserId then
        return true, Players:GetPlayerByUserId(carrierAttr)
    end
    return false, nil
end

local carriedEggsCache = {}
local lastCarryCheckTime = 0
local function refreshCarriedEggsCache()
    local now = tick()
    if now - lastCarryCheckTime < 0.3 then return end
    lastCarryCheckTime = now
    carriedEggsCache = {}
    for uid in pairs(trackedEggs) do
        local carried, carrier = isEggCarriedByOtherPlayer(uid)
        if carried then carriedEggsCache[uid] = carrier end
    end
end

local function findPromptNearPosition(position, maxDist)
    maxDist = maxDist or 25
    local bestPrompt, bestDist = nil, maxDist
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name == "CarryAreaEgg" and obj.Enabled then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (parent.Position - position).Magnitude
                if dist < bestDist then bestDist = dist; bestPrompt = obj end
            end
        end
    end
    return bestPrompt
end

-- ============ Best/Nearest Finding ============
local function findBestEgg()
    local bestUid, bestScore = nil, -1
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position or nil
    refreshCarriedEggsCache()
    for uid, data in pairs(trackedEggs) do
        if data.model and data.model.Parent then
            if carriedEggsCache[uid] then continue end
            local passesFilter = true
            if eggRarityFilter ~= "All" then
                local rarityName = getEggRarityName(data.record)
                if rarityName:lower() ~= eggRarityFilter:lower() then passesFilter = false end
            end
            if not passesFilter then continue end
            local s = scoreEgg(data)
            local isBetter = false
            if s > bestScore then isBetter = true
            elseif s == bestScore and playerPos then
                local bp = data.basePart or getModelBasePart(data.model)
                if bp then
                    local dist = (playerPos - bp.Position).Magnitude
                    local bestData = bestUid and trackedEggs[bestUid]
                    local bestBp = bestData and (bestData.basePart or getModelBasePart(bestData.model))
                    local bestDist = bestBp and (playerPos - bestBp.Position).Magnitude or math.huge
                    if dist < bestDist then isBetter = true end
                end
            end
            if isBetter then bestScore = s; bestUid = uid end
        end
    end
    return bestUid, bestScore
end

local function findNearestEgg()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local playerPos = hrp.Position
    local nearestUid, nearestDist = nil, math.huge
    refreshCarriedEggsCache()
    for uid, data in pairs(trackedEggs) do
        if data.model and data.model.Parent then
            if carriedEggsCache[uid] then continue end
            local bp = data.basePart or getModelBasePart(data.model)
            if bp then
                local dist = (playerPos - bp.Position).Magnitude
                if dist < nearestDist then nearestDist = dist; nearestUid = uid end
            end
        end
    end
    return nearestUid, nearestDist
end

local function findBiggestEgg()
    refreshCarriedEggsCache()
    local biggestUid, biggestSize = nil, -1
    for uid, data in pairs(trackedEggs) do
        if data.model and data.model.Parent then
            if carriedEggsCache[uid] then continue end
            local size = getModelSizeScore(data.model)
            if size > biggestSize then biggestSize = size; biggestUid = uid end
        end
    end
    return biggestUid, biggestSize
end

local function findNearestBigEgg()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local playerPos = hrp.Position
    local nearestUid, nearestDist = nil, math.huge
    refreshCarriedEggsCache()
    for uid, data in pairs(trackedEggs) do
        if data.model and data.model.Parent then
            if carriedEggsCache[uid] then continue end
            local bp = data.basePart or getModelBasePart(data.model)
            if bp then
                local dist = (playerPos - bp.Position).Magnitude
                if dist < nearestDist then nearestDist = dist; nearestUid = uid end
            end
        end
    end
    return nearestUid, nearestDist
end

-- ============ ESP ============
local function clearAll()
    for uid, data in pairs(trackedEggs) do
        pcall(function() if data.highlight then data.highlight:Destroy() end end)
    end
    trackedEggs = {}; modelCache = {}; promptCache = {}
    bestEggUid = nil
    pcall(function() if espBeam then espBeam:Destroy() end end)
    pcall(function() if espPlayerAttach then espPlayerAttach:Destroy() end end)
    pcall(function() if espEggAttach then espEggAttach:Destroy() end end)
    espBeam, espPlayerAttach, espEggAttach = nil, nil, nil
end

local function ensureHighlight(uid)
    local data = trackedEggs[uid]
    if not data then return end
    local model = data.model
    if not model or not model.Parent then return end
    if data.highlight and data.highlight.Parent then
        pcall(function()
            local color = getRarityColor(data.record.AssetCategory)
            data.highlight.FillColor = color
            data.highlight.OutlineColor = color
        end)
        return
    end
    pcall(function()
        local color = getRarityColor(data.record.AssetCategory)
        local hl = Instance.new("Highlight")
        hl.Name = "shouyuhubEggESP"
        hl.Adornee = model
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = color
        hl.OutlineColor = color
        hl.Parent = model
        data.highlight = hl
    end)
end

local function updateBeam()
    if not espEnabled or not bestEggUid then return end
    local data = trackedEggs[bestEggUid]
    if not data then return end
    local model = data.model
    if not model or not model.Parent then return end
    local basePart = data.basePart
    if not basePart or not basePart.Parent then
        basePart = getModelBasePart(model)
        data.basePart = basePart
        if not basePart then return end
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not espPlayerAttach or espPlayerAttach.Parent ~= hrp then
        pcall(function() if espPlayerAttach then espPlayerAttach:Destroy() end end)
        espPlayerAttach = Instance.new("Attachment")
        espPlayerAttach.Name = "BestEggESP_PlayerAttachment"
        espPlayerAttach.Parent = hrp
        if espBeam then espBeam.Attachment0 = espPlayerAttach end
    end
    if not espEggAttach or espEggAttach.Parent ~= basePart then
        pcall(function() if espEggAttach then espEggAttach:Destroy() end end)
        espEggAttach = Instance.new("Attachment")
        espEggAttach.Name = "BestEggESP_EggAttachment"
        espEggAttach.Parent = basePart
        if espBeam then espBeam.Attachment1 = espEggAttach end
    end
    if not espBeam or espBeam.Parent == nil then
        espBeam = Instance.new("Beam")
        espBeam.Name = "BestEggESP_Tracer"
        espBeam.FaceCamera = true
        espBeam.LightEmission = 1
        espBeam.LightInfluence = 0
        espBeam.Width0 = 0.18; espBeam.Width1 = 0.18
        espBeam.Transparency = NumberSequence.new(0)
        espBeam.Segments = 12
        espBeam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        espBeam.Parent = hrp
        espBeam.Attachment0 = espPlayerAttach
        espBeam.Attachment1 = espEggAttach
    end
end

local function syncEggs()
    if not EggState or not EggState.ReadFieldEggs then return end
    local success, snapshot = pcall(EggState.ReadFieldEggs, EggState)
    if not success or not snapshot or not snapshot.Records then clearAll(); return end
    local currentUids = {}
    for _, record in ipairs(snapshot.Records) do
        currentUids[record.Uid] = true
        if not trackedEggs[record.Uid] then
            trackedEggs[record.Uid] = {record = record, highlight = nil, model = nil, basePart = nil}
        else
            trackedEggs[record.Uid].record = record
        end
    end
    for uid in pairs(trackedEggs) do
        if not currentUids[uid] then
            pcall(function() if trackedEggs[uid].highlight then trackedEggs[uid].highlight:Destroy() end end)
            trackedEggs[uid] = nil
            modelCache[uid] = nil
            if bestEggUid == uid then bestEggUid = nil end
        end
    end
    for uid, data in pairs(trackedEggs) do
        if not data.model or not data.model.Parent then
            local model = findEggModel(uid)
            if model then data.model = model; data.basePart = getModelBasePart(model) end
        end
        if data.model and data.model.Parent then
            local passesFilter = true
            if eggRarityFilter ~= "All" then
                local rarityName = getEggRarityName(data.record)
                if rarityName:lower() ~= eggRarityFilter:lower() then passesFilter = false end
            end
            if passesFilter then ensureHighlight(uid)
            else
                pcall(function()
                    if data.highlight then data.highlight:Destroy(); data.highlight = nil end
                end)
            end
        end
    end
    local newBest = findBestEgg()
    if newBest ~= bestEggUid then
        bestEggUid = newBest
        pcall(function() if espEggAttach then espEggAttach:Destroy() end end)
        espEggAttach = nil
    end
end

-- ============ Steal State ============
local StealState = {
    IDLE = "IDLE", MOVING_TO_EGG = "MOVING_TO_EGG", COLLECTING = "COLLECTING",
    RETURNING = "RETURNING", DEPOSITING = "DEPOSITING", WAITING_RESET = "WAITING_RESET",
    WAITING = "WAITING", RAGDOLLED_RUSH = "RAGDOLLED_RUSH",
    MOVING_TO_BEST = "MOVING_TO_BEST", COLLECTING_BEST = "COLLECTING_BEST",
}

local currentStealState = StealState.IDLE
local activeTween = nil
local targetEggUid = nil
local safePosition = Vector3.new(536.423340, 70.333313, -364.236969)
local antiTrapPosition = Vector3.new(806, 167, -407)

local function getReturnPosition()
    if AntiTrapEnabled then
        return Vector3.new(safePosition.X, antiTrapPosition.Y, safePosition.Z)
    end
    return safePosition
end

local virtualAnchor = Instance.new("Part")
virtualAnchor.Anchored = true
virtualAnchor.CanCollide = false
virtualAnchor.Transparency = 1
virtualAnchor.Size = Vector3.new(1, 1, 1)
virtualAnchor.Parent = workspace.Terrain

local currentConnection = nil
local tweenCancelled = false

local AreaEggResetWall = safeRequire(ReplicatedStorage, "Client", "AreaEggResetWall")
local EggStateModule = safeRequire(ReplicatedStorage, "Client", "EggState")

local rawCarryState = false
if EggStateModule and EggStateModule.CarryChanged then
    pcall(function()
        EggStateModule.CarryChanged:Connect(function(carryData)
            rawCarryState = carryData and carryData.IsCarrying == true
        end)
    end)
end

local function cancelActiveTween()
    tweenCancelled = true
    if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
    if currentConnection then pcall(function() currentConnection:Disconnect() end); currentConnection = nil end
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function tweenCharacterTo(targetPos, speed)
    cancelActiveTween()
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local dist = (hrp.Position - targetPos).Magnitude
    if dist < 3 then return true end
    tweenCancelled = false
    virtualAnchor.CFrame = hrp.CFrame
    local duration = math.max(dist / speed, 0.03)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local targetCFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.atan2(
        targetPos.X - hrp.Position.X, targetPos.Z - hrp.Position.Z), 0)
    activeTween = TweenService:Create(virtualAnchor, tweenInfo, {CFrame = targetCFrame})
    local completed = false
    currentConnection = RunService.Heartbeat:Connect(function()
        if not completed and not tweenCancelled and hrp and hrp.Parent and virtualAnchor and virtualAnchor.Parent then
            hrp.CFrame = virtualAnchor.CFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    activeTween.Completed:Connect(function()
        completed = true
        if currentConnection then pcall(function() currentConnection:Disconnect() end); currentConnection = nil end
        if hrp and hrp.Parent and not tweenCancelled then hrp.CFrame = targetCFrame end
        activeTween = nil
    end)
    activeTween:Play()
    return true
end

local function isAtPosition(pos, threshold)
    threshold = th
-- ============ Automation ============
local shouyuhubAutomation = {
    Remotes = nil, Save = nil, EggState = nil, Assets = nil,
    Trails = nil, PlotState = nil, Treadmills = nil,
    initialized = false, loops = {},
    autoPlaceAll = false, autoHatch = false, autoClaim = false,
    autoBaseUpgrade = false, autoTreadmillUpgrade = false,
    autoBuyTrail = false, autoAbyss = false,
}

local function autoRequire(parent, childName)
    local child = parent and parent:FindFirstChild(childName)
    if not child or not child:IsA("ModuleScript") then return nil end
    local ok, result = pcall(require, child)
    return ok and result or nil
end

local function initAutomation()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local client = ReplicatedStorage:FindFirstChild("Client")
    local data = ReplicatedStorage:FindFirstChild("Data")
    if not shared or not client or not data then return false end
    shouyuhubAutomation.Remotes = autoRequire(shared, "Remotes")
    shouyuhubAutomation.Save = autoRequire(shared, "Save")
    shouyuhubAutomation.EggState = autoRequire(client, "EggState")
    shouyuhubAutomation.Assets = autoRequire(data, "Assets")
    shouyuhubAutomation.Trails = autoRequire(data, "Trails")
    shouyuhubAutomation.PlotState = autoRequire(client, "PlotState")
    shouyuhubAutomation.Treadmills = autoRequire(data, "Treadmills")
    shouyuhubAutomation.initialized =
        shouyuhubAutomation.Remotes ~= nil and
        shouyuhubAutomation.Save ~= nil and
        shouyuhubAutomation.EggState ~= nil
    return shouyuhubAutomation.initialized
end

local function ensureAutomation()
    if shouyuhubAutomation.initialized then return true end
    return initAutomation()
end

local function invokeRemote(remote, ...)
    if not remote then return false, nil end
    local args = table.pack(...)
    local ok, a, b, c = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
    return ok, a, b, c
end

local function fireRemote(remote, ...)
    if not remote then return false end
    local args = table.pack(...)
    local ok = pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
    return ok
end

local function automationSave()
    if not ensureAutomation() or not shouyuhubAutomation.Save then return nil end
    local ok, save = pcall(shouyuhubAutomation.Save.Get, player)
    return ok and save or nil
end

local function resolveAutomationSlot()
    if not ensureAutomation() then return nil end
    local r = shouyuhubAutomation.Remotes
    if not (r and r.Homestead and r.Homestead.AskState) then return nil end
    local ok, state = invokeRemote(r.Homestead.AskState)
    if not ok or type(state) ~= "table" or type(state.OwnersBySlot) ~= "table" then return nil end
    for slot, userId in pairs(state.OwnersBySlot) do
        if tostring(userId) == tostring(player.UserId) then return tostring(slot) end
    end
    return nil
end

local function getAutomationPlacementFrames()
    if not ensureAutomation() or not shouyuhubAutomation.PlotState then return {} end
    local ok, plot = pcall(shouyuhubAutomation.PlotState.ResolvePlot)
    if not ok or type(plot) ~= "table" or not plot.PetArea or not plot.CenterPoint then return {} end
    local petArea, center = plot.PetArea, plot.CenterPoint
    if not petArea.Size or not center.CFrame then return {} end
    local frames = {}
    for x = -petArea.Size.X * 0.5 + 5, petArea.Size.X * 0.5 - 5, 7 do
        for z = -petArea.Size.Z * 0.5 + 5, petArea.Size.Z * 0.5 - 5, 7 do
            local world = petArea.CFrame:PointToWorldSpace(Vector3.new(x, 1, z))
            table.insert(frames, center.CFrame:ToObjectSpace(CFrame.new(world)))
        end
    end
    return frames
end

local function getAutomationEggs()
    local save = automationSave()
    local inventory = save and save.EggInventory
    local result = {}
    if type(inventory) ~= "table" then return result end
    for uid, egg in pairs(inventory) do
        if type(uid) == "string" and type(egg) == "table" and egg.Placement == nil then
            table.insert(result, uid)
        end
    end
    return result
end

local automationPlaceIndex = 1
local function runAutomationPlaceAll()
    if not ensureAutomation() or not shouyuhubAutomation.EggState then return 0 end
    local eggs = getAutomationEggs()
    local frames = getAutomationPlacementFrames()
    if #eggs == 0 or #frames == 0 then return 0 end
    local placed = 0
    for _, uid in ipairs(eggs) do
        pcall(function()
            if shouyuhubAutomation.EggState.WearEggTool then
                shouyuhubAutomation.EggState.WearEggTool(uid)
            end
        end)
        task.wait(0.12)
        local didPlace = false
        for offset = 0, #frames - 1 do
            local index = ((automationPlaceIndex + offset - 1) % #frames) + 1
            local ok, result = pcall(function()
                return shouyuhubAutomation.EggState.PlantEgg(uid, frames[index])
            end)
            if ok and result == true then
                automationPlaceIndex = index + 1
                didPlace = true
                placed = placed + 1
                task.wait(0.2)
                break
            end
        end
        if not didPlace then break end
    end
    return placed
end

local function runAutomationHatch()
    if not ensureAutomation() or not shouyuhubAutomation.EggState then return 0 end
    local save = automationSave()
    if not save then return 0 end
    local done = 0
    for uid, egg in pairs(save.EggInventory or {}) do
        if type(uid) == "string" and type(egg) == "table" then
            local ready = true
            if egg.Placement == nil and shouyuhubAutomation.EggState.PlantEgg then
                local slot = resolveAutomationSlot()
                local plots = Workspace:FindFirstChild("Plots")
                local center = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local pos = center and center.Position or Vector3.zero
                if plots and slot and plots:FindFirstChild(slot) then
                    local plot = plots[slot]
                    local point = plot:FindFirstChild("CenterPoint") or plot:FindFirstChild("PlotSign")
                    if point and point:IsA("BasePart") then pos = point.Position end
                end
                pcall(shouyuhubAutomation.EggState.PlantEgg, uid, CFrame.new(pos + Vector3.new(math.random(-6,6), 0, math.random(-6,6))))
                task.wait(0.15)
            elseif shouyuhubAutomation.EggState.IsReadyToHatch then
                local okReady, resultReady = pcall(shouyuhubAutomation.EggState.IsReadyToHatch, uid)
                ready = okReady and resultReady == true
            end
            if ready and shouyuhubAutomation.EggState.BeginHatch then
                local okHatch, started = pcall(shouyuhubAutomation.EggState.BeginHatch, uid)
                if okHatch and started == true then
                    if shouyuhubAutomation.EggState.FinishHatch then
                        pcall(shouyuhubAutomation.EggState.FinishHatch, uid)
                    end
                    done = done + 1
                    task.wait(0.2)
                end
            end
        end
    end
    return done
end

local function runAutomationClaim()
    if not ensureAutomation() then return 0 end
    local r, claimed = shouyuhubAutomation.Remotes, 0
    if r.Codex and r.Codex.AskRedeemAll then
        local ok, result = invokeRemote(r.Codex.AskRedeemAll)
        if ok and result == true then claimed = claimed + 1 end
    end
    if r.Codex and r.Codex.AskRedeemLimitedEgg then
        local ok, result = invokeRemote(r.Codex.AskRedeemLimitedEgg)
        if ok and result == true then claimed = claimed + 1 end
    end
    if r.GroupPerk and r.GroupPerk.RedeemPerk then
        local ok, result = invokeRemote(r.GroupPerk.RedeemPerk)
        if ok and result == true then claimed = claimed + 1 end
    end
    if r.AwayEarnings and r.AwayEarnings.FetchSummary and r.AwayEarnings.AskCollect then
        local okSummary, summary = invokeRemote(r.AwayEarnings.FetchSummary)
        if okSummary and type(summary) == "table" and (tonumber(summary.ClaimableAmount) or 0) > 0 then
            local okCollect = invokeRemote(r.AwayEarnings.AskCollect)
            if okCollect then claimed = claimed + 1 end
        end
    end
    return claimed
end

local function runAutomationBaseUpgrade()
    if not ensureAutomation() then return false end
    local r = shouyuhubAutomation.Remotes
    return r and r.Homestead and r.Homestead.AskBaseTierRaise
        and fireRemote(r.Homestead.AskBaseTierRaise) or false
end

local function runAutomationTreadmillUpgrade()
    if not ensureAutomation() then return false end
    local r, tm = shouyuhubAutomation.Remotes, shouyuhubAutomation.Treadmills
    if not (r and r.Treadmill and r.Treadmill.AskTierRaise and tm and type(tm.GetByUpgradeLevel) == "function") then
        return false
    end
    local save = automationSave()
    if not save then return false end
    local level = tonumber(save.TreadmillUpgradeLevel) or 0
    local okCfg, nextCfg = pcall(tm.GetByUpgradeLevel, level + 1)
    if not okCfg or type(nextCfg) ~= "table" or not nextCfg._id then return false end
    if (tonumber(save.Money) or 0) < (tonumber(nextCfg.Price) or math.huge) then return false end
    local ok, result = invokeRemote(r.Treadmill.AskTierRaise, nextCfg._id)
    return ok and result == true
end

local TRAIL_VALUES, TRAIL_ID, TRAIL_PRICE = {}, {}, {}
local function refreshAutomationTrails()
    table.clear(TRAIL_VALUES); table.clear(TRAIL_ID); table.clear(TRAIL_PRICE)
    local trails = shouyuhubAutomation.Trails
    local directory = trails and (trails.Directory or trails.Trails or trails)
    local ordered = {}
    if type(directory) == "table" then
        for id, data in pairs(directory) do
            if type(data) == "table" and type(data.DisplayName) == "string" then
                table.insert(ordered, {id = id, name = data.DisplayName, price = tonumber(data.Price) or 0})
            end
        end
    end
    table.sort(ordered, function(a, b) return a.price < b.price end)
    for _, entry in ipairs(ordered) do
        table.insert(TRAIL_VALUES, entry.name)
        TRAIL_ID[entry.name] = entry.id
        TRAIL_PRICE[entry.name] = entry.price
    end
end

local function runAutomationBuyTrail(selected)
    if not ensureAutomation() then return 0 end
    local save = automationSave()
    local r = shouyuhubAutomation.Remotes
    local buyRemote = r and r.Trailwear and r.Trailwear.AskPurchase
    if not save or not buyRemote or type(selected) ~= "table" then return 0 end
    local inventory = save.TrailInventory or {}
    local bought = 0
    for _, name in ipairs(TRAIL_VALUES) do
        if selected[name] then
            local id = TRAIL_ID[name]
            local price = TRAIL_PRICE[name] or 0
            if id and not inventory[id] and (tonumber(save.Money) or 0) >= price then
                local ok, result = invokeRemote(buyRemote, id)
                if ok and result ~= false then bought = bought + 1 end
                task.wait(0.3)
                save = automationSave() or save
                inventory = save.TrailInventory or inventory
            end
        end
    end
    return bought
end

local function automationEnterAbyss()
    local net = ReplicatedStorage:FindFirstChild("Packages")
        and ReplicatedStorage.Packages:FindFirstChild("Networking")
    local remote = net and net:FindFirstChild("RF/BossEvent/AskEnter")
    if not remote then return false, "Abyss entry remote not found" end
    local ok, accepted, msg = pcall(function() return remote:InvokeServer() end)
    if not ok then return false, tostring(accepted) end
    if accepted == true then return true, "Entering the Abyss World" end
    return false, tostring(msg or "Boss entry refused")
end

-- ============ Speed / Fly / Anti ============
local newBypassConnections = {}
local newBypassCharConnection = nil

local GCHookBypass = {
    RunService = RunService, Players = Players,
    speedconn = nil, hookedfunc3 = nil,
}

function GCHookBypass:collectgarbage()
    local s, r = pcall(function() return getgc() end)
    if s and r then return r end
    return warn("failed to get garbage: "..tostring(r))
end

function GCHookBypass:safehook(f, c)
    local s, r = pcall(function() return hookfunction(f, newlclosure(c)) end)
    if s and r then return r end
    return warn("failed to hook function: "..tostring(r))
end

function GCHookBypass:findfunction(nups, linedefined)
    local s, r = pcall(function()
        for _, f in next, self:collectgarbage() do
            if typeof(f) == 'function' and islclosure(f) then
                local upvs = debug.getupvalues(f)
                local line = debug.info(f, "l")
                if upvs and #upvs == nups and line == linedefined then
                    if nups == 10 then
                        local t = debug.getupvalue(f, 3)
                        if typeof(t) == "table" and rawget(t, "Humanoid") then return f end
                    else return f end
                end
            end
        end
        return nil
    end)
    if s and r then return r end
    return nil
end

function GCHookBypass:init()
    self.LocalPlayer = self.Players.LocalPlayer
    if not self.LocalPlayer then return warn("failed to get localplayer") end
    if not getgc then self.LocalPlayer:Kick("UNSUPPORT EXECUTOR MISSING getgc") end
    if not hookfunction then self.LocalPlayer:Kick("UNSUPPORT EXECUTOR MISSING hookfunction") end
    if not islclosure then self.LocalPlayer:Kick("UNSUPPORT EXECUTOR MISSING islclosure") end
    local func3 = self:findfunction(19, 3)
    if not func3 then return warn("failed to get function 3") end
    local v7 = debug.getupvalue(func3, 2)
    if not v7 then return warn("failed to get v7") end
    self.hookedfunc3 = self:safehook(v7, function(p1, p2)
        if p2 and typeof(p2) == "table" then setmetatable(p2, {}) end
        return self.hookedfunc3(p1, p2)
    end)
    self.speedconn = self.RunService.Heartbeat:Connect(function()
        local char = self.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
        hum.WalkSpeed = DesiredSpeed
    end)
    warn("[GC Hook Bypass] Initialized")
    return true
end

function GCHookBypass:stop()
    if self.speedconn then pcall(function() self.speedconn:Disconnect() end); self.speedconn = nil end
    warn("[GC Hook Bypass] Stopped")
end

local function forceWalkSpeedNewBypass(humanoid)
    if newBypassConnections[humanoid] then
        pcall(function() newBypassConnections[humanoid]:Disconnect() end)
    end
    newBypassConnections[humanoid] = RunService.Heartbeat:Connect(function()
        if humanoid and humanoid.Parent then
            if humanoid.WalkSpeed ~= DesiredSpeed then humanoid.WalkSpeed = DesiredSpeed end
        else
            if newBypassConnections[humanoid] then
                newBypassConnections[humanoid]:Disconnect()
                newBypassConnections[humanoid] = nil
            end
        end
    end)
end

local function applyNewBypass(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local camera = workspace.CurrentCamera
    local animateScript = character:FindFirstChild("Animate")
    local jumpPower = humanoid.JumpPower
    local jumpHeight = humanoid.JumpHeight
    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    if animateScript and animateScript:IsA("LocalScript") then animateScript.Disabled = true end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in next, animator:GetPlayingAnimationTracks() do track:Stop(0) end
    end
    humanoid.Archivable = true
    local newHumanoid = humanoid:Clone()
    for _, child in next, newHumanoid:GetChildren() do
        if child:IsA("Animator") then child:Destroy() end
    end
    humanoid.Name = "_OldHumanoid"
    newHumanoid.Name = "Humanoid"
    newHumanoid.Parent = character
    local newAnimator = Instance.new("Animator")
    newAnimator.Parent = newHumanoid
    newHumanoid.WalkSpeed = DesiredSpeed
    newHumanoid.JumpPower = jumpPower
    newHumanoid.JumpHeight = jumpHeight
    newHumanoid.MaxHealth = maxHealth
    newHumanoid.Health = math.min(health, maxHealth)
    if camera then camera.CameraSubject = newHumanoid end
    humanoid:Destroy()
    if animateScript and animateScript:IsA("LocalScript") then
        task.wait()
        animateScript.Disabled = false
        task.defer(function()
            if animateScript.Parent then
                animateScript.Disabled = true
                task.wait()
                animateScript.Disabled = false
            end
        end)
    end
    task.defer(function()
        if newHumanoid.Parent then newHumanoid:ChangeState(Enum.HumanoidStateType.Running) end
    end)
    forceWalkSpeedNewBypass(newHumanoid)
    CurrentHumanoid = newHumanoid
    return newHumanoid
end

local function setupNewBypass(character)
    character:WaitForChild("Humanoid")
    task.wait()
    applyNewBypass(character)
end

local function startHumanoidCloneBypass()
    if newBypassCharConnection then
        pcall(function() newBypassCharConnection:Disconnect() end)
    end
    newBypassCharConnection = player.CharacterAdded:Connect(function(char)
        if SpeedEnabled then task.spawn(setupNewBypass, char) end
    end)
    if player.Character then task.spawn(setupNewBypass, player.Character) end
end

local function stopHumanoidCloneBypass()
    for hum, conn in pairs(newBypassConnections) do
        pcall(function() conn:Disconnect() end)
    end
    newBypassConnections = {}
    if newBypassCharConnection then
        pcall(function() newBypassCharConnection:Disconnect() end)
        newBypassCharConnection = nil
    end
end

local function startNewBypass()
    if SpeedBypassMethod == "GC Hook Bypass" then
        GCHookBypass:init()
    else
        startHumanoidCloneBypass()
    end
end

local function stopNewBypass()
    if SpeedBypassMethod == "GC Hook Bypass" then
        GCHookBypass:stop()
    else
        stopHumanoidCloneBypass()
    end
end

local function startFly()
    if FlyConnection then FlyConnection:Disconnect(); FlyConnection = nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy(); FlyBodyVelocity = nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro = nil end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyGyro.CFrame = hrp.CFrame
    FlyBodyGyro.P = 9e4
    FlyBodyGyro.Parent = hrp
    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlyBodyVelocity.Parent = hrp
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not FlyEnabled then return end
        if not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then return end
        local currentHrp = player.Character.HumanoidRootPart
        local cam = workspace.CurrentCamera
        local direction = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + cam.CFrame.RightVector end
        if Us
          -- ============ Obsidian UI Construction ============
local Window = Library:CreateWindow({
    Title = "shouyuhub",
    Footer = "Steal An Egg",
    Center = true,
    AutoShow = true,
    ShowMobileButtons = false,
})

-- ============ Tabs ============
local MainTab = Window:AddTab({ Name = "Main" })
local EggTab = Window:AddTab({ Name = "Egg Steal" })
local AutomationTab = Window:AddTab({ Name = "Automation" })
local SellTab = Window:AddTab({ Name = "Auto Sell" })
local SettingsTab = Window:AddTab({ Name = "Settings" })

-- ============ Main Tab ============
local MoveGroup = MainTab:AddLeftGroupbox("Movement")
MoveGroup:AddInput("SpeedInput", {
    Text = "Walk Speed",
    Default = tostring(DesiredSpeed),
    Numeric = true,
    Callback = function(v)
        local num = tonumber(v)
        if num then
            DesiredSpeed = num
            Memory.DesiredSpeed = num
            if SpeedEnabled and CurrentHumanoid then
                pcall(function() CurrentHumanoid.WalkSpeed = DesiredSpeed end)
            end
        end
    end
})
MoveGroup:AddDropdown("BypassDropdown", {
    Text = "Speed Bypass Method",
    Values = {"Humanoid Clone", "GC Hook Bypass"},
    Default = SpeedBypassMethod,
    Callback = function(v)
        SpeedBypassMethod = v
        Memory.SpeedBypassMethod = v
        if SpeedEnabled then
            stopNewBypass()
            task.wait(0.1)
            startNewBypass()
        end
    end
})
MoveGroup:AddToggle("SpeedToggle", {
    Text = "Speed Hack",
    Default = SpeedEnabled,
    Callback = function(v)
        SpeedEnabled = v
        Memory.SpeedEnabled = v
        if v then startNewBypass()
        else
            stopNewBypass()
            if CurrentHumanoid then pcall(function() CurrentHumanoid.WalkSpeed = 16 end) end
        end
    end
})
MoveGroup:AddInput("FlyInput", {
    Text = "Fly Speed",
    Default = tostring(FlySpeed),
    Numeric = true,
    Callback = function(v)
        local num = tonumber(v)
        if num then FlySpeed = num; Memory.FlySpeed = num end
    end
})
MoveGroup:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = FlyEnabled,
    Callback = function(v)
        FlyEnabled = v
        Memory.FlyEnabled = v
        if v then startFly() else stopFly() end
    end
})

local CombatGroup = MainTab:AddRightGroupbox("Combat / Protection")
CombatGroup:AddToggle("AntiKB", {
    Text = "Anti Knockback",
    Default = AntiKnockbackEnabled,
    Callback = function(v) AntiKnockbackEnabled = v; Memory.AntiKnockbackEnabled = v end
})
CombatGroup:AddToggle("AntiRagdoll", {
    Text = "Anti Ragdoll",
    Default = AntiRagdollEnabled,
    Callback = function(v) AntiRagdollEnabled = v; Memory.AntiRagdollEnabled = v end
})
CombatGroup:AddToggle("InstantAccel", {
    Text = "Smooth Movement",
    Default = InstantAccelerationEnabled,
    Callback = function(v) InstantAccelerationEnabled = v; Memory.InstantAccelerationEnabled = v end
})
CombatGroup:AddToggle("AntiRejoin", {
    Text = "Anti Rejoin / Kick",
    Default = AntiRejoinEnabled,
    Callback = function(v) AntiRejoinEnabled = v; Memory.AntiRejoinEnabled = v end
})

-- ============ Egg Steal Tab ============
local StealGroup = EggTab:AddLeftGroupbox("Auto Steal")
StealGroup:AddToggle("EspToggle", {
    Text = "Best Egg ESP",
    Default = espEnabled,
    Callback = function(v)
        espEnabled = v
        Memory.EggEspEnabled = v
        if v then
            syncEggs()
            if not espLoopRunning then
                espLoopRunning = true
                task.spawn(function()
                    while espEnabled do syncEggs(); task.wait(0.5) end
                    espLoopRunning = false
                end)
            end
        else clearAll() end
    end
})
StealGroup:AddToggle("AutoStealToggle", {
    Text = "Auto Steal Best",
    Default = autoStealEnabled,
    Callback = function(v)
        autoStealEnabled = v
        Memory.EggAutoStealEnabled = v
        if v then
            if bigOnlyAutoStealEnabled then
                bigOnlyAutoStealEnabled = false; Memory.EggBigOnly = false; eggBigOnly = false; bigOnlyLoopRunning = false
                cancelActiveTween(); resetCarryDetection()
            end
            if not autoLoopRunning then
                autoLoopRunning = true
                task.spawn(runAutoStealBest)
            end
        else
            cancelActiveTween()
            currentStealState = StealState.IDLE
            resetCarryDetection()
        end
    end
})
StealGroup:AddToggle("BigOnlyToggle", {
    Text = "Big Eggs Only",
    Default = eggBigOnly,
    Callback = function(v)
        eggBigOnly = v
        Memory.EggBigOnly = v
        if v then
            if autoStealEnabled then
                autoStealEnabled = false; Memory.EggAutoStealEnabled = false; autoLoopRunning = false
                cancelActiveTween(); resetCarryDetection()
            end
            bigOnlyAutoStealEnabled = true
            if not bigOnlyLoopRunning then
                bigOnlyLoopRunning = true
                task.spawn(runBigOnlyAutoSteal)
            end
        else
            bigOnlyAutoStealEnabled = false
            cancelActiveTween(); resetCarryDetection()
        end
        syncEggs()
    end
})

local FilterGroup = EggTab:AddRightGroupbox("Filters")
FilterGroup:AddDropdown("RarityFilter", {
    Text = "Rarity Filter",
    Values = {"All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine", "Prismatic", "Cosmic"},
    Default = eggRarityFilter,
    Callback = function(v) eggRarityFilter = v; Memory.EggRarityFilter = v; syncEggs() end
})
FilterGroup:AddToggle("AntiTrap", {
    Text = "Anti Trap",
    Default = AntiTrapEnabled,
    Callback = function(v) AntiTrapEnabled = v; Memory.AntiTrapEnabled = v end
})

-- ============ Automation Tab ============
local AutoGroup = AutomationTab:AddLeftGroupbox("Automation")
AutoGroup:AddToggle("PlaceAll", {
    Text = "Auto Place All",
    Default = Memory.AutoPlaceAll or false,
    Callback = function(v)
        shouyuhubAutomation.autoPlaceAll = v
        Memory.AutoPlaceAll = v
        if v and not shouyuhubAutomation.loops.place then
            shouyuhubAutomation.loops.place = true
            task.spawn(function()
                while shouyuhubAutomation.autoPlaceAll do
                    local count = 0
                    pcall(function() count = runAutomationPlaceAll() end)
                    task.wait(count > 0 and 0.8 or 1.5)
                end
                shouyuhubAutomation.loops.place = false
            end)
        end
    end
})
AutoGroup:AddToggle("AutoHatch", {
    Text = "Auto Hatch",
    Default = Memory.AutoHatch or false,
    Callback = function(v)
        shouyuhubAutomation.autoHatch = v
        Memory.AutoHatch = v
        if v and not shouyuhubAutomation.loops.hatch then
            shouyuhubAutomation.loops.hatch = true
            task.spawn(function()
                while shouyuhubAutomation.autoHatch do pcall(runAutomationHatch); task.wait(1.2) end
                shouyuhubAutomation.loops.hatch = false
            end)
        end
    end
})
AutoGroup:AddToggle("AutoClaim", {
    Text = "Auto Claim Index",
    Default = Memory.AutoClaim or false,
    Callback = function(v)
        shouyuhubAutomation.autoClaim = v
        Memory.AutoClaim = v
        if v and not shouyuhubAutomation.loops.claim then
            shouyuhubAutomation.loops.claim = true
            task.spawn(function()
                while shouyuhubAutomation.autoClaim do pcall(runAutomationClaim); task.wait(30) end
                shouyuhubAutomation.loops.claim = false
            end)
        end
    end
})
AutoGroup:AddToggle("AutoAbyss", {
    Text = "Auto Enter Abyss World",
    Default = Memory.AutoEnterAbyss or false,
    Callback = function(v)
        shouyuhubAutomation.autoAbyss = v
        Memory.AutoEnterAbyss = v
        if v and not shouyuhubAutomation.loops.abyss then
            shouyuhubAutomation.loops.abyss = true
            task.spawn(function()
                while shouyuhubAutomation.autoAbyss do
                    pcall(function()
                        if player:GetAttribute("InBossArena") ~= true then
                            local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
                            local snap = net and net:FindFirstChild("RF/BossEvent/AskSnapshot")
                            local shouldEnter = true
                            if snap then
                                local okSnap, s = pcall(snap.InvokeServer, snap)
                                if okSnap and type(s) == "table" and s.Open ~= nil then shouldEnter = s.Open == true end
                            end
                            if shouldEnter then automationEnterAbyss() end
                        end
                    end)
                    task.wait(2)
                end
                shouyuhubAutomation.loops.abyss = false
            end)
        end
    end
})

local UpGroup = AutomationTab:AddRightGroupbox("Upgrades")
UpGroup:AddToggle("UpBase", {
    Text = "Auto Upgrade Base",
    Default = Memory.AutoUpgradeBase or false,
    Callback = function(v)
        shouyuhubAutomation.autoBaseUpgrade = v
        Memory.AutoUpgradeBase = v
        if v and not shouyuhubAutomation.loops.base then
            shouyuhubAutomation.loops.base = true
            task.spawn(function()
                while shouyuhubAutomation.autoBaseUpgrade do pcall(runAutomationBaseUpgrade); task.wait(15) end
                shouyuhubAutomation.loops.base = false
            end)
        end
    end
})
UpGroup:AddToggle("UpTread", {
    Text = "Auto Upgrade Treadmill",
    Default = Memory.AutoUpgradeTreadmill or false,
    Callback = function(v)
        shouyuhubAutomation.autoTreadmillUpgrade = v
        Memory.AutoUpgradeTreadmill = v
        if v and not shouyuhubAutomation.loops.treadmill then
            shouyuhubAutomation.loops.treadmill = true
            task.spawn(function()
                while shouyuhubAutomation.autoTreadmillUpgrade do pcall(runAutomationTreadmillUpgrade); task.wait(15) end
                shouyuhubAutomation.loops.treadmill = false
            end)
        end
    end
})

refreshAutomationTrails()
UpGroup:AddDropdown("TrailSelect", {
    Text = "Trail Selection",
    Values = TRAIL_VALUES,
    Multi = true,
    Default = {},
    Callback = function(v) AutomationTrailSelection = v; Memory.AutoBuyTrailSelection = v end
})
UpGroup:AddToggle("BuyTrail", {
    Text = "Auto Buy Trail",
    Default = Memory.AutoBuyTrail or false,
    Callback = function(v)
        shouyuhubAutomation.autoBuyTrail = v
        Memory.AutoBuyTrail = v
        if v and not shouyuhubAutomation.loops.trail then
            shouyuhubAutomation.loops.trail = true
            task.spawn(function()
                while shouyuhubAutomation.autoBuyTrail do
                    pcall(function() runAutomationBuyTrail(AutomationTrailSelection) end)
                    task.wait(6)
                end
                shouyuhubAutomation.loops.trail = false
            end)
        end
    end
})

-- ============ Auto Sell Tab ============
local SellGroup = SellTab:AddLeftGroupbox("Auto Sell")
SellGroup:AddDropdown("SellRarity", {
    Text = "Sell Rarities",
    Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Prismatic", "Eternal", "Transcendent", "Divine", "Celestial", "Titan"},
    Multi = true,
    Default = AutoSellRarities,
    Callback = function(v) AutoSellRarities = v; Memory.AutoSellRarities = v end
})
SellGroup:AddToggle("AutoSell", {
    Text = "Auto Sell Eggs",
    Default = AutoSellEnabled,
    Callback = function(v) AutoSellEnabled = v; Memory.AutoSellEnabled = v end
})

-- ============ Settings Tab ============
local SetGroup = SettingsTab:AddLeftGroupbox("UI Settings")
SetGroup:AddButton({ Text = "Open UI", Func = function() Library:Open() end })
SetGroup:AddButton({ Text = "Close UI", Func = function() Library:Close() end })
SetGroup:AddKeybind("UIKey", {
    Text = "UI Keybind",
    Default = "K",
    Callback = function(v) Library.ToggleKeybind = v end
})
SetGroup:AddButton({
    Text = "Copy Discord Link",
    Func = function()
        if setclipboard then setclipboard("https://discord.gg/PEsmsDCHdf") end
    end
})

Library:Notify({
    Title = "shouyuhub",
    Content = "Loaded successfully!",
    Duration = 4
})
