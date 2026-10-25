--[[
    Script Name : LiveScanner_v11_patched.lua
    Type        : Single-file Script
    Target Exec : Delta
    Version     : Patch v1.0
    Function    : Live scanner bidirectional (FireServer/InvokeServer/OnClientEvent/require/SetAttribute),
                  GUI 6 tab (LOG, CFG, INFO, HOOK, BTN, GAME), auto-on, anti-spam, copy all, silent reset
    Changelog   : fix vararg '...' di dalam pcall closure (script gagal compile), forward declaration
                  renderLog/setupBackpack, dispatcher hook di-refresh tiap execute, setnamecallmethod restore,
                  filter refresh + kategori PLAYER/MODEL, fmt typeof, backpack watch aman saat execute ulang,
                  fallback clipboard, boot section dibungkus pcall. fitur/logika lain tidak diubah.
]]

-- ============================================================
-- SECTION: SERVICES & CLEANUP
-- ============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local lp = Players.LocalPlayer

-- cleanup guard: hapus instance lama kalau script di-execute ulang
if _G._LiveScanner_v10_Cleanup then pcall(_G._LiveScanner_v10_Cleanup) end
for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
    if g.Name == "FullLiveScan" then g:Destroy() end
end
for _, g in ipairs(lp:WaitForChild("PlayerGui"):GetChildren()) do
    if g.Name == "FullLiveScan" then g:Destroy() end
end

-- ============================================================
-- SECTION: CONFIG
-- ============================================================
local CFG = {
    ScanInterval = 1.5, RenderInterval = 1.5, InfoInterval = 5, HookInterval = 5, ButtonScanInterval = 2,
    MaxLines = 25, MaxBuffer = 400, Radius = 100,

    -- INBOUND (server -> client)
    TrackAttrs = true, TrackStats = true, TrackHumanoid = true,
    TrackModels = false,
    TrackRemotes = true, TrackRemoteFunctions = true, TrackInventory = true,
    TrackPosition = false, TrackPlayers = true,
    TrackHealth = true, TrackNetwork = false, TrackToolEquip = true, TrackButtons = true,

    -- OUTBOUND (client -> server)
    TrackOutbound = true,       -- FireServer hook
    TrackGlobalAttr = false,    -- SetAttribute hook on all instances (noisy, opt-in)
    TrackRequires = true,       -- require() hook
    TrackPlayerEvents = true,   -- PlayerAdded/Removing/CharacterAdded
    TrackBackpack = true,       -- Backpack + / - items

    AlertMode = true, CurrencyRadar = true, SpeedHackDetect = true, PatternDetect = true,

    IgnoreRemotes = {
        "ReplicaSet", "Replica", "ReplicaCreated", "ReplicaRemoved", "CatchAnnounce", "CastRoll", "CleanupCast",
        "ShowDamage", "PlaySound", "HitEffect", "Damage", "UpdateHealth", "CameraShake", "PlayAnim"
    },
    IgnorePatterns = {
        "replica", "heartbeat", "tick", "ping", "update", "coinschanged", "leaderboard", "income", "effect", "sound"
    },
    IgnoreAttrPatterns = {
        "LBTHIncomeLastTick", "LastDailyReset", "_lemonade", "Presentation", "Internal", "Temp", "LastTick", "LastUpdate", "LastSync",
    },
    IgnoreEquipItems = {
        "Humanoid", "HumanoidRootPart", "Head", "Torso", "LowerTorso", "UpperTorso",
        "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "Health", "Animate", "Body Colors", "Shirt", "Pants", "Accessory",
        "Right Arm", "Left Arm", "Right Leg", "Left Leg", "CharacterMesh",
    },

    ButtonKeywords = {
        "tap", "click", "arrow", "skill", "cast", "reel", "hook", "fish", "left", "right",
        "up", "down", "power", "hit", "strike", "qte", "minigame", "ribbon", "doublecast", "execute", "reset",
    },
    ButtonBlacklist = {
        "buy", "close", "menu", "settings", "exit", "shop", "trade", "sell", "invite", "claim",
        "rod", "quest", "stats", "index", "store", "home", "back",
    },

    SmartDiff = true, DedupeRemote = true, DedupeWindow = 3,
    NumericTolerance = 0.5, HighFreqThreshold = 8, HighFreqWindow = 3, MaxArgLen = 200,
    SilentResetTime = 10,
    SpeedWarnCooldown = 5,
    SetAttrCooldown = 0.1,
    ClipboardCap = 80000,
    TeleportThreshold = 50,
    ModelLogBudget = 20,

    AlertKeywords = {"admin","kick","ban","give","cash","coin","token","prize","reward","hack","exploit","detected","victory"},
    CurrencyKeywords = {"cash","coin","gem","token","money","gold","credit","crystal","diamond","point","xp","level"},
    PatternKeywords = {"admin","give","set","hack","cheat","debug","test","backdoor","grant","unlock","free"},
    MaxSpeedNormal = 100, MaxJumpNormal = 150,
}

local State = {running = true, paused = false, destroyed = false}

-- forward declaration (dipakai event handler sebelum fungsinya didefinisikan)
local renderLog, setupBackpack

-- ============================================================
-- SECTION: CONNECTION TRACKER
-- ============================================================
local _conns = {}
local function trackConn(c) table.insert(_conns, c); return c end
local function disconnectAll()
    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    _conns = {}
end

-- ============================================================
-- SECTION: AUTO-FIT LAYAR
-- ============================================================
local VIEW = workspace.CurrentCamera.ViewportSize
local SCALE_W = VIEW.X / 720
local SCALE_H = VIEW.Y / 1280
local UI_SCALE = math.min(SCALE_W, SCALE_H)
if UI_SCALE < 0.45 then UI_SCALE = 0.45 end
if UI_SCALE > 1.2 then UI_SCALE = 1.2 end

local BASE_W = 300
local BASE_H = 420
local FRAME_W = math.floor(BASE_W * UI_SCALE)
local FRAME_H = math.floor(BASE_H * UI_SCALE)
if FRAME_W > VIEW.X * 0.9 then FRAME_W = math.floor(VIEW.X * 0.9) end
if FRAME_H > VIEW.Y * 0.85 then FRAME_H = math.floor(VIEW.Y * 0.85) end
if FRAME_W < 180 then FRAME_W = 180 end
if FRAME_H < 250 then FRAME_H = 250 end

local FONT_SIZE = math.max(8, math.floor(11 * UI_SCALE))
local TITLE_SIZE = math.max(10, math.floor(13 * UI_SCALE))

local startX = math.max(5, math.floor(VIEW.X * 0.02))
local startY = math.max(30, math.floor(VIEW.Y * 0.05))
if startY + FRAME_H > VIEW.Y - 10 then
    startY = math.max(10, VIEW.Y - FRAME_H - 10)
end

-- ============================================================
-- SECTION: LOG BUFFER
-- ============================================================
local Logs = {entries = {}, totalCount = 0, categoryCount = {}}

local function pushLog(text, color, category)
    if State.destroyed then return end
    category = category or "SYS" -- patch: default kategori biar categoryCount tidak error
    local entry = {
        text = "[" .. os.date("%H:%M:%S") .. "] " .. text,
        raw = text, color = color or Color3.fromRGB(200,200,200), category = category, time = os.clock(),
    }
    table.insert(Logs.entries, entry)
    if #Logs.entries > CFG.MaxBuffer then table.remove(Logs.entries, 1) end
    Logs.totalCount = Logs.totalCount + 1
    Logs.categoryCount[category] = (Logs.categoryCount[category] or 0) + 1
end

-- ============================================================
-- SECTION: HELPERS
-- ============================================================
local function truncate(s, max)
    s = tostring(s)
    if #s > max then return string.sub(s, 1, max) .. "...(+" .. (#s - max) .. ")" end
    return s
