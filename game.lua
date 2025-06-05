-- game.lua

local game = {}
local suit = require "SUIT"
local fishing = require("game.fishing")
local serialize = require("game.serialize")
local combat = require("game.combat")
local shop = require("shop")
local spawnenemy = require("game.spawnenemy")
local menu = require("menu")  -- Add menu requirement to get ship name

-- game configuration (modifiable during runtime)
local game_config = {
    fishing_cooldown = 5,  -- base cooldown time in seconds
    catch_text_spacing = 20,  -- vertical spacing between texts
}

-- derived settings (automatically update when config changes)
local function get_max_catch_texts()
    return math.ceil(game_config.fishing_cooldown)  -- one text slot per second of cooldown
end

local function get_animation_duration()
    return game_config.fishing_cooldown * 0.06  -- animation takes 6% of cooldown time
end

-- debug options
local debugOptions = {
    showDebugButtons = false  -- toggle with f3
}

local gameState = {
    focus = "", -- either "voyage", "sleep", "shop", "attack"
    combat = {
        is_active = false,
        zoom_progress = 0,
        zoom_duration = 2.0,  -- 2 seconds for zoom animation
        target_zoom = 2.0,    -- zoom in 2x for combat
        enemy = nil,          -- store enemy data during combat
        result_display_time = 3.0,  -- time to display combat results
        result = nil,         -- store combat results
        is_fully_zoomed = false,  -- new flag to track zoom completion
        defeat_flash = {
            active = false,
            alpha = 0,
            duration = 3.0,   -- 3 seconds to fade to white
            timer = 0,
            text_display_time = 2.0  -- Show defeat text for 2 seconds before flash
        }
    }
}

local camera = {
    x = 0,
    y = 0,
    scale = 1
}

local player_ship = {
    x = 100,  -- starting x position
    y = 100,  -- starting y position
    name = "",  -- ship name
    men = 1,
    fainted_men = 0,
    velocity_x = 0,
    velocity_y = 0,
    rotation = 0,  -- current rotation in radians
    target_rotation = 0,  -- where the ship is trying to turn to
    
    -- Movement configuration
    max_speed = 200,  -- maximum speed in pixels per second
    acceleration = 50,  -- how quickly it speeds up
    deceleration = 30,  -- how quickly it slows down
    turn_speed = 2,  -- how quickly it can turn (radians per second)
    turn_penalty = 0.7,  -- speed multiplier when turning
    reverse_multiplier = 0.5,  -- speed multiplier when reversing
    
    radius = 20,
    color = {1, 1, 1, 1},
    rod = "Basic Rod",
    sword = "Basic Sword",
    direction = 0,
    caught_fish = {},
    time_system = {
        time = 0,
        DAY_LENGTH = 12 * 60,
        SLEEP_DURATION = 10,
        sleep_timer = 0,
        fade_alpha = 0,
        is_sleeping = false,
        is_fading = false,
        FADE_DURATION = 2,
        fade_timer = 0,
        fade_direction = "in"
    }
}

local shore_division = 60 -- what separates water from land (land is above this value)

-- ripple system
local ripples = {
    particles = {},
    maxParticles = 50,
    spawnTimer = 0,
    spawnRate = 0.5, -- seconds between spawns
    spawnMargin = 100 -- spawn ripples slightly outside view
}

-- port-a-shop configuration
local SHOP_SPACING = 1000  -- distance between shops
local SHOP_SIZE = { width = 60, height = 40 }  -- size of the shop platform
local INTERACTION_RANGE = 50  -- how close the player needs to be to interact

-- port-a-shops state
local port_a_shops = {}

-- shopkeeper
local shopkeeper = {
    x = 0,
    y = shore_division,
    size = 15,
    color = {1, 0.8, 0.2, 1}, -- golden color
    interaction_range = 50,    -- how close the ship needs to be to interact
    is_spawned = false,       -- whether the shopkeeper is currently spawned
    
    -- updates shopkeeper position
    update = function(self, ship_x, ship_y)
        -- keep shopkeeper at shore level
        self.y = shore_division
        
        -- check if shore is in view
        local viewTop = camera.y
        local viewHeight = love.graphics.getHeight() / camera.scale
        local isShoreVisible = viewTop <= shore_division and viewTop + viewHeight >= shore_division
        
        if isShoreVisible then
            -- if shore just came into view and shopkeeper isn't spawned, spawn near ship
            if not self.is_spawned then
                -- spawn slightly ahead of the ship in the direction it's moving
                local spawn_offset = player_ship.velocity_x > 0 and 200 or -200
                self.x = ship_x + spawn_offset
                self.is_spawned = true
            end
        else
            -- shore not visible, despawn shopkeeper
            self.is_spawned = false
        end
    end,
    
    -- draw the shopkeeper
    draw = function(self)
        -- only draw if spawned and in viewport
        if not self.is_spawned then return end
        
        local viewLeft = camera.x
        local viewWidth = love.graphics.getWidth() / camera.scale
        
        if self.x >= viewLeft - 50 and self.x <= viewLeft + viewWidth + 50 then
            -- draw body
            love.graphics.setColor(self.color)
            love.graphics.circle("fill", self.x, self.y, self.size)
            
            -- draw shop indicator if ship is in range
            local distance = math.sqrt((self.x - player_ship.x)^2 + (self.y - player_ship.y)^2)
            if distance <= self.interaction_range then
                -- draw "SHOP" text above shopkeeper
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("SHOP", self.x - 20, self.y - self.size * 2)
            end
        end
    end,
    
    -- check if ship can interact with shop
    can_interact = function(self)
        if not self.is_spawned then return false end
        local distance = math.sqrt((self.x - player_ship.x)^2 + (self.y - player_ship.y)^2)
        return distance <= self.interaction_range
    end
}

