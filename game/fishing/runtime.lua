local runtime_module = {}

local function update_catch_text_offsets(catch_texts, spacing)
    for i, catch in ipairs(catch_texts) do
        catch.y_offset = (i - 1) * spacing
    end
end

function runtime_module.create(deps)
    local fishing = deps.fishing

    local runtime_state = {
        catch_texts = {},
        fishing_pressed = false,
        wait_for_fish_release = false,
        fishing_cooldown = 0,
        last_cooldown = deps.game_config.fishing_cooldown,
        player_just_failed_fishing = false
    }

    local runtime = {}

    local function reset_runtime_state()
        for i = #runtime_state.catch_texts, 1, -1 do
            runtime_state.catch_texts[i] = nil
        end
        runtime_state.fishing_pressed = false
        runtime_state.wait_for_fish_release = false
        runtime_state.fishing_cooldown = 0
        runtime_state.last_cooldown = deps.game_config.fishing_cooldown
        runtime_state.player_just_failed_fishing = false
    end

    local function get_roll_context()
        return fishing.build_roll_context(deps.player_ship)
    end

    local function add_catch_text(text)
        table.insert(runtime_state.catch_texts, 1, {
            text = text,
            time = deps.game_config.fishing_cooldown,
            y_offset = 0
        })

        if #runtime_state.catch_texts > deps.get_max_catch_texts() then
            table.remove(runtime_state.catch_texts)
        end

        update_catch_text_offsets(runtime_state.catch_texts, deps.game_config.catch_text_spacing)
    end

    local function record_catch(fisher_name, fish_caught)
        if fishing.is_special_fish(fish_caught) then
            deps.trigger_special_fish_event(fish_caught)
            return false
        end

        add_catch_text((fisher_name or "You") .. ": " .. fish_caught)
        table.insert(deps.player_ship.caught_fish, fish_caught)
        return true
    end

    local function crew_auto_fish()
        local ctx = get_roll_context()
        deps.trigger_ship_animation()

        for i = 1, deps.player_ship.men do
            local fish_caught = fishing.roll_from_context(ctx)
            record_catch("Crew " .. i, fish_caught)
        end
    end

    function runtime.reset_state()
        reset_runtime_state()
    end

    function runtime.add_catch_text(text)
        add_catch_text(text)
    end

    function runtime.record_catch(fisher_name, fish_caught)
        return record_catch(fisher_name, fish_caught)
    end

    function runtime.update_catch_texts(dt)
        for i = #runtime_state.catch_texts, 1, -1 do
            local catch = runtime_state.catch_texts[i]
            if not deps.special_fish_event.active then
                catch.time = catch.time - dt
            end
            if catch.time <= 0 then
                table.remove(runtime_state.catch_texts, i)
                update_catch_text_offsets(runtime_state.catch_texts, deps.game_config.catch_text_spacing)
            end
        end
    end

    function runtime.fish(dt)
        local fishing_down = love.keyboard.isDown("f") or deps.mobile_controls.buttons.fish.pressed
        local fishing_just_pressed = fishing_down and not runtime_state.fishing_pressed
        runtime_state.fishing_pressed = fishing_down

        local prev_cooldown = runtime_state.fishing_cooldown
        runtime_state.fishing_cooldown = math.max(0, runtime_state.fishing_cooldown - dt)

        local blocked_by_shop_line = deps.is_on_shop_line(deps.player_ship.y)
        if prev_cooldown > 0 and runtime_state.fishing_cooldown <= 0 then
            if blocked_by_shop_line then
                print("Crew cannot fish on shop lines.")
            elseif not runtime_state.player_just_failed_fishing then
                crew_auto_fish()
            else
                runtime_state.player_just_failed_fishing = false
                print("Crew did not fish because player failed.")
            end
        end

        if runtime_state.wait_for_fish_release then
            if not fishing_down then
                runtime_state.wait_for_fish_release = false
            end
            return
        end

        if fishing_just_pressed and runtime_state.fishing_cooldown <= 0 and deps.gamestate.get() == deps.GameType.VOYAGE then
            if blocked_by_shop_line then
                print("You can't fish on shop lines.")
                return
            end

            local ctx = get_roll_context()
            deps.fishing_minigame.start_fishing(
                ctx.fish_available,
                ctx.rod_rarity,
                ctx.depth_level,
                deps.get_current_water_color()
            )
            deps.gamestate.set(deps.GameType.FISHING)
        end
    end

    function runtime.get_catch_texts()
        return runtime_state.catch_texts
    end

    function runtime.get_fishing_cooldown()
        return runtime_state.fishing_cooldown
    end

    function runtime.set_fishing_cooldown(value)
        runtime_state.fishing_cooldown = value
    end

    function runtime.get_last_cooldown()
        return runtime_state.last_cooldown
    end

    function runtime.set_last_cooldown(value)
        runtime_state.last_cooldown = value
    end

    function runtime.set_player_just_failed_fishing(value)
        runtime_state.player_just_failed_fishing = value
    end

    function runtime.block_fishing_until_release()
        runtime_state.wait_for_fish_release = true
        runtime_state.fishing_pressed = true
    end

    return runtime
end

return runtime_module
