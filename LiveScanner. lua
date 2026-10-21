-- ============================================
-- FULL LIVE SCANNER v10.10 — REMOTE RECON OP
-- @in666ar | FireServer hook, RF return, dynamic discovery
-- ============================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local MPS = game:GetService("MarketplaceService")
local lp = Players.LocalPlayer

-- ============ CLEANUP ============
if _G._LiveScanner_v10_Cleanup then pcall(_G._LiveScanner_v10_Cleanup) end
if _G._RF_HookInstalled and getrawmetatable and setreadonly then
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and _G._RF_OldNamecall then
            setreadonly(mt, false); mt.__namecall = _G._RF_OldNamecall; setreadonly(mt, true)
        end
    end)
end
_G._RF_HookInstalled = nil; _G._RF_OldNamecall = nil

for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
    if g.Name == "FullLiveScan" then g:Destroy() end
end
for _, g in ipairs(lp:WaitForChild("PlayerGui"):GetChildren()) do
    if g.Name == "FullLiveScan" then g:Destroy() end
end

-- ============ CONFIG ============
local CFG = {
    ScanInterval = 1.5, RenderInterval = 1.5, InfoInterval = 5,
    HookInterval = 5, ButtonScanInterval = 2,
    MaxLines = 25, MaxBuffer = 400, Radius = 100,

    TrackAttrs = true, TrackStats = true, TrackHumanoid = true,
    TrackModels = true, TrackRemotes = true, TrackRemoteFunctions = true,
    TrackFireServer = true, TrackInvokeReturn = true,
    TrackInventory = true, TrackPosition = false, TrackPlayers = true,
    TrackHealth = true, TrackNetwork = false, TrackToolEquip = true,
    TrackButtons = true, ReconMode = true,

    AlertMode = true, CurrencyRadar = true,
    SpeedHackDetect = true, PatternDetect = true,

    IgnoreRemotes = {"ReplicaSet","Replica","ReplicaCreated","ReplicaRemoved",
                     "CatchAnnounce","CastRoll","CleanupCast"},
    IgnorePatterns = {"replica","heartbeat","tick","ping","update",
                      "coinschanged","leaderboard","income"},
    IgnoreAttrPatterns = {"LBTHIncomeLastTick","LastDailyReset","_lemonade",
                          "Presentation","Internal","Temp","LastTick","LastUpdate","LastSync"},
    IgnoreEquipItems = {"Humanoid","HumanoidRootPart","Head","Torso","LowerTorso","UpperTorso",
        "RightUpperArm","RightLowerArm","RightHand","LeftUpperArm","LeftLowerArm","LeftHand",
        "RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot",
        "Health","Animate","Body Colors","Shirt","Pants","Accessory",
        "Right Arm","Left Arm","Right Leg","Left Leg","CharacterMesh"},

    ButtonKeywords = {"tap","click","arrow","skill","cast","reel","hook","fish","left","right",
                      "up","down","power","hit","strike","qte","minigame","ribbon","doublecast",
                      "execute","reset"},
    ButtonBlacklist = {"buy","close","menu","settings","exit","shop","trade","sell","invite",
                       "claim","rod","quest","stats","index","store","home","back"},

    DedupeRemote = true, DedupeWindow = 3, NumericTolerance = 0.5,
    HighFreqThreshold = 8, HighFreqWindow = 3, MaxArgLen = 200, MaxTypeDepth = 2,

    AlertKeywords = {"admin","kick","ban","give","cash","coin","token","prize","reward",
                     "hack","exploit","detected","victory"},
    CurrencyKeywords = {"cash","coin","gem","token","money","gold","credit","crystal",
                        "diamond","point","xp","level"},
    MaxSpeedNormal = 100, MaxJumpNormal = 150,

    ScanServices = {  -- FIX: scan service lain buat remote
        "ReplicatedStorage","Workspace","Players","ReplicatedFirst",
    },
    ScanDepth = 4,
}

-- ============ STATE ============
local State = {running = true, paused = false, destroyed = false}

-- ============ AUTO-FIT ============
local VIEW = workspace.CurrentCamera.ViewportSize
local UI_SCALE = math.min(VIEW.X / 720, VIEW.Y / 1280)
if UI_SCALE < 0.45 then UI_SCALE = 0.45 end
if UI_SCALE > 1.2 then UI_SCALE = 1.2 end
local BASE_W, BASE_H = 300, 420
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
if startY + FRAME_H > VIEW.Y - 10 then startY = math.max(10, VIEW.Y - FRAME_H - 10) end

-- ============ LOG ============
local Logs = {entries = {}, totalCount = 0, categoryCount = {}}
local function pushLog(text, color, category)
    if State.destroyed then return end
    table.insert(Logs.entries, {
        text = "["..os.date("%H:%M:%S").."] "..text, raw = text,
        color = color or Color3.fromRGB(200,200,200), category = category or "SYS", time = tick(),
    })
    if #Logs.entries > CFG.MaxBuffer then table.remove(Logs.entries, 1) end
    Logs.totalCount = Logs.totalCount + 1
    Logs.categoryCount[category] = (Logs.categoryCount[category] or 0) + 1
end

-- ============ HELPERS ============
local function truncate(s, max)
    s = tostring(s)
    if #s > max then return string.sub(s,1,max).."...(+"..(#s-max)..")" end
    return s
