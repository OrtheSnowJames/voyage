#!/usr/bin/env lua

local function parse_args(argv)
    if #argv < 1 then
        io.stderr:write("Usage: lua scripts/econ_math.lua <constants.lua> [--levels N] [--sell-multiplier X] [--out path]\n")
        os.exit(1)
    end

    local opts = {
        constants_lua = argv[1],
        levels = 30,
        sell_multiplier = 0.6,
        out = "econ_math.csv",
    }

    local i = 2
    while i <= #argv do
        local a = argv[i]
        if a == "--levels" then
            i = i + 1
            opts.levels = tonumber(argv[i]) or opts.levels
        elseif a == "--sell-multiplier" then
            i = i + 1
            opts.sell_multiplier = tonumber(argv[i]) or opts.sell_multiplier
        elseif a == "--out" then
            i = i + 1
            opts.out = argv[i] or opts.out
        else
            io.stderr:write("Unknown argument: " .. tostring(a) .. "\n")
            os.exit(1)
        end
        i = i + 1
    end

    return opts
end

local function parse_constants(path)
    local ok, loaded = pcall(dofile, path)
    if not ok then
        error("Failed to execute constants file '" .. path .. "': " .. tostring(loaded))
    end
    if type(loaded) ~= "table" then
        error("constants.lua must return a table")
    end

    local shops = loaded.shops or {}
    local econ = shops.ECON or {}
    local fish = loaded.fish or {}
    local combat = loaded.combat or {}

    local function need_number(value, key)
        if type(value) ~= "number" then
            error("Missing numeric key '" .. key .. "' in constants.lua")
        end
        return value
    end

    return {
        fishing_level = math.floor(need_number(loaded.fishing_level, "fishing_level")),
        shop_target_cycles_base = need_number(econ.shop_target_cycles_base, "shops.ECON.shop_target_cycles_base"),
        shop_target_cycles_step = need_number(econ.shop_target_cycles_step, "shops.ECON.shop_target_cycles_step"),
        regular_fish_count = math.floor(need_number(fish.regular_fish_count, "fish.regular_fish_count")),
        careless_multiplier = math.floor(need_number(combat.careless_crew_advantage_multiplier, "combat.careless_crew_advantage_multiplier")),
    }
end

local function enemy_base(depth)
    local curved_base = (depth * 1.2) + ((depth ^ 1.75) * 0.45)
    return math.max(1, math.floor(curved_base))
end

local function crew_cap(depth, careless_multiplier)
    return (careless_multiplier * enemy_base(depth)) - 1
end

local function expected_income_per_cycle(level, crew, max_depth_band, sell_mult)
    local depth_band = math.min(math.max(level, 1), max_depth_band)
    local player_expected_value = depth_band + 1
    local crew_expected_value = depth_band + 0.5
    return sell_mult * (player_expected_value + (crew * crew_expected_value))
end

local function shop_cost(level, base_cycles, step_cycles, expected_income)
    local target_cycles = base_cycles + (step_cycles * (level - 1))
    return math.floor(expected_income * target_cycles)
end

local function run(constants, levels, sell_mult)
    local rows = {}
    local coins = 0.0
    local cumulative_cycles = 0
    local max_depth_band = math.max(1, constants.regular_fish_count - 2)

    for level = 1, levels do
        local crew = crew_cap(level, constants.careless_multiplier)
        local income = expected_income_per_cycle(level, crew, max_depth_band, sell_mult)
        local cost = shop_cost(level, constants.shop_target_cycles_base, constants.shop_target_cycles_step, income)
        local need = math.max(0.0, cost - coins)
        local cycles = math.ceil(need / income)

        coins = coins + cycles * income - cost
        cumulative_cycles = cumulative_cycles + cycles

        rows[#rows + 1] = {
            level = level,
            shop_cost = cost,
            crew_cap_used = crew,
            coins_per_cycle = income,
            cycles_this_level = cycles,
            cumulative_cycles = cumulative_cycles,
            carry_coins = coins,
        }
    end

    return rows
end

local function write_csv(path, rows)
    local f, err = io.open(path, "w")
    if not f then
        error("Failed to write " .. path .. ": " .. tostring(err))
    end

    f:write("level,shop_cost,crew_cap_used,coins_per_cycle,cycles_this_level,cumulative_cycles,carry_coins\n")
    for _, row in ipairs(rows) do
        f:write(string.format(
            "%d,%d,%d,%.1f,%d,%d,%.1f\n",
            row.level,
            row.shop_cost,
            row.crew_cap_used,
            row.coins_per_cycle,
            row.cycles_this_level,
            row.cumulative_cycles,
            row.carry_coins
        ))
    end

    f:close()
end

local opts = parse_args(arg)
local constants = parse_constants(opts.constants_lua)
local rows = run(constants, opts.levels, opts.sell_multiplier)
write_csv(opts.out, rows)
print(string.format("Wrote %d rows to %s", #rows, opts.out))
