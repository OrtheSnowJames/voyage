-- game.lua

local game = {}
local suit = require "SUIT"
local fishing = require("game.fishing")
local serialize = require("game.serialize")
local combat = require("game.combat")
local shop = require("shop")
local spawnenemy = require("game.spawnenemy")
local menu = require("menu")  -- add menu requirement to get ship name

-- game configuration (modifiable during runtime)
local game_config = {
    fishing_cooldown = 5,  -- base cooldown time in seconds
    catch_text_spacing = 20,  -- vertical spacing between texts
}

-- special fish event state
local special_fish_event = {
    active = false,
    timer = 0,
    duration = 5.0,  -- show message for 5 seconds
    fish_name = "",
    caught_gold_sturgeon = false  -- track if gold sturgeon was caught tonight
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
            text_display_time = 2.0  -- show defeat text for 2 seconds before flash
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
    
    -- movement configuration
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
    inventory = {},
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
    },
    
    -- ship sprite
    sprite = love.graphics.newImage("assets/boat.png")
}

local shore_division = 60 -- what separates water from land (land is above this value)

-- load shore texture
local shore_texture = love.graphics.newImage("assets/shore.png")
local shore_width = shore_texture:getWidth()
local shore_height = shore_texture:getHeight()

-- ripple system
local ripples = {
    particles = {},
    maxParticles = 50,
    spawnTimer = 0,
    baseSpawnRate = 0.3, -- base seconds between spawns
    spawnMargin = 100, -- spawn ripples slightly outside view
    minVisibleRipples = 5 -- minimum ripples to keep on screen
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
    y = shore_division - 16, -- position on shore visually (half sprite height)
    size = 15,
    color = {1, 0.8, 0.2, 1}, -- golden color
    interaction_range = 70,    -- increased from 50 to allow interaction from the water
    is_spawned = false,       -- whether the shopkeeper is currently spawned
    
    -- animation properties
    sprite = love.graphics.newImage("assets/shopkeeper.png"),
    frame_width = 32,
    frame_height = 32,
    frame_time = 0.5, -- 500ms per frame
    current_frame = 1,
    total_frames = 2,
    timer = 0,
    
    -- updates shopkeeper position
    update = function(self, ship_x, ship_y, dt)
        -- keep shopkeeper at shore level (visually on the shore)
        self.y = shore_division - 16
        
        -- update animation
        self.timer = self.timer + dt
        if self.timer >= self.frame_time then
            self.timer = self.timer - self.frame_time
            self.current_frame = self.current_frame % self.total_frames + 1
        end
        
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
            -- create quad for the current frame
            local quad = love.graphics.newQuad(
                (self.current_frame - 1) * self.frame_width, 
                0, 
                self.frame_width, 
                self.frame_height, 
                self.sprite:getWidth(), 
                self.sprite:getHeight()
            )
            
            -- check if player is in range (for yellow color)
            local distance = math.sqrt((self.x - player_ship.x)^2 + (self.y - player_ship.y)^2)
            local in_range = distance <= self.interaction_range
            
            -- set color based on interaction range
            if in_range then
                -- yellow tint when in range (replace white with yellow)
                love.graphics.setColor(1, 1, 0)
            else
                -- normal coloring
                love.graphics.setColor(1, 1, 1)
            end
            
            -- draw the sprite
            love.graphics.draw(
                self.sprite, 
                quad, 
                self.x, 
                self.y, 
                0, -- rotation
                1, -- scale x
                1, -- scale y
                self.frame_width/2, -- origin x (center)
                self.frame_height/2 -- origin y (center)
            )
            
            -- reset color
            love.graphics.setColor(1, 1, 1, 1)
            
            -- draw shop indicator if ship is in range
            if in_range then
                -- draw "shop" text above shopkeeper
                love.graphics.print("SHOP", self.x - 20, self.y - self.frame_height)
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
    player_ship.inventory = {}
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
    shopkeeper.y = shore_division - 16
    shopkeeper.is_spawned = false

    -- reset special fish event
    special_fish_event.active = false
    special_fish_event.timer = 0
    special_fish_event.fish_name = ""
    special_fish_event.caught_gold_sturgeon = false
end

function ripples:spawn(player_ship, x, y)
    if #self.particles >= self.maxParticles then return end
    
    -- get viewport boundaries (in world coordinates)
    local viewLeft = camera.x
    local viewTop = camera.y
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    
    -- default spawn position and movement
    local ripple_x = x or (viewLeft + math.random() * viewWidth)
    local ripple_y = y or (viewTop + viewHeight + self.spawnMargin)
    local ripple_vy = -love.math.random(20, 40)  -- default: move toward shore (upward)
    
    -- if player_ship is provided, make spawning direction-aware
    if player_ship and not x and not y then
        -- calculate player movement direction
        local player_speed = math.sqrt(player_ship.velocity_x^2 + player_ship.velocity_y^2)
        
        -- determine if player is moving toward or away from shore
        local moving_toward_shore = player_ship.velocity_y < -10  -- moving upward significantly
        local moving_away_from_shore = player_ship.velocity_y > 10  -- moving downward significantly
        
        if moving_toward_shore then
            -- player moving toward shore: spawn ripples ahead (above viewport)
            ripple_y = viewTop - self.spawnMargin
            ripple_vy = -love.math.random(20, 40)  -- still move toward shore
        elseif moving_away_from_shore then
            -- player moving away from shore: spawn ripples ahead (below viewport)  
            ripple_y = viewTop + viewHeight + self.spawnMargin
            ripple_vy = -love.math.random(20, 40)  -- still move toward shore
        else
            -- player not moving much vertically: spawn randomly above or below
            if math.random() < 0.5 then
                ripple_y = viewTop - self.spawnMargin  -- above
            else
                ripple_y = viewTop + viewHeight + self.spawnMargin  -- below
            end
            ripple_vy = -love.math.random(20, 40)
        end
        
        -- if player is moving fast, spawn ripples more around the player's area
        if player_speed > 50 then
            -- spawn in a wider area around the player's x position
            local spawn_range = math.min(viewWidth, 400) -- limit spawn range
            ripple_x = player_ship.x + (math.random() - 0.5) * spawn_range
        end
    end
    
    -- spawn 3 ripples: center, left, and right
    local spacing = 50 + math.random() * 100  -- 50-150 units apart
    local positions = {
        {x = ripple_x - spacing, y = ripple_y},  -- left
        {x = ripple_x, y = ripple_y},            -- center (original)
        {x = ripple_x + spacing, y = ripple_y}   -- right
    }
    
    for _, pos in ipairs(positions) do
        if #self.particles < self.maxParticles then
            table.insert(self.particles, {
                x = pos.x,
                y = pos.y,
                vy = ripple_vy + love.math.random(-5, 5),  -- slight variation in speed
                size = love.math.random(3, 6),
                alpha = 1,
                maxLife = love.math.random(3, 6),
                life = 0
            })
        end
    end
end

function ripples:update(dt, player_ship)
    -- calculate player speed
    local player_speed = math.sqrt(player_ship.velocity_x^2 + player_ship.velocity_y^2)
    
    -- adjust spawn rate based on speed (faster player = faster spawning)
    local speed_multiplier = 1 + (player_speed / 100) -- faster spawning when moving faster
    local current_spawn_rate = self.baseSpawnRate / speed_multiplier
    
    -- get viewport boundaries
    local viewLeft = camera.x
    local viewTop = camera.y
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    
    -- count visible ripples (ripples currently on screen)
    local visible_ripples = 0
    for _, p in ipairs(self.particles) do
        if p.x >= viewLeft - self.spawnMargin and
           p.x <= viewLeft + viewWidth + self.spawnMargin and
           p.y >= viewTop - self.spawnMargin and
           p.y <= viewTop + viewHeight + self.spawnMargin then
            visible_ripples = visible_ripples + 1
        end
    end
    
    -- regular spawning based on timer
    self.spawnTimer = self.spawnTimer + dt
    if self.spawnTimer >= current_spawn_rate then
        self:spawn(player_ship)
        self.spawnTimer = 0
    end
    
    -- "catch up" spawning - if we have fewer than minimum visible ripples, spawn more immediately
    if visible_ripples < self.minVisibleRipples then
        local needed_ripples = self.minVisibleRipples - visible_ripples
        for i = 1, needed_ripples do
            self:spawn(player_ship)
        end
    end
    
    -- update existing ripples
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        
        -- move toward shore (upward)
        p.y = p.y + p.vy * dt
        
        -- update lifetime and alpha
        p.life = p.life + dt
        p.alpha = 1 - (p.life / p.maxLife)
        
        -- remove particles that are too old or completely out of view
        if p.life >= p.maxLife or
           p.x < viewLeft - self.spawnMargin or
           p.x > viewLeft + viewWidth + self.spawnMargin or
           p.y < viewTop - self.spawnMargin * 2 then  -- let them go well past the top
            table.remove(self.particles, i)
        end
    end
end

function ripples:draw()
    -- get viewport boundaries
    local viewLeft = camera.x
    local viewTop = camera.y
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    
    love.graphics.setLineWidth(1)
    for _, p in ipairs(self.particles) do
        -- only draw ripples that are visible in viewport (with margin)
        if p.x >= viewLeft - self.spawnMargin and
           p.x <= viewLeft + viewWidth + self.spawnMargin and
           p.y >= viewTop - self.spawnMargin and
           p.y <= viewTop + viewHeight + self.spawnMargin then
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
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function player_ship:update(dt)
    -- handle rotation
    local turning = false
    if love.keyboard.isDown("a") then
        self.target_rotation = self.target_rotation - self.turn_speed * dt
        turning = true
    end
    if love.keyboard.isDown("d") then
        self.target_rotation = self.target_rotation + self.turn_speed * dt
        turning = true
    end
    
    -- smoothly interpolate current rotation towards target rotation
    local rotation_diff = self.target_rotation - self.rotation
    self.rotation = self.rotation + rotation_diff * 5 * dt
    
    -- calculate forward direction based on rotation
    local forward_x = math.cos(self.rotation)
    local forward_y = math.sin(self.rotation)
    
    -- handle acceleration
    local accelerating = false
    if love.keyboard.isDown("w") then
        -- accelerate forward
        self.velocity_x = self.velocity_x + forward_x * self.acceleration * dt
        self.velocity_y = self.velocity_y + forward_y * self.acceleration * dt
        accelerating = true
    end
    if love.keyboard.isDown("s") then
        -- brake/reverse with the configured multiplier
        self.velocity_x = self.velocity_x - forward_x * self.acceleration * self.reverse_multiplier * dt
        self.velocity_y = self.velocity_y - forward_y * self.acceleration * self.reverse_multiplier * dt
        accelerating = true
    end
    
    -- apply turning speed penalty
    local speed_multiplier = turning and self.turn_penalty or 1
    
    -- calculate current speed
    local current_speed = math.sqrt(self.velocity_x * self.velocity_x + self.velocity_y * self.velocity_y)
    
    -- apply speed limit
    if current_speed > self.max_speed * speed_multiplier then
        local scale = (self.max_speed * speed_multiplier) / current_speed
        self.velocity_x = self.velocity_x * scale
        self.velocity_y = self.velocity_y * scale
    end
    
    -- apply water resistance (deceleration) when not accelerating
    if not accelerating then
        self.velocity_x = self.velocity_x * (1 - self.deceleration * dt)
        self.velocity_y = self.velocity_y * (1 - self.deceleration * dt)
    end
    
    -- update position
    local new_x = self.x + self.velocity_x * dt
    local new_y = self.y + self.velocity_y * dt
    
    -- check shore boundary (keep 40 units away)
    local min_shore_distance = 40
    if new_y <= shore_division + min_shore_distance then
        -- stop vertical movement at minimum distance from shore
        new_y = shore_division + min_shore_distance
        self.velocity_y = math.max(0, self.velocity_y) -- only allow moving away from shore
        
        -- add extra friction when near shore
        self.velocity_x = self.velocity_x * 0.98
    end
    
    -- apply new position
    self.x = new_x
    self.y = new_y
end

-- moves camera to a specific world coordinate
function camera:goto(x, y)
    self.x = x
    self.y = y
end

-- zooms the camera, keeping the center stable
function camera:zoom(factor, target_x, target_y)
    local oldScale = self.scale
    self.scale = self.scale * factor

    -- if target coordinates provided, adjust position to keep that point centered
    if target_x and target_y then
        local screen_width = love.graphics.getWidth()
        local screen_height = love.graphics.getHeight()
        
        -- calculate screen center
        local center_x = screen_width / 2
        local center_y = screen_height / 2
        
        -- calculate the difference between target point and center in world coordinates
        local dx = (target_x * oldScale - center_x) / oldScale - (target_x * self.scale - center_x) / self.scale
        local dy = (target_y * oldScale - center_y) / oldScale - (target_y * self.scale - center_y) / self.scale
        
        self.x = self.x + dx
        self.y = self.y + dy
    else
        -- if no target, keep screen center stable (old behavior)
    local mx, my = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    local dx = mx / oldScale - mx / self.scale
    local dy = my / oldScale - my / self.scale

    self.x = self.x + dx
    self.y = self.y + dy
    end
end

-- get saveable data (excluding functions)
function game.get_saveable_data()
    local data = {}
    for k, v in pairs(player_ship) do
        if type(v) ~= "function" then
            data[k] = v
        end
    end
    -- add shop data
    data.shop_data = shop.get_port_a_shops_data()
    return data
end

function game.load()
    local saved_data = serialize.load_data()
    if saved_data then
        -- only copy saved data properties, preserving methods
        for k, v in pairs(saved_data) do
            if k == "shop_data" then
                -- load shop data separately
                shop.set_port_a_shops_data(v)
            elseif type(player_ship[k]) ~= "function" then  -- don't overwrite functions
                player_ship[k] = v
            end
        end
    else
        -- if no save data, get name from menu
        player_ship.name = menu.get_name()
        serialize.save_data(game.get_saveable_data())
    end
end

-- ship animation
local ship_animation = {
    scale = 1,
    target_scale = 1,
    animation_time = 0,
    get_duration = get_animation_duration  -- function to get current duration
}

-- catch text display system
local catch_texts = {}
local fishing_pressed = false
local fishing_cooldown = 0
local last_cooldown = game_config.fishing_cooldown  -- track previous cooldown to detect when it reaches 0

function add_catch_text(text)
    -- add new text at the beginning
    table.insert(catch_texts, 1, {
        text = text,
        time = game_config.fishing_cooldown,  -- uses the current cooldown time
        y_offset = 0  -- starting y offset
    })
    
    -- remove oldest if we have too many
    if #catch_texts > get_max_catch_texts() then
        table.remove(catch_texts)
    end
    
    -- update y offsets for all texts
    for i, catch in ipairs(catch_texts) do
        catch.y_offset = (i - 1) * game_config.catch_text_spacing
    end
end

function update_catch_texts(dt)
    for i = #catch_texts, 1, -1 do
        local catch = catch_texts[i]
        -- only update times if not in special fish event
        if not special_fish_event.active then
            catch.time = catch.time - dt
        end
        if catch.time <= 0 then
            table.remove(catch_texts, i)
            -- update remaining text positions
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
        -- smooth interpolation between scales
        ship_animation.scale = 1 + (ship_animation.target_scale - 1) * progress
    end
end

function trigger_ship_animation()
    ship_animation.target_scale = 0.7  -- shrink to 70% size
    ship_animation.scale = 1
    ship_animation.animation_time = ship_animation.get_duration()
end

function trigger_special_fish_event(fish_name)
    -- set up the special fish event
    special_fish_event.active = true
    special_fish_event.timer = 0
    special_fish_event.fish_name = fish_name
    
    -- if it's gold sturgeon, mark it as caught for the night
    if fish_name == "Gold Sturgeon" then
        special_fish_event.caught_gold_sturgeon = true
    end
    
    -- add a paused-state catch text that will be shown after the event
    add_catch_text("You: " .. fish_name)
    
    -- don't add to inventory yet - will be added after the event
end

function fish(dt)
    -- track if f was just pressed (not held)
    local fishing_released = love.keyboard.isDown("f") and not fishing_pressed
    fishing_pressed = love.keyboard.isDown("f")

    -- store previous cooldown for transition detection
    local prev_cooldown = fishing_cooldown
    
    -- update cooldown
    fishing_cooldown = math.max(0, fishing_cooldown - dt)
    
    -- detect when cooldown just reached 0
    if prev_cooldown > 0 and fishing_cooldown <= 0 then
        -- crew fishing
        local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y, player_ship.time_system.time)
        trigger_ship_animation()  -- trigger animation for crew fishing
        for i = 1, player_ship.men do
            local fish_caught = fishing.fish(fishing.get_rod_rarity(player_ship.rod), fishing.get_rod_top_rarity(), fish_available, player_ship.y)
            
            -- check for special fish
            if fishing.is_special_fish(fish_caught) then
                trigger_special_fish_event(fish_caught)
            else
                -- regular fish
                add_catch_text("Crew " .. i .. ": " .. fish_caught)
                table.insert(player_ship.caught_fish, fish_caught)  -- store in player_ship
                print("Crew member " .. i .. " caught: " .. fish_caught)
            end
        end
    end

    -- player-initiated fishing
    if fishing_released and fishing_cooldown <= 0 then
        local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y, player_ship.time_system.time)
        local fish_caught = fishing.fish(fishing.get_rod_rarity(player_ship.rod), fishing.get_rod_top_rarity(), fish_available, player_ship.y)
        
        -- check for special fish
        if fishing.is_special_fish(fish_caught) then
            trigger_special_fish_event(fish_caught)
        else
            -- regular fish
            add_catch_text("You: " .. fish_caught)
            table.insert(player_ship.caught_fish, fish_caught)  -- store in player_ship
            print("You caught: " .. fish_caught)
        end
        
        trigger_ship_animation()  -- trigger animation for player fishing
        
        -- reset cooldown using current config value
        fishing_cooldown = game_config.fishing_cooldown
    end
