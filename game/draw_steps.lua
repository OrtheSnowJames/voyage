local draw_steps = {}
local hunger = require("game.hunger")
local crew_management = require("game.crew_management")

local function prepare_ripple_uniform_data(state)
    local ripple_x_data = {}
    local ripple_y_data = {}
    local ripple_time_data = {}
    local ripple_intensity_data = {}
    local ship_ripples = state.world.ship_ripples
    local max_ripples = state.constants.world.max_ripples

    for i = 1, max_ripples do
        local ripple = ship_ripples[i]
        if ripple then
            table.insert(ripple_x_data, ripple.x)
            table.insert(ripple_y_data, ripple.y)
            table.insert(ripple_time_data, ripple.spawn_time)
            table.insert(ripple_intensity_data, ripple.intensity)
        else
            table.insert(ripple_x_data, 0)
            table.insert(ripple_y_data, 0)
            table.insert(ripple_time_data, 0)
            table.insert(ripple_intensity_data, 0)
        end
    end

    return ripple_x_data, ripple_y_data, ripple_time_data, ripple_intensity_data
end

function draw_steps.draw_background(state)
    local water_color = state.actions.get_current_water_color()
    local player_ship = state.player
    local camera = state.camera
    local size = state.system.size
    local water_shader = state.shore.water_shader
    local ship_ripples = state.world.ship_ripples

    love.graphics.clear(0, 0, 0, 1)

    local ripple_x_data, ripple_y_data, ripple_time_data, ripple_intensity_data = prepare_ripple_uniform_data(state)

    love.graphics.setShader(water_shader)
    water_shader:send("time", player_ship.time_system.time)
    water_shader:send("waterColor", {water_color[1], water_color[2], water_color[3]})
    water_shader:send("shoreY", state.shore.division)
    water_shader:send("camera", {camera.x, camera.y})
    water_shader:send("resolution", {size.CANVAS_WIDTH, size.CANVAS_HEIGHT})
    water_shader:send("ripple_count", #ship_ripples)
    water_shader:send("ripple_sources_x", unpack(ripple_x_data))
    water_shader:send("ripple_sources_y", unpack(ripple_y_data))
    water_shader:send("ripple_spawn_times", unpack(ripple_time_data))
    water_shader:send("ripple_intensities", unpack(ripple_intensity_data))

    love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)
    love.graphics.setShader()

    love.graphics.push()
    love.graphics.translate(-camera.x * camera.scale, -camera.y * camera.scale)
    love.graphics.scale(camera.scale)
end

function draw_steps.draw_shore(state)
    local camera = state.camera
    local size = state.system.size
    local shore = state.shore
    local view_width = size.CANVAS_WIDTH / camera.scale

    for _, obj in ipairs(shore.objects) do
        if obj.x + shore.width > camera.x and obj.x < camera.x + view_width then
            love.graphics.setShader(shore.shader)
            shore.shader:send("greenPixel", {0, 1, 0})

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(shore.texture, shore.quad, obj.x, obj.y - shore.height / 2.2, 0, 1, -1, 0, shore.quad_height)

            local overlap = 10
            for i = 1, 10 do
                local y_pos = obj.y - shore.quad_height - ((i - 1) * shore.bottom_half_quad_height) + ((i - 1) * overlap)
                love.graphics.draw(shore.texture, shore.bottom_half_quad, obj.x, y_pos, 0, 1, -1, 0, shore.bottom_half_quad_height)
            end

            love.graphics.setShader()
        end
    end
end

