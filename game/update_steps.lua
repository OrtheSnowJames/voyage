local update_steps = {}
local constants = require("game.constants")
local time_utils = require("game.time_utils")
local RECOVERY_BAY_MAX = constants.combat.recovery_bay_max or 15

local function clear_catch_texts(state)
    local catch_texts = state.fishing.runtime.get_catch_texts()
    for i = #catch_texts, 1, -1 do
        catch_texts[i] = nil
    end
end

local function update_enemy_ripples(state)
    local enemies = state.enemy.module.get_enemies()
    local ship_ripples = state.world.ship_ripples
    local ripple_spawn_distance = state.world.ripple_spawn_distance
    local max_ripples = state.world.max_ripples
    local player_ship = state.player

    for _, enemy in ipairs(enemies) do
        local dist_since_last_ripple = math.abs(enemy.x - enemy.last_ripple_pos.x)

        if enemy.speed > 50 and dist_since_last_ripple > ripple_spawn_distance then
            table.insert(ship_ripples, 1, {
                x = enemy.x,
                y = enemy.y,
                spawn_time = player_ship.time_system.time,
                intensity = math.min(0.8, enemy.speed / 500)
            })
            enemy.last_ripple_pos.x = enemy.x

            if #ship_ripples > max_ripples then
                table.remove(ship_ripples)
            end
        end
    end
end

