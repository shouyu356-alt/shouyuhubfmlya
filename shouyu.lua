-- Shouyuhub
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

-- 既存UIのクリーンアップ
for _, v in pairs(pgui:GetChildren()) do
    if v.Name == "Shouyuhub_Gui" then
        v:Destroy()
    end
end

local config = {
    SpeedValue = 150,
    SpeedHack = false,
    AutoSteer = false,      -- 周囲の「盗む」プロンプトを自動実行
    Fly = false,
    FlySpeed = 60,
    Underground = false,    -- 地面に埋まる（リスポーン防止）
    Noclip = false
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
ScreenGui.Name = "Shouyuhub_Gui"
ScreenGui.Parent = pgui
ScreenGui.ResetOnSpawn = false

-- 開閉アイコン（⚡）
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 48, 0, 48)
ToggleBtn.Position = UDim2.new(0, 15, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
ToggleBtn.Text = "⚡"
ToggleBtn.TextColor3 = Color3.fromRGB(210, 140, 255)
ToggleBtn.TextSize = 24
ToggleBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleBtn

-- メインフレーム
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 440, 0, 300)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- ヘッダー（Shouyuhub表記）
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(28, 22, 40)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Shouyuhub"
Title.TextColor3 = Color3.fromRGB(220, 160, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- スクロール可能な機能リスト
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -45)
Scroll.Position = UDim2.new(0, 8, 0, 40)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 340)
Scroll.ScrollBarThickness = 4
Scroll.Parent = MainFrame

local function createToggle(text, yPos, key)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(32, 27, 45)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = Scroll

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseButton1Click:Connect(function()
        config[key] = not config[key]
        local state = config[key]
        btn.Text = text .. " : " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(100, 45, 180) or Color3.fromRGB(32, 27, 45)
    end)
end

-- 各種機能の配置
createToggle("🎯 オートスティール (自動盗み)", 0, "AutoSteer")
createToggle("🛡️ 地面に埋まる (リスポーン防止)", 44, "Underground")
createToggle("⚡ スピードハック", 88, "SpeedHack")
createToggle("✈️ 飛行 (Fly)", 132, "Fly")
createToggle("👻 壁抜け (Noclip)", 176, "Noclip")

-- 速度変更ボタン
local SpeedBtn = Instance.new("TextButton")
SpeedBtn.Size = UDim2.new(1, 0, 0, 36)
SpeedBtn.Position = UDim2.new(0, 0, 0, 220)
SpeedBtn.BackgroundColor3 = Color3.fromRGB(32, 27, 45)
SpeedBtn.Text = "移動速度切替 (現在: 150)"
SpeedBtn.TextColor3 = Color3.new(1, 1, 1)
SpeedBtn.Font = Enum.Font.GothamMedium
SpeedBtn.TextSize = 12
SpeedBtn.Parent = Scroll

local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 6)
sc.Parent = SpeedBtn

SpeedBtn.MouseButton1Click:Connect(function()
    if config.SpeedValue == 150 then config.SpeedValue = 220
    elseif config.SpeedValue == 220 then config.SpeedValue = 90
    else config.SpeedValue = 150 end
    SpeedBtn.Text = "移動速度切替 (現在: " .. config.SpeedValue .. ")"
end)

-- 再参加ボタン
local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Size = UDim2.new(1, 0, 0, 36)
RejoinBtn.Position = UDim2.new(0, 0, 0, 264)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(55, 30, 75)
RejoinBtn.Text = "サーバー再参加 (Rejoin)"
RejoinBtn.TextColor3 = Color3.new(1, 1, 1)
RejoinBtn.Font = Enum.Font.GothamMedium
RejoinBtn.TextSize = 12
RejoinBtn.Parent = Scroll

local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 6)
rc.Parent = RejoinBtn

RejoinBtn.MouseButton1Click:Connect(function()
    task.wait(0.3)
    pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
end)

-- メインの動作ループ
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
    end

    if config.Underground then
        rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 5, 0)
        rootPart.Velocity = Vector3.new(0, 0, 0)
    end

    if config.Noclip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end

    if config.Fly then
        rootPart.Velocity = Vector3.new(0, 0, 0)
        local cam = workspace.CurrentCamera
        local move = humanoid.MoveDirection
        if move.Magnitude > 0 then
            rootPart.CFrame = rootPart.CFrame + (cam.CFrame.LookVector * move.Z + cam.CFrame.RightVector * move.X) * (config.FlySpeed / 10)
        end
    end
end)

-- オートスティール（自動盗み）の実行処理
RunService.Stepped:Connect(function()
    if not config.AutoSteer then return end
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local parentPart = obj.Parent
                if parentPart and parentPart:IsA("BasePart") then
                    if (rootPart.Position - parentPart.Position).Magnitude <= (obj.MaxActivationDistance + 12) then
                        fireproximityprompt(obj)
                    end
                end
            end
        end
    end)
end)