local function draw_enemy_in_combat(state, glow_intensity)
    local combat_state = state.combat.state.combat
    local enemy = combat_state.enemy
    local player_ship = state.player
    if not enemy then
        return
    end

    if glow_intensity > 0 then
        state.actions.draw_ship_glow(enemy.x, enemy.y, enemy.radius, {1, 0.5, 0.5}, glow_intensity)
    end

    love.graphics.push()
    love.graphics.translate(enemy.x, enemy.y)
    love.graphics.rotate((enemy.direction > 0 and 0 or math.pi) + math.pi)

    love.graphics.setColor(1, 0, 0, 1)
    local target_width = 64
    local sprite_scale = target_width / player_ship.sprite:getWidth()

    love.graphics.draw(
        player_ship.sprite,
        0,
        0,
        0,
        sprite_scale,
        sprite_scale,
        player_ship.sprite:getWidth() / 2,
        player_ship.sprite:getHeight() / 2
    )

    love.graphics.pop()

    local text = tostring(enemy.size)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    local text_height = font:getHeight()
    local text_x = enemy.x - text_width / 2
    local text_y = enemy.y - text_height / 2

    local water_color = state.actions.get_current_water_color()
    local inverted_r = 1 - water_color[1]
    local inverted_g = 1 - water_color[2]
    local inverted_b = 1 - water_color[3]

    love.graphics.setColor(inverted_r, inverted_g, inverted_b, 0.8)
    love.graphics.rectangle("fill", text_x - 2, text_y - 1, text_width + 4, text_height + 2)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, text_x, text_y)
end

