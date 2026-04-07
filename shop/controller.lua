local shop_state = require("shop.state")
local main_ui = require("shop.ui.main")
local transfer_ui = require("shop.ui.transfer")
local inventory_ui = require("shop.ui.inventory")
local top_bar = require("game.top")

local controller = {}

local PORT_EXPORTS = {
    "get_main_dock_position",
    "try_disembark_main_dock",
    "can_disembark_main_dock",
    "try_board_main_dock",
    "can_board_main_dock",
    "request_main_shop_interaction",
    "can_talk_to_main_shopkeeper",
    "can_disembark_port_shop",
    "try_disembark_port_shop",
    "can_talk_to_port_shopkeeper",
    "request_port_shop_interaction",
    "has_shop_collision_at_y",
    "draw_main_dock",
    "resolve_boat_collisions",
    "resolve_enemy_collisions",
    "draw_shops"
}

function controller.create(deps)
    local suit = deps.suit
    local fishing = deps.fishing
    local economy = deps.economy
    local port = deps.port
    local size = deps.size
    local scrolling = deps.scrolling
    local GameType = deps.GameType
    local inventory_utils = deps.inventory_utils
    local combat = deps.combat

    local runtime_state = shop_state.create(scrolling)
    local shop = {}

    for _, method_name in ipairs(PORT_EXPORTS) do
        shop[method_name] = port[method_name]
    end

    function shop.get_coins()
        return runtime_state.coins
    end

    function shop.try_spend_coins(amount)
        local cost = math.floor(tonumber(amount) or 0)
        if cost <= 0 then
            return true
        end

        if runtime_state.coins < cost then
            return false
        end

        runtime_state.coins = runtime_state.coins - cost
        return true
    end

    function shop.add_coins(amount)
        local gain = math.floor(tonumber(amount) or 0)
        if gain <= 0 then
            return 0
        end

        runtime_state.coins = runtime_state.coins + gain
        return gain
    end

    function shop.get_crew_hire_cost(current_crew)
        return economy.get_crew_hire_cost(current_crew)
    end

    function shop.get_current_crew_hire_cost(player_ship)
        local crew_count = player_ship and player_ship.men or 1
        return economy.get_crew_hire_cost(crew_count)
    end

    function shop.update(gamestate, player_ship, shopkeeper, game_config)
        local dt = love.timer.getDelta()
        port.update_spawn_and_animation(player_ship, dt)

        local shop_active, port_shop_active, main_shop_active = port.check_shop_interaction(player_ship, shopkeeper)
        if not shop_active then
            runtime_state.shop_reopen_requires_exit = false
        end
        if not (main_shop_active or port_shop_active) then
            player_ship.pending_shop_interaction = false
        end

        if gamestate.get() == GameType.VOYAGE then
            if player_ship.pending_shop_interaction and (main_shop_active or port_shop_active) then
                gamestate.set(GameType.SHOP)
                player_ship.pending_shop_interaction = false
            end
        elseif not shop_active and gamestate.get():find(GameType.SHOP, 1, true) then
            player_ship.pending_shop_interaction = false
            gamestate.set(GameType.VOYAGE)
        end

        if not gamestate.get():find(GameType.SHOP, 1, true) then
            scrolling.stop_drag(runtime_state.main_shop_scroll)
            return
        end

        if runtime_state.message_timer > 0 then
            runtime_state.message_timer = runtime_state.message_timer - dt
            if runtime_state.message_timer <= 0 then
                runtime_state.show_no_fish_message = false
            end
        end

        local window_width = size.CANVAS_WIDTH
        local window_height = size.CANVAS_HEIGHT
        local top_offset = top_bar.get_height(window_height)

        if suit.Button("Leave Shop", {id = "leave_shop"}, window_width - 132, top_offset + 10, 122, 30).hit then
            gamestate.set(GameType.VOYAGE)
            runtime_state.shop_reopen_requires_exit = true
            player_ship.pending_shop_interaction = false
            scrolling.stop_drag(runtime_state.main_shop_scroll)
            return
        end

        if gamestate.get() ~= GameType.SHOP then
            scrolling.stop_drag(runtime_state.main_shop_scroll)
        end

        local ui_ctx = {
            suit = suit,
            size = size,
            scrolling = scrolling,
            fishing = fishing,
            combat = combat,
            economy = economy,
            port = port,
            inventory_utils = inventory_utils,
            runtime_state = runtime_state,
            player_ship = player_ship,
            gamestate = gamestate,
            GameType = GameType,
            game_config = game_config
        }
        ui_ctx.top_offset = top_offset

        if gamestate.get() == GameType.SHOP_TRANSFER then
            transfer_ui.render(ui_ctx)
            return
        end

        if gamestate.get() == GameType.SHOP_VIEW_INVENTORY then
            inventory_ui.render(ui_ctx)
            return
        end

        ui_ctx.open_transfer = function()
            gamestate.set(GameType.SHOP_TRANSFER)
            transfer_ui.enter(runtime_state, player_ship)
        end

        ui_ctx.open_inventory = function()
            gamestate.set(GameType.SHOP_VIEW_INVENTORY)
            inventory_ui.enter(runtime_state)
        end

        main_ui.render(ui_ctx)
    end

    function shop.draw_ui(gamestate)
        if gamestate.get():find(GameType.SHOP, 1, true) then
            local alpha = gamestate.get() ~= GameType.SHOP and 0.9 or 0.85
            love.graphics.setColor(0, 0, 0, alpha)
            love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)
            love.graphics.setColor(1, 1, 1, 1)

            if gamestate.get() == GameType.SHOP then
                scrolling.begin_clip(runtime_state.main_shop_scroll)
                suit.draw()
                scrolling.end_clip()
                scrolling.draw(runtime_state.main_shop_scroll)
            else
                suit.draw()
            end
        end
    end

    function shop.reset()
        shop_state.reset(runtime_state, scrolling)
        port.reset()
    end

    function shop.get_port_a_shops_data()
        return {
            port_a_shops = port.get_port_a_shops_data(),
            coins = runtime_state.coins
        }
    end

    function shop.set_port_a_shops_data(data)
        if data.port_a_shops then
            port.set_port_a_shops_data(data.port_a_shops)
        end
        if data.coins then
            runtime_state.coins = data.coins
        end
    end

    function shop.get_last_port_a_shop_y()
        return port.get_last_port_a_shop_y()
    end

    return shop
end

return controller
