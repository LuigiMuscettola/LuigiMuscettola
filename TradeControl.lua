-- Trade Control V1.2: local, synthetic trade simulation.
-- No real inventory, game remotes, or other player input is accessed.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("TradeControl")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TradeControl"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local W, H = 330, 390
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(W, H)
panel.BackgroundColor3 = Color3.fromRGB(19, 21, 30)
panel.Parent = root
Instance.new("UICorner", panel)
local scale = Instance.new("UIScale", panel)

local connections = {}
local alive = true
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function text(value, y, h)
    local l = Instance.new("TextLabel", panel)
    l.Size = UDim2.new(1, -20, 0, h)
    l.Position = UDim2.fromOffset(10, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(235, 235, 245)
    l.TextSize = 14
    l.TextWrapped = true
    l.Font = Enum.Font.GothamBold
    l.Text = value
    return l
end

local function button(value, y, fn)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(1, -20, 0, 32)
    b.Position = UDim2.fromOffset(10, y)
    b.BackgroundColor3 = Color3.fromRGB(45, 49, 70)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.Text = value
    Instance.new("UICorner", b)
    connect(b.Activated, fn)
    return b
end

local title = text("TRADE SIMULATOR V1.2  [MOVE]", 4, 32)
title.Active = true
local status = text("In attesa", 38, 36)
local offerText = text("Offerta NPC: --", 75, 29)
local detail = text("Nessuna conferma", 104, 28)
detail.TextSize = 12

local positioned = false
local dragInput, startPointer, startPosition
local function place(x, y)
    local b = root.AbsoluteSize
    panel.Position = UDim2.fromOffset(
        math.clamp(x, 0, math.max(0, b.X - W * scale.Scale)),
        math.clamp(y, 0, math.max(0, b.Y - H * scale.Scale))
    )
end

local function resize()
    local b = root.AbsoluteSize
    if b.X < 1 or b.Y < 1 then return end
    scale.Scale = math.min(1, b.X / W, b.Y / H)
    if not positioned then
        place((b.X - W * scale.Scale) / 2, (b.Y - H * scale.Scale) / 2)
        positioned = true
    else
        place(panel.Position.X.Offset, panel.Position.Y.Offset)
    end
    dragInput, startPointer, startPosition = nil, nil, nil
end
connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
resize()
task.defer(function() if alive then resize() end end)

connect(title.InputBegan, function(i)
    if dragInput then return end
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
        dragInput = i
        startPointer = i.Position
        startPosition = panel.Position
    end
end)
connect(UIS.InputChanged, function(i)
    if not dragInput then return end
    if (dragInput.UserInputType == Enum.UserInputType.Touch and i == dragInput)
        or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - startPointer
        place(startPosition.X.Offset + d.X, startPosition.Y.Offset + d.Y)
    end
end)
connect(UIS.InputEnded, function(i)
    if i == dragInput then dragInput, startPointer, startPosition = nil, nil, nil end
end)
connect(UIS.WindowFocusReleased, function()
    dragInput, startPointer, startPosition = nil, nil, nil
end)

-- Synthetic catalog and offers; names do not come from a live game.
local catalog = {dragon = "Dragon", kitsune = "Kitsune", leopard = "Leopard",
    dough = "Dough", rocket = "Rocket"}
local scenarios = {
    {"dragon"}, {"kitsune"}, {"leopard", "dough"},
    {"rocket"}, {}, {"dragon", "rocket"}, {"dragon", "dragon"}
}
local allowed = {dragon = true, kitsune = true, leopard = true, dough = true}
local SAFE_TIME = 2
local state = "idle"
local offer = {}
local scenario = 1
local revision = 0
local changedAt = 0
local npcRevision, ownRevision
local npcAuto, ownAuto = false, false
local neutral = Color3.fromRGB(235,235,245)
local green = Color3.fromRGB(80,255,140)
local red = Color3.fromRGB(255,125,125)

local function offerKey(items)
    local copy = table.clone(items)
    table.sort(copy)
    return table.concat(copy, "|")
end

local function validOffer()
    if #offer == 0 then return false end
    for _, id in ipairs(offer) do
        if not catalog[id] or not allowed[id] then return false end
    end
    return true
end

local function stable()
    return os.clock() - changedAt >= SAFE_TIME
end

local function setOffer(items)
    local nextOffer = table.clone(items)
    if offerKey(offer) == offerKey(nextOffer) then return false end
    offer = nextOffer
    revision += 1
    changedAt = os.clock()
    npcRevision, ownRevision = nil, nil
    return true
end

local function renderOffer()
    local names = {}
    for _, id in ipairs(offer) do
        table.insert(names, catalog[id] or "Sconosciuto")
    end
    offerText.Text = "Offerta NPC: " .. (#names > 0 and table.concat(names, " + ") or "vuota")
end

local function render()
    if state ~= "open" then return end
    renderOffer()
    local valid = validOffer()
    local remaining = math.max(0, SAFE_TIME - (os.clock() - changedAt))
    local npcOk = npcRevision == revision
    local ownOk = ownRevision == revision
    detail.Text = string.format("Rev %d | NPC %s | Tu %s", revision,
        npcOk and "OK" or "--", ownOk and "OK" or "--")
    status.TextColor3 = valid and neutral or red
    if not valid then
        status.Text = "Protezione: offerta non autorizzata"
    elseif remaining > 0 then
        status.Text = string.format("Anti-Swap: stabilita %.1f s", remaining)
    elseif npcOk and ownOk then
        state = "complete"
        status.Text = "SCAMBIO SIMULATO COMPLETATO"
        status.TextColor3 = green
    elseif npcOk then
        status.Text = "NPC ha confermato"
    elseif ownOk then
        status.Text = "Attesa conferma NPC"
    else
        status.Text = "Offerta stabile: attesa conferme"
    end
end

local function advance()
    if state ~= "open" then return end
    if validOffer() and stable() then
        if npcAuto then npcRevision = revision end
        if ownAuto and npcRevision == revision then ownRevision = revision end
    end
    render()
end

button("AVVIA SCAMBIO NPC", 136, function()
    state = "open"
    scenario = 1
    offer = table.clone(scenarios[scenario])
    revision += 1
    changedAt = os.clock()
    npcRevision, ownRevision = nil, nil
    advance()
end)

local npcButton, ownButton
npcButton = button("NPC AUTO: OFF", 172, function()
    npcAuto = not npcAuto
    npcButton.Text = "NPC AUTO: " .. (npcAuto and "ON" or "OFF")
    if not npcAuto and state == "open" then npcRevision = nil end
    advance()
end)
ownButton = button("AUTO ACCEPT: OFF", 208, function()
    ownAuto = not ownAuto
    ownButton.Text = "AUTO ACCEPT: " .. (ownAuto and "ON" or "OFF")
    if not ownAuto and state == "open" then ownRevision = nil end
    advance()
end)

button("SIMULA CAMBIO FRUTTI", 244, function()
    if state ~= "open" then return end
    scenario = scenario % #scenarios + 1
    setOffer(scenarios[scenario])
    advance()
end)

button("CONFERMA NPC (TEST)", 280, function()
    if state == "open" and stable() and validOffer() then
        npcRevision = revision
        advance()
    end
end)
button("ACCETTA MANUALMENTE", 316, function()
    if state == "open" and stable() and validOffer() then
        ownRevision = revision
        advance()
    end
end)
local stop = button("EMERGENCY STOP", 352, function()
    state = "cancelled"
    revision += 1
    offer = {}
    npcRevision, ownRevision = nil, nil
    npcAuto, ownAuto = false, false
    npcButton.Text = "NPC AUTO: OFF"
    ownButton.Text = "AUTO ACCEPT: OFF"
    status.Text = "Scambio annullato"
    status.TextColor3 = red
    offerText.Text = "Offerta NPC: --"
    detail.Text = "Nessuna conferma"
end)
stop.BackgroundColor3 = Color3.fromRGB(155,40,50)

gui.Destroying:Connect(function()
    alive = false
    for _, c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
end)

task.spawn(function()
    while alive and gui.Parent do
        task.wait(0.1)
        if not alive or not gui.Parent then break end
        advance()
    end
end)