end
local function fmt(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    if type(v) == "Instance" then return v.Name end
    if type(v) == "table" then
        local p = {}
        for k, val in pairs(v) do table.insert(p, tostring(k).."="..fmt(val, depth+1)) end
        return "{"..table.concat(p,",").."}"
    end
    return tostring(v)
end
-- NEW: type-tagged arg untuk recon
local function typed(v, depth)
    depth = depth or 0
    if depth > CFG.MaxTypeDepth then return "..." end
    local t = type(v)
    if t == "Instance" then return "["..v.ClassName..":"..v.Name.."]" end
    if t == "string" then return '["'..(v:gsub("\n","\\n"):sub(1,40))..'"]' end
    if t == "number" then return "["..tostring(v).."]" end
    if t == "boolean" then return "["..tostring(v).."]" end
    if t == "nil" then return "[nil]" end
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "[table:"..n.."]"
    end
    return "["..t..":"..tostring(v):sub(1,20).."]"
end
local function typedArgs(args)
    local out = {}
    for i, a in ipairs(args) do out[i] = typed(a) end
    return truncate(table.concat(out, " "), CFG.MaxArgLen)
end
local function hasKwWord(text, list)
    local low = " "..string.lower(text).." "
    for _, kw in ipairs(list) do
        if string.find(low, "[^%a%d]"..string.lower(kw).."[^%a%d]") then return kw end
    end
end
local function isIgnoredName(name, patterns)
    local low = string.lower(name)
    for _, pat in ipairs(patterns) do
        if string.find(low, string.lower(pat), 1, true) then return true end
    end
    return false
end
local function isIgnoredEquipItem(name)
    for _, item in ipairs(CFG.IgnoreEquipItems) do if name == item then return true end end
    return false
end
local function numAlmostEqual(a, b, tol)
    tol = tol or CFG.NumericTolerance
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    return math.abs(a - b) < tol
end
local function addLog(text, color, category)
    if State.destroyed then return end
    if CFG.AlertMode then
        local kw = hasKwWord(text, CFG.AlertKeywords)
        if kw then color = Color3.fromRGB(255,60,60); text = "🚨 ["..kw.."] "..text end
    end
    pushLog(text, color, category or "SYS")
end

-- ============ GUI ============
local C = {
    Bg=Color3.fromRGB(16,18,24), BgTop=Color3.fromRGB(26,30,40),
    TabBar=Color3.fromRGB(20,23,31), TabActive=Color3.fromRGB(38,44,58),
    Search=Color3.fromRGB(22,25,34), Accent=Color3.fromRGB(88,166,255),
    AccentDim=Color3.fromRGB(60,110,180), Success=Color3.fromRGB(72,190,120),
    Warning=Color3.fromRGB(220,160,60), Danger=Color3.fromRGB(220,76,76),
    Text=Color3.fromRGB(226,230,238), SubText=Color3.fromRGB(140,146,160),
    RowBg=Color3.fromRGB(24,27,36), RowBgAlt=Color3.fromRGB(28,32,42),
}

local gui = Instance.new("ScreenGui")
gui.Name = "FullLiveScan"; gui.ResetOnSpawn = false
gui.DisplayOrder = 997; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
frame.Position = UDim2.new(0, startX, 0, startY)
frame.BackgroundColor3 = C.Bg; frame.BorderSizePixel = 0; frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)
local fg = Instance.new("UIGradient", frame)
fg.Rotation = 90
fg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,C.BgTop),ColorSequenceKeypoint.new(1,C.Bg)})
local stroke = Instance.new("UIStroke", frame)
stroke.Color = C.Accent; stroke.Thickness = 1.4; stroke.Transparency = 0.55
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,30); header.BackgroundTransparency = 1; header.Parent = frame
local titleContainer = Instance.new("Frame")
titleContainer.Size = UDim2.new(1,-104,1,0); titleContainer.Position = UDim2.new(0,10,0,0)
titleContainer.BackgroundTransparency = 1; titleContainer.Parent = header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,math.floor(14*UI_SCALE)); title.Position = UDim2.new(0,0,0,3)
title.BackgroundTransparency = 1; title.Text = "⚡ LIVE SCAN v10.10"
title.TextColor3 = C.Accent; title.Font = Enum.Font.GothamBold
title.TextSize = TITLE_SIZE; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = titleContainer
local watermark = Instance.new("TextLabel")
watermark.Size = UDim2.new(1,0,0,math.floor(10*UI_SCALE))
watermark.Position = UDim2.new(0,0,0,math.floor(16*UI_SCALE))
watermark.BackgroundTransparency = 1; watermark.Text = "@in666ar"
watermark.TextColor3 = C.SubText; watermark.Font = Enum.Font.GothamBold
watermark.TextSize = math.max(7,math.floor(9*UI_SCALE))
watermark.TextXAlignment = Enum.TextXAlignment.Left; watermark.Parent = titleContainer

local function mkHeaderBtn(text, xOff, w, color, txtSize)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,24); b.Position = UDim2.new(1,xOff,0,3)
    b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1,1,1); b.Text = text
    b.Font = Enum.Font.GothamBold; b.TextSize = txtSize or FONT_SIZE
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end
local powerBtn = mkHeaderBtn("ON", -102, 40, C.Success, FONT_SIZE)
local collapse = mkHeaderBtn("−", -58, 24, C.RowBgAlt, 15)
local closeBtn = mkHeaderBtn("×", -30, 24, C.Danger, 17)
closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = Color3.fromRGB(245,100,100) end)
closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = C.Danger end)
collapse.MouseEnter:Connect(function() collapse.BackgroundColor3 = Color3.fromRGB(48,54,70) end)
collapse.MouseLeave:Connect(function() collapse.BackgroundColor3 = C.RowBgAlt end)

-- Forward decls (harus ada sebelum dipakai)
local renderLog, renderCfg, renderInfo, renderHook, renderButtons, renderGame
local fullKill

fullKill = function()
    State.destroyed = true; State.running = false
    for r, conn in pairs(_G._LS_hooks or {}) do
        if type(conn) == "userdata" or type(conn) == "table" then
            pcall(function() conn:Disconnect() end)
        end
    end
    _G._LS_hooks = nil; _G._LS_remoteMeta = nil
    _G._LS_scanConns = nil; _G._LS_remoteLastArgs = nil; _G._LS_remoteLastTime = nil
    if _G._RF_HookInstalled and getrawmetatable and setreadonly then
        pcall(function()
            local mt = getrawmetatable(game)
            if mt and _G._RF_OldNamecall then
                setreadonly(mt, false); mt.__namecall = _G._RF_OldNamecall; setreadonly(mt, true)
            end
        end)
    end
    _G._RF_HookInstalled = nil; _G._RF_OldNamecall = nil
    pcall(function() gui:Destroy() end)
    print("[LiveScan v10.10] Full stop.")
end
_G._LiveScanner_v10_Cleanup = fullKill
closeBtn.MouseButton1Click:Connect(fullKill)

local function updatePowerBtn()
    if State.running and not State.paused then
        powerBtn.BackgroundColor3 = C.Success; powerBtn.Text = "ON"
    elseif State.paused then
        powerBtn.BackgroundColor3 = C.Warning; powerBtn.Text = "HOLD"
    else
        powerBtn.BackgroundColor3 = Color3.fromRGB(80,40,40); powerBtn.Text = "OFF"
    end
end
powerBtn.MouseButton1Click:Connect(function()
    if State.running then
        State.running = false; addLog("⏹ STOPPED", Color3.fromRGB(255,150,150), "SYS")
    else
        State.running = true; addLog("▶ STARTED", Color3.fromRGB(150,255,150), "SYS")
    end
    updatePowerBtn()
end)

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-10,0,26); tabBar.Position = UDim2.new(0,5,0,34)
tabBar.BackgroundColor3 = C.TabBar; tabBar.BorderSizePixel = 0; tabBar.Parent = frame
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0,6)

local tabs = {
    {name="LOG", color=Color3.fromRGB(100,200,255)},
    {name="CFG", color=Color3.fromRGB(255,200,100)},
    {name="INFO", color=Color3.fromRGB(200,255,100)},
    {name="HOOK", color=Color3.fromRGB(255,130,200)},
    {name="BTN", color=Color3.fromRGB(255,220,100)},
    {name="GAME", color=Color3.fromRGB(150,255,200)},
}
local activeTab = "LOG"
local tabButtons = {}
for i, t in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#tabs,-3,1,-4); btn.Position = UDim2.new((i-1)/#tabs,1.5,0,2)
    btn.BackgroundColor3 = i == 1 and C.TabActive or C.TabBar
    btn.TextColor3 = t.color; btn.Text = t.name; btn.Font = Enum.Font.GothamBold
    btn.TextSize = math.max(8, FONT_SIZE-1); btn.BorderSizePixel = 0
    btn.AutoButtonColor = false; btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
    tabButtons[t.name] = btn
