
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VisualizerModule = require(ReplicatedStorage:WaitForChild('Visualizers'))
local CanvasImageModule = require(ReplicatedStorage:WaitForChild('CanvasImage'))

local GLOBAL_COUNTER = 0

export type RaytraceConfig = {
	MaxDepth : number,
	RayLength : number,
	NRaySplits : number,
	AmbientColor : Color3,
	RaycastParams : RaycastParams?,
	MaxRaysPerUpdate : number,
}

export type RayData = {
	UUID : string,
	Parent : string,
	Origin : Vector3,
	Direction : Vector3,
	WeightedColor : Color3,
	Depth : number,
}

export type RayFrontier = {
	Position2D : Vector2,
	IsCompleted : boolean,
	RootRay : RayData,
	OngoingRays : { RayData },
	RayMap : { [string] : RayData },
	RayHeirarchyForward : { [string] : {string} }, -- { sourceUUID : {childrenUUID} }
	RayHeirarchyBackward : { [string] : string }, -- { childUUID : sourceUUID }
}

local DEFAULT_RAYCAST_PARAMS = RaycastParams.new()
DEFAULT_RAYCAST_PARAMS.IgnoreWater = false
DEFAULT_RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
DEFAULT_RAYCAST_PARAMS.FilterDescendantsInstances = { workspace.CurrentCamera }

local function SetProperties( Parent, Properties )
	if typeof(Properties) == 'table' then
		for propName, propValue in pairs(Properties) do
			Parent[propName] = propValue
		end
	end
	return Parent
end

local templatePart = Instance.new('Part')
templatePart.Anchored = true
templatePart.Transparency = 0.5
templatePart.Color = Color3.fromRGB(120, 210, 35)
templatePart.CanCollide = false
templatePart.CanTouch = false
templatePart.CanQuery = false
templatePart.CastShadow = false

local function VisualizeRay( origin : Vector3, direction : Vector3 )
	local result = workspace:Raycast( origin, direction * 50, DEFAULT_RAYCAST_PARAMS )
	local endPosition = result and result.Position or origin + (direction * 50)
	local distance = (endPosition - origin).Magnitude

	local obj = templatePart:Clone()
	obj.Size = Vector3.new(0.05, 0.05, distance)
	obj.CFrame = CFrame.lookAt( origin, endPosition ) * CFrame.new(0, 0, -distance / 2)
	obj.Parent = workspace.CurrentCamera
end

local ZAXIS = Vector3.zAxis
local function GetConedDirection(axis: Vector3, height_angle: number, circle_radian : number) : CFrame
	local cosAngle = math.cos(height_angle)
	local z = 1 - (1 - cosAngle)
	local r = math.sqrt(1 - z*z)
	local x = r * math.cos(circle_radian)
	local y = r * math.sin(circle_radian)
	local vec = Vector3.new(x, y, z)
	if axis.Z > 0.9999 then
		return vec.Unit
	elseif axis.Z < -0.9999 then
		return -vec.Unit
	end
	local orth = ZAXIS:Cross(axis)
	local rot = math.acos(axis:Dot(Vector3.zAxis))
	return (CFrame.fromAxisAngle(orth, rot) * vec).Unit
end

local function CreateRayData( frontier : RayFrontier, origin : Vector3, direction : Vector3, color : Color3, parent : RayData? ) : RayData
	-- VisualizeRay( origin, direction )

	local newRayData = {
		UUID = tostring(GLOBAL_COUNTER),
		Parent = parent and parent.UUID or false,
		Origin = origin,
		Direction = direction,
		WeightedColor = color,
		Depth = parent and (parent.Depth + 1) or 0,
	}

	GLOBAL_COUNTER += 1

	frontier.RayMap[ newRayData.UUID ] = newRayData
	if newRayData.Parent then
		frontier.RayHeirarchyBackward[ newRayData.UUID ] = newRayData.Parent
		if not frontier.RayHeirarchyForward[ newRayData.Parent ] then
			frontier.RayHeirarchyForward[ newRayData.Parent ] = {}
		end
		table.insert( frontier.RayHeirarchyForward[ newRayData.Parent ], newRayData.UUID )
	end

	table.insert( frontier.OngoingRays, newRayData )
	return newRayData
end

