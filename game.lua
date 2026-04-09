-- game.lua

local game = {}
local suit = require "SUIT"
local fishing = require("game.fishing")
local serialize = require("game.serialize")
local combat = require("game.combat")
local shop = require("shop")
local spawnenemy = require("game.spawnenemy")
local menu = require("menu")  -- add menu requirement to get ship name
local size = require("game.size")
local gamestate = require("game.gamestate")
local GameType = require("game.gametypes")
local morningtext = require("game.morningtext")
local shader_factory = require("game.shaders")
local visuals = require("game.visuals")
local ripple_steps = require("game.ripple_steps")
local movement_steps = require("game.movement_steps")
local mobile_controls_steps = require("game.mobile_controls_steps")
local update_steps = require("game.update_steps")
local draw_steps = require("game.draw_steps")
local shopkeeper_factory = require("game.shopkeeper")
local constants = require("game.constants")
local state_factory = require("game.state")
local mods = require("game.mods")
local hunger = require("game.hunger")
local crew_management = require("game.crew_management")
local alert = require("game.alert")
local FISHING_LEVEL = constants.fishing_level
local fishing_minigame = fishing.minigame

local boot_state = state_factory.create(love.graphics.newImage("assets/boat.png"))
local state = {
    constants = constants,
    core = boot_state,
    world = {
        shore_objects = {},
        ship_ripples = {},
        last_player_ripple_pos = {x = 0, y = 0}
    },
    shore = {}
}

local game_config = state.core.game_config
local special_fish_event = state.core.special_fish_event
local debugOptions = state.core.debug_options
local mobile_controls = state.core.mobile_controls
local gameState = state.core.game_state
local water_state = state.core.water
local camera = state.core.camera
local player_ship = state.core.player_ship
local ripples = state.core.ripples

state.player = player_ship
state.drowning = constants.ship.drowning_time
state.shipwreck_reached_land = false
state.shipwreck_landfall_pending_recovery = false
state.camera = camera
state.water = water_state
state.system = {
    game = game,
    gamestate = gamestate,
    gametype = GameType,
    serialize = serialize,
    menu = menu,
    size = size,
    spawnenemy = spawnenemy,
    constants = constants,
    require = require,
    -- direct module access for mods
    fishing = fishing,
    combat = combat,
    shop = shop,
    enemy = spawnenemy,
    visuals = visuals,
    morningtext = morningtext,
    update_steps = update_steps,
    draw_steps = draw_steps,
    movement_steps = movement_steps,
    mobile_controls_steps = mobile_controls_steps,
    ripple_steps = ripple_steps,
    shaders = shader_factory,
    shopkeeper = shopkeeper_factory,
    hunger = hunger,
    crew_management = crew_management,
    alert = alert,
    mods = mods,
    -- grouped alias kept for backward compatibility
    modules = {
        fishing = fishing,
        combat = combat,
        shop = shop,
        enemy = spawnenemy,
        visuals = visuals,
        morningtext = morningtext,
        update_steps = update_steps,
        draw_steps = draw_steps,
        movement_steps = movement_steps,
        mobile_controls_steps = mobile_controls_steps,
        ripple_steps = ripple_steps,
        shaders = shader_factory,
        shopkeeper = shopkeeper_factory,
        hunger = hunger,
        crew_management = crew_management,
        alert = alert,
        mods = mods
    },
    libs = {
        math = math,
        string = string,
        table = table,
        utf8 = utf8,
        love = love
    }
}
state.fishing = {
    module = fishing,
    minigame = fishing_minigame,
    config = game_config,
    event = special_fish_event,
    runtime = nil
}
state.combat = {
    module = combat,
    state = gameState
}
state.enemy = {
    module = spawnenemy
}
state.shop = {
    module = shop,
    keeper = nil,
    port_a_shops = nil
}
state.ui = {
    debug = debugOptions,
    mobile = mobile_controls,
    suit = suit,
    morningtext = morningtext,
    alert = alert
}
state.actions = {}
state.mods = {
    module = mods,
    active = false,
    count = 0
}

-- mirror runtime state on state.system so most code/mods can access one surface
state.system.player = state.player
state.system.camera = state.camera
state.system.water = state.water
state.system.world = state.world
state.system.shore = state.shore
state.system.ui = state.ui
state.system.actions = state.actions
state.system.fishing_state = state.fishing
state.system.combat_state = state.combat
state.system.enemy_state = state.enemy
state.system.shop_state = state.shop
state.system.mods_state = state.mods
state.system.mods_module = mods
state.system.mods = state.mods

-- derived settings (automatically update when config changes)
local function get_max_catch_texts()
    return math.ceil(game_config.fishing_cooldown)  -- one text slot per second of cooldown
end

local function get_animation_duration()
    return game_config.fishing_cooldown * 0.06  -- animation takes 6% of cooldown time
end

local shore_division = constants.world.shore_division -- what separates water from land (land is above this value)

-- load shore texture
local shore_texture = love.graphics.newImage("assets/shore.png")
local shore_width = shore_texture:getWidth()
local shore_height = shore_texture:getHeight()
local shore_quad = love.graphics.newQuad(0, 10, shore_width, shore_height - 20, shore_width, shore_height)
local shore_quad_height = shore_height - 40
local bottom_half_quad = love.graphics.newQuad(0, shore_height / 2 + 20, shore_width, shore_height / 2 - 20, shore_width, shore_height)
local bottom_half_quad_height = shore_height / 2 - 20

