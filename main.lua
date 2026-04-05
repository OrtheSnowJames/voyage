local game = require("game")
local menu = require("menu")
local suit = require "SUIT"
local size = require("game.size")
local gamestate = require("game.gamestate")
local GameType = require("game.gametypes")

local ship_name = ""  -- store ship name globally

local game_states = {
    [GameType.VOYAGE] = true,
    [GameType.FISHING] = true,
    [GameType.COMBAT] = true,
    [GameType.SHOP] = true,
    [GameType.SHOP_TRANSFER] = true,
    [GameType.SHOP_VIEW_INVENTORY] = true,
    [GameType.SLEEPING] = true,
}

-- canvas system for consistent rendering
local canvas = nil
local CANVAS_WIDTH = size.CANVAS_WIDTH
local CANVAS_HEIGHT = size.CANVAS_HEIGHT

local function recreate_canvas(width, height)
    size.setDimensions(width, height)
    CANVAS_WIDTH = size.CANVAS_WIDTH
    CANVAS_HEIGHT = size.CANVAS_HEIGHT
    canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
end

function love.load()
    local window_width, window_height = love.graphics.getDimensions()
    recreate_canvas(window_width, window_height)
    math.randomseed(os.time())

    gamestate.set(GameType.MENU)
    game.load()
    menu.load()
end

function love.update(dt)
    if game_states[gamestate.get()] then
        local next_state_str = game.update(dt)
        if next_state_str then
            gamestate.set(next_state_str) -- should only be "menu"
        end
    elseif gamestate.get() == GameType.MENU then
        local next_state_str = menu.update(dt)
        if next_state_str then
            -- store ship name before transitioning to game
            if next_state_str == "game" then
                ship_name = menu.get_ship_name()
                gamestate.set(GameType.VOYAGE)
            else
                gamestate.set(next_state_str)
            end
        end
    end
end

function love.draw()
    -- set the canvas as the render target with stencil support
    love.graphics.setCanvas{canvas, stencil=true}
    canvas:setFilter("nearest", "nearest")
    love.graphics.clear()
    
    -- draw everything to the current canvas resolution
    if game_states[gamestate.get()] then
        game.draw()
    elseif gamestate.get() == GameType.MENU then
        menu.draw()
    end
    
    -- reset canvas and draw it scaled to window size
    love.graphics.setCanvas()
    
    -- draw canvas to the window; scale should usually be 1:1 since we recreate on resize
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local scale_x = window_width / CANVAS_WIDTH
    local scale_y = window_height / CANVAS_HEIGHT

    -- draw the canvas stretched to current window size
    love.graphics.draw(canvas, 0, 0, 0, scale_x, scale_y)
end

-- add keyboard event handler for debug toggle
function love.keypressed(key)
    if key == "f3" then
        game.toggleDebug()
    end
    if game_states[gamestate.get()] then
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
        if game_states[gamestate.get()] then
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
        if game_states[gamestate.get()] then
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

-- helper functions for coordinate conversion
function love.getCanvasWidth()
    return CANVAS_WIDTH
end

function love.getCanvasHeight()
    return CANVAS_HEIGHT
end

function love.windowToCanvas(x, y)
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local canvas_x = x * (CANVAS_WIDTH / math.max(1, window_width))
    local canvas_y = y * (CANVAS_HEIGHT / math.max(1, window_height))
    
    return canvas_x, canvas_y
end

function love.textinput(t)
    suit.textinput(t)
end

-- handle window resize
function love.resize(w, h)
    recreate_canvas(w, h)
end
