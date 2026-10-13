-- On-screen display. Reads values the server puts on the player; never changes them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local notifyEvent = ReplicatedStorage:WaitForChild("Notify")

local player = Players.LocalPlayer

local INK = Color3.fromRGB(22, 36, 43)
local WHITE = Color3.fromRGB(255, 255, 255)
local HAZARD = Color3.fromRGB(242, 183, 5)

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function newLabel(parent, size, position, textSize, bold)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	label.TextSize = textSize
	label.TextColor3 = WHITE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

-- Stats panel, left side
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(250, 204)
panel.Position = UDim2.new(0, 12, 0.5, -102)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local coinsLabel = newLabel(panel, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 8), 24, true)
coinsLabel.TextColor3 = HAZARD
local bagLabel = newLabel(panel, UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 42), 16, true)

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(1, -24, 0, 10)
barBack.Position = UDim2.fromOffset(12, 66)
barBack.BackgroundColor3 = Color3.fromRGB(60, 78, 86)
barBack.BorderSizePixel = 0
barBack.Parent = panel

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = HAZARD
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local toolLabel = newLabel(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 88), 14, false)
local nextToolLabel = newLabel(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 106), 14, false)
local nextBagLabel = newLabel(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 124), 14, false)
local nextZoneLabel = newLabel(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 142), 14, false)
local bonusLabel = newLabel(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 160), 14, false)
local rebirthLabel = newLabel(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 178), 14, false)

-- Message banner, top centre
local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(420, 40)
toast.Position = UDim2.new(0.5, -210, 0, 70)
toast.BackgroundColor3 = INK
toast.BackgroundTransparency = 0.1
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBold
toast.TextSize = 18
toast.TextColor3 = WHITE
toast.TextWrapped = true
toast.Visible = false
toast.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toast

local toastToken = 0
notifyEvent.OnClientEvent:Connect(function(message)
	toastToken = toastToken + 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	task.delay(2.5, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end)

-- "+3" pop-up each time scrap is collected
local function popup(amount)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(120, 36)
	label.Position = UDim2.new(0.5, math.random(-90, 30), 0.5, math.random(-70, -30))
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 28
	label.TextColor3 = HAZARD
	label.TextStrokeTransparency = 0
	label.Text = "+" .. Config.format(amount)
	label.Parent = gui

	local tween = TweenService:Create(label, TweenInfo.new(0.6), {
		Position = label.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		label:Destroy()
	end)
	tween:Play()
end

local function describeNext(prefix, item)
	if item then
		return string.format("%s: %s (%s)", prefix, item.name, Config.format(item.cost))
	end
	return prefix .. ": max"
end

-- Signs above the tool bench and backpack stand. The server builds them; the text is set here
-- because the next price is different for each player.
local map = Workspace:WaitForChild("Map")

local function priceLine(item)
	if item then
		return string.format("%s: %s coins", item.name, Config.format(item.cost))
	end
	return "You own the best one"
end

local function setSign(zoneFolder, partName, text)
	local part = zoneFolder:FindFirstChild(partName)
	local sign = part and part:FindFirstChild("Label")
	local label = sign and sign:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

local function refreshSigns()
	local toolText = "TOOL BENCH\n" .. priceLine(Config.Tools[(player:GetAttribute("ToolIndex") or 1) + 1])
	local bagText = "BACKPACKS\n" .. priceLine(Config.Backpacks[(player:GetAttribute("BackpackIndex") or 1) + 1])
	for _, zoneFolder in ipairs(map:GetChildren()) do
		setSign(zoneFolder, "ToolBench", toolText)
		setSign(zoneFolder, "BackpackStand", bagText)
	end
end

-- Signs in far zones can load late.
map.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("TextLabel") then
		task.defer(refreshSigns)
	end
end)

local lastScrap = nil

local function refresh()
	local coins = player:GetAttribute("Coins") or 0
	local scrap = player:GetAttribute("Scrap") or 0
	local toolIndex = player:GetAttribute("ToolIndex") or 1
	local backpackIndex = player:GetAttribute("BackpackIndex") or 1
	local zoneIndex = player:GetAttribute("ZoneIndex") or 1

	local tool = Config.Tools[toolIndex]
	local backpack = Config.Backpacks[backpackIndex]

	coinsLabel.Text = Config.format(coins) .. " coins"
	bagLabel.Text = string.format("Backpack %s / %s", Config.format(scrap), Config.format(backpack.capacity))
	barFill.Size = UDim2.fromScale(math.clamp(scrap / backpack.capacity, 0, 1), 1)
	toolLabel.Text = string.format("Tool: %s (+%d per tap)", tool.name, tool.power)
	nextToolLabel.Text = describeNext("Next tool", Config.Tools[toolIndex + 1])
	nextBagLabel.Text = describeNext("Next backpack", Config.Backpacks[backpackIndex + 1])
	nextZoneLabel.Text = describeNext("Next zone", Config.Zones[zoneIndex + 1])
	bonusLabel.Text = string.format("Robots: +%d%% coins", math.floor((player:GetAttribute("CoinBonus") or 0) * 100 + 0.5))

	local rebirths = player:GetAttribute("Rebirths") or 0
	rebirthLabel.Text = string.format("Rebirths: %d (+%d%% coins)", rebirths,
		math.floor(Config.RebirthBonus * rebirths * 100 + 0.5))

	refreshSigns()

	if lastScrap ~= nil and scrap > lastScrap then
		popup(scrap - lastScrap)
	end
	lastScrap = scrap
end

player.AttributeChanged:Connect(refresh)
refresh()
