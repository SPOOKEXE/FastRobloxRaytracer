-- // Module // --
local Module = {}

function Module.AngleBetween(vectorA : Vector3, vectorB : Vector3) : number
	return math.acos(math.clamp(vectorA:Dot(vectorB), -1, 1))
end

function Module.GetCFrameFaceDirection( CF : CFrame, Way : Enum.NormalId) : Vector3
	if Way == Enum.NormalId.Front then
		return CF.LookVector
	elseif Way == Enum.NormalId.Left then
		return -CF.RightVector
	elseif Way == Enum.NormalId.Right then
		return CF.RightVector
	elseif Way == Enum.NormalId.Top then
		return CF.UpVector
	elseif Way == Enum.NormalId.Bottom then
		return -CF.UpVector
	elseif Way == Enum.NormalId.Back then
		return -CF.LookVector
	end
	return Vector3.zero -- unknown
end

return Module