local shore_shader, water_shader = shader_factory.create()

state.shore = {
    division = shore_division,
    texture = shore_texture,
    width = shore_width,
    height = shore_height,
    quad = shore_quad,
    quad_height = shore_quad_height,
    bottom_half_quad = bottom_half_quad,
    bottom_half_quad_height = bottom_half_quad_height,
    shader = shore_shader,
    water_shader = water_shader,
    objects = state.world.shore_objects
}
state.system.shore = state.shore

-- shore objects system
local shore_objects = state.world.shore_objects
local SHORE_OBJECT_COUNT = constants.world.shore_object_count
local SHORE_OBJECT_SPACING = shore_width  -- space between objects

-- ship ripple system
local ship_ripples = state.world.ship_ripples
local MAX_RIPPLES = constants.world.max_ripples -- more ripples for a longer wake
local RIPPLE_SPAWN_DIST = constants.world.ripple_spawn_distance -- spawn a new ripple source every 20 pixels traveled
local last_player_ripple_pos = state.world.last_player_ripple_pos
state.world.max_ripples = MAX_RIPPLES
state.world.ripple_spawn_distance = RIPPLE_SPAWN_DIST

-- initialize shore objects
local function init_shore_objects()
    for i = #shore_objects, 1, -1 do
        shore_objects[i] = nil
    end
    for i = 1, SHORE_OBJECT_COUNT do
        table.insert(shore_objects, {
            x = (i - 11) * SHORE_OBJECT_SPACING, -- start centered on the player
            y = shore_division
        })
    end
end

