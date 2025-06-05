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
    print("\nCombat Debug:")
    print("Crew Size: " .. crew_size)
    print("Enemy Size: " .. enemy_size)
    print("Sword Level: " .. sword_level)
    print("Top Sword Level: " .. top_sword_level)

    -- if crew_size is less than enemy_size, you lose
    if crew_size <= enemy_size then
        print("Defeat - crew smaller than enemy")
        return {
            victory = false,
            casualties = crew_size,  -- all crew members are lost
            fainted = 0
        }
    end
    
    -- Check for farming penalty (10x or more crew than enemy)
    if crew_size >= enemy_size * 10 then
        -- Apply harsh penalty - lose 90% of crew
        local casualties = math.floor(crew_size * 0.9)
        print("Farming penalty applied - 90% casualties")
        return {
            victory = true,
            casualties = casualties,
            fainted = 0,
            farming_penalty = true  -- Flag to indicate this was a farming penalty
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
    
    -- calculate final casualties
    local total_casualties = math.floor(enemy_size * best_roll * enemy_ratio)
    print("Total Casualties (before minimum): " .. total_casualties)
    
    -- Ensure there are always some consequences to combat
    -- At least 10% of enemy size will be casualties+fainted, minimum 1
    local minimum_consequences = math.max(1, math.floor(enemy_size * 0.1))
    total_casualties = math.max(minimum_consequences, total_casualties)
    
    -- ensure we don't lose more than we have
    total_casualties = math.min(total_casualties, crew_size - 1)  -- always keep at least 1 crew
    print("Total Casualties (after min/cap): " .. total_casualties)
    
    -- calculate how many are just fainted vs actual casualties
    -- Increase base faint ratio to make swords more effective at preventing deaths
    local base_faint_ratio = 0.6  -- 60% base chance to faint instead of die
    local faint_ratio = base_faint_ratio + (sword_effectiveness * 0.4)  -- up to 100% with best sword
    local fainted = math.floor(total_casualties * faint_ratio)
    local actual_casualties = total_casualties - fainted
    
    -- Ensure at least one consequence if we had any total casualties
    if total_casualties > 0 and fainted == 0 and actual_casualties == 0 then
        fainted = 1
    end
    
    -- Ensure at least one fainted with any sword
    if total_casualties > 0 and sword_level > 0 and fainted == 0 then
        fainted = 1
        actual_casualties = math.max(0, total_casualties - 1)
    end
    
    print("Faint Ratio: " .. faint_ratio)
    print("Fainted: " .. fainted)
    print("Actual Casualties: " .. actual_casualties)
    
    return {
        victory = true,
        casualties = actual_casualties,
        fainted = fainted
    }
end

return combat