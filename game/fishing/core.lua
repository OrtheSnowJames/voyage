local core = {}

function core.create(deps)
    local constants = deps.constants

    local fishing = {}
    local FISHING_LEVEL = constants.fishing_level
    local FISH_VALUE_OFFSET = constants.fish.value_offset or 0
    local GOLD_STURGEON_VALUE = constants.fish.gold_sturgeon_value or 100000
    local NIGHT_FISH_VALUE_MULTIPLIER = constants.fish.night_fish_value_multiplier or 1000

    local fish = {
        "Bluegill", "Crappie", "Yellow Perch", "Redfin Pickerel", "Bullhead Catfish",
        "Largemouth Bass", "Smallmouth Bass", "Channel Catfish", "Common Carp", "Mirror Carp",
        "Northern Pike", "Walleye", "Rainbow Trout", "Brown Trout", "Brook Trout",
        "Flathead Catfish", "Lake Trout", "Grass Carp", "Cutthroat Trout", "Sauger",
        "Muskellunge (Muskie)", "Arctic Char", "Paddlefish", "Tilapia", "Oscar",
        "Peacock Bass", "Piranha", "Arowana", "Snakehead", "Sturgeon"
    }

    local rare_night_fish = {
        "Twilight Pike", "Glassfin Monarch", "Eclipsed Lanternfish", "Ashscale Marlin", "Starbone Eel",
        "Vermillion Snapjaw", "Crimson Daggerfish", "Phantom Koi", "Abyssal Goldtail", "Frostgill Leviathan",
        "Obsidian Sunfish", "Echofin Halibut", "Wraithfin Thresher", "Moonlace Carp", "Radiant Chimerafish"
    }

    local special_fish = {
        "Gold Sturgeon"
    }

    local rods = {
        "Basic Rod", "Good Rod", "Great Rod", "Super Rod", "Ultra Rod", "Master Rod", "Legendary Rod"
    }

    local corruption_level = 0

    local function standardize_depth(y)
        local depth_level = math.floor(math.abs(y) / FISHING_LEVEL)
        if depth_level < 1 then
            depth_level = 1
        end
        return depth_level
    end

    local function normalize_rod_rarity(rod_rarity)
        return math.max(1, tonumber(rod_rarity) or 1)
    end

    local function normalize_rarity_scale_max(top_rarity, rod_rarity)
        return math.max(tonumber(top_rarity) or 1, rod_rarity)
    end

    local function apply_depth_penalty(rod_rarity, player_y)
        local numeric_y = tonumber(player_y)
        if not numeric_y then
            return rod_rarity
        end

        local depth_level = standardize_depth(numeric_y)
        return math.max(1, rod_rarity - depth_level)
    end

    local function maybe_pick_gold_sturgeon(fish_available)
        for _, fish_name in ipairs(fish_available) do
            if fish_name == "Gold Sturgeon" and math.random() < 0.01 then
                return "Gold Sturgeon"
            end
        end
        return nil
    end

    local function pick_best_roll(rod_rarity, rarity_scale_max, fish_available)
        local num_rolls = math.floor(1 + rod_rarity / 2)
        local best_catch = 1

        for _ = 1, num_rolls do
            local roll = math.random(1, math.max(2, math.floor(#fish_available * 0.4)))
            local bias = math.floor((rod_rarity / rarity_scale_max) * math.random(0, #fish_available * 0.3))
            roll = math.min(roll + bias, #fish_available)
            best_catch = math.max(best_catch, roll)
        end

        return fish_available[best_catch]
    end

    function fishing.get_rod_level(rod_name)
        for i, v in ipairs(rods) do
            if v == rod_name then
                return i
            end
        end

        local plus = string.match(rod_name or "", "Legendary Rod%+(%d+)")
        if plus then
            return #rods + tonumber(plus)
        end

        return 1
    end

    function fishing.get_rod_name(level)
        if level <= #rods then
            return rods[level]
        end
        return string.format("Legendary Rod+%d", level - #rods)
    end

    function fishing.get_rod_rarity(rod)
        return fishing.get_rod_level(rod)
    end

    function fishing.get_rod_top_rarity()
        return #rods
    end

    function fishing.get_all_fish()
        local all_fish = {}
        for _, fish_name in ipairs(fish) do
            table.insert(all_fish, fish_name)
        end
        for _, fish_name in ipairs(rare_night_fish) do
            table.insert(all_fish, fish_name)
        end
        for _, fish_name in ipairs(special_fish) do
            table.insert(all_fish, fish_name)
        end
        return all_fish
    end

    function fishing.is_special_fish(fish_name)
        for _, special in ipairs(special_fish) do
            if fish_name == special then
                return true
            end
        end
        return false
    end

    function fishing.is_night_fish(fish_name)
        for _, night in ipairs(rare_night_fish) do
            if fish_name == night then
                return true
            end
        end
        return false
    end

    function fishing.set_corruption_level(level)
        corruption_level = math.max(0, tonumber(level) or 0)
    end

    function fishing.get_fish_available(x, y, game_time)
        if corruption_level >= 0.3 then
            print("The water remembers..")
            return {"Brown Trout"}
        end

        local depth_level = standardize_depth(y)
        local start_index = depth_level
        local end_index = start_index + 2

        if end_index > #fish then
            end_index = #fish
            start_index = end_index - 2
        end

        local available_fish = {}
        for i = start_index, end_index do
            table.insert(available_fish, fish[i])
        end

        if game_time then
            local time_of_day = (game_time / (12 * 60)) * 12
            if time_of_day >= 8 then
                local night_fish_index = math.min(depth_level, #rare_night_fish)
                table.insert(available_fish, rare_night_fish[night_fish_index])

                if depth_level > 2 and math.random() < 0.5 then
                    local second_index = math.min(night_fish_index + 1, #rare_night_fish)
                    table.insert(available_fish, rare_night_fish[second_index])
                end
            end

            if time_of_day >= 11.5 and math.random() < 0.05 then
                table.insert(available_fish, "Gold Sturgeon")
            end
        end

        return available_fish
    end

    function fishing.fish(rod_rarity, top_rarity, fish_available, player_y)
        local normalized_rod_rarity = normalize_rod_rarity(rod_rarity)
        local rarity_scale_max = normalize_rarity_scale_max(top_rarity, normalized_rod_rarity)
        local effective_rod_rarity = apply_depth_penalty(normalized_rod_rarity, player_y)

        if not fish_available or #fish_available == 0 then
            return fish[1]
        end

        local gold_sturgeon = maybe_pick_gold_sturgeon(fish_available)
        if gold_sturgeon then
            return gold_sturgeon
        end

        return pick_best_roll(effective_rod_rarity, rarity_scale_max, fish_available)
    end

    function fishing.build_roll_context(player_ship)
        local ship = player_ship or {}
        local player_y = tonumber(ship.y) or 0
        local game_time = ship.time_system and ship.time_system.time
        local fish_available = fishing.get_fish_available(ship.x or 0, player_y, game_time)

        return {
            fish_available = fish_available,
            rod_rarity = fishing.get_rod_rarity(ship.rod),
            top_rarity = fishing.get_rod_top_rarity(),
            depth_level = standardize_depth(player_y),
            player_y = player_y
        }
    end

    function fishing.roll_from_context(context)
        local ctx = context or {}
        return fishing.fish(
            ctx.rod_rarity,
            ctx.top_rarity,
            ctx.fish_available,
            ctx.player_y
        )
    end

    function fishing.get_fish_avalible(x, y, game_time)
        return fishing.get_fish_available(x, y, game_time)
    end

    function fishing.debug_fish_at_depth(y, game_time)
        local available = fishing.get_fish_available(0, y, game_time)
        print("at depth " .. y .. " (level " .. standardize_depth(y) .. "), you can catch:")
        for _, fish_name in ipairs(available) do
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
    end

    function fishing.get_fish_value(fish_name)
        if fish_name == "Gold Sturgeon" then
            return GOLD_STURGEON_VALUE
        end

        for i, f in ipairs(fish) do
            if f == fish_name then
                return i + FISH_VALUE_OFFSET
            end
        end

        for i, f in ipairs(rare_night_fish) do
            if f == fish_name then
                return (#fish + i + FISH_VALUE_OFFSET) * NIGHT_FISH_VALUE_MULTIPLIER
            end
        end

        return 1 + FISH_VALUE_OFFSET
    end

    return fishing
end

return core
