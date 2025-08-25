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
    
    -- check if it's a legendary sword+n format
    local plus = string.match(sword_name, "Legendary Sword%+(%d+)")
    if plus then
        return #swords + tonumber(plus)
    end
    
    return 1  -- return basic sword level if not found
end

function combat.get_sword_name(level)
    if level <= #swords then
        return swords[level]
    else
        -- for levels beyond the highest sword, return "legendary sword+n"
        local plus = level - #swords
        return string.format("Legendary Sword+%d", plus)
    end
end

function combat.get_sword_top_rarity()
    return #swords
end

function combat.combat(crew_size, enemy_size, sword_level, top_sword_level, player_y)
    print("\nCombat Debug:")
    print("Crew Size: " .. crew_size)
    print("Enemy Size: " .. enemy_size)
    print("Sword Level: " .. sword_level)
    print("Top Sword Level: " .. top_sword_level)
    
    -- apply depth penalty to sword level
    local original_sword_level = sword_level
    if player_y then
        local depth_level = math.floor(math.abs(player_y) / 1000)
        if depth_level > 0 then
            -- calculate how much the sword is "debuffed" at this depth
            -- the deeper you go, the more the sword is weakened
            local effective_sword_level = sword_level - depth_level
            sword_level = math.max(1, effective_sword_level) -- minimum level 1
            
            print("Depth Level: " .. depth_level)
            print("Original Sword Level: " .. original_sword_level)
            print("Effective Sword Level: " .. sword_level .. " (debuffed by depth)")
        end
    end

    -- if crew_size is less than enemy_size, you lose
    if crew_size <= enemy_size then
        print("Defeat - crew smaller than enemy")
        return {
            victory = false,
            casualties = crew_size,  -- all crew members are lost
            fainted = 0
        }
    end
    
    -- check for farming penalty (10x or more crew than enemy)
    if crew_size >= enemy_size * 10 then
        -- apply harsh penalty - lose 90% of crew
        local casualties = math.floor(crew_size * 0.9)
        print("Farming penalty applied - 90% casualties")
        return {
            victory = true,
            casualties = casualties,
            fainted = 0,
            farming_penalty = true  -- flag to indicate this was a farming penalty
        }
    end
    
    -- calculate base casualty rate based on enemy size ratio
    local enemy_ratio = enemy_size / crew_size
    print("Enemy Ratio: " .. enemy_ratio)
    
    -- normalize sword effectiveness (0 to 1)
    local sword_effectiveness = sword_level / top_sword_level
    print("Sword Effectiveness: " .. sword_effectiveness)
    
    -- calculate number of rolls based on sword level
    local num_rolls = math.floor(2 + sword_level / 2)
    print("Number of Rolls: " .. num_rolls)
    local best_roll = 1
    
    -- multiple rolls system - better swords get more chances for good outcomes
    for i = 1, num_rolls do
        -- base casualty calculation (20% to 60% of enemy size)
        local roll = math.random(20, 60) / 100
        
        -- apply sword bias: better swords reduce casualties
        local sword_bonus = sword_effectiveness * 0.4  -- up to 40% reduction
        roll = roll * (1 - sword_bonus)
        print("Roll " .. i .. ": " .. roll .. " (after " .. (sword_bonus * 100) .. "% sword reduction)")
        
        -- keep the best (lowest) roll
        best_roll = math.min(best_roll, roll)
    end
    print("Best Roll: " .. best_roll)
    
    -- calculate fainted using equation: (their_men - 1) * random(0.7 to 1.0)
    local base_fainted = enemy_size - 1
    local random_multiplier = 0.7 + (math.random() * 0.3)  -- 0.7 to 1.0
    local fainted = math.floor(base_fainted * random_multiplier)
    
    -- calculate actual casualties based on best_roll and crew advantage
    local base_casualties = math.ceil(enemy_size * best_roll)
    
    -- A larger crew directly reduces the number of casualties
    local crew_advantage = (crew_size / enemy_size) - 1 -- e.g., 18/6 = 3, advantage = 2
    local crew_reduction = math.floor(base_casualties * (1 - (1 / (1 + crew_advantage))))
    local actual_casualties = math.max(0, base_casualties - crew_reduction)
    
    -- better swords reduce our casualties (deaths), not enemy fainted count
    local sword_reduction = math.floor(sword_effectiveness * 2)  -- up to 2 reduction with best sword
    actual_casualties = math.max(0, actual_casualties - sword_reduction)
    
    -- better swords can prevent casualties entirely
    if actual_casualties > 0 and sword_level >= 3 then  -- great sword or better
        if math.random(1, 10) <= sword_level then  -- higher level = better chance to prevent death
            actual_casualties = 0
        end
    end
    
    print("Enemy Fainted: " .. fainted)
    print("Our Casualties (before sword reduction): " .. (actual_casualties + sword_reduction))
    print("Sword Reduction: " .. sword_reduction) 
    print("Final Casualties: " .. actual_casualties)
    
    return {
        victory = true,
        casualties = actual_casualties,
        fainted = fainted
    }
end

return combat