-- update shore objects (teleport when needed, don't move them)
local function update_shore_objects()
    local viewWidth = size.CANVAS_WIDTH / camera.scale
    local view_left = camera.x
    local view_right = camera.x + viewWidth

    -- find the object with the minimum x and the object with the maximum x
    local min_obj = shore_objects[1]
    local max_obj = shore_objects[1]
    for i = 2, #shore_objects do
        if shore_objects[i].x < min_obj.x then
            min_obj = shore_objects[i]
        end
        if shore_objects[i].x > max_obj.x then
            max_obj = shore_objects[i]
        end
    end

    -- if the camera view gets too close to the leftmost shore object,
    -- move the rightmost object to the left end to pre-fill the space.
    if view_left < min_obj.x + shore_width then
        max_obj.x = min_obj.x - SHORE_OBJECT_SPACING
    end

    -- if the camera view gets too close to the rightmost shore object,
    -- move the leftmost object to the right end to pre-fill the space.
    if view_right > max_obj.x then
        min_obj.x = max_obj.x + SHORE_OBJECT_SPACING
    end
end

-- port-a-shop configuration
local ON_FOOT_SPEED = constants.shops.on_foot_speed or 125
local ON_FOOT_MAX_WALK_UP = constants.shops.on_foot_max_walk_up or 240
local ON_FOOT_MAX_WALK_SIDE = constants.shops.on_foot_max_walk_side or 260
local ON_FOOT_MAX_WALK_DOWN = constants.shops.on_foot_max_walk_down or 24
local MAIN_DOCK_WALK_HALF_WIDTH = constants.shops.main_dock_walk_half_width or 20
local MAIN_SHOPKEEPER_SIDE_OFFSET_X = constants.shops.main_shopkeeper_side_offset_x or 42
local MAIN_SHOPKEEPER_SHORE_OFFSET_Y = constants.shops.main_shopkeeper_shore_offset_y or 0

-- port-a-shops state
local port_a_shops = {}
state.shop.port_a_shops = port_a_shops
local get_enemy_pull_radius
local cheat_runtime
local normalize_rainbows
local reset_cheating_state
local update_ship_animation
local anti_cheat_enabled = true

local shopkeeper = shopkeeper_factory.create({
    camera = camera,
    player_ship = player_ship,
    shore_division = shore_division,
    size = size,
    main_shopkeeper_side_offset_x = MAIN_SHOPKEEPER_SIDE_OFFSET_X,
    main_shopkeeper_shore_offset_y = MAIN_SHOPKEEPER_SHORE_OFFSET_Y
})
state.shop.keeper = shopkeeper

reset_cheating_state = function()
    player_ship.rainbows = 0
    player_ship.corruption_started = false
    player_ship.debug_menu_opened = false
    player_ship.reached_first_1130 = false
    cheat_runtime.last_observed_time = player_ship.time_system.time or 0
    fishing.set_corruption_level(0)
    spawnenemy.set_corruption_state(0, 0)
end

local function reset_game()
    -- delete save file
    love.filesystem.remove("save.lua")
    
    -- clear enemies
    spawnenemy.clear_enemies()
    
    -- reset player ship to initial state
    state.drowning = constants.ship.drowning_time
    state.shipwreck_reached_land = false
    state.shipwreck_landfall_pending_recovery = false
    state.shipwreck_game_over = nil
    player_ship.x = constants.ship.start_x
    player_ship.y = constants.ship.start_y
    player_ship.men = constants.ship.start_crew
    player_ship.fainted_men = 0
    player_ship.velocity_x = 0
    player_ship.velocity_y = 0
    player_ship.rotation = 0
    player_ship.target_rotation = 0
    player_ship.is_on_foot = false
    player_ship.is_swimming = false
    player_ship.on_foot_x = player_ship.x
    player_ship.on_foot_y = player_ship.y
    player_ship.shipwreck_landed = false
    player_ship.shipwreck_sleep_timer = 0
    player_ship.shipwreck_land_dock_x = nil
    player_ship.shipwreck_land_dock_y = nil
    player_ship.boat_hidden_until_morning = false
    player_ship.pending_shop_interaction = false
    player_ship.dock_walk_center_x = nil
    player_ship.dock_walk_center_y = nil
    player_ship.dock_walk_dock_x = nil
    player_ship.dock_walk_dock_y = nil
    player_ship.docked_port_shop_index = nil
    player_ship.dock_walk_mode = nil
    player_ship.dock_walk_island_radius = nil
    player_ship.dock_walk_dock_half_width = nil
    player_ship.dock_walk_dock_height = nil
    player_ship.dock_walk_max_side = nil
    player_ship.dock_walk_max_up = nil
    player_ship.dock_walk_max_down = nil
    player_ship.rod = "Basic Rod"
    player_ship.sword = "Basic Sword"
    player_ship.caught_fish = {}
    player_ship.inventory = {}
    hunger.reset(player_ship, constants.hunger)
    player_ship.time_system.time = 0
    reset_cheating_state()
    if state.fishing.runtime then
        state.fishing.runtime.reset_state()
    end

    -- reset combat and defeat flash state
    gameState.combat.zoom_progress = 0
    gameState.combat.enemy = nil
    gameState.combat.result = nil
    gameState.combat.defeat_flash.active = false
    gameState.combat.defeat_flash.alpha = 0
    gameState.combat.defeat_flash.timer = 0

    -- reset camera
    camera.x = 0
    camera.y = 0
    camera.scale = 1

    -- reset shops
    shop.reset()
    shopkeeper.x = 0
    shopkeeper.y = shore_division - 16
    shopkeeper.is_spawned = false

    -- reset special fish event
    special_fish_event.active = false
    special_fish_event.timer = 0
    special_fish_event.fish_name = ""
    special_fish_event.caught_gold_sturgeon = false
    
    -- reset mobile controls
    for _, button in pairs(mobile_controls.buttons) do
        button.pressed = false
    end
    
    -- reset shore objects
    init_shore_objects()
    
    -- reset ship_ripples
    for i = #ship_ripples, 1, -1 do
        ship_ripples[i] = nil
    end
    last_player_ripple_pos.x = player_ship.x
    last_player_ripple_pos.y = player_ship.y

    morningtext.reset()
end

local function reset_after_shipwreck_landfall()
    local kept_inventory = {}
    for i, item in ipairs(player_ship.inventory or {}) do
        kept_inventory[i] = item
    end
    local kept_shop_data = shop.get_port_a_shops_data and shop.get_port_a_shops_data() or nil
    local kept_coins = tonumber(shop.get_coins and shop.get_coins()) or 0
    local kept_x = tonumber(player_ship.shipwreck_land_dock_x) or tonumber(player_ship.x) or constants.ship.start_x
    local kept_y = tonumber(player_ship.shipwreck_land_dock_y) or tonumber(player_ship.y) or constants.ship.start_y
    local kept_rotation = tonumber(player_ship.rotation) or 0

    reset_game()

    player_ship.inventory = kept_inventory
    player_ship.caught_fish = {}
    player_ship.men = 1
    player_ship.loyal_men = 1
    player_ship.fainted_men = 5
    player_ship.hunger_levels = {60}
    player_ship.hunger_alert_text = ""
    player_ship.hunger_alert_timer = 0
    player_ship.x = kept_x
    player_ship.y = kept_y
    player_ship.rotation = kept_rotation
    player_ship.target_rotation = kept_rotation
    player_ship.is_on_foot = false
    player_ship.is_swimming = false
    player_ship.boat_hidden_until_morning = false
    player_ship.on_foot_x = kept_x
    player_ship.on_foot_y = kept_y

    if shop.set_port_a_shops_data then
        if kept_shop_data then
            shop.set_port_a_shops_data(kept_shop_data)
        else
            shop.set_port_a_shops_data({coins = kept_coins})
        end
        if shop.add_coins and shop.get_coins then
            local current_coins = tonumber(shop.get_coins()) or 0
            local delta = kept_coins - current_coins
            if delta > 0 then
                shop.add_coins(delta)
            elseif delta < 0 and shop.try_spend_coins then
                shop.try_spend_coins(-delta)
            end
        end
    end

    serialize.save_data(game.get_saveable_data())
end

function ripples:spawn(player_ship, x, y)
    ripple_steps.spawn(self, player_ship, camera, size, x, y)
end

function ripples:update(dt, player_ship)
    ripple_steps.update(self, dt, player_ship, camera, size)
end

function ripples:draw()
    ripple_steps.draw(self, camera, size)
end

function player_ship:update(dt)
    local walk_center_x = tonumber(player_ship.dock_walk_center_x) or player_ship.x
    local walk_center_y = tonumber(player_ship.dock_walk_center_y) or (shore_division - 30)
    local dock_x = tonumber(player_ship.dock_walk_dock_x)
    local dock_bottom_y = tonumber(player_ship.dock_walk_dock_y)
    local dock_walk_half_width = tonumber(player_ship.dock_walk_dock_half_width) or MAIN_DOCK_WALK_HALF_WIDTH
    local dock_height = tonumber(player_ship.dock_walk_dock_height) or 26
    local on_foot_max_walk_up = tonumber(player_ship.dock_walk_max_up) or ON_FOOT_MAX_WALK_UP
    local on_foot_max_walk_side = tonumber(player_ship.dock_walk_max_side) or ON_FOOT_MAX_WALK_SIDE
    local on_foot_max_walk_down = tonumber(player_ship.dock_walk_max_down) or ON_FOOT_MAX_WALK_DOWN

    movement_steps.update_player_ship(self, dt, {
        mobile_controls = mobile_controls,
        gamestate = gamestate.get(),
        GameType = GameType,
        normalize_rainbows = game.normalize_rainbows,
        shore_division = shore_division,
        on_foot_speed = ON_FOOT_SPEED,
        on_foot_max_walk_up = on_foot_max_walk_up,
        on_foot_max_walk_side = on_foot_max_walk_side,
        on_foot_max_walk_down = on_foot_max_walk_down,
        on_foot_bounds_mode = player_ship.dock_walk_mode or "shore",
        foot_island_radius = tonumber(player_ship.dock_walk_island_radius),
        dock_x = dock_x,
        dock_bottom_y = dock_bottom_y,
        dock_walk_half_width = dock_walk_half_width,
        dock_height = dock_height,
        walk_center_x = walk_center_x,
        walk_center_y = walk_center_y,
        last_player_ripple_pos = last_player_ripple_pos,
        ship_ripples = ship_ripples,
        RIPPLE_SPAWN_DIST = RIPPLE_SPAWN_DIST,
        MAX_RIPPLES = MAX_RIPPLES,
        update_ship_animation = update_ship_animation
    })
end

-- moves camera to a specific world coordinate
function camera:goto(x, y)
    movement_steps.camera_goto(self, x, y)
end

-- zooms the camera, keeping the center stable
function camera:zoom(factor, target_x, target_y)
    movement_steps.camera_zoom(self, factor, target_x, target_y, size)
end

local GOLD_STURGEON_UNLOCK_HOUR = constants.fish.gold_sturgeon_unlock_hour
local REGULAR_FISH_COUNT = constants.fish.regular_fish_count
local CHEAT_DEPTH_TOLERANCE = constants.cheat.depth_tolerance
local TIME_SKIP_CHEAT_THRESHOLD_SECONDS = constants.cheat.time_skip_threshold_seconds
local MONEY_BASE_THRESHOLD = constants.cheat.money_base_threshold
local MONEY_GROWTH_PER_DEPTH = constants.cheat.money_growth_per_depth
local MONEY_PER_CREW_BONUS = constants.cheat.money_per_crew_bonus
local RAINBOWS_START_VALUE = constants.corruption.start_value
local RAINBOWS_STEP = constants.corruption.step

cheat_runtime = {
    last_observed_time = nil
}

get_enemy_pull_radius = function()
    local current_rainbows = math.max(0, tonumber(player_ship.rainbows) or 0)
    if current_rainbows < RAINBOWS_START_VALUE then
        return 0
    end

    local day_step = math.max(1, math.floor(current_rainbows * 10 + 0.5))
    return 170 + (day_step - 1) * 55
end

normalize_rainbows = function(value)
    local numeric = tonumber(value) or 0
    local clamped = math.max(0, math.min(1, numeric))
    return math.floor(clamped * 10 + 0.5) / 10
end
game.normalize_rainbows = normalize_rainbows

local function get_time_of_day_hours()
    return (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12
end

local function has_fish(fish_name)
    for _, caught in ipairs(player_ship.caught_fish or {}) do
        if caught == fish_name then
            return true
        end
    end

    for _, stored in ipairs(player_ship.inventory or {}) do
        if stored == fish_name then
            return true
        end
    end

    return special_fish_event.active and special_fish_event.fish_name == fish_name
end

function game.get_required_depth_for_fish(fish_name)
    local fish_value = fishing.get_fish_value(fish_name)
    if fish_value == 100000 then
        return nil -- gold sturgeon is handled by the time rule below.
    end

    if fish_value <= REGULAR_FISH_COUNT then
        return math.max(1, fish_value - 2)
    end

    local night_fish_index = fish_value - REGULAR_FISH_COUNT
    return math.max(1, night_fish_index - 1)
end

local function get_max_reasonable_coins(shop_depth_level, crew_count)
    local depth = math.max(1, tonumber(shop_depth_level) or 1)
    local crew = math.max(1, tonumber(crew_count) or 1)
    local depth_cap = MONEY_BASE_THRESHOLD * (MONEY_GROWTH_PER_DEPTH ^ (depth - 1))
    local crew_bonus = (crew - 1) * MONEY_PER_CREW_BONUS
    return depth_cap + crew_bonus
end

local function force_corruption_sleep_if_needed()
    if player_ship.corruption_started then
        return false
    end

    local current_rainbows = tonumber(player_ship.rainbows) or 0
    if math.abs(current_rainbows - RAINBOWS_START_VALUE) > 0.0001 then
        return false
    end

    if player_ship.time_system.is_fading or player_ship.time_system.is_sleeping then
        return false
    end

    player_ship.corruption_started = true
    player_ship.time_system.time = 0
    player_ship.time_system.is_fading = true
    player_ship.time_system.fade_timer = 0
    player_ship.time_system.fade_direction = "out"
    player_ship.time_system.fade_alpha = 0
    player_ship.time_system.is_sleeping = false
    gamestate.set(GameType.SLEEPING)
    print("Rainbows reached 0.1 - forcing immediate sleep to begin corruption.")
    return true
end

local function flag_save_as_rainbows(reason)
    local current_rainbows = tonumber(player_ship.rainbows) or 0
    if current_rainbows >= RAINBOWS_START_VALUE then
        return
    end

    player_ship.rainbows = RAINBOWS_START_VALUE
    print(string.format("Cheat detector flagged save: %s (rainbows=%.1f)", reason, player_ship.rainbows)) 
    print("lollipops and rainbows headed your way!")
    serialize.save_data(game.get_saveable_data())
    force_corruption_sleep_if_needed()
end

local function increase_rainbows_for_new_day()
    local current_rainbows = tonumber(player_ship.rainbows) or 0
    if current_rainbows < RAINBOWS_START_VALUE or current_rainbows >= 1 then
        return false
    end

    local next_rainbows = math.min(1, math.floor((current_rainbows + RAINBOWS_STEP) * 10 + 0.5) / 10)
    if next_rainbows > current_rainbows then
        player_ship.rainbows = next_rainbows
        print(string.format("Rainbows increased to %.1f", player_ship.rainbows))
        serialize.save_data(game.get_saveable_data())
        return true
    end

    return false
end

local function detect_cheating()
    if not anti_cheat_enabled then
        cheat_runtime.last_observed_time = player_ship.time_system.time or 0
        return false
    end

    local current_time = player_ship.time_system.time or 0
    local previous_time = cheat_runtime.last_observed_time
    cheat_runtime.last_observed_time = current_time

    local current_rainbows = tonumber(player_ship.rainbows) or 0
    if current_rainbows >= RAINBOWS_START_VALUE or player_ship.debug_menu_opened then
        return false
    end

    if previous_time ~= nil then
        local day_length = player_ship.time_system.DAY_LENGTH or (12 * 60)
        local delta_time = current_time - previous_time
        if delta_time < 0 then
            delta_time = delta_time + day_length
        end

        if delta_time > TIME_SKIP_CHEAT_THRESHOLD_SECONDS then
            flag_save_as_rainbows(string.format(
                "time jumped by %.1f seconds in one tick",
                delta_time
            ))
            return true
        end
    end

    if get_time_of_day_hours() >= GOLD_STURGEON_UNLOCK_HOUR then
        player_ship.reached_first_1130 = true
    end

    if has_fish("Gold Sturgeon") and not player_ship.reached_first_1130 then
        flag_save_as_rainbows("Gold Sturgeon owned before first 11:30")
        return true
    end

    local last_shop_y = shop.get_last_port_a_shop_y() or 0
    local shop_depth_level = math.max(1, math.floor(last_shop_y / FISHING_LEVEL))
    local max_expected_depth = shop_depth_level + CHEAT_DEPTH_TOLERANCE
    local current_coins = tonumber(shop.get_coins()) or 0
    local max_reasonable_coins = get_max_reasonable_coins(shop_depth_level, player_ship.men)

    if current_coins > max_reasonable_coins then
        local reason = string.format(
            "coins %.1f exceed reasonable cap %.1f at depth level %d",
            current_coins,
            max_reasonable_coins,
            shop_depth_level
        )
        flag_save_as_rainbows(reason)
        return true
    end

    local fish_lists = {
        player_ship.caught_fish or {},
        player_ship.inventory or {}
    }

    for _, fish_list in ipairs(fish_lists) do
        for _, fish_name in ipairs(fish_list) do
            local required_depth = game.get_required_depth_for_fish(fish_name)
            if required_depth and required_depth > max_expected_depth then
                local reason = string.format(
                    "%s requires depth %d, shop progression suggests <= %d",
                    fish_name,
                    required_depth,
                    max_expected_depth
                )
                flag_save_as_rainbows(reason)
                return true
            end
        end
    end

    return false
end

-- get saveable data (excluding functions)
function game.get_saveable_data()
    local data = {}
    for k, v in pairs(player_ship) do
        if type(v) ~= "function" and k ~= "sprite" then
            data[k] = v
        end
    end
    -- add shop data
    data.shop_data = shop.get_port_a_shops_data()
    return data
end

function game.load()
    -- check if mobile
    on_mobile = false
    on_web = false
    local os = love.system.getOS()
    if os == 'iOS' or os == 'Android' then
        on_mobile = true
        print("mobile")
    elseif os == 'Web' then
        on_web = true
        print("web")
    else
        print("not on web or mobile")
    end
    anti_cheat_enabled = not (on_mobile or os == "Web")

    mobile_controls.enabled = on_mobile

    mods.load_all(state)
    state.mods.count = mods.count()
    state.mods.active = state.mods.count > 0
    if state.mods.active then
        print(string.format("Loaded %d mod(s)", state.mods.count))
    end

    local saved_data = serialize.load_data({
        allow_tampered = true
    })
    if serialize.was_tampered() then
        print("Tampered save.lua detected: loading anyway.")
    end

    if saved_data then
        -- only copy saved data properties, preserving methods
        for k, v in pairs(saved_data) do
            if k == "shop_data" then
                -- load shop data separately
                shop.set_port_a_shops_data(v)
            elseif type(player_ship[k]) ~= "function" then  -- don't overwrite functions
                player_ship[k] = v
            end
        end
    else
        -- if no save data, get name from menu
        player_ship.name = menu.get_name()
        serialize.save_data(game.get_saveable_data())
    end

    -- migration defaults for older saves
    player_ship.caught_fish = player_ship.caught_fish or {}
    player_ship.inventory = player_ship.inventory or {}
    hunger.sync(player_ship, constants.hunger)

    if player_ship.rainbows == true then
        player_ship.rainbows = RAINBOWS_START_VALUE
    else
        player_ship.rainbows = game.normalize_rainbows(player_ship.rainbows)
    end

    if player_ship.corruption_started == nil then
        player_ship.corruption_started = (tonumber(player_ship.rainbows) or 0) > RAINBOWS_START_VALUE
    else
        player_ship.corruption_started = player_ship.corruption_started == true
    end

    player_ship.debug_menu_opened = player_ship.debug_menu_opened == true

    if player_ship.reached_first_1130 == nil then
        player_ship.reached_first_1130 = has_fish("Gold Sturgeon") or get_time_of_day_hours() >= GOLD_STURGEON_UNLOCK_HOUR
    else
        player_ship.reached_first_1130 = player_ship.reached_first_1130 == true
    end

    if player_ship.is_on_foot == nil then
        player_ship.is_on_foot = false
    else
        player_ship.is_on_foot = player_ship.is_on_foot == true
    end
    player_ship.is_swimming = player_ship.is_swimming == true
    player_ship.shipwreck_landed = player_ship.shipwreck_landed == true
    player_ship.shipwreck_sleep_timer = tonumber(player_ship.shipwreck_sleep_timer) or 0
    player_ship.shipwreck_land_dock_x = tonumber(player_ship.shipwreck_land_dock_x)
    player_ship.shipwreck_land_dock_y = tonumber(player_ship.shipwreck_land_dock_y)
    player_ship.boat_hidden_until_morning = player_ship.boat_hidden_until_morning == true
    player_ship.on_foot_x = tonumber(player_ship.on_foot_x) or player_ship.x
    player_ship.on_foot_y = tonumber(player_ship.on_foot_y) or player_ship.y
    player_ship.pending_shop_interaction = player_ship.pending_shop_interaction == true
    player_ship.docked_port_shop_index = tonumber(player_ship.docked_port_shop_index)
    if player_ship.docked_port_shop_index then
        player_ship.docked_port_shop_index = math.max(1, math.floor(player_ship.docked_port_shop_index))
    end
    player_ship.dock_walk_mode = (player_ship.dock_walk_mode == "island") and "island" or "shore"
    player_ship.dock_walk_island_radius = tonumber(player_ship.dock_walk_island_radius)
    player_ship.dock_walk_dock_half_width = tonumber(player_ship.dock_walk_dock_half_width)
    player_ship.dock_walk_dock_height = tonumber(player_ship.dock_walk_dock_height)
    player_ship.dock_walk_max_side = tonumber(player_ship.dock_walk_max_side)
    player_ship.dock_walk_max_up = tonumber(player_ship.dock_walk_max_up)
    player_ship.dock_walk_max_down = tonumber(player_ship.dock_walk_max_down)

    if player_ship.is_on_foot then
        player_ship.dock_walk_center_x = tonumber(player_ship.dock_walk_center_x) or player_ship.on_foot_x
        player_ship.dock_walk_center_y = tonumber(player_ship.dock_walk_center_y) or player_ship.on_foot_y
        player_ship.dock_walk_dock_x = tonumber(player_ship.dock_walk_dock_x) or player_ship.on_foot_x
        player_ship.dock_walk_dock_y = tonumber(player_ship.dock_walk_dock_y) or player_ship.on_foot_y
    else
        player_ship.dock_walk_center_x = nil
        player_ship.dock_walk_center_y = nil
        player_ship.dock_walk_dock_x = nil
        player_ship.dock_walk_dock_y = nil
        player_ship.docked_port_shop_index = nil
        player_ship.dock_walk_mode = nil
        player_ship.dock_walk_island_radius = nil
        player_ship.dock_walk_dock_half_width = nil
        player_ship.dock_walk_dock_height = nil
        player_ship.dock_walk_max_side = nil
        player_ship.dock_walk_max_up = nil
        player_ship.dock_walk_max_down = nil
    end

    if state.fishing.runtime then
        state.fishing.runtime.reset_state()
    end
    
    -- initialize shore objects
    init_shore_objects()
    cheat_runtime.last_observed_time = player_ship.time_system.time
    fishing.set_corruption_level(player_ship.rainbows)
    spawnenemy.set_corruption_state(player_ship.rainbows, get_enemy_pull_radius())
    detect_cheating()
    morningtext.start(player_ship.rainbows)
    mods.run_hook("on_game_load", state)
end

-- ship animation
local ship_animation = {
    scale = 1,
    target_scale = 1,
    animation_time = 0,
    get_duration = get_animation_duration  -- function to get current duration
}
state.ship_animation = ship_animation

update_ship_animation = function(dt)
    if ship_animation.animation_time > 0 then
        ship_animation.animation_time = math.max(0, ship_animation.animation_time - dt)
        local progress = ship_animation.animation_time / ship_animation.get_duration()
        -- smooth interpolation between scales
        ship_animation.scale = 1 + (ship_animation.target_scale - 1) * progress
    end
end

local function trigger_ship_animation()
    ship_animation.target_scale = 0.7  -- shrink to 70% size
    ship_animation.scale = 1
    ship_animation.animation_time = ship_animation.get_duration()
end

local function trigger_special_fish_event(fish_name)
    -- set up the special fish event
    special_fish_event.active = true
    special_fish_event.timer = 0
    special_fish_event.fish_name = fish_name
    
    -- if it's gold sturgeon, mark it as caught for the night
    if fish_name == "Gold Sturgeon" then
        special_fish_event.caught_gold_sturgeon = true
    end
    
    -- add a paused-state catch text that will be shown after the event
    state.fishing.runtime.add_catch_text("You: " .. fish_name)
    
    -- don't add to inventory yet - will be added after the event
end

local function getCurrentWaterColor()
    return visuals.get_current_water_color(player_ship)
end

-- make getcurrentwatercolor accessible to other modules
game.getCurrentWaterColor = getCurrentWaterColor

state.fishing.runtime = fishing.create_runtime({
    GameType = GameType,
    fishing = fishing,
    fishing_minigame = fishing_minigame,
    game_config = game_config,
    gamestate = gamestate,
    get_current_water_color = getCurrentWaterColor,
    get_max_catch_texts = get_max_catch_texts,
    is_on_shop_line = shop.has_shop_collision_at_y,
    mobile_controls = mobile_controls,
    player_ship = player_ship,
    special_fish_event = special_fish_event,
    trigger_ship_animation = trigger_ship_animation,
    trigger_special_fish_event = trigger_special_fish_event
})

-- function to get ambient light intensity (for glow effects)
local function getAmbientLight()
    return visuals.get_ambient_light(player_ship)
end

-- function to draw ship glow effect
local function drawShipGlow(x, y, radius, color, intensity)
    visuals.draw_ship_glow(x, y, radius, color, intensity)
end

-- function to handle sleep state
local function during_sleep()
    if state.shipwreck_landfall_pending_recovery then
        reset_after_shipwreck_landfall()
        state.shipwreck_landfall_pending_recovery = false
    end

    if player_ship.boat_hidden_until_morning then
        local dock_x = tonumber(player_ship.shipwreck_land_dock_x)
        local dock_y = tonumber(player_ship.shipwreck_land_dock_y)
        if not dock_x or not dock_y then
            local main_dock_x, main_dock_y = shop.get_main_dock_position and shop.get_main_dock_position(shopkeeper)
            dock_x = dock_x or main_dock_x
            dock_y = dock_y or main_dock_y
        end
        dock_x = dock_x or player_ship.x
        dock_y = dock_y or player_ship.y
        player_ship.x = dock_x
        player_ship.y = dock_y
        player_ship.time_system.time = 0
        player_ship.boat_hidden_until_morning = false
    end

    -- check if near any shop (port-a-shop or shopkeeper)
    local near_shop = false
    
    -- check port-a-shops
    for _, shop_data in ipairs(port_a_shops) do
        if shop_data.is_spawned then
            local distance = math.sqrt((shop_data.x - player_ship.x)^2 + (shop_data.y - player_ship.y)^2)
            if distance <= 50 then
                near_shop = true
                break
            end
        end
    end
    
    -- check main shopkeeper if not already near a port-a-shop
    if not near_shop and shopkeeper and shopkeeper.is_spawned then
        local distance_to_main_shop = math.sqrt((shopkeeper.x - player_ship.x)^2 + (shopkeeper.y - player_ship.y)^2)
        if distance_to_main_shop <= 75 then
            near_shop = true
        end
    end
    
    -- if near a shop, recover fainted enemy crew members
    if near_shop and player_ship.fainted_men > 0 then
        print("Recovering " .. player_ship.fainted_men .. " fainted enemy crew member(s)...")
        player_ship.men = player_ship.men + player_ship.fainted_men
        player_ship.fainted_men = 0
        print("All fainted enemy crew recovered!")
    end

    -- note: game will be saved after waking up, not during sleep
end

function game.toggleDebug()
    debugOptions.showDebugButtons = not debugOptions.showDebugButtons
    if debugOptions.showDebugButtons then
        player_ship.debug_menu_opened = true
    end
    print("Debug mode: " .. (debugOptions.showDebugButtons and "ON" or "OFF"))
end

-- handle mobile button press
local function handle_mobile_button_press(x, y)
    if gamestate.get():find(GameType.SHOP, 1, true) or (crew_management.is_open and crew_management.is_open()) then
        return false
    end
    return mobile_controls_steps.handle_press(mobile_controls, x, y)
end

-- handle mobile button release
local function handle_mobile_button_release(x, y)
    if gamestate.get():find(GameType.SHOP, 1, true) or (crew_management.is_open and crew_management.is_open()) then
        return false
    end
    return mobile_controls_steps.handle_release(mobile_controls, x, y)
end

-- draw mobile controls
local function draw_mobile_controls()
    mobile_controls_steps.draw(mobile_controls, size)
end

state.actions.get_time_of_day_hours = get_time_of_day_hours
state.actions.increase_rainbows_for_new_day = increase_rainbows_for_new_day
state.actions.reset_game = reset_game
state.actions.reset_after_shipwreck_landfall = reset_after_shipwreck_landfall
state.actions.during_sleep = during_sleep
state.actions.trigger_ship_animation = trigger_ship_animation
state.actions.trigger_special_fish_event = trigger_special_fish_event
state.actions.update_ship_animation = update_ship_animation
state.actions.update_shore_objects = update_shore_objects
state.actions.get_current_water_color = getCurrentWaterColor
state.actions.get_ambient_light = getAmbientLight
state.actions.draw_ship_glow = drawShipGlow
state.actions.draw_mobile_controls = draw_mobile_controls
state.actions.force_corruption_sleep_if_needed = force_corruption_sleep_if_needed

-- handle key presses in the game
function game.keypressed(key)
    if key == "f" and gamestate.get() == GameType.VOYAGE then
        local function consume_f_press_for_fishing()
            if state and state.fishing and state.fishing.runtime and state.fishing.runtime.block_fishing_until_release then
                state.fishing.runtime.block_fishing_until_release()
            end
        end

        if player_ship.is_on_foot then
            if shop.request_main_shop_interaction and shop.request_main_shop_interaction(player_ship, shopkeeper) then
                consume_f_press_for_fishing()
                print("You talk to the shopkeeper.")
                return
            end
            if shop.request_port_shop_interaction and shop.request_port_shop_interaction(player_ship) then
                consume_f_press_for_fishing()
                print("You talk to the port-a-shop keeper.")
                return
            end
            if shop.try_board_main_dock and shop.try_board_main_dock(player_ship, shopkeeper) then
                consume_f_press_for_fishing()
                print("You board your boat.")
                return
            end
        else
            if shop.try_disembark_main_dock and shop.try_disembark_main_dock(player_ship, shopkeeper) then
                consume_f_press_for_fishing()
                print("You dock and step off your boat.")
                return
            end
            if shop.try_disembark_port_shop and shop.try_disembark_port_shop(player_ship) then
                consume_f_press_for_fishing()
                print("You dock at the port-a-shop and step off your boat.")
                return
            end
        end
    end

    if key == "escape" and gamestate.get() == GameType.FISHING then
        local result = fishing_minigame.cancel_fishing()
        if result then
            state.fishing.runtime.add_catch_text("Fishing cancelled!")
            print("Fishing cancelled!")
            -- reset cooldown
            state.fishing.runtime.set_player_just_failed_fishing(true)
            state.fishing.runtime.set_fishing_cooldown(game_config.fishing_cooldown)
            gamestate.set(GameType.VOYAGE)
        end
    end
end

function game.update(dt)
    force_corruption_sleep_if_needed()
    update_steps.day_night_cycle(dt, state)
    morningtext.observe_time(get_time_of_day_hours())
    morningtext.update(dt)
    alert.update(dt)
    detect_cheating()
    update_steps.sleep_fade_state(dt, state)

    if gamestate.get():find(GameType.SHOP, 1, true) or (crew_management.is_open and crew_management.is_open()) then
        for _, button in pairs(mobile_controls.buttons) do
            button.pressed = false
        end
    end

    if update_steps.handle_back_to_menu_button(state) then
        return GameType.MENU
    end

    crew_management.handle_buttons(state)
    local hunger_result = hunger.update(dt, state)
    if hunger_result then
        return hunger_result
    end

    update_steps.shop_and_navigation(dt, state)
    update_steps.voyage_state(dt, state)
    update_steps.fishing_minigame_state(dt, state)

    ripples:update(dt, player_ship)

    local combat_result = update_steps.combat_state(dt, state)
    if combat_result then
        return combat_result
    end

    update_steps.camera_follow(state)
    update_steps.special_fish_event(dt, state)
    mods.run_hook("on_update", dt, state)

    return nil
end

function game.draw()
    draw_steps.draw_background(state)
    draw_steps.draw_world(state)
    draw_steps.draw_post_world_overlays(state)
    draw_steps.draw_time_and_debug(state)
    draw_steps.draw_final_ui(state)
    draw_steps.draw_special_event_overlay(state)
    mods.run_hook("on_draw", state)
end

-- make player_ship accessible to other modules
game.player_ship = player_ship
game.reset_state = reset_game

-- make mobile control functions accessible to other modules
game.handle_mobile_button_press = handle_mobile_button_press
game.handle_mobile_button_release = handle_mobile_button_release
game.set_mods_enabled = function(enabled)
    mods.set_enabled(enabled)
end
game.are_mods_enabled = function()
    return mods.is_enabled()
end

return game
