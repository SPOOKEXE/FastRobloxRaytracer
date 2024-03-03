
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
	RootRay : RayData,
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
	local orth = Vector3.new(0, 0, 1):Cross(axis)
	local rot = math.acos(axis:Dot(Vector3.zAxis))
	return (CFrame.fromAxisAngle(orth, rot) * vec).Unit
end

local function CreateRayData( frontier : RayFrontier, origin : Vector3, direction : Vector3, color : Color3, parent : RayData? ) : RayData
	local newRayData = {
		UUID = tostring(GLOBAL_COUNTER),
		Parent = parent and parent.UUID or false,
		Origin = origin,
		Direction = direction,
		WeightedColor = color,
		Depth = parent and (parent.Depth + 1) or 1,
	}

	local endPosition = origin + (direction * 50)
	VisualizerModule.Beam( origin, endPosition, 20, { Color = ColorSequence.new( Color3.new(0, 0.7, 0) ) } )

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

-- // Module // --
local Module = {}

Module.RAYCAST_PARAMS = RaycastParams.new()
Module.RAYCAST_PARAMS.IgnoreWater = false

function Module.CreateConfig( properties : { [string] : any } ) : RaytraceConfig
	return SetProperties( {
		MaxDepth = 3, -- what is the max depth of a ray
		RayLength = 100, -- distance for raycasting
		NRaySplits = 4, -- how many rays are generated on a new reflection
	}, properties )
end

function Module.ResolveColorFromFrontier( frontier : RayFrontier ) : Color3
	-- return Color3.fromRGB( math.random(255), math.random(255), math.random(255) )
	return frontier.RootRay.WeightedColor
end

function Module.ResolveRay( frontier : RayFrontier, rayData : RayData, config : RaytraceConfig )
	local rayResult : RaycastResult = workspace:Raycast( rayData.Origin, rayData.Direction * config.RayLength, Module.RAYCAST_PARAMS )
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
	objectColor = rayData.WeightedColor:Lerp(objectColor, 0.6) -- lerp towards the object's color

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
	for _ = 1, #frontier.OngoingRays do
		local Data : RayData = table.remove( frontier.OngoingRays, 1 )
		Module.ResolveRay( frontier, Data, config )
	end
	frontier.IsCompleted = true
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
			local finish = ray.Origin + (ray.Direction * 10)
			VisualizerModule.Beam( ray.Origin, finish, 20, { Color = ColorSequence.new( Color3.new(0, 0.7, 0) ) } )
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

	--[==[
		local pixels : {number} = {}
		for x = 1, canvas.EditableImage.Size.X do
			for y = 1, canvas.EditableImage.Size.Y do

				local xIndex = math.round(x / skipToXth) + 1
				local yIndex = math.round(y / skipToYth) + 1
				local frontier = frontiers[ xIndex * yIndex ] or frontiers[1]
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

		canvas.EditableImage:WritePixels( Vector2.zero, canvas.EditableImage.Size, pixels )
	]==]

	-- print(#pixels, EditableImage.Size.X * EditableImage.Size.Y * 4)
	-- temporaryImage:WritePixels(Vector2.zero, canvas.EditableImage.Size, pixels)
	-- temporaryImage.Parent = canvas.Container
	-- canvas.EditableImage = temporaryImage
end

return Module