local function handle_enemy_collision(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local player_ship = state.player
    local combat_state = state.combat.state.combat
    local fishing_runtime = state.fishing.runtime
    local fishing_minigame = state.fishing.minigame

    local collided_enemy = state.enemy.module.check_collision(player_ship.x, player_ship.y, player_ship.radius)
    if not collided_enemy then
        return
    end

    clear_catch_texts(state)
    fishing_runtime.set_fishing_cooldown(0)

    if gamestate.get() == GameType.FISHING then
        local result = fishing_minigame.combat_interrupt()
        if result then
            fishing_runtime.add_catch_text("Fish escaped due to combat!")
            print('Fishing interrupted by combat - fish escaped!')
        end
    end

    gamestate.set(GameType.COMBAT)
    combat_state.zoom_progress = 0
    combat_state.enemy = collided_enemy
    combat_state.result = nil
    combat_state.is_fully_zoomed = false
    combat_state.result_display_time = 3.0
end

function update_steps.day_night_cycle(dt, state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local player_ship = state.player

    if gamestate.get() ~= GameType.COMBAT then
        if not player_ship.time_system.is_sleeping then
            player_ship.time_system.time = player_ship.time_system.time + dt

            if not player_ship.reached_first_1130 and state.actions.get_time_of_day_hours() >= state.constants.fish.gold_sturgeon_unlock_hour then
                player_ship.reached_first_1130 = true
            end

            if player_ship.time_system.time >= player_ship.time_system.DAY_LENGTH then
                state.actions.increase_rainbows_for_new_day()
                player_ship.time_system.time = 0
                player_ship.time_system.is_fading = true
                player_ship.time_system.fade_timer = 0
                player_ship.time_system.fade_direction = "out"
                gamestate.set(GameType.SLEEPING)
                print('Starting night transition...')
            end
        end
    end
end

function update_steps.sleep_fade_state(dt, state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local player_ship = state.player
    local time_system = player_ship.time_system

    if gamestate.get() ~= GameType.COMBAT then
        if time_system.is_fading then
            time_system.fade_timer = time_system.fade_timer + dt

            if time_system.fade_direction == "out" then
                time_system.fade_alpha = math.min(1, time_system.fade_timer / time_system.FADE_DURATION)

                if time_system.fade_timer >= time_system.FADE_DURATION then
                    time_system.is_sleeping = true
                    time_system.sleep_timer = 0
                    time_system.fade_direction = "wait"
                    time_system.fade_timer = 0
                    state.actions.during_sleep()
                end
            elseif time_system.fade_direction == "wait" then
                time_system.sleep_timer = time_system.sleep_timer + dt
                if time_system.sleep_timer >= time_system.SLEEP_DURATION then
                    time_system.fade_direction = "in"
                    time_system.fade_timer = 0
                end
            elseif time_system.fade_direction == "in" then
                time_system.fade_alpha = math.max(0, 1 - (time_system.fade_timer / time_system.FADE_DURATION))

                if time_system.fade_timer >= time_system.FADE_DURATION then
                    time_system.is_fading = false
                    time_system.is_sleeping = false
                    time_system.fade_alpha = 0
                    gamestate.set(GameType.VOYAGE)
                    state.ui.morningtext.start(player_ship.rainbows)

                    player_ship.name = state.system.menu.get_name()
                    state.system.serialize.save_data(state.system.game.get_saveable_data())
                end
            end
        end
    end
end

function update_steps.handle_back_to_menu_button(state)
    local suit = state.ui.suit
    if suit.Button("Save & Return", {id = "menu"}, suit.layout:row(120, 30)).hit then
        state.player.name = state.system.menu.get_name()
        local data = state.system.game.get_saveable_data()
        local time_system = data.time_system or {}
        local day_length = tonumber(time_system.DAY_LENGTH) or state.constants.time.day_length
        local unlock_time = time_utils.time_of("11:30", day_length) or ((11.5 / 12) * day_length)
        local lock_time = time_utils.time_of("11:59", day_length) or (day_length - (day_length / (12 * 60)))
        local current_time = tonumber(time_system.time) or 0

        -- don't allow resetting progress before 11:30 once the threshold was reached
        if current_time >= unlock_time then
            time_system.time = lock_time
            data.time_system = time_system
        end

        state.system.serialize.save_data(data)
        state.system.gamestate.set(state.system.gametype.MENU)
        return true
    end

    return false
end

function update_steps.shop_and_navigation(dt, state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local current_state = gamestate.get()

    if current_state == GameType.VOYAGE or current_state:find(GameType.SHOP, 1, true) then
        state.shop.module.update(gamestate, state.player, state.shop.keeper, state.fishing.config)
        if current_state == GameType.VOYAGE then
            state.player:update(dt)
        end
        state.actions.update_ship_animation(dt)
        state.actions.update_shore_objects()
        state.shop.keeper:update(state.player.x, state.player.y, dt)
        if current_state == GameType.VOYAGE and state.shop.module.resolve_boat_collisions then
            state.shop.module.resolve_boat_collisions(state.player, state.shop.keeper)
        end
    end
end

function update_steps.voyage_state(dt, state)
    if state.system.gamestate.get() ~= state.system.gametype.VOYAGE then
        return
    end

    if state.player.is_on_foot then
        state.fishing.runtime.update_catch_texts(dt)
        return
    end

    state.fishing.runtime.update_catch_texts(dt)
    state.enemy.module.update(dt, state.camera, state.player.x, state.player.y)
    update_enemy_ripples(state)
    handle_enemy_collision(state)
    state.fishing.runtime.fish(dt)
end

function update_steps.fishing_minigame_state(dt, state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    if gamestate.get() ~= GameType.FISHING then
        return
    end

    local result = state.fishing.minigame.update(dt)
    if not result then
        return
    end

    gamestate.set(GameType.VOYAGE)
    if result.success then
        local stored_in_inventory = state.fishing.runtime.record_catch("You", result.fish_name)
        if stored_in_inventory then
            print('You caught: ' .. result.fish_name .. ' in ' .. string.format('%.1f', result.total_time) .. 's')
        end

        state.actions.trigger_ship_animation()
        print('Final fish: ' .. result.fish_name .. ' (Quality score: ' .. result.quality_score .. ')')
    else
        state.fishing.runtime.add_catch_text("Fish escaped!")
        print('Fish escaped!')
        state.fishing.runtime.set_player_just_failed_fishing(true)
    end

    state.fishing.runtime.set_fishing_cooldown(state.fishing.config.fishing_cooldown)
end

function update_steps.combat_state(dt, state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local player_ship = state.player
    local combat_state = state.combat.state.combat
    local camera = state.camera

    if gamestate.get() ~= GameType.COMBAT then
        return nil
    end

    combat_state.zoom_progress = math.min(1, combat_state.zoom_progress + dt / combat_state.zoom_duration)
    local zoom_factor = 1 + (combat_state.target_zoom - 1) * combat_state.zoom_progress

    local center_x = (player_ship.x + combat_state.enemy.x) / 2
    local center_y = (player_ship.y + combat_state.enemy.y) / 2

    camera:zoom(zoom_factor / camera.scale, center_x, center_y)

    if combat_state.zoom_progress >= 1 then
        if not combat_state.is_fully_zoomed then
            combat_state.is_fully_zoomed = true

            local enemy = combat_state.enemy
            local result = state.combat.module.combat(
                player_ship.men,
                enemy.size,
                state.combat.module.get_sword_level(player_ship.sword),
                state.combat.module.get_sword_top_rarity(),
                player_ship.y
            )

            if result.victory then
                player_ship.men = player_ship.men - result.casualties
                local open_slots = math.max(0, RECOVERY_BAY_MAX - player_ship.fainted_men)
                local stored_fainted = math.min(open_slots, result.fainted)
                local overflow_fainted = math.max(0, result.fainted - stored_fainted)
                player_ship.fainted_men = player_ship.fainted_men + stored_fainted
                result.fainted_stored = stored_fainted
                result.fainted_overflow = overflow_fainted
                combat_state.result = result
                combat_state.result_display_time = 3.0
            else
                combat_state.result = result
                combat_state.defeat_flash.active = true
                combat_state.defeat_flash.alpha = 0
                combat_state.defeat_flash.timer = 0
            end
        end
    end

    if combat_state.result then
        if combat_state.result.victory then
            if combat_state.result_display_time > 0 then
                combat_state.result_display_time = combat_state.result_display_time - dt
                if combat_state.result_display_time <= 0 then
                    state.enemy.module.remove_enemy(combat_state.enemy)
                    gamestate.set(GameType.VOYAGE)
                    combat_state.zoom_progress = 0
                    combat_state.is_fully_zoomed = false
                    combat_state.result = nil
                    camera.scale = 1
                end
            end
        else
            if combat_state.defeat_flash.active then
                combat_state.defeat_flash.timer = combat_state.defeat_flash.timer + dt

                if combat_state.defeat_flash.timer >= combat_state.defeat_flash.text_display_time then
                    local flash_time = combat_state.defeat_flash.timer - combat_state.defeat_flash.text_display_time
                    combat_state.defeat_flash.alpha = math.min(1, flash_time / combat_state.defeat_flash.duration)

                    if combat_state.defeat_flash.alpha >= 1 then
                        local has_gold_sturgeon = false
                        for _, fish_name in ipairs(player_ship.caught_fish) do
                            if fish_name == "Gold Sturgeon" then
                                has_gold_sturgeon = true
                                break
                            end
                        end

                        if has_gold_sturgeon then
                            love.filesystem.write("note.txt", "A golden catch, a silver grave.")
                            print('A mysterious note has been left behind...')
                        end

                        state.actions.reset_game()
                        gamestate.set(GameType.MENU)
                        return GameType.MENU
                    end
                end
            end
        end
    end

    return nil
end

function update_steps.camera_follow(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local player_ship = state.player
    local camera = state.camera
    local canvas = state.system.size

    if gamestate.get() == GameType.COMBAT then
        local enemy = state.combat.state.combat.enemy
        local center_x = (player_ship.x + enemy.x) / 2
        local center_y = (player_ship.y + enemy.y) / 2

        camera:goto(
            center_x - canvas.CANVAS_WIDTH / (2 * camera.scale),
            center_y - canvas.CANVAS_HEIGHT / (2 * camera.scale)
        )
    else
        local focus_x = player_ship.x
        local focus_y = player_ship.y
        if player_ship.is_on_foot then
            focus_x = player_ship.on_foot_x or player_ship.x
            focus_y = player_ship.on_foot_y or player_ship.y
        end

        camera:goto(
            focus_x - canvas.CANVAS_WIDTH / 2,
            focus_y - canvas.CANVAS_HEIGHT / 2
        )
    end
end

function update_steps.special_fish_event(dt, state)
    local special_fish_event = state.fishing.event
    if not special_fish_event.active then
        return
    end

    special_fish_event.timer = special_fish_event.timer + dt

    if special_fish_event.timer >= special_fish_event.duration then
        special_fish_event.active = false
        table.insert(state.player.caught_fish, special_fish_event.fish_name)
        print('Special fish caught: ' .. special_fish_event.fish_name)
    end
end

return update_steps