end

local function fmt(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    if typeof(v) == "Instance" then return v.Name end -- patch: type -> typeof (type() tidak pernah return "Instance")
    if type(v) == "table" then
        local p = {}
        for k, val in pairs(v) do table.insert(p, tostring(k).."="..fmt(val, depth + 1)) end
        return "{"..table.concat(p,",").."}"
    end
    return tostring(v)
end

local function hasKwWord(text, list)
    local low = string.lower(text)
    for _, kw in ipairs(list) do
        local kwLow = string.lower(kw)
        local padded = " " .. low .. " "
        if string.find(padded, "[^%a%d]" .. kwLow .. "[^%a%d]") then return kw end
    end
    return nil
end

local function isIgnoredName(name, patterns)
    local low = string.lower(name)
    for _, pat in ipairs(patterns) do
        if string.find(low, string.lower(pat), 1, true) then return true end
    end
    return false
end

local function isIgnoredEquipItem(name)
    for _, item in ipairs(CFG.IgnoreEquipItems) do
        if name == item then return true end
    end
    return false
end

local function numAlmostEqual(a, b, tol)
    tol = tol or CFG.NumericTolerance
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    return math.abs(a - b) < tol
end

-- addLog: tambah penanda alert kalau kena keyword
local function addLog(text, color, category)
    if State.destroyed then return end
    if CFG.AlertMode then
        local kw = hasKwWord(text, CFG.AlertKeywords)
        if kw then
            color = Color3.fromRGB(255, 60, 60)
            text = "🚨 ["..kw.."] "..text
        end
    end
    pushLog(text, color, category or "SYS")
end

-- ============================================================
-- SECTION: GUI - FRAME & HEADER
-- ============================================================
local C = {
    Bg          = Color3.fromRGB(16, 18, 24),
    BgTop       = Color3.fromRGB(26, 30, 40),
    Header      = Color3.fromRGB(22, 25, 34),
    TabBar      = Color3.fromRGB(20, 23, 31),
    TabActive   = Color3.fromRGB(38, 44, 58),
    Search      = Color3.fromRGB(22, 25, 34),
    Accent      = Color3.fromRGB(88, 166, 255),
    AccentDim   = Color3.fromRGB(60, 110, 180),
    Success     = Color3.fromRGB(72, 190, 120),
    Warning     = Color3.fromRGB(220, 160, 60),
    Danger      = Color3.fromRGB(220, 76, 76),
    Text        = Color3.fromRGB(226, 230, 238),
    SubText     = Color3.fromRGB(140, 146, 160),
    RowBg       = Color3.fromRGB(24, 27, 36),
    RowBgAlt    = Color3.fromRGB(28, 32, 42),
}

local gui = Instance.new("ScreenGui")
gui.Name = "FullLiveScan"
gui.ResetOnSpawn = false
gui.DisplayOrder = 997
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
frame.Position = UDim2.new(0, startX, 0, startY)
frame.BackgroundColor3 = C.Bg
frame.BackgroundTransparency = 0
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local frameGrad = Instance.new("UIGradient", frame)
frameGrad.Rotation = 90
frameGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.BgTop),
    ColorSequenceKeypoint.new(1, C.Bg),
})

local stroke = Instance.new("UIStroke", frame)
stroke.Color = C.Accent
stroke.Thickness = 1.4
stroke.Transparency = 0.55
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundTransparency = 1
header.Parent = frame

local titleContainer = Instance.new("Frame")
titleContainer.Size = UDim2.new(1, -104, 1, 0)
titleContainer.Position = UDim2.new(0, 10, 0, 0)
titleContainer.BackgroundTransparency = 1
titleContainer.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, math.floor(14 * UI_SCALE))
title.Position = UDim2.new(0, 0, 0, 3)
title.BackgroundTransparency = 1
title.Text = "⚡ LIVE SCAN v11.0"
title.TextColor3 = C.Accent
title.Font = Enum.Font.GothamBold
title.TextSize = TITLE_SIZE
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleContainer

local watermark = Instance.new("TextLabel")
watermark.Size = UDim2.new(1, 0, 0, math.floor(10 * UI_SCALE))
watermark.Position = UDim2.new(0, 0, 0, math.floor(16 * UI_SCALE))
watermark.BackgroundTransparency = 1
watermark.Text = "@in666ar | bidir"
watermark.TextColor3 = C.SubText
watermark.Font = Enum.Font.GothamBold
watermark.TextSize = math.max(7, math.floor(9 * UI_SCALE))
watermark.TextXAlignment = Enum.TextXAlignment.Left
watermark.Parent = titleContainer

local powerBtn = Instance.new("TextButton")
powerBtn.Size = UDim2.new(0, 40, 0, 24)
powerBtn.Position = UDim2.new(1, -102, 0, 3)
powerBtn.BackgroundColor3 = C.Success
powerBtn.TextColor3 = Color3.new(1,1,1)
powerBtn.Text = "AUTO"
powerBtn.Font = Enum.Font.GothamBold
powerBtn.TextSize = FONT_SIZE
powerBtn.BorderSizePixel = 0
powerBtn.AutoButtonColor = false
powerBtn.Parent = header
Instance.new("UICorner", powerBtn).CornerRadius = UDim.new(0, 6)

powerBtn.MouseButton1Click:Connect(function()
    addLog("⚠️ Mode AUTO aktif, scanner berjalan terus.", Color3.fromRGB(255,150,150), "SYS")
end)

local collapse = Instance.new("TextButton")
collapse.Size = UDim2.new(0, 24, 0, 24)
collapse.Position = UDim2.new(1, -58, 0, 3)
collapse.BackgroundColor3 = C.RowBgAlt
collapse.TextColor3 = C.Text
collapse.Text = "−"
collapse.Font = Enum.Font.GothamBold
collapse.TextSize = 15
collapse.BorderSizePixel = 0
collapse.AutoButtonColor = false
collapse.Parent = header
Instance.new("UICorner", collapse).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 3)
closeBtn.BackgroundColor3 = C.Danger
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Text = "×"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 17
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = Color3.fromRGB(245, 100, 100) end)
closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = C.Danger end)
collapse.MouseEnter:Connect(function() collapse.BackgroundColor3 = Color3.fromRGB(48, 54, 70) end)
collapse.MouseLeave:Connect(function() collapse.BackgroundColor3 = C.RowBgAlt end)

-- fullKill: matikan semua loop, koneksi, dan GUI
local function fullKill()
    State.destroyed = true
    State.running = false
    disconnectAll()
    for r, conn in pairs(_G._LS_hooks or {}) do
        pcall(function()
            if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
        end)
    end
    _G._LS_hooks = nil
    pcall(function() gui:Destroy() end)
end
_G._LiveScanner_v10_Cleanup = fullKill
closeBtn.MouseButton1Click:Connect(fullKill)

-- ============================================================
-- SECTION: GUI - TAB BAR
-- ============================================================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -10, 0, 26)
tabBar.Position = UDim2.new(0, 5, 0, 34)
tabBar.BackgroundColor3 = C.TabBar
tabBar.BorderSizePixel = 0
tabBar.Parent = frame
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)

local tabs = {
    {name="LOG", color=Color3.fromRGB(100, 200, 255)},
    {name="CFG", color=Color3.fromRGB(255, 200, 100)},
    {name="INFO", color=Color3.fromRGB(200, 255, 100)},
    {name="HOOK", color=Color3.fromRGB(255, 130, 200)},
    {name="BTN", color=Color3.fromRGB(255, 220, 100)},
    {name="GAME", color=Color3.fromRGB(150, 255, 200)},
}
local activeTab = "LOG"
local tabButtons = {}