end

-- Search + Filter
local searchFrame = Instance.new("Frame")
searchFrame.Size = UDim2.new(1,-10,0,26); searchFrame.Position = UDim2.new(0,5,0,64)
searchFrame.BackgroundColor3 = C.Search; searchFrame.BorderSizePixel = 0; searchFrame.Parent = frame
Instance.new("UICorner", searchFrame).CornerRadius = UDim.new(0,6)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1,-64,1,-4); searchBox.Position = UDim2.new(0,8,0,2)
searchBox.BackgroundTransparency = 1; searchBox.Text = ""
searchBox.PlaceholderText = "🔍 Cari..."; searchBox.TextColor3 = C.Text
searchBox.PlaceholderColor3 = C.SubText; searchBox.Font = Enum.Font.Code
searchBox.TextSize = FONT_SIZE; searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false; searchBox.Parent = searchFrame

local filterBtn = Instance.new("TextButton")
filterBtn.Size = UDim2.new(0,54,1,-4); filterBtn.Position = UDim2.new(1,-58,0,2)
filterBtn.BackgroundColor3 = C.AccentDim; filterBtn.TextColor3 = Color3.new(1,1,1)
filterBtn.Text = "ALL"; filterBtn.Font = Enum.Font.GothamBold
filterBtn.TextSize = math.max(8,FONT_SIZE-1); filterBtn.BorderSizePixel = 0
filterBtn.AutoButtonColor = false; filterBtn.Parent = searchFrame
Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0,5)

local filterCycle = {"ALL","ATTR","STAT","REMOTE","RF","FIRESERVER","RETURN","MODEL",
                     "INV","PLAYER","HEALTH","CURRENCY","PATTERN","NET","ANOMALY","SYS",
                     "TOOL","BTN","POS"}
local filterIdx = 1
local searchText = ""

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = string.lower(searchBox.Text)
    if activeTab == "LOG" and renderLog then renderLog() end
end)
filterBtn.MouseButton1Click:Connect(function()
    filterIdx = filterIdx + 1
    if filterIdx > #filterCycle then filterIdx = 1 end
    filterBtn.Text = filterCycle[filterIdx]
    if renderLog then renderLog() end
end)

-- Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1,-10,1,-124); content.Position = UDim2.new(0,5,0,94)
content.BackgroundTransparency = 1; content.Parent = frame

local function makeScroll()
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1,0,1,0); s.BackgroundTransparency = 1; s.BorderSizePixel = 0
    s.ScrollBarThickness = 4; s.ScrollBarImageColor3 = C.Accent
    s.CanvasSize = UDim2.new(0,0,0,0); s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Parent = content
    local l = Instance.new("UIListLayout", s); l.Padding = UDim.new(0,3)
    return s
end
local scroll = makeScroll(); scroll.Visible = true
local cfgFrame = makeScroll(); cfgFrame.Visible = false
local infoFrame = makeScroll(); infoFrame.Visible = false
local hookFrame = makeScroll(); hookFrame.Visible = false
local btnFrame = makeScroll(); btnFrame.Visible = false
local gameFrame = makeScroll(); gameFrame.Visible = false

-- Footer
local BTN_GAP = 5
local BTN_TOTAL_W = FRAME_W - 10
local BTN_W = math.floor((BTN_TOTAL_W - BTN_GAP*2) / 3)
local BTN_H = 26
local function mkFooterBtn(text, xOff, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,BTN_W,0,BTN_H); b.Position = UDim2.new(0,xOff,1,-30)
    b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1,1,1); b.Text = text
    b.Font = Enum.Font.GothamBold; b.TextSize = FONT_SIZE
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end
local btnPause = mkFooterBtn("PAUSE", 5, C.Success)
local btnClear = mkFooterBtn("CLEAR", 5+BTN_W+BTN_GAP, C.Danger)
local btnCopy = mkFooterBtn("COPY", 5+(BTN_W+BTN_GAP)*2, Color3.fromRGB(50,90,170))

-- Draggable
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
header.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
                     or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local collapsed = false
collapse.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    if collapsed then
        frame.Size = UDim2.new(0,FRAME_W,0,30); collapse.Text = "+"
    else
        frame.Size = UDim2.new(0,FRAME_W,0,FRAME_H); collapse.Text = "−"
    end
end)

-- ============ RENDER LOG ============
renderLog = function()
    if State.destroyed then return end
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local shown, curFilter = 0, filterCycle[filterIdx]
    for i = #Logs.entries, 1, -1 do
        if shown >= CFG.MaxLines then break end
        local e = Logs.entries[i]
        local pass = true
        if curFilter ~= "ALL" and e.category ~= curFilter then pass = false end
        if pass and searchText ~= "" and not string.find(string.lower(e.text), searchText) then
            pass = false
        end
        if pass then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
            lbl.BackgroundColor3 = (shown%2 == 0) and C.RowBg or C.RowBgAlt
            lbl.BackgroundTransparency = 0.35; lbl.Text = "  "..e.text
            lbl.TextColor3 = e.color; lbl.Font = Enum.Font.Code
            lbl.TextSize = math.max(8,FONT_SIZE-1); lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd; lbl.LayoutOrder = -i
            lbl.BorderSizePixel = 0; lbl.Parent = scroll
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,3)
            shown = shown + 1
        end
    end
end

-- ============ TOGGLE ============
local function makeToggle(name, key, parent)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-4,0,24); row.BackgroundColor3 = C.RowBg
    row.BackgroundTransparency = 0.15; row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,5)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-56,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = name; lbl.TextColor3 = C.Text
    lbl.Font = Enum.Font.Code; lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,40,1,-6); btn.Position = UDim2.new(1,-44,0,3)
    btn.BackgroundColor3 = CFG[key] and C.Success or Color3.fromRGB(80,40,40)
    btn.TextColor3 = Color3.new(1,1,1); btn.Text = CFG[key] and "ON" or "OFF"
    btn.Font = Enum.Font.GothamBold; btn.TextSize = math.max(8,FONT_SIZE-1)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        btn.BackgroundColor3 = CFG[key] and C.Success or Color3.fromRGB(80,40,40)
        btn.Text = CFG[key] and "ON" or "OFF"
    end)
end

