local constants = require("game.constants")

local state = {}
local START_CREW = constants.ship.start_crew

local function create_mobile_buttons()
    return {
        forward = {x = 0, y = 0, pressed = false, key = "w"},
        left = {x = 0, y = 0, pressed = false, key = "a"},
        right = {x = 0, y = 0, pressed = false, key = "d"},
        fish = {x = 0, y = 0, pressed = false, key = "f"}
    }
end

local function create_player_time_system()
    return {
        time = 0,
        DAY_LENGTH = constants.time.day_length,
        SLEEP_DURATION = constants.time.sleep_duration,
        sleep_timer = 0,
        fade_alpha = 0,
        is_sleeping = false,
        is_fading = false,
        FADE_DURATION = constants.time.fade_duration,
        fade_timer = 0,
        fade_direction = "in"
    }
end

local function create_player_ship(sprite)
    local hunger_levels = {}
    for i = 1, START_CREW do
        hunger_levels[i] = constants.hunger.start
    end

    return {
        x = constants.ship.start_x,
        y = constants.ship.start_y,
        name = "",
        men = START_CREW,
        loyal_men = START_CREW,
        fainted_men = 0,
        velocity_x = 0,
        velocity_y = 0,
        rotation = 0,
        target_rotation = 0,
        max_speed = constants.ship.max_speed,
        acceleration = constants.ship.acceleration,
        deceleration = constants.ship.deceleration,
        turn_speed = constants.ship.turn_speed,
        turn_penalty = constants.ship.turn_penalty,
        reverse_multiplier = constants.ship.reverse_multiplier,
        radius = constants.ship.radius,
        color = {1, 1, 1, 1},
        rod = "Basic Rod",
        sword = "Basic Sword",
        direction = 0,
        caught_fish = {},
        inventory = {},
        hunger_levels = hunger_levels,
        hunger_alert_text = "",
        hunger_alert_timer = 0,
        rainbows = 0,
        corruption_started = false,
        debug_menu_opened = false,
        reached_first_1130 = false,
        time_system = create_player_time_system(),
        sprite = sprite
    }
end

function state.create(sprite)
    return {
        game_config = {
            fishing_cooldown = constants.config.fishing_cooldown,
            catch_text_spacing = constants.config.catch_text_spacing
        },
        special_fish_event = {
            active = false,
            timer = 0,
            duration = constants.special_fish_event.duration,
            fish_name = "",
            caught_gold_sturgeon = false
        },
        debug_options = {
            showDebugButtons = false
        },
        mobile_controls = {
            enabled = constants.mobile_controls.enabled_default,
            button_size = constants.mobile_controls.button_size,
            button_spacing = constants.mobile_controls.button_spacing,
            button_alpha = constants.mobile_controls.button_alpha,
            buttons = create_mobile_buttons()
        },
        game_state = {
            combat = {
                zoom_progress = 0,
                zoom_duration = constants.combat.zoom_duration,
                target_zoom = constants.combat.target_zoom,
                enemy = nil,
                result_display_time = constants.combat.result_display_time,
                result = nil,
                is_fully_zoomed = false,
                defeat_flash = {
                    active = false,
                    alpha = 0,
                    duration = constants.combat.defeat_flash_duration,
                    timer = 0,
                    text_display_time = constants.combat.defeat_text_display_time
                }
            }
        },
        camera = {
            x = 0,
            y = 0,
            scale = 1
        },
        player_ship = create_player_ship(sprite),
        ripples = {
            particles = {},
            maxParticles = constants.ambient_ripples.max_particles,
            spawnTimer = 0,
            baseSpawnRate = constants.ambient_ripples.base_spawn_rate,
            spawnMargin = constants.ambient_ripples.spawn_margin,
            minVisibleRipples = constants.ambient_ripples.min_visible
        }
    }
end

return state
