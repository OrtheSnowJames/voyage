local fishing_level = 1000 -- the big number that separates the fishing levels

local constants = {
    fishing_level = fishing_level,
    config = {
        fishing_cooldown = 5,
        catch_text_spacing = 20
    },
    action_display = {
        keycap = {
            default_padding = 12,
            corner_radius = 10,
            depth_offset = 3,
            font_size = 30,
            face_color = {0.95, 0.92, 0.84, 1.0},
            shadow_color = {0.32, 0.28, 0.20, 1.0},
            border_color = {0.74, 0.66, 0.50, 1.0},
            text_color = {0.14, 0.12, 0.08, 1.0},
            highlight_color = {1.0, 1.0, 1.0, 0.32}
        },
        prompt = {
            font_path = "NotoSans-VariableFont_wdth,wght.ttf",
            font_size = 28,
            margin = 18,
            width = 560,
            height = 112,
            corner_radius = 24,
            border_line_width = 3,
            normal_color = {0.11, 0.16, 0.24, 1.0},
            hover_color = {0.14, 0.20, 0.30, 1.0},
            pressed_color = {0.09, 0.13, 0.19, 1.0},
            border_color = {0.98, 0.89, 0.56, 1.0},
            frame_color = {0.25, 0.33, 0.45, 1.0},
            inner_border_color = {1.0, 1.0, 1.0, 0.16},
            shadow_color = {0.01, 0.03, 0.07, 0.60},
            text_color = {0.98, 0.99, 1.0, 1.0},
            text_shadow_color = {0.0, 0.0, 0.0, 0.50},
            press_offset = 2,
            bottom_margin = 28
        },
        mouse_decal = {
            border_line_width = 2,
            shadow_offset_y = 3,
            fishing_size = 56,
            fishing_right_margin = 28,
            fishing_y_ratio = 0.5,
            wheel_padding_ratio = 0.06,
            loop_color = {0.549, 0.792, 0.859, 0.92},
            loop_line_width = 3,
            loop_radius_scale = 1.12,
            loop_arrow_size_ratio = 0.20,
            loop_angle_degrees = 0,
            body_color = {0.08, 0.09, 0.11, 1.0},
            button_color = {0.13, 0.14, 0.17, 1.0},
            button_pressed_color = {0.05, 0.06, 0.08, 1.0},
            wheel_color = {0.02, 0.02, 0.03, 1.0},
            wheel_slot_color = {0.16, 0.17, 0.21, 1.0},
            wheel_slot_shadow_color = {0.02, 0.02, 0.03, 0.70},
            wheel_slot_border_color = {0.34, 0.36, 0.43, 1.0},
            split_color = {0.32, 0.34, 0.40, 1.0},
            border_color = {0.70, 0.72, 0.79, 1.0},
            highlight_color = {1.0, 1.0, 1.0, 0.12},
            shadow_color = {0.0, 0.0, 0.0, 0.45}
        }
    },
    special_fish_event = {
        duration = 5.0
    },
    mobile_controls = {
        enabled_default = true,
        button_size = 60,
        button_spacing = 20,
        button_alpha = 0.6
    },
    combat = {
        zoom_duration = 2.0,
        target_zoom = 2.0,
        result_display_time = 3.0,
        defeat_flash_duration = 3.0,
        defeat_text_display_time = 2.0,
        careless_crew_advantage_multiplier = 3,
        fainted_recovery_penalty_per_enemy = 0.005,
        recovery_bay_max = 15,
        dangerous_area_buffer = 10
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
        reverse_multiplier = 0.5,
        drowning_time = 25 -- seconds
    },
    time = {
        day_length = 12 * 60,
        sleep_duration = 10,
        fade_duration = 2,
        morningtext_fade_duration = 2
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
        dock_interaction_range = 25,
        board_interaction_range = 90,
        dock_tip_offset_y = 16,
        disembark_offset_y = -4,
        on_foot_speed = 125,
        on_foot_max_walk_up = 240,
        on_foot_max_walk_side = 260,
        on_foot_max_walk_down = 0,
        main_dock_walk_half_width = 20,
        main_shopkeeper_side_offset_x = 42,
        main_shopkeeper_shore_offset_y = -100,
        ECON = {
            shop_base = 50,
            shop_target_cycles_base = 4,
            shop_target_cycles_step = 0.9,

            crew_start_cost = 15,
            crew_linear_cost = 10,
            crew_quadratic_cost = 1.2,

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
        night_fish_value_multiplier = 777,
        gold_sturgeon_sell_price = 60000,
        fish_icon_width = 64,
        fish_icon_height = 64,
        minigame = {
            bar_width = 60,
            bar_height = 300,
            bar_levels = 4,
            gravity = 200,
            rod_speed = 300,
            catch_time = 5.0,
            catch_range = 40,
            progress_start = 0.5,
            perfect_alignment_bonus = 0.3,
            night_fish_catch_denominator = 90
        }
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