end

-- linear interpolation helper function
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- water colors for different times of day
local waterColors = {
    dawn = {0.3, 0.2, 0.4},    -- purple-orange mix for sunrise (0:00)
    day = {0.05, 0.1, 0.3},    -- bright blue (6:00)
    dusk = {0.2, 0.1, 0.3},    -- purple-blue for evening (11:00)
    night = {0.01, 0.02, 0.08} -- very dark blue for night (12:00)
}

-- function to get current water color based on time
local function getCurrentWaterColor()
    local timeOfDay = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12 -- convert to 12-hour format
    
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

-- function to get ambient light intensity (for glow effects)
local function getAmbientLight()
    local timeOfDay = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12
    
    if timeOfDay >= 0 and timeOfDay < 2 then  -- dawn
        return 0.3 + (timeOfDay / 2) * 0.4  -- 0.3 to 0.7
    elseif timeOfDay >= 2 and timeOfDay < 10 then  -- day
        return 1.0  -- full brightness
    elseif timeOfDay >= 10 and timeOfDay < 12 then  -- dusk to night
        return 1.0 - ((timeOfDay - 10) / 2) * 0.7  -- 1.0 to 0.3
    else  -- night
        return 0.3  -- dim
    end
end

-- function to draw ship glow effect
local function drawShipGlow(x, y, radius, color, intensity)
    local glowRadius = radius * 2.5
    local segments = 20
    
    -- draw multiple layered circles for glow effect
    for i = 1, 3 do
        local currentRadius = glowRadius * (1 - i * 0.2)
        local alpha = (intensity * 0.1) / i
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.circle("fill", x, y, currentRadius, segments)
    end
