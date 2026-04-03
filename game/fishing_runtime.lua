local fishing = require("game.fishing")

local fishing_runtime = {}

function fishing_runtime.create(deps)
    return fishing.create_runtime(deps)
end

return fishing_runtime
