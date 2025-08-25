local game = require("game")
local menu = require("menu")
local suit = require "SUIT"
local size = require("game.size")

local state = "menu"
local ship_name = ""  -- store ship name globally

-- Canvas system for consistent rendering
local canvas = nil
local CANVAS_WIDTH = size.CANVAS_WIDTH
local CANVAS_HEIGHT = size.CANVAS_HEIGHT

function love.load()
    -- Create the fixed-size canvas
    canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
    
    game.load()
    menu.load()
end

function love.update(dt)
    if state == "game" then
        local new_state = game.update(dt)
        if new_state then
            state = new_state
        end
    elseif state == "menu" then
        local new_state = menu.update(dt)
        if new_state then
            -- store ship name before transitioning to game
            if new_state == "game" then
                ship_name = menu.get_ship_name()
            end
            state = new_state
        end
    end
end

function love.draw()
    -- Set the canvas as the render target with stencil support
    love.graphics.setCanvas{canvas, stencil=true}
    canvas:setFilter("nearest", "nearest")
    love.graphics.clear()
    
    -- Draw everything to the canvas at fixed 800x600 resolution
    if state == "game" then
        game.draw()
    elseif state == "menu" then
        menu.draw()
    end
    
    -- Reset canvas and draw it scaled to window size
    love.graphics.setCanvas()
    
    -- Calculate scaling to fit the canvas in the window
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local scale_x = window_width / CANVAS_WIDTH
    local scale_y = window_height / CANVAS_HEIGHT
    local scale = math.min(scale_x, scale_y)  -- maintain aspect ratio
    
    -- Calculate centering offset
    local offset_x = (window_width - CANVAS_WIDTH * scale) / 2
    local offset_y = (window_height - CANVAS_HEIGHT * scale) / 2
    
    -- Draw the canvas scaled and centered
    love.graphics.draw(canvas, offset_x, offset_y, 0, scale, scale)
end

-- add keyboard event handler for debug toggle
function love.keypressed(key)
    if key == "f3" then
        game.toggleDebug()
    end
    if state == "game" then
        game.keypressed(key)
    end
    suit.keypressed(key)
end

-- add mouse event handlers for suit
function love.mousepressed(x, y, button)
    if button == 1 then  -- left mouse button
        local canvas_x, canvas_y = love.windowToCanvas(x, y)
        suit.updateMouse(canvas_x, canvas_y, true)
        
        -- handle mobile button press
        if state == "game" then
            local game_module = require("game")
            if game_module.handle_mobile_button_press then
                game_module.handle_mobile_button_press(canvas_x, canvas_y)
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then  -- left mouse button
        local canvas_x, canvas_y = love.windowToCanvas(x, y)
        suit.updateMouse(canvas_x, canvas_y, false)
        
        -- handle mobile button release
        if state == "game" then
            local game_module = require("game")
            if game_module.handle_mobile_button_release then
                game_module.handle_mobile_button_release(canvas_x, canvas_y)
            end
        end
    end
end

function love.mousemoved(x, y)
    local canvas_x, canvas_y = love.windowToCanvas(x, y)
    suit.updateMouse(canvas_x, canvas_y, love.mouse.isDown(1))
end

-- add function to get ship name
function love.get_ship_name()
    return ship_name
end

-- Helper functions for coordinate conversion
function love.getCanvasWidth()
    return CANVAS_WIDTH
end

function love.getCanvasHeight()
    return CANVAS_HEIGHT
end

function love.windowToCanvas(x, y)
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local scale_x = window_width / CANVAS_WIDTH
    local scale_y = window_height / CANVAS_HEIGHT
    local scale = math.min(scale_x, scale_y)
    local offset_x = (window_width - CANVAS_WIDTH * scale) / 2
    local offset_y = (window_height - CANVAS_HEIGHT * scale) / 2
    
    local canvas_x = (x - offset_x) / scale
    local canvas_y = (y - offset_y) / scale
    
    return canvas_x, canvas_y
end

function love.textinput(t)
    suit.textinput(t)
end

-- handle window resize
function love.resize(w, h)
    -- [rainbow frog]
    -- Canvas system automatically handles resizing since we scale on every draw
end