-- a speaker's lines in a box at the bottom of the screen, typed out one at a time.
-- The game stands still while it is up; F / Enter / Space or the Next button moves on.
local dialogue = {}

local size = require("game.size")
local shopkeeper_dialogue = require("game.shopkeeper_dialogue")

local TYPEWRITER_CHARS_PER_SECOND = 30
local TEXT_SCALE = 1.6
local PANEL_HEIGHT = 110
local PANEL_MARGIN = 20

local run = nil

-- the box itself, shared with the ending
function dialogue.draw_panel(speaker, text)
    local panel_x = PANEL_MARGIN
    local panel_y = size.CANVAS_HEIGHT - PANEL_HEIGHT - PANEL_MARGIN
    local panel_w = size.CANVAS_WIDTH - PANEL_MARGIN * 2

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", panel_x, panel_y, panel_w, PANEL_HEIGHT)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("line", panel_x, panel_y, panel_w, PANEL_HEIGHT)

    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.print(speaker, panel_x + 16, panel_y + 10, 0, TEXT_SCALE, TEXT_SCALE)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, panel_x + 16, panel_y + 44, 0, TEXT_SCALE, TEXT_SCALE)

    return panel_x, panel_y, panel_w, PANEL_HEIGHT
end

function dialogue.start(speaker, lines)
    if not lines or #lines == 0 then
        return
    end
    run = {speaker = speaker, lines = lines, line = 1, reveal = 0}
end

-- what shopkeeper number `index` says on the way out (see shopkeeper_dialogue.lua for the numbering)
function dialogue.start_shopkeeper(index)
    local script = shopkeeper_dialogue[index] or shopkeeper_dialogue[1]
    dialogue.start(script.name, script.lines)
end

function dialogue.reset()
    run = nil
end

function dialogue.is_active()
    return run ~= nil
end

local function line_is_fully_shown()
    return math.floor(run.reveal) >= #run.lines[run.line]
end

-- skip the typing, then go to the next line, then close
function dialogue.advance()
    if not run then
        return
    end
    if not line_is_fully_shown() then
        run.reveal = #run.lines[run.line]
    elseif run.line < #run.lines then
        run.line = run.line + 1
        run.reveal = 0
    else
        run = nil
    end
end

function dialogue.keypressed(key)
    if not run then
        return false
    end
    if key == "f" or key == "return" or key == "space" then
        dialogue.advance()
    end
    return true -- every key is swallowed while someone is talking
end

function dialogue.update(dt)
    if run and not line_is_fully_shown() then
        run.reveal = run.reveal + dt * TYPEWRITER_CHARS_PER_SECOND
    end
end

function dialogue.draw(state)
    if not run then
        return
    end

    local shown = run.lines[run.line]:sub(1, math.floor(run.reveal))
    local panel_x, panel_y, panel_w, panel_h = dialogue.draw_panel(run.speaker, shown)

    local label = run.line < #run.lines and "Next" or "Close"
    if state.system.ui.suit.Button(label, {id = "dialogue_next"}, panel_x + panel_w - 110, panel_y + panel_h - 46, 96, 34).hit then
        dialogue.advance()
    end
end

return dialogue
