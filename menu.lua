local menu = {}
local suit = require "SUIT"
local serialize = require("game.serialize")

local state = {
    ship_name = {text = ""},  -- Initialize with text property for SUIT input
    name_submitted = false,  -- Track if name has been submitted
    show_error = false,  -- Show error if name is empty
    time = 0,  -- Track time for water colors
    DAY_LENGTH = 12 * 60  -- 12 minutes in seconds
}

-- Water colors for different times of day
local waterColors = {
    dawn = {0.4, 0.3, 0.3},    -- Subtle orange-blue mix for sunrise (0:00)
    day = {0.04, 0.04, 0.2},   -- Bright blue (6:00)
    dusk = {0.3, 0.2, 0.3},    -- Purple-blue for evening (11:00)
    night = {0.02, 0.02, 0.1}  -- Dark blue for night (12:00)
}

-- Linear interpolation helper function
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Function to get current water color based on time
local function getCurrentWaterColor()
    local timeOfDay = (state.time / state.DAY_LENGTH) * 12 -- Convert to 12-hour format
    
    if timeOfDay >= 0 and timeOfDay < 1 then  -- Dawn (0-1)
        local t = timeOfDay -- 0 to 1
        return {
            lerp(waterColors.dawn[1], waterColors.dawn[1], t),
            lerp(waterColors.dawn[2], waterColors.dawn[2], t),
            lerp(waterColors.dawn[3], waterColors.dawn[3], t)
        }
    elseif timeOfDay >= 1 and timeOfDay < 6 then  -- Dawn to day (1-6)
        local t = (timeOfDay - 1) / 5  -- Normalize to 0-1
        return {
            lerp(waterColors.dawn[1], waterColors.day[1], t),
            lerp(waterColors.dawn[2], waterColors.day[2], t),
            lerp(waterColors.dawn[3], waterColors.day[3], t)
        }
    elseif timeOfDay >= 6 and timeOfDay < 11 then  -- Day (6-11)
        return waterColors.day
    elseif timeOfDay >= 11 and timeOfDay < 12 then  -- Day to night (11-12)
        local t = (timeOfDay - 11)  -- 0 to 1
        return {
            lerp(waterColors.day[1], waterColors.dusk[1], t),
            lerp(waterColors.day[2], waterColors.dusk[2], t),
            lerp(waterColors.day[3], waterColors.dusk[3], t)
        }
    else  -- Night (12)
        return waterColors.night
    end
end

-- Check if save file exists at startup
local function check_save_file()
    if love.filesystem.getInfo("save.lua") then
        local save_data = serialize.load_data()
        if save_data and save_data.name and save_data.name ~= "" then
            state.ship_name.text = save_data.name
            state.name_submitted = true
            return true
        end
    end
    return false
end

-- Create menu-specific ripple system
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
    
    -- Spawn at bottom, move up
    local speed = love.math.random(20, 40)
    
    table.insert(self.particles, {
        x = math.random() * love.graphics.getWidth(),
        y = love.graphics.getHeight() + 50,
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
        
        -- Move upward
        p.y = p.y + p.vy * dt
        
        -- Update lifetime and alpha
        p.life = p.life + dt
        p.alpha = 1 - (p.life / p.maxLife)
        
        -- Remove particles that are too old or moved off screen
        if p.life >= p.maxLife or p.y < -50 then
            table.remove(self.particles, i)
        end
    end
end

function ripples:draw()
    love.graphics.setLineWidth(1)
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(1, 1, 1, p.alpha * 0.5)
        
        -- Draw little wave pattern like:
        --  ☐☐
        -- ☐  ☐
        local s = p.size
        -- Top two dots
        love.graphics.rectangle("fill", p.x - s, p.y - s, s/2, s/2)
        love.graphics.rectangle("fill", p.x + s/2, p.y - s, s/2, s/2)
        -- Bottom side dots
        love.graphics.rectangle("fill", p.x - s*1.5, p.y, s/2, s/2)
        love.graphics.rectangle("fill", p.x + s, p.y, s/2, s/2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function menu.load()
    -- Check save file on enter
    check_save_file()
end

function menu.update(dt)
    -- Update time
    state.time = state.time + dt
    if state.time >= state.DAY_LENGTH then
        state.time = 0
    end

    -- Update ripples
    ripples:update(dt)

    -- Reset layout with bigger buttons and more spacing
    local button_width = 300
    local button_height = 50
    local button_spacing = 20
    suit.layout:reset(love.graphics.getWidth()/2 - button_width/2, love.graphics.getHeight()/2 - 100)
    
    if not state.name_submitted then
        -- Ship name input
        suit.Label("Enter your ship's name:", {align = "left"}, suit.layout:row(button_width, 40))
        suit.layout:row(button_width, button_spacing) -- spacing
        
        -- Text input for ship name
        if suit.Input(state.ship_name, suit.layout:row(button_width, button_height)).submitted and #state.ship_name.text > 0 then
            state.name_submitted = true
            state.show_error = false
        end
        suit.layout:row(button_width, button_spacing) -- spacing
        
        -- Start button
        if suit.Button("Startup", suit.layout:row(button_width, button_height)).hit then
            if #state.ship_name.text > 0 then
                state.name_submitted = true
                state.show_error = false
            else
                state.show_error = true
            end
        end
        
        -- Show error if name is empty
        if state.show_error then
            suit.layout:row(button_width, button_spacing) -- spacing
            suit.Label("Please enter a name!", {align = "left", color = {normal = {fg = {1,0,0}}}}, suit.layout:row(button_width, 40))
        end
    else
        -- Regular menu buttons after name is set
        if suit.Button("Play", suit.layout:row(button_width, button_height)).hit then
            return "game"
        end
        suit.layout:row(button_width, button_spacing) -- spacing
        
        if suit.Button("Reset Save", suit.layout:row(button_width, button_height)).hit then
            love.filesystem.remove("save.lua")
            state.name_submitted = false
            state.ship_name.text = ""
            state.show_error = false
        end
        suit.layout:row(button_width, button_spacing) -- spacing
        
        if suit.Button("Quit", suit.layout:row(button_width, button_height)).hit then
            love.event.quit()
        end
    end
    
    return nil
end

function menu.draw()
    -- Get current water color based on time of day
    local waterColor = getCurrentWaterColor()
    love.graphics.setColor(waterColor[1], waterColor[2], waterColor[3])
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw ripples first as background effect
    ripples:draw()
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    local title = "Voyage"
    local font = love.graphics.getFont()
    local title_width = font:getWidth(title)
    love.graphics.print(title, 
        love.graphics.getWidth()/2 - title_width/2, 
        50)  -- Fixed distance from top
    
    -- Draw UI
    suit.draw()
end

function menu.get_ship_name()
    return state.ship_name.text
end

return menu
