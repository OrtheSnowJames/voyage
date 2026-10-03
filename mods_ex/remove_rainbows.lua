return {
    on_load = function(state, api)
        local serialize = state.system.modules.serialize
        local current_data = serialize.load_data()
        if current_data then
            if current_data.rainbows then
                current_data.rainbows = 0
                current_data.corruption_started = false
                serialize.save_data(current_data)
            end
        end
        if state and state.system and state.system.player and state.system.player.rainbows then
            state.system.player.rainbows = 0
            state.system.player.corruption_started = false
        else
            if api and api.log then
                api.log("rainbows not found")
            end
        end
    end
}
