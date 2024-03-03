
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VisualizerModule = require(ReplicatedStorage:WaitForChild('Visualizers'))
local CanvasImageModule = require(ReplicatedStorage:WaitForChild('CanvasImage'))

local GLOBAL_COUNTER = 0

export type RaytraceConfig = {
	MaxDepth : number,
	RayLength : number,
	NRaySplits : number,
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
	IsCompleted : boolean,
	OngoingRays : { RayData },
	RayMap : { [string] : RayData },
	RayHeirarchyForward : { [string] : {string} }, -- { sourceUUID : {childrenUUID} }
	RayHeirarchyBackward : { [string] : string }, -- { childUUID : sourceUUID }
}

local function SetProperties( Parent, Properties )
	if typeof(Properties) == 'table' then
		for propName, propValue in pairs(Properties) do
			Parent[propName] = propValue
		end
	end
	return Parent
end

-- // Module // --
local Module = {}

Module.RAYCAST_PARAMS = RaycastParams.new()
Module.RAYCAST_PARAMS.IgnoreWater = false

function Module.CreateConfig( properties : { [string] : any } ) : RaytraceConfig
	return SetProperties( {
		MaxDepth = 3, -- what is the max depth of a ray
		RayLength = 100, -- distance for raycasting
		NRaySplits = 5, -- how many rays are generated on a new reflection
	}, properties )
end

function Module.ResolveColorFromFrontier( frontier : RayFrontier ) : Color3
	-- return Color3.fromRGB( math.random(255), math.random(255), math.random(255) )
	error('NotImplemented')
end

function Module.ResolveRay( frontier : RayFrontier, rayData : RayData, config : RaytraceConfig )
	error('NotImplemented')

	local rayResult : RaycastResult = workspace:Raycast( rayData.Origin, rayData.Direction * config.RayLength, Module.RAYCAST_PARAMS )
	if not rayResult then
		-- get ambient color
		rayData.WeightedColor = config.AmbientColor
		return
	end

	if rayData.Depth + 1 <= config.MaxDepth then
		-- append new rays

		for _ = 1, config.NRaySplits do
			local reflectedRayDirection = GetReflectedRay( rayData.Direction, rayResult.Normal )
			local randomizeDirection = RandomizeDirection( reflectedRayDirection, 40 ) -- n degree randomize

			local objectColor = nil
			if rayResult.Instance == workspace.Terrain then
				objectColor = workspace.Terrain:GetMaterialColor(rayResult.Material)
			else
				objectColor = rayResult.Instance.Color
			end

			local newRayData = {
				UUID = tostring(GLOBAL_COUNTER),
				Parent = rayData.UUID,
				Origin = rayResult.Position,
				Direction = randomizeDirection,
				WeightedColor = objectColor,
				Depth = rayData.Depth + 1,
			}

			GLOBAL_COUNTER += 1
			frontier.RayMap[ newRayData.UUID ] = newRayData
			frontier.RayHeirarchyBackward[ newRayData.UUID ] = newRayData.Parent
			if not frontier.RayHeirarchyForward[ newRayData.Parent ] then
				frontier.RayHeirarchyForward[ newRayData.Parent ] = {}
			end
			table.insert( frontier.RayHeirarchyForward[ newRayData.Parent ], newRayData.UUID )
			table.insert( frontier.OngoingRays, newRayData )
		end

	end

end

function Module.UpdateFrontier( frontier : RayFrontier, config : RaytraceConfig )
	--[[
		for _ = 1, #frontier.OngoingRays do
			Module.ResolveRay( frontier, table.remove( frontier.OngoingRays, 1 ), config )
		end
	]]
	frontier.IsCompleted = true
end

function Module.CreateFrontier( position2D : Vector2, origin : Vector3, direction : Vector3, config : RaytraceConfig ) : RayFrontier
	local frontier = {
		Position2D = position2D,
		OngoingRays = {},
		RayMap = {},
		RayHeirarchyForward = {},
		RayHeirarchyBackward = {},
	}

	local rootRay = {
		UUID = tostring(GLOBAL_COUNTER),
		Parent = false,
		Origin = origin,
		Direction = direction.Unit,
		WeightedColor = Color3.fromRGB(100, 100, 100),
		Depth = 0,
	}

	GLOBAL_COUNTER += 1
	frontier.RayMap[ rootRay.UUID ] = rootRay

	Module.ResolveRay( frontier, rootRay, config )
	return frontier
end

function Module.Render( Camera : Camera, canvas : CanvasImageModule.Canvas, config : RaytraceConfig )

	local skipToXth = 50
	local skipToYth = 40

	local frontiers : { RayFrontier } = { }

	local offsetStepX = (Camera.ViewportSize.X / canvas.EditableImage.Size.X)
	local offsetStepY = (Camera.ViewportSize.Y / canvas.EditableImage.Size.Y)
	for x = 0, (canvas.EditableImage.Size.X - 1), skipToXth do
		for y = 0, (canvas.EditableImage.Size.Y - 1), skipToYth do
			local ray = Camera:ViewportPointToRay(x * offsetStepX, y * offsetStepY)
			local frontier = Module.CreateFrontier(Vector2.new(x, y), ray.Origin, ray.Direction, config)
			table.insert(frontiers, frontier)
			-- visualize
			-- local finish = ray.Origin + (ray.Direction * 5)
			-- VisualizerModule.Beam( ray.Origin, finish, 20, { Color = ColorSequence.new( Color3.new(0, 0.7, 0) ) } )
		end
	end

	-- TODO: update frontiers (actor pool)

	local steps = 0
	while true do
		steps += 1
		local IsStillUpdating = false
		for _, item in ipairs( frontiers ) do
			if item.IsCompleted then
				continue
			end
			IsStillUpdating = true
			Module.UpdateFrontier( item, config )
		end
		if not IsStillUpdating then
			print('Broke loop after', steps, 'steps.')
			break
		end
		task.wait()
	end

	-- resolve colors

	print( canvas.EditableImage.Size.X * canvas.EditableImage.Size.Y, 'to random colors.' )

	-- local temporaryImage = Instance.new('EditableImage')
	-- temporaryImage:Resize( canvas.EditableImage.Size )

	local pixels : {number} = {}
	for x = 1, canvas.EditableImage.Size.X do
		for y = 1, canvas.EditableImage.Size.Y do

			local xIndex = math.round(x / skipToXth) + 1
			local yIndex = math.round(y / skipToYth) + 1
			local frontier = frontiers[ xIndex * yIndex ]
			local frontierColor = Module.ResolveColorFromFrontier( frontier )
			table.insert(pixels, frontierColor.R)
			table.insert(pixels, frontierColor.G)
			table.insert(pixels, frontierColor.B)
			table.insert(pixels, 1)
			if (xIndex % 30) == 0 and (yIndex % 30) == 0 then
				print(x, y, frontierColor)
			end

			--[[
				table.insert(pixels, math.random(255)/255)
				table.insert(pixels, math.random(255)/255)
				table.insert(pixels, math.random(255)/255)
				table.insert(pixels, 1)
			]]
		end
	end

	canvas.EditableImage:WritePixels( Vector2.zero, canvas.EditableImage.Size, pixels )

	-- print(#pixels, EditableImage.Size.X * EditableImage.Size.Y * 4)
	-- temporaryImage:WritePixels(Vector2.zero, canvas.EditableImage.Size, pixels)
	-- temporaryImage.Parent = canvas.Container
	-- canvas.EditableImage = temporaryImage
end

return Module