local function reset_game()
    -- delete save file
    love.filesystem.remove("save.lua")
    
    -- clear enemies
    spawnenemy.clear_enemies()
    
    -- reset player ship to initial state
    player_ship.x = 100
    player_ship.y = 100
    player_ship.men = 1
    player_ship.fainted_men = 0
    player_ship.velocity_x = 0
    player_ship.velocity_y = 0
    player_ship.rotation = 0
    player_ship.target_rotation = 0
    player_ship.rod = "Basic Rod"
    player_ship.sword = "Basic Sword"
    player_ship.caught_fish = {}
    player_ship.time_system.time = 0

    -- reset combat and defeat flash state
    gameState.combat.is_active = false
    gameState.combat.zoom_progress = 0
    gameState.combat.enemy = nil
    gameState.combat.result = nil
    gameState.combat.defeat_flash.active = false
    gameState.combat.defeat_flash.alpha = 0
    gameState.combat.defeat_flash.timer = 0

    -- reset camera
    camera.x = 0
    camera.y = 0
    camera.scale = 1

    -- reset shops
    shop.reset()
    shopkeeper.x = 0
    shopkeeper.y = shore_division
    shopkeeper.is_spawned = false
end

function ripples:spawn(x, y)
    if #self.particles >= self.maxParticles then return end
    
    -- Get viewport boundaries (in world coordinates)
    local viewLeft = camera.x
    local viewTop = camera.y
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    
    -- Generate position within and slightly outside viewport if not specified
    local ripple_x = x or (viewLeft - self.spawnMargin + math.random() * (viewWidth + 2 * self.spawnMargin))
    local ripple_y = y or (viewTop - self.spawnMargin + math.random() * (viewHeight + 2 * self.spawnMargin))
    
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
    local viewLeft = camera.x
    local viewTop = camera.y
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.radius = p.radius + p.speed * dt
        p.alpha = 1 - (p.radius / p.maxRadius)
        
        -- Remove particles that are either too big or outside viewport with margin
        if p.radius >= p.maxRadius or
           p.x < viewLeft - self.spawnMargin or
           p.x > viewLeft + viewWidth + self.spawnMargin or
           p.y < viewTop - self.spawnMargin or
           p.y > viewTop + viewHeight + self.spawnMargin then
            table.remove(self.particles, i)
        end
    end
end

