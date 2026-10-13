-- Robot rules: crate rolls, equipping and merging. Works on a player's saved data table.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Bots = {}
local rng = Random.new()

local function roll(zoneIndex)
	local crate = Config.Crates[zoneIndex]
	local value = rng:NextNumber(0, 100)
	local total = 0
	for rarityIndex, rarity in ipairs(Config.Rarities) do
		total = total + rarity.chance
		if value < total then
			return crate.bots[rarityIndex].id
		end
	end
	return crate.bots[1].id
end

function Bots.equippedCount(data)
	local count = 0
	for _, bot in ipairs(data.bots) do
		if bot.equipped then
			count = count + 1
		end
	end
	return count
end

-- Returns the total coin bonus and collect share of the equipped bots.
function Bots.totals(data)
	local bonus = 0
	local collect = 0
	for _, bot in ipairs(data.bots) do
		if bot.equipped then
			local botBonus, botCollect = Config.botStats(bot.id, bot.polished)
			if botBonus then
				bonus = bonus + botBonus
				collect = collect + botCollect
			end
		end
	end
	return bonus, collect
end

-- Text form of the bot list, stored on the player so clients can read it.
function Bots.encode(data)
	return HttpService:JSONEncode(data.bots)
end

-- Each function below returns a message for the player, or nil.

-- free skips the cost, for developer testing.
function Bots.openCrate(data, zoneIndex, free)
	local crate = Config.Crates[zoneIndex]
	if not crate then
		return nil
	end
	if #data.bots >= Config.MaxBots then
		return string.format("You can hold %d robots. Merge some first.", Config.MaxBots)
	end
	if not free then
		if data.coins < crate.cost then
			return string.format("A crate costs %s coins. You need %s more.", Config.format(crate.cost),
				Config.format(crate.cost - data.coins))
		end
		data.coins = data.coins - crate.cost
	end

	local bot = Config.Bots[roll(zoneIndex)]
	table.insert(data.bots, {
		id = bot.id,
		polished = false,
		equipped = Bots.equippedCount(data) < Config.botSlots(data.rebirths),
	})
	data.index[bot.id] = true
	return string.format("You got a %s robot: %s!", Config.Rarities[bot.rarity].name, bot.name)
end

function Bots.setEquipped(data, id, index, equipped)
	local bot = type(index) == "number" and data.bots[index]
	if not bot or bot.id ~= id or bot.equipped == equipped then
		return nil
	end
	local slots = Config.botSlots(data.rebirths)
	if equipped and Bots.equippedCount(data) >= slots then
		return string.format("All %d robot slots are in use. Unequip one first.", slots)
	end
	bot.equipped = equipped
	return nil
end

function Bots.scrap(data, id, index)
	local bot = type(index) == "number" and data.bots[index]
	if not bot or bot.id ~= id then
		return nil
	end
	local refund = Config.botRefund(bot.id, bot.polished) or 0
	table.remove(data.bots, index)
	data.coins = data.coins + refund
	local info = Config.Bots[id]
	return string.format("Scrapped %s for %s coins", info and info.name or "robot", Config.format(refund))
end

function Bots.merge(data, id)
	local bot = type(id) == "string" and Config.Bots[id]
	if not bot then
		return nil
	end

	-- Use up unequipped copies first.
	local spare, worn = {}, {}
	for index, owned in ipairs(data.bots) do
		if owned.id == id and not owned.polished then
			table.insert(owned.equipped and worn or spare, index)
		end
	end
	local chosen = {}
	for _, index in ipairs(spare) do
		table.insert(chosen, index)
	end
	for _, index in ipairs(worn) do
		table.insert(chosen, index)
	end
	if #chosen < Config.MergeCount then
		return string.format("You need %d %s to merge.", Config.MergeCount, bot.name)
	end

	local remove = {}
	local wasEquipped = false
	for position = 1, Config.MergeCount do
		local index = chosen[position]
		wasEquipped = wasEquipped or data.bots[index].equipped
		table.insert(remove, index)
	end
	table.sort(remove, function(a, b)
		return a > b
	end)
	for _, index in ipairs(remove) do
		table.remove(data.bots, index)
	end

	table.insert(data.bots, { id = id, polished = true, equipped = wasEquipped })
	return "Merged into a Polished " .. bot.name .. "!"
end

return Bots
