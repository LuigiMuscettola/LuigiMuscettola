-- Trade Control V1.1: local simulated trades only.
-- No real inventory, game remotes, or other player input is accessed.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("TradeControl")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TradeControl"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(290, 325)
frame.Position = UDim2.new(0.5, -145, 0.5, -162)
frame.BackgroundColor3 = Color3.fromRGB(19, 21, 30)
Instance.new("UICorner", frame)

local function label(text, y, h)
    local l = Instance.new("TextLabel", frame)
    l.Size = UDim2.new(1, -20, 0, h)
    l.Position = UDim2.fromOffset(10, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(235,235,245)
    l.TextSize = 14
    l.TextWrapped = true
    l.Font = Enum.Font.GothamBold
    l.Text = text
    return l
end

local function button(text, y, callback)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -20, 0, 32)
    b.Position = UDim2.fromOffset(10, y)
    b.BackgroundColor3 = Color3.fromRGB(45,49,70)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = text
    Instance.new("UICorner", b)
    b.Activated:Connect(callback)
    return b
end

local title = label("TRADE CONTROL - SIMULATOR  [MOVE]", 5, 30)
title.Active = true
title.TextSize = 12

-- Drag the title using a mouse or one finger, without intercepting buttons.
local UIS = game:GetService("UserInputService")
local dragInput, startPointer, startPosition
local function movePanel(pointer)
    if not startPosition or not startPointer then return end
    local delta = pointer - startPointer
    local bounds = gui.AbsoluteSize
    local size = frame.AbsoluteSize
    local x = startPosition.X.Scale * bounds.X + startPosition.X.Offset + delta.X
    local y = startPosition.Y.Scale * bounds.Y + startPosition.Y.Offset + delta.Y
    -- Keep the title reachable even on a small screen.
    x = math.clamp(x, 0, math.max(0, bounds.X - size.X))
    y = math.clamp(y, 0, math.max(0, bounds.Y - math.min(size.Y, 40)))
    frame.Position = UDim2.fromOffset(x, y)
end

local begin = title.InputBegan:Connect(function(input)
    if dragInput then return end
    local kind = input.UserInputType
    if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
        dragInput = input
        startPointer = input.Position
        startPosition = frame.Position
    end
end)

local changed = UIS.InputChanged:Connect(function(input)
    if not dragInput then return end
    if dragInput.UserInputType == Enum.UserInputType.Touch then
        if input == dragInput then movePanel(input.Position) end
    elseif input.UserInputType == Enum.UserInputType.MouseMovement then
        movePanel(input.Position)
    end
end)

local ended = UIS.InputEnded:Connect(function(input)
    if input == dragInput or (dragInput and
        dragInput.UserInputType == Enum.UserInputType.MouseButton1 and
        input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragInput, startPointer, startPosition = nil, nil, nil
    end
end)

gui.Destroying:Connect(function()
    begin:Disconnect()
    changed:Disconnect()
    ended:Disconnect()
end)
local status = label("In attesa", 38, 30)
local offerLabel = label("Offerta: --", 68, 25)

local active = false
local npcAccepted = false
local localAccepted = false
local autoAccept = false
local forceNPC = false
local stableSince = 0
local offer = "Dragon"
local safeTime = 2

local function reset()
    active = false
    npcAccepted = false
    localAccepted = false
    status.TextColor3 = Color3.fromRGB(235,235,245)
end

local function startTrade()
    reset()
    active = true
    offer = "Dragon"
    stableSince = os.clock()
    offerLabel.Text = "Offerta NPC: " .. offer
    status.Text = "Scambio simulato aperto"
end

local function changeOffer()
    if not active then return end
    offer = offer == "Dragon" and "Rocket" or "Dragon"
    stableSince = os.clock()
    npcAccepted = false
    localAccepted = false
    offerLabel.Text = "Offerta NPC: " .. offer
    status.Text = "Anti-Swap: conferme annullate"
end

button("AVVIA SCAMBIO NPC", 100, startTrade)

local forceButton
forceButton = button("FORCE ACCEPT NPC: OFF", 136, function()
    forceNPC = not forceNPC
    forceButton.Text = "FORCE ACCEPT NPC: " .. (forceNPC and "ON" or "OFF")
end)

local autoButton
autoButton = button("AUTO ACCEPT: OFF", 172, function()
    autoAccept = not autoAccept
    autoButton.Text = "AUTO ACCEPT: " .. (autoAccept and "ON" or "OFF")
end)

button("SIMULA CAMBIO FRUTTO", 208, changeOffer)

button("ACCETTA MANUALMENTE", 244, function()
    if not active then return end
    if os.clock() - stableSince < safeTime then
        status.Text = "Attendi stabilizzazione"
        return
    end
    if offer ~= "Dragon" then
        status.Text = "Offerta non autorizzata"
        return
    end
    localAccepted = true
end)

local stop = button("EMERGENCY STOP", 280, function()
    reset()
    status.Text = "Scambio annullato"
    offerLabel.Text = "Offerta: --"
end)
stop.BackgroundColor3 = Color3.fromRGB(155,40,50)

task.spawn(function()
    while gui.Parent do
        task.wait(0.05)
        if not gui.Parent then break end
        if not active then continue end
        if os.clock() - stableSince < safeTime then continue end
        if forceNPC then npcAccepted = true end
        if offer ~= "Dragon" then
            status.Text = "Protezione: offerta rifiutata"
            continue
        end
        if autoAccept and npcAccepted then localAccepted = true end
        if npcAccepted and localAccepted then
            reset()
            status.Text = "SCAMBIO SIMULATO COMPLETATO"
            status.TextColor3 = Color3.fromRGB(80,255,140)
        elseif npcAccepted then
            status.Text = "NPC ha accettato"
        elseif localAccepted then
            status.Text = "In attesa dell'NPC"
        else
            status.Text = "In attesa di conferma"
        end
    end
end)
