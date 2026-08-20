-- Shouyuhub Speed & Teleport Edition
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

-- 既存UIのクリーンアップ
for _, v in pairs(pgui:GetChildren()) do
    if v.Name == "Shouyuhub_Teleport_Gui" then
        v:Destroy()
    end
end

local config = {
    SpeedValue = 250,       -- 超高速移動
    SpeedHack = false,
    Fly = false,
    FlySpeed = 70,
    Noclip = false,
    Underground = false     -- 地面に埋まる防止
}

-- 基地の位置を保存するための変数
local basePosition = nil

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
ScreenGui.Name = "Shouyuhub_Teleport_Gui"
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
MainFrame.Size = UDim2.new(0, 420, 0, 280)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -140)
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

-- ヘッダー
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
Scroll.CanvasSize = UDim2.new(0, 0, 0, 300)
Scroll.ScrollBarThickness = 4
Scroll.Parent = MainFrame

local function createButton(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(32, 27, 45)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = Scroll

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- 1. 基地の場所をセーブするボタン
local SetBaseBtn = createButton("📍 現在地を「自分の基地」として記憶", 0, function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        basePosition = char.HumanoidRootPart.CFrame
        notify("Shouyuhub", "現在の位置を基地として保存しました！")
    end
end)

-- 2. 基地へ瞬間移動するボタン（シュッと戻る用）
local TpBaseBtn = createButton("🏠 基地へ瞬間テレポート (シュッ！)", 44, function()
    if basePosition then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = basePosition
            notify("Shouyuhub", "基地へテレポートしました！")
        end
    else
        notify("Shouyuhub", "先に「基地を記憶」してください！")
    end
end)

-- 3. スピードハック切り替え
local speedStateBtn
speedStateBtn = createButton("⚡ スピードハック : OFF", 88, function()
    config.SpeedHack = not config.SpeedHack
    speedStateBtn.Text = "⚡ スピードハック : " .. (config.SpeedHack and "ON" or "OFF")
    speedStateBtn.BackgroundColor3 = config.SpeedHack and Color3.fromRGB(100, 45, 180) or Color3.fromRGB(32, 27, 45)
end)

-- 4. 飛行 (Fly)
local flyStateBtn
flyStateBtn = createButton("✈️ 飛行 (Fly) : OFF", 132, function()
    config.Fly = not config.Fly
    flyStateBtn.Text = "✈️ 飛行 (Fly) : " .. (config.Fly and "ON" or "OFF")
    flyStateBtn.BackgroundColor3 = config.Fly and Color3.fromRGB(100, 45, 180) or Color3.fromRGB(32, 27, 45)
end)

-- 5. 壁抜け (Noclip)
local noclipStateBtn
noclipStateBtn = createButton("👻 壁抜け (Noclip) : OFF", 176, function()
    config.Noclip = not config.Noclip
    noclipStateBtn.Text = "👻 壁抜け (Noclip) : " .. (config.Noclip and "ON" or "OFF")
    noclipStateBtn.BackgroundColor3 = config.Noclip and Color3.fromRGB(100, 45, 180) or Color3.fromRGB(32, 27, 45)
end)

-- メインの動作ループ（高速移動・飛行・壁抜け）
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
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

notify("Shouyuhub", "高速移動＆基地テレポート版をロードしました！")