for i, t in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#tabs, -3, 1, -4)
    btn.Position = UDim2.new((i-1)/#tabs, 1.5, 0, 2)
    btn.BackgroundColor3 = i == 1 and C.TabActive or C.TabBar
    btn.TextColor3 = t.color
    btn.Text = t.name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = math.max(8, FONT_SIZE - 1)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    tabButtons[t.name] = btn
end

-- ============================================================
-- SECTION: GUI - SEARCH & FILTER
-- ============================================================
local searchFrame = Instance.new("Frame")
searchFrame.Size = UDim2.new(1, -10, 0, 26)
searchFrame.Position = UDim2.new(0, 5, 0, 64)
searchFrame.BackgroundColor3 = C.Search
searchFrame.BorderSizePixel = 0
searchFrame.Parent = frame
Instance.new("UICorner", searchFrame).CornerRadius = UDim.new(0, 6)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -64, 1, -4)
searchBox.Position = UDim2.new(0, 8, 0, 2)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "🔍 Cari..."
searchBox.TextColor3 = C.Text
searchBox.PlaceholderColor3 = C.SubText
searchBox.Font = Enum.Font.Code
searchBox.TextSize = FONT_SIZE
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchFrame

local filterBtn = Instance.new("TextButton")
filterBtn.Size = UDim2.new(0, 54, 1, -4)
filterBtn.Position = UDim2.new(1, -58, 0, 2)
filterBtn.BackgroundColor3 = C.AccentDim
filterBtn.TextColor3 = Color3.new(1,1,1)
filterBtn.Text = "ALL"
filterBtn.Font = Enum.Font.GothamBold
filterBtn.TextSize = math.max(8, FONT_SIZE - 1)
filterBtn.BorderSizePixel = 0
filterBtn.AutoButtonColor = false
filterBtn.Parent = searchFrame
Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0, 5)

-- patch: tambah PLAYER & MODEL (kategori ini dipakai addLog tapi sebelumnya tidak bisa difilter)
local filterCycle = {
    "ALL","REMOTE","OUT","RF","ATTR","STAT","HEALTH","SPEED","CURRENCY","PATTERN",
    "MODULE","EVENT","INV","TOOL","BTN","NET","ANOMALY","PLAYER","MODEL","SYS"
}
local filterIdx = 1
local searchText = ""

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = string.lower(searchBox.Text)
    if activeTab == "LOG" then renderLog() end
end)
filterBtn.MouseButton1Click:Connect(function()
    filterIdx = filterIdx + 1
    if filterIdx > #filterCycle then filterIdx = 1 end
    filterBtn.Text = filterCycle[filterIdx]
    renderLog() -- patch: refresh langsung saat filter diganti
end)

-- ============================================================
-- SECTION: GUI - CONTENT (scroll per tab)
-- ============================================================
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 1, -142)
content.Position = UDim2.new(0, 5, 0, 94)
content.BackgroundTransparency = 1
content.Parent = frame

local function makeScroll()
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 4
    s.ScrollBarImageColor3 = C.Accent
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Parent = content
    local l = Instance.new("UIListLayout", s)
    l.Padding = UDim.new(0, 3)
    return s
end

local scroll = makeScroll(); scroll.Visible = true
local cfgFrame = makeScroll(); cfgFrame.Visible = false
local infoFrame = makeScroll(); infoFrame.Visible = false
local hookFrame = makeScroll(); hookFrame.Visible = false
local btnFrame = makeScroll(); btnFrame.Visible = false
local gameFrame = makeScroll(); gameFrame.Visible = false

-- ============================================================
-- SECTION: GUI - FOOTER (PAUSE / CLEAR / COPY ALL)
-- ============================================================
local BTN_GAP = 5
local BTN_TOTAL_W = FRAME_W - 10
local BTN_W = math.floor((BTN_TOTAL_W - BTN_GAP * 2) / 3)
local BTN_H = 26

local btnPause = Instance.new("TextButton")
btnPause.Size = UDim2.new(0, BTN_W, 0, BTN_H)
btnPause.Position = UDim2.new(0, 5, 1, -30)
btnPause.BackgroundColor3 = C.Success
btnPause.TextColor3 = Color3.new(1,1,1)
btnPause.Text = "PAUSE"
btnPause.Font = Enum.Font.GothamBold
btnPause.TextSize = FONT_SIZE
btnPause.BorderSizePixel = 0
btnPause.AutoButtonColor = false
btnPause.Parent = frame
Instance.new("UICorner", btnPause).CornerRadius = UDim.new(0, 6)

local btnClear = Instance.new("TextButton")
btnClear.Size = UDim2.new(0, BTN_W, 0, BTN_H)
btnClear.Position = UDim2.new(0, 5 + BTN_W + BTN_GAP, 1, -30)
btnClear.BackgroundColor3 = C.Danger
btnClear.TextColor3 = Color3.new(1,1,1)
btnClear.Text = "CLEAR"
btnClear.Font = Enum.Font.GothamBold
btnClear.TextSize = FONT_SIZE
btnClear.BorderSizePixel = 0
btnClear.AutoButtonColor = false
btnClear.Parent = frame
Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 6)

local btnCopy = Instance.new("TextButton")
btnCopy.Size = UDim2.new(0, BTN_W, 0, BTN_H)
btnCopy.Position = UDim2.new(0, 5 + (BTN_W + BTN_GAP) * 2, 1, -30)
btnCopy.BackgroundColor3 = Color3.fromRGB(50, 90, 170)
btnCopy.TextColor3 = Color3.new(1,1,1)
btnCopy.Text = "COPY ALL"
btnCopy.Font = Enum.Font.GothamBold
btnCopy.TextSize = FONT_SIZE
btnCopy.BorderSizePixel = 0
btnCopy.AutoButtonColor = false
btnCopy.Parent = frame
Instance.new("UICorner", btnCopy).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- SECTION: GUI - DRAG & COLLAPSE
-- ============================================================
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
header.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local collapsed = false
collapse.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    if collapsed then
        frame.Size = UDim2.new(0, FRAME_W, 0, 30)
        collapse.Text = "+"
    else
        frame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
        collapse.Text = "−"
    end
end)

-- ============================================================
-- SECTION: RENDER - LOG
-- ============================================================
function renderLog() -- assign ke forward declaration
    if State.destroyed then return end
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local shown = 0
    local curFilter = filterCycle[filterIdx]
    for i = #Logs.entries, 1, -1 do
        if shown >= CFG.MaxLines then break end
        local e = Logs.entries[i]
        local pass = true
        if curFilter ~= "ALL" and e.category ~= curFilter then pass = false end
        if pass and searchText ~= "" and not string.find(string.lower(e.text), searchText) then pass = false end
        if pass then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -4, 0, math.max(13, FONT_SIZE + 3))
            lbl.BackgroundColor3 = (shown % 2 == 0) and C.RowBg or C.RowBgAlt
            lbl.BackgroundTransparency = 0.35
            lbl.Text = "  " .. e.text
            lbl.TextColor3 = e.color
            lbl.Font = Enum.Font.Code
            lbl.TextSize = math.max(8, FONT_SIZE - 1)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.LayoutOrder = -i
            lbl.BorderSizePixel = 0
            lbl.Parent = scroll
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
            shown = shown + 1
        end
    end
end

-- ============================================================
-- SECTION: CFG TAB (toggle)
-- ============================================================
local toggleRefs = {}
local function makeToggle(name, key, parent, onChanged)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 24)
    row.BackgroundColor3 = C.RowBg
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = C.Text
    lbl.Font = Enum.Font.Code
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 1, -6)
    btn.Position = UDim2.new(1, -44, 0, 3)
    btn.BackgroundColor3 = CFG[key] and C.Success or Color3.fromRGB(80, 40, 40)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Text = CFG[key] and "ON" or "OFF"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = math.max(8, FONT_SIZE - 1)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        btn.BackgroundColor3 = CFG[key] and C.Success or Color3.fromRGB(80, 40, 40)
        btn.Text = CFG[key] and "ON" or "OFF"
        if onChanged then onChanged(CFG[key]) end
    end)
    toggleRefs[key] = btn
