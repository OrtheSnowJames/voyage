local menu = {}
local suit = require "SUIT"
local serialize = require("game.serialize")
local persistent_defaults = require("game.persistent_defaults")
local ending = require("game.ending")
local size = require("game.size")
local extra_math = require("game.extra_math")
local WEB_QUIT_REDIRECT_URL = "http://waffledogz.us"
local lerp = extra_math.lerp

local state = {
    ship_name = { text = "" }, -- initialize with text property for suit input
    selected_save = 1,         -- index of the selected save slot
    save_menu_error = "",      -- error message to display in save menu
    name_submitted = false,  -- track if name has been submitted
    show_error = false,  -- show error if name is empty
    persistent = {},  -- survives saves and wipes; loaded in menu.load and kept private to the menu
    time = 0,  -- track time for water colors
    DAY_LENGTH = 12 * 60  -- 12 minutes in seconds
}

local save_slot_prefix = "save_slot_"
local save_slots = 3

local menuState = {
    main_menu = "MAIN_MENU",
    startup_menu = "STARTUP_MENU",
    save_menu = "SAVE_MENU",
}

local menu_state = menuState.startup_menu

-- water colors for different times of day
local waterColors = {
    dawn  = {0.15, 0.2, 0.35},   -- bluish with slight warm tint (sunrise ~0:00)
    day   = {0.05, 0.1, 0.3},    -- bright clear blue (6:00)
    dusk  = {0.12, 0.08, 0.25},  -- deeper blue with purple hint (11:00)
    night = {0.01, 0.02, 0.08}   -- very dark blue (12:00)
}

-- function to get current water color based on time
local function getCurrentWaterColor()
    local timeOfDay = (state.time / state.DAY_LENGTH) * 12 -- convert to 12-hour format

    if timeOfDay >= 0 and timeOfDay < 1 then  -- dawn (0-1)
        local t = timeOfDay -- 0 to 1
        return {
            lerp(waterColors.dawn[1], waterColors.dawn[1], t),
            lerp(waterColors.dawn[2], waterColors.dawn[2], t),
            lerp(waterColors.dawn[3], waterColors.dawn[3], t)
        }
    elseif timeOfDay >= 1 and timeOfDay < 6 then  -- dawn to day (1-6)
        local t = (timeOfDay - 1) / 5  -- normalize to 0-1
        return {
            lerp(waterColors.dawn[1], waterColors.day[1], t),
            lerp(waterColors.dawn[2], waterColors.day[2], t),
            lerp(waterColors.dawn[3], waterColors.day[3], t)
        }
    elseif timeOfDay >= 6 and timeOfDay < 11 then  -- day (6-11)
        return waterColors.day
    elseif timeOfDay >= 11 and timeOfDay < 12 then  -- day to night (11-12)
        local t = (timeOfDay - 11)  -- 0 to 1
        return {
            lerp(waterColors.day[1], waterColors.dusk[1], t),
            lerp(waterColors.day[2], waterColors.dusk[2], t),
            lerp(waterColors.day[3], waterColors.dusk[3], t)
        }
    else  -- night (12)
        return waterColors.night
    end
end

-- check if save file exists at startup
local function check_save_file()
    if love.filesystem.getInfo("save.lua") then
        local save_data = serialize.load_data({
            allow_tampered = true
        })
        if save_data and save_data.name and save_data.name ~= "" then
            state.ship_name.text = save_data.name
            state.name_submitted = true
            menu_state = menuState.main_menu
            return true
        end
    end
    return false
end

-- create menu-specific ripple system
local ripples = {
    particles = {},
    maxParticles = 50,
    spawnTimer = 0,
    spawnRate = 0.5,
    spawnMargin = 100
}

function menu.get_name()
    return state.ship_name.text
end

function ripples:spawn()
    if #self.particles >= self.maxParticles then return end

    -- spawn at bottom, move up
    local speed = love.math.random(20, 40)

    table.insert(self.particles, {
        x = math.random() * size.CANVAS_WIDTH,
        y = size.CANVAS_HEIGHT + 50,
        vy = -speed,  -- move upward
        size = love.math.random(3, 6),
        alpha = 1,
        maxLife = love.math.random(3, 6),
        life = 0
    })
end

function ripples:update(dt)
    self.spawnTimer = self.spawnTimer + dt
    if self.spawnTimer >= self.spawnRate then
        self:spawn()
        self.spawnTimer = 0
    end

    for i = #self.particles, 1, -1 do
        local p = self.particles[i]

        -- move upward
        p.y = p.y + p.vy * dt

        -- update lifetime and alpha
        p.life = p.life + dt
        p.alpha = 1 - (p.life / p.maxLife)

        -- remove particles that are too old or moved off screen
        if p.life >= p.maxLife or p.y < -50 then
            table.remove(self.particles, i)
        end
    end