function ripples:draw()
    -- Get viewport boundaries
    local viewLeft = camera.x
    local viewTop = camera.y
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    
    love.graphics.setLineWidth(2)
    for _, p in ipairs(self.particles) do
        -- Only draw ripples that are visible in viewport (with margin)
        if p.x >= viewLeft - self.spawnMargin and
           p.x <= viewLeft + viewWidth + self.spawnMargin and
           p.y >= viewTop - self.spawnMargin and
           p.y <= viewTop + viewHeight + self.spawnMargin then
            love.graphics.setColor(1, 1, 1, p.alpha * 0.3)
            love.graphics.circle("line", p.x, p.y, p.radius)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function player_ship:update(dt)
    -- Handle rotation
    local turning = false
    if love.keyboard.isDown("a") then
        self.target_rotation = self.target_rotation - self.turn_speed * dt
        turning = true
    end
    if love.keyboard.isDown("d") then
        self.target_rotation = self.target_rotation + self.turn_speed * dt
        turning = true
    end
    
    -- Smoothly interpolate current rotation towards target rotation
    local rotation_diff = self.target_rotation - self.rotation
    self.rotation = self.rotation + rotation_diff * 5 * dt
    
    -- Calculate forward direction based on rotation
    local forward_x = math.cos(self.rotation)
    local forward_y = math.sin(self.rotation)
    
    -- Handle acceleration
    local accelerating = false
    if love.keyboard.isDown("w") then
        -- Accelerate forward
        self.velocity_x = self.velocity_x + forward_x * self.acceleration * dt
        self.velocity_y = self.velocity_y + forward_y * self.acceleration * dt
        accelerating = true
    end
    if love.keyboard.isDown("s") then
        -- Brake/reverse with the configured multiplier
        self.velocity_x = self.velocity_x - forward_x * self.acceleration * self.reverse_multiplier * dt
        self.velocity_y = self.velocity_y - forward_y * self.acceleration * self.reverse_multiplier * dt
        accelerating = true
    end
    
    -- Apply turning speed penalty
    local speed_multiplier = turning and self.turn_penalty or 1
    
    -- Calculate current speed
    local current_speed = math.sqrt(self.velocity_x * self.velocity_x + self.velocity_y * self.velocity_y)
    
    -- Apply speed limit
    if current_speed > self.max_speed * speed_multiplier then
        local scale = (self.max_speed * speed_multiplier) / current_speed
        self.velocity_x = self.velocity_x * scale
        self.velocity_y = self.velocity_y * scale
    end
    
    -- Apply water resistance (deceleration) when not accelerating
    if not accelerating then
        self.velocity_x = self.velocity_x * (1 - self.deceleration * dt)
        self.velocity_y = self.velocity_y * (1 - self.deceleration * dt)
    end
    
    -- Update position
    local new_x = self.x + self.velocity_x * dt
    local new_y = self.y + self.velocity_y * dt
    
    -- Check shore boundary (keep 40 units away)
    local min_shore_distance = 40
    if new_y <= shore_division + min_shore_distance then
        -- Stop vertical movement at minimum distance from shore
        new_y = shore_division + min_shore_distance
        self.velocity_y = math.max(0, self.velocity_y) -- Only allow moving away from shore
        
        -- Add extra friction when near shore
        self.velocity_x = self.velocity_x * 0.98
    end
    
    -- Apply new position
    self.x = new_x
    self.y = new_y
end

-- Moves camera to a specific world coordinate
function camera:goto(x, y)
    self.x = x
    self.y = y
end

-- Zooms the camera, keeping the center stable
function camera:zoom(factor, target_x, target_y)
    local oldScale = self.scale
    self.scale = self.scale * factor

    -- If target coordinates provided, adjust position to keep that point centered
    if target_x and target_y then
        local screen_width = love.graphics.getWidth()
        local screen_height = love.graphics.getHeight()
        
        -- Calculate screen center
        local center_x = screen_width / 2
        local center_y = screen_height / 2
        
        -- Calculate the difference between target point and center in world coordinates
        local dx = (target_x * oldScale - center_x) / oldScale - (target_x * self.scale - center_x) / self.scale
        local dy = (target_y * oldScale - center_y) / oldScale - (target_y * self.scale - center_y) / self.scale
        
        self.x = self.x + dx
        self.y = self.y + dy
    else
        -- If no target, keep screen center stable (old behavior)
    local mx, my = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    local dx = mx / oldScale - mx / self.scale
    local dy = my / oldScale - my / self.scale

    self.x = self.x + dx
    self.y = self.y + dy
    end
end

-- Get saveable data (excluding functions)
function game.get_saveable_data()
    local data = {}
    for k, v in pairs(player_ship) do
        if type(v) ~= "function" then
            data[k] = v
        end
    end
    return data
end

function game.load()
    local saved_data = serialize.load_data()
    if saved_data then
        -- Only copy saved data properties, preserving methods
        for k, v in pairs(saved_data) do
            if type(player_ship[k]) ~= "function" then  -- Don't overwrite functions
                player_ship[k] = v
                if k == "name" then
                    print("Loaded ship name in game: " .. v)  -- Add debug print
                end
            end
        end
    else
        -- If no save data, get name from menu
        player_ship.name = menu.get_name()
        print("Setting initial ship name: " .. player_ship.name)  -- Add debug print
        serialize.save_data(game.get_saveable_data())
    end
end

-- Ship animation
local ship_animation = {
    scale = 1,
    target_scale = 1,
    animation_time = 0,
    get_duration = get_animation_duration  -- Function to get current duration
}

-- Catch text display system
local catch_texts = {}
local fishing_pressed = false
local fishing_cooldown = 0
local last_cooldown = game_config.fishing_cooldown  -- Track previous cooldown to detect when it reaches 0

function add_catch_text(text)
    -- Add new text at the beginning
    table.insert(catch_texts, 1, {
        text = text,
        time = game_config.fishing_cooldown,  -- Uses the current cooldown time
        y_offset = 0  -- Starting y offset
    })
    
    -- Remove oldest if we have too many
    if #catch_texts > get_max_catch_texts() then
        table.remove(catch_texts)
    end
    
    -- Update y offsets for all texts
    for i, catch in ipairs(catch_texts) do
        catch.y_offset = (i - 1) * game_config.catch_text_spacing
    end
end

function update_catch_texts(dt)
    for i = #catch_texts, 1, -1 do
        local catch = catch_texts[i]
        catch.time = catch.time - dt
        if catch.time <= 0 then
            table.remove(catch_texts, i)
            -- Update remaining text positions
            for j = i, #catch_texts do
                catch_texts[j].y_offset = (j - 1) * game_config.catch_text_spacing
            end
        end
    end