end

local resetSnapshotFuncs = {}

makeToggle("Player Attributes", "TrackAttrs", cfgFrame, function(v)
    if not v then for f in pairs(resetSnapshotFuncs.attrs or {}) do end end
end)
makeToggle("Leaderstats", "TrackStats", cfgFrame)
makeToggle("Humanoid", "TrackHumanoid", cfgFrame)
makeToggle("Models Sekitar", "TrackModels", cfgFrame)
makeToggle("Remote Events (IN)", "TrackRemotes", cfgFrame)
makeToggle("Remote Functions (IN)", "TrackRemoteFunctions", cfgFrame)
makeToggle("Inventory", "TrackInventory", cfgFrame)
makeToggle("Position", "TrackPosition", cfgFrame)
makeToggle("Track Players", "TrackPlayers", cfgFrame)
makeToggle("Track Health", "TrackHealth", cfgFrame)
makeToggle("Track Network", "TrackNetwork", cfgFrame)
makeToggle("Track Tool Equip", "TrackToolEquip", cfgFrame)
makeToggle("Track UI Buttons", "TrackButtons", cfgFrame)
makeToggle("🔥 FireServer (OUT)", "TrackOutbound", cfgFrame)
makeToggle("🔥 require() Hook", "TrackRequires", cfgFrame)
makeToggle("🔥 Global SetAttribute", "TrackGlobalAttr", cfgFrame)
makeToggle("🔥 Player Events", "TrackPlayerEvents", cfgFrame)
makeToggle("🔥 Backpack Watch", "TrackBackpack", cfgFrame)
makeToggle("Alert Mode", "AlertMode", cfgFrame)
makeToggle("Currency Radar", "CurrencyRadar", cfgFrame)
makeToggle("SpeedHack Detect", "SpeedHackDetect", cfgFrame)
makeToggle("Pattern Detect", "PatternDetect", cfgFrame)

-- ============================================================
-- SECTION: RENDER - INFO
-- ============================================================
local function renderInfo()
    if State.destroyed then return end
    for _, c in ipairs(infoFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local data = {
        "PlaceId: " .. game.PlaceId,
        "JobId: " .. tostring(game.JobId):sub(1, 20) .. "...",
        "Player: " .. lp.Name,
        "UserId: " .. lp.UserId,
        "Total logs: " .. tostring(Logs.totalCount),
        "Scanner: AUTO-ON v11.0 (BIDIRECTIONAL)",
        "--- Category Count ---",
    }
    for k, v in pairs(Logs.categoryCount) do
        if v > 0 then table.insert(data, "  " .. k .. ": " .. v) end
    end
    table.insert(data, "--- Player Attributes ---")
    local count = 0
    for k, v in pairs(lp:GetAttributes()) do
        if count < 15 then
            table.insert(data, "  " .. k .. " = " .. tostring(v))
            count = count + 1
        end
    end
    for _, txt in ipairs(data) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(13, FONT_SIZE + 3))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = "  " .. txt
        lbl.TextColor3 = Color3.fromRGB(200, 220, 255)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0
        lbl.Parent = infoFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end
end

-- ============================================================
-- SECTION: RENDER - GAME
-- ============================================================
local function renderGame()
    if State.destroyed then return end
    for _, c in ipairs(gameFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local data = {
        "🎮 GAME INFORMATION", "─────────────────────",
        "Name: " .. game.PlaceId,
        "PlaceId: " .. game.PlaceId,
        "Players: " .. #Players:GetPlayers(), "",
        "👤 YOU", "─────────────────────",
        "Name: " .. lp.Name,
        "Display: " .. lp.DisplayName,
        "UserId: " .. lp.UserId, "",
        "💻 DEVICE", "─────────────────────",
        "Type: " .. (UIS.TouchEnabled and UIS.KeyboardEnabled and "Tablet" or UIS.TouchEnabled and "Mobile" or "PC"),
        "📦 PLAYERS ONLINE", "─────────────────────",
    }
    for _, p in ipairs(Players:GetPlayers()) do table.insert(data, "  " .. p.Name) end
    for _, txt in ipairs(data) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(13, FONT_SIZE + 3))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = "  " .. txt
        lbl.TextColor3 = Color3.fromRGB(150, 255, 200)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0
        lbl.Parent = gameFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end
end

-- ============================================================
-- SECTION: HOOK STATE & RENDER - HOOK TAB
-- ============================================================
_G._LS_hooks = _G._LS_hooks or {}
local hookedRemotes = _G._LS_hooks
local remoteStats = {}
local outStats = {}
local remoteLastArgs = {}
local remoteLastTime = {}
local seenModules = {}

local function renderHook()
    if State.destroyed then return end
    for _, c in ipairs(hookFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local events, functions = {}, {}
    for r in pairs(hookedRemotes) do
        if typeof(r) == "Instance" then -- patch: guard biar aman kalau key bukan Instance
            if r:IsA("RemoteEvent") then table.insert(events, r.Name)
            elseif r:IsA("RemoteFunction") then table.insert(functions, r.Name) end
        end
    end
    table.sort(events)
    table.sort(functions)

    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, -4, 0, math.max(13, FONT_SIZE + 3))
    hdr.BackgroundColor3 = C.RowBgAlt
    hdr.BackgroundTransparency = 0.2
    hdr.Text = "  📡 EV:" .. #events .. " | 📤 RF:" .. #functions .. " | ⬆ OUT:" .. (function()
        local n=0; for _ in pairs(outStats) do n=n+1 end; return n
    end)() .. " | 📦 MOD:" .. (function() local n=0; for _ in pairs(seenModules) do n=n+1 end; return n end)()
    hdr.TextColor3 = Color3.fromRGB(255, 130, 200)
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = FONT_SIZE
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.BorderSizePixel = 0
    hdr.Parent = hookFrame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 4)

    local hdrEv = Instance.new("TextLabel")
    hdrEv.Size = UDim2.new(1, -4, 0, math.max(12, FONT_SIZE + 1))
    hdrEv.BackgroundTransparency = 1
    hdrEv.Text = "  ── RemoteEvents (" .. #events .. ") ──"
    hdrEv.TextColor3 = Color3.fromRGB(210, 210, 210)
    hdrEv.Font = Enum.Font.GothamBold
    hdrEv.TextSize = FONT_SIZE
    hdrEv.TextXAlignment = Enum.TextXAlignment.Left
    hdrEv.Parent = hookFrame

    for _, txt in ipairs(events) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(12, FONT_SIZE + 1))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = "  📡 " .. txt
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0
        lbl.Parent = hookFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end

    local hdrFn = Instance.new("TextLabel")
    hdrFn.Size = UDim2.new(1, -4, 0, math.max(12, FONT_SIZE + 1))
    hdrFn.BackgroundTransparency = 1
    hdrFn.Text = "  ── RemoteFunctions (" .. #functions .. ") ──"
    hdrFn.TextColor3 = Color3.fromRGB(255, 150, 100)
    hdrFn.Font = Enum.Font.GothamBold
    hdrFn.TextSize = FONT_SIZE
    hdrFn.TextXAlignment = Enum.TextXAlignment.Left
    hdrFn.Parent = hookFrame

    for _, txt in ipairs(functions) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(12, FONT_SIZE + 1))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = "  📤 " .. txt
        lbl.TextColor3 = Color3.fromRGB(255, 180, 120)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0
        lbl.Parent = hookFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end

    -- modules loaded
    local hdrMod = Instance.new("TextLabel")
    hdrMod.Size = UDim2.new(1, -4, 0, math.max(12, FONT_SIZE + 1))
    hdrMod.BackgroundTransparency = 1
    hdrMod.Text = "  ── Modules Loaded ──"
    hdrMod.TextColor3 = Color3.fromRGB(180, 130, 255)
    hdrMod.Font = Enum.Font.GothamBold
    hdrMod.TextSize = FONT_SIZE
    hdrMod.TextXAlignment = Enum.TextXAlignment.Left
    hdrMod.Parent = hookFrame
    local modList = {}
    for k in pairs(seenModules) do table.insert(modList, k) end
    table.sort(modList)
    for _, txt in ipairs(modList) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(12, FONT_SIZE + 1))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = "  📦 " .. txt
        lbl.TextColor3 = Color3.fromRGB(200, 170, 255)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0
        lbl.Parent = hookFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end
