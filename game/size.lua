-- canvas dimensions for consistent rendering
local size = {}

-- fixed canvas dimensions
size.CANVAS_WIDTH = 800
size.CANVAS_HEIGHT = 600

function size.setDimensions(width, height)
    local w = math.floor(tonumber(width) or size.CANVAS_WIDTH)
    local h = math.floor(tonumber(height) or size.CANVAS_HEIGHT)
    size.CANVAS_WIDTH = math.max(1, w)
    size.CANVAS_HEIGHT = math.max(1, h)
end

-- helper functions
function size.getWidth()
    return size.CANVAS_WIDTH
end

function size.getHeight()
    return size.CANVAS_HEIGHT
end

return size
