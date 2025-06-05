local game = require("game")
local menu = require("menu")
local suit = require "SUIT"

local state = "menu"
local ship_name = ""  -- Store ship name globally

function love.load()
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
            -- Store ship name before transitioning to game
            if new_state == "game" then
                ship_name = menu.get_ship_name()
            end
            state = new_state
        end
    end
end

function love.draw()
    if state == "game" then
        game.draw()
    elseif state == "menu" then
        menu.draw()
    end
end

-- Add keyboard event handler for debug toggle
function love.keypressed(key)
    if key == "f3" then
        game.toggleDebug()
    end
    suit.keypressed(key)
end

-- Add mouse event handlers for SUIT
function love.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        suit.updateMouse(x, y, true)
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then  -- Left mouse button
        suit.updateMouse(x, y, false)
    end
end

function love.mousemoved(x, y)
    suit.updateMouse(x, y, love.mouse.isDown(1))
end

-- Add function to get ship name
function love.get_ship_name()
    return ship_name
end

function love.textinput(t)
    suit.textinput(t)
end