end

-- ============================================================
-- SECTION: HOOK - INBOUND RemoteEvent (OnClientEvent)
-- ============================================================
local function hookRemoteEvent(r)
    if hookedRemotes[r] then return end
    if isIgnoredName(r.Name, CFG.IgnoreRemotes) or isIgnoredName(r.Name, CFG.IgnorePatterns) then
        hookedRemotes[r] = "IGNORED"
        return
    end

    remoteStats[r] = {count = 0, first = os.clock(), timestamps = {}, skipped = 0, silent = false, lastHit = 0}
    remoteLastArgs[r] = nil
    remoteLastTime[r] = 0

    local conn = r.OnClientEvent:Connect(function(...)
        if State.destroyed or State.paused then return end
        if not CFG.TrackRemotes then return end

        local args = {...}
        local rs = remoteStats[r]
        rs.count = rs.count + 1

        -- hitung frekuensi (anti-spam)
        local now = os.clock()
        rs.lastHit = now
        table.insert(rs.timestamps, now)
        while #rs.timestamps > 50 do table.remove(rs.timestamps, 1) end
        local recent = 0
        for _, t in ipairs(rs.timestamps) do
            if now - t < CFG.HighFreqWindow then recent = recent + 1 end
        end

        if recent >= CFG.HighFreqThreshold then
            if not rs.silent then
                rs.silent = true
                addLog("🔇 IN-SILENT: "..r.Name, Color3.fromRGB(150, 150, 200), "SYS")
            end
            rs.skipped = (rs.skipped or 0) + 1
            return
        end

        local argStr = ""
        for _, a in ipairs(args) do argStr = argStr .. "|" .. fmt(a) end
        argStr = truncate(argStr, CFG.MaxArgLen)

        -- dedupe argumen sama dalam window
        if CFG.DedupeRemote then
            if remoteLastArgs[r] == argStr and (now - (remoteLastTime[r] or 0)) < CFG.DedupeWindow then
                rs.skipped = (rs.skipped or 0) + 1
                return
            end
            remoteLastArgs[r] = argStr
            remoteLastTime[r] = now
        end

        addLog("⬇ " .. r.Name .. " | " .. argStr, Color3.fromRGB(255, 130, 200), "REMOTE")
    end)
    hookedRemotes[r] = conn

    -- pattern detect pada remote baru
    if CFG.PatternDetect then
        local low = string.lower(r.Name)
        for _, p in ipairs(CFG.PatternKeywords) do
            if string.find(low, p, 1, true) then
                addLog("🔍 Suspicious remote: " .. r.Name, C.Danger, "PATTERN")
                break
            end
        end
    end
end

-- ============================================================
-- SECTION: HOOK - OUTBOUND FireServer / InvokeServer
-- ============================================================
local function getOutStats(r)
    if not outStats[r] then
        outStats[r] = {count = 0, timestamps = {}, silent = false, lastHit = 0, lastArgs = nil, lastTime = 0}
    end
    return outStats[r]
end

local function onFireServer(r, args)
    if not CFG.TrackOutbound or State.paused or State.destroyed then return end
    if isIgnoredName(r.Name, CFG.IgnoreRemotes) or isIgnoredName(r.Name, CFG.IgnorePatterns) then return end

    local rs = getOutStats(r)
    local now = os.clock()
    rs.count = rs.count + 1
    rs.lastHit = now
    table.insert(rs.timestamps, now)
    while #rs.timestamps > 50 do table.remove(rs.timestamps, 1) end

    local recent = 0
    for _, t in ipairs(rs.timestamps) do
        if now - t < CFG.HighFreqWindow then recent = recent + 1 end
    end
    if recent >= CFG.HighFreqThreshold then
        if not rs.silent then
            rs.silent = true
            addLog("🔇 OUT-SILENT: " .. r.Name, Color3.fromRGB(150, 150, 200), "SYS")
        end
        return
    end

    local argStr = ""
    for _, a in ipairs(args) do argStr = argStr .. "|" .. fmt(a) end
    argStr = truncate(argStr, CFG.MaxArgLen)

    if CFG.DedupeRemote and rs.lastArgs == argStr and (now - rs.lastTime) < CFG.DedupeWindow then
        return
    end
    rs.lastArgs = argStr
    rs.lastTime = now

    addLog("⬆ " .. r.Name .. " | " .. argStr, Color3.fromRGB(255, 200, 50), "OUT")
end

local function onInvokeServer(r, args)
    if not CFG.TrackRemoteFunctions or State.paused or State.destroyed then return end
    if isIgnoredName(r.Name, CFG.IgnoreRemotes) or isIgnoredName(r.Name, CFG.IgnorePatterns) then return end
    local argStr = ""
    for _, a in ipairs(args) do argStr = argStr .. "|" .. fmt(a) end
    addLog("📤 RF " .. r.Name .. " | " .. truncate(argStr, CFG.MaxArgLen), Color3.fromRGB(255, 150, 100), "RF")
end

local function hookRemoteFunction(r)
    if hookedRemotes[r] then return end
    if isIgnoredName(r.Name, CFG.IgnoreRemotes) or isIgnoredName(r.Name, CFG.IgnorePatterns) then
        hookedRemotes[r] = "IGNORED"
        return
    end
    hookedRemotes[r] = "FUNCTION"
end

-- ============================================================
-- SECTION: UNIFIED NAMECALL HOOK (satu-satunya tempat hook namecall)
-- ============================================================
local _lastSetAttrLog = 0
local function installNamecallHook()
    -- patch: dispatcher di-refresh tiap execute. hook asli cuma dipasang sekali (guard di bawah),
    -- jadi tanpa ini hook lama masih nunjuk ke State/GUI lama yang sudah destroyed.
    _G._LS_onNamecall = function(self, method, args)
        if typeof(self) ~= "Instance" then return end

        if method == "FireServer" and self:IsA("RemoteEvent") then
            onFireServer(self, args)
        elseif method == "InvokeServer" and self:IsA("RemoteFunction") then
            onInvokeServer(self, args)
        elseif method == "SetAttribute" and CFG.TrackGlobalAttr and not State.paused then
            if self ~= lp and not self:IsDescendantOf(lp) then
                local now = os.clock()
                if now - _lastSetAttrLog > CFG.SetAttrCooldown then
                    _lastSetAttrLog = now
                    pcall(function()
                        addLog("🏷 " .. self:GetFullName() .. "." .. tostring(args[1]) .. " = " .. fmt(args[2]), C.Accent, "ATTR")
                    end)
                end
            end
        end
    end

    if not (hookmetamethod and getnamecallmethod) then
        addLog("⚠️ hookmetamethod not available", C.Danger, "SYS")
        return
    end
    if _G._LS_NamecallInstalled then return end -- guard anti double-hook
    _G._LS_NamecallInstalled = true

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        -- patch: '...' diambil di fungsi vararg ini (bukan di dalam closure pcall, itu bikin compile error)
        if method == "FireServer" or method == "InvokeServer" or method == "SetAttribute" then
            local dispatch = _G._LS_onNamecall
            if dispatch then
                local args = {...}
                pcall(dispatch, self, method, args)
            end
            -- patch: dispatcher memanggil method lain (IsA dll) yang menimpa namecall method, kembalikan
            if setnamecallmethod then pcall(setnamecallmethod, method) end
        end

        return oldNamecall(self, ...)
    end)
