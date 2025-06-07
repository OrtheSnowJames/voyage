local fishing = {}

local fish = {
    -- common freshwater fish
    "Bluegill",
    "Crappie",
    "Yellow Perch",
    "Bullhead Catfish",
    
    -- popular game fish
    "Largemouth Bass",
    "Smallmouth Bass",
    "Channel Catfish",
    "Common Carp",
    "Mirror Carp",
    
    -- prized game fish
    "Northern Pike",
    "Walleye",
    "Rainbow Trout",
    "Brown Trout",
    "Brook Trout",
    
    -- rare/trophy fish
    "Flathead Catfish",
    "Lake Trout",
    "Grass Carp",
    "Cutthroat Trout",
    "Sauger",
    
    -- very rare/exotic
    "Muskellunge (Muskie)",
    "Arctic Char",
    "Paddlefish",
    "Tilapia",
    "Oscar",
    
    -- ultra rare/legendary
    "Peacock Bass",
    "Piranha",
    "Arowana",
    "Snakehead",
    "Sturgeon"
}

-- night-only rare fish (only available after 8:00)
local rare_night_fish = {
    "Twilight Pike",
    "Glassfin Monarch",
    "Eclipsed Lanternfish",
    "Ashscale Marlin",
    "Starbone Eel",
    "Vermillion Snapjaw",
    "Crimson Daggerfish",
    "Phantom Koi",
    "Abyssal Goldtail",
    "Frostgill Leviathan",
    "Obsidian Sunfish",
    "Echofin Halibut",
    "Wraithfin Thresher",
    "Moonlace Carp",
    "Radiant Chimerafish"
}

-- special legendary fish
local special_fish = {
    "Gold Sturgeon" -- ultra rare fish only available after 11:30 with 1% chance
}

local rods = {
    "Basic Rod",
    "Good Rod",
    "Great Rod",
    "Super Rod",
    "Ultra Rod",
    "Master Rod",
    "Legendary Rod",
}

function fishing.get_rod_level(rod_name)
    -- check if it's a base rod type
    for i, v in ipairs(rods) do
        if v == rod_name then
            return i
        end
    end
    
    -- check if it's a legendary rod+n format
    local plus = string.match(rod_name, "Legendary Rod%+(%d+)")
    if plus then
        return #rods + tonumber(plus)
    end
    
    return 1  -- return basic rod level if not found
end

function fishing.get_rod_name(level)
    if level <= #rods then
        return rods[level]
    else
        -- for levels beyond the highest rod, return "legendary rod+n"
        local plus = level - #rods
        return string.format("Legendary Rod+%d", plus)
    end
end

function fishing.get_rod_rarity(rod)
    return fishing.get_rod_level(rod)
end

function fishing.get_rod_top_rarity()
    return #rods
end

function fishing.get_all_fish()
    local all_fish = {}
    -- copy regular fish
    for _, fish_name in ipairs(fish) do
        table.insert(all_fish, fish_name)
    end
    -- copy night fish
    for _, fish_name in ipairs(rare_night_fish) do
        table.insert(all_fish, fish_name)
    end
    -- copy special fish
    for _, fish_name in ipairs(special_fish) do
        table.insert(all_fish, fish_name)
    end
    return all_fish
end

-- check if a fish is a special fish that triggers events
function fishing.is_special_fish(fish_name)
    for _, special in ipairs(special_fish) do
        if fish_name == special then
            return true
        end
    end
    return false
end

