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
    
    -- check if it's a Legendary Rod+N format
    local base, plus = string.match(rod_name, "Legendary Rod%+(%d+)")
    if plus then
        return #rods + tonumber(plus)
    end
    
    return 1  -- return basic rod level if not found
end

function fishing.get_rod_name(level)
    if level <= #rods then
        return rods[level]
    else
        -- for levels beyond the highest rod, return "Legendary Rod+N"
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

-- get available fish based on Y position
-- each 1000 units deeper unlocks better fish with a sliding window
function fishing.get_fish_avalible(x, y)
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
    
    return available_fish
end

function fishing.fish(rod_rarity, top_rarity, fish_available)
    -- ensure valid input ranges
    rod_rarity = math.min(math.max(1, rod_rarity), top_rarity)
    
    -- ensure fish_available is valid
    if not fish_available or #fish_available == 0 then
        return fish[1]  -- return most common fish if no fish available
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
    -- find the fish in the complete list and return its index
    for i, f in ipairs(fish) do
        if f == fish_name then
            return i
        end
    end
    return 1  -- return 1 if fish not found (shouldn't happen)
end

-- debug function to show available fish at a depth
function fishing.debug_fish_at_depth(y)
    local available = fishing.get_fish_avalible(0, y)
    print("at depth " .. y .. " (level " .. math.floor(math.abs(y)/1000) .. "), you can catch:")
    for i, fish_name in ipairs(available) do
        print("  - " .. fish_name)
    end
end

return fishing