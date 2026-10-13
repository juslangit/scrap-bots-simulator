-- Game rules. The server decides every amount; clients only tap, walk and trigger prompts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Data = require(script.Parent:WaitForChild("Data"))
local World = require(script.Parent:WaitForChild("World"))
local Bots = require(script.Parent:WaitForChild("Bots"))

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = ReplicatedStorage

local botEvent = Instance.new("RemoteEvent")
botEvent.Name = "BotAction"
botEvent.Parent = ReplicatedStorage

local rebirthEvent = Instance.new("RemoteEvent")
rebirthEvent.Name = "Rebirth"
rebirthEvent.Parent = ReplicatedStorage

local devEvent = Instance.new("RemoteEvent")
devEvent.Name = "DevAction"
devEvent.Parent = ReplicatedStorage

-- Roblox user ids allowed to use the developer panel. The check is done here, never on the client.
local DEVELOPERS = {
	[2971849098] = true, -- juslangit
}
local DEV_MAX_COINS = 1e12 -- most coins one request can add

local zones = World.build()

local lastTap = {} -- [player] = os.clock()
local lastFullNotice = {} -- [player] = os.clock()
local lastBotAction = {} -- [player] = os.clock()

local function notify(player, message)
	notifyEvent:FireClient(player, message)
end

-- Copies the bot list onto the player. Every client reads it to draw the robots.
local function syncBots(player, data)
	local bonus = Bots.totals(data)
	player:SetAttribute("Bots", Bots.encode(data))
	player:SetAttribute("CoinBonus", bonus)
end

-- Copies saved data onto the player so the HUD and leaderboard can read it.
local function sync(player, data)
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("Scrap", data.scrap)
	player:SetAttribute("ToolIndex", data.toolIndex)
	player:SetAttribute("BackpackIndex", data.backpackIndex)
	player:SetAttribute("ZoneIndex", data.zoneIndex)
	player:SetAttribute("Rebirths", data.rebirths)

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins then
		coins.Value = data.coins
	end
	local rebirths = stats and stats:FindFirstChild("Rebirths")
	if rebirths then
		rebirths.Value = data.rebirths
	end
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleport(player, zoneIndex)
	local character = player.Character
	if character then
		character:PivotTo(zones[zoneIndex].arrival)
	end
end

-- Collecting ----------------------------------------------------------------

local function setupPile(pile, zoneIndex)
	local detector = pile:FindFirstChildOfClass("ClickDetector")
	local fullSize = pile.Size
	local hits = Config.PileHits
	local active = true
	local visual = pile:FindFirstChild("Visual") -- Toolbox model, if there is one
	local fullScale = visual and visual:GetScale()

	local function respawn()
		hits = Config.PileHits
		active = true
		pile.Size = fullSize
		if visual then
			visual:ScaleTo(fullScale)
			visual.Parent = pile
		else
			pile.Transparency = 0
		end
		pile.CanCollide = true
		detector.MaxActivationDistance = Config.TapRange
	end

	detector.MouseClick:Connect(function(player)
		local data = Data.get(player)
		if not data or not active then
			return
		end

		local root = rootOf(player)
		if not root or (root.Position - pile.Position).Magnitude > Config.TapRange + 6 then
			return
		end

		local now = os.clock()
		if now - (lastTap[player] or 0) < Config.TapCooldown then
			return
		end
		lastTap[player] = now

		if zoneIndex > data.zoneIndex then
			return
		end

		local capacity = Config.Backpacks[data.backpackIndex].capacity
		local space = capacity - data.scrap
		if space <= 0 then
			if now - (lastFullNotice[player] or 0) > 2 then
				lastFullNotice[player] = now
				notify(player, "Backpack full! Sell at the crusher.")
			end
			return
		end

		local amount = math.min(Config.Tools[data.toolIndex].power, space)
		data.scrap = data.scrap + amount
		data.pending = data.pending + amount * Config.Zones[zoneIndex].mult
		data.totalScrap = data.totalScrap + amount
		sync(player, data)

		hits = hits - 1
		if hits <= 0 then
			active = false
			pile.Transparency = 1
			pile.CanCollide = false
			if visual then
				visual.Parent = nil
			end
			detector.MaxActivationDistance = 0
			task.delay(Config.PileRespawn, respawn)
		else
			local shrink = 0.6 + 0.4 * hits / Config.PileHits
			pile.Size = fullSize * shrink
			if visual then
				visual:ScaleTo(fullScale * shrink)
			end
		end
	end)
