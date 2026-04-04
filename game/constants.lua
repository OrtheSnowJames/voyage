local fishing_level = 1000 -- the big number that separates the fishing levels

local constants = {
    fishing_level = fishing_level,
    config = {
        fishing_cooldown = 5,
        catch_text_spacing = 20
    },
    special_fish_event = {
        duration = 5.0
    },
    mobile_controls = {
        enabled_default = true,
        button_size = 60,
        button_spacing = 20,
        button_alpha = 0.8
    },
    combat = {
        zoom_duration = 2.0,
        target_zoom = 2.0,
        result_display_time = 3.0,
        defeat_flash_duration = 3.0,
        defeat_text_display_time = 2.0,
        careless_crew_advantage_multiplier = 3,
        fainted_recovery_penalty_per_enemy = 0.005
    },
    ship = {
        start_x = 100,
        start_y = 100,
        start_crew = 1,
        radius = 20,
        max_speed = 200,
        acceleration = 50,
        deceleration = 30,
        turn_speed = 2,
        turn_penalty = 0.7,
        reverse_multiplier = 0.5
    },
    time = {
        day_length = 12 * 60,
        sleep_duration = 10,
        fade_duration = 2
    },
    world = {
        shore_division = 60,
        shore_object_count = 20,
        max_ripples = 50,
        ripple_spawn_distance = 20
    },
    ambient_ripples = {
        max_particles = 50,
        base_spawn_rate = 0.3,
        spawn_margin = 100,
        min_visible = 5
    },
    shops = {
        spacing = fishing_level,
        size = { width = 60, height = 40 },
        interaction_range = 50,
        no_fish_line_distance = 50,
        ECON = {
            shop_base = 50,
            shop_target_cycles_base = 4,
            shop_target_cycles_step = 0.9,

            crew_start_cost = 8,
            crew_linear_cost = 6,
            crew_quadratic_cost = 0.6,

            sword_base = 11,
            sword_growth = 1.7,
        
            rod_base = 12,
            rod_growth = 1.75,
        
            speed_base = 15,
            speed_growth = 1.65,
        
            cooldown_base = 35,
            cooldown_growth = 1.75,
        }
    },
    fish = {
        gold_sturgeon_unlock_hour = 11.5,
        regular_fish_count = 30,
        value_offset = 2,
        gold_sturgeon_value = 100000,
        gold_sturgeon_sell_price = 60000
    },
    hunger = {
        max = 100,
        start = 100,
        days_without_food_to_die = 1,
        decay_per_second = 0.05,
        half_threshold = 0.5,
        feed_below_current_percent = 5,
        feed_lowest_current_percent = 25,
        feed_mid_current_percent = 50,
        feed_highest_current_percent = 90,
        feed_above_current_percent = 100,
        feed_min = 1,
        feed_max = 100,
        alert_duration = 4
    },
    cheat = {
        depth_tolerance = 10,
        time_skip_threshold_seconds = 20,
        money_base_threshold = 3000,
        money_growth_per_depth = 1.75,
        money_per_crew_bonus = 500
    },
    corruption = {
        start_value = 0.1,
        step = 0.1
    }
}

return constants