makeToggle("Player Attributes", "TrackAttrs", cfgFrame)
makeToggle("Leaderstats", "TrackStats", cfgFrame)
makeToggle("Humanoid", "TrackHumanoid", cfgFrame)
makeToggle("Models Sekitar", "TrackModels", cfgFrame)
makeToggle("Remote Events (OnClientEvent)", "TrackRemotes", cfgFrame)
makeToggle("Remote Functions (InvokeServer)", "TrackRemoteFunctions", cfgFrame)
makeToggle("🔥 FireServer (client→server)", "TrackFireServer", cfgFrame)
makeToggle("📥 RF Return Value", "TrackInvokeReturn", cfgFrame)
makeToggle("🔎 Recon Mode (list idle remotes)", "ReconMode", cfgFrame)
makeToggle("Inventory", "TrackInventory", cfgFrame)
makeToggle("Position", "TrackPosition", cfgFrame)
makeToggle("Track Players", "TrackPlayers", cfgFrame)
makeToggle("Track Health", "TrackHealth", cfgFrame)
makeToggle("Track Network", "TrackNetwork", cfgFrame)
makeToggle("Track Tool Equip", "TrackToolEquip", cfgFrame)
makeToggle("Track UI Buttons", "TrackButtons", cfgFrame)
makeToggle("Alert Mode", "AlertMode", cfgFrame)
makeToggle("Currency Radar", "CurrencyRadar", cfgFrame)
makeToggle("SpeedHack Detect", "SpeedHackDetect", cfgFrame)
makeToggle("Pattern Detect", "PatternDetect", cfgFrame)

renderCfg = function()
    for _, c in ipairs(cfgFrame:GetChildren()) do
        if c:IsA("TextLabel") and c.Name == "CfgHeader" then c:Destroy() end
    end
    local hdr = Instance.new("TextLabel")
    hdr.Name = "CfgHeader"; hdr.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
    hdr.BackgroundColor3 = C.RowBgAlt; hdr.BackgroundTransparency = 0.2
    hdr.Text = "  ⚙ Toggle fitur scanner"; hdr.TextColor3 = Color3.fromRGB(255,200,100)
    hdr.Font = Enum.Font.GothamBold; hdr.TextSize = FONT_SIZE+1
    hdr.TextXAlignment = Enum.TextXAlignment.Left; hdr.BorderSizePixel = 0
    hdr.Parent = cfgFrame; hdr.LayoutOrder = -999
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0,4)
end
renderCfg()