end

-- Selling -------------------------------------------------------------------

local function setupCrusher(crusher)
	crusher.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local data = player and Data.get(player)
		if not data or data.scrap <= 0 then
			return
		end
		local bonus = Bots.totals(data)
		local earned = math.floor(data.pending * (1 + bonus) * (1 + Config.RebirthBonus * data.rebirths))
		data.coins = data.coins + earned
		data.scrap = 0
		data.pending = 0
		sync(player, data)
		notify(player, "Sold for " .. Config.format(earned) .. " coins")
	end)
end

-- Upgrades ------------------------------------------------------------------

local function buyNext(player, list, indexKey)
	local data = Data.get(player)
	if not data then
		return
	end
	local nextItem = list[data[indexKey] + 1]
	if not nextItem then
		notify(player, "You already own the best one.")
		return
	end
	if data.coins < nextItem.cost then
		notify(player, string.format("%s costs %s coins. You need %s more.", nextItem.name,
			Config.format(nextItem.cost), Config.format(nextItem.cost - data.coins)))
		return
	end
	data.coins = data.coins - nextItem.cost
	data[indexKey] = data[indexKey] + 1
	sync(player, data)
	notify(player, "Bought " .. nextItem.name .. "!")
end

-- Zones ---------------------------------------------------------------------

local function travelForward(player, targetIndex)
	local data = Data.get(player)
	if not data then
		return
	end
	local target = Config.Zones[targetIndex]
	if data.zoneIndex < targetIndex then
		if data.zoneIndex < targetIndex - 1 then
			return
		end
		if data.coins < target.cost then
			notify(player, string.format("%s costs %s coins. You need %s more.", target.name,
				Config.format(target.cost), Config.format(target.cost - data.coins)))
			return
		end
		data.coins = data.coins - target.cost
		data.zoneIndex = targetIndex
		sync(player, data)
		notify(player, "Unlocked " .. target.name .. "!")
	end
	teleport(player, targetIndex)
end

-- Rebirth -------------------------------------------------------------------

rebirthEvent.OnServerEvent:Connect(function(player)
	local data = Data.get(player)
	if not data then
		return
	end
	local cost = Config.rebirthCost(data.rebirths)
	if data.coins < cost then
		notify(player, string.format("Rebirth costs %s coins. You need %s more.", Config.format(cost),
			Config.format(cost - data.coins)))
		return
	end

	data.rebirths = data.rebirths + 1
	data.coins = 0
	data.scrap = 0
	data.pending = 0
	data.toolIndex = 1
	data.backpackIndex = 1
	data.zoneIndex = 1
	sync(player, data)
	syncBots(player, data)
	teleport(player, 1)
	notify(player, string.format("Rebirth %d! You now earn +%d%% coins.", data.rebirths,
		math.floor(Config.RebirthBonus * data.rebirths * 100 + 0.5)))
end)

-- Robots --------------------------------------------------------------------

local function openCrate(player, zoneIndex)
	local data = Data.get(player)
	if not data or zoneIndex > data.zoneIndex then
		return
	end
	local message = Bots.openCrate(data, zoneIndex)
	sync(player, data)
	syncBots(player, data)
	if message then
		notify(player, message)
	end
end