end

-- function to handle sleep state
local function during_sleep()
    -- check if near any shop (port-a-shop or shopkeeper)
    local near_shop = false
    
    -- check port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            local distance = math.sqrt((shop_data.x - player_ship.x)^2 + (shop_data.y - player_ship.y)^2)
            if distance <= 50 then
                near_shop = true
                break
            end
        end
    end
    
    -- check main shopkeeper if not already near a port-a-shop
    if not near_shop and shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact() then
        near_shop = true
    end
    
    -- if near a shop, heal fainted crew members
    if near_shop and player_ship.fainted_men > 0 then
        print("Healing " .. player_ship.fainted_men .. " fainted crew members...")
        player_ship.men = player_ship.men + player_ship.fainted_men
        player_ship.fainted_men = 0
        print("All crew members healed!")
    end

    -- note: game will be saved after waking up, not during sleep
end

function game.toggleDebug()
    debugOptions.showDebugButtons = not debugOptions.showDebugButtons
    print("Debug mode: " .. (debugOptions.showDebugButtons and "ON" or "OFF"))
end

function game.update(dt)
    -- update day-night cycle - only if not in combat
    if not gameState.combat.is_active then
        if not player_ship.time_system.is_sleeping then
            player_ship.time_system.time = player_ship.time_system.time + dt
            
            -- check if we've reached the end of the day (12 minutes)
            if player_ship.time_system.time >= player_ship.time_system.DAY_LENGTH then
                player_ship.time_system.time = 0
                player_ship.time_system.is_fading = true
                player_ship.time_system.fade_timer = 0
                player_ship.time_system.fade_direction = "out"
                print("Starting night transition...")
            end
        end
    end
    
    -- handle fading and sleep state - only if not in combat
    if not gameState.combat.is_active then
        if player_ship.time_system.is_fading then
            player_ship.time_system.fade_timer = player_ship.time_system.fade_timer + dt
            
            if player_ship.time_system.fade_direction == "out" then
                -- fading to black
                player_ship.time_system.fade_alpha = math.min(1, player_ship.time_system.fade_timer / player_ship.time_system.FADE_DURATION)
                
                if player_ship.time_system.fade_timer >= player_ship.time_system.FADE_DURATION then
                    -- start sleep
                    player_ship.time_system.is_sleeping = true
                    player_ship.time_system.sleep_timer = 0
                    player_ship.time_system.fade_direction = "wait"
                    player_ship.time_system.fade_timer = 0  -- reset timer for next phase
                    during_sleep()
                end
            elseif player_ship.time_system.fade_direction == "wait" then
                -- during sleep
                player_ship.time_system.sleep_timer = player_ship.time_system.sleep_timer + dt
                if player_ship.time_system.sleep_timer >= player_ship.time_system.SLEEP_DURATION then
                    -- start waking up
                    player_ship.time_system.fade_direction = "in"
                    player_ship.time_system.fade_timer = 0  -- reset timer for fade in
                end
            elseif player_ship.time_system.fade_direction == "in" then
                -- fading back in
                player_ship.time_system.fade_alpha = math.max(0, 1 - (player_ship.time_system.fade_timer / player_ship.time_system.FADE_DURATION))
                
                if player_ship.time_system.fade_timer >= player_ship.time_system.FADE_DURATION then
                    -- finish waking up
                    player_ship.time_system.is_fading = false
                    player_ship.time_system.is_sleeping = false
                    player_ship.time_system.fade_alpha = 0
                    
                    -- save game after fully waking up
                    player_ship.name = menu.get_name()
                    serialize.save_data(game.get_saveable_data())
                end
            end
        end
    end

    if suit.Button("Back to Menu", {id = "menu"}, suit.layout:row(120, 30)).hit then
        player_ship.name = menu.get_name()
        local data = game.get_saveable_data()
        serialize.save_data(data)
        return "menu"
    end

    -- only update game elements if not sleeping and not in combat
    if not player_ship.time_system.is_sleeping and not gameState.combat.is_active then
        -- update ship
        player_ship:update(dt)
        
        -- update ship animation
        update_ship_animation(dt)
        
        -- update catch texts
        update_catch_texts(dt)
        
        -- update shopkeeper position
        shopkeeper:update(player_ship.x, player_ship.y, dt)
        
        -- update shop
        local new_state = shop.update(gameState, player_ship, shopkeeper)
        if new_state then
            return new_state
        end

        -- update enemy spawning and movement
        spawnenemy.update(dt, camera, player_ship.x, player_ship.y)

        -- check for collision with enemies
        local collided_enemy = spawnenemy.check_collision(player_ship.x, player_ship.y, player_ship.radius)
        if collided_enemy then
            -- clear any fishing text displays
            catch_texts = {}
            fishing_cooldown = 0
            
            -- start combat
            gameState.combat.is_active = true
            gameState.combat.zoom_progress = 0
            gameState.combat.enemy = collided_enemy
            gameState.combat.result = nil
            gameState.combat.is_fully_zoomed = false
            gameState.combat.result_display_time = 3.0  -- reset display time
        end

        -- some mechs
        fish(dt)

        ripples:update(dt, player_ship)
    end
    
    -- handle combat state
    if gameState.combat.is_active then
        -- update zoom animation
        gameState.combat.zoom_progress = math.min(1, gameState.combat.zoom_progress + dt / gameState.combat.zoom_duration)
        local zoom_factor = 1 + (gameState.combat.target_zoom - 1) * gameState.combat.zoom_progress
        
        -- calculate center point between player and enemy
        local center_x = (player_ship.x + gameState.combat.enemy.x) / 2
        local center_y = (player_ship.y + gameState.combat.enemy.y) / 2
        
        -- apply zoom with target point
        camera:zoom(zoom_factor / camera.scale, center_x, center_y)
        
        -- check if zoom is complete
        if gameState.combat.zoom_progress >= 1 then
            if not gameState.combat.is_fully_zoomed then
                gameState.combat.is_fully_zoomed = true
                
                -- process combat only when zoom is complete
                local enemy = gameState.combat.enemy
                local result = combat.combat(player_ship.men, enemy.size, 
                    combat.get_sword_level(player_ship.sword),
                    combat.get_sword_top_rarity(),
                    player_ship.y)

                -- apply combat results
                if result.victory then
                    player_ship.men = player_ship.men - result.casualties
                    player_ship.fainted_men = player_ship.fainted_men + result.fainted
                    gameState.combat.result = result
                    gameState.combat.result_display_time = 3.0  -- reset display time for victory
                else
                    -- defeat handling
                    gameState.combat.result = result
                    gameState.combat.defeat_flash.active = true
                    gameState.combat.defeat_flash.alpha = 0
                    gameState.combat.defeat_flash.timer = 0
                end
            end
        end

        -- update result display timer and handle defeat
        if gameState.combat.result then
            if gameState.combat.result.victory then
                -- normal victory handling
                if gameState.combat.result_display_time > 0 then  -- only count down if time remains
                    gameState.combat.result_display_time = gameState.combat.result_display_time - dt
                    if gameState.combat.result_display_time <= 0 then
                        -- remove the enemy and end combat
                        spawnenemy.remove_enemy(gameState.combat.enemy)
                        gameState.combat.is_active = false
                        gameState.combat.zoom_progress = 0
                        gameState.combat.is_fully_zoomed = false
                        gameState.combat.result = nil
                        camera.scale = 1
                    end
                end
            else
                -- defeat flash handling
                if gameState.combat.defeat_flash.active then
                    gameState.combat.defeat_flash.timer = gameState.combat.defeat_flash.timer + dt
                    
                    -- show text for text_display_time seconds before starting flash
                    if gameState.combat.defeat_flash.timer >= gameState.combat.defeat_flash.text_display_time then
                        -- calculate flash alpha only after text display time
                        local flash_time = gameState.combat.defeat_flash.timer - gameState.combat.defeat_flash.text_display_time
                        gameState.combat.defeat_flash.alpha = math.min(1, flash_time / gameState.combat.defeat_flash.duration)
                        
                        -- when fully white, reset game
                        if gameState.combat.defeat_flash.alpha >= 1 then
                            -- check if player has gold sturgeon before resetting
                            local has_gold_sturgeon = false
                            for _, fish in ipairs(player_ship.caught_fish) do
                                if fish == "Gold Sturgeon" then
                                    has_gold_sturgeon = true
                                    break
                                end
                            end
                            
                            -- create mysterious note if died with gold sturgeon
                            if has_gold_sturgeon then
                                -- write the mysterious message to note.txt
                                love.filesystem.write("note.txt", "A golden catch, a silver grave.")
                                print("A mysterious note has been left behind...")
                            end
                            
                            reset_game()
                            return "menu"
                        end
                    end
                end
            end
        end
    end
    
    -- always update camera to follow ship or combat center
    if gameState.combat.is_active then
        -- during combat, camera should focus on the center point between player and enemy
        local center_x = (player_ship.x + gameState.combat.enemy.x) / 2
        local center_y = (player_ship.y + gameState.combat.enemy.y) / 2
        
        -- adjust for screen center
        camera:goto(
            center_x - love.graphics.getWidth()/(2 * camera.scale),
            center_y - love.graphics.getHeight()/(2 * camera.scale)
        )
    else
        -- normal camera following during gameplay
        camera:goto(
            player_ship.x - love.graphics.getWidth()/2,
            player_ship.y - love.graphics.getHeight()/2
        )
    end
    
    -- update special fish event if active
    if special_fish_event.active then
        special_fish_event.timer = special_fish_event.timer + dt
        
        if special_fish_event.timer >= special_fish_event.duration then
            -- event finished
            special_fish_event.active = false
            
            -- now add the fish to inventory
            table.insert(player_ship.caught_fish, special_fish_event.fish_name)
            print("Special fish caught: " .. special_fish_event.fish_name)
        end
        
        -- don't process regular game updates during special fish event
        return nil
    end
    
    return nil