-- ============ INFO ============
renderInfo = function()
    if State.destroyed then return end
    for _, c in ipairs(infoFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local data = {
        "PlaceId: "..game.PlaceId,
        "JobId: "..tostring(game.JobId):sub(1,20).."...",
        "Player: "..lp.Name,
        "UserId: "..lp.UserId,
        "Total logs: "..tostring(Logs.totalCount),
        "Scanner: "..(State.running and "RUNNING" or "STOPPED"),
        "--- Category Count ---",
    }
    local catList = {}
    for k, v in pairs(Logs.categoryCount) do
        if v > 0 then table.insert(catList, {k=k,v=v}) end
    end
    table.sort(catList, function(a,b) return a.v > b.v end)
    for _, c in ipairs(catList) do table.insert(data, "  "..c.k..": "..c.v) end
    table.insert(data, "--- Player Attributes ---")
    local count = 0
    for k, v in pairs(lp:GetAttributes()) do
        if count < 15 then table.insert(data, "  "..k.." = "..tostring(v)); count = count + 1 end
    end
    for _, txt in ipairs(data) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
        lbl.BackgroundColor3 = C.RowBg; lbl.BackgroundTransparency = 0.35
        lbl.Text = "  "..txt; lbl.TextColor3 = Color3.fromRGB(200,220,255)
        lbl.Font = Enum.Font.Code; lbl.TextSize = math.max(8,FONT_SIZE-1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0; lbl.Parent = infoFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,3)
    end
end

-- ============ GAME INFO ============
local cachedGameName = nil
local gameNameFetched = false
local function fetchGameName()
    if gameNameFetched then return cachedGameName or "Unknown" end
    gameNameFetched = true
    pcall(function() cachedGameName = MPS:GetProductInfo(game.PlaceId).Name end)
    return cachedGameName or "Unknown"
end

renderGame = function()
    if State.destroyed then return end
    for _, c in ipairs(gameFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local data = {
        "🎮 GAME INFORMATION", "─────────────────────",
        "Name: "..fetchGameName(),
        "PlaceId: "..game.PlaceId,
        "Creator: "..tostring(game.CreatorId),
        "JobId: "..tostring(game.JobId), "",
        "🌍 SERVER", "─────────────────────",
        "Players: "..#Players:GetPlayers(), "",
        "👤 YOU", "─────────────────────",
        "Name: "..lp.Name, "Display: "..lp.DisplayName,
        "UserId: "..lp.UserId, "Age: "..lp.AccountAge.." days", "",
        "💻 DEVICE", "─────────────────────",
        "Type: "..(UIS.TouchEnabled and UIS.KeyboardEnabled and "Tablet"
                   or UIS.TouchEnabled and "Mobile" or "PC"),
        "Viewport: "..math.floor(VIEW.X).."x"..math.floor(VIEW.Y),
        "UI Scale: "..string.format("%.2f", UI_SCALE), "",
        "📊 INSTANCE COUNT", "─────────────────────",
        "Workspace: "..#workspace:GetDescendants(),
        "ReplicatedStorage: "..#RS:GetDescendants(), "",
        "📦 PLAYERS ONLINE", "─────────────────────",
    }
    for _, p in ipairs(Players:GetPlayers()) do table.insert(data, "  "..p.Name) end
    for _, txt in ipairs(data) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
        lbl.BackgroundColor3 = C.RowBg; lbl.BackgroundTransparency = 0.35
        lbl.Text = "  "..txt; lbl.TextColor3 = Color3.fromRGB(150,255,200)
        lbl.Font = Enum.Font.Code; lbl.TextSize = math.max(8,FONT_SIZE-1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.BorderSizePixel = 0; lbl.Parent = gameFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,3)
    end
end

-- ================================================================
-- ============ 🔥 REMOTE RECON ENGINE (v10.10 UPGRADE) ============
-- ================================================================
_G._LS_hooks = _G._LS_hooks or {}
_G._LS_remoteMeta = _G._LS_remoteMeta or {}
_G._LS_scanConns = _G._LS_scanConns or {}
_G._LS_remoteLastArgs = _G._LS_remoteLastArgs or {}
_G._LS_remoteLastTime = _G._LS_remoteLastTime or {}

local hookedRemotes = _G._LS_hooks
local remoteMeta    = _G._LS_remoteMeta
local remoteLastArgs = _G._LS_remoteLastArgs
local remoteLastTime = _G._LS_remoteLastTime

-- Meta factory
local function ensureMeta(remote, kind)
    local m = remoteMeta[remote]
    if not m then
        m = {
            kind = kind or (remote:IsA("RemoteEvent") and "event" or "function"),
            hooked = false, ignored = false,
            count = 0, lastTime = 0, firstTime = 0,
            lastArgs = nil, lastReturn = nil,
            skipped = 0, silent = false,
            timestamps = {},  -- buat high-freq
            evConn = nil,     -- OnClientEvent conn
        }
        remoteMeta[remote] = m
    end
    return m
end

-- High-freq check
local function isHighFreq(m)
    local now = tick()
    table.insert(m.timestamps, now)
    while #m.timestamps > 50 do table.remove(m.timestamps, 1) end
    local recent = 0
    for _, t in ipairs(m.timestamps) do
        if now - t < CFG.HighFreqWindow then recent = recent + 1 end
    end
    return recent >= CFG.HighFreqThreshold
end

-- Dedupe check
local function isDuplicate(remote, argStr)
    if not CFG.DedupeRemote then return false end
    local now = tick()
    if remoteLastArgs[remote] == argStr
       and (now - (remoteLastTime[remote] or 0)) < CFG.DedupeWindow then
        return true
    end
    remoteLastArgs[remote] = argStr
    remoteLastTime[remote] = now
    return false
end

-- Handle incoming payload (dari event ATAU namecall)
local function onRemoteCall(remote, direction, argStr, returnVal)
    if State.destroyed or not State.running or State.paused then return end
    local m = ensureMeta(remote)

    if m.ignored then return end
    if isIgnoredName(remote.Name, CFG.IgnoreRemotes)
       or isIgnoredName(remote.Name, CFG.IgnorePatterns) then
        m.ignored = true; return
    end

    -- Cek toggle sesuai arah
    if direction == "ONCLIENT" and not CFG.TrackRemotes then return end
    if direction == "FIRESERVER" and not CFG.TrackFireServer then return end
    if direction == "INVOKE" and not CFG.TrackRemoteFunctions then return end

    m.count = m.count + 1
    if m.firstTime == 0 then m.firstTime = tick() end

    -- High-freq silent
    if isHighFreq(m) then
        if not m.silent then
            m.silent = true
            addLog("🔇 AUTO-SILENT: "..remote.Name, Color3.fromRGB(150,150,200), "SYS")
        end
        m.skipped = m.skipped + 1
        return
    end

    -- Dedupe
    if isDuplicate(remote, argStr) then
        m.skipped = m.skipped + 1
        return
    end

    m.lastArgs = argStr
    m.lastTime = tick()
    if returnVal ~= nil then m.lastReturn = returnVal end

    -- Log entry
    local prefix, color, cat
    if direction == "ONCLIENT" then
        prefix = "⬇ "..remote.Name; color = Color3.fromRGB(255,130,200); cat = "REMOTE"
    elseif direction == "FIRESERVER" then
        prefix = "🔥 "..remote.Name; color = Color3.fromRGB(255,160,80); cat = "FIRESERVER"
    else
        prefix = "📤 "..remote.Name; color = Color3.fromRGB(255,150,100); cat = "RF"
    end

    local line = prefix
    if argStr ~= "" then line = line.." | "..argStr end
    if returnVal ~= nil and CFG.TrackInvokeReturn then
        line = line.." → "..typed(returnVal)
        if cat == "RF" then cat = "RF" end  -- udah RF
    end
    addLog(line, color, cat)

    -- Return value log terpisah (opsional, biar jelas)
    if direction == "INVOKE" and returnVal ~= nil and CFG.TrackInvokeReturn then
        addLog("↩ RET "..remote.Name.." = "..typed(returnVal),
               Color3.fromRGB(180,255,180), "RETURN")
    end
end

-- Register remote (idempotent)
local function registerRemote(remote)
    if not remote then return end
    local m = ensureMeta(remote)
    if m.hooked or m.ignored then return end

    if isIgnoredName(remote.Name, CFG.IgnoreRemotes)
       or isIgnoredName(remote.Name, CFG.IgnorePatterns) then
        m.ignored = true; return
    end

    -- Hook RemoteEvent OnClientEvent
    if remote:IsA("RemoteEvent") and m.evConn == nil then
        m.evConn = remote.OnClientEvent:Connect(function(...)
            if State.destroyed or not State.running or State.paused then return end
            local args = {...}
            onRemoteCall(remote, "ONCLIENT", typedArgs(args))
        end)
        hookedRemotes[remote] = m.evConn
    end

    m.hooked = true
end

-- Scan services recursively (v10.10: multi-service + dynamic)
local function scanRemotesRecursive(parent, depth)
    if depth > CFG.ScanDepth then return end
    for _, obj in ipairs(parent:GetChildren()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            registerRemote(obj)
        end
        pcall(function() scanRemotesRecursive(obj, depth + 1) end)
    end
end

for _, svcName in ipairs(CFG.ScanServices) do
    local svc = game:FindFirstChild(svcName)
    if svc then scanRemotesRecursive(svc, 0) end
end

-- Dynamic discovery: remote baru runtime
local function installDiscovery(parent)
    if not parent then return end
    local conn = parent.DescendantAdded:Connect(function(obj)
        if State.destroyed then return end
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            task.wait(0.1)  -- tunggu parent stabil
            registerRemote(obj)
        end
    end)
    table.insert(_G._LS_scanConns, conn)
end
for _, svcName in ipairs(CFG.ScanServices) do
    local svc = game:FindFirstChild(svcName)
    if svc then installDiscovery(svc) end
end

-- Namecall hook (GLOBAL) — FIX: sekarang handle FireServer + InvokeServer + return
if getrawmetatable and setreadonly and newcclosure and getnamecallmethod then
    local mt = getrawmetatable(game)
    if mt and mt.__namecall and not _G._RF_HookInstalled then
        _G._RF_HookInstalled = true
        _G._RF_OldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local ok, isRemoteEvent, isRemoteFunc = pcall(function()
                return typeof(self) == "Instance" and self:IsA("RemoteEvent"),
                       typeof(self) == "Instance" and self:IsA("RemoteFunction")
            end)
            local isRE = ok and isRemoteEvent
            local isRF = ok and isRemoteFunc

            -- FireServer (client→server)
            if method == "FireServer" and isRE then
                if State.running and not State.paused and CFG.TrackFireServer then
                    local args = {...}
                    local argStr = typedArgs(args)
                    -- Auto-register remote kalau belum dikenal
                    if not remoteMeta[self] then
                        ensureMeta(self, "event")
                        registerRemote(self)
                    end
                    onRemoteCall(self, "FIRESERVER", argStr)
                end
                return _G._RF_OldNamecall(self, ...)
            end

            -- InvokeServer (client→server) + capture return
            if method == "InvokeServer" and isRF then
                local args = {...}
                local argStr = typedArgs(args)
                if not remoteMeta[self] then
                    ensureMeta(self, "function")
                    registerRemote(self)
                end
                local result = _G._RF_OldNamecall(self, ...)
                if State.running and not State.paused and CFG.TrackRemoteFunctions then
                    onRemoteCall(self, "INVOKE", argStr, result)
                end
                return result
            end

            return _G._RF_OldNamecall(self, ...)
        end)
        setreadonly(mt, true)
        print("[LiveScan v10.10] Global namecall hook installed (FireServer + InvokeServer + return)")
    end
end

-- ============ RENDER HOOK (v10.10 UPGRADE) ============
renderHook = function()
    if State.destroyed then return end
    for _, c in ipairs(hookFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end

    -- Kumpulkan semua remote (dari meta + yang ada di game untuk recon)
    local allRemotes = {}
    for r, m in pairs(remoteMeta) do
        if typeof(r) == "Instance" and r.Parent then
            allRemotes[r] = m
        end
    end
    -- Recon: scan idle remote yang belum pernah dipanggil
    if CFG.ReconMode then
        for _, svcName in ipairs(CFG.ScanServices) do
            local svc = game:FindFirstChild(svcName)
            if svc then
                for _, obj in ipairs(svc:GetDescendants()) do
                    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
                       and not allRemotes[obj] then
                        allRemotes[obj] = ensureMeta(obj)
                    end
                end
            end
        end
    end

    -- Pisahkan per jenis, skip yang di-ignore
    local events, funcs = {}, {}
    for r, m in pairs(allRemotes) do
        if not m.ignored then
            local entry = {remote=r, meta=m}
            if r:IsA("RemoteEvent") then table.insert(events, entry)
            elseif r:IsA("RemoteFunction") then table.insert(funcs, entry) end
        end
    end
    table.sort(events, function(a,b)
        if (a.meta.count or 0) ~= (b.meta.count or 0) then
            return (a.meta.count or 0) > (b.meta.count or 0)
        end
        return a.remote.Name < b.remote.Name
    end)
    table.sort(funcs, function(a,b)
        if (a.meta.count or 0) ~= (b.meta.count or 0) then
            return (a.meta.count or 0) > (b.meta.count or 0)
        end
        return a.remote.Name < b.remote.Name
    end)

    -- Header
    local activeEv, activeFn = 0, 0
    for _, e in ipairs(events) do if e.meta.count > 0 then activeEv = activeEv + 1 end end
    for _, e in ipairs(funcs) do if e.meta.count > 0 then activeFn = activeFn + 1 end end

    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
    hdr.BackgroundColor3 = C.RowBgAlt; hdr.BackgroundTransparency = 0.2
    hdr.Text = string.format("  📡 Events: %d/%d  |  📤 Functions: %d/%d",
        activeEv, #events, activeFn, #funcs)
    hdr.TextColor3 = Color3.fromRGB(255,130,200); hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = FONT_SIZE+1; hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.BorderSizePixel = 0; hdr.Parent = hookFrame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0,4)

    -- Helper: render remote row
    local function renderRemoteRow(entry, headerText, headerColor)
        local r, m = entry.remote, entry.meta
        local isActive = m.count > 0
        local rowColor = isActive and Color3.fromRGB(45,30,45) or C.RowBg
        local textColor = isActive and headerColor or Color3.fromRGB(140,140,150)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-4,0,math.max(14,FONT_SIZE+4))
        btn.BackgroundColor3 = rowColor; btn.BackgroundTransparency = 0.35
        btn.Text = ""; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
        btn.Parent = hookFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,3)

        local icon = (r.ClassName == "RemoteEvent" and "📡" or "📤")
        local status = m.ignored and "⊘" or (isActive and "●" or "○")
        local statsStr = ""
        if isActive then
            statsStr = "  ×"..m.count
            if m.skipped > 0 then statsStr = statsStr.." (skip:"..m.skipped..")" end
        end

        local nameStr = icon.." "..status.." "..r.Name..statsStr
        if m.lastArgs and m.lastArgs ~= "" then
            nameStr = nameStr.."  | "..truncate(m.lastArgs, 40)
        end
        if m.lastReturn ~= nil and CFG.TrackInvokeReturn then
            nameStr = nameStr.."  ↩"..truncate(typed(m.lastReturn), 20)
        end

        btn.Text = "  "..nameStr
        btn.TextColor3 = textColor; btn.Font = Enum.Font.Code
        btn.TextSize = math.max(8,FONT_SIZE-1)
        btn.TextXAlignment = Enum.TextXAlignment.Left

        -- Klik untuk detail di log
        btn.MouseButton1Click:Connect(function()
            if m.count == 0 then return end
            addLog("📄 "..r.Name.." | count:"..m.count
                   .." | skip:"..m.skipped
                   .." | last:"..truncate(m.lastArgs or "-", 60)
                   ..(m.lastReturn~=nil and (" | ret:"..typed(m.lastReturn)) or ""),
                   Color3.fromRGB(180,180,255), "SYS")
        end)
    end

    -- Sections
    local function makeSectionLabel(text, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-4,0,math.max(12,FONT_SIZE+1))
        l.BackgroundTransparency = 1; l.Text = "  ── "..text.." ──"
        l.TextColor3 = color; l.Font = Enum.Font.GothamBold
        l.TextSize = FONT_SIZE; l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = hookFrame
    end

    makeSectionLabel("RemoteEvents ("..#events..")", Color3.fromRGB(210,210,210))
    if #events == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
        lbl.BackgroundTransparency = 1; lbl.Text = "  (no events found)"
        lbl.TextColor3 = C.SubText; lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8,FONT_SIZE-1); lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = hookFrame
    else
        for _, entry in ipairs(events) do
            renderRemoteRow(entry, "Events", Color3.fromRGB(255,180,220))
        end
    end

    makeSectionLabel("RemoteFunctions ("..#funcs..")", Color3.fromRGB(255,150,100))
    if #funcs == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
        lbl.BackgroundTransparency = 1; lbl.Text = "  (no functions found)"
        lbl.TextColor3 = C.SubText; lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8,FONT_SIZE-1); lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = hookFrame
    else
        for _, entry in ipairs(funcs) do
            renderRemoteRow(entry, "Functions", Color3.fromRGB(255,200,150))
        end
    end

    -- Legend
    local legend = Instance.new("TextLabel")
    legend.Size = UDim2.new(1,-4,0,math.max(12,FONT_SIZE+1))
    legend.BackgroundTransparency = 1
    legend.Text = "  ● aktif  ○ idle  ⊘ ignore  ×N calls  ↩return"
    legend.TextColor3 = C.SubText; legend.Font = Enum.Font.Code
    legend.TextSize = math.max(7,FONT_SIZE-2); legend.TextXAlignment = Enum.TextXAlignment.Left
    legend.Parent = hookFrame
end

-- ============ BUTTON SCANNER ============
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
                local lowName, lowText = string.lower(name), string.lower(text)
                local isBlacklisted = false
                for _, bl in ipairs(CFG.ButtonBlacklist) do
                    if string.find(lowName, bl, 1, true) or string.find(lowText, bl, 1, true) then
                        isBlacklisted = true; break
                    end
                end
                if not isBlacklisted then
                    local isTracked = false
                    for _, kw in ipairs(CFG.ButtonKeywords) do
                        if string.find(lowName, kw, 1, true) or string.find(lowText, kw, 1, true) then
                            isTracked = true; break
                        end
                    end
                    if isTracked then
                        table.insert(found, {instance=obj, name=name, text=text,
                            size=obj.AbsoluteSize, position=obj.AbsolutePosition, class=obj.ClassName})
                    end
                end
            end
        end
    end
    return found
end

renderButtons = function()
    if State.destroyed then return end
    for _, c in ipairs(btnFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    local buttons = scanButtons()
    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
    hdr.BackgroundColor3 = Color3.fromRGB(45,40,22); hdr.BackgroundTransparency = 0.15
    hdr.Text = "  👆 Buttons: "..#buttons
    hdr.TextColor3 = Color3.fromRGB(255,220,100); hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = FONT_SIZE+1; hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.BorderSizePixel = 0; hdr.Parent = btnFrame
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0,4)
    for i, btn in ipairs(buttons) do
        if i > 30 then break end
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,math.max(14,FONT_SIZE+4))
        lbl.BackgroundColor3 = C.RowBg; lbl.BackgroundTransparency = 0.35
        lbl.Text = string.format("  %s | %s | %.0f,%.0f", btn.name,
            btn.class == "TextButton" and "T" or "I", btn.position.X, btn.position.Y)
        lbl.TextColor3 = Color3.fromRGB(255,220,100); lbl.Font = Enum.Font.Code
        lbl.TextSize = math.max(8,FONT_SIZE-1); lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd; lbl.BorderSizePixel = 0; lbl.Parent = btnFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,3)
    end
    if #buttons == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,math.max(13,FONT_SIZE+3))
        lbl.BackgroundColor3 = C.RowBg; lbl.BackgroundTransparency = 0.35
        lbl.Text = "  No buttons detected"; lbl.TextColor3 = C.SubText
        lbl.Font = Enum.Font.Code; lbl.TextSize = math.max(8,FONT_SIZE-1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.BorderSizePixel = 0
        lbl.Parent = btnFrame
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,3)
    end
