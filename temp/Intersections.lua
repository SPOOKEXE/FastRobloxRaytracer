local NormalIdToCFrame = {}
for _, NormalId in ipairs( Enum.NormalId:GetEnumItems() ) do
	NormalIdToCFrame[ NormalId ] = CFrame.new( Vector3.FromNormalId(NormalId) )
end

-- Faster to localize this for the functions taht utilize it
local function IsInLightCone(position : Vector3, cf : CFrame, angle : number, range : number, face : Enum.NormalId, offset : CFrame) : boolean
	range = range + 4
	offset = offset or CFrame.identity
	local emissionPoint = CFrame.lookAt(cf.Position, (cf * NormalIdToCFrame[face]).Position) * offset
	local space = emissionPoint:PointToObjectSpace(position)
	if space.Magnitude > range then
		return false
	end
	local half_cone = math.rad(angle) / 2
	local unit = space.Unit
	return (unit.Z < 0) and unit.X > -half_cone and unit.X < half_cone
end

-- // Module // --
local Module = {}

-- Function for SpotLights/SurfaceLights
Module.IsInLightCone = IsInLightCone

-- Function to see if position is within a spot-light
function Module.IsInSpotLight( light : SpotLight, position : Vector3) : boolean
	return IsInLightCone(position, light.Parent.CFrame, light.Angle, light.Range, light.Face)
end

-- Function to see if a position is within a point light
function Module.IsInPointLight( light : PointLight, position : Vector3) : boolean
	return (position - light.Parent.Position).Magnitude <= (light.Range + 4)
end

-- TODO: optimize further - remove the surface light zones table with if-statements?
-- Function to see if position is within a surface light
local surfaceLightZones = {Front = "xy"; Back = "xy"; Left = "yz"; Right = "yz"; Top = "xz"; Bottom = "xz"}
function Module.IsInSurfaceLight( light : SurfaceLight, position : Vector3 ) : boolean
	local part = light.Parent
	local face = light.Face
	-- Calculate where the cone will be emitted from by capping
	-- certain xyz coordinates based on the face and it's size.
	local zone1, zone2 = string.match(surfaceLightZones[face.Name],"(%l)(%l)")
	local hsize1, hsize2 = part.Size[zone1] / 2, part.Size[zone2] / 2
	local space = part.CFrame:PointToObjectSpace(position)
	local pos = { x = 0, y = 0, z = 0 }
	pos[zone1] = math.max(-hsize1, math.min(hsize1, space[zone1]))
	pos[zone2] = math.max(-hsize2, math.min(hsize2, space[zone2]))
	local faceOffset = CFrame.new( 0, 0, part.Size.Z * -0.5 )
	local cf = part.CFrame * CFrame.new(pos.x, pos.y, pos.z)
	-- Act like a SpotLight using this CFrame.
	return IsInLightCone(position, cf, light.Angle, light.Range, face, faceOffset)
end

-- General Purpose IsInLight function.
function Module.IsInLightInstance( light : Light, position : Vector3 ) : boolean
	assert( light:IsA("Light"), "Passed light is not a light instance." )
	if light:IsA("PointLight") then
		return Module.IsInPointLight(light, position)
	elseif light:IsA("SpotLight") then
		return Module.IsInSpotLight(light, position)
	elseif light:IsA("SurfaceLight") then
		return Module.IsInSurfaceLight(light, position)
	else
		error("Unrecognized Light: "..tostring(light.ClassName))
	end
end

return Module