local -- Richardean Colour Scheme
function ApplyRCS( Color : Color3 ) : Color3
	local Red = Color.R
	local Blue = Color.B
	local Green = Color.G
	if Red > Blue and Red > Green then
		Red = Red * 1.2
		Blue = Blue * 0.9
		Green = Green * 0.9
	elseif Blue > Red and Blue > Green then
		Red = Red * 0.9
		Blue = Blue * 1.2
		Green = Green * 0.9
	elseif Green > Red and Green > Blue then
		Red = Red * 0.9
		Blue = Blue * 0.9
		Green = Green * 1.2
	elseif math.abs(Red-Green) <= 1 and not (math.abs(Red-Blue) <= 1) then
		Red = Red * 1.1
		Blue = Blue * 0.8
		Green = Green * 1.1
	elseif math.abs(Red-Blue) <= 1 and not (math.abs(Red-Green) <= 1) then
		Red = Red * 1.1
		Blue = Blue * 1.1
		Green = Green * 0.8
	elseif math.abs(Green-Blue) <= 1 and not (math.abs(Red-Green) <= 1) then
		Red = Red * 0.8
		Blue = Blue * 1.1
		Green = Green * 1.1
	else
		Red = Red * 1.1
		Blue = Blue * 1.1
		Green = Green * 1.1
	end
	return Color3.new( math.min( Red, 1 ), math.min( Green, 1 ), math.min( Blue, 1 ) )
end

-- // Module // --
local Module = {}

function Module.CreateConfig( properties : { [string] : any } ) : RaytraceConfig
	return SetProperties( {
		MaxDepth = 2, -- what is the max depth of a ray
		RayLength = 100, -- distance for raycasting
		NRaySplits = 4, -- how many rays are generated on a new reflection
		AmbientColor = Color3.new(),
		RaycastParams = nil,
		MaxRaysPerUpdate = 100,
	}, properties )
end

function Module.ResolveColorFromFrontier( frontier : RayFrontier ) : Color3
	local rootRay = frontier.RootRay
	local childUUIDs = frontier.RayHeirarchyForward[rootRay.UUID]
	if (not childUUIDs) or #childUUIDs == 0 then
		return frontier.RootRay.WeightedColor
	end

	local sourceColor : Color3 = frontier.RootRay.WeightedColor
	for _, childID in ipairs( childUUIDs ) do
		local rayData = frontier.RayMap[childID]
		if not rayData then
			continue
		end
		sourceColor = sourceColor:Lerp( rayData.WeightedColor, 0.8 )
	end

	return ApplyRCS( sourceColor )
end

function Module.ResolveRay( frontier : RayFrontier, rayData : RayData, config : RaytraceConfig )
	local rayResult : RaycastResult = workspace:Raycast( rayData.Origin, rayData.Direction * config.RayLength, config.RaycastParams or DEFAULT_RAYCAST_PARAMS )
	if not rayResult then
		-- get ambient color
		rayData.WeightedColor = config.AmbientColor
		return
	end

	local objectColor : Color3 = nil
	if rayResult.Instance == workspace.Terrain then
		objectColor = workspace.Terrain:GetMaterialColor(rayResult.Material)
	else
		objectColor = rayResult.Instance.Color
	end
	objectColor = rayData.WeightedColor:Lerp(objectColor, 0.9) -- lerp towards the object's color

	-- append new rays
	if (rayData.Depth + 1) <= config.MaxDepth then
		-- circular reflection
		local radianStep : number = (math.pi * 2) / config.NRaySplits
		for index = 1, config.NRaySplits do
			local sphericalDirection : Vector3 = GetConedDirection(rayResult.Normal, 45, (index-1) * radianStep)
			CreateRayData( frontier, rayResult.Position, sphericalDirection, objectColor, rayData )
		end
		-- 90 degree reflection
		CreateRayData( frontier, rayResult.Position, rayResult.Normal, objectColor, rayData )
	end
end

