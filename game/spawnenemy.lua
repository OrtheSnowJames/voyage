local spawnenemy = {}

-- configuration
local ENEMY_SPAWN_INTERVAL = 10  -- seconds between enemy spawns
local BASE_ENEMY_SPEED = 150  -- base speed in pixels per second
local SPEED_INCREASE_PER_LEVEL = 30  -- speed increase per 1000 units of depth
local MAX_SPEED_MULTIPLIER = 3  -- maximum speed multiplier (prevents excessive speeds)
local ENEMY_SIZE = 20   -- size of enemy ships
local SPAWN_MARGIN = 100  -- spawn enemies slightly outside view
local SHORE_DIVISION = 60  -- match the shore_division from game.lua
local MIN_SHORE_DISTANCE = 40  -- minimum distance from shore (match player ship restriction)
local SHOP_SAFE_DISTANCE = 50  -- minimum distance from shops for enemy spawns

-- load enemy boat sprite
local enemy_boat_sprite = love.graphics.newImage("assets/boat.png")

local enemies = {}  -- table to store active enemies
local spawn_timer = 0

-- generate a random enemy size (crew count)
local function generate_enemy_size(player_y)
    -- base size increases with depth
    local depth_level = math.floor(math.abs(player_y) / 1000)
    local base_size = math.max(1, depth_level)
    
    -- random variation around base size
    return math.max(1, math.floor(base_size + math.random(-1, 2)))
end

-- add helper function to check if a y position is too close to shops
local function is_near_shop(y)
    -- check main shopkeeper position (always at shore_division)
    if math.abs(y - SHORE_DIVISION) <= SHOP_SAFE_DISTANCE then
        return true
    end
    
    -- check port-a-shop positions (every 1000 units)
    local shop_y = math.floor(y / 1000) * 1000
    if math.abs(y - shop_y) <= SHOP_SAFE_DISTANCE then
        return true
    end
    
    -- also check the next shop level up and down
    if math.abs(y - (shop_y + 1000)) <= SHOP_SAFE_DISTANCE or
       math.abs(y - (shop_y - 1000)) <= SHOP_SAFE_DISTANCE then
        return true
    end
    
    return false
end

-- add helper function to calculate enemy speed based on depth
local function calculate_enemy_speed(y_position)
    local depth_level = math.floor(math.abs(y_position) / 1000)
    local speed_multiplier = 1 + (depth_level * SPEED_INCREASE_PER_LEVEL / BASE_ENEMY_SPEED)
    -- cap the multiplier to prevent excessive speeds
    speed_multiplier = math.min(speed_multiplier, MAX_SPEED_MULTIPLIER)
    return BASE_ENEMY_SPEED * speed_multiplier
end

function spawnenemy.update(dt, camera, player_x, player_y)
    -- calculate viewport boundaries
    local view_width = love.graphics.getWidth() / camera.scale
    local view_height = love.graphics.getHeight() / camera.scale
    
    -- update spawn timer
    spawn_timer = spawn_timer - dt
    
    -- check if it's time to spawn a new enemy
    if spawn_timer <= 0 then
        -- reset timer
        spawn_timer = ENEMY_SPAWN_INTERVAL
        
        -- randomly choose left or right side for spawning
        local spawn_side = math.random() < 0.5 and "left" or "right"
        local spawn_x
        local direction
        
        if spawn_side == "left" then
            spawn_x = camera.x - SPAWN_MARGIN
            direction = 1  -- moving right
        else
            spawn_x = camera.x + view_width + SPAWN_MARGIN
            direction = -1  -- moving left
        end
        
        -- calculate valid y range for spawning
        local min_y = math.max(200, camera.y)  -- minimum y position (at least 200)
        local max_y = camera.y + view_height - SPAWN_MARGIN  -- maximum y position (within view)
        
        -- only spawn if there's valid space
        if max_y > min_y then
            -- try to find a valid spawn position
            local max_attempts = 10
            local spawn_y = nil
            
            for i = 1, max_attempts do
                local test_y = math.random(min_y, max_y)
                if not is_near_shop(test_y) then
                    spawn_y = test_y
                    break
                end
            end
            
            -- only spawn if we found a valid position
            if spawn_y then
                -- calculate speed based on depth
                local enemy_speed = calculate_enemy_speed(spawn_y)
                
                -- create new enemy
                table.insert(enemies, {
                    x = spawn_x,
                    y = spawn_y,
                    direction = direction,
                    size = generate_enemy_size(player_y),
                    radius = ENEMY_SIZE,
                    speed = enemy_speed  -- store individual enemy speed
                })
            end
        end
    end
    
    -- update enemy positions and remove off-screen enemies
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        
        -- move enemy using its individual speed
        enemy.x = enemy.x + (enemy.speed * enemy.direction * dt)
        
        -- check if enemy is far off screen
        local far_margin = SPAWN_MARGIN * 2
        if enemy.x < camera.x - far_margin or enemy.x > camera.x + view_width + far_margin then
            table.remove(enemies, i)
        end
    end
end

function spawnenemy.draw()
    for _, enemy in ipairs(enemies) do
        -- save current transform
        love.graphics.push()
        
        -- move to enemy position and rotate based on direction
        love.graphics.translate(enemy.x, enemy.y)
        love.graphics.rotate((enemy.direction > 0 and 0 or math.pi) + math.pi)  -- rotate based on direction + 180° for boat sprite
        
        -- draw enemy boat sprite with red tint
        love.graphics.setColor(1, 0, 0, 1)  -- red color filter
        local target_width = 64
        local sprite_scale = target_width / enemy_boat_sprite:getWidth()
        
        love.graphics.draw(
            enemy_boat_sprite,
            0, 0, -- position (already translated)
            0, -- rotation (already applied)
            sprite_scale, sprite_scale, -- uniform scale to maintain aspect ratio
            enemy_boat_sprite:getWidth()/2, -- origin x (center)
            enemy_boat_sprite:getHeight()/2  -- origin y (center)
        )
        
        -- restore transform before drawing text
        love.graphics.pop()
        
        -- draw crew size text (always upright) with inverted background
        local text = tostring(enemy.size)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(text)
        local text_height = font:getHeight()
        local text_x = enemy.x - text_width/2
        local text_y = enemy.y - text_height/2
        
        -- draw inverted background (we'll use a dark blue water approximation since we don't have getcurrentwatercolor here)
        love.graphics.setColor(0.8, 0.8, 0.8, 0.8)  -- light gray background
        love.graphics.rectangle("fill", text_x - 2, text_y - 1, text_width + 4, text_height + 2)
        
        -- draw text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, text_x, text_y)
    end
    
    -- reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function spawnenemy.check_collision(player_x, player_y, player_radius)
    for i, enemy in ipairs(enemies) do
        -- simple circle collision
        local dx = player_x - enemy.x
        local dy = player_y - enemy.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < (player_radius + enemy.radius) then
            -- return enemy data without removing it
            return enemy
        end
    end
    return nil
end

function spawnenemy.remove_enemy(enemy)
    for i, e in ipairs(enemies) do
        if e == enemy then
            table.remove(enemies, i)
            break
        end
    end
end

function spawnenemy.get_enemies()
    return enemies
end

function spawnenemy.clear_enemies()
    enemies = {}
    spawn_timer = ENEMY_SPAWN_INTERVAL
end

return spawnenemy