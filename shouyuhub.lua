-- shouyuhub | Steal An Egg
for _, o in getgc(true) do
    if typeof(o) ~= "table" or getrawmetatable(o) then continue end
    local mr = false
    for _, v in o do if v == o then mr = true break end end
    if mr then for _, v in o do if typeof(v)=="number" and v>=1 and v<=3 and o[v]==nil then
        setmetatable(o,{__newindex=function()end}); break end end end
end

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local TeleportService=game:GetService("TeleportService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local player=Players.LocalPlayer

local Lib=loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()
if not Lib then return warn("Obsidian failed") end

local Mem = getgenv().shouyuhubMem or {
    SpeedEnabled=true, DesiredSpeed=500, SpeedBypassMethod="Humanoid Clone",
    AntiKnockbackEnabled=false, AntiRagdollEnabled=false, InstantAccelerationEnabled=false,
    AntiRejoinEnabled=false, FlyEnabled=false, FlySpeed=50,
    EggEspEnabled=false, EggAutoStealEnabled=false, EggRarityFilter="All", EggBigOnly=false,
    AntiTrapEnabled=false, AutoSellEnabled=false,
    AutoSellRarities={"Common","Uncommon","Rare","Epic"},
    AutoPlaceAll=false, AutoHatch=false, AutoEnterAbyss=false, AutoClaim=false,
    AutoUpgradeBase=false, AutoUpgradeTreadmill=false, AutoBuyTrail=false,
}
getgenv().shouyuhubMem = Mem

local DesiredSpeed=Mem.DesiredSpeed or 500
local SpeedEnabled=Mem.SpeedEnabled
local SpeedBypassMethod=Mem.SpeedBypassMethod
local AntiKnockbackEnabled=Mem.AntiKnockbackEnabled
local AntiRagdollEnabled=Mem.AntiRagdollEnabled
local InstantAccelerationEnabled=Mem.InstantAccelerationEnabled
local AntiRejoinEnabled=Mem.AntiRejoinEnabled
local FlyEnabled=Mem.FlyEnabled
local FlySpeed=Mem.FlySpeed
local AntiTrapEnabled=Mem.AntiTrapEnabled
local AutoSellEnabled=Mem.AutoSellEnabled
local AutoSellRarities=Mem.AutoSellRarities

local FlyBodyVelocity,FlyBodyGyro,FlyConnection,CurrentHumanoid
local ragdollConnection=nil
local joints={}
local AutomationTrailSelection = Mem.AutoBuyTrailSelection or {}

local function safeReq(parent,...)
    local cur=parent
    for _,n in ipairs({...}) do
        local c=cur:FindFirstChild(n)
        if not c then local s,r=pcall(function() return cur:WaitForChild(n,5) end); if s and r then c=r else return nil end end
        cur=c
    end
    if not cur:IsA("ModuleScript") then return nil end
    local s,r=pcall(require,cur); return s and r or nil
end

local EggState=safeReq(RS,"Client","EggState")
local Assets=safeReq(RS,"Data","Assets")
local WSEggVis=nil
pcall(function() WSEggVis=require(player.PlayerScripts.Game.AreaEggs.WorkspaceEggVisibility) end)

local RColors={Common=Color3.fromRGB(150,150,150),Uncommon=Color3.fromRGB(100,200,100),Rare=Color3.fromRGB(100,150,255),
SuperRare=Color3.fromRGB(80,120,255),Epic=Color3.fromRGB(180,80,255),Legendary=Color3.fromRGB(255,200,50),
Mythic=Color3.fromRGB(255,100,200),Mythical=Color3.fromRGB(255,100,200),Divine=Color3.fromRGB(255,50,50),
Secret=Color3.fromRGB(255,30,30),BrainrotGod=Color3.fromRGB(255,0,0),God=Color3.fromRGB(255,0,0),
Exclusive=Color3.fromRGB(255,100,50),Limited=Color3.fromRGB(255,150,50),Prismatic=Color3.fromRGB(255,100,255),
Transcendent=Color3.fromRGB(200,50,255),Eternal=Color3.fromRGB(100,255,255),Exotic=Color3.fromRGB(255,200,100),
Rainbow=Color3.fromRGB(255,100,255),Superior=Color3.fromRGB(255,80,80),Titan=Color3.fromRGB(255,120,50),
Celestial=Color3.fromRGB(100,200,255),Cosmic=Color3.fromRGB(150,100,255),Admin=Color3.fromRGB(255,0,0)}

local RPriority={["admin"]=100,["secret"]=99,["brainrotgod"]=98,["divine"]=97,["god"]=96,["eternal"]=90,
["transcendent"]=89,["prismatic"]=88,["celestial"]=87,["cosmic"]=86,["titan"]=85,["mythical"]=80,["mythic"]=79,
["superior"]=78,["exclusive"]=77,["limited"]=76,["legendary"]=60,["epic"]=50,["exotic"]=49,["rainbow"]=48,
["superrare"]=30,["rare"]=20,["uncommon"]=10,["common"]=1}

local espEnabled=Mem.EggEspEnabled
local autoStealEnabled=Mem.EggAutoStealEnabled
local eggRarityFilter=Mem.EggRarityFilter
local eggBigOnly=Mem.EggBigOnly
local trackedEggs={}
local bestEggUid=nil
local espBeam,espPlayerAttach,espEggAttach
local modelCache,promptCache={},{}
local espLoopRunning,autoLoopRunning=false,false
local bigOnlyAutoStealEnabled,bigOnlyLoopRunning=false,false

local function findEggModel(uid)
    local c=modelCache[uid]; if c and c.Parent then return c end
    if WSEggVis and WSEggVis.ResolveModel then
        local s,r=pcall(function() return WSEggVis.ResolveModel(uid) end)
        if s and r and r:IsA("Model") then modelCache[uid]=r; return r end
    end
    local m=WS:FindFirstChild(uid); if m and m:IsA("Model") then modelCache[uid]=m; return m end
    local a=WS:FindFirstChild("AreaEggSlotsClient")
    if a then m=a:FindFirstChild(uid); if m and m:IsA("Model") then modelCache[uid]=m; return m end end
end

local function getBasePart(m)
    if not m then return nil end
    if m.PrimaryPart then return m.PrimaryPart end
    for _,d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then return d end end
end

local function getPrompt(m)
    if not m then return nil end
    local c=promptCache[m]; if c and c.Parent then return c end
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name=="CarryAreaEgg" then promptCache[m]=d; return d end
    end
    for _,d in ipairs(m:GetDescendants()) do if d:IsA("ProximityPrompt") then promptCache[m]=d; return d end end
end

local function getRColor(cat)
    local i=Assets and Assets.Directory and Assets.Directory[cat]
    local r=i and i.Rarity
    if not r or not r.Name then return Color3.fromRGB(150,150,150) end
    return RColors[tostring(r.Name)] or Color3.fromRGB(150,150,150)
end

local rNameCache={}
local function getRName(rec)
    if not rec then return "Unknown" end
    local cat=rec.AssetCategory
    if not cat then return "Unknown" end
    if rNameCache[cat] then return rNameCache[cat] end
    local i=Assets and Assets.Directory and Assets.Directory[cat]
    local r=i and i.Rarity
    if not r then rNameCache[cat]="Unknown"; return "Unknown" end
    local n="Unknown"
    if r.Name~=nil then n=tostring(r.Name) elseif type(r)=="string" then n=r end
    rNameCache[cat]=n; return n
end

local function sizeScore(m)
    if not m or not m.Parent then return 0 end
    local s,sz=pcall(function() return m:GetExtentsSize() end)
    if s and sz then return math.floor(math.max(sz.X,sz.Y,sz.Z)*100) end
    return 0
end

local function rPriority(rec)
    local i=Assets and Assets.Directory and Assets.Directory[rec.AssetCategory]
    local r=i and i.Rarity
    if not r then return 0 end
    local n=r.Name and tostring(r.Name):lower() or ""
    local p=RPriority[n] or 0
    if p==0 and rec.AssetCategory then
        local cn=tostring(rec.AssetCategory):lower()
        for rn,pp in pairs(RPriority) do if cn:find(rn) then p=pp; break end end
    end
    return p
end

local function scoreEgg(d)
    local sz=sizeScore(d.model)
    if eggBigOnly then return sz end
    local pr=rPriority(d.record)
    local i=Assets and Assets.Directory and Assets.Directory[d.record.AssetCategory]
    local r=i and i.Rarity
    local rn=(r and r.RarityNumber) or 0
    if eggRarityFilter~="All" then return sz*1e8+rn end
    return pr*1e8+rn*10000+sz
end

local function isCarried(uid)
    local d=trackedEggs[uid]; if not d then return false end
    local m=d.model; if not m then return false end
    local p=m.Parent
    if p then
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=player and pl.Character and p:IsDescendantOf(pl.Character) then return true,pl end
        end
    end
    local rec=d.record
    local en=rec and rec.AssetCategory and tostring(rec.AssetCategory):lower() or nil
    local mn=m.Name:lower()
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=player then
            local ch=pl.Character
            if ch then
                for _,t in ipairs(ch:GetChildren()) do
                    if t:IsA("Tool") then
                        local tn=t.Name:lower()
                        if tn:find("area egg") or tn:find("carryareaegg") or tn=="egg" or tn:find("^egg_") or tn:find("_egg$") then
                            if en and (tn:find(en) or mn:find(tn) or tn:find(mn)) then return true,pl
                            elseif not en then return true,pl end
                        end
                    end
                end
            end
            local bp=pl:FindFirstChild("Backpack")
            if bp then
                for _,t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") then
                        local tn=t.Name:lower()
                        if tn:find("area egg") or tn:find("carryareaegg") or tn=="egg" or tn:find("^egg_") or tn:find("_egg$") then
                            if en and (tn:find(en) or mn:find(tn) or tn:find(mn)) then return true,pl
                            elseif not en then return true,pl end
                        end
                    end
                end
            end
        end
    end
    local pr=getPrompt(m); if pr and pr.Enabled==false then return true end
    local ca=m:GetAttribute("Carrier")
    if ca and ca~=player.UserId then return true,Players:GetPlayerByUserId(ca) end
    return false
end

local carriedCache={}
local lastCarryT=0
local function refreshCarry()
    local n=tick(); if n-lastCarryT<0.3 then return end
    lastCarryT=n; carriedCache={}
    for uid in pairs(trackedEggs) do
        local c,carr=isCarried(uid); if c then carriedCache[uid]=carr end
    end
end

local function findPromptNear(pos,maxD)
    maxD=maxD or 25
    local bp,bd=nil,maxD
    for _,o in ipairs(WS:GetDescendants()) do
        if o:IsA("ProximityPrompt") and o.Name=="CarryAreaEgg" and o.Enabled then
            local p=o.Parent
            if p and p:IsA("BasePart") then
                local d=(p.Position-pos).Magnitude
                if d<bd then bd=d; bp=o end
            end
        end
    end
    return bp
end

local function findBest()
    local bu,bs=nil,-1
    local ch=player.Character
    local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    local pp=hrp and hrp.Position or nil
    refreshCarry()
    for uid,d in pairs(trackedEggs) do
        if d.model and d.model.Parent and not carriedCache[uid] then
            local pass=true
            if eggRarityFilter~="All" then
                if getRName(d.record):lower()~=eggRarityFilter:lower() then pass=false end
            end
            if pass then
                local s=scoreEgg(d)
                local ib=false
                if s>bs then ib=true
                elseif s==bs and pp then
                    local bp=d.basePart or getBasePart(d.model)
                    if bp then
                        local dist=(pp-bp.Position).Magnitude
                        local bd=bu and trackedEggs[bu]
                        local bbp=bd and (bd.basePart or getBasePart(bd.model))
                        local bdist=bbp and (pp-bbp.Position).Magnitude or math.huge
                        if dist<bdist then ib=true end
                    end
                end
                if ib then bs=s; bu=uid end
            end
        end
    end
    return bu,bs
end

local function findNearest()
    local ch=player.Character
    local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pp=hrp.Position
    local nu,nd=nil,math.huge
    refreshCarry()
    for uid,d in pairs(trackedEggs) do
        if d.model and d.model.Parent and not carriedCache[uid] then
            local bp=d.basePart or getBasePart(d.model)
            if bp then local dist=(pp-bp.Position).Magnitude; if dist<nd then nd=dist; nu=uid end end
        end
    end
    return nu,nd
end

local function findBiggest()
    refreshCarry()
    local bu,bs=nil,-1
    for uid,d in pairs(trackedEggs) do
        if d.model and d.model.Parent and not carriedCache[uid] then
            local s=sizeScore(d.model); if s>bs then bs=s; bu=uid end
        end
    end
    return bu,bs
end

local function findNearestBig()
    local ch=player.Character
    local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pp=hrp.Position
    local nu,nd=nil,math.huge
    refreshCarry()
    for uid,d in pairs(trackedEggs) do
        if d.model and d.model.Parent and not carriedCache[uid] then
            local bp=d.basePart or getBasePart(d.model)
            if bp then local dist=(pp-bp.Position).Magnitude; if dist<nd then nd=dist; nu=uid end end
        end
    end
    return nu,nd
end

local function clearAll()
    for uid,d in pairs(trackedEggs) do pcall(function() if d.highlight then d.highlight:Destroy() end end) end
    trackedEggs={}; modelCache={}; promptCache={}; bestEggUid=nil
    pcall(function() if espBeam then espBeam:Destroy() end end)
    pcall(function() if espPlayerAttach then espPlayerAttach:Destroy() end end)
    pcall(function() if espEggAttach then espEggAttach:Destroy() end end)
    espBeam,espPlayerAttach,espEggAttach=nil,nil,nil
end

local function ensureHL(uid)
    local d=trackedEggs[uid]; if not d then return end
    local m=d.model; if not m or not m.Parent then return end
    if d.highlight and d.highlight.Parent then
        pcall(function() local c=getRColor(d.record.AssetCategory); d.highlight.FillColor=c; d.highlight.OutlineColor=c end)
        return
    end
    pcall(function()
        local c=getRColor(d.record.AssetCategory)
        local hl=Instance.new("Highlight")
        hl.Name="shouyuhubEggESP"; hl.Adornee=m; hl.FillTransparency=0.7
        hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor=c; hl.OutlineColor=c; hl.Parent=m; d.highlight=hl
    end)
end

local function updateBeam()
    if not espEnabled or not bestEggUid then return end
    local d=trackedEggs[bestEggUid]; if not d then return end
    local m=d.model; if not m or not m.Parent then return end
    local bp=d.basePart
    if not bp or not bp.Parent then bp=getBasePart(m); d.basePart=bp; if not bp then return end end
    local ch=player.Character; if not ch then return end
    local hrp=ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not espPlayerAttach or espPlayerAttach.Parent~=hrp then
        pcall(function() if espPlayerAttach then espPlayerAttach:Destroy() end end)
        espPlayerAttach=Instance.new("Attachment"); espPlayerAttach.Name="BestEggESP_P"; espPlayerAttach.Parent=hrp
        if espBeam then espBeam.Attachment0=espPlayerAttach end
    end
    if not espEggAttach or espEggAttach.Parent~=bp then
        pcall(function() if espEggAttach then espEggAttach:Destroy() end end)
        espEggAttach=Instance.new("Attachment"); espEggAttach.Name="BestEggESP_E"; espEggAttach.Parent=bp
        if espBeam then espBeam.Attachment1=espEggAttach end
    end
    if not espBeam or espBeam.Parent==nil then
        espBeam=Instance.new("Beam"); espBeam.Name="BestEggESP_B"
        espBeam.FaceCamera=true; espBeam.LightEmission=1; espBeam.LightInfluence=0
        espBeam.Width0=0.18; espBeam.Width1=0.18; espBeam.Transparency=NumberSequence.new(0)
        espBeam.Segments=12; espBeam.Color=ColorSequence.new(Color3.fromRGB(255,0,0))
        espBeam.Parent=hrp; espBeam.Attachment0=espPlayerAttach; espBeam.Attachment1=espEggAttach
    end
end

local function syncEggs()
    if not EggState or not EggState.ReadFieldEggs then return end
    local s,snap=pcall(EggState.ReadFieldEggs,EggState)
    if not s or not snap or not snap.Records then clearAll(); return end
    local cu={}
    for _,rec in ipairs(snap.Records) do
        cu[rec.Uid]=true
        if not trackedEggs[rec.Uid] then trackedEggs[rec.Uid]={record=rec,highlight=nil,model=nil,basePart=nil}
        else trackedEggs[rec.Uid].record=rec end
    end
    for uid in pairs(trackedEggs) do
        if not cu[uid] then
            pcall(function() if trackedEggs[uid].highlight then trackedEggs[uid].highlight:Destroy() end end)
            trackedEggs[uid]=nil; modelCache[uid]=nil
            if bestEggUid==uid then bestEggUid=nil end
        end
    end
    for uid,d in pairs(trackedEggs) do
        if not d.model or not d.model.Parent then
            local m=findEggModel(uid)
            if m then d.model=m; d.basePart=getBasePart(m) end
        end
        if d.model and d.model.Parent then
            local pass=true
            if eggRarityFilter~="All" then
                if getRName(d.record):lower()~=eggRarityFilter:lower() then pass=false end
            end
            if pass then ensureHL(uid)
            else pcall(function() if d.highlight then d.highlight:Destroy(); d.highlight=nil end end) end
        end
    end
    local nb=findBest()
    if nb~=bestEggUid then bestEggUid=nb
        pcall(function() if espEggAttach then espEggAttach:Destroy() end end); espEggAttach=nil
    end
end
local SS={IDLE="IDLE",MOVING_TO_EGG="MOVING_TO_EGG",COLLECTING="COLLECTING",RETURNING="RETURNING",
DEPOSITING="DEPOSITING",WAITING_RESET="WAITING_RESET",WAITING="WAITING",RAGDOLLED_RUSH="RAGDOLLED_RUSH",
MOVING_TO_BEST="MOVING_TO_BEST",COLLECTING_BEST="COLLECTING_BEST"}

local curState=SS.IDLE
local activeTween=nil
local targetEggUid=nil
local safePos=Vector3.new(536.423340,70.333313,-364.236969)
local antiTrapPos=Vector3.new(806,167,-407)

local function getReturnPos()
    if AntiTrapEnabled then return Vector3.new(safePos.X,antiTrapPos.Y,safePos.Z) end
    return safePos
end

local vAnchor=Instance.new("Part")
vAnchor.Anchored=true; vAnchor.CanCollide=false; vAnchor.Transparency=1
vAnchor.Size=Vector3.new(1,1,1); vAnchor.Parent=WS.Terrain
local curConn=nil
local tweenCancelled=false

local AreaEggResetWall=safeReq(RS,"Client","AreaEggResetWall")
local EggStateMod=safeReq(RS,"Client","EggState")
local rawCarry=false
if EggStateMod and EggStateMod.CarryChanged then
    pcall(function() EggStateMod.CarryChanged:Connect(function(cd) rawCarry=cd and cd.IsCarrying==true end) end)
end

local function cancelTween()
    tweenCancelled=true
    if activeTween then pcall(function() activeTween:Cancel() end); activeTween=nil end
    if curConn then pcall(function() curConn:Disconnect() end); curConn=nil end
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local h=player.Character.HumanoidRootPart
        h.AssemblyLinearVelocity=Vector3.zero; h.AssemblyAngularVelocity=Vector3.zero
    end
end

local function tweenTo(pos,speed)
    cancelTween()
    local ch=player.Character; if not ch then return false end
    local h=ch:FindFirstChild("HumanoidRootPart"); if not h then return false end
    local d=(h.Position-pos).Magnitude; if d<3 then return true end
    tweenCancelled=false
    vAnchor.CFrame=h.CFrame
    local dur=math.max(d/speed,0.03)
    local ti=TweenInfo.new(dur,Enum.EasingStyle.Linear)
    local tCF=CFrame.new(pos+Vector3.new(0,3,0))*CFrame.Angles(0,math.atan2(pos.X-h.Position.X,pos.Z-h.Position.Z),0)
    activeTween=TweenService:Create(vAnchor,ti,{CFrame=tCF})
    local done=false
    curConn=RunService.Heartbeat:Connect(function()
        if not done and not tweenCancelled and h and h.Parent and vAnchor and vAnchor.Parent then
            h.CFrame=vAnchor.CFrame; h.AssemblyLinearVelocity=Vector3.zero; h.AssemblyAngularVelocity=Vector3.zero
        end
    end)
    activeTween.Completed:Connect(function()
        done=true
        if curConn then pcall(function() curConn:Disconnect() end); curConn=nil end
        if h and h.Parent and not tweenCancelled then h.CFrame=tCF end
        activeTween=nil
    end)
    activeTween:Play()
    return true
end

local function atPos(pos,th)
    th=th or 5
    local ch=player.Character; if not ch then return false end
    local h=ch:FindFirstChild("HumanoidRootPart"); if not h then return false end
    return (h.Position-pos).Magnitude<=th
end

local carryConf=0
local CCT=1
local lastVerified=false
local function checkCarry()
    local det=false
    if EggStateMod then
        local ok,c=pcall(function()
            if type(EggStateMod.IsCarrying)=="function" then return EggStateMod:IsCarrying()
            elseif EggStateMod.CarryData then return EggStateMod.CarryData.IsCarrying==true end
            return rawCarry
        end)
        if ok and c then det=true end
    elseif rawCarry then det=true end
    if not det then
        local bp=player:FindFirstChild("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then local n=t.Name:lower()
                if n:find("area egg") or n:find("carryareaegg") or n=="egg" or n:find("^egg_") or n:find("_egg$") then det=true; break end
            end
        end end
    end
    if not det then
        local ch=player.Character
        if ch then for _,t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") then local n=t.Name:lower()
                if n:find("area egg") or n:find("carryareaegg") or n=="egg" or n:find("^egg_") or n:find("_egg$") then det=true; break end
            end
        end end
    end
    if det then carryConf=carryConf+1 else carryConf=0 end
    local v=carryConf>=CCT
    if v~=lastVerified then lastVerified=v end
    return v
end

local function resetCarry() carryConf=0; lastVerified=false end

local function firePrompt(pr)
    if not pr or not pr.Parent then return end
    pcall(function()
        local oh=pr.HoldDuration; pr.HoldDuration=0
        if fireproximityprompt then fireproximityprompt(pr)
        else pr:InputHoldBegin(); task.wait(0.05); pr:InputHoldEnd() end
        pr.HoldDuration=oh
    end)
end

local function isSealed()
    if AreaEggResetWall and AreaEggResetWall.IsSealed~=nil then
        if type(AreaEggResetWall.IsSealed)=="function" then
            local ok,s=pcall(function() return AreaEggResetWall:IsSealed() end)
            if ok then return s end
        else return AreaEggResetWall.IsSealed end
    end
    return false
end

local function isRagdolled()
    local ch=player.Character; if not ch then return true end
    local h=ch:FindFirstChildOfClass("Humanoid"); if not h then return true end
    if h.PlatformStand then return true end
    local s=h:GetState()
    if s==Enum.HumanoidStateType.Physics or s==Enum.HumanoidStateType.FallingDown then return true end
    if ch:GetAttribute("Ragdolled")==true or h:GetAttribute("Ragdolled")==true then return true end
    if ch:GetAttribute("Ragdoll")==true or h:GetAttribute("Ragdoll")==true then return true end
    for _,v in ipairs(ch:GetDescendants()) do if v:IsA("BallSocketConstraint") then return true end end
    local hm,hc=false,false
    for _,v in ipairs(ch:GetDescendants()) do
        if v:IsA("Motor6D") then hm=true elseif v:IsA("Constraint") then hc=true end
    end
    if hc and not hm then return true end
    return false
end

local function runBigOnly()
    local tUid,tScore=nil,nil
    local ca,cmax=0,20
    local lpf,pfi=0,0.08
    local rushMode=false
    local cs=SS.IDLE
    while bigOnlyAutoStealEnabled do
        local w=0.03
        syncEggs()
        local c=checkCarry()
        local r=isRagdolled()
        if isSealed() then
            if cs~=SS.WAITING_RESET then cs=SS.WAITING_RESET; cancelTween() end
            w=0.3
        elseif cs==SS.WAITING_RESET then cs=SS.IDLE; w=0.5
        else
            if cs==SS.IDLE then
                local nu=findNearestBig()
                if nu and trackedEggs[nu] then
                    local d=trackedEggs[nu]
                    local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                    if bp then tUid=nu; tScore=nil; ca=0; cs=SS.MOVING_TO_EGG; tweenTo(bp.Position,240) end
                else w=0.2 end
            elseif cs==SS.MOVING_TO_EGG then
                if c then cs=SS.WAITING; cancelTween(); rushMode=false
                elseif not tUid or not trackedEggs[tUid] then cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0
                elseif carriedCache[tUid] then cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0; w=0.1
                else
                    local d=trackedEggs[tUid]; local bp=d.basePart
                    if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; cs=SS.COLLECTING end
                end
            elseif cs==SS.COLLECTING then
                if c then ca=0; cs=SS.WAITING; cancelTween(); rushMode=false
                elseif not tUid or not trackedEggs[tUid] then cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0
                else
                    local d=trackedEggs[tUid]; local m=d.model
                    local pr,pp=nil,nil
                    if m and m.Parent then pr=getPrompt(m) end
                    if not pr then
                        local bp=d.basePart or getBasePart(m)
                        if bp then pr=findPromptNear(bp.Position,30); if pr and pr.Parent then pp=pr.Parent.Position end end
                    elseif pr and pr.Parent then pp=pr.Parent.Position end
                    if pr then
                        ca=ca+1
                        if ca<=cmax then
                            local ch=player.Character
                            local h=ch and ch:FindFirstChild("HumanoidRootPart")
                            local cf=true
                            if h and pp then cf=(h.Position-pp).Magnitude<=(pr.MaxActivationDistance+5) end
                            if cf then local n=tick(); if n-lpf>=pfi then firePrompt(pr); lpf=n end end
                            w=0.08
                        else cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0 end
                    else cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0 end
                end
            elseif cs==SS.WAITING then
                if r or not c then rushMode=true; cs=SS.RAGDOLLED_RUSH; cancelTween(); tUid,tScore,ca=nil,nil,0 end
            elseif cs==SS.RAGDOLLED_RUSH then
                if rushMode and c then rushMode=false; cs=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif rushMode then
                    refreshCarry()
                    local bu=findBiggest()
                    if bu and trackedEggs[bu] then
                        if bu~=tUid then tUid=bu; ca=0
                            local d=trackedEggs[bu]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp then tweenTo(bp.Position,5000) end
                        else
                            local d=trackedEggs[tUid]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; cs=SS.COLLECTING_BEST
                            elseif not d.model or not d.model.Parent then tUid=nil; ca=0 end
                        end
                    else w=0.05 end
                elseif not r and c then cs=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif not r then cs=SS.MOVING_TO_BEST; cancelTween(); tUid,tScore,ca=nil,nil,0
                elseif c then cs=SS.RETURNING; tweenTo(getReturnPos(),1000)
                else
                    refreshCarry()
                    local bu=findBiggest()
                    if bu and trackedEggs[bu] then
                        if bu~=tUid then tUid=bu; ca=0
                            local d=trackedEggs[bu]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp then tweenTo(bp.Position,5000) end
                        else
                            local d=trackedEggs[tUid]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; cs=SS.COLLECTING_BEST
                            elseif not d.model or not d.model.Parent then tUid=nil; ca=0 end
                        end
                    else w=0.05 end
                end
            elseif cs==SS.MOVING_TO_BEST then
                if r then rushMode=false; cs=SS.RAGDOLLED_RUSH; cancelTween(); tUid,tScore,ca=nil,nil,0
                elseif c then rushMode=false; cs=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif not tUid or not trackedEggs[tUid] then
                    local bu=findBiggest()
                    if bu and trackedEggs[bu] then
                        tUid=bu
                        local d=trackedEggs[bu]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                        if bp then tweenTo(bp.Position,240) end
                    else cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0 end
                elseif carriedCache[tUid] then cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0
                else
                    local d=trackedEggs[tUid]; local bp=d.basePart
                    if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; cs=SS.COLLECTING_BEST end
                end
            elseif cs==SS.COLLECTING_BEST then
                if r then cs=SS.RAGDOLLED_RUSH; cancelTween(); tUid,tScore,ca=nil,nil,0
                elseif c then ca=0; rushMode=false; cs=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif not tUid or not trackedEggs[tUid] then cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0
                else
                    local d=trackedEggs[tUid]; local m=d.model
                    local pr,pp=nil,nil
                    if m and m.Parent then pr=getPrompt(m) end
                    if not pr then
                        local bp=d.basePart or getBasePart(m)
                        if bp then pr=findPromptNear(bp.Position,30); if pr and pr.Parent then pp=pr.Parent.Position end end
                    elseif pr and pr.Parent then pp=pr.Parent.Position end
                    if pr then
                        ca=ca+1
                        if ca<=cmax then
                            local ch=player.Character
                            local h=ch and ch:FindFirstChild("HumanoidRootPart")
                            local cf=true
                            if h and pp then cf=(h.Position-pp).Magnitude<=(pr.MaxActivationDistance+5) end
                            if cf then local n=tick(); if n-lpf>=pfi then firePrompt(pr); lpf=n end end
                            w=0.08
                        else cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0 end
                    else cs=SS.IDLE; cancelTween(); tUid,tScore,ca=nil,nil,0 end
                end
            elseif cs==SS.RETURNING then
                if not c then cancelTween(); cs=SS.IDLE; tUid,tScore,ca=nil,nil,0; resetCarry(); rushMode=false
                elseif atPos(getReturnPos(),12) then cancelTween(); cs=SS.DEPOSITING end
            elseif cs==SS.DEPOSITING then
                if not c then cs=SS.IDLE; tUid,tScore,ca=nil,nil,0; resetCarry(); rushMode=false end
            end
        end
        task.wait(w)
    end
    bigOnlyLoopRunning=false; cancelTween()
end

local function runAutoSteal()
    local tScore=nil
    local ca,cmax=0,20
    local lpf,pfi=0,0.08
    local wasRag=false
    local rushMode=false
    while autoStealEnabled do
        local w=0.03
        syncEggs()
        local c=checkCarry()
        local r=isRagdolled()
        if isSealed() then
            if curState~=SS.WAITING_RESET then curState=SS.WAITING_RESET; cancelTween() end
            w=0.3
        elseif curState==SS.WAITING_RESET then curState=SS.IDLE; w=0.5
        else
            if curState==SS.IDLE then
                local nu=findNearest()
                if nu and trackedEggs[nu] then
                    local d=trackedEggs[nu]
                    local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                    if bp then targetEggUid=nu; tScore=nil; ca=0; curState=SS.MOVING_TO_EGG; tweenTo(bp.Position,240) end
                else w=0.2 end
            elseif curState==SS.MOVING_TO_EGG then
                if c then curState=SS.WAITING; cancelTween(); wasRag=false
                elseif not targetEggUid or not trackedEggs[targetEggUid] then curState=SS.IDLE; cancelTween(); targetEggUid,tScore,ca=nil,nil,0
                elseif carriedCache[targetEggUid] then curState=SS.IDLE; cancelTween(); targetEggUid,tScore,ca=nil,nil,0; w=0.1
                else
                    local d=trackedEggs[targetEggUid]; local bp=d.basePart
                    if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; curState=SS.COLLECTING end
                end
            elseif curState==SS.COLLECTING then
                if c then ca=0; curState=SS.WAITING; cancelTween(); wasRag=false
                elseif not targetEggUid or not trackedEggs[targetEggUid] then curState=SS.IDLE; cancelTween(); targetEggUid,tScore,ca=nil,nil,0
                else
                    local d=trackedEggs[targetEggUid]; local m=d.model
                    local pr,pp=nil,nil
                    if m and m.Parent then pr=getPrompt(m) end
                    if not pr then
                        local bp=d.basePart or getBasePart(m)
                        if bp then pr=findPromptNear(bp.Position,30); if pr and pr.Parent then pp=pr.Parent.Position end end
                    elseif pr and pr.Parent then pp=pr.Parent.Position end
                    if pr then
                        ca=ca+1
                        if ca<=cmax then
                            local ch=player.Character
                            local h=ch and ch:FindFirstChild("HumanoidRootPart")
                            local cf=true
                            if h and pp then cf=(h.Position-pp).Magnitude<=(pr.MaxActivationDistance+5) end
                            if cf then local n=tick(); if n-lpf>=pfi then firePrompt(pr); lpf=n end end
                            w=0.08
                        else curState=SS.IDLE; cancelTween(); targetEggUid,tScore,ca=nil,nil,0 end
                    else curState=SS.IDLE; cancelTween(); targetEggUid,tScore,ca=nil,nil,0 end
                end
            elseif curState==SS.WAITING then
                if r or not c then wasRag=true; rushMode=true; curState=SS.RAGDOLLED_RUSH; cancelTween(); targetEggUid,tScore,ca=nil,nil,0 end
            elseif curState==SS.RAGDOLLED_RUSH then
                if rushMode and c then rushMode=false; curState=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif rushMode then
                    refreshCarry()
                    local bu=findBest()
                    if bu and trackedEggs[bu] then
                        if bu~=targetEggUid then targetEggUid=bu; ca=0
                            local d=trackedEggs[bu]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp then tweenTo(bp.Position,5000) end
                        else
                            local d=trackedEggs[targetEggUid]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; curState=SS.COLLECTING_BEST
                            elseif not d.model or not d.model.Parent then targetEggUid=nil; ca=0 end
                        end
                    else w=0.05 end
                elseif not r and c then curState=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif not r then curState=SS.MOVING_TO_BEST; cancelTween(); targetEggUid,tScore,ca=nil,nil,0
                elseif c then curState=SS.RETURNING; tweenTo(getReturnPos(),1000)
                else
                    refreshCarry()
                    local bu=findBest()
                    if bu and trackedEggs[bu] then
                        if bu~=targetEggUid then targetEggUid=bu; ca=0
                            local d=trackedEggs[bu]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp then tweenTo(bp.Position,5000) end
                        else
                            local d=trackedEggs[targetEggUid]; local bp=d.basePart or getBasePart(d.model); d.basePart=bp
                            if bp and bp.Parent and atPos(bp.Position,8) then cancelTween(); ca=0; curState=SS.COLLECTING_BEST
                            elseif not d.model or not d.model.Parent then targetEggUid=nil; ca=0 end
                        end
                    else w=0.05 end
                end
            elseif curState==SS.MOVING_TO_BEST then
                if r then rushMode=false; curState=SS.RAGDOLLED_RUSH; cancelTween(); targetEggUid,tScore,ca=nil,nil,0
                elseif c then rushMode=false; curState=SS.RETURNING; tweenTo(getReturnPos(),1000)
                elseif not targetEggUid or not trackedEggs[targetEggUid] then
                    local bu=findBest()
                    if bu and trackedEggs[bu] then
                        targetEggUid=bu
                        local d=trackedEggs[bu]; local bp=d.basePart or getBasePart(d.model); d.basePart=
            -- Speed bypass
local nBC={}
local nBCC=nil
local GCH={RunService=RunService,Players=Players,speedconn=nil,hookedfunc3=nil}
function GCH:collectgarbage()
    local s,r=pcall(function() return getgc() end); if s and r then return r end
end
function GCH:safehook(f,c)
    local s,r=pcall(function() return hookfunction(f,newlclosure(c)) end); if s and r then return r end
end
function GCH:findfunction(nups,ln)
    local s,r=pcall(function()
        for _,f in next,self:collectgarbage() do
            if typeof(f)=='function' and islclosure(f) then
                local u=debug.getupvalues(f); local l=debug.info(f,"l")
                if u and #u==nups and l==ln then
                    if nups==10 then
                        local t=debug.getupvalue(f,3)
                        if typeof(t)=="table" and rawget(t,"Humanoid") then return f end
                    else return f end
                end
            end
        end
    end)
    if s then return r end
end
function GCH:init()
    self.LP=self.Players.LocalPlayer
    if not self.LP then return end
    if not getgc or not hookfunction or not islclosure then return warn("missing executor funcs") end
    local f3=self:findfunction(19,3); if not f3 then return warn("no f3") end
    local v7=debug.getupvalue(f3,2); if not v7 then return warn("no v7") end
    self.hookedfunc3=self:safehook(v7,function(p1,p2)
        if p2 and typeof(p2)=="table" then setmetatable(p2,{}) end
        return self.hookedfunc3(p1,p2)
    end)
    self.speedconn=self.RunService.Heartbeat:Connect(function()
        local ch=self.LP.Character; if not ch then return end
        local h=ch:FindFirstChild("Humanoid"); if not h then return end
        h.WalkSpeed=DesiredSpeed
    end)
end
function GCH:stop() if self.speedconn then pcall(function() self.speedconn:Disconnect() end); self.speedconn=nil end end

local function forceWS(h)
    if nBC[h] then pcall(function() nBC[h]:Disconnect() end) end
    nBC[h]=RunService.Heartbeat:Connect(function()
        if h and h.Parent then
            if h.WalkSpeed~=DesiredSpeed then h.WalkSpeed=DesiredSpeed end
        elseif nBC[h] then nBC[h]:Disconnect(); nBC[h]=nil end
    end)
end

local function applyBypass(ch)
    local h=ch:FindFirstChildOfClass("Humanoid"); if not h then return end
    local cam=WS.CurrentCamera
    local an=ch:FindFirstChild("Animate")
    local jp,jh,hp,mhp=h.JumpPower,h.JumpHeight,h.Health,h.MaxHealth
    if an and an:IsA("LocalScript") then an.Disabled=true end
    local anr=h:FindFirstChildOfClass("Animator")
    if anr then for _,t in next,anr:GetPlayingAnimationTracks() do t:Stop(0) end end
    h.Archivable=true
    local nh=h:Clone()
    for _,c in next,nh:GetChildren() do if c:IsA("Animator") then c:Destroy() end end
    h.Name="_OldHumanoid"; nh.Name="Humanoid"; nh.Parent=ch
    local na=Instance.new("Animator"); na.Parent=nh
    nh.WalkSpeed=DesiredSpeed; nh.JumpPower=jp; nh.JumpHeight=jh; nh.MaxHealth=mhp; nh.Health=math.min(hp,mhp)
    if cam then cam.CameraSubject=nh end
    h:Destroy()
    if an and an:IsA("LocalScript") then
        task.wait(); an.Disabled=false
        task.defer(function() if an.Parent then an.Disabled=true; task.wait(); an.Disabled=false end end)
    end
    task.defer(function() if nh.Parent then nh:ChangeState(Enum.HumanoidStateType.Running) end end)
    forceWS(nh); CurrentHumanoid=nh
end

local function setupBypass(ch) ch:WaitForChild("Humanoid"); task.wait(); applyBypass(ch) end

local function startHCB()
    if nBCC then pcall(function() nBCC:Disconnect() end) end
    nBCC=player.CharacterAdded:Connect(function(c) if SpeedEnabled then task.spawn(setupBypass,c) end end)
    if player.Character then task.spawn(setupBypass,player.Character) end
end

local function stopHCB()
    for h,c in pairs(nBC) do pcall(function() c:Disconnect() end) end
    nBC={}
    if nBCC then pcall(function() nBCC:Disconnect() end); nBCC=nil end
end

local function startBypass() if SpeedBypassMethod=="GC Hook Bypass" then GCH:init() else startHCB() end end
local function stopBypass() if SpeedBypassMethod=="GC Hook Bypass" then GCH:stop() else stopHCB() end end

local function startFly()
    if FlyConnection then FlyConnection:Disconnect(); FlyConnection=nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy(); FlyBodyVelocity=nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro=nil end
    local ch=player.Character; if not ch then return end
    local h=ch:FindFirstChild("HumanoidRootPart"); if not h then return end
    FlyBodyGyro=Instance.new("BodyGyro")
    FlyBodyGyro.MaxTorque=Vector3.new(9e9,9e9,9e9); FlyBodyGyro.CFrame=h.CFrame
    FlyBodyGyro.P=9e4; FlyBodyGyro.Parent=h
    FlyBodyVelocity=Instance.new("BodyVelocity")
    FlyBodyVelocity.MaxForce=Vector3.new(9e9,9e9,9e9)
    FlyBodyVelocity.Velocity=Vector3.new(0,0,0); FlyBodyVelocity.Parent=h
    FlyConnection=RunService.RenderStepped:Connect(function()
        if not FlyEnabled then return end
        if not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then return end
        local cam=WS.CurrentCamera
        local d=Vector3.new(0,0,0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then d=d+cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d=d-cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d=d-cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d=d+cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then d=d+Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d=d-Vector3.new(0,1,0) end
        if d.Magnitude>0 then d=d.Unit*FlySpeed end
        if FlyBodyGyro and FlyBodyGyro.Parent then FlyBodyGyro.CFrame=cam.CFrame end
        if FlyBodyVelocity and FlyBodyVelocity.Parent then FlyBodyVelocity.Velocity=d end
    end)
end

local function stopFly()
    if FlyConnection then FlyConnection:Disconnect(); FlyConnection=nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy(); FlyBodyVelocity=nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro=nil end
end

-- Anti Rejoin/Kick
if type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
    local orig
    orig=hookmetamethod(game,"__namecall",function(self,...)
        if AntiRejoinEnabled and (type(checkcaller)~="function" or not checkcaller()) then
            local m=getnamecallmethod()
            if m=="Kick" and self==player then return nil end
            if (m=="Teleport" or m=="TeleportAsync" or m=="TeleportToPlaceInstance") and self==TeleportService then return nil end
        end
        return orig(self,...)
    end)
end

-- Anti Ragdoll
local function storeJ(ch)
    joints={}
    for _,j in pairs(ch:GetDescendants()) do
        if j:IsA("Motor6D") then
            joints[j.Name]={Part0=j.Part0,Part1=j.Part1,C0=j.C0,C1=j.C1}
        end
    end
end
local function restoreJ(ch)
    for n,d in pairs(joints) do
        if d.Part0 and d.Part1 then
            local e=d.Part0:FindFirstChild(n)
            if e and e:IsA("Motor6D") then
                e.Part0=d.Part0; e.Part1=d.Part1; e.C0=d.C0; e.C1=d.C1
            elseif not e then
                local j=Instance.new("Motor6D")
                j.Name=n; j.Part0=d.Part0; j.Part1=d.Part1; j.C0=d.C0; j.C1=d.C1; j.Parent=d.Part0
            end
        end
    end
end

local function startAR(ch)
    local h=ch:WaitForChild("Humanoid")
    storeJ(ch)
    if ragdollConnection then ragdollConnection:Disconnect() end
    ragdollConnection=RunService.RenderStepped:Connect(function()
        if not AntiRagdollEnabled then return end
        if not ch.Parent then return end
        local s=h:GetState()
        if s==Enum.HumanoidStateType.Physics or s==Enum.HumanoidStateType.Freefall or s==Enum.HumanoidStateType.Seated then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Running); restoreJ(ch) end)
        end
    end)
end

local function onChar(ch)
    CurrentHumanoid=ch:FindFirstChildOfClass("Humanoid")
    if CurrentHumanoid and SpeedEnabled then CurrentHumanoid.WalkSpeed=DesiredSpeed end
    startAR(ch)
    if FlyEnabled then task.wait(0.5); startFly() end
end

if player.Character then onChar(player.Character) end
player.CharacterAdded:Connect(onChar)

-- Auto Sell
local ASErr={}
task.spawn(function()
    local sh=RS:FindFirstChild("Shared"); local da=RS:FindFirstChild("Data"); local pk=RS:FindFirstChild("Packages")
    if not (sh and da and pk) then return end
    local Save=require(sh:FindFirstChild("Save"))
    local Am=require(da:FindFirstChild("Assets"))
    local Net=pk:FindFirstChild("Networking")
    local AW=Net:FindFirstChild("RF/EggWorld/AskWearTool")
    local SP=Net:FindFirstChild("RE/PetSatchel/SellPet")
    if not (Save and Am and AW and SP) then return end
    while true do
        task.wait(1)
        if AutoSellEnabled then
            pcall(function()
                local d=Save.Get(); if not d then return end
                local inv=d.EggInventory; if not inv then return end
                for uid,e in next,inv do
                    if not AutoSellEnabled then break end
                    if e.Placement then continue end
                    local ai=Am.Directory[e.AssetCategory]
                    if not ai then continue end
                    local r=ai.Rarity; if not r then continue end
                    local rn=r.DisplayName or r.Name or "Unknown"
                    if table.find(AutoSellRarities,rn) then
                        pcall(function() AW:InvokeServer(uid) end)
                        task.wait(0.05)
                        pcall(function() SP:FireServer({uid}) end)
                        task.wait(0.1)
                    end
                end
            end)
        end
    end
end)

-- UI
local Win=Lib:CreateWindow({Title="shouyuhub",Footer="Steal An Egg",Center=true,AutoShow=true,ShowMobileButtons=false})
local MainT=Win:AddTab({Name="Main"})
local EggT=Win:AddTab({Name="Egg Steal"})
local AutoT=Win:AddTab({Name="Automation"})
local SellT=Win:AddTab({Name="Auto Sell"})
local SetT=Win:AddTab({Name="Settings"})

local MG=MainT:AddLeftGroupbox("Movement")
MG:AddInput("SpeedInput",{Text="Walk Speed",Default=tostring(DesiredSpeed),Numeric=true,Callback=function(v)
    local n=tonumber(v); if n then DesiredSpeed=n; Mem.DesiredSpeed=n
        if SpeedEnabled and CurrentHumanoid then pcall(function() CurrentHumanoid.WalkSpeed=n end) end end
end})
MG:AddDropdown("BypassDD",{Text="Speed Bypass",Values={"Humanoid Clone","GC Hook Bypass"},Default=SpeedBypassMethod,
Callback=function(v) SpeedBypassMethod=v; Mem.SpeedBypassMethod=v
    if SpeedEnabled then stopBypass(); task.wait(0.1); startBypass() end end})
MG:AddToggle("SpeedToggle",{Text="Speed Hack",Default=SpeedEnabled,Callback=function(v)
    SpeedEnabled=v; Mem.SpeedEnabled=v
    if v then startBypass() else stopBypass(); if CurrentHumanoid then pcall(function() CurrentHumanoid.WalkSpeed=16 end) end end
end})
MG:AddInput("FlyInput",{Text="Fly Speed",Default=tostring(FlySpeed),Numeric=true,
Callback=function(v) local n=tonumber(v); if n then FlySpeed=n; Mem.FlySpeed=n end end})
MG:AddToggle("FlyToggle",{Text="Fly",Default=FlyEnabled,Callback=function(v)
    FlyEnabled=v; Mem.FlyEnabled=v
    if v then startFly() else stopFly() end
end})

local CG=MainT:AddRightGroupbox("Combat")
CG:AddToggle("AntiKB",{Text="Anti Knockback",Default=AntiKnockbackEnabled,
Callback=function(v) AntiKnockbackEnabled=v; Mem.AntiKnockbackEnabled=v end})
CG:AddToggle("AntiRag",{Text="Anti Ragdoll",Default=AntiRagdollEnabled,
Callback=function(v) AntiRagdollEnabled=v; Mem.AntiRagdollEnabled=v end})
CG:AddToggle("InstAcc",{Text="Smooth Movement",Default=InstantAccelerationEnabled,
Callback=function(v) InstantAccelerationEnabled=v; Mem.InstantAccelerationEnabled=v end})
CG:AddToggle("AntiRej",{Text="Anti Rejoin / Kick",Default=AntiRejoinEnabled,
Callback=function(v) AntiRejoinEnabled=v; Mem.AntiRejoinEnabled=v end})

local SG=EggT:AddLeftGroupbox("Auto Steal")
SG:AddToggle("EspT",{Text="Best Egg ESP",Default=espEnabled,Callback=function(v)
    espEnabled=v; Mem.EggEspEnabled=v
    if v then
        syncEggs()
        if not espLoopRunning then espLoopRunning=true
            task.spawn(function() while espEnabled do syncEggs(); task.wait(0.5) end; espLoopRunning=false end)
        end
    else clearAll() end
end})
SG:AddToggle("AutoStealT",{Text="Auto Steal Best",Default=autoStealEnabled,Callback=function(v)
    autoStealEnabled=v; Mem.EggAutoStealEnabled=v
    if v then
        if bigOnlyAutoStealEnabled then
            bigOnlyAutoStealEnabled=false; Mem.EggBigOnly=false; eggBigOnly=false; bigOnlyLoopRunning=false
            cancelTween(); resetCarry()
        end
        if not autoLoopRunning then autoLoopRunning=true; task.spawn(runAutoSteal) end
    else
        cancelTween(); curState=SS.IDLE; resetCarry()
    end
end})
SG:AddToggle("BigOnlyT",{Text="Big Eggs Only",Default=eggBigOnly,Callback=function(v)
    eggBigOnly=v; Mem.EggBigOnly=v
    if v then
        if autoStealEnabled then
            autoStealEnabled=false; Mem.EggAutoStealEnabled=false; autoLoopRunning=false
            cancelTween(); resetCarry()
        end
        bigOnlyAutoStealEnabled=true
        if not bigOnlyLoopRunning then bigOnlyLoopRunning=true; task.spawn(runBigOnly) end
    else
        bigOnlyAutoStealEnabled=false; cancelTween(); resetCarry()
    end
    syncEggs()
end})

local FG=EggT:AddRightGroupbox("Filters")
FG:AddDropdown("RarityDD",{Text="Rarity Filter",
Values={"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret","Divine","Prismatic","Cosmic"},
Default=eggRarityFilter,Callback=function(v) eggRarityFilter=v; Mem.EggRarityFilter=v; syncEggs() end})
FG:AddToggle("AntiTrapT",{Text="Anti Trap",Default=AntiTrapEnabled,
Callback=function(v) AntiTrapEnabled=v; Mem.AntiTrapEnabled=v end})

local AG=AutoT:AddLeftGroupbox("Automation")
AG:AddToggle("PlaceAllT",{Text="Auto Place All",Default=Mem.AutoPlaceAll,Callback=function(v)
    Auto.autoPlaceAll=v; Mem.AutoPlaceAll=v
    if v and not Auto.loops.place then Auto.loops.place=true
        task.spawn(function()
            while Auto.autoPlaceAll do
                local c=0; pcall(function() c=runPlaceAll() end)
                task.wait(c>0 and 0.8 or 1.5)
            end
            Auto.loops.place=false
        end)
    end
end})
AG:AddToggle("HatchT",{Text="Auto Hatch",Default=Mem.AutoHatch,Callback=function(v)
    Auto.autoHatch=v; Mem.AutoHatch=v
    if v and not Auto.loops.hatch then Auto.loops.hatch=true
        task.spawn(function() while Auto.autoHatch do pcall(runHatch); task.wait(1.2) end; Auto.loops.hatch=false end)
    end
end})
AG:AddToggle("ClaimT",{Text="Auto Claim Index",Default=Mem.AutoClaim,Callback=function(v)
    Auto.autoClaim=v; Mem.AutoClaim=v
    if v and not Auto.loops.claim then Auto.loops.claim=true
        task.spawn(function() while Auto.autoClaim do pcall(runClaim); task.wait(30) end; Auto.loops.claim=false end)
    end
end})
AG:AddToggle("AbyssT",{Text="Auto Enter Abyss",Default=Mem.AutoEnterAbyss,Callback=function(v)
    Auto.autoAbyss=v; Mem.AutoEnterAbyss=v
    if v and not Auto.loops.abyss then Auto.loops.abyss=true
        task.spawn(function()
            while Auto.autoAbyss do
                pcall(function()
                    if player:GetAttribute("InBossArena")~=true then
                        local net=RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
                        local sn=net and net:FindFirstChild("RF/BossEvent/AskSnapshot")
                        local se=true
                        if sn then local ok,s=pcall(sn.InvokeServer,sn); if ok and type(s)=="table" and s.Open~=nil then se=s.Open==true end end
                        if se then enterAbyss() end
                    end
                end)
                task.wait(2)
            end
            Auto.loops.abyss=false
        end)
    end
end})

local UG=AutoT:AddRightGroupbox("Upgrades")
UG:AddToggle("UpBaseT",{Text="Auto Upgrade Base",Default=Mem.AutoUpgradeBase,Callback=function(v)
    Auto.autoBaseUpgrade=v; Mem.AutoUpgradeBase=v
    if v and not Auto.loops.base then Auto.loops.base=true
        task.spawn(function() while Auto.autoBaseUpgrade do pcall(runBaseUp); task.wait(15) end; Auto.loops.base=false end)
    end
end})
UG:AddToggle("UpTreadT",{Text="Auto Upgrade Treadmill",Default=Mem.AutoUpgradeTreadmill,Callback=function(v)
    Auto.autoTreadmillUpgrade=v; Mem.AutoUpgradeTreadmill=v
    if v and not Auto.loops.treadmill then Auto.loops.treadmill=true
        task.spawn(function() while Auto.autoTreadmillUpgrade do pcall(runTreadUp); task.wait(15) end; Auto.loops.treadmill=false end)
    end
end})

ensAuto(); refreshTrails()
UG:AddDropdown("TrailDD",{Text="Trail Selection",Values=TV,Multi=true,Default={},
Callback=function(v) AutomationTrailSelection=v; Mem.AutoBuyTrailSelection=v end})
UG:AddToggle("BuyTrailT",{Text="Auto Buy Trail",Default=Mem.AutoBuyTrail,Callback=function(v)
    Auto.autoBuyTrail=v; Mem.AutoBuyTrail=v
    if v and not Auto.loops.trail then Auto.loops.trail=true
        task.spawn(function()
            while Auto.autoBuyTrail do pcall(function() runBuyTrail(AutomationTrailSelection) end); task.wait(6) end
            Auto.loops.trail=false
        end)
    end
end})

local SlG=SellT:AddLeftGroupbox("Auto Sell")
SlG:AddDropdown("SellDD",{Text="Sell Rarities",
Values={"Common","Uncommon","Rare","Epic","Legendary","Mythic","Cosmic","Secret","Prismatic","Eternal","Transcendent","Divine","Celestial","Titan"},
Multi=true,Default=AutoSellRarities,Callback=function(v) AutoSellRarities=v; Mem.AutoSellRarities=v end})
SlG:AddToggle("AutoSellT",{Text="Auto Sell Eggs",Default=AutoSellEnabled,
Callback=function(v) AutoSellEnabled=v; Mem.AutoSellEnabled=v end})

local SetG=SetT:AddLeftGroupbox("UI Settings")
SetG:AddButton({Text="Open UI",Func=function() Lib:Open() end})
SetG:AddButton({Text="Close UI",Func=function() Lib:Close() end})
SetG:AddButton({Text="Copy Discord Link",Func=function()
    if setclipboard then setclipboard("https://discord.gg/PEsmsDCHdf") end
end})

-- 起動時の状態同期
if SpeedEnabled then startBypass() end

-- 定期同期
task.spawn(function()
    while true do
        task.wait(0.2)
        if SpeedEnabled and CurrentHumanoid and CurrentHumanoid.Parent then
            pcall(function() CurrentHumanoid.WalkSpeed=DesiredSpeed end)
        end
        if InstantAccelerationEnabled then
            local ch=player.Character
            local h=ch and ch:FindFirstChild("HumanoidRootPart")
            if h and CurrentHumanoid then
                pcall(function()
                    local md=CurrentHumanoid.MoveDirection
                    if md.Magnitude>0 then
                        local tv=md.Unit*DesiredSpeed
                        h.AssemblyLinearVelocity=Vector3.new(tv.X,h.AssemblyLinearVelocity.Y,tv.Z)
                    end
                end)
            end
        end
        if AntiKnockbackEnabled then
            local ch=player.Character
            local h=ch and ch:FindFirstChild("HumanoidRootPart")
            local hu=ch and ch:FindFirstChild("Humanoid")
            if h and hu then
                if hu.MoveDirection.Magnitude==0 then h.Velocity=Vector3.new(0,h.Velocity.Y,0) end
                h.RotVelocity=Vector3.new(0,0,0)
            end
        end
        if espEnabled and bestEggUid then updateBeam() end
    end
end)

-- ProximityPrompt HoldDuration=0
for _,v in ipairs(WS:GetDescendants()) do if v:IsA("ProximityPrompt") then v.HoldDuration=0 end end
WS.DescendantAdded:Connect(function(v) if v:IsA("ProximityPrompt") then v.HoldDuration=0 end end)

Lib:Notify({Title="shouyuhub",Content="Loaded successfully!",Duration=4})
            