end

function update_ship_animation(dt)
    if ship_animation.animation_time > 0 then
        ship_animation.animation_time = math.max(0, ship_animation.animation_time - dt)
        local progress = ship_animation.animation_time / ship_animation.get_duration()
        -- Smooth interpolation between scales
        ship_animation.scale = 1 + (ship_animation.target_scale - 1) * progress
    end
end

function trigger_ship_animation()
    ship_animation.target_scale = 0.7  -- Shrink to 70% size
    ship_animation.scale = 1
    ship_animation.animation_time = ship_animation.get_duration()
end

function fish(dt)
    -- Track if F was just pressed (not held)
    local fishing_released = love.keyboard.isDown("f") and not fishing_pressed
    fishing_pressed = love.keyboard.isDown("f")

    -- Store previous cooldown for transition detection
    local prev_cooldown = fishing_cooldown
    
    -- Update cooldown
    fishing_cooldown = math.max(0, fishing_cooldown - dt)
    
    -- Detect when cooldown just reached 0
    if prev_cooldown > 0 and fishing_cooldown <= 0 then
        -- Crew fishing
        local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y)
        trigger_ship_animation()  -- Trigger animation for crew fishing
        for i = 1, player_ship.men do
            local fish_caught = fishing.fish(fishing.get_rod_rarity(player_ship.rod), fishing.get_rod_top_rarity(), fish_available)
            add_catch_text("Crew " .. i .. ": " .. fish_caught)
            table.insert(player_ship.caught_fish, fish_caught)  -- Store in player_ship
            print("Crew member " .. i .. " caught: " .. fish_caught)
        end
    end

    -- Player-initiated fishing
    if fishing_released and fishing_cooldown <= 0 then
        local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y)
        local fish_caught = fishing.fish(fishing.get_rod_rarity(player_ship.rod), fishing.get_rod_top_rarity(), fish_available)
        add_catch_text("You: " .. fish_caught)
        table.insert(player_ship.caught_fish, fish_caught)  -- Store in player_ship
        print("You caught: " .. fish_caught)
        trigger_ship_animation()  -- Trigger animation for player fishing
        
        -- Reset cooldown using current config value
        fishing_cooldown = game_config.fishing_cooldown
    end
end

-- Linear interpolation helper function
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Water colors for different times of day
local waterColors = {
    dawn = {0.4, 0.3, 0.3},    -- Subtle orange-blue mix for sunrise (0:00)
    day = {0.04, 0.04, 0.2},   -- Bright blue (6:00)
    dusk = {0.3, 0.2, 0.3},    -- Purple-blue for evening (11:00)
    night = {0.02, 0.02, 0.1}  -- Dark blue for night (12:00)
}

-- Function to get current water color based on time
local function getCurrentWaterColor()
    local timeOfDay = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12 -- Convert to 12-hour format
    
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

-- Function to handle sleep state
local function during_sleep()
    -- Check if near any shop (port-a-shop or shopkeeper)
    local near_shop = false
    
    -- Check port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            local distance = math.sqrt((shop_data.x - player_ship.x)^2 + (shop_data.y - player_ship.y)^2)
            if distance <= 50 then
                near_shop = true
                break
            end
        end
    end
    
    -- Check main shopkeeper if not already near a port-a-shop
    if not near_shop and shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact() then
        near_shop = true
    end
    
    -- If near a shop, heal fainted crew members
    if near_shop and player_ship.fainted_men > 0 then
        print("Healing " .. player_ship.fainted_men .. " fainted crew members...")
        player_ship.men = player_ship.men + player_ship.fainted_men
        player_ship.fainted_men = 0
        print("All crew members healed!")
    end

    -- Save data
    player_ship.name = menu.get_name()
    serialize.save_data(game.get_saveable_data())
end

function game.toggleDebug()
    debugOptions.showDebugButtons = not debugOptions.showDebugButtons
    print("Debug mode: " .. (debugOptions.showDebugButtons and "ON" or "OFF"))
end

