local shop = {}
local suit = require "SUIT"
local fishing = require("game.fishing")
local combat = require("game.combat")  -- Add combat module

-- Player's inventory (should be moved to a proper inventory system later)
local coins = 0
local current_state = ""  -- Store the current game state
local show_no_fish_message = false
local message_timer = 0
local MESSAGE_DURATION = 2  -- How long to show the message

-- Port-a-shop configuration
local SHOP_SPACING = 1000  -- Distance between shops (changed from 40)
local SHOP_SIZE = { width = 60, height = 40 }  -- Size of the shop platform
local INTERACTION_RANGE = 50  -- How close the player needs to be to interact
local SHOP_ANIMATION_SPEED = 500  -- Speed of shop movement in pixels per second

-- Port-a-shops state
local port_a_shops = {}

-- Animation state for each shop
local function create_shop_animation(target_y)
    return {
        start_y = target_y + 1000,  -- Start 1000 pixels below target
        target_y = target_y,
        progress = 0,  -- 0 to 1
        duration = 2,  -- Animation duration in seconds
        is_animating = true
    }
end

-- Calculate cost for next port-a-shop
local function get_next_shop_cost()
    local base_cost = 100
    local num_shops = #port_a_shops
    -- Gentler exponential scaling: base_cost * (1.5^num_shops)
    return math.floor(base_cost * (1.5 ^ num_shops))
end

-- Add a new port-a-shop
local function add_port_a_shop()
    local shop_number = #port_a_shops + 1
    local target_y = shop_number * SHOP_SPACING  -- Y position based on shop number (1000, 2000, etc.)
    table.insert(port_a_shops, {
        x = 0,  -- Will be set during update
        y = target_y + 1000,  -- Start below target position
        is_spawned = false,
        is_active = false,  -- Whether player is in range to interact
        animation = create_shop_animation(target_y)
    })
    print("New port-a-shop added. Shop #" .. shop_number .. " at Y: " .. target_y)
end

-- Calculate cost for hiring crew
local function get_crew_hire_cost(current_crew)
    if current_crew < 5 then
        return 25  -- First 5 crew members cost 25 coins each
    else
        -- Start exponential scaling at 50 coins after 5 crew members
        -- Using 1.5 as the base for exponential growth
        local excess_crew = current_crew - 4  -- How many crew over the initial 5
        return math.floor(50 * (1.5 ^ excess_crew))
    end
end

-- Calculate cost for sword upgrade
local function get_sword_upgrade_cost(current_sword)
    local current_level = combat.get_sword_level(current_sword)
    -- Start exponential immediately with base cost of 25
    return math.floor(25 * (1.5 ^ (current_level - 1)))
end

-- Calculate cost for rod upgrade
local function get_rod_upgrade_cost(current_rod)
    local current_level = fishing.get_rod_level(current_rod)
    -- Start exponential immediately with base cost of 25
    return math.floor(25 * (1.5 ^ (current_level - 1)))
end

-- Calculate cost for speed upgrade
local function get_speed_upgrade_cost(current_speed)
    -- Start with base speed of 200, each upgrade adds 20
    local upgrade_level = math.floor((current_speed - 200) / 20) + 1
    -- Start exponential immediately with base cost of 25
    return math.floor(25 * (1.5 ^ (upgrade_level - 1)))
end

function shop.get_coins()
    return coins
end

-- Check if player is in range of any shop
local function check_shop_interaction(player_x, player_y, shopkeeper)
    local any_shop_active = false
    
    -- Check port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            -- Calculate if player is within the 20x20 collision box
            local in_x_range = math.abs(shop_data.x - player_x) <= 10
            local in_y_range = math.abs(shop_data.y - player_y) <= 10
            shop_data.is_active = in_x_range and in_y_range
            any_shop_active = any_shop_active or shop_data.is_active
        end
    end
    
    -- Check main shopkeeper if provided
    if shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact() then
        any_shop_active = true
    end
    
    return any_shop_active
end

