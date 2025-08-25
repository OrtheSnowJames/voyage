local spawnenemy = {}
local size = require("game.size")

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

-- excessive spawning configuration
local EXCESSIVE_SPAWN_INTERVAL = 0.1  -- seconds between spawns in dangerous areas
local MAX_ENEMIES_ON_SCREEN = 20  -- maximum enemies visible at once
local DESPAWN_MARGIN = 200  -- enemies despawn when this far outside view
local MULTIPLIER_DANGEROUS_AREA = 7
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

-- check if current area is dangerous (no port-a-shop nearby)
local function is_dangerous_area(y)
    -- areas less than 1000 units from shore are always safe
    if math.abs(y) < 1000 then
        return false
    end
    
    -- check if there's a port-a-shop nearby
    return not is_near_shop(y)
end

-- check if player is beyond their last port-a-shop (always dangerous)
local function is_beyond_last_shop(y)
    local shop = require("shop")
    local last_shop_y = shop.get_last_port_a_shop_y()
    
    -- if player is beyond their last port-a-shop, they're always in danger
    if math.abs(y) > math.abs(last_shop_y) + 100 and math.abs(y) >= 1000 then  -- 100 unit buffer + safe zone check
        return true
    end
    
    return false
end

-- add helper function to calculate enemy speed based on depth
local function calculate_enemy_speed(y_position, is_dangerous_area)
    local depth_level = math.floor(math.abs(y_position) / 1000)
    local speed_multiplier = 1 + (depth_level * SPEED_INCREASE_PER_LEVEL / BASE_ENEMY_SPEED)
    -- cap the multiplier to prevent excessive speeds
    speed_multiplier = math.min(speed_multiplier, MAX_SPEED_MULTIPLIER)
    
    -- apply dangerous area speed multiplier
    if is_dangerous_area then
        speed_multiplier = speed_multiplier * MULTIPLIER_DANGEROUS_AREA
    end
    
    return BASE_ENEMY_SPEED * speed_multiplier
end

