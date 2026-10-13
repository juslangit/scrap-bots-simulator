-- Shared game values. Balance the game here, not in the scripts.
local Config = {}

Config.Zones = {
	{ id = "BackyardHeap", name = "Backyard Heap", cost = 0, mult = 1, floor = Color3.fromRGB(118, 150, 92), scrap = Color3.fromRGB(150, 110, 80) },
	{ id = "AutoGraveyard", name = "Auto Graveyard", cost = 1500, mult = 4, floor = Color3.fromRGB(150, 135, 105), scrap = Color3.fromRGB(170, 70, 60) },
	{ id = "FactoryRuins", name = "Factory Ruins", cost = 75000, mult = 15, floor = Color3.fromRGB(110, 115, 125), scrap = Color3.fromRGB(90, 140, 170) },
	{ id = "ShipbreakerDocks", name = "Shipbreaker Docks", cost = 1000000, mult = 60, floor = Color3.fromRGB(80, 120, 130), scrap = Color3.fromRGB(230, 180, 60) },
}

Config.Tools = {
	{ id = "MagnetGlove", name = "Magnet Glove", cost = 0, power = 1 },
	{ id = "Crowbar", name = "Crowbar", cost = 50, power = 3 },
	{ id = "GrabberArm", name = "Grabber Arm", cost = 5000, power = 10 },
	{ id = "PlasmaCutter", name = "Plasma Cutter", cost = 100000, power = 40 },
	{ id = "GravityClaw", name = "Gravity Claw", cost = 2000000, power = 150 },
}

Config.Backpacks = {
	{ id = "LunchSack", name = "Lunch Sack", cost = 0, capacity = 25 },
	{ id = "ToolCrate", name = "Tool Crate", cost = 300, capacity = 100 },
	{ id = "OilDrum", name = "Oil Drum", cost = 8000, capacity = 500 },
	{ id = "CargoPod", name = "Cargo Pod", cost = 150000, capacity = 2500 },
	{ id = "ShippingContainer", name = "Shipping Container", cost = 3000000, capacity = 15000 },
}

-- Robots. chance is the crate odds in percent, bonus is extra coins when selling,
-- collect is scrap per tick as a share of the player's tool power,
-- refund is the share of the crate cost paid back for scrapping the bot.
-- Keep the average refund below 1, or opening and scrapping crates makes free coins.
Config.Rarities = {
	{ name = "Common", chance = 60, bonus = 0.10, collect = 0.5, refund = 0.25, color = Color3.fromRGB(190, 195, 200) },
	{ name = "Uncommon", chance = 28, bonus = 0.25, collect = 1, refund = 0.5, color = Color3.fromRGB(95, 200, 110) },
	{ name = "Rare", chance = 10, bonus = 0.60, collect = 2, refund = 1.5, color = Color3.fromRGB(80, 150, 240) },
	{ name = "Epic", chance = 1.9, bonus = 1.50, collect = 4, refund = 5, color = Color3.fromRGB(175, 100, 240) },
	{ name = "Legendary", chance = 0.1, bonus = 5.00, collect = 10, refund = 50, color = Color3.fromRGB(242, 183, 5) },
}