end

function game.draw()
    -- get current water color based off the time of day
    local waterColor = getCurrentWaterColor()
    love.graphics.clear(waterColor[1], waterColor[2], waterColor[3])

    love.graphics.push()
    love.graphics.translate(-camera.x * camera.scale, -camera.y * camera.scale)
    love.graphics.scale(camera.scale)

    -- draw ripples first as background effect
    ripples:draw()
    
    -- only draw game world if not sleeping
    if not player_ship.time_system.is_sleeping then
        -- draw the shore using repeating texture
        local viewWidth = love.graphics.getWidth() / camera.scale
        local viewHeight = love.graphics.getHeight() / camera.scale
        local shoreExtension = 1000 -- how far the shore extends beyond the viewport
        
        -- calculate how many times we need to repeat the shore texture
        local total_width = viewWidth + shoreExtension * 2
        local start_x = camera.x - shoreExtension
        local shore_top = -1000  -- extend well above viewport
        local shore_bottom = shore_division
        
        -- find the leftmost position to start drawing (aligned to texture width)
        local aligned_start_x = math.floor(start_x / shore_width) * shore_width
        local num_repeats = math.ceil(total_width / shore_width) + 2  -- +2 for safety margin
        
        love.graphics.setColor(1, 1, 1, 1)  -- full white tint
        
        -- draw repeating shore texture
        for i = 0, num_repeats do
            local x = aligned_start_x + (i * shore_width)
            
            -- scale the texture vertically to fill from shore_top to shore_division
            local scale_y = (shore_bottom - shore_top) / shore_height
            
            love.graphics.draw(shore_texture, x, shore_top, 0, 1, scale_y)
        end
        
        -- draw the shopkeeper
        shopkeeper:draw()

        -- get ambient light for glow effects
        local ambientLight = getAmbientLight()
        local glowIntensity = math.max(0, 1 - ambientLight) -- stronger glow at night
        
        -- draw enemy ships
        if not gameState.combat.is_active then
            -- draw enemy glow effects first
            if glowIntensity > 0 then
                local enemies = spawnenemy.get_enemies()
                for _, enemy in ipairs(enemies) do
                    drawShipGlow(enemy.x, enemy.y, enemy.radius, {1, 0.5, 0.5}, glowIntensity)
                end
            end
            -- draw all enemies normally when not in combat
            spawnenemy.draw()
        else
            -- during combat, only draw the enemy we're fighting
            if gameState.combat.enemy then
                -- draw enemy glow
                if glowIntensity > 0 then
                    drawShipGlow(gameState.combat.enemy.x, gameState.combat.enemy.y, gameState.combat.enemy.radius, {1, 0.5, 0.5}, glowIntensity)
                end
                
                -- save current transform
                love.graphics.push()
                
                -- move to enemy position and rotate based on direction
                love.graphics.translate(gameState.combat.enemy.x, gameState.combat.enemy.y)
                love.graphics.rotate((gameState.combat.enemy.direction > 0 and 0 or math.pi) + math.pi)  -- rotate based on direction + 180° for boat sprite
                
                -- draw enemy boat sprite with red tint
                love.graphics.setColor(1, 0, 0, 1)  -- red color filter
                local target_width = 64
                local sprite_scale = target_width / player_ship.sprite:getWidth()
                
                love.graphics.draw(
                    player_ship.sprite,  -- use the same boat sprite
                    0, 0, -- position (already translated)
                    0, -- rotation (already applied)
                    sprite_scale, sprite_scale, -- uniform scale to maintain aspect ratio
                    player_ship.sprite:getWidth()/2, -- origin x (center)
                    player_ship.sprite:getHeight()/2  -- origin y (center)
                )
                
                -- restore transform before drawing text
                love.graphics.pop()
                
                -- draw crew size text (always upright)
                local text = tostring(gameState.combat.enemy.size)
                local font = love.graphics.getFont()
                local text_width = font:getWidth(text)
                local text_height = font:getHeight()
                local text_x = gameState.combat.enemy.x - text_width/2
                local text_y = gameState.combat.enemy.y - text_height/2
                
                -- draw inverted background
                local waterColor = getCurrentWaterColor()
                local inverted_r = 1 - waterColor[1]
                local inverted_g = 1 - waterColor[2]
                local inverted_b = 1 - waterColor[3]
                love.graphics.setColor(inverted_r, inverted_g, inverted_b, 0.8)
                love.graphics.rectangle("fill", text_x - 2, text_y - 1, text_width + 4, text_height + 2)
                
                -- draw text
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(text, text_x, text_y)
            end
        end
        
        -- draw player ship glow effect
        if glowIntensity > 0 then
            drawShipGlow(player_ship.x, player_ship.y, player_ship.radius, {0.5, 0.8, 1}, glowIntensity)
        end
        
        -- draw ship wake trail if moving
        local ship_speed = math.sqrt(player_ship.velocity_x^2 + player_ship.velocity_y^2)
        if ship_speed > 10 then
            local wake_length = math.min(ship_speed * 0.5, 60)
            local wake_direction = math.atan2(-player_ship.velocity_y, -player_ship.velocity_x)
            
            -- draw wake trail
            love.graphics.setColor(1, 1, 1, 0.2 * (glowIntensity * 0.5 + 0.5))
            for i = 1, 3 do
                local offset = i * 15
                local wake_x = player_ship.x + math.cos(wake_direction) * offset
                local wake_y = player_ship.y + math.sin(wake_direction) * offset
                local wake_width = (4 - i) * 2
                
                love.graphics.circle("fill", wake_x, wake_y, wake_width)
            end
        end
        
        -- draw the ship with animation scale
        love.graphics.push()
        love.graphics.translate(player_ship.x, player_ship.y)
        -- rotate by 180 degrees (π radians) plus the ship's rotation since boat.png faces west
        love.graphics.rotate(player_ship.rotation + math.pi)
        love.graphics.scale(ship_animation.scale, ship_animation.scale)
        
        -- draw ship sprite
        love.graphics.setColor(player_ship.color)
        -- calculate scale to make sprite width 64 pixels while maintaining aspect ratio
        local target_width = 64
        local sprite_scale = target_width / player_ship.sprite:getWidth()
        
        love.graphics.draw(
            player_ship.sprite,
            0, 0, -- position (already translated)
            0, -- rotation (already applied)
            sprite_scale, sprite_scale, -- uniform scale to maintain aspect ratio
            player_ship.sprite:getWidth()/2, -- origin x (center)
            player_ship.sprite:getHeight()/2  -- origin y (center)
        )
        
        -- draw yellow shadow if gold sturgeon was caught tonight
        if special_fish_event.caught_gold_sturgeon then
            love.graphics.setColor(1, 0.8, 0, 0.5)  -- semi-transparent gold color
            love.graphics.draw(
                player_ship.sprite,
                0, 10, -- draw shadow slightly below
                0, -- rotation (already applied)
                sprite_scale, sprite_scale, -- uniform scale to maintain aspect ratio
                player_ship.sprite:getWidth()/2, -- origin x (center)
                player_ship.sprite:getHeight()/2  -- origin y (center)
            )
        end
        
        -- draw ship name below the ship
        love.graphics.push()
        love.graphics.scale(1/ship_animation.scale, 1/ship_animation.scale)  -- counter the ship animation scale
        love.graphics.rotate(-player_ship.rotation)  -- counter the ship rotation
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(player_ship.name)
        love.graphics.print(player_ship.name, 
            -text_width/2,  -- center horizontally
            player_ship.radius * 1.5 * ship_animation.scale)  -- position below ship
        love.graphics.pop()
        
        love.graphics.pop()

        -- draw combat result text at top of screen
        if gameState.combat.is_active and gameState.combat.result then
            -- draw combat result
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
                -- only show defeat text before the flash starts
                if gameState.combat.defeat_flash.timer < gameState.combat.defeat_flash.text_display_time then
                    result_text = {
                        "Defeat!",
                        string.format("Lost all %d crew member(s)!", player_ship.men)
                    }
                end
            end
            
            -- draw centered on screen with larger font
            if result_text then
                local font = love.graphics.getFont()
                local scale = 2.0  -- make text larger
                
                -- calculate screen center
                local screen_center_x = love.graphics.getWidth() / 2
                local screen_center_y = love.graphics.getHeight() / 2
                
                -- convert to world coordinates
                local world_x = screen_center_x / camera.scale + camera.x
                local world_y = screen_center_y / camera.scale + camera.y
                
                -- calculate dimensions for all lines
                local max_width = 0
                local total_height = 0
                for _, line in ipairs(result_text) do
                    local width = font:getWidth(line)
                    max_width = math.max(max_width, width)
                    total_height = (total_height + font:getHeight()) * 2
                end
                
                -- add padding for the background
                local padding = 20 / scale  -- 20 pixels padding, adjusted for scale
                
                -- draw semi-transparent black background
                love.graphics.setColor(0, 0, 0, 0.7)  -- 70% opacity black
                love.graphics.push()
                love.graphics.scale(scale, scale)
                love.graphics.rectangle("fill",
                    (world_x - (max_width * scale / 2)) / scale - padding,
                    (world_y - (total_height * scale / 2)) / scale - padding,
                    max_width + padding * 2,
                    total_height + padding * 2,
                    10 / scale  -- rounded corners, adjusted for scale
                )
                love.graphics.pop()
                
                -- draw text
                love.graphics.push()
                love.graphics.scale(scale, scale)
                
                -- start y position (centered vertically)
                local y_pos = (world_y - (total_height * scale / 2)) / scale
                
                -- draw each line centered
                for i, line in ipairs(result_text) do
                    local width = font:getWidth(line)
                    local x_pos = (world_x - (width * scale / 2)) / scale
                    
                    -- make title (first line) bigger
                    if i == 1 then
                        love.graphics.push()
                        love.graphics.scale(1.5, 1.5)  -- 50% bigger than the rest
                        x_pos = (world_x - (width * scale * 1.5 / 2)) / (scale * 1.5)
                        y_pos = (world_y - (total_height * scale / 2)) / (scale * 1.5)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(line, x_pos, y_pos)
                        love.graphics.pop()
                        y_pos = y_pos * 1.5 + font:getHeight() * 2  -- add extra spacing after title
                    else
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(line, x_pos, y_pos)
                        y_pos = y_pos + font:getHeight()
                    end
                end
                
                love.graphics.pop()
            end
        end
        
        -- draw catch texts
        for _, catch in ipairs(catch_texts) do
            local alpha = catch.time / game_config.fishing_cooldown  -- fade out over time
            local font = love.graphics.getFont()
            local text_width = font:getWidth(catch.text)
            local text_height = font:getHeight()
            local text_x = player_ship.x - 40
            local text_y = player_ship.y - 60 - catch.y_offset
            
            -- draw inverted background
            local waterColor = getCurrentWaterColor()
            local inverted_r = 1 - waterColor[1]
            local inverted_g = 1 - waterColor[2]
            local inverted_b = 1 - waterColor[3]
            love.graphics.setColor(inverted_r, inverted_g, inverted_b, alpha * 0.8)
            love.graphics.rectangle("fill", text_x - 2, text_y - 1, text_width + 4, text_height + 2)
            
            -- draw text
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.print(catch.text, text_x, text_y)
        end
        
        -- draw fishing cooldown indicator if on cooldown
        if fishing_cooldown > 0 then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.print(string.format("Fishing: %.1fs", fishing_cooldown), 
                player_ship.x - 30, 
                player_ship.y - 40)
        else
            -- show "crew fishing!" briefly when crew is about to fish
            if fishing_cooldown == 0 and last_cooldown > 0 then
                love.graphics.setColor(1, 1, 0.5, 0.8)  -- yellowish color
                love.graphics.print("Crew Fishing!", 
                    player_ship.x - 30, 
                    player_ship.y - 40)
            end
        end
        
        -- update last cooldown for next frame
        last_cooldown = fishing_cooldown
        
        shop.draw_shops(camera)
    end

    love.graphics.pop()

    -- draw shop ui on top of everything if not sleeping
    if not player_ship.time_system.is_sleeping then
        shop.draw_ui()
    end

    -- draw day/night fade overlay
    if player_ship.time_system.is_fading or player_ship.time_system.fade_alpha > 0 then
        love.graphics.setColor(0, 0, 0, player_ship.time_system.fade_alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        -- draw sleep message when fully black
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

    -- draw time of day
    love.graphics.setColor(1, 1, 1, 1)
    local timeOfDay = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12  -- convert to 12-hour format
    local hours = math.floor(timeOfDay)
    local minutes = math.floor((timeOfDay - hours) * 60)
    -- ensure we don't display past 12:00
    if hours >= 12 then
        hours = 12
        minutes = 0
    end
    love.graphics.print(string.format("Time: %02d:%02d", hours, minutes), 10, 10)

    -- draw debug buttons if enabled and not sleeping
    if debugOptions.showDebugButtons and not player_ship.time_system.is_sleeping then
        -- reset layout for debug buttons
        suit.layout:reset(10, 40)
        suit.layout:padding(10)

        -- add 100 fish button
        if suit.Button("Add 100 Fish", suit.layout:row(100, 30)).hit then
            for i = 1, 100 do
                local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y, player_ship.time_system.time)
                local fish_caught = fishing.fish(fishing.get_rod_rarity(player_ship.rod), fishing.get_rod_top_rarity(), fish_available, player_ship.y)
                table.insert(player_ship.caught_fish, fish_caught)
            end
            print("Added 100 fish!")
        end

        -- add one of every fish button
        if suit.Button("Add Every Fish", suit.layout:row(100, 30)).hit then
            local all_fish = fishing.get_all_fish()
            for _, fish_name in ipairs(all_fish) do
                table.insert(player_ship.caught_fish, fish_name)
            end
            print("Added one of every fish type (" .. #all_fish .. " fish)!")
        end

        -- skip 1 minute button
        if suit.Button("Skip 1 Min", suit.layout:row(100, 30)).hit then
            local old_time = player_ship.time_system.time
            player_ship.time_system.time = player_ship.time_system.time + 60  -- add 60 seconds
            
            -- check if we've passed the day length threshold
            if old_time < player_ship.time_system.DAY_LENGTH and player_ship.time_system.time >= player_ship.time_system.DAY_LENGTH then
                -- reset time and start sleep sequence properly
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

        -- toggle fishing cooldown button
        if suit.Button("Toggle Cooldown (5s/2s)", suit.layout:row(150, 30)).hit then
            game_config.fishing_cooldown = game_config.fishing_cooldown == 5 and 2 or 5
            print("Fishing cooldown set to: " .. game_config.fishing_cooldown .. "s")
        end

        if suit.Button("Display Position", suit.layout:row(100, 30)).hit then
            print("Player Position: " .. player_ship.x .. ", " .. player_ship.y)
        end
        
        -- gold sturgeon debug button
        if suit.Button("Gold Sturgeon Time", suit.layout:row(150, 30)).hit then
            -- set time to 11:30 (late night)
            player_ship.time_system.time = (11.5/12) * player_ship.time_system.DAY_LENGTH
            
            -- update water color to reflect night time immediately
            getCurrentWaterColor()
            
            -- trigger gold sturgeon event
            trigger_special_fish_event("Gold Sturgeon")
            
            print("Time set to 11:30 and Gold Sturgeon event triggered!")
        end
        
        -- show debug status
        love.graphics.print("Debug Mode (F3 to toggle)", 10, 100)
    end

    -- draw white flash overlay for defeat
    if gameState.combat.defeat_flash and gameState.combat.defeat_flash.active then
        love.graphics.setColor(1, 1, 1, gameState.combat.defeat_flash.alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- reset color
    love.graphics.setColor(1, 1, 1, 1)

    -- not zoomed in viewport
    suit.draw()

    -- draw special fish event if active
    if special_fish_event.active then
        -- darkened background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        -- center message
        love.graphics.setColor(1, 1, 1, 1)
        local message = "You feel a tug unlike anything before..."
        local font = love.graphics.getFont()
        local text_width = font:getWidth(message)
        local scale = 2.0  -- larger text
        
        -- draw centered text with scaling
        love.graphics.push()
        love.graphics.scale(scale, scale)
        love.graphics.print(
            message,
            (love.graphics.getWidth() / scale - text_width) / 2,
            love.graphics.getHeight() / scale / 2 - 20
        )
        love.graphics.pop()
        
        -- add mysterious golden glow for gold sturgeon without revealing its name
        if special_fish_event.timer > special_fish_event.duration / 2 and special_fish_event.fish_name == "Gold Sturgeon" then
            -- draw glowing circles behind
            for i = 1, 3 do
                local radius = 100 - i * 20
                love.graphics.setColor(1, 0.8, 0, 0.1)
                love.graphics.circle("fill", love.graphics.getWidth() / 2, love.graphics.getHeight() / 2 + 30, radius)
            end
        end
    end
end

-- make player_ship accessible to other modules
game.player_ship = player_ship

return game