local shop = {}
local suit = require "SUIT"
local fishing = require("game.fishing")
local combat = require("game.combat")  -- add combat module

-- player's inventory (should be moved to a proper inventory system later)
local coins = 0
local current_state = ""  -- store the current game state
local show_no_fish_message = false
local message_timer = 0
local MESSAGE_DURATION = 2  -- how long to show the message

-- inventory ui state
local inventory_state = {
    mode = "",  -- "", "transfer", "view"
    search_text = {text = ""},
    selected_fish = nil,
    filtered_fish = {},
    scroll_offset = 0
}

-- port-a-shop configuration
local SHOP_SPACING = 1000  -- distance between shops (changed from 40)
local SHOP_SIZE = { width = 60, height = 40 }  -- size of the shop platform
local INTERACTION_RANGE = 50  -- how close the player needs to be to interact
local SHOP_ANIMATION_SPEED = 500  -- speed of shop movement in pixels per second

-- port-a-shops state
local port_a_shops = {}

-- load shopkeeper sprite
local shopkeeper_sprite = love.graphics.newImage("assets/shopkeeper.png")
local sprite_frame_width = 32
local sprite_frame_height = 32
local animation_frame_time = 0.5 -- 500ms per frame
local total_frames = 2

-- animation state for each shop
local function create_shop_animation(target_y)
    return {
        start_y = target_y + 1000,  -- start 1000 pixels below target
        target_y = target_y,
        progress = 0,  -- 0 to 1
        duration = 2,  -- animation duration in seconds
        is_animating = true,
        -- frame animation
        current_frame = 1,
        frame_timer = 0
    }
end

-- calculate cost for next port-a-shop
local function get_next_shop_cost()
    local base_cost = 100
    local num_shops = #port_a_shops
    -- gentler exponential scaling: base_cost * (1.5^num_shops)
    return math.floor(base_cost * (1.5 ^ num_shops))
end

-- add a new port-a-shop
local function add_port_a_shop()
    local shop_number = #port_a_shops + 1
    local target_y = shop_number * SHOP_SPACING  -- y position based on shop number (1000, 2000, etc.)
    table.insert(port_a_shops, {
        x = 0,  -- will be set during update
        y = target_y + 1000,  -- start below target position
        is_spawned = false,
        is_active = false,  -- whether player is in range to interact
        animation = create_shop_animation(target_y)
    })
    print("New port-a-shop added. Shop #" .. shop_number .. " at Y: " .. target_y)
end

-- calculate cost for hiring crew
local function get_crew_hire_cost(current_crew)
    if current_crew < 5 then
        return 25  -- first 5 crew members cost 25 coins each
    else
        -- start exponential scaling at 50 coins after 5 crew members
        -- using 1.5 as the base for exponential growth
        local excess_crew = current_crew - 4  -- how many crew over the initial 5
        return math.floor(50 * (1.5 ^ excess_crew))
    end
end

-- calculate cost for sword upgrade
local function get_sword_upgrade_cost(current_sword)
    local current_level = combat.get_sword_level(current_sword)
    -- start exponential immediately with base cost of 25
    return math.floor(25 * (1.5 ^ (current_level - 1)))
end

-- calculate cost for rod upgrade
local function get_rod_upgrade_cost(current_rod)
    local current_level = fishing.get_rod_level(current_rod)
    -- start exponential immediately with base cost of 25
    return math.floor(25 * (1.5 ^ (current_level - 1)))
end

-- calculate cost for speed upgrade
local function get_speed_upgrade_cost(current_speed)
    -- start with base speed of 200, each upgrade adds 20
    local upgrade_level = math.floor((current_speed - 200) / 20) + 1
    -- start exponential immediately with base cost of 25
    return math.floor(25 * (1.5 ^ (upgrade_level - 1)))
end

-- filter fish based on search text
local function filter_fish(fish_list, search_text)
    if search_text == "" then
        return fish_list
    end
    
    local filtered = {}
    local search_lower = string.lower(search_text)
    for _, fish in ipairs(fish_list) do
        if string.find(string.lower(fish), search_lower) then
            table.insert(filtered, fish)
        end
    end
    return filtered
end

-- count fish in inventory
local function count_fish_in_inventory(fish_name, inventory)
    local count = 0
    for _, fish in ipairs(inventory) do
        if fish == fish_name then
            count = count + 1
        end
    end
    return count