function spawnenemy.update(dt, camera, player_x, player_y)
    -- calculate viewport boundaries
    local view_width = size.CANVAS_WIDTH / camera.scale
    local view_height = love.graphics.getHeight() / camera.scale
    
    -- check if current area is dangerous
    local is_dangerous = is_dangerous_area(player_y)
    
    -- check if player is beyond their last port-a-shop (always dangerous)
    local is_beyond_last = is_beyond_last_shop(player_y)
    
    -- determine spawn interval based on area safety
    -- if beyond last shop OR in dangerous area, use excessive spawning
    local current_spawn_interval = (is_dangerous or is_beyond_last) and EXCESSIVE_SPAWN_INTERVAL or ENEMY_SPAWN_INTERVAL
    
    -- debug output
    if is_dangerous or is_beyond_last then
        local reason = is_beyond_last and "beyond last shop" or "in dangerous area"
        print("DEBUG: " .. reason .. " at Y=" .. player_y .. ", spawn interval=" .. current_spawn_interval .. "s, timer=" .. string.format("%.1f", spawn_timer) .. "s, enemies=" .. #enemies)
    end
    
    -- update spawn timer
    spawn_timer = spawn_timer - dt
    
    -- check if it's time to spawn a new enemy
    if spawn_timer <= 0 then
        -- reset timer
        spawn_timer = current_spawn_interval
        print("DEBUG: Spawn timer reset to " .. current_spawn_interval .. "s")
        
        -- only spawn if we don't have too many enemies on screen
        if #enemies < MAX_ENEMIES_ON_SCREEN then
            print("DEBUG: Attempting to spawn enemy (enemy count: " .. #enemies .. "/" .. MAX_ENEMIES_ON_SCREEN .. ")")
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
            
            print("DEBUG: Y range - min: " .. min_y .. ", max: " .. max_y .. ", camera.y: " .. camera.y .. ", view_height: " .. view_height)
            
            -- only spawn if there's valid space
            if max_y > min_y then
                local spawn_y = nil
                
                                if is_dangerous or is_beyond_last then
                    local area_type = is_beyond_last and "beyond last shop" or "dangerous area"
                    print("DEBUG: " .. area_type .. " spawning - checking both lines and random positions")
                    
                    -- First, try to spawn on 1000-unit divider lines
                    local start_y = math.floor(min_y / 1000) * 1000
                    local end_y = math.ceil(max_y / 1000) * 1000
                    
                    print("DEBUG: Divider line search - start: " .. start_y .. ", end: " .. end_y)
                    
                    local valid_lines = {}
                    for line_y = start_y, end_y, 1000 do
                        if line_y >= min_y and line_y <= max_y and not is_near_shop(line_y) then
                            table.insert(valid_lines, line_y)
                            print("DEBUG: Found valid line at Y=" .. line_y)
                        end
                    end
                    
                    -- 50% chance to spawn on a divider line if available
                    if #valid_lines > 0 and math.random() < 0.5 then
                        spawn_y = valid_lines[math.random(1, #valid_lines)]
                        print("DEBUG: Spawning on divider line Y=" .. spawn_y)
                    else
                        -- Otherwise spawn randomly throughout the area
                        print("DEBUG: Spawning at random position")
                        local max_attempts = 20
                        for i = 1, max_attempts do
                            local test_y = min_y + math.random() * (max_y - min_y)
                            if not is_near_shop(test_y) then
                                spawn_y = test_y
                                print("DEBUG: Found random spawn position at Y=" .. spawn_y)
                                break
                            end
                        end
                    end
                    
                    if not spawn_y then
                        print("DEBUG: Could not find valid spawn position after all attempts")
                    end
            else
                -- in safe areas, use random spawning as before
                local max_attempts = 10
                for i = 1, max_attempts do
                    local test_y = math.random(min_y, max_y)
                    if not is_near_shop(test_y) then
                        spawn_y = test_y
                        break
                    end
                end
            end
            
            print("DEBUG: Final spawn_y value: " .. (spawn_y or "nil"))
            
            -- only spawn if we found a valid position
            if spawn_y then
                    print("DEBUG: Spawn position found at Y=" .. spawn_y .. ", proceeding with enemy creation")
                    -- calculate speed based on depth and area danger
                    local enemy_speed = calculate_enemy_speed(spawn_y, is_dangerous or is_beyond_last)
                    
                    -- create new enemy
                    table.insert(enemies, {
                        x = spawn_x,
                        y = spawn_y,
                        direction = direction,
                        size = generate_enemy_size(player_y),
                        radius = ENEMY_SIZE,
                        speed = enemy_speed,  -- store individual enemy speed
                        last_ripple_pos = {x = spawn_x, y = spawn_y}
                    })
                    
                    -- print spawn info for debugging
                    if is_dangerous or is_beyond_last then
                        local area_type = is_beyond_last and "BEYOND LAST SHOP" or "DANGEROUS AREA"
                        -- Check if this was a divider line spawn
                        local is_divider_line = false
                        for _, line_y in ipairs(valid_lines or {}) do
                            if math.abs(spawn_y - line_y) < 1 then
                                is_divider_line = true
                                break
                            end
                        end
                        
                        if is_divider_line then
                            print(area_type .. ": Enemy spawned on divider line Y=" .. spawn_y .. "! Speed: " .. string.format("%.1f", enemy_speed) .. " (multiplier: " .. MULTIPLIER_DANGEROUS_AREA .. "x)")
                        else
                            print(area_type .. ": Enemy spawned at random Y=" .. spawn_y .. "! Speed: " .. string.format("%.1f", enemy_speed) .. " (multiplier: " .. MULTIPLIER_DANGEROUS_AREA .. "x)")
                        end
                    else
                        print("SAFE AREA: Enemy spawned at Y=" .. spawn_y .. "! Speed: " .. string.format("%.1f", enemy_speed))
                    end
                end
            end
        end
    end
    
    -- update enemy positions and remove off-screen enemies
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        
        -- move enemy using its individual speed
        enemy.x = enemy.x + (enemy.speed * enemy.direction * dt)
        
        -- check if enemy is far off screen
        if enemy.x < camera.x - DESPAWN_MARGIN or enemy.x > camera.x + view_width + DESPAWN_MARGIN then
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

function spawnenemy.get_spawn_status(player_y)
    local is_dangerous = is_dangerous_area(player_y)
    local is_beyond_last = is_beyond_last_shop(player_y)
    local current_interval = (is_dangerous or is_beyond_last) and EXCESSIVE_SPAWN_INTERVAL or ENEMY_SPAWN_INTERVAL
    return {
        is_dangerous = is_dangerous or is_beyond_last,
        spawn_interval = current_interval,
        enemy_count = #enemies,
        max_enemies = MAX_ENEMIES_ON_SCREEN
    }
end

function spawnenemy.clear_enemies()
    enemies = {}
    spawn_timer = ENEMY_SPAWN_INTERVAL
end

return spawnenemy