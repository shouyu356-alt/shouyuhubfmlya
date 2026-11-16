-- ============================================================
-- SHOUYU HUB - ALL IN ONE (ANTI-LAG + UI + UTILS)
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- 1. ANTI-LAG / FPS BOOST (自動起動)
-- ============================================================
task.spawn(function()
    local applied = setmetatable({}, {__mode = "k"})
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    
    local function isProtected(inst)
        local char = LocalPlayer.Character
        if char and inst:IsDescendantOf(char) then return true end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp and inst:IsDescendantOf(bp) then return true end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character and inst:IsDescendantOf(pl.Character) then return true end
        end
        return false
    end

    local function applyLag()
        pcall(function()
            if settings and settings().Rendering then
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 1
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") or e:IsA("Atmosphere") or e:IsA("Sky") or e:IsA("Clouds") then
                    pcall(function() e:Destroy() end)
                end
            end
        end)
        if Terrain then
            pcall(function()
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
                if sethiddenproperty then pcall(function() sethiddenproperty(Terrain, "Decoration", false) end) end
            end)
        end
    end

    local function strip(obj)
        if applied[obj] or isProtected(obj) then return end
        pcall(function()
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.CastShadow = false
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj:Destroy()
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Highlight") then
                obj.Enabled = false
                obj:Destroy()
            end
            applied[obj] = true
        end)
    end

    applyLag()
    for _, d in ipairs(Workspace:GetDescendants()) do strip(d) end
    Workspace.DescendantAdded:Connect(strip)
    while true do
        task.wait(0.5)
        pcall(applyLag)
    end
end)

-- ============================================================
-- 2. UI LIBRARY (Shouyu独自)
-- ============================================================
local C = {
    BG        = Color3.fromRGB(12, 16, 20),
    Sidebar   = Color3.fromRGB(18, 24, 30),
    Card      = Color3.fromRGB(24, 32, 40),
    CardHover = Color3.fromRGB(32, 42, 52),
    Line      = Color3.fromRGB(42, 54, 66),
    Accent    = Color3.fromRGB(34, 211, 238),
    Text      = Color3.fromRGB(235, 245, 250),
    Sub       = Color3.fromRGB(140, 158, 175),
    Green     = Color3.fromRGB(74, 222, 128),
    Red       = Color3.fromRGB(239, 68, 68),
    White     = Color3.new(1,1,1),
}

local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do if k ~= "Parent" then inst[k] = v end end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Round(p, px) return New("UICorner", {CornerRadius = UDim.new(0, px), Parent = p}) end
local function Stroke(p, c, t, tr) return New("UIStroke", {Color = c, Thickness = t or 1, Transparency = tr or 0, Parent = p}) end