local function draw_combat_result_text(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local combat_state = state.combat.state.combat
    local player_ship = state.player
    local size = state.system.size
    local camera = state.camera

    if gamestate.get() ~= GameType.COMBAT or not combat_state.result then
        return
    end

    love.graphics.setColor(1, 1, 1, 1)
    local result_text

    if combat_state.result.victory then
        if combat_state.result.farming_penalty then
            result_text = {
                "Overwhelming Victory!",
                "Your crew got careless...",
                string.format("Lost %d men to friendly fire!", combat_state.result.casualties)
            }
        else
            result_text = {
                "Victory!",
                string.format("Lost: %d crew", combat_state.result.casualties),
                string.format("Enemy Fainted: %d crew", combat_state.result.fainted)
            }
        end
    elseif combat_state.defeat_flash.timer < combat_state.defeat_flash.text_display_time then
        result_text = {
            "Defeat!",
            string.format("Lost all %d crew member(s)!", player_ship.men)
        }
    end

    if not result_text then
        return
    end

    local font = love.graphics.getFont()
    local scale = 2.0

    local screen_center_x = size.CANVAS_WIDTH / 2
    local screen_center_y = size.CANVAS_HEIGHT / 2

    local world_x = screen_center_x / camera.scale + camera.x
    local world_y = screen_center_y / camera.scale + camera.y

    local max_width = 0
    local total_height = 0
    for _, line in ipairs(result_text) do
        local width = font:getWidth(line)
        max_width = math.max(max_width, width)
        total_height = (total_height + font:getHeight()) * 2
    end

    local padding = 20 / scale

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.push()
    love.graphics.scale(scale, scale)
    love.graphics.rectangle(
        "fill",
        (world_x - (max_width * scale / 2)) / scale - padding,
        (world_y - (total_height * scale / 2)) / scale - padding,
        max_width + padding * 2,
        total_height + padding * 2,
        10 / scale
    )
    love.graphics.pop()

    love.graphics.push()
    love.graphics.scale(scale, scale)

    local y_pos = (world_y - (total_height * scale / 2)) / scale

    for i, line in ipairs(result_text) do
        local width = font:getWidth(line)
        local x_pos = (world_x - (width * scale / 2)) / scale

        if i == 1 then
            love.graphics.push()
            love.graphics.scale(1.5, 1.5)
            x_pos = (world_x - (width * scale * 1.5 / 2)) / (scale * 1.5)
            y_pos = (world_y - (total_height * scale / 2)) / (scale * 1.5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(line, x_pos, y_pos)
            love.graphics.pop()
            y_pos = y_pos * 1.5 + font:getHeight() * 2
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(line, x_pos, y_pos)
            y_pos = y_pos + font:getHeight()
        end
    end

    love.graphics.pop()
end

local function draw_catch_texts(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    if gamestate.get() ~= GameType.VOYAGE then
        return
    end

    local catch_texts = state.fishing.runtime.get_catch_texts()
    local fishing_cooldown = state.fishing.config.fishing_cooldown
    local player_ship = state.player

    for _, catch in ipairs(catch_texts) do
        local alpha = catch.time / fishing_cooldown
        local font = love.graphics.getFont()
        local text_width = font:getWidth(catch.text)
        local text_height = font:getHeight()
        local text_x = player_ship.x - 40
        local text_y = player_ship.y - 60 - catch.y_offset

        local water_color = state.actions.get_current_water_color()
        local inverted_r = 1 - water_color[1]
        local inverted_g = 1 - water_color[2]
        local inverted_b = 1 - water_color[3]
        love.graphics.setColor(inverted_r, inverted_g, inverted_b, alpha * 0.8)
        love.graphics.rectangle("fill", text_x - 2, text_y - 1, text_width + 4, text_height + 2)

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(catch.text, text_x, text_y)
    end
end

local function draw_fishing_and_danger_hud(state)
    local fishing_runtime = state.fishing.runtime
    local fishing_cooldown = fishing_runtime.get_fishing_cooldown()
    local last_cooldown = fishing_runtime.get_last_cooldown()
    local player_ship = state.player

    if fishing_cooldown > 0 then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(string.format("Fishing: %.1fs", fishing_cooldown), player_ship.x - 30, player_ship.y - 40)
    elseif fishing_cooldown == 0 and last_cooldown > 0 then
        love.graphics.setColor(1, 1, 0.5, 0.8)
        love.graphics.print("Crew Fishing!", player_ship.x - 30, player_ship.y - 40)
    end

    local spawn_status = state.enemy.module.get_spawn_status(player_ship.y)
    if spawn_status.is_dangerous then
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.print("DANGEROUS AREA - No Port-a-Shop!", player_ship.x - 80, player_ship.y - 80)
        love.graphics.setColor(1, 0.5, 0.5, 0.8)
        love.graphics.print(
            string.format("Enemies: %d/%d (Spawn: %.1fs)", spawn_status.enemy_count, spawn_status.max_enemies, spawn_status.spawn_interval),
            player_ship.x - 60,
            player_ship.y - 60
        )
        love.graphics.setColor(1, 0.7, 0.7, 0.9)
        love.graphics.print("ENEMY SPEED: 7x MULTIPLIER!", player_ship.x - 70, player_ship.y - 100)
    end

    fishing_runtime.set_last_cooldown(fishing_cooldown)
end

function draw_steps.draw_world(state)
    local player_ship = state.player
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local ship_animation = state.ship_animation

    draw_steps.draw_shore(state)

    if not player_ship.time_system.is_sleeping then
        state.shop.keeper:draw()

        local ambient_light = state.actions.get_ambient_light()
        local glow_intensity = math.max(0, 1 - ambient_light)

        if gamestate.get() ~= GameType.COMBAT then
            if glow_intensity > 0 then
                local enemies = state.enemy.module.get_enemies()
                for _, enemy in ipairs(enemies) do
                    state.actions.draw_ship_glow(enemy.x, enemy.y, enemy.radius, {1, 0.5, 0.5}, glow_intensity)
                end
            end
            state.enemy.module.draw()
        else
            draw_enemy_in_combat(state, glow_intensity)
        end

        if glow_intensity > 0 then
            state.actions.draw_ship_glow(player_ship.x, player_ship.y, player_ship.radius, {0.5, 0.8, 1}, glow_intensity)
        end

        local ship_speed = math.sqrt(player_ship.velocity_x^2 + player_ship.velocity_y^2)
        if ship_speed > 10 then
            local wake_direction = math.atan2(-player_ship.velocity_y, -player_ship.velocity_x)
            love.graphics.setColor(1, 1, 1, 0.2 * (glow_intensity * 0.5 + 0.5))
            for i = 1, 3 do
                local offset = i * 15
                local wake_x = player_ship.x + math.cos(wake_direction) * offset
                local wake_y = player_ship.y + math.sin(wake_direction) * offset
                local wake_width = (4 - i) * 2
                love.graphics.circle("fill", wake_x, wake_y, wake_width)
            end
        end

        love.graphics.push()
        love.graphics.translate(player_ship.x, player_ship.y)
        love.graphics.rotate(player_ship.rotation + math.pi)
        love.graphics.scale(ship_animation.scale, ship_animation.scale)

        love.graphics.setColor(player_ship.color)
        local target_width = 64
        local sprite_scale = target_width / player_ship.sprite:getWidth()

        love.graphics.draw(
            player_ship.sprite,
            0,
            0,
            0,
            sprite_scale,
            sprite_scale,
            player_ship.sprite:getWidth() / 2,
            player_ship.sprite:getHeight() / 2
        )

        if state.fishing.event.caught_gold_sturgeon then
            love.graphics.setColor(1, 0.8, 0, 0.5)
            love.graphics.draw(
                player_ship.sprite,
                0,
                10,
                0,
                sprite_scale,
                sprite_scale,
                player_ship.sprite:getWidth() / 2,
                player_ship.sprite:getHeight() / 2
            )
        end

        love.graphics.push()
        love.graphics.scale(1 / ship_animation.scale, 1 / ship_animation.scale)
        love.graphics.rotate(-player_ship.rotation)
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(player_ship.name)
        love.graphics.print(player_ship.name, -text_width / 2, player_ship.radius * 1.5 * ship_animation.scale)
        love.graphics.pop()

        love.graphics.pop()

        draw_combat_result_text(state)
        draw_catch_texts(state)
        draw_fishing_and_danger_hud(state)

        state.shop.module.draw_shops(state.camera)
    end

    love.graphics.pop()
end

function draw_steps.draw_post_world_overlays(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local size = state.system.size
    local time_system = state.player.time_system

    if gamestate.get():find("shop", 1, true) then
        state.shop.module.draw_ui(gamestate)
    end

    if time_system.is_fading or time_system.fade_alpha > 0 then
        love.graphics.setColor(0, 0, 0, time_system.fade_alpha)
        love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)

        if time_system.is_sleeping and time_system.fade_alpha > 0.9 then
            love.graphics.setColor(1, 1, 1, 1)
            local sleep_text = "Sleeping..."
            local font = love.graphics.getFont()
            local text_width = font:getWidth(sleep_text)
            love.graphics.print(sleep_text, (size.CANVAS_WIDTH - text_width) / 2, size.CANVAS_HEIGHT / 2)
        end
    end

    if gamestate.get() == GameType.FISHING then
        state.fishing.minigame.draw()
    end

    crew_management.draw_overlay(state)
    state.ui.morningtext.draw()
end

function draw_steps.draw_time_and_debug(state)
    local player_ship = state.player
    local debugOptions = state.ui.debug
    local suit = state.ui.suit
    local mobile_controls = state.ui.mobile
    local fishing = state.fishing.module
    local gamestate = state.system.gamestate
    local game_config = state.fishing.config

    love.graphics.setColor(1, 1, 1, 1)
    local time_of_day = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12
    local hours = math.floor(time_of_day)
    local minutes = math.floor((time_of_day - hours) * 60)
    local fishing_level = state.constants.fishing_level
    if hours >= 12 then
        hours = 12
        minutes = 0
    end
    love.graphics.print(string.format("Time: %02d:%02d", hours, minutes), 10, 10)
    love.graphics.print(string.format("Fishing Level: %d", player_ship.y / fishing_level), 10, 30)
    hunger.draw_hud(state)
    state.ui.alert.draw(state.system.size)

    if debugOptions.showDebugButtons and not player_ship.time_system.is_sleeping then
        suit.layout:reset(10, 40)
        suit.layout:padding(10)

        if suit.Button("Add 100 Fish", suit.layout:row(100, 30)).hit then
            for _ = 1, 100 do
                local fish_available = fishing.get_fish_avalible(player_ship.x, player_ship.y, player_ship.time_system.time)
                local fish_caught = fishing.fish(
                    fishing.get_rod_rarity(player_ship.rod),
                    fishing.get_rod_top_rarity(),
                    fish_available,
                    player_ship.y
                )
                table.insert(player_ship.caught_fish, fish_caught)
            end
            print("Added 100 fish!")
        end

        if suit.Button("Add Every Fish", suit.layout:row(100, 30)).hit then
            local all_fish = fishing.get_all_fish()
            for _, fish_name in ipairs(all_fish) do
                table.insert(player_ship.caught_fish, fish_name)
            end
            print("Added one of every fish type (" .. #all_fish .. " fish)!")
        end

        if suit.Button("Skip 1 Min", suit.layout:row(100, 30)).hit then
            local max_debug_time = player_ship.time_system.DAY_LENGTH - 1
            local new_time = math.min(player_ship.time_system.time + 60, max_debug_time)
            player_ship.time_system.time = new_time
            print("skipped to " .. new_time)
        end

        if suit.Button("Toggle Cooldown (5s/2s)", suit.layout:row(150, 30)).hit then
            game_config.fishing_cooldown = game_config.fishing_cooldown == 5 and 2 or 5
            print("Fishing cooldown set to: " .. game_config.fishing_cooldown .. "s")
        end

        if suit.Button("Display Position", suit.layout:row(100, 30)).hit then
            print("Player Position: " .. player_ship.x .. ", " .. player_ship.y)
        end

        if suit.Button("Gold Sturgeon Time", suit.layout:row(150, 30)).hit then
            player_ship.time_system.time = (11.5 / 12) * player_ship.time_system.DAY_LENGTH
            state.actions.get_current_water_color()
            state.actions.trigger_special_fish_event("Gold Sturgeon")
            print("Time set to 11:30 and Gold Sturgeon event triggered!")
        end

        if suit.Button("Rainbows 0.1", suit.layout:row(150, 30)).hit then
            local start_value = state.constants.corruption.start_value
            player_ship.rainbows = math.max(tonumber(player_ship.rainbows) or 0, start_value)
            state.system.serialize.save_data(state.system.game.get_saveable_data())
            print(string.format("Rainbows set to %.1f", player_ship.rainbows))
            state.actions.force_corruption_sleep_if_needed()
        end

        love.graphics.print("Debug Mode (F3 to toggle)", 10, 100)

        if suit.Button("Toggle Mobile Controls", suit.layout:row(150, 30)).hit then
            mobile_controls.enabled = not mobile_controls.enabled
            print("Mobile controls: " .. (mobile_controls.enabled and "ON" or "OFF"))
        end

        if suit.Button("Print Shore Positions", suit.layout:row(150, 30)).hit then
            print("--- Shore Debug Info ---")
            print(string.format("Player Position: x=%.2f, y=%.2f", player_ship.x, player_ship.y))
            print("Shore Object Positions:")
            for i, obj in ipairs(state.shore.objects) do
                print(string.format("  [%d]: x=%.2f, y=%.2f", i, obj.x, obj.y))
            end
            print("------------------------")
        end
    end
end

function draw_steps.draw_final_ui(state)
    local combat_state = state.combat.state.combat
    if combat_state.defeat_flash and combat_state.defeat_flash.active then
        love.graphics.setColor(1, 1, 1, combat_state.defeat_flash.alpha)
        love.graphics.rectangle("fill", 0, 0, state.system.size.CANVAS_WIDTH, state.system.size.CANVAS_HEIGHT)
    end

    if state.ui.mobile.enabled then
        state.actions.draw_mobile_controls()
    end

    love.graphics.setColor(1, 1, 1, 1)
    state.ui.suit.draw()
end

function draw_steps.draw_special_event_overlay(state)
    local special_fish_event = state.fishing.event
    if not special_fish_event.active then
        return
    end

    local size = state.system.size
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)

    love.graphics.setColor(1, 1, 1, 1)
    local message = "You feel a tug unlike anything before..."
    local font = love.graphics.getFont()
    local text_width = font:getWidth(message)
    local scale = 2.0

    love.graphics.push()
    love.graphics.scale(scale, scale)
    love.graphics.print(message, (size.CANVAS_WIDTH / scale - text_width) / 2, size.CANVAS_HEIGHT / scale / 2 - 20)
    love.graphics.pop()

    if special_fish_event.timer > special_fish_event.duration / 2 and special_fish_event.fish_name == "Gold Sturgeon" then
        for i = 1, 3 do
            local radius = 100 - i * 20
            love.graphics.setColor(1, 0.8, 0, 0.1)
            love.graphics.circle("fill", size.CANVAS_WIDTH / 2, size.CANVAS_HEIGHT / 2 + 30, radius)
        end
    end
end

return draw_steps
