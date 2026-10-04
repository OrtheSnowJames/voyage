-- the ending: docking at the far coast beats the game.
-- Jonas says his piece, then the player picks Complete Voyage (counts the win, starts over) or Keep Exploring.
local ending = {}

local constants = require("game.constants")
local size = require("game.size")
local times_beaten = require("game.times_beaten")
local morningtext = require("game.morningtext")
local days = require("game.days")
local dialogue = require("game.dialogue")

local LINES = {
    "Wow, dude! Can't believe we made it!",
    "I'm gonna go to my house now...",
    "Unless you wanna keep exploring?"
}
local TYPEWRITER_CHARS_PER_SECOND = 30
local FADE_DURATION = 2.5
local BUTTON_WIDTH = 200
local BUTTON_HEIGHT = 40

local run = nil

local function line_length(index)
    return #LINES[index]
end

function ending.reset()
    run = nil
end

function ending.is_active()
    return run ~= nil
end

function ending.is_completing()
    return run ~= nil and run.completing == true
end

-- first dock plays the whole conversation; docking again after Keep Exploring goes straight to the question
function ending.start(player_ship)
    local seen_before = player_ship.reached_end_coast == true
    player_ship.reached_end_coast = true
    if not seen_before then
        days.record_voyage_complete()
    end
    morningtext.reset() -- don't let a leftover morning line show through the dialogue
    run = {
        line = seen_before and #LINES or 1,
        reveal = 0,
        completing = false,
        counted = false,
        fade = 0
    }
end

local function on_last_line()
    return run.line >= #LINES
end

local function line_is_fully_shown()
    return math.floor(run.reveal) >= line_length(run.line)
end

-- skip the typing, or move to the next line; the last line waits for a button
function ending.advance()
    if not run or run.completing then
        return
    end
    if not line_is_fully_shown() then
        run.reveal = line_length(run.line)
    elseif not on_last_line() then
        run.line = run.line + 1
        run.reveal = 0
    end
end

function ending.keypressed(key)
    if not run then
        return false
    end
    if key == "f" or key == "return" or key == "space" then
        ending.advance()
    end
    return true -- the ending swallows every key while it is up
end

local function complete_voyage()
    if run.completing then
        return
    end
    run.completing = true
    run.fade = 0
    if not run.counted then
        run.counted = true
        times_beaten.increment()
    end
end

local function keep_exploring()
    run = nil
end

-- returns nil while the ending is idle or still going, GameType.MENU once the voyage is over
function ending.update(dt, state)
    if not run then
        return nil
    end

    if run.completing then
        run.fade = run.fade + dt
        local time_system = state.system.player.time_system
        time_system.fade_alpha = math.max(0, math.min(1, run.fade / FADE_DURATION))
        if run.fade >= FADE_DURATION then
            run = nil
            time_system.fade_alpha = 0
            state.system.alert.clear()
            state.system.actions.reset_game()
            state.system.gamestate.set(state.system.gametype.MENU)
            return state.system.gametype.MENU
        end
        return nil
    end

    if not line_is_fully_shown() then
        run.reveal = run.reveal + dt * TYPEWRITER_CHARS_PER_SECOND
    end
    return nil
end

function ending.draw(state)
    if not run or run.completing then
        return
    end

    local suit = state.system.ui.suit
    local panel_x, panel_y, panel_w, panel_h = dialogue.draw_panel(
        constants.ship.start_crew_name,
        LINES[run.line]:sub(1, math.floor(run.reveal))
    )

    if on_last_line() and line_is_fully_shown() then
        local gap = 20
        local total = BUTTON_WIDTH * 2 + gap
        local buttons_x = (size.CANVAS_WIDTH - total) / 2
        local buttons_y = panel_y - BUTTON_HEIGHT - 14
        if suit.Button("Complete Voyage", {id = "ending_complete"}, buttons_x, buttons_y, BUTTON_WIDTH, BUTTON_HEIGHT).hit then
            complete_voyage()
        end
        if suit.Button("Keep Exploring", {id = "ending_keep"}, buttons_x + BUTTON_WIDTH + gap, buttons_y, BUTTON_WIDTH, BUTTON_HEIGHT).hit then
            keep_exploring()
        end
    elseif not on_last_line() then
        if suit.Button("Next", {id = "ending_next"}, panel_x + panel_w - 110, panel_y + panel_h - 46, 96, 34).hit then
            ending.advance()
        end
    end
end

return ending
