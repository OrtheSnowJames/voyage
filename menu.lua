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
        print("there")
        local save_data = serialize.load_data()
        if save_data and save_data.name and save_data.name ~= "" then
            state.ship_name.text = save_data.name
            state.name_submitted = true
            print("Loaded ship name: " .. save_data.name)  -- Add debug print
            return true
        else
            print("No name in save data")  -- Add debug print
        end
    else
        print("not there apparently")
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
    
    table.insert(self.particles, {
        x = math.random() * love.graphics.getWidth(),
        y = math.random() * love.graphics.getHeight(),
        radius = love.math.random(5, 15),
        maxRadius = love.math.random(30, 60),
        speed = love.math.random(20, 40),
        alpha = 1
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
        p.radius = p.radius + p.speed * dt
        p.alpha = 1 - (p.radius / p.maxRadius)
        
        if p.radius >= p.maxRadius then
            table.remove(self.particles, i)
        end
    end
end

function ripples:draw()
    love.graphics.setLineWidth(2)
    for _, p in ipairs(self.particles) do
        love.graphics.setColor(1, 1, 1, p.alpha * 0.3)
        love.graphics.circle("line", p.x, p.y, p.radius)
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

    -- Reset layout
    suit.layout:reset(love.graphics.getWidth()/2 - 100, love.graphics.getHeight()/2 - 50)
    
    if not state.name_submitted then
        -- Ship name input
        suit.Label("Enter your ship's name:", {align = "left"}, suit.layout:row(200, 30))
        
        -- Text input for ship name
        if suit.Input(state.ship_name, suit.layout:row(200, 30)).submitted and #state.ship_name.text > 0 then
            state.name_submitted = true
            state.show_error = false
        end
        
        -- Start button
        if suit.Button("Startup", suit.layout:row(200, 30)).hit then
            if #state.ship_name.text > 0 then
                state.name_submitted = true
                state.show_error = false
            else
                state.show_error = true
            end
        end
        
        -- Show error if name is empty
        if state.show_error then
            suit.Label("Please enter a name!", {align = "left", color = {normal = {fg = {1,0,0}}}}, suit.layout:row(200, 30))
        end
    else
        -- Regular menu buttons after name is set
        if suit.Button("Play", suit.layout:row(200, 30)).hit then
            return "game"
        end
        
        if suit.Button("Reset Save", suit.layout:row(200, 30)).hit then
            love.filesystem.remove("save.lua")
            state.name_submitted = false
            state.ship_name.text = ""
            state.show_error = false
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
