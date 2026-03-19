local fishing_runtime = {}

function fishing_runtime.create(deps)
    local state = {
        catch_texts = {},
        fishing_pressed = false,
        fishing_cooldown = 0,
        last_cooldown = deps.game_config.fishing_cooldown,
        player_just_failed_fishing = false
    }

    local runtime = {}

    function runtime.reset_state()
        for i = #state.catch_texts, 1, -1 do
            state.catch_texts[i] = nil
        end
        state.fishing_pressed = false
        state.fishing_cooldown = 0
        state.last_cooldown = deps.game_config.fishing_cooldown
        state.player_just_failed_fishing = false
    end

    function runtime.add_catch_text(text)
        table.insert(state.catch_texts, 1, {
            text = text,
            time = deps.game_config.fishing_cooldown,
            y_offset = 0
        })

        if #state.catch_texts > deps.get_max_catch_texts() then
            table.remove(state.catch_texts)
        end

        for i, catch in ipairs(state.catch_texts) do
            catch.y_offset = (i - 1) * deps.game_config.catch_text_spacing
        end
    end

    function runtime.update_catch_texts(dt)
        for i = #state.catch_texts, 1, -1 do
            local catch = state.catch_texts[i]
            if not deps.special_fish_event.active then
                catch.time = catch.time - dt
            end
            if catch.time <= 0 then
                table.remove(state.catch_texts, i)
                for j = i, #state.catch_texts do
                    state.catch_texts[j].y_offset = (j - 1) * deps.game_config.catch_text_spacing
                end
            end
        end
    end

    function runtime.fish(dt)
        local fishing_released = (love.keyboard.isDown('f') or deps.mobile_controls.buttons.fish.pressed) and not state.fishing_pressed
        state.fishing_pressed = love.keyboard.isDown('f') or deps.mobile_controls.buttons.fish.pressed

        local prev_cooldown = state.fishing_cooldown
        state.fishing_cooldown = math.max(0, state.fishing_cooldown - dt)

        local blocked_by_shop_line = deps.is_on_shop_line(deps.player_ship.y)
        if prev_cooldown > 0 and state.fishing_cooldown <= 0 then
            if blocked_by_shop_line then
                print('Crew cannot fish on shop lines.')
            elseif not state.player_just_failed_fishing then
                local fish_available = deps.fishing.get_fish_avalible(deps.player_ship.x, deps.player_ship.y, deps.player_ship.time_system.time)
                deps.trigger_ship_animation()
                for i = 1, deps.player_ship.men do
                    local fish_caught = deps.fishing.fish(
                        deps.fishing.get_rod_rarity(deps.player_ship.rod),
                        deps.fishing.get_rod_top_rarity(),
                        fish_available,
                        deps.player_ship.y
                    )

                    if deps.fishing.is_special_fish(fish_caught) then
                        deps.trigger_special_fish_event(fish_caught)
                    else
                        runtime.add_catch_text('Crew ' .. i .. ': ' .. fish_caught)
                        table.insert(deps.player_ship.caught_fish, fish_caught)
                        print('Crew member ' .. i .. ' caught: ' .. fish_caught)
                    end
                end
            else
                state.player_just_failed_fishing = false
                print('Crew did not fish because player failed.')
            end
        end

        if fishing_released and state.fishing_cooldown <= 0 and deps.gamestate.get() == deps.GameType.VOYAGE then
            if blocked_by_shop_line then
                print("You can't fish on shop lines.")
                return
            end

            local fish_available = deps.fishing.get_fish_avalible(deps.player_ship.x, deps.player_ship.y, deps.player_ship.time_system.time)
            local depth_level = math.floor(math.abs(deps.player_ship.y) / 1000)
            if depth_level < 1 then
                depth_level = 1
            end

            local current_water_color = deps.get_current_water_color()
            deps.fishing_minigame.start_fishing(
                fish_available,
                deps.fishing.get_rod_rarity(deps.player_ship.rod),
                depth_level,
                current_water_color
            )
            deps.gamestate.set(deps.GameType.FISHING)
        end
    end

    function runtime.get_catch_texts()
        return state.catch_texts
    end

    function runtime.get_fishing_cooldown()
        return state.fishing_cooldown
    end

    function runtime.set_fishing_cooldown(value)
        state.fishing_cooldown = value
    end

    function runtime.get_last_cooldown()
        return state.last_cooldown
    end

    function runtime.set_last_cooldown(value)
        state.last_cooldown = value
    end

    function runtime.set_player_just_failed_fishing(value)
        state.player_just_failed_fishing = value
    end

    return runtime
end

return fishing_runtime
