return {
    on_load = function (state, api)
        local system = state and state.system or nil
        if system == nil then
            print("no system!")
            return
        end
        local spawnenemy = system.spawnenemy

        local checker = function(_)
            return false
        end

        if spawnenemy.set_dangerous_area_checker then
            spawnenemy.set_dangerous_area_checker(checker)
        else
            spawnenemy.is_dangerous_area = checker
        end
    end
}
