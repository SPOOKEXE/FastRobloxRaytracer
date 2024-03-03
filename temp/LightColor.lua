local Lighting = game:GetService('Lighting')

local Intersections = require(script.Parent.Intersections)
local LightCacher = require(script.Parent.LightCacher)

-- // Module // --
local Module = {}

-- Converts a Color3 to a Vector3 for arithmetic usage.
function Module.ColorToVector(c3 : Color3) : Vector3
	return Vector3.new(c3.r, c3.g, c3.b)
end

-- Converts a Vector3 into a Color3, while making sure the values don't go above 1.
function Module.VectorToColor(v3 : Vector3) : Color3
	return Color3.new(math.min(1, v3.X), math.min(1, v3.Y), math.min(1, v3.Z))
end

-- Guess the ambient hue depending on the sun and the nearby lights
function Module:GetAmbientHue(position : Vector3) : Color3
	-- Roughly estimates the hue of a given position.
	local globalColor = nil
	if Lighting.GlobalShadows then
		local isSunBlocked = workspace:Raycast(position, Lighting:GetSunDirection() * 512)
		globalColor = (isSunBlocked and Lighting.Ambient or Lighting.OutdoorAmbient)
	else
		globalColor = Lighting.Ambient
	end
	globalColor = Module.ColorToVector(globalColor)

	local Queue = {} :: { Light }
	for _, Light in ipairs( LightCacher.GetEveryLight() ) do
		if Intersections.IsInLight(position, Light) then
			table.insert(Queue, Light)
		end
	end

	-- apply the color to the global color
	for _, light in ipairs(Queue) do
		local part = light.Parent
		local lightPos = nil
		if light:IsA("SurfaceLight") then -- Shift it to the front of the face.
			lightPos = (part.CFrame * CFrame.new(0, 0, -part.Size.Z * 0.5)).Position
		else
			lightPos = part.Position
		end
		local dist = (position-lightPos).Magnitude
		local fade = math.min(8, light.Range - dist)/4
		local brightness = math.max(0, math.min(1, light.Brightness)) * fade
		local color = Module.ColorToVector(light.Color) * brightness
		globalColor = globalColor + color
	end
	-- return the color from the vector
	return Module.VectorToColor(globalColor)
end

-- Richardean Colour Scheme
function Module.ApplyRCS( Color )
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

return Module