end

function ripples:draw()
    love.graphics.setLineWidth(1)
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(1, 1, 1, p.alpha * 0.5)

        -- draw little wave pattern like:
        --  ☐☐
        -- ☐  ☐
        local s = p.size
        -- top two dots
        love.graphics.rectangle("fill", p.x - s, p.y - s, s/2, s/2)
        love.graphics.rectangle("fill", p.x + s/2, p.y - s, s/2, s/2)
        -- bottom side dots
        love.graphics.rectangle("fill", p.x - s*1.5, p.y, s/2, s/2)
        love.graphics.rectangle("fill", p.x + s, p.y, s/2, s/2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local persistent_loaded = false

-- idempotent: mods load before the menu does and may already be asking for api.times_beaten
local function load_persistent()
    if persistent_loaded then
        return
    end
    persistent_loaded = true
    state.persistent = serialize.load_persistent(persistent_defaults)
    serialize.set_save_slot(state.persistent.save_slot, save_slot_prefix)
    ending.set_on_complete(function()
        state.persistent.times_beaten = state.persistent.times_beaten + 1
        serialize.save_persistent(state.persistent)
    end)
end

function menu.load()
    load_persistent()

    -- check save file on enter
    check_save_file()

    pixel_sans = love.graphics.newFont("assets/PixelifySans-SemiBold.ttf")
end

local function handle_quit_button()
    if love.system.getOS() == "Web" then
        love.system.openURL(WEB_QUIT_REDIRECT_URL)
        return
    end
    love.event.quit()
end

-- the ship name stored in a save slot, or nil when the slot is empty; re-read only when the file changes
local slot_name_cache = {}
local function get_slot_name(slot)
    local info = love.filesystem.getInfo(save_slot_prefix .. slot .. ".lua")
    if not info then
        slot_name_cache[slot] = nil
        return nil
    end

    local cached = slot_name_cache[slot]
    if not cached or cached.modtime ~= info.modtime or cached.size ~= info.size then
        local data = serialize.load_manually(slot, save_slot_prefix)
        cached = {modtime = info.modtime, size = info.size, name = tostring(data and data.name or "")}
        slot_name_cache[slot] = cached
    end
    return cached.name
end

local function slot_label(slot)
    local name = get_slot_name(slot)
    if name == nil then
        return "Empty slot " .. slot
    elseif name == "" then
        return "Slot " .. slot .. " (unnamed)"
    end
    return name
end

local function red_button()
    -- the theme draws a border and a shadow too, so every state needs all four colors
    local function red(border_alpha)
        return {
            bg = {1, 0, 0},
            fg = {1, 1, 1},
            border = {1, 0.6, 0.6, border_alpha},
            shadow = {0.25, 0, 0, 0.55}
        }
    end
    return {
        normal  = red(1),
        hovered = red(1),
        active  = red(1)
    }
end

function menu.update(dt)
    -- update time
    state.time = state.time + dt
    if state.time >= state.DAY_LENGTH then
        state.time = 0
    end

    -- update ripples
    ripples:update(dt)

    -- reset layout with bigger buttons and more spacing
    local button_width = 300
    local button_height = 50
    local button_spacing = 20
    suit.layout:reset(size.CANVAS_WIDTH/2 - button_width/2, size.CANVAS_HEIGHT/2 - 100)

    if menu_state == menuState.startup_menu then
        -- ship name input
        suit.Label("Enter your ship's name:", {align = "left"}, suit.layout:row(button_width, 40))
        suit.layout:row(button_width, button_spacing) -- spacing

        -- text input for ship name
        if suit.Input(state.ship_name, suit.layout:row(button_width, button_height)).submitted and #state.ship_name.text > 0 then
            state.name_submitted = true
            state.show_error = false
            -- save the ship name immediately
            serialize.save_data({ name = state.ship_name.text })
            -- save the data to save slot x
            local s_save_slot = menu.get_save_slot()
            serialize.save_manually({ name = state.ship_name.text }, s_save_slot, save_slot_prefix)

            state.save_menu_error = ""
        end
        suit.layout:row(button_width, button_spacing) -- spacing

        -- start button
        if suit.Button("Startup", suit.layout:row(button_width, button_height)).hit then
            if #state.ship_name.text > 0 then
                state.name_submitted = true
                state.show_error = false
                -- save the ship name immediately
                local s_save_slot = menu.get_save_slot()
                serialize.save_manually({ name = state.ship_name.text }, s_save_slot, save_slot_prefix)
                state.save_menu_error = ""
                menu_state = menuState.save_menu
            else
                state.show_error = true
            end
        end

        -- show error if name is empty
        if state.show_error then
            suit.layout:row(button_width, button_spacing) -- spacing
            suit.Label("Please enter a name!", {align = "left", color = {normal = {fg = {1,0,0}}}}, suit.layout:row(button_width, 40))
        end
    elseif menu_state == menuState.main_menu then
        -- regular menu buttons after name is set
        if suit.Button("Play", suit.layout:row(button_width, button_height)).hit then
            return "game"
        end
        suit.layout:row(button_width, button_spacing) -- spacing

        if suit.Button("Save Menu", suit.layout:row(button_width, button_height)).hit then
            state.save_menu_error = ""
            menu_state = menuState.save_menu
        end
        suit.layout:row(button_width, button_spacing) -- spacing

        if suit.Button("Quit", suit.layout:row(button_width, button_height)).hit then
            handle_quit_button()
        end
    elseif menu_state == menuState.save_menu then
        if suit.Button("Back", suit.layout:row(button_width, button_height)).hit then
            menu_state = menuState.main_menu
        end
        suit.layout:row(button_width, button_spacing) -- spacing

        local s_save_slot = menu.get_save_slot()
        -- x buttons; make the one on the save slot red_
        for i = 1, save_slots do
            local red_ = red_button()
            -- make the button red if it's the selected save slot
            if i == s_save_slot then
                if suit.Button(slot_label(i), {
                        id = "save_slot_" .. i,
                        color = red_
                    }, suit.layout:row(button_width, button_height)).hit then
                    s_save_slot = i
                    -- technically we don't have to do this lol
                end
            else
                if suit.Button(slot_label(i), {id = "save_slot_" .. i}, suit.layout:row(button_width, button_height)).hit then
                    s_save_slot = i
                    menu.set_save_slot(i)
                    -- check if save exists
                    if not love.filesystem.getInfo(save_slot_prefix .. s_save_slot .. ".lua") then
                        -- startup a new save slot: it needs its own ship name
                        state.save_menu_error = ""
                        state.ship_name.text = ""
                        state.name_submitted = false
                        menu_state = menuState.startup_menu
                    else
                        -- overwrite save with save slot data
                        local data, tampered = serialize.load_manually(s_save_slot, save_slot_prefix)
                        if data then
                            -- save_data signs what it writes, so remember an edited slot before it can be laundered
                            if tampered then
                                data.save_file_tampered = true
                            end
                            serialize.save_data(data)
                            state.save_menu_error = tampered and "This save slot was edited" or ""
                        else
                            state.save_menu_error = "Failed to load save slot; data could not be loaded"
                        end
                    end
                end
            end
        end

        suit.layout:row(button_width, button_spacing) -- spacing
        if suit.Button("Delete", suit.layout:row(button_width, button_height)).hit then
            -- delete it from filesystem
            local success = serialize.delete_slot(s_save_slot, save_slot_prefix)
            if not success then
                state.save_menu_error = "Failed to delete save slot"
            else
                state.save_menu_error = ""
            end
        end

        local x, y = suit.layout:row(200, 30)
        love.graphics.printf(state.save_menu_error, x, y, 200, "center")
    end

    return nil
end

function menu.draw()
    -- get current water color based on time of day
    local waterColor = getCurrentWaterColor()
    love.graphics.setColor(waterColor[1], waterColor[2], waterColor[3])
    love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)

    -- draw ripples first as background effect
    ripples:draw()

    -- draw title
    local title = "Voyage"
    local titleScale = 8.0

    local oldFont = love.graphics.getFont()
    local titleFont = pixel_sans

    love.graphics.setFont(titleFont)

    local w = titleFont:getWidth(title) * titleScale
    local x = size.CANVAS_WIDTH/2 - w/2
    local y = 24

    -- shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.print(title, x + 4, y + 4, 0, titleScale, titleScale)

    -- main text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(title, x, y, 0, titleScale, titleScale)

    love.graphics.setFont(oldFont)

    -- times the game has been beaten, top left
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Times beaten: " .. menu.get_times_beaten(), 12, 10)

    -- draw ui
    suit.draw()
end

-- the one persistent value mods are allowed to read (as api.times_beaten)
function menu.get_times_beaten()
    load_persistent()
    return state.persistent.times_beaten or 0
end

-- chooses the save slot: remembered across launches, and every save from now on goes into it
function menu.set_save_slot(slot)
    load_persistent()
    state.persistent.save_slot = slot
    serialize.save_persistent(state.persistent)
    serialize.set_save_slot(slot, save_slot_prefix)
end

function menu.get_save_slot()
    load_persistent()
    return state.persistent.save_slot or 1
end

function menu.get_ship_name()
    return state.ship_name.text
end

return menu