function Module.UpdateFrontier( frontier : RayFrontier, config : RaytraceConfig )
	for _ = 1, math.min(#frontier.OngoingRays, config.MaxRaysPerUpdate) do
		local item = table.remove(frontier.OngoingRays, 1)
		-- VisualizeRay( item.Origin, item.Direction )
		Module.ResolveRay( frontier, item, config )
	end
	frontier.IsCompleted = (#frontier.OngoingRays == 0)
end

function Module.CreateFrontier( position2D : Vector2, origin : Vector3, direction : Vector3, config : RaytraceConfig ) : RayFrontier
	local frontier = {
		Position2D = position2D,
		OngoingRays = {},
		RayMap = {},
		RayHeirarchyForward = {},
		RayHeirarchyBackward = {},
		RootRay = nil,
	}
	local rootRay : RayData = CreateRayData( frontier, origin, direction.Unit, config.AmbientColor, nil )
	frontier.RootRay = rootRay
	return frontier
end

function Module.Render( Camera : Camera, canvas : CanvasImageModule.Canvas, config : RaytraceConfig )

	DEFAULT_RAYCAST_PARAMS.FilterDescendantsInstances = { workspace.CurrentCamera }

	local skipToXth = 50
	local skipToYth = 40

	local frontiers : { RayFrontier } = { }

	local offsetStepX = (Camera.ViewportSize.X / canvas.EditableImage.Size.X)
	local offsetStepY = (Camera.ViewportSize.Y / canvas.EditableImage.Size.Y)
	for x = 0, (canvas.EditableImage.Size.X - 1), skipToXth do
		for y = 0, (canvas.EditableImage.Size.Y - 1), skipToYth do
			local ray = Camera:ViewportPointToRay(x * offsetStepX, y * offsetStepY)
			local frontier = Module.CreateFrontier(Vector2.new(x, y), ray.Origin, ray.Direction.Unit, config)
			table.insert(frontiers, frontier)
			-- visualize
			-- VisualizeRay( ray.Origin, ray.Direction )
		end
	end

	-- TODO: update frontiers (move and resolve in actor pools)
	local AreFrontiersUpdating = true
	while AreFrontiersUpdating do
		AreFrontiersUpdating = false
		for _, frontier in ipairs( frontiers ) do
			Module.UpdateFrontier(frontier, config)
			if not frontier.IsCompleted then
				AreFrontiersUpdating = true
			end
		end
		task.wait()
	end

	local scale : number = 0.08
	workspace.CurrentCamera:ClearAllChildren()
	for _, frontier in ipairs( frontiers ) do
		local pos = frontier.Position2D
		local p = templatePart:Clone()
		p.Color = Module.ResolveColorFromFrontier( frontier )
		p.Size = Vector3.new( skipToXth, skipToYth, 1 ) * scale
		p.Position = Vector3.new(pos.X * scale, pos.Y * scale, 0) + Vector3.new(0, 10, 0)
		p.Parent = workspace.CurrentCamera
	end

	-- resolve colors
	--[==[ local xD = math.floor(canvas.EditableImage.Size.X/skipToXth)
	local yD = math.floor(canvas.EditableImage.Size.Y/skipToYth)
	local pixels : {number} = {}
	local index = 0
	for x = 0, canvas.EditableImage.Size.X-1 do
		for y = 0, canvas.EditableImage.Size.Y-1 do
			if (x % skipToXth) == 0 and (y % skipToYth) == 0 and x > 0 and y > 0 then
				index += 1
				print(x, y, index, #frontiers)

				local p = templatePart:Clone()
				p.Color = Module.ResolveColorFromFrontier( frontiers[ index ] )
				p.Size = Vector3.one
				p.Position = Vector3.new(
					math.floor(xD * (x / canvas.EditableImage.Size.X)),
					math.floor(yD * (y / canvas.EditableImage.Size.Y)),
					0
				) + Vector3.new(0, 10, 0)
				p.Parent = workspace.CurrentCamera
			end

			local frontier = frontiers[ index ]
			local frontierColor = Module.ResolveColorFromFrontier( frontier )
			table.insert(pixels, frontierColor.R)
			table.insert(pixels, frontierColor.G)
			table.insert(pixels, frontierColor.B)
			table.insert(pixels, 1)

			--[[
				table.insert(pixels, math.random(255)/255)
				table.insert(pixels, math.random(255)/255)
				table.insert(pixels, math.random(255)/255)
				table.insert(pixels, 1)
			]]
		end
	end

	canvas.EditableImage:WritePixels( Vector2.zero, canvas.EditableImage.Size, pixels ) ]==]


end

return Module