local parentTarget = (gethui and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
for _, n in ipairs({"ShouyuHub_UI", "ShouyuHub_Toast"}) do
    local old = parentTarget:FindFirstChild(n)
    if old then old:Destroy() end
end

local Gui = New("ScreenGui", {Name = "ShouyuHub_UI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999999})
pcall(function() Gui.Parent = parentTarget end)
if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local ToastGui = New("ScreenGui", {Name = "ShouyuHub_Toast", ResetOnSpawn = false, DisplayOrder = 999998})
pcall(function() ToastGui.Parent = parentTarget end)
if not ToastGui.Parent then ToastGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local BASE_W, BASE_H = 540, 380
local Main = New("Frame", {Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, BASE_W, 0, BASE_H), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = C.BG, BorderSizePixel = 0, ClipsDescendants = true, Parent = Gui})
Round(Main, 16)
local MainScale = New("UIScale", {Scale = 1, Parent = Main})
Stroke(Main, C.Accent, 1.4, 0.25)

local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local s = math.clamp(math.min((vp.X - 40)/BASE_W, (vp.Y - 40)/BASE_H), 0.5, 1.0)
    TweenService:Create(MainScale, TweenInfo.new(0.2), {Scale = s}):Play()
end
updateScale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end

local dragging, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = Main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local Header = New("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Parent = Main})
Round(Header, 16)
New("Frame", {Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Parent = Header})
New("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(24, 34, 44), Color3.fromRGB(18, 24, 30)), Rotation = 90, Parent = Header})
local AccentBar = New("Frame", {Size = UDim2.new(0, 4, 0, 20), Position = UDim2.new(0, 16, 0.5, -10), BackgroundColor3 = C.Accent, Parent = Header})
Round(AccentBar, 2)
New("UIGradient", {Color = ColorSequence.new(C.Accent, Color3.fromRGB(56, 189, 248)), Rotation = 90, Parent = AccentBar})

New("TextLabel", {Size = UDim2.new(0, 260, 0, 18), Position = UDim2.new(0, 28, 0, 8), BackgroundTransparency = 1, Text = "SHOUYU HUB", TextColor3 = C.Text, TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header})
New("TextLabel", {Size = UDim2.new(0, 260, 0, 12), Position = UDim2.new(0, 28, 0, 26), BackgroundTransparency = 1, Text = "All-in-One · Anti-Lag Enabled", TextColor3 = C.Accent, TextSize = 9, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header})

local StatusDot = New("Frame", {Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(1, -118, 0.5, -4), BackgroundColor3 = C.Green, Parent = Header})
Round(StatusDot, 4)
RunService.RenderStepped:Connect(function()
    StatusDot.BackgroundTransparency = 0.4 + math.sin(tick() * 3) * 0.3
end)

local CloseBtn = New("TextButton", {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -34, 0.5, -13), BackgroundColor3 = C.Card, Text = "X", TextColor3 = C.Sub, TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = Header})
Round(CloseBtn, 8)
CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy(); ToastGui:Destroy() end)

local Sidebar = New("Frame", {Size = UDim2.new(0, 130, 1, -46), Position = UDim2.new(0, 0, 0, 46), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Parent = Main})
New("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = C.Line, BorderSizePixel = 0, Parent = Sidebar})
New("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar})
New("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = Sidebar})

local Content = New("Frame", {Size = UDim2.new(1, -134, 1, -46), Position = UDim2.new(0, 130, 0, 46), BackgroundTransparency = 1, Parent = Main})
New("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8), Parent = Content})

local tabs = {}
local pages = {}
local activeTab = nil

local function SelectTab(id)
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
    for tid, btn in pairs(tabs) do
        local on = (tid == id)
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = on and C.Card or C.Sidebar}):Play()
        for _, ch in ipairs(btn:GetChildren()) do
            if ch:IsA("TextLabel") then TweenService:Create(ch, TweenInfo.new(0.15), {TextColor3 = on and C.Text or C.Sub}):Play() end
        end
    end
    activeTab = id
end

local function AddTab(id, icon, label)
    local btn = New("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.Sidebar, Text = "", AutoButtonColor = false, LayoutOrder = #tabs + 1, Parent = Sidebar})
    Round(btn, 8)
    local accent = New("Frame", {Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = C.Accent, BackgroundTransparency = 1, Parent = btn})
    Round(accent, 2)
    New("TextLabel", {Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = icon, TextColor3 = C.Sub, TextSize = 14, Parent = btn})
    New("TextLabel", {Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 38, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = C.Sub, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn})
    local page = New("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = Content})
    
    tabs[id] = btn
    pages[id] = page
    btn.MouseButton1Click:Connect(function() SelectTab(id) end)
    if not activeTab then SelectTab(id) end
    return page
end

local function Section(parent, y, text)
    New("TextLabel", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 4, 0, y), BackgroundTransparency = 1, Text = text, TextColor3 = C.Accent, TextSize = 9, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    New("Frame", {Size = UDim2.new(1, -100, 0, 1), Position = UDim2.new(0, 100, 0, y + 7), BackgroundColor3 = C.Line, Parent = parent})
    return y + 22
end

local function Toggle(parent, y, label, desc, default, cb)
    local row = New("Frame", {Size = UDim2.new(1, -4, 0, 42), Position = UDim2.new(0, 2, 0, y), BackgroundColor3 = C.Card, Parent = parent})
    Round(row, 8); Stroke(row, C.Line, 1, 0.5)
    New("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 10, 0, 6), BackgroundTransparency = 1, Text = label, TextColor3 = C.Text, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
    if desc then New("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 10, 0, 22), BackgroundTransparency = 1, Text = desc, TextColor3 = C.Sub, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, Parent = row}) end
    local btn = New("TextButton", {Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -46, 0.5, -9), BackgroundColor3 = default and C.Accent or Color3.fromRGB(36, 46, 56), Text = "", AutoButtonColor = false, Parent = row})
    Round(btn, 9)
    local knob = New("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = C.White, Parent = btn})
    Round(knob, 7)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = state and C.Accent or Color3.fromRGB(36, 46, 56)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        if cb then pcall(cb, state) end
    end)
    return y + 46
end

local function Button(parent, y, label, color, cb)
    local btn = New("TextButton", {Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, y), BackgroundColor3 = color, Text = label, TextColor3 = C.White, TextSize = 11, Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = parent})
    Round(btn, 8)
    btn.MouseButton1Click:Connect(function() if cb then pcall(cb) end end)
    return y + 40
end

-- ============================================================
-- 3. TABS CONSTRUCTION (メイン・機能・設定)
-- ============================================================
local pageMain = AddTab("main", "🏠", "MAIN")
local pageUtils = AddTab("utils", "⚡", "UTILS")
local pageSettings = AddTab("settings", "⚙", "SETTINGS")

-- MAIN TAB
local y = 0
y = Section(pageMain, y, "STATUS")
New("TextLabel", {Size = UDim2.new(1, -4, 0, 24), Position = UDim2.new(0, 2, 0, y), BackgroundColor3 = C.Card, Text = "  Anti-Lag: ACTIVE", TextColor3 = C.Green, TextSize = 10, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, Parent = pageMain})
Round(pageMain:GetChildren()[#pageMain:GetChildren()], 8)
y = y + 32

y = Section(pageMain, y, "QUICK ACTIONS")
y = Button(pageMain, y, "TP to Safe Zone", C.Accent, function()
    print("TP to Safe Zone triggered")
end)
y = Button(pageMain, y, "Reset Character", C.Red, function()
    if LocalPlayer.Character then LocalPlayer.Character:BreakJoints() end
end)

-- UTILS TAB
local y2 = 0
y2 = Section(pageUtils, y2, "ANTI-LAG")
y2 = Toggle(pageUtils, y2, "Anti-Lag / FPS Boost", "自動適用中", true, function(v)
    if getgenv then getgenv().ShouyuAntiLagEnabled = v end
end)

-- SETTINGS TAB
local y3 = 0
y3 = Section(pageSettings, y3, "CONFIG")
y3 = Button(pageSettings, y3, "Save Config", C.Accent, function() print("Saved") end)
y3 = Button(pageSettings, y3, "Load Config", C.Accent, function() print("Loaded") end)

-- ============================================================
-- 4. TOAST
-- ============================================================
local function Toast(text, color)
    local old = ToastGui:FindFirstChild("T")
    if old then old:Destroy() end
    local t = New("Frame", {Name = "T", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 280, 0, 36), Position = UDim2.new(0.5, 0, 0, -60), BackgroundColor3 = C.Card, Parent = ToastGui})
    Round(t, 10); Stroke(t, color or C.Accent, 1.2)
    New("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C.Text, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = t})
    TweenService:Create(t, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0, 20)}):Play()
    task.delay(2.4, function()
        if t and t.Parent then
            local tw = TweenService:Create(t, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 0, -60)})
            tw.Completed:Connect(function() t:Destroy() end)
            tw:Play()
        end
    end)
end

Toast("Shouyu Hub Loaded", C.Green)
