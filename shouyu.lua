-- shouyuhubfmly v4.0 - Auto Steal & Prompt Spammer Edition
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

local config = {
    SpeedHack = false,
    SpeedValue = 150,
    AutoSteer = false,      -- 自動で「盗む」プロンプトを即座に実行する機能
    Fly = false,
    FlySpeed = 60,
    Underground = false     -- リスポーン防止
}

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2
        })
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "shouyuhubfmly_" .. math.random(1000, 9999)
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local ToggleButtonIcon = Instance.new("TextButton")
ToggleButtonIcon.Size = UDim2.new(0, 45, 0, 45)
ToggleButtonIcon.Position = UDim2.new(0, 15, 0.4, 0)
ToggleButtonIcon.BackgroundColor3 = Color3.fromRGB(20, 18, 25)
ToggleButtonIcon.Text = "⚡"
ToggleButtonIcon.TextColor3 = Color3.fromRGB(200, 130, 255)
ToggleButtonIcon.TextSize = 22
ToggleButtonIcon.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = ToggleButtonIcon

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 460, 0, 310)
MainFrame.Position = UDim2.new(0.5, -230, 0.5, -155)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 14, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

ToggleButtonIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 8)
TopBarCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -12, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "shouyuhubfmly"
Title.TextColor3 = Color3.fromRGB(200, 140, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local TabMenu = Instance.new("Frame")
TabMenu.Size = UDim2.new(0, 125, 1, -32)
TabMenu.Position = UDim2.new(0, 0, 0, 32)
TabMenu.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
TabMenu.BorderSizePixel = 0
TabMenu.Parent = MainFrame

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -125, 1, -32)
Container.Position = UDim2.new(0, 125, 0, 32)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local Tabs = {}
local function createTabContent(name)
    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Size = UDim2.new(1, -10, 1, -10)
    scrolling.Position = UDim2.new(0, 5, 0, 5)
    scrolling.BackgroundTransparency = 1
    scrolling.CanvasSize = UDim2.new(0, 0, 0, 250)
    scrolling.ScrollBarThickness = 3
    scrolling.Visible = false
    scrolling.Parent = Container
    Tabs[name] = scrolling
    return scrolling
end

local tab1 = createTabContent("Steal")
local tab2 = createTabContent("Movement")
local tab3 = createTabContent("Settings")
local tab4 = createTabContent("Joiner")

local function createTabButton(text, yPos, targetTab)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = TabMenu
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do t.Visible = false end
        targetTab.Visible = true
    end)
end

tab1.Visible = true
createTabButton("🎯 盗み・奪取", 10, tab1)
createTabButton("⚡ 移動・飛行", 45, tab2)
createTabButton("⚙️ 設定機能", 80, tab3)
createTabButton("🔗 ジョイナー", 115, tab4)

local function createToggleInTab(parent, text, yPos, settingKey)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.95, 0, 0, 32)
    btn.Position = UDim2.new(0.025, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = parent
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        config[settingKey] = not config[settingKey]
        local stateStr = config[settingKey] and "ON" or "OFF"
        btn.Text = text .. " : " .. stateStr
        btn.BackgroundColor3 = config[settingKey] and Color3.fromRGB(90, 40, 160) or Color3.fromRGB(30, 27, 40)
        notify("shouyuhubfmly", text .. " を " .. stateStr)
    end)
end

-- --- タブ1: 盗み機能 ---
createToggleInTab(tab1, "オートスティール(自動盗み)", 10, "AutoSteer")
createToggleInTab(tab1, "地面に埋まる(リスポーン防止)", 50, "Underground")

-- --- タブ2: 移動・飛行機能 ---
createToggleInTab(tab2, "スピードアップ", 10, "SpeedHack")
createToggleInTab(tab2, "飛行 (Fly)", 50, "Fly")

local SpeedBtn = Instance.new("TextButton")
SpeedBtn.Size = UDim2.new(0.95, 0, 0, 32)
SpeedBtn.Position = UDim2.new(0.025, 0, 0, 90)
SpeedBtn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
SpeedBtn.Text = "速度調整 (現在: 150)"
SpeedBtn.TextColor3 = Color3.new(1, 1, 1)
SpeedBtn.Font = Enum.Font.GothamMedium
SpeedBtn.TextSize = 12
SpeedBtn.Parent = tab2

