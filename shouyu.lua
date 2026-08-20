-- shouyuhubfmly Simple Edition
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

-- 既存のUIがあれば消す
for _, v in pairs(pgui:GetChildren()) do
    if v.Name == "shouyuhubfmly_gui" then
        v:Destroy()
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "shouyuhubfmly_gui"
ScreenGui.Parent = pgui
ScreenGui.ResetOnSpawn = false

-- 開閉ボタン
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Position = UDim2.new(0, 15, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 18, 25)
ToggleBtn.Text = "⚡"
ToggleBtn.TextColor3 = Color3.fromRGB(200, 130, 255)
ToggleBtn.TextSize = 22
ToggleBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleBtn

-- メインフレーム
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 380, 0, 240)
Main.Position = UDim2.new(0.5, -190, 0.5, -120)
Main.BackgroundColor3 = Color3.fromRGB(15, 14, 20)
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

ToggleBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

-- タイトル
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
Title.Text = "  shouyuhubfmly"
Title.TextColor3 = Color3.fromRGB(200, 140, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- 機能の状態管理
local speedEnabled = false
local flyEnabled = false
local underEnabled = false

-- トグルボタン生成関数
local function createButton(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize, btn.Parent = 12, Main
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. " : " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(90, 40, 160) or Color3.fromRGB(30, 27, 40)
        callback(state)
    end)
end

-- 各ボタンの配置
createButton("スピードアップ", 45, function(state) speedEnabled = state end)
createButton("飛行 (Fly)", 85, function(state) flyEnabled = state end)
createButton("地面に埋まる (リスポーン防止)", 125, function(state) underEnabled = state end)

-- 再参加ボタン
local Rejoin = Instance.new("TextButton")
Rejoin.Size = UDim2.new(0.9, 0, 0, 35)
Rejoin.Position = UDim2.new(0.05, 0, 0, 165)
Rejoin.BackgroundColor3 = Color3.fromRGB(50, 30, 70)
Rejoin.Text = "サーバー再参加 (Rejoin)"
Rejoin.TextColor3 = Color3.new(1, 1, 1)
Rejoin.Font = Enum.Font.GothamMedium
Rejoin.TextSize, Rejoin.Parent = 12, Main

local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 6)
rc.Parent = Rejoin

Rejoin.MouseButton1Click:Connect(function()
    pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
end)

-- 動作ループ
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if speedEnabled then
        humanoid.WalkSpeed = 150
    end

    if flyEnabled then
        rootPart.Velocity = Vector3.new(0, 0, 0)
        local cam = workspace.CurrentCamera
        local move = humanoid.MoveDirection
        if move.Magnitude > 0 then
            rootPart.CFrame = rootPart.CFrame + (cam.CFrame.LookVector * move.Z + cam.CFrame.RightVector * move.X) * 1.5
        end
    end

    if underEnabled then
        rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 5, 0)
        rootPart.Velocity = Vector3.new(0, 0, 0)
    end
end)
