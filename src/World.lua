-- Builds the grey-box map from Config so no manual building is needed yet.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Props = require(ReplicatedStorage:WaitForChild("Props"))

local World = {}

local WHITE = Color3.fromRGB(255, 255, 255)

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function addLabel(part, text, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(16, 4) -- in studs, so the sign keeps its size in the world at any distance
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 150
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	return label
end

local function addPrompt(part, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

-- Swaps a grey box for its Toolbox model. The box stays as the invisible holder of the sign and
-- prompt. Does nothing if the model is missing.
local function dress(part, name, size, turn)
	local model = Props.make(name, true)
	if not model then
		return
	end
	local floor = part.Position.Y - part.Size.Y / 2
	Props.fit(model, size, Vector3.new(part.Position.X, floor + size.Y / 2, part.Position.Z), turn)
	Props.turn(model, Config.PropYaw[name] or 0)
	model.Name = "Visual"
	model.Parent = part
	part.Transparency = 1
	part.CanCollide = false
end

function World.build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	local size = Config.ZoneSize
	local half = size / 2
	local zones = {}

	for index, zone in ipairs(Config.Zones) do
		local folder = Instance.new("Folder")
		folder.Name = zone.id
		folder.Parent = map

		local centerX = (index - 1) * (size + Config.ZoneGap)
		local frontZ = -half + 15 -- row of stations along the front edge

		newPart(folder, "Floor", Vector3.new(size, 4, size), CFrame.new(centerX, -2, 0), zone.floor, Enum.Material.Ground)

		local arrivalPos = Vector3.new(centerX, 3, -half + 38)
		local arrival = CFrame.lookAt(arrivalPos, arrivalPos + Vector3.new(0, 0, 1))

		if index == 1 then
			local spawn = Instance.new("SpawnLocation")
			spawn.Anchored = true
			spawn.Size = Vector3.new(10, 1, 10)
			spawn.CFrame = CFrame.new(centerX, 0.5, -half + 38)
			spawn.Color = Color3.fromRGB(240, 240, 240)
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.Parent = folder
		end

		local crusher = newPart(folder, "Crusher", Vector3.new(14, 1, 14), CFrame.new(centerX, 0.5, frontZ + 7),
			Color3.fromRGB(242, 183, 5), Enum.Material.Neon)
		addLabel(crusher, "CRUSHER\nWalk here to sell", 13)

		-- The crusher machine stands behind the pad, so the pad stays easy to walk onto.
		local machine = Props.make("Crusher", true)
		if machine then
			Props.fit(machine, Vector3.new(18, 12, 14), Vector3.new(centerX, 6, frontZ - 7.5), true)
			Props.turn(machine, Config.PropYaw.Crusher or 0)
			machine.Name = "CrusherMachine"
			machine.Parent = folder
		end

		local toolBench = newPart(folder, "ToolBench", Vector3.new(6, 5, 6), CFrame.new(centerX - 25, 2.5, frontZ),
			Color3.fromRGB(60, 120, 200), Enum.Material.Metal)
		addLabel(toolBench, "TOOL BENCH", 8.5)
		local toolPrompt = addPrompt(toolBench, "Buy next tool", "Tool Bench")
		dress(toolBench, "ToolBench", Vector3.new(10, 8, 8), true)

		local bagStand = newPart(folder, "BackpackStand", Vector3.new(6, 5, 6), CFrame.new(centerX + 25, 2.5, frontZ),
			Color3.fromRGB(90, 170, 90), Enum.Material.Metal)
		addLabel(bagStand, "BACKPACKS", 8.5)
		local bagPrompt = addPrompt(bagStand, "Buy next backpack", "Backpack Stand")
		dress(bagStand, "BackpackStand", Vector3.new(7, 8, 7), false)

		local cratePrompt
		local crate = Config.Crates[index]
		if crate then
			local crateBox = newPart(folder, "BotCrate", Vector3.new(6, 6, 6), CFrame.new(centerX + 42, 3, frontZ),
				Color3.fromRGB(230, 120, 50), Enum.Material.DiamondPlate)
			local odds = {}
			for _, rarity in ipairs(Config.Rarities) do
				table.insert(odds, string.format("%s %s%%", rarity.name, tostring(rarity.chance)))
			end
			local label = addLabel(crateBox, string.format("BOT CRATE\n%s coins\n%s", Config.format(crate.cost),
				table.concat(odds, "  ")), 9)
			label.Parent.Size = UDim2.fromScale(24, 6)
			cratePrompt = addPrompt(crateBox, "Open crate", "Bot Crate")
			dress(crateBox, "BotCrate", Vector3.new(8, 7, 8), false)
		end

		local nextPrompt, prevPrompt
		local nextZone = Config.Zones[index + 1]
		if nextZone then
			local portal = newPart(folder, "NextPortal", Vector3.new(10, 12, 2), CFrame.new(centerX + 60, 6, frontZ),
				Color3.fromRGB(170, 90, 230), Enum.Material.Neon)
			addLabel(portal, string.format("%s\n%s coins to unlock", nextZone.name, Config.format(nextZone.cost)), 8)
			nextPrompt = addPrompt(portal, "Travel", nextZone.name)
			dress(portal, "Portal", Vector3.new(10, 12, 4), true)
		end
		local prevZone = Config.Zones[index - 1]
		if prevZone then
			local portal = newPart(folder, "PrevPortal", Vector3.new(10, 12, 2), CFrame.new(centerX - 60, 6, frontZ),
				Color3.fromRGB(120, 120, 135), Enum.Material.Neon)
			addLabel(portal, "Back to\n" .. prevZone.name, 8)
			prevPrompt = addPrompt(portal, "Travel", prevZone.name)
			dress(portal, "Portal", Vector3.new(10, 12, 4), true)
		end

		-- Scrap piles fill the area behind the stations.
		local piles = {}
		local rng = Random.new(index)
		for pileIndex = 1, Config.PilesPerZone do
			local x = centerX + rng:NextNumber(-half + 10, half - 10)
			local z = rng:NextNumber(-half + 55, half - 10)
			local pileSize = Vector3.new(rng:NextNumber(3.5, 5), rng:NextNumber(2.5, 4), rng:NextNumber(3.5, 5))
			local cframe = CFrame.new(x, pileSize.Y / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local pile = newPart(folder, "Scrap" .. pileIndex, pileSize, cframe, zone.scrap, Enum.Material.CorrodedMetal)

			local detector = Instance.new("ClickDetector")
			detector.MaxActivationDistance = Config.TapRange
			detector.Parent = pile

			-- The box stays as the tap target; the scrap model inside it is what players see.
			local visual = Props.make("ScrapPile", false, Config.PileParts)
			if visual then
				Props.fit(visual, pileSize, cframe.Position, false)
				Props.turn(visual, rng:NextNumber(0, 360))
				for _, part in ipairs(Props.parts(visual)) do
					part.Color = zone.scrap:Lerp(part.Color, 0.35)
				end
				visual.Name = "Visual"
				visual.Parent = pile
				pile.Transparency = 1
			end

			table.insert(piles, pile)
		end

		zones[index] = {
			arrival = arrival,
			crusher = crusher,
			toolPrompt = toolPrompt,
			bagPrompt = bagPrompt,
			cratePrompt = cratePrompt,
			nextPrompt = nextPrompt,
			prevPrompt = prevPrompt,
			piles = piles,
		}
	end

	return zones
end

return World