function game.update(dt)
    -- Update day-night cycle - only if not in combat
    if not gameState.combat.is_active then
        if not player_ship.time_system.is_sleeping then
            player_ship.time_system.time = player_ship.time_system.time + dt
            
            -- Check if we've reached the end of the day (12 minutes)
            if player_ship.time_system.time >= player_ship.time_system.DAY_LENGTH then
                player_ship.time_system.time = 0
                player_ship.time_system.is_fading = true
                player_ship.time_system.fade_timer = 0
                player_ship.time_system.fade_direction = "out"
                print("Starting night transition...")
            end
        end
    end
    
    -- Handle fading and sleep state - only if not in combat
    if not gameState.combat.is_active then
        if player_ship.time_system.is_fading then
            player_ship.time_system.fade_timer = player_ship.time_system.fade_timer + dt
            
            if player_ship.time_system.fade_direction == "out" then
                -- Fading to black
                player_ship.time_system.fade_alpha = math.min(1, player_ship.time_system.fade_timer / player_ship.time_system.FADE_DURATION)
                
                if player_ship.time_system.fade_timer >= player_ship.time_system.FADE_DURATION then
                    -- Start sleep
                    player_ship.time_system.is_sleeping = true
                    player_ship.time_system.sleep_timer = 0
                    player_ship.time_system.fade_direction = "wait"
                    player_ship.time_system.fade_timer = 0  -- Reset timer for next phase
                    during_sleep()
                end
            elseif player_ship.time_system.fade_direction == "wait" then
                -- During sleep
                player_ship.time_system.sleep_timer = player_ship.time_system.sleep_timer + dt
                if player_ship.time_system.sleep_timer >= player_ship.time_system.SLEEP_DURATION then
                    -- Start waking up
                    player_ship.time_system.fade_direction = "in"
                    player_ship.time_system.fade_timer = 0  -- Reset timer for fade in
                end
            elseif player_ship.time_system.fade_direction == "in" then
                -- Fading back in
                player_ship.time_system.fade_alpha = math.max(0, 1 - (player_ship.time_system.fade_timer / player_ship.time_system.FADE_DURATION))
                
                if player_ship.time_system.fade_timer >= player_ship.time_system.FADE_DURATION then
                    -- Finish waking up
                    player_ship.time_system.is_fading = false
                    player_ship.time_system.is_sleeping = false
                    player_ship.time_system.fade_alpha = 0
                end
            end
        end
    end

    if suit.Button("Back to Menu", {id = "menu"}, suit.layout:row(120, 30)).hit then
        player_ship.name = menu.get_name()
        print("Saving ship name on menu return: " .. player_ship.name)  -- Add debug print
        local data = game.get_saveable_data()
        print("Save data contains name: " .. (data.name or "NO NAME"))  -- Add debug print
        serialize.save_data(data)
        return "menu"
    end

    -- Only update game elements if not sleeping and not in combat
    if not player_ship.time_system.is_sleeping and not gameState.combat.is_active then
        -- Update ship
        player_ship:update(dt)
        
        -- Update ship animation
        update_ship_animation(dt)
        
        -- Update catch texts
        update_catch_texts(dt)
        
        -- Update shopkeeper position
        shopkeeper:update(player_ship.x, player_ship.y)
        
        -- Update shop
        local new_state = shop.update(gameState, player_ship, shopkeeper)
        if new_state then
            return new_state
        end

        -- Update enemy spawning and movement
        spawnenemy.update(dt, camera, player_ship.x, player_ship.y)

        -- Check for collision with enemies
        local collided_enemy = spawnenemy.check_collision(player_ship.x, player_ship.y, player_ship.radius)
        if collided_enemy then
            -- Clear any fishing text displays
            catch_texts = {}
            fishing_cooldown = 0
            
            -- Start combat
            gameState.combat.is_active = true
            gameState.combat.zoom_progress = 0
            gameState.combat.enemy = collided_enemy
            gameState.combat.result = nil
            gameState.combat.is_fully_zoomed = false
            gameState.combat.result_display_time = 3.0  -- Reset display time
        end

        -- Some Mechs
        fish(dt)

        ripples:update(dt)
    end
    
    -- Handle combat state
    if gameState.combat.is_active then
        -- Update zoom animation
        gameState.combat.zoom_progress = math.min(1, gameState.combat.zoom_progress + dt / gameState.combat.zoom_duration)
        local zoom_factor = 1 + (gameState.combat.target_zoom - 1) * gameState.combat.zoom_progress
        
        -- Calculate center point between player and enemy
        local center_x = (player_ship.x + gameState.combat.enemy.x) / 2
        local center_y = (player_ship.y + gameState.combat.enemy.y) / 2
        
        -- Apply zoom with target point
        camera:zoom(zoom_factor / camera.scale, center_x, center_y)
        
        -- Check if zoom is complete
        if gameState.combat.zoom_progress >= 1 then
            if not gameState.combat.is_fully_zoomed then
                gameState.combat.is_fully_zoomed = true
                
                -- Process combat only when zoom is complete
                local enemy = gameState.combat.enemy
                local result = combat.combat(player_ship.men, enemy.size, 
                    combat.get_sword_level(player_ship.sword),
                    combat.get_sword_top_rarity())

                -- Apply combat results
                if result.victory then
                    player_ship.men = player_ship.men - result.casualties
                    player_ship.fainted_men = player_ship.fainted_men + result.fainted
                    gameState.combat.result = result
                    gameState.combat.result_display_time = 3.0  -- Reset display time for victory
                else
                    -- Defeat handling
                    gameState.combat.result = result
                    gameState.combat.defeat_flash.active = true
                    gameState.combat.defeat_flash.alpha = 0
                    gameState.combat.defeat_flash.timer = 0
                end
            end
        end

        -- Update result display timer and handle defeat
        if gameState.combat.result then
            if gameState.combat.result.victory then
                -- Normal victory handling
                if gameState.combat.result_display_time > 0 then  -- Only count down if time remains
                    gameState.combat.result_display_time = gameState.combat.result_display_time - dt
                    if gameState.combat.result_display_time <= 0 then
                        -- Remove the enemy and end combat
                        spawnenemy.remove_enemy(gameState.combat.enemy)
                        gameState.combat.is_active = false
                        gameState.combat.zoom_progress = 0
                        gameState.combat.is_fully_zoomed = false
                        gameState.combat.result = nil
                        camera.scale = 1
                    end
                end
            else
                -- Defeat flash handling
                if gameState.combat.defeat_flash.active then
                    gameState.combat.defeat_flash.timer = gameState.combat.defeat_flash.timer + dt
                    
                    -- Show text for text_display_time seconds before starting flash
                    if gameState.combat.defeat_flash.timer >= gameState.combat.defeat_flash.text_display_time then
                        -- Calculate flash alpha only after text display time
                        local flash_time = gameState.combat.defeat_flash.timer - gameState.combat.defeat_flash.text_display_time
                        gameState.combat.defeat_flash.alpha = math.min(1, flash_time / gameState.combat.defeat_flash.duration)
                        
                        -- When fully white, reset game
                        if gameState.combat.defeat_flash.alpha >= 1 then
                            reset_game()
                            return "menu"
                        end
                    end
                end
            end
        end
    end
    
    -- Always update camera to follow ship or combat center
    if gameState.combat.is_active then
        -- During combat, camera should focus on the center point between player and enemy
        local center_x = (player_ship.x + gameState.combat.enemy.x) / 2
        local center_y = (player_ship.y + gameState.combat.enemy.y) / 2
        
        -- Adjust for screen center
        camera:goto(
            center_x - love.graphics.getWidth()/(2 * camera.scale),
            center_y - love.graphics.getHeight()/(2 * camera.scale)
        )
    else
        -- Normal camera following during gameplay
        camera:goto(
            player_ship.x - love.graphics.getWidth()/2,
            player_ship.y - love.graphics.getHeight()/2
        )
    end
    
    return nil
