local combat = {}

local swords = {
    "Basic Sword",
    "Good Sword",
    "Great Sword",
    "Super Sword",
    "Ultra Sword",
    "Master Sword",
    "Legendary Sword",
}

function combat.get_swords()
    return swords
end

function combat.get_sword_level(sword_name)
    -- check if it's a base sword type
    for i, v in ipairs(swords) do
        if v == sword_name then
            return i
        end
    end
    
    -- check if it's a Legendary Sword+N format
    local base, plus = string.match(sword_name, "Legendary Sword%+(%d+)")
    if plus then
        return #swords + tonumber(plus)
    end
    
    return 1  -- return basic sword level if not found
end

function combat.get_sword_name(level)
    if level <= #swords then
        return swords[level]
    else
        -- for levels beyond the highest sword, return "Legendary Sword+N"
        local plus = level - #swords
        return string.format("Legendary Sword+%d", plus)
    end
end

function combat.get_sword_top_rarity()
    return #swords
end

function combat.combat(crew_size, enemy_size, sword_level, top_sword_level)
    -- if crew_size is less than enemy_size, you lose
    if crew_size <= enemy_size then
        return {
            victory = false,
            casualties = crew_size,  -- all crew members are lost
            fainted = 0
        }
    end
    
    -- calculate base casualty rate based on enemy size ratio
    local enemy_ratio = enemy_size / crew_size
    
    -- normalize sword effectiveness (0 to 1)
    local sword_effectiveness = sword_level / top_sword_level
    
    -- calculate number of rolls based on sword level
    local num_rolls = math.floor(2 + sword_level / 2)
    local best_roll = 1
    
    -- multiple rolls system - better swords get more chances for good outcomes
    for i = 1, num_rolls do
        -- base casualty calculation (20% to 60% of enemy size)
        local roll = math.random(20, 60) / 100
        
        -- apply sword bias: better swords reduce casualties
        local sword_bonus = sword_effectiveness * 0.4  -- up to 40% reduction
        roll = roll * (1 - sword_bonus)
        
        -- keep the best (lowest) roll
        best_roll = math.min(best_roll, roll)
    end
    
    -- calculate final casualties
    local total_casualties = math.floor(enemy_size * best_roll * enemy_ratio)
    
    -- ensure we don't lose more than we have
    total_casualties = math.min(total_casualties, crew_size - 1)  -- always keep at least 1 crew
    
    -- calculate how many are just fainted vs actual casualties
    local faint_ratio = sword_effectiveness * 0.8  -- up to 80% of casualties can be fainted instead
    local fainted = math.floor(total_casualties * faint_ratio)
    local actual_casualties = total_casualties - fainted
    
    return {
        victory = true,
        casualties = actual_casualties,
        fainted = fainted
    }
end

return combat