-- Canvas dimensions for consistent rendering
local size = {}

-- Fixed canvas dimensions
size.CANVAS_WIDTH = 800
size.CANVAS_HEIGHT = 600

-- Helper functions
function size.getWidth()
    return size.CANVAS_WIDTH
end

function size.getHeight()
    return size.CANVAS_HEIGHT
end

return size
