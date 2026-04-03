local constants = {
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
        defeat_text_display_time = 2.0
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
        spacing = 1000,
        size = { width = 60, height = 40 },
        interaction_range = 50,
        no_fish_line_distance = 50
    },
    fish = {
        gold_sturgeon_unlock_hour = 11.5,
        regular_fish_count = 30
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