end

function shop.get_coins()
    return coins
end

-- check if player is in range of any shop
local function check_shop_interaction(player_x, player_y, shopkeeper)
    local any_shop_active = false
    
    -- check port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            -- calculate if player is within range of the shopkeeper sprite
            -- using an extended interaction range for easier access
            local distance = math.sqrt((shop_data.x - player_x)^2 + (shop_data.y - player_y)^2)
            local interaction_range = 75 -- increased from sprite size to a larger fixed value
            shop_data.is_active = distance <= interaction_range
            any_shop_active = any_shop_active or shop_data.is_active
        end
    end
    
    -- check main shopkeeper if provided
    if shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact() then
        any_shop_active = true
    end
    
    return any_shop_active
end

function shop.update(game_state, player_ship, shopkeeper)
    -- update animation timers for all shops
    local dt = love.timer.getDelta()
    
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            -- ensure animation structure exists (for backwards compatibility)
            if not shop_data.animation or not shop_data.animation.current_frame then
                shop_data.animation = create_shop_animation(shop_data.y)
            end
            
            -- update frame animation
            shop_data.animation.frame_timer = shop_data.animation.frame_timer + dt
            if shop_data.animation.frame_timer >= animation_frame_time then
                shop_data.animation.frame_timer = shop_data.animation.frame_timer - animation_frame_time
                shop_data.animation.current_frame = shop_data.animation.current_frame % total_frames + 1
            end
        end
    end
    
    -- update shop visibility and animation based on player position with larger range
    local viewHeight = love.graphics.getHeight()
    
    for _, shop_data in ipairs(port_a_shops) do
        -- check if shop's target y position is in view with 500 unit buffer
        local isShopVisible = math.abs(shop_data.animation.target_y - player_ship.y) <= 500
        
        if isShopVisible then
            -- if shop just came into view and isn't spawned, spawn at player's x with small offset
            if not shop_data.is_spawned then
                local spawn_offset = player_ship.velocity_x > 0 and 200 or -200
                shop_data.x = player_ship.x + spawn_offset
                shop_data.is_spawned = true
                shop_data.animation.is_animating = true
                shop_data.animation.progress = 0
                shop_data.y = shop_data.animation.start_y
                print("Port-a-shop spawned at: X=" .. shop_data.x .. ", Y=" .. shop_data.y)
            end
            
            -- update animation
            if shop_data.animation.is_animating then
                shop_data.animation.progress = math.min(1, shop_data.animation.progress + love.timer.getDelta() / shop_data.animation.duration)
                -- use smooth easing for the animation
                local eased_progress = 1 - (1 - shop_data.animation.progress) * (1 - shop_data.animation.progress)
                shop_data.y = shop_data.animation.start_y + (shop_data.animation.target_y - shop_data.animation.start_y) * eased_progress
                
                if shop_data.animation.progress >= 1 then
                    shop_data.animation.is_animating = false
                    shop_data.y = shop_data.animation.target_y
                end
            end
        else
            -- shop not visible, despawn it
            if shop_data.is_spawned then
                print("Port-a-shop despawned at: X=" .. shop_data.x .. ", Y=" .. shop_data.y .. " (Player Y: " .. player_ship.y .. ")")
            end
            shop_data.is_spawned = false
        end
    end
    
    -- check if player is in range of any shop
    local shop_active = check_shop_interaction(player_ship.x, player_ship.y, shopkeeper)
    current_state = shop_active and "shop" or ""
    
    if current_state ~= "shop" then return end
    
    -- update message timer
    if message_timer > 0 then
        message_timer = message_timer - love.timer.getDelta()
        if message_timer <= 0 then
            show_no_fish_message = false
        end
    end
    
    -- get window dimensions
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    
    if inventory_state.mode == "transfer" then
        -- transfer interface
        suit.layout:reset(window_width/2 - 300, 50)
        suit.Label("Transfer Fish to Inventory (5 coins each)", {align = "center"}, suit.layout:row(600, 30))
        suit.Label("Current Coins: " .. string.format("%.1f", coins), {align = "center"}, suit.layout:row(600, 30))
        
        -- search box
        suit.layout:reset(window_width/2 - 200, 120)
        suit.Label("Search fish:", {align = "left"}, suit.layout:row(400, 30))
        local input_result = suit.Input(inventory_state.search_text, suit.layout:row(400, 30))
        if input_result.submitted or input_result.changed then
            -- update filtered list when search changes
            local all_fish = {}
            for _, fish in ipairs(player_ship.caught_fish) do
                table.insert(all_fish, fish)
            end
            inventory_state.filtered_fish = filter_fish(all_fish, inventory_state.search_text.text)
        end
        
        -- fish list
        suit.layout:reset(window_width/2 - 200, 200)
        suit.Label("Select fish to transfer:", {align = "left"}, suit.layout:row(400, 30))
        
        local unique_fish = {}
        local fish_counts = {}
        for _, fish in ipairs(inventory_state.filtered_fish) do
            if not fish_counts[fish] then
                fish_counts[fish] = 0
                table.insert(unique_fish, fish)
            end
            fish_counts[fish] = fish_counts[fish] + 1
        end
        
        for i, fish in ipairs(unique_fish) do
            local button_text = fish .. " (" .. fish_counts[fish] .. ")"
            if coins >= 5 then
                if suit.Button(button_text, suit.layout:row(400, 30)).hit then
                    -- transfer one fish
                    coins = coins - 5
                    table.insert(player_ship.inventory, fish)
                    -- remove one instance from caught_fish
                    for j, caught_fish in ipairs(player_ship.caught_fish) do
                        if caught_fish == fish then
                            table.remove(player_ship.caught_fish, j)
                            break
                        end
                    end
                    -- update filtered list
                    local all_fish = {}
                    for _, f in ipairs(player_ship.caught_fish) do
                        table.insert(all_fish, f)
                    end
                    inventory_state.filtered_fish = filter_fish(all_fish, inventory_state.search_text.text)
                    print("Transferred " .. fish .. " to inventory!")
                end
            else
                suit.Label(button_text .. " - Need 5 coins", {align = "left"}, suit.layout:row(400, 30))
            end
        end
        
        -- back button
        suit.layout:reset(window_width/2 - 100, window_height - 100)
        if suit.Button("Back", suit.layout:row(200, 30)).hit then
            inventory_state.mode = ""
        end
        
    elseif inventory_state.mode == "view" then
        -- view inventory interface
        suit.layout:reset(window_width/2 - 300, 50)
        suit.Label("Fish Inventory", {align = "center"}, suit.layout:row(600, 40))
        
        -- count unique fish in inventory
        local inventory_counts = {}
        local unique_inventory = {}
        for _, fish in ipairs(player_ship.inventory) do
            if not inventory_counts[fish] then
                inventory_counts[fish] = 0
                table.insert(unique_inventory, fish)
            end
            inventory_counts[fish] = inventory_counts[fish] + 1
        end
        
        -- scroll controls
        local items_per_page = 12  -- how many fish to show at once
        local max_scroll = math.max(0, #unique_inventory - items_per_page)
        
        suit.layout:reset(window_width/2 - 200, 120)
        if #unique_inventory == 0 then
            suit.Label("Inventory is empty", {align = "center"}, suit.layout:row(400, 30))
        else
            -- scroll up button
            if inventory_state.scroll_offset > 0 then
                if suit.Button("▲ Scroll Up", suit.layout:row(400, 30)).hit then
                    inventory_state.scroll_offset = math.max(0, inventory_state.scroll_offset - 3)
                end
            else
                suit.Label("", {align = "center"}, suit.layout:row(400, 30)) -- spacer
            end
            
            -- display fish list with scrolling
            local start_index = inventory_state.scroll_offset + 1
            local end_index = math.min(start_index + items_per_page - 1, #unique_inventory)
             
            local current_y = 180  -- start y position after scroll up button
            for i = start_index, end_index do
                local fish = unique_inventory[i]
                local fish_value = fishing.get_fish_value(fish)
                
                -- fish info on left side
                suit.layout:reset(window_width/2 - 200, current_y)
                suit.Label(fish .. " x" .. inventory_counts[fish] .. " (Value: " .. fish_value .. " each)", 
                          {align = "left"}, suit.layout:row(280, 30))
                
                -- deposit button on right side
                suit.layout:reset(window_width/2 + 90, current_y)
                if suit.Button("Deposit", suit.layout:row(80, 30)).hit then
                    -- remove one fish from inventory
                    for j, inv_fish in ipairs(player_ship.inventory) do
                        if inv_fish == fish then
                            table.remove(player_ship.inventory, j)
                            break
                        end
                    end
                    -- add to caught_fish
                    table.insert(player_ship.caught_fish, fish)
                    
                    -- update counts for display
                    inventory_counts[fish] = inventory_counts[fish] - 1
                    if inventory_counts[fish] <= 0 then
                        -- remove from unique_inventory if count reaches 0
                        for k, unique_fish in ipairs(unique_inventory) do
                            if unique_fish == fish then
                                table.remove(unique_inventory, k)
                                break
                            end
                        end
                        -- adjust scroll if needed
                        local max_scroll = math.max(0, #unique_inventory - items_per_page)
                        inventory_state.scroll_offset = math.min(inventory_state.scroll_offset, max_scroll)
                    end
                    
                    print("Deposited " .. fish .. " to caught fish!")
                end
                
                -- move to next row
                current_y = current_y + 35
            end
            
            -- scroll down button
            if inventory_state.scroll_offset < max_scroll then
                if suit.Button("▼ Scroll Down", suit.layout:row(400, 30)).hit then
                    inventory_state.scroll_offset = math.min(max_scroll, inventory_state.scroll_offset + 3)
                end
            else
                suit.Label("", {align = "center"}, suit.layout:row(400, 30)) -- spacer
            end
            
            -- show scroll position indicator
            if #unique_inventory > items_per_page then
                local scroll_info = string.format("Showing %d-%d of %d fish", start_index, end_index, #unique_inventory)
                suit.Label(scroll_info, {align = "center"}, suit.layout:row(400, 20))
            end
        end
        
        -- back button
        suit.layout:reset(window_width/2 - 100, window_height - 100)
        if suit.Button("Back", suit.layout:row(200, 30)).hit then
            inventory_state.mode = ""
            inventory_state.scroll_offset = 0  -- reset scroll when leaving
        end
        
    else
        -- regular shop interface (only when inventory_state.mode == "")
    
    -- calculate layout dimensions
    local section_width = 250
    local section_height = 150
    local padding = 30
    local top_margin = 100
    
    -- calculate grid layout
    local grid_width = section_width * 3 + padding * 2  -- 3 columns with 2 paddings between
    local grid_start_x = (window_width - grid_width) / 2  -- center the grid horizontally
    
    -- shop title (centered at top)
    local title_width = 200
    suit.layout:reset((window_width - title_width) / 2, padding)
    suit.Label("SHOP", {align = "center"}, suit.layout:row(title_width, 30))
    
    -- display current coins (centered below title)
    suit.layout:reset((window_width - title_width) / 2, padding + 40)
    suit.Label("Coins: " .. string.format("%.1f", coins), {align = "center"}, suit.layout:row(title_width, 30))
    
    -- first row
    
    -- fish section (top left)
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
    
    -- crew section (top center)
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
    
    -- sword section (top right)
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
    
    -- second row
    local row2_y = top_margin + section_height + padding
    
    -- rod section (bottom left)
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
    
    -- port-a-shop section (bottom center)
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
    
    -- speed upgrade section (bottom right)
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
    
    -- third row
    local row3_y = row2_y + section_height + padding
    
    -- healing section (third row left)
    suit.layout:reset(grid_start_x, row3_y)
    suit.Label("Pharmacy", {align = "center"}, suit.layout:row(section_width, 30))
    local healing_cost = player_ship.fainted_men * 10
    if player_ship.fainted_men > 0 then
        if coins >= healing_cost then
            if suit.Button("Heal Fainted Crew (" .. healing_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                coins = coins - healing_cost
                player_ship.men = player_ship.men + player_ship.fainted_men
                print("Healed " .. player_ship.fainted_men .. " crew members!")
                player_ship.fainted_men = 0
            end
        else
            suit.Label("Need " .. healing_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
    else
        suit.Label("No fainted crew", {align = "center"}, suit.layout:row(section_width, 30))
    end
    suit.Label("Fainted: " .. player_ship.fainted_men, {align = "center"}, suit.layout:row(section_width, 30))
    
    -- inventory section (third row center)
    suit.layout:reset(grid_start_x + section_width + padding, row3_y)
    suit.Label("Fish Inventory", {align = "center"}, suit.layout:row(section_width, 30))
    if suit.Button("Transfer to Inventory", suit.layout:row(section_width, 30)).hit then
        inventory_state.mode = "transfer"
        inventory_state.search_text.text = ""
        inventory_state.selected_fish = nil
        -- create filtered fish list
        inventory_state.filtered_fish = {}
        for _, fish in ipairs(player_ship.caught_fish) do
            table.insert(inventory_state.filtered_fish, fish)
        end
    end
    if suit.Button("View Inventory", suit.layout:row(section_width, 30)).hit then
        inventory_state.mode = "view"
    end
    
    end -- close the else block for regular shop interface
end

-- draw the physical shops in the game world
function shop.draw_shops(camera)
    -- save current graphics state
    love.graphics.push()
    
    -- draw horizontal divider lines every 1000 units
    -- get viewport boundaries
    local viewWidth = love.graphics.getWidth() / camera.scale
    local viewHeight = love.graphics.getHeight() / camera.scale
    local shoreExtension = 1000 -- match the shore extension from game.lua
    
    -- calculate visible range
    local startY = math.floor((camera.y - viewHeight) / 1000) * 1000
    local endY = math.ceil((camera.y + viewHeight * 2) / 1000) * 1000
    
    -- draw divider lines
    love.graphics.setColor(0.3, 0.3, 0.5, 0.3) -- similar to shore line but more transparent
    love.graphics.setLineWidth(2)
    for y = startY, endY, 1000 do
        love.graphics.line(
            camera.x - shoreExtension, y,
            camera.x + viewWidth + shoreExtension, y
        )
    end
    
    -- draw port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            -- ensure animation structure exists (for backwards compatibility)
            if not shop_data.animation or not shop_data.animation.current_frame then
                shop_data.animation = create_shop_animation(shop_data.y)
            end
            
            -- create quad for the current frame
            local quad = love.graphics.newQuad(
                (shop_data.animation.current_frame - 1) * sprite_frame_width, 
                0, 
                sprite_frame_width, 
                sprite_frame_height, 
                shopkeeper_sprite:getWidth(), 
                shopkeeper_sprite:getHeight()
            )
            
            -- set color based on interaction state
            if shop_data.is_active then
                -- yellow tint when active (replace white with yellow)
                love.graphics.setColor(1, 1, 0)
            else
                -- normal coloring
                love.graphics.setColor(1, 1, 1)
            end
            
            -- draw the sprite
            love.graphics.draw(
                shopkeeper_sprite, 
                quad, 
                shop_data.x, 
                shop_data.y, 
                0, -- rotation
                1, -- scale x
                1, -- scale y
                sprite_frame_width/2, -- origin x (center)
                sprite_frame_height/2 -- origin y (center)
            )
            
            -- reset color
            love.graphics.setColor(1, 1, 1, 1)
            
            -- draw "shop" text above shopkeeper when active
            if shop_data.is_active then
                love.graphics.print("SHOP", shop_data.x - 20, shop_data.y - sprite_frame_height)
            end
        end
    end
    
    -- restore graphics state
    love.graphics.pop()
end

-- draw the shop ui overlay
function shop.draw_ui()
    if current_state == "shop" then
        -- draw full-screen semi-transparent background (darker for inventory)
        local alpha = inventory_state.mode ~= "" and 0.9 or 0.85
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        
        -- draw ui
        suit.draw()
    end
end

function shop.reset()
    -- clear all port-a-shops
    port_a_shops = {}
    
    -- reset shop state
    current_state = ""
    show_no_fish_message = false
    message_timer = 0
    coins = 0
    
    -- reset inventory state
    inventory_state.mode = ""
    inventory_state.search_text.text = ""
    inventory_state.selected_fish = nil
    inventory_state.filtered_fish = {}
end

-- get port-a-shops data for saving
function shop.get_port_a_shops_data()
    return {
        port_a_shops = port_a_shops,
        coins = coins
    }
end

-- set port-a-shops data from save
function shop.set_port_a_shops_data(data)
    if data.port_a_shops then
        port_a_shops = data.port_a_shops
    end
    if data.coins then
        coins = data.coins
    end
end

return shop
