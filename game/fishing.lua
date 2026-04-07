local constants = require("game.constants")
local size = require("game.size")

local fishing = require("game.fishing.core").create({
    constants = constants
})

fishing.minigame = require("game.fishing.minigame").create({
    fishing = fishing,
    size = size,
    constants = constants
})

local runtime = require("game.fishing.runtime")

function fishing.create_runtime(deps)
    local runtime_deps = deps or {}
    runtime_deps.fishing = runtime_deps.fishing or fishing
    return runtime.create(runtime_deps)
end

return fishing
