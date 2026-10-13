-- Loads and saves player data. Nothing else touches the DataStore.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 120
local LOAD_ATTEMPTS = 3

local Data = {}
local profiles = {} -- [player] = { data = table, canSave = boolean }

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore unavailable, progress will not save: " .. tostring(result))
	end
end

local function defaults()
	return {
		version = 1,
		coins = 0,
		scrap = 0, -- units in the backpack
		pending = 0, -- coin value of the backpack
		toolIndex = 1,
		backpackIndex = 1,
		zoneIndex = 1, -- highest zone unlocked
		totalScrap = 0,
		rebirths = 0,
		bots = {}, -- list of { id = string, polished = boolean, equipped = boolean }
		index = {}, -- [botId] = true for every bot ever found
	}
end

local function keyFor(player)
	return "player_" .. player.UserId
end

function Data.load(player)
	local data
	local loaded = false

	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(string.format("[Data] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
			task.wait(2)
		end
	end

	if not loaded then
		if RunService:IsStudio() then
			warn("[Data] Using temporary data in Studio. Turn on API access in Game Settings to test saving.")
		else
			-- Never let a player play on blank data that could overwrite their real save.
			player:Kick("Your data could not be loaded. Please rejoin.")
			return nil
		end
	end

	if player.Parent ~= Players then
		return nil
	end

	if type(data) ~= "table" then
		data = defaults()
	else
		for key, value in pairs(defaults()) do
			if data[key] == nil then
				data[key] = value
			end
		end
	end

	profiles[player] = { data = data, canSave = loaded }
	return data
end

function Data.get(player)
	local profile = profiles[player]
	return profile and profile.data or nil
end

-- Wipes a player back to a new save. Developer testing only.
function Data.reset(player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	profile.data = defaults()
	return profile.data
end

function Data.save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), profile.data)
	end)
	if not ok then
		warn(string.format("[Data] Save failed for %s: %s", player.Name, tostring(err)))
	end
end

function Data.release(player)
	Data.save(player)
	profiles[player] = nil
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player in pairs(profiles) do
			task.spawn(Data.save, player)
		end
	end
end)

game:BindToClose(function()
	local remaining = 0
	for player in pairs(profiles) do
		remaining = remaining + 1
		task.spawn(function()
			Data.save(player)
			remaining = remaining - 1
		end)
	end
	while remaining > 0 do
		task.wait()
	end
end)

return Data