-- get available fish based on y position and time of day
-- each 1000 units deeper unlocks better fish with a sliding window
function fishing.get_fish_avalible(x, y, game_time)
    -- round to nearest 1000
    local depth_level = math.floor(math.abs(y) / 1000)
    if depth_level < 1 then depth_level = 1 end -- minimum depth level is 1
    
    -- create a window of available fish (3 types)
    local start_index = depth_level  -- start from depth level
    local end_index = start_index + 2  -- get 3 fish types
    
    -- ensure we don't go out of bounds
    if end_index > #fish then
        end_index = #fish
        start_index = end_index - 2
    end
    
    -- create array of available fish
    local available_fish = {}
    for i = start_index, end_index do
        table.insert(available_fish, fish[i])
    end
    
    -- add night fish if it's after 8:00
    if game_time then
        local time_of_day = (game_time / (12 * 60)) * 12 -- convert to 12-hour format
        if time_of_day >= 8 then
            -- add one night fish based on depth (similar to regular fish distribution)
            local night_fish_index = math.min(depth_level, #rare_night_fish)
            table.insert(available_fish, rare_night_fish[night_fish_index])
            
            -- deeper levels have a chance for a second night fish
            if depth_level > 2 and math.random() < 0.5 then
                local second_index = math.min(night_fish_index + 1, #rare_night_fish)
                table.insert(available_fish, rare_night_fish[second_index])
            end
        end
        
        -- special gold sturgeon available after 11:30
        if time_of_day >= 11.5 and math.random() < 0.01 then  -- 1% chance
            table.insert(available_fish, "Gold Sturgeon")
        end
    end
    
    return available_fish
end

function fishing.fish(rod_rarity, top_rarity, fish_available, player_y)
    -- ensure valid input ranges
    rod_rarity = math.min(math.max(1, rod_rarity), top_rarity)
    
    -- apply depth penalty to rod level
    local original_rod_rarity = rod_rarity
    if player_y then
        local depth_level = math.floor(math.abs(player_y) / 1000)
        if depth_level > 0 then
            -- calculate how much the rod is "debuffed" at this depth
            -- the deeper you go, the more the rod is weakened
            local effective_rod_rarity = rod_rarity - depth_level
            rod_rarity = math.max(1, effective_rod_rarity) -- minimum level 1
            
            print("Fishing at depth level: " .. depth_level)
            print("Original rod level: " .. original_rod_rarity)
            print("Effective rod level: " .. rod_rarity .. " (debuffed by depth)")
        end
    end
    
    -- ensure fish_available is valid
    if not fish_available or #fish_available == 0 then
        return fish[1]  -- return most common fish if no fish available
    end
    
    -- check for gold sturgeon in available fish (it has special handling)
    for _, f in ipairs(fish_available) do
        if f == "Gold Sturgeon" and math.random() < 0.01 then  -- additional 1% chance check
            return "Gold Sturgeon"  -- very rare, but guaranteed if it passes both chance checks
        end
    end
    
    -- generate multiple rolls and take the best one
    -- better rods get more rolls, increasing chances of rare fish
    local num_rolls = math.floor(1 + rod_rarity / 2)
    local best_catch = 1
    
    for i = 1, num_rolls do
        -- base random roll - heavily weighted towards common fish
        local roll = math.random(1, math.max(2, math.floor(#fish_available * 0.4)))
        
        -- apply small rod bias for better rods
        -- even with best rod, still high chance of common fish
        local bias = math.floor((rod_rarity / top_rarity) * math.random(0, #fish_available * 0.3))
        roll = math.min(roll + bias, #fish_available)
        
        -- keep track of best roll
        best_catch = math.max(best_catch, roll)
    end
    
    return fish_available[best_catch]
end

-- add this new function to get a fish's value
function fishing.get_fish_value(fish_name)
    -- special case for gold sturgeon
    if fish_name == "Gold Sturgeon" then
        return 100000  -- 100,000 coins
    end
    
    -- find the fish in the complete list and return its index
    for i, f in ipairs(fish) do
        if f == fish_name then
            return i
        end
    end
    
    -- check night fish if not found in regular fish
    for i, f in ipairs(rare_night_fish) do
        if f == fish_name then
            return #fish + i  -- higher value than regular fish
        end
    end
    
    return 1  -- return 1 if fish not found (shouldn't happen)
end

-- debug function to show available fish at a depth
function fishing.debug_fish_at_depth(y, game_time)
    local available = fishing.get_fish_avalible(0, y, game_time)
    print("at depth " .. y .. " (level " .. math.floor(math.abs(y)/1000) .. "), you can catch:")
    for i, fish_name in ipairs(available) do
        -- check if it's a night fish
        local is_night_fish = false
        for _, night_fish in ipairs(rare_night_fish) do
            if fish_name == night_fish then
                is_night_fish = true
                break
            end
        end
        
        if is_night_fish then
            print("  - " .. fish_name .. " (night fish, only after 8:00)")
        else
            print("  - " .. fish_name)
        end
    end
    
    -- show current time info if provided
    if game_time then
        local time_of_day = (game_time / (12 * 60)) * 12
        local hours = math.floor(time_of_day)
        local minutes = math.floor((time_of_day - hours) * 60)
        print(string.format("Current time: %02d:%02d", hours, minutes))
        
        if time_of_day < 8 then
            print("Night fish will become available after 8:00")
        end
    end
end

return fishing