-- One crate per zone, bots listed from Common to Legendary. scale multiplies the coin bonus.
Config.Crates = {
	{ cost = 150, scale = 1, bots = {
		{ id = "RustyRoller", name = "Rusty Roller" },
		{ id = "ToasterTank", name = "Toaster Tank" },
		{ id = "ForkliftFred", name = "Forklift Fred" },
		{ id = "ChromeHound", name = "Chrome Hound" },
		{ id = "TitanCrusher", name = "Titan Crusher" },
	} },
	{ cost = 3000, scale = 2, bots = {
		{ id = "HubcapHopper", name = "Hubcap Hopper" },
		{ id = "PistonPup", name = "Piston Pup" },
		{ id = "TowTruckTim", name = "Tow Truck Tim" },
		{ id = "TurboStallion", name = "Turbo Stallion" },
		{ id = "MonsterHauler", name = "Monster Hauler" },
	} },
	{ cost = 50000, scale = 4, bots = {
		{ id = "BoltBeetle", name = "Bolt Beetle" },
		{ id = "ConveyorCrab", name = "Conveyor Crab" },
		{ id = "WelderWasp", name = "Welder Wasp" },
		{ id = "PressGolem", name = "Press Golem" },
		{ id = "FoundryKing", name = "Foundry King" },
	} },
	{ cost = 750000, scale = 8, bots = {
		{ id = "BarnacleBot", name = "Barnacle Bot" },
		{ id = "RivetGull", name = "Rivet Gull" },
		{ id = "AnchorApe", name = "Anchor Ape" },
		{ id = "CraneKraken", name = "Crane Kraken" },
		{ id = "Dreadnought", name = "Dreadnought" },
	} },
}

Config.BotSlots = 3 -- equipped at once, before rebirth slots
Config.MaxBots = 50 -- owned at once
Config.MergeCount = 3 -- same bots needed for a Polished one
Config.BotTick = 2 -- seconds between auto-collects
Config.BotActionCooldown = 0.15 -- seconds between inventory requests per player

-- Lookup by id, built from the crates above.
Config.Bots = {}
for zoneIndex, crate in ipairs(Config.Crates) do
	for rarityIndex, bot in ipairs(crate.bots) do
		Config.Bots[bot.id] = { id = bot.id, name = bot.name, zone = zoneIndex, rarity = rarityIndex }
	end
end

-- Returns the coin bonus and collect share of one bot, or nil for an unknown id.
function Config.botStats(id, polished)
	local bot = Config.Bots[id]
	if not bot then
		return nil
	end
	local rarity = Config.Rarities[bot.rarity]
	local polish = polished and 2 or 1
	return rarity.bonus * Config.Crates[bot.zone].scale * polish, rarity.collect * polish
end

-- Coins paid for scrapping one bot, or nil for an unknown id. A Polished bot pays for the bots merged into it.
function Config.botRefund(id, polished)
	local bot = Config.Bots[id]
	if not bot then
		return nil
	end
	local refund = Config.Crates[bot.zone].cost * Config.Rarities[bot.rarity].refund
	return math.floor(refund * (polished and Config.MergeCount or 1))
end

-- Rebirth: resets coins, tools, backpacks and zones for a permanent coin bonus. Robots are kept.
Config.RebirthCost = 2500000 -- first rebirth
Config.RebirthCostGrowth = 2.5 -- each later rebirth costs this many times more
Config.RebirthBonus = 0.5 -- extra coins per rebirth
Config.RebirthSlots = { 1, 5, 15 } -- rebirths that add a robot slot

function Config.rebirthCost(rebirths)
	return math.floor(Config.RebirthCost * Config.RebirthCostGrowth ^ rebirths)
end

-- Robots a player can equip at once.
function Config.botSlots(rebirths)
	local slots = Config.BotSlots
	for _, needed in ipairs(Config.RebirthSlots) do
		if rebirths >= needed then
			slots = slots + 1
		end
	end
	return slots
end

-- Scrap piles
Config.PilesPerZone = 30
Config.PileHits = 5 -- taps before a pile is used up
Config.PileRespawn = 4 -- seconds
Config.TapCooldown = 0.12 -- seconds between taps per player
Config.TapRange = 18 -- studs

-- Toolbox models (see Props). PileParts caps the parts kept per scrap pile, to stay light on phones.
-- PropYaw turns a model, in degrees, when it comes out facing the wrong way.
Config.PileParts = 24
Config.PropYaw = {
	ToolBench = 180,
}

-- Map layout
Config.ZoneSize = 160
Config.ZoneGap = 60

local SUFFIXES = { "", "K", "M", "B", "T" }

function Config.format(n)
	n = math.floor(n)
	local value = n
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value = value / 1000
		index = index + 1
	end
	if index == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", value, SUFFIXES[index])
end

return Config