function shop.update(game_state, player_ship, shopkeeper)
    -- Update shop visibility and animation based on player position with larger range
    local viewHeight = love.graphics.getHeight()
    
    for _, shop_data in ipairs(port_a_shops) do
        -- Check if shop's target y position is in view with 500 unit buffer
        local isShopVisible = math.abs(shop_data.animation.target_y - player_ship.y) <= 500
        
        if isShopVisible then
            -- If shop just came into view and isn't spawned, spawn at player's X with small offset
            if not shop_data.is_spawned then
                local spawn_offset = player_ship.velocity_x > 0 and 200 or -200
                shop_data.x = player_ship.x + spawn_offset
                shop_data.is_spawned = true
                shop_data.animation.is_animating = true
                shop_data.animation.progress = 0
                shop_data.y = shop_data.animation.start_y
                print("Port-a-shop spawned at: X=" .. shop_data.x .. ", Y=" .. shop_data.y)
            end
            
            -- Update animation
            if shop_data.animation.is_animating then
                shop_data.animation.progress = math.min(1, shop_data.animation.progress + love.timer.getDelta() / shop_data.animation.duration)
                -- Use smooth easing for the animation
                local eased_progress = 1 - (1 - shop_data.animation.progress) * (1 - shop_data.animation.progress)
                shop_data.y = shop_data.animation.start_y + (shop_data.animation.target_y - shop_data.animation.start_y) * eased_progress
                
                if shop_data.animation.progress >= 1 then
                    shop_data.animation.is_animating = false
                    shop_data.y = shop_data.animation.target_y
                end
            end
        else
            -- Shop not visible, despawn it
            if shop_data.is_spawned then
                print("Port-a-shop despawned at: X=" .. shop_data.x .. ", Y=" .. shop_data.y .. " (Player Y: " .. player_ship.y .. ")")
            end
            shop_data.is_spawned = false
        end
    end
    
    -- Check if player is in range of any shop
    local shop_active = check_shop_interaction(player_ship.x, player_ship.y, shopkeeper)
    current_state = shop_active and "shop" or ""
    
    if current_state ~= "shop" then return end
    
    -- Update message timer
    if message_timer > 0 then
        message_timer = message_timer - love.timer.getDelta()
        if message_timer <= 0 then
            show_no_fish_message = false
        end
    end
    
    -- Get window dimensions
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    
    -- Calculate layout dimensions
    local section_width = 250
    local section_height = 150
    local padding = 30
    local top_margin = 100
    
    -- Calculate grid layout
    local grid_width = section_width * 3 + padding * 2  -- 3 columns with 2 paddings between
    local grid_start_x = (window_width - grid_width) / 2  -- Center the grid horizontally
    
    -- Shop Title (centered at top)
    local title_width = 200
    suit.layout:reset((window_width - title_width) / 2, padding)
    suit.Label("SHOP", {align = "center"}, suit.layout:row(title_width, 30))
    
    -- Display current coins (centered below title)
    suit.layout:reset((window_width - title_width) / 2, padding + 40)
    suit.Label("Coins: " .. string.format("%.1f", coins), {align = "center"}, suit.layout:row(title_width, 30))
    
    -- First Row
    
    -- Fish Section (top left)
    suit.layout:reset(grid_start_x, top_margin)
    suit.Label("Fish", {align = "center"}, suit.layout:row(section_width, 30))
    local button_text = #player_ship.caught_fish > 0 and "Sell All Fish (" .. #player_ship.caught_fish .. ")" or "Sell All Fish (none)"
    if suit.Button(button_text, suit.layout:row(section_width, 30)).hit then
        if #player_ship.caught_fish > 0 then
            local total = 0
            for _, fish in ipairs(player_ship.caught_fish) do
                local fish_value = fishing.get_fish_value(fish)
                total = total + (fish_value * 0.6)
            end
            coins = coins + total
            player_ship.caught_fish = {}
            print("Sold fish for " .. total .. " coins!")
        else
            show_no_fish_message = true
            message_timer = MESSAGE_DURATION
        end
    end
    if show_no_fish_message then
        suit.Label("No fish to sell!", {align = "center"}, suit.layout:row(section_width, 20))
    end
    
    -- Crew Section (top center)
    suit.layout:reset(grid_start_x + section_width + padding, top_margin)
    suit.Label("Crew Members", {align = "center"}, suit.layout:row(section_width, 30))
    local hire_cost = get_crew_hire_cost(player_ship.men)
    if coins >= hire_cost then
        if suit.Button("Hire 1 Man (" .. hire_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            coins = coins - hire_cost
            player_ship.men = player_ship.men + 1
        end
    else
        suit.Label("Need " .. hire_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end
    suit.Label("Current Crew: " .. player_ship.men, {align = "center"}, suit.layout:row(section_width, 30))
    
    -- Sword Section (top right)
    suit.layout:reset(grid_start_x + (section_width + padding) * 2, top_margin)
    suit.Label("Sword", {align = "center"}, suit.layout:row(section_width, 30))
    local sword_cost = get_sword_upgrade_cost(player_ship.sword)
    local current_level = combat.get_sword_level(player_ship.sword)
    if coins >= sword_cost then
        if suit.Button("Upgrade Sword (" .. sword_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            coins = coins - sword_cost
            player_ship.sword = combat.get_sword_name(current_level + 1)
            print("Upgraded sword to: " .. player_ship.sword)
        end
    else
        suit.Label("Need " .. sword_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end
    suit.Label("Current: " .. player_ship.sword, {align = "center"}, suit.layout:row(section_width, 30))
    
    -- Second Row
    local row2_y = top_margin + section_height + padding
    
    -- Rod Section (bottom left)
    suit.layout:reset(grid_start_x, row2_y)
    suit.Label("Rod", {align = "center"}, suit.layout:row(section_width, 30))
    local rod_cost = get_rod_upgrade_cost(player_ship.rod)
    local current_rod_level = fishing.get_rod_level(player_ship.rod)
    if coins >= rod_cost then
        if suit.Button("Upgrade Rod (" .. rod_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            coins = coins - rod_cost
            player_ship.rod = fishing.get_rod_name(current_rod_level + 1)
            print("Upgraded rod to: " .. player_ship.rod)
        end
    else
        suit.Label("Need " .. rod_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end
    suit.Label("Current: " .. player_ship.rod, {align = "center"}, suit.layout:row(section_width, 30))
    
    -- Port-a-shop Section (bottom center)
    suit.layout:reset(grid_start_x + section_width + padding, row2_y)
    suit.Label("Port-a-Shops", {align = "center"}, suit.layout:row(section_width, 30))
    local next_shop_cost = get_next_shop_cost()
    if coins >= next_shop_cost then
        if suit.Button("Buy Port-a-Shop (" .. next_shop_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            coins = coins - next_shop_cost
            add_port_a_shop()
        end
    else
        suit.Label("Need " .. next_shop_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end
    suit.Label("Owned: " .. #port_a_shops, {align = "center"}, suit.layout:row(section_width, 30))
    
    -- Speed upgrade section (bottom right)
    suit.layout:reset(grid_start_x + (section_width + padding) * 2, row2_y)
    suit.Label("Ship Speed", {align = "center"}, suit.layout:row(section_width, 30))
    local speed_cost = get_speed_upgrade_cost(player_ship.max_speed)
    if coins >= speed_cost then
        if suit.Button("Upgrade Speed (" .. speed_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            coins = coins - speed_cost
            player_ship.max_speed = player_ship.max_speed + 20
            print("Upgraded speed to: " .. player_ship.max_speed)
        end
    else
        suit.Label("Need " .. speed_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end
    suit.Label("Current: " .. player_ship.max_speed .. " speed", {align = "center"}, suit.layout:row(section_width, 30))
end

-- Draw the physical shops in the game world
function shop.draw_shops(camera)
    -- Save current graphics state
    love.graphics.push()
    
    -- Draw horizontal divider lines every 1000 units
    -- Get viewport boundaries
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    local shoreExtension = 1000 -- Match the shore extension from game.lua
    
    -- Calculate visible range
    local startY = math.floor((camera.y - viewHeight) / 1000) * 1000
    local endY = math.ceil((camera.y + viewHeight * 2) / 1000) * 1000
    
    -- Draw divider lines
    love.graphics.setColor(0.3, 0.3, 0.5, 0.3) -- Similar to shore line but more transparent
    love.graphics.setLineWidth(2)
    for y = startY, endY, 1000 do
        love.graphics.line(
            camera.x - shoreExtension, y,
            camera.x + viewWidth + shoreExtension, y
        )
    end
    
    -- Draw port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            -- Draw the main circle
            if shop_data.is_active then
                love.graphics.setColor(0.8, 0.8, 0.2, 1)  -- Yellow when active
            else
                love.graphics.setColor(0.6, 0.6, 0.6, 1)  -- Gray when inactive
            end
            love.graphics.circle("fill", shop_data.x, shop_data.y, 15)
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Restore graphics state
    love.graphics.pop()
end

-- Draw the shop UI overlay
function shop.draw_ui()
    if current_state == "shop" then
        -- Draw full-screen semi-transparent background
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Draw UI
        suit.draw()
    end
end

function shop.reset()
    -- Clear all port-a-shops
    port_a_shops = {}
    
    -- Reset shop state
    current_state = ""
    show_no_fish_message = false
    message_timer = 0
    coins = 0
end
return shop
