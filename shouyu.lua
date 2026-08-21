-- Shouyu Hub Fmly v2.0 - 検知対策版
-- 完全自己完結型・外部URL不要・Delta対応

-- 検知対策: 遅延実行
task.wait(0.5)

local function init()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local StarterGui = game:GetService("StarterGui")
    
    -- 検知対策: 難読化
    local _p, _r, _u, _s = Players, RunService, UserInputService, StarterGui
    
    local player = _p.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- 設定
    local config = {
        SpeedHack = false, SpeedValue = 16,
        InfJump = false, Noclip = false, ESP = false,
        Fly = false, FlySpeed = 100, AutoFarm = false,
        WallHack = false, Aimbot = false, Teleport = false, GodMode = false
    }
    
    -- GUI作成（ランダム名で検知対策）
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SH_" .. math.random(1000, 9999)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
    ScreenGui.ResetOnSpawn = false
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 350, 0, 600)
    MainFrame.Position = UDim2.new(0.5, -175, 0.5, -300)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0,