end

-- ============ SNAPSHOT ============
local lastSnapshot = {
    attrs={}, stats={}, nearby={}, inventory={}, models={},
    walkspeed=nil, health=nil, ping=nil, tool=nil, currency={}, position=nil,
}
local trackedPlayers = {}

-- ============ CORE SCAN ============
local function scanOnce()
    if State.destroyed or not State.running or State.paused then return end
    if not gui or not gui.Parent then fullKill(); return end
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if CFG.TrackAttrs then
        for k, v in pairs(lp:GetAttributes()) do
            if isIgnoredName(k, CFG.IgnoreAttrPatterns) then
                lastSnapshot.attrs[k] = v
            else
                local old = lastSnapshot.attrs[k]
                if old == nil then lastSnapshot.attrs[k] = v
                elseif tostring(old) ~= tostring(v) then
                    if type(v) == "number" and type(old) == "number" and numAlmostEqual(old, v) then
                        lastSnapshot.attrs[k] = v
                    else
                        local color = Color3.fromRGB(255,220,100)
                        if type(v) == "number" and type(old) == "number" then
                            color = v > old and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,100,100)
                        end
                        addLog("ATTR "..k..": "..fmt(old).." → "..fmt(v), color, "ATTR")
                        lastSnapshot.attrs[k] = v
                    end
                end
            end
        end
    end

    if CFG.TrackStats then
        local ls = lp:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                local old = lastSnapshot.stats[v.Name]
                if old == nil then lastSnapshot.stats[v.Name] = tostring(v.Value)
                elseif tostring(old) ~= tostring(v.Value) then
                    addLog("STAT "..v.Name..": "..tostring(old).." → "..tostring(v.Value),
                           Color3.fromRGB(100,200,255), "STAT")
                    lastSnapshot.stats[v.Name] = tostring(v.Value)
                end
            end
        end
    end

    if hum then
        if CFG.TrackHumanoid and lastSnapshot.walkspeed ~= hum.WalkSpeed then
            if lastSnapshot.walkspeed ~= nil
               and math.abs(hum.WalkSpeed - lastSnapshot.walkspeed) >= 1 then
                addLog("WalkSpeed: "..string.format("%.1f", lastSnapshot.walkspeed)
                       .." → "..string.format("%.1f", hum.WalkSpeed),
                       Color3.fromRGB(255,180,100), "HEALTH")
            end
            lastSnapshot.walkspeed = hum.WalkSpeed
        end
        if CFG.TrackHealth then
            local hp = math.floor(hum.Health)
            if lastSnapshot.health ~= hp then
                if lastSnapshot.health ~= nil then
                    local diff = hp - lastSnapshot.health
                    local color = diff < 0 and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,255,80)
                    addLog("❤ HP: "..lastSnapshot.health.." → "..hp
                           .." ("..(diff > 0 and "+" or "")..diff..")", color, "HEALTH")
                end
                lastSnapshot.health = hp
            end
        end
        if CFG.SpeedHackDetect and hum.WalkSpeed > CFG.MaxSpeedNormal then
            addLog("⚡ SPEED WARN: "..math.floor(hum.WalkSpeed),
                   Color3.fromRGB(255,200,50), "ANOMALY")
        end
    end

    if CFG.TrackNetwork then
        pcall(function()
            local net = Stats:FindFirstChild("Network")
            local ssi = net and net:FindFirstChild("ServerStatsItem")
            local pingObj = ssi and (ssi:FindFirstChild("Data Ping") or ssi:FindFirstChild("Ping"))
            if pingObj then
                local val = math.floor(pingObj:GetValue())
                if lastSnapshot.ping ~= val then
                    if lastSnapshot.ping ~= nil and math.abs(val - lastSnapshot.ping) > 30 then
                        local color = val > 200 and Color3.fromRGB(255,100,100) or Color3.fromRGB(150,200,255)
                        addLog("📡 Ping: "..lastSnapshot.ping.." → "..val.."ms", color, "NET")
                    end
                    lastSnapshot.ping = val
                end
            end
        end)
    end

    if char and CFG.TrackToolEquip then
        local tool = char:FindFirstChildOfClass("Tool")
        local tname = tool and tool.Name or nil
        if lastSnapshot.tool ~= tname then
            if lastSnapshot.tool ~= nil then
                addLog("🔧 Tool: "..tostring(lastSnapshot.tool).." → "..tostring(tname),
                       Color3.fromRGB(255,220,100), "TOOL")
            end
            lastSnapshot.tool = tname
        end
    end

    if CFG.TrackPlayers then
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local current = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp then
                    local pc = p.Character
                    local pr = pc and pc:FindFirstChild("HumanoidRootPart")
                    if pr and (pr.Position - root.Position).Magnitude < CFG.Radius then
                        current[p.UserId] = true
                    end
                end
            end
            for uid in pairs(current) do
                if not trackedPlayers[uid] then
                    trackedPlayers[uid] = true
                    local p = Players:GetPlayerByUserId(uid)
                    addLog("👤 + "..(p and p.Name or uid), Color3.fromRGB(100,255,200), "PLAYER")
                end
            end
            for uid in pairs(trackedPlayers) do
                if not current[uid] then
                    trackedPlayers[uid] = nil
                    local p = Players:GetPlayerByUserId(uid)
                    addLog("👤 − "..(p and p.Name or uid), Color3.fromRGB(255,150,150), "PLAYER")
                end
            end
        end
    end

    if CFG.TrackInventory then
        local function scanContainer(c, label)
            if not c then return end
            for _, item in ipairs(c:GetChildren()) do
                if not (label == "EQ" and isIgnoredEquipItem(item.Name)) then
                    local id = label..":"..item.Name
                    if not lastSnapshot.inventory[id] then
                        lastSnapshot.inventory[id] = true
                        addLog("INV + "..id, Color3.fromRGB(150,255,150), "INV")
                    end
                end
            end
        end
        scanContainer(lp:FindFirstChild("Backpack"), "BP")
        if char then scanContainer(char, "EQ") end
    end

    if CFG.CurrencyRadar then
        local function check(name, value)
            local lower = string.lower(name)
            for _, kw in ipairs(CFG.CurrencyKeywords) do
                if string.find(lower, kw, 1, true) then
                    local old = lastSnapshot.currency[name]
                    local num = tonumber(value)
                    if num and old then
                        local diff = num - old
                        if math.abs(diff) >= 1 then
                            local color = diff > 0 and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,120,120)
                            addLog((diff > 0 and "📈 " or "📉 ")..name..": "..old.." → "..num
                                   .." ("..(diff>0 and "+" or "")..diff..")", color, "CURRENCY")
                        end
                    end
                    if num then lastSnapshot.currency[name] = num end
                    return
                end
            end
        end
        local ls = lp:FindFirstChild("leaderstats")
        if ls then for _, v in ipairs(ls:GetChildren()) do check(v.Name, v.Value) end end
        for k, v in pairs(lp:GetAttributes()) do check(k, v) end
    end

    if CFG.TrackModels then
        local char2 = lp.Character
        local root = char2 and char2:FindFirstChild("HumanoidRootPart")
        if root then
            local cur = {}
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model") and obj ~= char2 then
                    local prim = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if prim then
                        local dist = (prim.Position - root.Position).Magnitude
                        if dist < CFG.Radius then cur[obj] = math.floor(dist) end
                    end
                end
            end
            for obj, dist in pairs(cur) do
                if not lastSnapshot.models[obj] then
                    lastSnapshot.models[obj] = dist
                    addLog("📦 + "..obj.Name.." ("..dist.."m)", Color3.fromRGB(150,200,255), "MODEL")
                end
            end
            for obj in pairs(lastSnapshot.models) do
                if not cur[obj] then
                    if obj and obj.Parent then
                        addLog("📦 − "..obj.Name, Color3.fromRGB(200,150,150), "MODEL")
                    end
                    lastSnapshot.models[obj] = nil
                end
            end
        end
    end

    if CFG.TrackPosition and char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local pos = root.Position
            if lastSnapshot.position then
                local delta = (pos - lastSnapshot.position).Magnitude
                if delta > 5 then
                    addLog(string.format("📍 Pos: (%.0f,%.0f,%.0f) Δ%.0fm",
                        pos.X, pos.Y, pos.Z, delta), Color3.fromRGB(180,180,255), "POS")
                end
            end
            lastSnapshot.position = pos
        end
    end

    if CFG.PatternDetect then
        for r, m in pairs(remoteMeta) do
            if typeof(r) == "Instance" and m.count > 30 then
                if not m._patternFlagged and m.skipped > m.count * 0.8 then
                    m._patternFlagged = true
                    addLog("🧠 PATTERN: "..r.Name.." spam ("..m.count.." calls, "..m.skipped.." dedupe)",
                           Color3.fromRGB(255,140,255), "PATTERN")
                end
            end
        end
    end