end

-- ============================================================
-- SECTION: REQUIRE HOOK (satu-satunya tempat hook require)
-- ============================================================
local function installRequireHook()
    local env = getgenv and getgenv() or _G

    -- patch: dispatcher di-refresh tiap execute (flag _LS_require_hooked tetap dipakai)
    env._LS_onRequire = function(m)
        if CFG.TrackRequires and not State.paused and not State.destroyed then
            if typeof(m) == "Instance" then
                local path = m:GetFullName()
                if path and #path < 120 and not seenModules[path] then
                    seenModules[path] = true
                    addLog("📦 require: " .. path, Color3.fromRGB(180, 130, 255), "MODULE")
                end
            end
        end
    end

    local ok, err = pcall(function()
        if env._LS_require_hooked then return end -- guard anti double-hook
        env._LS_require_hooked = true
        local oldRequire = env.require or require
        env.require = function(m)
            local d = env._LS_onRequire
            if d then pcall(d, m) end
            return oldRequire(m)
        end
    end)
    if not ok then
        addLog("⚠️ require hook failed: " .. tostring(err), C.Danger, "SYS")
    end
end

-- ============================================================
-- SECTION: REMOTE SCAN (initial + dynamic)
-- ============================================================
local function scanRemotes(parent, depth)
    if depth > 6 then return end
    for _, obj in ipairs(parent:GetChildren()) do
        if State.destroyed then return end
        if obj:IsA("RemoteEvent") then hookRemoteEvent(obj)
        elseif obj:IsA("RemoteFunction") then hookRemoteFunction(obj) end
        pcall(function() scanRemotes(obj, depth + 1) end)
    end
end

local function setupDynamicRemoteWatch()
    trackConn(RS.DescendantAdded:Connect(function(obj)
        if State.destroyed then return end
        task.defer(function()
            if State.destroyed then return end
            pcall(function()
                if obj:IsA("RemoteEvent") then hookRemoteEvent(obj)
                elseif obj:IsA("RemoteFunction") then hookRemoteFunction(obj) end
            end)
        end)
    end))
end

-- ============================================================
-- SECTION: BUTTON SCANNER & RENDER - BTN TAB
-- ============================================================
local function scanButtons()
    local found = {}
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return found end
    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
            local skip = false
            if obj.AbsoluteSize.X < 10 or obj.AbsoluteSize.Y < 10 then skip = true end
            if obj.AbsolutePosition.X < 0 or obj.AbsolutePosition.Y < 0 then skip = true end

            if not skip then
                local name = obj.Name
                local text = obj:IsA("TextButton") and obj.Text or ""
                local lowName = string.lower(name)
                local lowText = string.lower(text)

                -- blacklist
                local isBlacklisted = false
                for _, bl in ipairs(CFG.ButtonBlacklist) do
                    if string.find(lowName, bl, 1, true) or string.find(lowText, bl, 1, true) then
                        isBlacklisted = true; break
                    end
                end

                if not isBlacklisted then
                    -- keyword match
                    local isTracked = false
                    for _, kw in ipairs(CFG.ButtonKeywords) do
                        if string.find(lowName, kw, 1, true) or string.find(lowText, kw, 1, true) then
                            isTracked = true; break
                        end
                    end

                    if isTracked then
                        table.insert(found, {instance = obj, name = name, text = text, size = obj.AbsoluteSize, position = obj.AbsolutePosition, class = obj.ClassName})
                    end
                end
            end
        end
    end
    return found
end

local function renderButtons()
    if State.destroyed then return end
    for _, c in ipairs(btnFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local buttons = scanButtons()
    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, -4, 0, math.max(13, FONT_SIZE + 3))
    hdr.BackgroundColor3 = Color3.fromRGB(45, 40, 22)
    hdr.BackgroundTransparency = 0.15
    hdr.Text = "  👆 Buttons: " .. #buttons
    hdr.TextColor3 = Color3.fromRGB(255, 220, 100)
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = FONT_SIZE + 1
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.BorderSizePixel = 0
    hdr.Parent = btnFrame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 4)

    for i, btn in ipairs(buttons) do
        if i > 30 then break end
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(14, FONT_SIZE + 4))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = string.format("  %s | %s | %.0f,%.0f", btn.name, btn.class == "TextButton" and "T" or "I", btn.position.X, btn.position.Y)
        lbl.TextColor3 = Color3.fromRGB(255, 220, 100)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0
        lbl.Parent = btnFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end
    if #buttons == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, math.max(13, FONT_SIZE + 3))
        lbl.BackgroundColor3 = C.RowBg
        lbl.BackgroundTransparency = 0.35
        lbl.Text = "  No buttons detected"
        lbl.TextColor3 = C.SubText
        lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8, FONT_SIZE - 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BorderSizePixel = 0
        lbl.Parent = btnFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 3)
    end
end

-- ============================================================
-- SECTION: SNAPSHOT STATE
-- ============================================================
local lastSnapshot = {attrs = {}, stats = {}, nearby = {}, inventory = {}, walkspeed = nil, jumppower = nil, seat = nil, position = nil, health = nil, ping = nil, tool = nil, currency = {}}
local lastSpeedWarn = 0
local seenModelNames = {}
local modelLogBudget = 0

