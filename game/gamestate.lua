local gamestate = {}
local GameType = require("game.gametypes")

local current_state = GameType.MENU

function gamestate.get()
    return current_state
end

function gamestate.set(new_state)
    if current_state ~= new_state then
        print("GameState changed from '" .. current_state .. "' to '" .. new_state .. "'")
        current_state = new_state
    end
end

return gamestate
