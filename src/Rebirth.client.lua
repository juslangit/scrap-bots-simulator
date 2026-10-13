-- Rebirth window. Explains the trade and asks the server to do it; the server checks the cost.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local rebirthEvent = ReplicatedStorage:WaitForChild("Rebirth")

local player = Players.LocalPlayer

local INK = Color3.fromRGB(22, 36, 43)
local WHITE = Color3.fromRGB(255, 255, 255)
local HAZARD = Color3.fromRGB(242, 183, 5)
local PURPLE = Color3.fromRGB(140, 80, 210)
local GREY = Color3.fromRGB(90, 104, 110)

local gui = Instance.new("ScreenGui")
gui.Name = "Rebirth"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function round(instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = instance
end

local function newButton(parent, size, position, text, color)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = parent
	round(button)
	return button
end

-- Open button, beside the Robots button
local openButton = newButton(gui, UDim2.fromOffset(121, 44), UDim2.new(0, 141, 0.5, 110), "Rebirth", PURPLE)

-- Window, centre of the screen
local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Size = UDim2.fromOffset(360, 290)
window.Position = UDim2.fromScale(0.5, 0.5)
window.BackgroundColor3 = INK
window.BackgroundTransparency = 0.05
window.BorderSizePixel = 0
window.Visible = false
window.Parent = gui
round(window)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -72, 0, 24)
title.Position = UDim2.fromOffset(14, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = HAZARD
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = window

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -28, 0, 170)
body.Position = UDim2.fromOffset(14, 50)
body.BackgroundTransparency = 1
body.Font = Enum.Font.GothamMedium
body.TextSize = 15
body.TextColor3 = WHITE
body.TextWrapped = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Parent = window

local closeButton = newButton(window, UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 8), "X", GREY)
local confirmButton = newButton(window, UDim2.new(1, -28, 0, 48), UDim2.new(0, 14, 1, -60), "", PURPLE)

local function percent(rebirths)
	return math.floor(Config.RebirthBonus * rebirths * 100 + 0.5)
end

local function refresh()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local coins = player:GetAttribute("Coins") or 0
	local cost = Config.rebirthCost(rebirths)

	local slotLine = ""
	if Config.botSlots(rebirths + 1) > Config.botSlots(rebirths) then
		slotLine = "\nYou also get 1 more robot slot."
	end

	title.Text = "Rebirth " .. (rebirths + 1)
	body.Text = string.format(
		"Cost: %s coins\n\nYou lose: coins, tools, backpacks and unlocked zones.\nYou keep: all your robots.\n\n"
			.. "Coin bonus goes from +%d%% to +%d%%, forever.%s",
		Config.format(cost), percent(rebirths), percent(rebirths + 1), slotLine)

	if coins >= cost then
		confirmButton.Text = "Rebirth now"
		confirmButton.BackgroundColor3 = PURPLE
	else
		confirmButton.Text = string.format("Need %s more coins", Config.format(cost - coins))
		confirmButton.BackgroundColor3 = GREY
	end
end

openButton.Activated:Connect(function()
	window.Visible = not window.Visible
end)
closeButton.Activated:Connect(function()
	window.Visible = false
end)
confirmButton.Activated:Connect(function()
	if (player:GetAttribute("Coins") or 0) >= Config.rebirthCost(player:GetAttribute("Rebirths") or 0) then
		rebirthEvent:FireServer()
		window.Visible = false
	end
end)

player:GetAttributeChangedSignal("Coins"):Connect(refresh)
player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
refresh()
