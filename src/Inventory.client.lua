-- Robot inventory. Shows the bots the server says the player owns and asks it to equip or merge.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local botEvent = ReplicatedStorage:WaitForChild("BotAction")

local player = Players.LocalPlayer

local INK = Color3.fromRGB(22, 36, 43)
local ROW = Color3.fromRGB(40, 58, 66)
local WHITE = Color3.fromRGB(255, 255, 255)
local HAZARD = Color3.fromRGB(242, 183, 5)
local TEAL = Color3.fromRGB(18, 105, 107)
local GREY = Color3.fromRGB(90, 104, 110)
local RED = Color3.fromRGB(190, 60, 55)

local gui = Instance.new("ScreenGui")
gui.Name = "Inventory"
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
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = WHITE
	button.Text = text
	button.Parent = parent
	round(button)
	return button
end

local function newLabel(parent, size, position, textSize, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

-- Open button, under the stats panel
local openButton = newButton(gui, UDim2.fromOffset(121, 44), UDim2.new(0, 12, 0.5, 110), "Robots", TEAL)

-- Window, centre of the screen
local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Size = UDim2.new(0, 380, 0.85, 0)
window.Position = UDim2.fromScale(0.5, 0.5)
window.BackgroundColor3 = INK
window.BackgroundTransparency = 0.05
window.BorderSizePixel = 0
window.Visible = false
window.Parent = gui
round(window)

local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(380, 440)
limit.Parent = window

local title = newLabel(window, UDim2.new(1, -72, 0, 24), UDim2.fromOffset(14, 10), 20, HAZARD)
local summary = newLabel(window, UDim2.new(1, -72, 0, 18), UDim2.fromOffset(14, 36), 14, WHITE)
local closeButton = newButton(window, UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 8), "X", GREY)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -74)
list.Position = UDim2.fromOffset(10, 64)
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

local function readBots()
	local ok, bots = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Bots") or "[]")
	end)
	return ok and type(bots) == "table" and bots or {}
end

local function percent(value)
	return math.floor(value * 100 + 0.5)
end

local function refresh()
	for _, child in ipairs(list:GetChildren()) do
		if child ~= layout then
			child:Destroy()
		end
	end

	local bots = readBots()
	local equipped = 0
	local spare = {} -- [id] = number of unpolished copies
	for _, bot in ipairs(bots) do
		if bot.equipped then
			equipped = equipped + 1
		end
		if not bot.polished then
			spare[bot.id] = (spare[bot.id] or 0) + 1
		end
	end

	title.Text = string.format("Robots %d / %d", #bots, Config.MaxBots)
	summary.Text = string.format("%d of %d equipped, +%d%% coins", equipped,
		Config.botSlots(player:GetAttribute("Rebirths") or 0),
		percent(player:GetAttribute("CoinBonus") or 0))
	openButton.Text = string.format("Robots (%d)", #bots)

	local order = 0

	-- Merge buttons first, so they are easy to find.
	for id, count in pairs(spare) do
		local bot = Config.Bots[id]
		if bot and count >= Config.MergeCount then
			order = order + 1
			local merge = newButton(list, UDim2.new(1, -8, 0, 44), UDim2.new(),
				string.format("Merge %d x %s into Polished", Config.MergeCount, bot.name), HAZARD)
			merge.TextColor3 = INK
			merge.LayoutOrder = order
			merge.Activated:Connect(function()
				botEvent:FireServer("merge", id)
			end)
		end
	end

	if #bots == 0 then
		local empty = newLabel(list, UDim2.new(1, -8, 0, 44), UDim2.new(), 15, WHITE)
		empty.TextWrapped = true
		empty.Text = "No robots yet. Open a Bot Crate next to the crusher."
		return
	end

	for index, bot in ipairs(bots) do
		local info = Config.Bots[bot.id]
		local bonus = Config.botStats(bot.id, bot.polished)
		if info and bonus then
			local rarity = Config.Rarities[info.rarity]
			order = order + 1

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 52)
			row.BackgroundColor3 = ROW
			row.BorderSizePixel = 0
			row.LayoutOrder = order
			row.Parent = list
			round(row)

			local name = newLabel(row, UDim2.new(1, -196, 0, 22), UDim2.fromOffset(10, 6), 16, rarity.color)
			name.Text = (bot.polished and "Polished " or "") .. info.name
			local detail = newLabel(row, UDim2.new(1, -196, 0, 18), UDim2.fromOffset(10, 28), 13, WHITE)
			detail.Text = string.format("%s, +%d%% coins", rarity.name, percent(bonus))

			local toggle = newButton(row, UDim2.fromOffset(84, 40), UDim2.new(1, -180, 0, 6),
				bot.equipped and "Unequip" or "Equip", bot.equipped and GREY or TEAL)
			toggle.TextSize = 14
			toggle.Activated:Connect(function()
				botEvent:FireServer(bot.equipped and "unequip" or "equip", bot.id, index)
			end)

			-- Scrapping needs a second tap, so a robot is never lost by accident.
			local scrapText = "Scrap +" .. Config.format(Config.botRefund(bot.id, bot.polished))
			local scrap = newButton(row, UDim2.fromOffset(84, 40), UDim2.new(1, -90, 0, 6), scrapText, RED)
			scrap.TextSize = 14
			local armed = false
			scrap.Activated:Connect(function()
				if armed then
					botEvent:FireServer("scrap", bot.id, index)
					return
				end
				armed = true
				scrap.Text = "Sure?"
				task.delay(2.5, function()
					armed = false
					if scrap.Parent then
						scrap.Text = scrapText
					end
				end)
			end)
		end
	end
end

openButton.Activated:Connect(function()
	window.Visible = not window.Visible
end)
closeButton.Activated:Connect(function()
	window.Visible = false
end)

player:GetAttributeChangedSignal("Bots"):Connect(refresh)
player:GetAttributeChangedSignal("CoinBonus"):Connect(refresh)
player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
refresh()