-- ============================================================
-- SECTION: CORE SCAN
-- ============================================================
local function scanOnce()
    if State.destroyed or State.paused then return end
    if not gui or not gui.Parent then fullKill(); return end

    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    -- attributes (LocalPlayer)
    if CFG.TrackAttrs then
        for k, v in pairs(lp:GetAttributes()) do
            if isIgnoredName(k, CFG.IgnoreAttrPatterns) then
                lastSnapshot.attrs[k] = v
            else
                local old = lastSnapshot.attrs[k]
                if old == nil then
                    lastSnapshot.attrs[k] = v
                elseif tostring(old) ~= tostring(v) then
                    if type(v) == "number" and type(old) == "number" and numAlmostEqual(old, v) then
                        lastSnapshot.attrs[k] = v
                    else
                        local color = Color3.fromRGB(255, 220, 100)
                        if type(v) == "number" and type(old) == "number" then
                            color = v > old and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
                        end
                        addLog("ATTR "..k..": "..fmt(old).." → "..fmt(v), color, "ATTR")
                        lastSnapshot.attrs[k] = v
                    end
                end
            end
        end
    end

    -- leaderstats
    if CFG.TrackStats then
        local ls = lp:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                local old = lastSnapshot.stats[v.Name]
                if old == nil then
                    lastSnapshot.stats[v.Name] = tostring(v.Value)
                elseif tostring(old) ~= tostring(v.Value) then
                    addLog("STAT "..v.Name..": "..tostring(old).." → "..tostring(v.Value), Color3.fromRGB(100, 200, 255), "STAT")
                    lastSnapshot.stats[v.Name] = tostring(v.Value)
                end
            end
        end
    end

    -- currency radar
    if CFG.CurrencyRadar then
        local ls = lp:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                if hasKwWord(v.Name, CFG.CurrencyKeywords) then
                    local old = lastSnapshot.currency[v.Name]
                    if old ~= nil and tostring(old) ~= tostring(v.Value) then
                        addLog("💰 " .. v.Name .. ": " .. tostring(old) .. " → " .. tostring(v.Value), C.Success, "CURRENCY")
                    end
                    lastSnapshot.currency[v.Name] = v.Value
                end
            end
        end
        -- currency di attributes
        for k, v in pairs(lp:GetAttributes()) do
            if hasKwWord(k, CFG.CurrencyKeywords) and type(v) == "number" then
                local old = lastSnapshot.currency["attr_"..k]
                if old ~= nil and old ~= v then
                    addLog("💰 (attr) " .. k .. ": " .. tostring(old) .. " → " .. tostring(v), C.Success, "CURRENCY")
                end
                lastSnapshot.currency["attr_"..k] = v
            end
        end
    end

    -- humanoid
    if hum then
        if CFG.TrackHumanoid and lastSnapshot.walkspeed ~= hum.WalkSpeed then
            if lastSnapshot.walkspeed ~= nil and math.abs(hum.WalkSpeed - lastSnapshot.walkspeed) >= 1 then
                addLog("WalkSpeed: "..string.format("%.1f", lastSnapshot.walkspeed).." → "..string.format("%.1f", hum.WalkSpeed), Color3.fromRGB(255, 180, 100), "SPEED")
            end
            lastSnapshot.walkspeed = hum.WalkSpeed
        end

        if CFG.TrackHealth then
            local hp = math.floor(hum.Health)
            if lastSnapshot.health ~= hp then
                if lastSnapshot.health ~= nil then
                    local diff = hp - lastSnapshot.health
                    local color = diff < 0 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 255, 80)
                    addLog("❤ HP: "..lastSnapshot.health.." → "..hp.." ("..(diff > 0 and "+" or "")..diff..")", color, "HEALTH")
                end
                lastSnapshot.health = hp
            end
        end

        -- speedhack detect (throttled)
        if CFG.SpeedHackDetect and hum.WalkSpeed > CFG.MaxSpeedNormal then
            local now = os.clock()
            if now - lastSpeedWarn > CFG.SpeedWarnCooldown then
                lastSpeedWarn = now
                addLog("⚡ SPEED WARN: "..math.floor(hum.WalkSpeed), Color3.fromRGB(255,200,50), "SPEED")
            end
        end
    end

    -- tool equip
    if CFG.TrackToolEquip then
        local tool = char and char:FindFirstChildOfClass("Tool")
        local tname = tool and tool.Name or nil
        if lastSnapshot.tool ~= tname then
            if lastSnapshot.tool ~= nil then
                addLog("🔧 Tool: "..tostring(lastSnapshot.tool).." → "..tostring(tname), Color3.fromRGB(255,220,100), "TOOL")
            end
            lastSnapshot.tool = tname
        end
    end

    -- position tracking (teleport detection)
    if CFG.TrackPosition and char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            if lastSnapshot.position then
                local dist = (pos - lastSnapshot.position).Magnitude
                if dist > CFG.TeleportThreshold then
                    addLog(string.format("📍 Teleport: %.0f studs", dist), C.Warning, "ANOMALY")
                end
            end
            lastSnapshot.position = pos
        end
    end

    -- network / ping
    if CFG.TrackNetwork then
        local pingItem = Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"]
        if pingItem then
            local ok, ping = pcall(function() return pingItem:GetValue() end)
            if ok and ping then
                local lastPing = lastSnapshot.ping
                if lastPing and math.abs(ping - lastPing) > 50 then
                    addLog("📡 Ping: " .. math.floor(lastPing) .. " → " .. math.floor(ping) .. "ms", C.SubText, "NET")
                end
                lastSnapshot.ping = ping
            end
        end
    end

    -- nearby players
    if CFG.TrackPlayers then
        local near = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character and char then
                local a = p.Character:FindFirstChild("HumanoidRootPart")
                local b = char:FindFirstChild("HumanoidRootPart")
                if a and b then
                    local dist = (a.Position - b.Position).Magnitude
                    if dist <= CFG.Radius then
                        near[p.Name] = math.floor(dist)
                    end
                end
            end
        end
        for name, dist in pairs(near) do
            if lastSnapshot.nearby[name] == nil then
                addLog("👥 Near: " .. name .. " (" .. dist .. " studs)", C.Accent, "PLAYER")
            end
        end
        for name in pairs(lastSnapshot.nearby) do
            if near[name] == nil then
                addLog("👋 Left radius: " .. name, C.SubText, "PLAYER")
            end
        end
        lastSnapshot.nearby = near
    end
end

-- ============================================================
-- SECTION: BACKPACK WATCH
-- ============================================================
-- token sesi: attribute _LS_watched dulu cuma boolean sehingga setelah execute ulang
-- backpack tidak pernah di-watch lagi (koneksi lama sudah di-disconnect)
local SESSION_TOKEN = tostring(os.clock()) .. "-" .. tostring(math.random(100000, 999999))

function setupBackpack() -- assign ke forward declaration
    local bp = lp:FindFirstChildOfClass("Backpack")
    if not bp then return end
    if bp:GetAttribute("_LS_watched") == SESSION_TOKEN then return end
    bp:SetAttribute("_LS_watched", SESSION_TOKEN)
    trackConn(bp.ChildAdded:Connect(function(c)
        if CFG.TrackBackpack and not State.paused and not State.destroyed then
            addLog("🎒 +Item: " .. c.Name .. " (" .. c.ClassName .. ")", C.Success, "INV")
        end
    end))
    trackConn(bp.ChildRemoved:Connect(function(c)
        if CFG.TrackBackpack and not State.paused and not State.destroyed then
            addLog("🎒 -Item: " .. c.Name, C.Warning, "INV")
        end
    end))
end

-- ============================================================
-- SECTION: PLAYER EVENTS
-- ============================================================
local function setupPlayerEvents()
    trackConn(Players.PlayerAdded:Connect(function(p)
        if CFG.TrackPlayerEvents and not State.paused and not State.destroyed then
            addLog("👤 Join: " .. p.Name, C.Success, "EVENT")
        end
    end))
    trackConn(Players.PlayerRemoving:Connect(function(p)
        if CFG.TrackPlayerEvents and not State.paused and not State.destroyed then
            addLog("👤 Leave: " .. p.Name, C.Warning, "EVENT")
        end
    end))
    trackConn(lp.CharacterAdded:Connect(function(c)
        if CFG.TrackPlayerEvents and not State.paused and not State.destroyed then
            addLog("🎮 Character spawned: " .. c.Name, C.Accent, "EVENT")
        end
        task.wait(1)
        if not State.destroyed then setupBackpack() end
    end))
end

-- ============================================================
-- SECTION: WORKSPACE MODEL WATCH (opt-in via toggle)
-- ============================================================
local function setupModelWatch()
    trackConn(workspace.DescendantAdded:Connect(function(obj)
        if not CFG.TrackModels or State.paused or State.destroyed then return end
        if not obj:IsA("Model") then return end
        if modelLogBudget > CFG.ModelLogBudget then return end
        task.defer(function()
            if State.destroyed then return end
            if seenModelNames[obj.Name] then return end
            seenModelNames[obj.Name] = true
            modelLogBudget = modelLogBudget + 1
            addLog("📦 Model: " .. obj.Name, C.SubText, "MODEL")
        end)
    end))
    -- reset budget tiap 5 detik
    task.spawn(function()
        while not State.destroyed do
            task.wait(5)
            modelLogBudget = 0
        end
    end)
end

-- ============================================================
-- SECTION: SILENT RESET LOOP
-- ============================================================
task.spawn(function()
    while not State.destroyed do
        task.wait(2)
        local now = os.clock()
        for r, rs in pairs(remoteStats) do
            if rs.silent and (now - (rs.lastHit or 0)) > CFG.SilentResetTime then
                rs.silent = false
                addLog("🔊 RESUME IN: " .. r.Name, Color3.fromRGB(150, 200, 150), "SYS")
            end
        end
        for r, rs in pairs(outStats) do
            if rs.silent and (now - (rs.lastHit or 0)) > CFG.SilentResetTime then
                rs.silent = false
                addLog("🔊 RESUME OUT: " .. r.Name, Color3.fromRGB(150, 200, 150), "SYS")
            end
        end
    end
end)

