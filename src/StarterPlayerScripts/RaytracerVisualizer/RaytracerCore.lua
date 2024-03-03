
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VisualizerModule = require(ReplicatedStorage:WaitForChild('Visualizers'))

local GLOBAL_COUNTER = 0

export type RaytraceConfig = {
	MaxDepth : number,
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
	OngoingRays : { RayData },
	RayMap : { [string] : RayData },
	RayHeirarchyForward : { [string] : {string} }, -- { sourceUUID : {childrenUUID} }
	RayHeirarchyBackward : { [string] : string }, -- { childUUID : sourceUUID }
}

-- // Module // --
local Module = {}

function Module.ResolveColorFromFrontier( frontier : RayFrontier ) : Color3

end

function Module.ResolveRay( frontier : RayFrontier, rayData : RayData, config : RaytraceConfig )

end

function Module.UpdateFrontier( frontier : RayFrontier, config : RaytraceConfig )
	for _ = 1, #frontier.OngoingRays do
		Module.ResolveRay( frontier, table.remove( frontier.OngoingRays, 1 ), config )
	end
end

function Module.CreateFrontier( origin : Vector3, direction : Vector3, config : RaytraceConfig ) : RayFrontier
	local frontier = {
		OngoingRays = {},
		RayMap = {},
		RayHeirarchyForward = {},
		RayHeirarchyBackward = {},
	}

	local rootRay = {
		UUID = tostring(GLOBAL_COUNTER),
		Parent = false,
		Origin = origin,
		Direction = direction,
		WeightedColor = Color3.fromRGB(100, 100, 100),
		Depth = 0,
	}

	GLOBAL_COUNTER += 1
	Module.ResolveRay( frontier, rootRay, config )

	return frontier
end

function Module.Render( Camera : Camera, EditableImage : EditableImage, config : RaytraceConfig )

	local skipX = 50
	local skipY = 40

	local frontiers : { RayFrontier } = { }

	local stepX = (Camera.ViewportSize.X / EditableImage.Size.X)
	local stepY = (Camera.ViewportSize.Y / EditableImage.Size.Y)
	for x = 0, (EditableImage.Size.X - 1), skipX do
		for y = 0, (EditableImage.Size.Y - 1), skipY do
			local ray = Camera:ViewportPointToRay(x * stepX, y * stepY)
			local frontier = Module.CreateFrontier(ray.Origin, ray.Direction, config)
			table.insert(frontiers, frontier)
			-- visualize
			-- local finish = ray.Origin + (ray.Direction * 5)
			-- VisualizerModule.Beam( ray.Origin, finish, 20, { Color = ColorSequence.new( Color3.new(0, 0.7, 0) ) } )
			-- local rayCFrame = CFrame.lookAt( ray.Origin, ray.Origin + ray.Direction )
		end
	end

	-- TODO: keep updating frontiers

	--[[
		local pixels : {number} = {}
		for x = 0, EditableImage.Size.X - 1, skipX do
			for y = 0, EditableImage.Size.Y - 1, skipY do
				local frontier = frontiers[(x+1)*(y+1)]
				local color = Module.ResolveColorFromFrontier( frontier )
				table.insert(pixels, { color.R, color.G, color.B, 1 })
			end
		end
		EditableImage:WritePixels(Vector2.zero, EditableImage.Size, pixels)
	]]

end

return Module
