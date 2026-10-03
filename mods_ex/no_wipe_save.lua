return {
    on_load = function (state, _)
        state.system.actions.reset_game = function()
            print("preventing reset...")
        end
    end
}