botEvent.OnServerEvent:Connect(function(player, action, id, index)
	local data = Data.get(player)
	if not data then
		return
	end

	local now = os.clock()
	if now - (lastBotAction[player] or 0) < Config.BotActionCooldown then
		return
	end
	lastBotAction[player] = now

	local message
	if action == "equip" or action == "unequip" then
		message = Bots.setEquipped(data, id, index, action == "equip")
	elseif action == "merge" then
		message = Bots.merge(data, id)
	elseif action == "scrap" then
		message = Bots.scrap(data, id, index)
	else
		return
	end
	sync(player, data)
	syncBots(player, data)
	if message then
		notify(player, message)
	end
end)

local function zoneAt(position)
	local index = math.floor(position.X / (Config.ZoneSize + Config.ZoneGap) + 0.5) + 1
	return math.clamp(index, 1, #Config.Zones)
end

-- Equipped robots collect for their owner, valued at the zone the owner is standing in.
task.spawn(function()
	while true do
		task.wait(Config.BotTick)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = Data.get(player)
			local root = rootOf(player)
			if data and root then
				local _, collect = Bots.totals(data)
				local space = Config.Backpacks[data.backpackIndex].capacity - data.scrap
				if collect > 0 and space > 0 then
					local zoneIndex = math.min(zoneAt(root.Position), data.zoneIndex)
					local amount = math.min(math.ceil(Config.Tools[data.toolIndex].power * collect), space)
					data.scrap = data.scrap + amount
					data.pending = data.pending + amount * Config.Zones[zoneIndex].mult
					data.totalScrap = data.totalScrap + amount
					sync(player, data)
				end
			end
		end
	end
end)

for index, zone in ipairs(zones) do
	for _, pile in ipairs(zone.piles) do
		setupPile(pile, index)
	end
	setupCrusher(zone.crusher)

	zone.toolPrompt.Triggered:Connect(function(player)
		buyNext(player, Config.Tools, "toolIndex")
	end)
	zone.bagPrompt.Triggered:Connect(function(player)
		buyNext(player, Config.Backpacks, "backpackIndex")
	end)
	if zone.cratePrompt then
		zone.cratePrompt.Triggered:Connect(function(player)
			openCrate(player, index)
		end)
	end
	if zone.nextPrompt then
		zone.nextPrompt.Triggered:Connect(function(player)
			travelForward(player, index + 1)
		end)
	end
	if zone.prevPrompt then
		zone.prevPrompt.Triggered:Connect(function(player)
			if Data.get(player) then
				teleport(player, index - 1)
			end
		end)
	end
end

-- Developer panel -----------------------------------------------------------

devEvent.OnServerEvent:Connect(function(player, action, value)
	if not DEVELOPERS[player.UserId] then
		return
	end
	local data = Data.get(player)
	if not data then
		return
	end

	local message
	if action == "coins" then
		if type(value) ~= "number" or value ~= value or value <= 0 then
			return
		end
		local amount = math.floor(math.min(value, DEV_MAX_COINS))
		data.coins = data.coins + amount
		message = "Dev: added " .. Config.format(amount) .. " coins"
	elseif action == "robot" then
		if type(value) ~= "number" or not Config.Crates[value] then
			return
		end
		message = Bots.openCrate(data, value, true)
	elseif action == "gear" then
		data.toolIndex = #Config.Tools
		data.backpackIndex = #Config.Backpacks
		message = "Dev: best tool and backpack"
	elseif action == "zones" then
		data.zoneIndex = #Config.Zones
		message = "Dev: all zones unlocked"
	elseif action == "rebirth" then
		data.rebirths = data.rebirths + 1
		message = "Dev: rebirths set to " .. data.rebirths
	elseif action == "reset" then
		data = Data.reset(player)
		teleport(player, 1)
		message = "Dev: save wiped"
	else
		return
	end

	sync(player, data)
	syncBots(player, data)
	if message then
		notify(player, message)
	end
end)

-- Players -------------------------------------------------------------------

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player

	if DEVELOPERS[player.UserId] then
		player:SetAttribute("Developer", true)
	end

	local data = Data.load(player)
	if data then
		sync(player, data)
		syncBots(player, data)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Data.release(player)
	lastTap[player] = nil
	lastFullNotice[player] = nil
	lastBotAction[player] = nil
end)
