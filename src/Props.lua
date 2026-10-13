-- Toolbox models used in place of the grey boxes. They are looks only: if a model is missing,
-- callers keep their plain part. Models live in ReplicatedStorage.Assets (built from Assets.rbxmx).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Props = {}

-- Free models can carry scripts, physics and character rigs. None of it is wanted here.
local STRIP = { "LuaSourceContainer", "Humanoid", "BodyMover", "Constraint", "JointInstance", "Sound" }

local prepared = {} -- [cache key] = cleaned template

local function assetFolder()
	if RunService:IsServer() then
		return ReplicatedStorage:FindFirstChild("Assets")
	end
	-- On a client, wait until the models have fully arrived before copying them.
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	return ReplicatedStorage:FindFirstChild("Assets")
end

local function partsOf(model)
	local parts = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end

local function volume(part)
	return part.Size.X * part.Size.Y * part.Size.Z
end

-- World-space box around every visible part of the model. Invisible parts are skipped, because
-- free models often carry large hidden boxes that would throw the fit off.
local function bounds(model)
	local low, high
	for _, part in ipairs(partsOf(model)) do
		if part.Transparency >= 1 then
			continue
		end
		local cframe = part.CFrame
		local half = part.Size / 2
		local x, y, z = cframe.RightVector * half.X, cframe.UpVector * half.Y, cframe.LookVector * half.Z
		local reach = Vector3.new(
			math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
			math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
			math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z))
		local a, b = cframe.Position - reach, cframe.Position + reach
		low = low and low:Min(a) or a
		high = high and high:Max(b) or b
	end
	return low, high
end

local function prepare(name, collide, maxParts)
	local folder = assetFolder()
	local template = folder and folder:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
	for _, item in ipairs(model:GetDescendants()) do
		for _, class in ipairs(STRIP) do
			if item:IsA(class) then
				item:Destroy()
				break
			end
		end
	end

	-- Stand the model upright, then drop its PrimaryPart so the pivot can be set freely.
	model:PivotTo(CFrame.new(model:GetPivot().Position))
	model.PrimaryPart = nil

	local parts = partsOf(model)
	if maxParts and #parts > maxParts then
		-- Keep only the biggest parts, so many copies stay cheap on phones.
		table.sort(parts, function(a, b)
			return volume(a) > volume(b)
		end)
		for index = maxParts + 1, #parts do
			parts[index]:Destroy()
			parts[index] = nil
		end
	end
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = collide
		part.CanQuery = collide
		part.CanTouch = false
	end
	if #parts == 0 then
		return nil
	end
	return model
end

-- Returns a cleaned copy of the named model, or nil if there is none.
function Props.make(name, collide, maxParts)
	local key = string.format("%s/%s/%s", name, tostring(collide), tostring(maxParts))
	if prepared[key] == nil then
		prepared[key] = prepare(name, collide, maxParts) or false
	end
	local template = prepared[key]
	return template and template:Clone() or nil
end

-- Scales the model to fit inside a box of the given size centred on center, standing on the
-- box's floor. turn lets it rotate a quarter turn if that fits better. The pivot ends up at
-- the bottom centre, so later scaling and turning happen in place.
function Props.fit(model, size, center, turn)
	local low, high = bounds(model)
	if not low then
		return
	end
	local dims = high - low
	local straight = math.min(size.X / dims.X, size.Y / dims.Y, size.Z / dims.Z)
	local turned = turn and math.min(size.X / dims.Z, size.Y / dims.Y, size.Z / dims.X) or 0
	if turned > straight then
		model:PivotTo(CFrame.Angles(0, math.pi / 2, 0) * model:GetPivot())
	end
	model:ScaleTo(model:GetScale() * math.max(straight, turned))

	low, high = bounds(model)
	local bottom = Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	local target = center - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (target - bottom))
	model.WorldPivot = CFrame.new(target)
end

-- Turns the model on the spot by a number of degrees.
function Props.turn(model, degrees)
	if degrees == 0 then
		return
	end
	local pivot = model:GetPivot()
	model:PivotTo(pivot * CFrame.Angles(0, math.rad(degrees), 0))
	model.WorldPivot = CFrame.new(pivot.Position)
end

-- Every BasePart in the model.
Props.parts = partsOf

return Props