local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 6)
sc.Parent = SpeedBtn

SpeedBtn.MouseButton1Click:Connect(function()
    if config.SpeedValue == 150 then
        config.SpeedValue = 220
    elseif config.SpeedValue == 220 then
        config.SpeedValue = 90
    else
        config.SpeedValue = 150
    end
    SpeedBtn.Text = "速度調整 (現在: " .. config.SpeedValue .. ")"
    notify("shouyuhubfmly", "移動速度を " .. config.SpeedValue .. " に変更")
end)

-- --- タブ3: 設定機能 ---
local FlySpeedBtn = Instance.new("TextButton")
FlySpeedBtn.Size = UDim2.new(0.95, 0, 0, 32)
FlySpeedBtn.Position = UDim2.new(0.025, 0, 0, 10)
FlySpeedBtn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
FlySpeedBtn.Text = "飛行速度 (現在: 60)"
FlySpeedBtn.TextColor3 = Color3.new(1, 1, 1)
FlySpeedBtn.Font = Enum.Font.GothamMedium
FlySpeedBtn.TextSize = 12
FlySpeedBtn.Parent = tab3

local fsc = Instance.new("UICorner")
fsc.CornerRadius = UDim.new(0, 6)
fsc.Parent = FlySpeedBtn

FlySpeedBtn.MouseButton1Click:Connect(function()
    if config.FlySpeed == 60 then
        config.FlySpeed = 100
    elseif config.FlySpeed == 100 then
        config.FlySpeed = 30
    else
        config.FlySpeed = 60
    end
    FlySpeedBtn.Text = "飛行速度 (現在: " .. config.FlySpeed .. ")"
    notify("shouyuhubfmly", "飛行速度を " .. config.FlySpeed .. " に設定")
end)

-- --- タブ4: ジョイナー ---
local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Size = UDim2.new(0.95, 0, 0, 32)
RejoinBtn.Position = UDim2.new(0.025, 0, 0, 10)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
RejoinBtn.Text = "サーバー再参加 (Rejoin)"
RejoinBtn.TextColor3 = Color3.new(1, 1, 1)
RejoinBtn.Font = Enum.Font.GothamMedium
RejoinBtn.TextSize = 12
RejoinBtn.Parent = tab4

local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 6)
rc.Parent = RejoinBtn

RejoinBtn.MouseButton1Code = RejoinBtn.MouseButton1Click:Connect(function()
    notify("shouyuhubfmly", "サーバーに再接続中...")
    task.wait(0.3)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
end)

-- --- 安定・高速メインループ処理 ---
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
    end

    if config.Fly then
        local cam = workspace.CurrentCamera
        rootPart.Velocity = Vector3.new(0, 0, 0)
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            rootPart.CFrame = rootPart.CFrame + (cam.CFrame.LookVector * moveDir.Z + cam.CFrame.RightVector * moveDir.X) * (config.FlySpeed / 10)
        end
    end

    if config.Underground then
        rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 4.2, 0)
    end
end)

-- --- 真のオートスティール（周囲の「盗む」プロンプトやアクションを自動実行） ---
RunService.Stepped:Connect(function()
    if not config.AutoSteer then return end
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- マップ全体のProximityPromptや、盗む判定を持つパーツを探索して自動トリガー
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            -- ProximityPrompt（「盗む」などの長押し・タップ要求）を自動発動
            if obj:IsA("ProximityPrompt") then
                local parentPart = obj.Parent
                if parentPart and parentPart:IsA("BasePart") then
                    if (rootPart.Position - parentPart.Position).Magnitude <= (obj.MaxActivationDistance + 5) then
                        -- プロンプトの条件をバイパスして即座に発動
                        fireproximityprompt(obj)
                    end
                end
            end
            
            -- 「盗む」や「Steal」という文字が含まれるタッチパーツ（触れるだけで盗めるオブジェクト）への自動接近
            if obj:IsA("TouchTransmitter") and obj.Parent then
                local part = obj.Parent
                if part:IsA("BasePart") and (rootPart.Position - part.Position).Magnitude < 30 then
                    -- 触れに行くようにわずかに引き寄せる
                    rootPart.CFrame = rootPart.CFrame:Lerp(part.CFrame + Vector3.new(0, 1, 0), 0.2)
                end
            end
        end
    end)
end)

notify("shouyuhubfmly", "オートスティール機能をロードしました！")