end

function game.draw()
    -- Get current water color based on time of day
    local waterColor = getCurrentWaterColor()
    love.graphics.clear(waterColor[1], waterColor[2], waterColor[3])

    love.graphics.push()
    love.graphics.translate(-camera.x * camera.scale, -camera.y * camera.scale)
    love.graphics.scale(camera.scale)

    -- Draw ripples first as background effect
    ripples:draw()
    
    -- Only draw game world if not sleeping
    if not player_ship.time_system.is_sleeping then
        -- Draw the shore
        -- Calculate shore dimensions based on camera view
        local viewWidth = love.graphics.getWidth() / camera.scale
        local viewHeight = love.graphics.getHeight() / camera.scale
        local shoreExtension = 1000 -- How far the shore extends beyond the viewport
        
        -- Draw sand-colored rectangle for shore area
        love.graphics.setColor(0.87, 0.84, 0.69) -- Warm sand color
        love.graphics.rectangle("fill",
            camera.x - shoreExtension,  -- Left edge (extend past viewport)
            -1000,  -- Extend well above viewport
            viewWidth + shoreExtension * 2,  -- Width (extend both directions)
            shore_division + 1000  -- Height (include the extension)
        )
        
        -- Draw shore edge line
        love.graphics.setColor(0.3, 0.3, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.line(
            camera.x - shoreExtension, shore_division,
            camera.x + viewWidth + shoreExtension, shore_division
        )
        
        -- Draw the shopkeeper
        shopkeeper:draw()

        -- Draw enemy ships
        if not gameState.combat.is_active then
            -- Draw all enemies normally when not in combat
            spawnenemy.draw()
        else
            -- During combat, only draw the enemy we're fighting
            if gameState.combat.enemy then
                love.graphics.setColor(1, 0, 0, 1)
                
                -- Save current transform
                love.graphics.push()
                
                -- Move to enemy position and rotate based on direction
                love.graphics.translate(gameState.combat.enemy.x, gameState.combat.enemy.y)
                love.graphics.rotate(gameState.combat.enemy.direction > 0 and 0 or math.pi)  -- rotate if moving left
                
                -- Draw triangle
                love.graphics.polygon("fill",
                    gameState.combat.enemy.radius, 0,  -- front
                    -gameState.combat.enemy.radius, -gameState.combat.enemy.radius/2,  -- back left
                    -gameState.combat.enemy.radius, gameState.combat.enemy.radius/2    -- back right
                )
                
                -- Restore transform before drawing text
                love.graphics.pop()
                
                -- Draw crew size text (always upright)
                love.graphics.setColor(1, 1, 1, 1)
                local text = tostring(gameState.combat.enemy.size)
                local font = love.graphics.getFont()
                local text_width = font:getWidth(text)
                love.graphics.print(text, 
                    gameState.combat.enemy.x - text_width/2,
                    gameState.combat.enemy.y - font:getHeight()/2)
            end
        end
        
        -- Draw the ship with animation scale
        love.graphics.push()
        love.graphics.translate(player_ship.x, player_ship.y)
        love.graphics.rotate(player_ship.rotation)
        love.graphics.scale(ship_animation.scale, ship_animation.scale)
        
        -- Draw ship triangle
        love.graphics.setColor(player_ship.color)
        love.graphics.polygon("fill", 
            player_ship.radius, 0,
            -player_ship.radius, -player_ship.radius/2,
            -player_ship.radius, player_ship.radius/2
        )
        
        -- Draw ship name below the ship
        love.graphics.push()
        love.graphics.scale(1/ship_animation.scale, 1/ship_animation.scale)  -- Counter the ship animation scale
        love.graphics.rotate(-player_ship.rotation)  -- Counter the ship rotation
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(player_ship.name)
        love.graphics.print(player_ship.name, 
            -text_width/2,  -- Center horizontally
            player_ship.radius * 1.5 * ship_animation.scale)  -- Position below ship
        love.graphics.pop()
        
        love.graphics.pop()

        -- Draw combat result text at top of screen
        if gameState.combat.is_active and gameState.combat.result then
            -- Draw combat result
            love.graphics.setColor(1, 1, 1, 1)
            local result_text
            if gameState.combat.result.victory then
                if gameState.combat.result.farming_penalty then
                    result_text = {
                        "Overwhelming Victory!",
                        "Your crew got careless...",
                        string.format("Lost %d men to friendly fire!", gameState.combat.result.casualties)
                    }
                else
                    result_text = {
                        "Victory!",
                        string.format("Lost: %d crew", gameState.combat.result.casualties),
                        string.format("Fainted: %d crew", gameState.combat.result.fainted)
                    }
                end
            else
                -- Only show defeat text before the flash starts
                if gameState.combat.defeat_flash.timer < gameState.combat.defeat_flash.text_display_time then
                    result_text = {
                        "Defeat!",
                        string.format("Lost all %d crew member(s)!", player_ship.men)
                    }
                end
            end
            
            -- Draw centered on screen with larger font
            if result_text then
                local font = love.graphics.getFont()
                local scale = 2.0  -- Make text larger
                
                -- Calculate screen center
                local screen_center_x = love.graphics.getWidth() / 2
                local screen_center_y = love.graphics.getHeight() / 2
                
                -- Convert to world coordinates
                local world_x = screen_center_x / camera.scale + camera.x
                local world_y = screen_center_y / camera.scale + camera.y
                
                -- Calculate dimensions for all lines
                local max_width = 0
                local total_height = 0
                for _, line in ipairs(result_text) do
                    local width = font:getWidth(line)
                    max_width = math.max(max_width, width)
                    total_height = (total_height + font:getHeight()) * 2
                end
                
                -- Add padding for the background
                local padding = 20 / scale  -- 20 pixels padding, adjusted for scale
                
                -- Draw semi-transparent black background
                love.graphics.setColor(0, 0, 0, 0.7)  -- 70% opacity black
                love.graphics.push()
                love.graphics.scale(scale, scale)
                love.graphics.rectangle("fill",
                    (world_x - (max_width * scale / 2)) / scale - padding,
                    (world_y - (total_height * scale / 2)) / scale - padding,
                    max_width + padding * 2,
                    total_height + padding * 2,
                    10 / scale  -- Rounded corners, adjusted for scale
                )
                love.graphics.pop()
                
                -- Draw text
                love.graphics.push()
                love.graphics.scale(scale, scale)
                
                -- Start Y position (centered vertically)
                local y_pos = (world_y - (total_height * scale / 2)) / scale
                
                -- Draw each line centered
                for i, line in ipairs(result_text) do
                    local width = font:getWidth(line)
                    local x_pos = (world_x - (width * scale / 2)) / scale
                    
                    -- Make title (first line) bigger
                    if i == 1 then
                        love.graphics.push()
                        love.graphics.scale(1.5, 1.5)  -- 50% bigger than the rest
                        x_pos = (world_x - (width * scale * 1.5 / 2)) / (scale * 1.5)
                        y_pos = (world_y - (total_height * scale / 2)) / (scale * 1.5)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(line, x_pos, y_pos)
                        love.graphics.pop()
                        y_pos = y_pos * 1.5 + font:getHeight() * 2  -- Add extra spacing after title
                    else
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(line, x_pos, y_pos)
                        y_pos = y_pos + font:getHeight()
                    end
                end
                
                love.graphics.pop()
            end
        end
        
        -- Draw catch texts
        for _, catch in ipairs(catch_texts) do
            local alpha = catch.time / game_config.fishing_cooldown  -- Fade out over time
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.print(catch.text, 
                player_ship.x - 40, 
                player_ship.y - 60 - catch.y_offset)
        end
        
        -- Draw fishing cooldown indicator if on cooldown
        if fishing_cooldown > 0 then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.print(string.format("Fishing: %.1fs", fishing_cooldown), 
                player_ship.x - 30, 
                player_ship.y - 40)
        else
            -- Show "Crew Fishing!" briefly when crew is about to fish
            if fishing_cooldown == 0 and last_cooldown > 0 then
                love.graphics.setColor(1, 1, 0.5, 0.8)  -- Yellowish color
                love.graphics.print("Crew Fishing!", 
                    player_ship.x - 30, 
                    player_ship.y - 40)
            end
        end
        
        -- Update last cooldown for next frame
        last_cooldown = fishing_cooldown
        
        shop.draw_shops(camera)
    end

    love.graphics.pop()

    -- Draw shop UI on top of everything if not sleeping
    if not player_ship.time_system.is_sleeping then
        shop.draw_ui()
    end

    -- Draw day/night fade overlay
    if player_ship.time_system.is_fading or player_ship.time_system.fade_alpha > 0 then
        love.graphics.setColor(0, 0, 0, player_ship.time_system.fade_alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        -- Draw sleep message when fully black
        if player_ship.time_system.is_sleeping and player_ship.time_system.fade_alpha > 0.9 then
            love.graphics.setColor(1, 1, 1, 1)
            local sleep_text = "Sleeping..."
            local font = love.graphics.getFont()
            local text_width = font:getWidth(sleep_text)
            love.graphics.print(sleep_text, 
                (love.graphics.getWidth() - text_width) / 2,
                love.graphics.getHeight() / 2)
        end
    end

    -- Draw time of day
    love.graphics.setColor(1, 1, 1, 1)
    local timeOfDay = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12  -- Convert to 12-hour format
    local hours = math.floor(timeOfDay)
    local minutes = math.floor((timeOfDay - hours) * 60)
    -- Ensure we don't display past 12:00
    if hours >= 12 then
        hours = 12
        minutes = 0
    end
    love.graphics.print(string.format("Time: %02d:%02d", hours, minutes), 10, 10)

    -- Draw debug buttons if enabled and not sleeping
    if debugOptions.showDebugButtons and not player_ship.time_system.is_sleeping then
        -- Reset layout for debug buttons
        suit.layout:reset(10, 40)
        suit.layout:padding(10)

        -- Add 100 fish button
        if suit.Button("Add 100 Fish", suit.layout:row(100, 30)).hit then
            for i = 1, 100 do
                local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y)
                local fish_caught = fishing.fish(fishing.get_rod_rarity(player_ship.rod), fishing.get_rod_top_rarity(), fish_available)
                table.insert(player_ship.caught_fish, fish_caught)
            end
            print("Added 100 fish!")
        end

        -- Skip 1 minute button
        if suit.Button("Skip 1 Min", suit.layout:row(100, 30)).hit then
            local old_time = player_ship.time_system.time
            player_ship.time_system.time = player_ship.time_system.time + 60  -- Add 60 seconds
            
            -- Check if we've passed the day length threshold
            if old_time < player_ship.time_system.DAY_LENGTH and player_ship.time_system.time >= player_ship.time_system.DAY_LENGTH then
                -- Reset time and start sleep sequence properly
                player_ship.time_system.time = 0
                player_ship.time_system.is_fading = true
                player_ship.time_system.fade_timer = 0
                player_ship.time_system.fade_direction = "out"
                player_ship.time_system.fade_alpha = 0
                player_ship.time_system.is_sleeping = false
                print("Skipped to night time!")
            else
                print("Skipped 1 minute!")
            end
        end

        -- Toggle fishing cooldown button
        if suit.Button("Toggle Cooldown (5s/2s)", suit.layout:row(150, 30)).hit then
            game_config.fishing_cooldown = game_config.fishing_cooldown == 5 and 2 or 5
            print("Fishing cooldown set to: " .. game_config.fishing_cooldown .. "s")
        end

        if suit.Button("Display Position", suit.layout:row(100, 30)).hit then
            print("Player Position: " .. player_ship.x .. ", " .. player_ship.y)
        end
        -- Show debug status
        love.graphics.print("Debug Mode (F3 to toggle)", 10, 100)
    end

    -- Draw white flash overlay for defeat
    if gameState.combat.defeat_flash and gameState.combat.defeat_flash.active then
        love.graphics.setColor(1, 1, 1, gameState.combat.defeat_flash.alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)

    -- not zoomed in viewport
    suit.draw()
end

-- Make player_ship accessible to other modules
game.player_ship = player_ship

return game