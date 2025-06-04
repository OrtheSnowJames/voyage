local menu = {}
local suit = require "SUIT"
local game = require("game")  -- Import game module to access time system and ripples

-- Create menu-specific ripple system
local ripples = {
    particles = {},
    maxParticles = 50,
    spawnTimer = 0,
    spawnRate = 0.5, -- seconds between spawns
    spawnMargin = 100 -- spawn ripples slightly outside view
}

-- Copy ripple functions from game
function ripples:spawn(x, y)
    if #self.particles >= self.maxParticles then return end
    
    -- Get viewport boundaries (in world coordinates)
    local viewWidth = love.graphics.getWidth()
    local viewHeight = love.graphics.getHeight()
    
    -- Generate position within and slightly outside viewport if not specified
    local ripple_x = x or (-self.spawnMargin + math.random() * (viewWidth + 2 * self.spawnMargin))
    local ripple_y = y or (-self.spawnMargin + math.random() * (viewHeight + 2 * self.spawnMargin))
    
    table.insert(self.particles, {
        x = ripple_x,
        y = ripple_y,
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

    -- Get viewport boundaries
    local viewWidth = love.graphics.getWidth()
    local viewHeight = love.graphics.getHeight()
    
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.radius = p.radius + p.speed * dt
        p.alpha = 1 - (p.radius / p.maxRadius)
        
        -- Remove particles that are either too big or outside viewport with margin
        if p.radius >= p.maxRadius or
           p.x < -self.spawnMargin or
           p.x > viewWidth + self.spawnMargin or
           p.y < -self.spawnMargin or
           p.y > viewHeight + self.spawnMargin then
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

-- Water colors for different times of day
local waterColors = {
    dawn = {0.8, 0.6, 0.4},    -- Orange tint for sunrise (0:00)
    day = {0.04, 0.04, 0.2},   -- Bright blue (6:00)
    dusk = {0.3, 0.3, 0.4},    -- Purple-blue for evening (11:00)
    night = {0.02, 0.02, 0.1}  -- Dark blue for night (12:00)
}

-- Linear interpolation helper function
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Function to get current water color based on time
local function getCurrentWaterColor(time_system)
    local timeOfDay = (time_system.time / time_system.DAY_LENGTH) * 12 -- Convert to 12-hour format
    
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

function menu.update(dt)
    -- Update time system
    if not game.player_ship.time_system.is_sleeping then
        game.player_ship.time_system.time = game.player_ship.time_system.time + dt
        
        -- Check if we've reached the end of the day (12 minutes)
        if game.player_ship.time_system.time >= game.player_ship.time_system.DAY_LENGTH then
            game.player_ship.time_system.time = 0
        end
    end

    -- Update ripples
    ripples:update(dt)

    -- Center the buttons on screen
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local button_width = 200
    local button_height = 50
    local padding = 20
    
    -- Calculate center position
    local start_x = (window_width - button_width) / 2
    local start_y = (window_height - (button_height * 2 + padding)) / 2
    
    -- Reset layout for menu buttons
    suit.layout:reset(start_x, start_y)
    suit.layout:padding(padding)
    
    -- Play Game button
    if suit.Button("Play Game", {id = "play"}, suit.layout:row(button_width, button_height)).hit then
        -- Switch to game state
        return "game"
    end
    
    -- Quit button
    if suit.Button("Quit", {id = "quit"}, suit.layout:row(button_width, button_height)).hit then
        love.event.quit()
    end

    if suit.Button("Eject Save", {id = "delete"}, suit.layout:row(button_width, button_height)).hit then
        love.filesystem.remove("save.lua")
    end

    return nil
end

function menu.draw()
    -- Get current water color based on time of day
    local waterColor = getCurrentWaterColor(game.player_ship.time_system)
    love.graphics.clear(waterColor[1], waterColor[2], waterColor[3])
    
    -- Draw ripples
    ripples:draw()
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    local title = "Fishing Voyage"
    local font = love.graphics.getFont()
    local title_width = font:getWidth(title)
    local title_height = font:getHeight()
    love.graphics.print(title, 
        (love.graphics.getWidth() - title_width) / 2,
        50)  -- Fixed distance from top
    
    -- Draw menu UI
    suit.draw()
end

return menu
