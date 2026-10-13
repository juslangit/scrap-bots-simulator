-- Developer panel. Only shown to players the server marks as developers; the server checks again on every request.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local devEvent = ReplicatedStorage:WaitForChild("DevAction")

local player = Players.LocalPlayer

local INK = Color3.fromRGB(22, 36, 43)
local WHITE = Color3.fromRGB(255, 255, 255)
local HAZARD = Color3.fromRGB(242, 183, 5)
local ORANGE = Color3.fromRGB(215, 110, 40)
local ROW = Color3.fromRGB(40, 58, 66)
local RED = Color3.fromRGB(190, 60, 55)
local GREY = Color3.fromRGB(90, 104, 110)

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
	button.TextSize = 15
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = parent
	round(button)
	return button
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dev"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Open button, right edge of the screen
	local openButton = newButton(gui, UDim2.fromOffset(70, 44), UDim2.new(1, -82, 0.5, -22), "DEV", ORANGE)

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(1, 0.5)
	window.Size = UDim2.new(0, 250, 0.85, 0)
	window.Position = UDim2.new(1, -92, 0.5, 0)
	window.BackgroundColor3 = INK
	window.BackgroundTransparency = 0.05
	window.BorderSizePixel = 0
	window.Visible = false
	window.Parent = gui
	round(window)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(250, 560)
	limit.Parent = window

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -28, 0, 24)
	title.Position = UDim2.fromOffset(14, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = HAZARD
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Developer"
	title.Parent = window

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -52)
	list.Position = UDim2.fromOffset(10, 42)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function action(text, color, name, value)
		order = order + 1
		local button = newButton(list, UDim2.new(1, -8, 0, 40), UDim2.new(), text, color)
		button.LayoutOrder = order
		button.Activated:Connect(function()
			devEvent:FireServer(name, value)
		end)
		return button
	end

	for _, amount in ipairs({ 1000, 100000, 10000000, 1000000000 }) do
		action("+" .. Config.format(amount) .. " coins", ROW, "coins", amount)
	end
	for zoneIndex, zone in ipairs(Config.Zones) do
		if Config.Crates[zoneIndex] then
			action("Free robot: " .. zone.name, ROW, "robot", zoneIndex)
		end
	end
	action("Best tool and backpack", ROW, "gear")
	action("Unlock all zones", ROW, "zones")
	action("+1 rebirth", ROW, "rebirth")

	-- Wiping the save needs a second tap.
	order = order + 1
	local reset = newButton(list, UDim2.new(1, -8, 0, 40), UDim2.new(), "Wipe my save", RED)
	reset.LayoutOrder = order
	local armed = false
	reset.Activated:Connect(function()
		if armed then
			armed = false
			reset.Text = "Wipe my save"
			devEvent:FireServer("reset")
			return
		end
		armed = true
		reset.Text = "Sure? Tap again"
		task.delay(2.5, function()
			if armed then
				armed = false
				reset.Text = "Wipe my save"
			end
		end)
	end)

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
		openButton.BackgroundColor3 = window.Visible and GREY or ORANGE
	end)
end

if player:GetAttribute("Developer") then
	build()
else
	local connection
	connection = player:GetAttributeChangedSignal("Developer"):Connect(function()
		if player:GetAttribute("Developer") then
			connection:Disconnect()
			build()
		end
	end)
end