-- ============================================================
-- SECTION: FOOTER BUTTON HANDLERS
-- ============================================================
btnPause.MouseButton1Click:Connect(function()
    State.paused = not State.paused
    btnPause.Text = State.paused and "RESUME" or "PAUSE"
    btnPause.BackgroundColor3 = State.paused and C.Warning or C.Success
end)

btnClear.MouseButton1Click:Connect(function()
    Logs.entries = {}
    Logs.categoryCount = {}
    renderLog()
    btnClear.Text = "OK!"
    task.wait(0.6)
    btnClear.Text = "CLEAR"
end)

-- COPY ALL: dump semua log + remote + modul + attribute ke clipboard
btnCopy.MouseButton1Click:Connect(function()
    local lines = {}

    table.insert(lines, "===========================================")
    table.insert(lines, "   LIVE SCANNER v11.0 DUMP | @in666ar")
    table.insert(lines, "===========================================")
    table.insert(lines, "")

    -- [1] logs
    table.insert(lines, "=== [1] SCANNER LOGS ===")
    if #Logs.entries == 0 then table.insert(lines, "(No logs yet)") end
    for _, e in ipairs(Logs.entries) do table.insert(lines, e.text) end

    -- [2] inbound remote events
    table.insert(lines, "")
    table.insert(lines, "=== [2] REMOTE EVENTS (IN - OnClientEvent) ===")
    local evs = {}
    for r in pairs(hookedRemotes) do
        if typeof(r) == "Instance" and r:IsA("RemoteEvent") then
            local ok, name = pcall(function() return r:GetFullName() end)
            if ok then table.insert(evs, name) end
        end
    end
    table.sort(evs)
    if #evs == 0 then table.insert(lines, "(None)") end
    for _, n in ipairs(evs) do table.insert(lines, "📡 " .. n) end

    -- [3] remote functions
    table.insert(lines, "")
    table.insert(lines, "=== [3] REMOTE FUNCTIONS (IN - InvokeServer) ===")
    local fns = {}
    for r in pairs(hookedRemotes) do
        if typeof(r) == "Instance" and r:IsA("RemoteFunction") then
            local ok, name = pcall(function() return r:GetFullName() end)
            if ok then table.insert(fns, name) end
        end
    end
    table.sort(fns)
    if #fns == 0 then table.insert(lines, "(None)") end
    for _, n in ipairs(fns) do table.insert(lines, "📤 " .. n) end

    -- [4] outbound
    table.insert(lines, "")
    table.insert(lines, "=== [4] OUTBOUND (FireServer — seen) ===")
    local outs = {}
    for r, st in pairs(outStats) do
        local ok, name = pcall(function() return r:GetFullName() end)
        if ok then table.insert(outs, name .. " (count: " .. st.count .. ")") end
    end
    table.sort(outs)
    if #outs == 0 then table.insert(lines, "(None captured)") end
    for _, n in ipairs(outs) do table.insert(lines, "⬆ " .. n) end

    -- [5] modules
    table.insert(lines, "")
    table.insert(lines, "=== [5] MODULES LOADED (require) ===")
    local mods = {}
    for k in pairs(seenModules) do table.insert(mods, k) end
    table.sort(mods)
    if #mods == 0 then table.insert(lines, "(None)") end
    for _, n in ipairs(mods) do table.insert(lines, "📦 " .. n) end

    -- [6] attributes
    table.insert(lines, "")
    table.insert(lines, "=== [6] PLAYER ATTRIBUTES ===")
    local attrCount = 0
    for k, v in pairs(lp:GetAttributes()) do
        table.insert(lines, k .. " = " .. tostring(v))
        attrCount = attrCount + 1
    end
    if attrCount == 0 then table.insert(lines, "(None)") end

    table.insert(lines, "===========================================")

    local text = table.concat(lines, "\n")
    if #text > CFG.ClipboardCap then
        text = string.sub(text, 1, CFG.ClipboardCap) .. "\n\n[TRUNCATED — exceeded " .. CFG.ClipboardCap .. " bytes]"
    end

    -- patch: fallback clipboard antar executor
    local clip = setclipboard or toclipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, text)
    btnCopy.Text = ok and "ALL COPIED!" or "FAIL"
    task.wait(1.5)
    btnCopy.Text = "COPY ALL"
end)

-- ============================================================
-- SECTION: TAB HANDLER
-- ============================================================
for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        activeTab = name
        scroll.Visible = name == "LOG"
        cfgFrame.Visible = name == "CFG"
        infoFrame.Visible = name == "INFO"
        hookFrame.Visible = name == "HOOK"
        btnFrame.Visible = name == "BTN"
        gameFrame.Visible = name == "GAME"
        searchFrame.Visible = name == "LOG"

        for n, b in pairs(tabButtons) do
            b.BackgroundColor3 = n == name and C.TabActive or C.TabBar
        end

        if name == "LOG" then renderLog()
        elseif name == "INFO" then renderInfo()
        elseif name == "HOOK" then renderHook()
        elseif name == "BTN" then renderButtons()
        elseif name == "GAME" then renderGame() end
    end)
end

-- ============================================================
-- SECTION: BOOT (dibungkus pcall biar tidak crash total)
-- ============================================================
local bootOk, bootErr = pcall(function()
    -- 1. namecall hook dulu (FireServer / InvokeServer / SetAttribute)
    installNamecallHook()

    -- 2. require hook
    installRequireHook()

    -- 3. scan awal remote yang sudah ada
    task.spawn(function()
        local count = 0
        for _, obj in ipairs(RS:GetDescendants()) do
            if State.destroyed then break end
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                if obj:IsA("RemoteEvent") then hookRemoteEvent(obj)
                else hookRemoteFunction(obj) end
                count = count + 1
                if count % 50 == 0 then task.wait() end
            end
        end
    end)

    -- 4. pantau remote baru
    setupDynamicRemoteWatch()

    -- 5. player events + backpack
    setupPlayerEvents()
    setupBackpack()

    -- 6. model watch (aktif kalau toggle ON)
    setupModelWatch()

    -- ========================================================
    -- LOOPS
    -- ========================================================
    task.spawn(function()
        while not State.destroyed do
            task.wait(CFG.ScanInterval)
            if not State.paused then pcall(scanOnce) end
        end
    end)

    task.spawn(function()
        while not State.destroyed do
            task.wait(CFG.RenderInterval)
            if activeTab == "LOG" then pcall(renderLog) end
        end
    end)

    task.spawn(function()
        while not State.destroyed do
            task.wait(CFG.ButtonScanInterval)
            if activeTab == "BTN" and CFG.TrackButtons then pcall(renderButtons) end
        end
    end)

    task.spawn(function()
        while not State.destroyed do
            task.wait(CFG.InfoInterval)
            if State.destroyed then break end
            if activeTab == "INFO" then pcall(renderInfo) end
            if activeTab == "GAME" then pcall(renderGame) end
        end
    end)

    task.spawn(function()
        while not State.destroyed do
            task.wait(CFG.HookInterval)
            if State.destroyed then break end
            if activeTab == "HOOK" then pcall(renderHook) end
        end
    end)

    -- ========================================================
    -- INITIAL RENDER
    -- ========================================================
    renderLog(); renderInfo(); renderHook(); renderButtons(); renderGame()

    addLog("🚀 v11.0 BIDIRECTIONAL — FireServer + InvokeServer + require + DescendantAdded ACTIVE", C.Success, "SYS")
    print("⚡ [LiveScan v11.0 BIDIRECTIONAL] FireServer/InvokeServer/require hooks installed.")
end)

if not bootOk then
    warn("[LiveScan] boot error: " .. tostring(bootErr))
    pcall(addLog, "❌ boot error: " .. tostring(bootErr), C.Danger, "SYS")
end
