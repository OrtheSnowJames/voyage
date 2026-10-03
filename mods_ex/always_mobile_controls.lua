local function enable(state)
    local mobile = state and state.system and state.system.ui and state.system.ui.mobile
    if mobile then
        mobile.enabled = true
    end
end

return {
    on_load = function (state, _)
        enable(state)
    end,
    on_update = function (_, state)
        enable(state)
    end
}
