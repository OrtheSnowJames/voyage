local crew_management = {}
local hunger = require("game.hunger")
local shop = require("shop")
local alert = require("game.alert")

local panel_open = false

local TOGGLE_WIDTH = 95
local TOGGLE_HEIGHT = 30
local ACTION_WIDTH = 220
local ACTION_HEIGHT = 36
local ACTION_GAP = 120
local ACTION_ROW_Y = 320
local ACTION_STACK_GAP = 12

local function get_layout(size)
    local center_x = math.floor(size.CANVAS_WIDTH / 2)
    local left_x = math.floor(center_x - ACTION_GAP - ACTION_WIDTH)
    local right_x = math.floor(center_x + ACTION_GAP)

    return {
        toggle = {
            x = 12,
            y = size.CANVAS_HEIGHT - TOGGLE_HEIGHT - 12,
            width = TOGGLE_WIDTH,
            height = TOGGLE_HEIGHT
        },
        title = {
            x = center_x,
            y = 140
        },
        feed = {
            x = left_x,
            y = ACTION_ROW_Y,
            width = ACTION_WIDTH,
            height = ACTION_HEIGHT
        },
        feed_all = {
            x = left_x,
            y = ACTION_ROW_Y + ACTION_HEIGHT + ACTION_STACK_GAP,
            width = ACTION_WIDTH,
            height = ACTION_HEIGHT
        },
        right_slot = {
            x = right_x,
            y = ACTION_ROW_Y,
            width = ACTION_WIDTH,
            height = ACTION_HEIGHT
        }
    }
end

function crew_management.handle_buttons(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    if gamestate.get() ~= GameType.VOYAGE then
        panel_open = false
        return
    end

    local suit = state.ui.suit
    local layout = get_layout(state.system.size)

    local toggle_label = panel_open and "Close Crew" or "Crew"
    if suit.Button(toggle_label, {id = "crew_panel_toggle"}, layout.toggle.x, layout.toggle.y, layout.toggle.width, layout.toggle.height).hit then
        panel_open = not panel_open
    end

    if not panel_open then
        return
    end

    hunger.handle_feed_button(state, {
        x = layout.feed.x,
        y = layout.feed.y,
        width = layout.feed.width,
        height = layout.feed.height,
        id = "feed_crew_centered"
    })
    hunger.handle_feed_all_button(state, {
        x = layout.feed_all.x,
        y = layout.feed_all.y,
        width = layout.feed_all.width,
        height = layout.feed_all.height,
        id = "feed_all_crew_centered"
    })

    local sell_price = shop.get_crew_hire_cost(math.max(1, state.player.men - 1))
    local sell_label
    if state.player.men > 1 then
        sell_label = string.format("Sell (+%d)", sell_price)
    else
        sell_label = "Need 2+ Crew"
    end

    if suit.Button(sell_label, {id = "crew_right_placeholder"}, layout.right_slot.x, layout.right_slot.y, layout.right_slot.width, layout.right_slot.height).hit then
        if state.player.men > 1 and state.player.loyal_men > 1 then -- loyal men are bought from shop and can be sold
            shop.add_coins(sell_price)
            state.player.men = state.player.men - 1
            state.player.loyal_men = state.player.loyal_men - 1
            alert.show("Sold successfully", 1.6, {1, 1, 1, 1})
        else
            alert.show("Not enough crew", 1.6, {1, 0.3, 0.3, 1})
        end
    end
end

function crew_management.draw_overlay(state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    if gamestate.get() ~= GameType.VOYAGE then
        return
    end

    if not panel_open then
        return
    end

    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, state.system.size.CANVAS_WIDTH, state.system.size.CANVAS_HEIGHT)

    local layout = get_layout(state.system.size)
    local font = love.graphics.getFont()

    love.graphics.setColor(1, 1, 1, 1)
    local title = "Crew Management"
    love.graphics.print(title, layout.title.x - (font:getWidth(title) / 2), layout.title.y)

    local feed_label = "Feed Crew"
    love.graphics.print(
        feed_label,
        layout.feed.x + (layout.feed.width - font:getWidth(feed_label)) / 2,
        layout.feed.y - 26
    )
    local feed_all_label = "Feed Everyone"
    love.graphics.print(
        feed_all_label,
        layout.feed_all.x + (layout.feed_all.width - font:getWidth(feed_all_label)) / 2,
        layout.feed_all.y - 26
    )

    local right_label = "Sell Crew Member"
    love.graphics.print(
        right_label,
        layout.right_slot.x + (layout.right_slot.width - font:getWidth(right_label)) / 2,
        layout.right_slot.y - 26
    )

end

return crew_management
