local game = require("game")
local menu = require("menu")
local mod_terminal = require("game.mod_terminal")
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
local USE_OFFSCREEN_CANVAS = true
local runtime_error = nil
local default_ui_font = nil
local launcher = nil

local function record_runtime_error(context, err)
    local trace = ""
    if debug and debug.traceback then
        trace = "\n" .. debug.traceback("", 2)
    end
    runtime_error = tostring(context) .. ": " .. tostring(err) .. trace
    print(runtime_error)
end

local function recreate_canvas(width, height)
    size.setDimensions(width, height)
    CANVAS_WIDTH = size.CANVAS_WIDTH
    CANVAS_HEIGHT = size.CANVAS_HEIGHT
    if USE_OFFSCREEN_CANVAS then
        canvas = love.graphics.newCanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
    else
        canvas = nil
    end
end

local function sync_canvas_dimensions_if_needed()
    local w, h = love.graphics.getDimensions()
    if w ~= CANVAS_WIDTH or h ~= CANVAS_HEIGHT then
        recreate_canvas(w, h)
    end
end

function love.load()
    -- Disable smoothing/anti-aliasing for a crisp pixel look.
    love.graphics.setDefaultFilter("nearest", "nearest", 1)
    love.graphics.setLineStyle("rough")

    -- Fix grey screen in love.js
    if love.system.getOS() ~= "Web" then
        love.window.setMode(800, 600, {
            resizable = true,
            minwidth = 400,
            minheight = 300
        })
    end

    local ok, err = xpcall(function()
        print("hello")
        USE_OFFSCREEN_CANVAS = love.system.getOS() ~= "Web"
        local window_width, window_height = love.graphics.getDimensions()
        recreate_canvas(window_width, window_height)
        math.randomseed(os.time())
        default_ui_font = love.graphics.getFont()

        gamestate.set(GameType.MENU)
        launcher = mod_terminal.new({
            on_start = function()
                if default_ui_font then
                    love.graphics.setFont(default_ui_font)
                end
                game.load()
                menu.load()
            end
        })
        launcher:setup()
    end, function(e) return e end)
    if not ok then
        record_runtime_error("load", err)
    end
end

function love.update(dt)
    if runtime_error then
        return
    end
    local ok, err = xpcall(function()
        sync_canvas_dimensions_if_needed()
        if launcher and launcher:is_active() then
            launcher:update(dt)
            return
        end

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
    end, function(e) return e end)
    if not ok then
        record_runtime_error("update", err)
    end
end

function love.draw()
    if runtime_error then
        love.graphics.setCanvas()
        love.graphics.origin()
        pcall(love.graphics.setShader)
        pcall(love.graphics.setScissor)
        love.graphics.clear(0.1, 0.1, 0.1, 1)
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.printf(runtime_error, 12, 12, math.max(100, love.graphics.getWidth() - 24))
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local ok, err = xpcall(function()
        sync_canvas_dimensions_if_needed()

        -- Reset graphics state each frame. WebGL builds can keep stale state.
        love.graphics.origin()
        pcall(love.graphics.setShader)
        pcall(love.graphics.setScissor)
        love.graphics.setColor(1, 1, 1, 1)
        if default_ui_font then
            love.graphics.setFont(default_ui_font)
        end

        if USE_OFFSCREEN_CANVAS and canvas then
            -- set the canvas as the render target with stencil support
            love.graphics.setCanvas({canvas, stencil = true})
            canvas:setFilter("nearest", "nearest")
            love.graphics.clear()

            if launcher and launcher:is_active() then
                launcher:draw(CANVAS_WIDTH, CANVAS_HEIGHT)
            elseif game_states[gamestate.get()] then
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
        else
            -- Web fallback: draw directly in the current canvas size.
            love.graphics.clear(0, 0, 0, 1)
            if launcher and launcher:is_active() then
                launcher:draw(CANVAS_WIDTH, CANVAS_HEIGHT)
            elseif game_states[gamestate.get()] then
                game.draw()
            elseif gamestate.get() == GameType.MENU then
                menu.draw()
            end
        end
    end, function(e) return e end)
    if not ok then
        pcall(love.graphics.setCanvas)
        record_runtime_error("draw", err)
    end
end

-- add keyboard event handler for debug toggle
function love.keypressed(key)
    if launcher and launcher:keypressed(key) then
        return
    end

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
    local canvas_x, canvas_y = love.windowToCanvas(x, y)
    if launcher and launcher:mousepressed(canvas_x, canvas_y, button) then
        return
    end

    if button == 1 then  -- left mouse button
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
    local canvas_x, canvas_y = love.windowToCanvas(x, y)
    if launcher and launcher:mousereleased(canvas_x, canvas_y, button) then
        return
    end
    if button == 1 then  -- left mouse button
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
    if launcher and launcher:mousemoved(canvas_x, canvas_y) then
        return
    end
    suit.updateMouse(canvas_x, canvas_y, love.mouse.isDown(1))
end

function love.wheelmoved(x, y)
    if launcher and launcher:wheelmoved(x, y) then
        return
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    local pixel_x = x * love.graphics.getWidth()
    local pixel_y = y * love.graphics.getHeight()
    love.mousepressed(pixel_x, pixel_y, 1)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    local pixel_x = x * love.graphics.getWidth()
    local pixel_y = y * love.graphics.getHeight()
    love.mousereleased(pixel_x, pixel_y, 1)
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
    if launcher and launcher:textinput(t) then
        return
    end
    suit.textinput(t)
end

-- handle window resize
function love.resize(w, h)
    recreate_canvas(w, h)
end
