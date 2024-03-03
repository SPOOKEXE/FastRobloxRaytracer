
local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CanvasImageModule = require(ReplicatedStorage:WaitForChild('CanvasImage'))

local RaytracerCore = require(script.RaytracerCore)

local CurrentCamera = workspace.CurrentCamera

local PixelsScreenGui : ScreenGui = nil
local Canvas : CanvasImageModule.Canvas = nil
local IsBusyRendering = false

-- // Module // --
local Module = {}

function Module.Render( canvas : CanvasImageModule.Canvas, config : RaytracerCore.RaytraceConfig )
	if IsBusyRendering then
		return
	end
	IsBusyRendering = true

	print('Starting Raytrace:')
	local t = os.clock()
	RaytracerCore.Render( CurrentCamera, canvas, config )
	print('Duration:', os.clock() - t)

	IsBusyRendering = false
end

function Module.Init()
	PixelsScreenGui = Instance.new('ScreenGui')
	PixelsScreenGui.Name = 'PixelsScreen'
	PixelsScreenGui.ResetOnSpawn = false
	PixelsScreenGui.IgnoreGuiInset = true
	PixelsScreenGui.Parent = LocalPlayer.PlayerGui

	local ImageContainer = Instance.new('ImageLabel')
	ImageContainer.Name = 'ImageContainer'
	ImageContainer.ScaleType = Enum.ScaleType.Fit
	ImageContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	ImageContainer.Position = UDim2.fromScale(0.5, 0.5)
	ImageContainer.Size = UDim2.fromScale(1, 1)
	ImageContainer.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
	ImageContainer.BorderSizePixel = 0
	ImageContainer.Parent = PixelsScreenGui

	-- resizing image
	local MaxBounds = Vector2.new(1024, 1024)
	local Size = CanvasImageModule.ScaleSizeToBounds(PixelsScreenGui.AbsoluteSize, MaxBounds )
	Canvas = CanvasImageModule.Canvas.New(ImageContainer, Size, {0,0,0,1})
	PixelsScreenGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
		local NewAbsoluteSize = CanvasImageModule.ScaleSizeToBounds(PixelsScreenGui.AbsoluteSize, MaxBounds)
		Canvas:ResizeCanvas(NewAbsoluteSize)
	end)

	-- PixelsScreenGui.Enabled = false
end

function Module.Start()

	local config : RaytracerCore.RaytraceConfig = RaytracerCore.CreateConfig({
		MaxDepth = 2,
		NRaySplits = 10,
		AmbientColor = Color3.fromRGB(17, 133, 149)
	})

	UserInputService.InputBegan:Connect(function(inputObject, _)
		if inputObject.KeyCode == Enum.KeyCode.V then
			Module.Render(Canvas, config)
		end
	end)

end

return Module
