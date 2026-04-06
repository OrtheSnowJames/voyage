local economy = {}

function economy.create(deps)
    local constants = deps.constants
    local fishing = deps.fishing
    local combat = deps.combat

    local econ = {}
    local ECON = constants.shops.ECON
    local GOLD_STURGEON_SELL_PRICE = constants.fish.gold_sturgeon_sell_price or 60000
    local FISH_SELL_MULTIPLIER = 0.6
    local MAX_DEPTH_BAND = math.max(1, (constants.fish.regular_fish_count or 30) - 2)
    local CARELESS_CREW_ADVANTAGE_MULTIPLIER = constants.combat.careless_crew_advantage_multiplier or 3
    local RECOVERY_BAY_MAX = constants.combat.recovery_bay_max or 15
    local SHIP_PARTS_ACCEL_BONUS = 5

    local function get_enemy_base_for_depth(depth_level)
        local curved_base = (depth_level * 1.2) + ((depth_level ^ 1.75) * 0.45)
        return math.max(1, math.floor(curved_base))
    end

    local function get_expected_income_per_cycle(depth_level)
        local band = math.min(math.max(depth_level, 1), MAX_DEPTH_BAND)
        local enemy_base = get_enemy_base_for_depth(depth_level)
        local crew_cap = (CARELESS_CREW_ADVANTAGE_MULTIPLIER * enemy_base) - 1
        local player_expected_value = band + 1
        local crew_expected_value = band + 0.5
        return FISH_SELL_MULTIPLIER * (player_expected_value + (crew_cap * crew_expected_value))
    end

    function econ.get_next_shop_cost(port_shop_count)
        local level = math.max(0, tonumber(port_shop_count) or 0) + 1
        local target_cycles = ECON.shop_target_cycles_base + (ECON.shop_target_cycles_step * (level - 1))
        local expected_income = get_expected_income_per_cycle(level)
        return math.floor(expected_income * target_cycles)
    end

    function econ.get_crew_hire_cost(current_crew)
        local crew_count = math.max(1, tonumber(current_crew) or 1)
        local upgrades = crew_count - 1
        local cost = ECON.crew_start_cost
            + (upgrades * ECON.crew_linear_cost)
            + (upgrades * upgrades * ECON.crew_quadratic_cost)
        return math.floor(cost)
    end

    function econ.get_sword_upgrade_cost(current_sword)
        local current_level = combat.get_sword_level(current_sword)
        return math.floor(ECON.sword_base * (ECON.sword_growth ^ (current_level - 1)))
    end

    function econ.get_rod_upgrade_cost(current_rod)
        local current_level = fishing.get_rod_level(current_rod)
        return math.floor(ECON.rod_base * (ECON.rod_growth ^ (current_level - 1)))
    end

    function econ.get_speed_upgrade_cost(current_speed)
        local upgrade_level = math.floor((current_speed - 200) / 20) + 1
        return math.floor(ECON.speed_base * (ECON.speed_growth ^ (upgrade_level - 1)))
    end

    function econ.get_cooldown_upgrade_cost(current_cooldown)
        local base_cooldown = 5.0
        local upgrade_level = math.floor((base_cooldown - current_cooldown) * 10) + 1
        return math.floor(ECON.cooldown_base * (ECON.cooldown_growth ^ (upgrade_level - 1)))
    end

    function econ.get_fish_action_button_color(fish_name)
        if fish_name == "Sturgeon" then
            return {
                normal = {bg = {0.72, 0.18, 0.18}, fg = {1, 1, 1}},
                hovered = {bg = {0.82, 0.24, 0.24}, fg = {1, 1, 1}},
                active = {bg = {0.58, 0.13, 0.13}, fg = {1, 1, 1}}
            }
        end

        if fish_name == "Gold Sturgeon" then
            return {
                normal = {bg = {0.82, 0.67, 0.10}, fg = {0.08, 0.08, 0.08}},
                hovered = {bg = {0.92, 0.78, 0.18}, fg = {0.08, 0.08, 0.08}},
                active = {bg = {0.70, 0.56, 0.08}, fg = {0.08, 0.08, 0.08}}
            }
        end

        if fishing.is_night_fish and fishing.is_night_fish(fish_name) then
            return {
                normal = {bg = {0.45, 0.26, 0.62}, fg = {1, 1, 1}},
                hovered = {bg = {0.53, 0.32, 0.72}, fg = {1, 1, 1}},
                active = {bg = {0.36, 0.20, 0.52}, fg = {1, 1, 1}}
            }
        end

        return nil
    end

    function econ.get_gold_sturgeon_sell_price()
        return GOLD_STURGEON_SELL_PRICE
    end

    function econ.get_fish_sell_multiplier()
        return FISH_SELL_MULTIPLIER
    end

    function econ.get_recovery_bay_max()
        return RECOVERY_BAY_MAX
    end

    function econ.get_ship_parts_accel_bonus()
        return SHIP_PARTS_ACCEL_BONUS
    end

    return econ
end

return economy
