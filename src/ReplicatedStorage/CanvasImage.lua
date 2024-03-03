
export type Canvas = {
	-- properties
	Container : ImageLabel,
	CanvasSize : Vector2,
	EditableImage : EditableImage,
	-- functions
	WritePixelFormat : ( Canvas, Vector2, Vector2, { {number} } ) -> nil,
	ReadPixelFormat : ( Canvas, Vector2, Vector2 ) -> { {number} },
	ResizeCanvas : (Canvas, Vector2) -> nil,
}

local function CreatePixelSequence( total_pixels : number, template_pixel : {number} ) : { number }
	local array = table.create(total_pixels * 4, false)
	for i = 1, total_pixels * 4, 4 do
		array[i] = template_pixel[1]
		array[i+1] = template_pixel[2]
		array[i+2] = template_pixel[3]
		array[i+3] = template_pixel[4]
	end
	return array
end

-- // Class // --
local Canvas = {}
Canvas.__index = Canvas

function Canvas.New( container : ImageLabel, canvasSize : Vector2, background : { number } ) : Canvas
	local image = Instance.new('EditableImage')
	image:Resize( canvasSize )
	image:WritePixels( Vector2.zero, canvasSize, CreatePixelSequence(canvasSize.X * canvasSize.Y, background) )
	image.Parent = container
	local self = { Container = container, CanvasSize = canvasSize, EditableImage = image, BackgroundFColor = background }
	return setmetatable(self, Canvas)
end

function Canvas:WritePixelFormat( topLeft : Vector2, size : Vector2, pixels : { {number} } )
	local pixelArray = {}
	for _, item in ipairs( pixels ) do
		table.insert(pixelArray, item[1])
		table.insert(pixelArray, item[2])
		table.insert(pixelArray, item[3])
		table.insert(pixelArray, item[4])
	end
	self.EditableImage:WritePixels(topLeft, size, pixelArray)
end

function Canvas:ReadPixelFormat( topLeft : Vector2, size : Vector2 ) : { {number} }
	local pixels = self.EditableImage:ReadPixels(topLeft, size)
	local pixelFormat = {}
	for i = 1, (size.X * size.Y * 4), 4 do
		table.insert(pixelFormat, { pixels[i], pixels[i+1], pixels[i+2], pixels[i+3] })
	end
	return pixelFormat
end

function Canvas:ResizeCanvas( new_size : Vector2 )
	assert( new_size.X <= 1024 and new_size.Y <= 1024, 'Max size reached, cannot go larger than 1024x1024.' )
	local newImage = Instance.new('EditableImage')
	newImage:Resize( new_size )
	newImage:WritePixels( Vector2.zero, new_size, CreatePixelSequence( new_size.X * new_size.Y, self.BackgroundFColor ) )
	local originalImage = self.EditableImage
	local upperBounds = Vector2.new(math.min(new_size.X, originalImage.Size.X), math.min(new_size.Y, originalImage.Size.Y))
	originalImage:Crop( Vector2.zero, upperBounds )
	newImage:DrawImage(Vector2.zero, originalImage, Enum.ImageCombineType.Overwrite)
	self.EditableImage = newImage
end

-- // Module // --
local Module = {}
Module.Canvas = Canvas
Module.CreatePixelSequence = CreatePixelSequence

function Module.ClampSizeToBounds(canvasSize : Vector2, boundsMax : Vector2 ) : Vector2
	return Vector2.new( math.min(canvasSize.X, boundsMax.X), math.min(canvasSize.Y, boundsMax.Y) )
end

function Module.ScaleSizeToBounds( canvasSize : Vector2, boundsMax : Vector2 ) : Vector2
	if canvasSize.X > boundsMax.X then
		-- scale X down
		local delta = (boundsMax.X / canvasSize.X)
		canvasSize = Vector2.new( boundsMax.X, math.floor(canvasSize.Y * delta) )
	end
	if canvasSize.Y > boundsMax.Y then
		-- scale Y down
		local delta = (boundsMax.Y / canvasSize.Y)
		canvasSize = Vector2.new( math.floor(boundsMax.X * delta), boundsMax.Y )
	end
	return canvasSize
end

function Module.ColorToPixelFormat( color : Color3 ) : { number } -- ALPHA IS LOST
	return { math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255), 0 }
end

function Module.PixelFormatToColor( formatted : {number} ) : Color3 -- ALPHA IS LOST
	return Color3.fromRGB( formatted[1], formatted[2], formatted[3] )
end

return Module