end

-- ============ BUTTON HANDLERS ============
btnPause.MouseButton1Click:Connect(function()
    State.paused = not State.paused
    btnPause.Text = State.paused and "RESUME" or "PAUSE"
    btnPause.BackgroundColor3 = State.paused and C.Warning or C.Success
    updatePowerBtn()
end)
btnClear.MouseButton1Click:Connect(function()
    Logs.entries = {}; Logs.categoryCount = {}; Logs.totalCount = 0
    -- FIX: clear semua snapshot
    lastSnapshot.attrs = {}; lastSnapshot.stats = {}
    lastSnapshot.models = {}; lastSnapshot.inventory = {}
    lastSnapshot.currency = {}; lastSnapshot.position = nil
    renderLog()
    btnClear.Text = "OK!"; task.wait(0.6); btnClear.Text = "CLEAR"
end)
btnCopy.MouseButton1Click:Connect(function()
    local lines = {}
    for _, e in ipairs(Logs.entries) do table.insert(lines, e.text) end
    local ok = pcall(function() setclipboard(table.concat(lines, "\n")) end)
    btnCopy.Text = ok and "COPIED!" or "FAIL"
    task.wait(1); btnCopy.Text = "COPY"
end)

-- Tab handler (FIX: filter reset saat pindah tab)
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
        elseif name == "CFG" then renderCfg()
        elseif name == "INFO" then renderInfo()
        elseif name == "HOOK" then renderHook()
        elseif name == "BTN" then renderButtons()
        elseif name == "GAME" then renderGame() end
    end)
end

-- ============ LOOPS (FIX: pcall di semua render loop) ============
task.spawn(function()
    while not State.destroyed do
        task.wait(CFG.ScanInterval)
        if State.running and not State.paused then pcall(scanOnce) end
    end
end)
task.spawn(function()
    while not State.destroyed do
        task.wait(CFG.RenderInterval)
        if State.running and activeTab == "LOG" then pcall(renderLog) end
    end
end)
task.spawn(function()
    while not State.destroyed do
        task.wait(CFG.ButtonScanInterval)
        if State.running and activeTab == "BTN" and CFG.TrackButtons then pcall(renderButtons) end
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

-- ============ INITIAL RENDER ============
renderLog(); renderCfg(); renderInfo(); renderHook(); renderButtons(); renderGame()

print("⚡ [LiveScan v10.10] Loaded! @in666ar")
print("   🔥 FireServer hook (client→server) AKTIF")
print("   📥 RF return value capture AKTIF")
print("   🔎 Dynamic discovery + Recon mode AKTIF")
print("   📡 Tabs: LOG | CFG | INFO | HOOK | BTN | GAME")
