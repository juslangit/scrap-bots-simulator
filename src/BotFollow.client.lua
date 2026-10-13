-- Draws every player's equipped robots following them. Visual only; the server tracks bots as numbers.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Props = require(ReplicatedStorage:WaitForChild("Props"))

local ROOT_HEIGHT = 3 -- studs from a character's root part down to the ground

-- The robot model must have fully arrived before the first copy is made.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local folder = Instance.new("Folder")
folder.Name = "BotVisuals"
folder.Parent = Workspace

local visuals = {} -- [player] = list of models

local function clear(target)
	for _, model in ipairs(visuals[target] or {}) do
		model:Destroy()
	end
	visuals[target] = nil
end

-- Builds one robot standing on the origin with its pivot at its feet.
local function newBot(bot, info)
	local rarity = Config.Rarities[info.rarity]
	local height = 2.4 + 0.35 * info.rarity

	local model = Props.make("Robot", false)
	if model then
		Props.fit(model, Vector3.new(height, height, height), Vector3.new(0, height / 2, 0), false)
		Props.turn(model, Config.PropYaw.Robot or 0)
		for _, part in ipairs(Props.parts(model)) do
			if not part:FindFirstAncestorWhichIsA("Accessory") then
				part.Color = rarity.color
				if bot.polished then
					part.Material = Enum.Material.Neon
				end
			end
		end
	else
		-- No robot model in this build: fall back to a plain block.
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Anchored = true
		block.CanCollide = false
		block.CanQuery = false
		block.CanTouch = false
		block.Size = Vector3.new(height, height, height) * 0.7
		block.Position = Vector3.new(0, block.Size.Y / 2, 0)
		block.Color = rarity.color
		block.Material = bot.polished and Enum.Material.Neon or Enum.Material.Metal
		block.Parent = model
		model.WorldPivot = CFrame.new()
	end
	model.Name = info.id

	-- Invisible part at the feet that carries the name tag.
	local anchor = Instance.new("Part")
	anchor.Name = "Tag"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = model:GetPivot()
	anchor.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 1) -- in studs, so the name keeps its size in the world at any distance
	gui.StudsOffset = Vector3.new(0, height + 1, 0)
	gui.MaxDistance = 45
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rarity.color
	label.TextStrokeTransparency = 0
	label.Text = (bot.polished and "Polished " or "") .. info.name
	label.Parent = gui

	return model
end

local function rebuild(target)
	clear(target)

	local ok, bots = pcall(function()
		return HttpService:JSONDecode(target:GetAttribute("Bots") or "[]")
	end)
	if not ok or type(bots) ~= "table" then
		return
	end

	local models = {}
	for _, bot in ipairs(bots) do
		local info = Config.Bots[bot.id]
		if bot.equipped and info then
			table.insert(models, newBot(bot, info))
		end
	end
	visuals[target] = models
end

local function watch(target)
	target:GetAttributeChangedSignal("Bots"):Connect(function()
		rebuild(target)
	end)
	rebuild(target)
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)
for _, target in ipairs(Players:GetPlayers()) do
	task.spawn(watch, target)
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for target, models in pairs(visuals) do
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		for slot, model in ipairs(models) do
			if root then
				-- A row behind the owner, bobbing a little.
				local x = (slot - (#models + 1) / 2) * 4
				local y = -ROOT_HEIGHT + 0.3 + math.sin(now * 3 + slot) * 0.3
				local goal = root.CFrame * CFrame.new(x, y, 5)
				if model.Parent ~= folder then
					model:PivotTo(goal)
					model.Parent = folder
				else
					model:PivotTo(model:GetPivot():Lerp(goal, math.min(1, dt * 8)))
				end
			else
				model.Parent = nil
			end
		end
	end
end)
