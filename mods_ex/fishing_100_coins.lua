local BONUS_COINS = 100

return {
    on_load = function(state, api)
        local system = state and state.system or nil
        local fishing_state = (system and system.fishing_state) or (state and state.fishing) or nil
        local shop_state = (system and system.shop_state) or (state and state.shop) or nil
        local ui_state = (system and system.ui) or (state and state.ui) or nil
        local runtime = fishing_state and fishing_state.runtime
        local shop = shop_state and shop_state.module
        local alert = ui_state and ui_state.alert

        if type(runtime) ~= "table" or type(runtime.record_catch) ~= "function" then
            if api and api.log then
                api.log("fishing_100_coins: fishing runtime missing")
            end
            return
        end

        if type(shop) ~= "table" or type(shop.add_coins) ~= "function" then
            if api and api.log then
                api.log("fishing_100_coins: shop.add_coins missing")
            end
            return
        end

        if runtime.__fishing_100_coins_installed then
            return
        end

        local original_record_catch = runtime.record_catch
        runtime.record_catch = function(fisher_name, fish_caught)
            local stored_in_inventory = original_record_catch(fisher_name, fish_caught)
            if fisher_name == "You" and stored_in_inventory then
                shop.add_coins(BONUS_COINS)
                if alert and type(alert.show) == "function" and type(shop.get_coins) == "function" then
                    local balance = tonumber(shop.get_coins()) or 0
                    alert.show(
                        string.format("%d coins received. Balance: %.1f", BONUS_COINS, balance),
                        1.8,
                        {1, 1, 1, 1}
                    )
                end
                if api and api.log then
                    api.log("fishing_100_coins: +" .. BONUS_COINS .. " coins")
                end
            end
            return stored_in_inventory
        end

        runtime.__fishing_100_coins_installed = true
        if api and api.log then
            api.log("fishing_100_coins: enabled")
        end
    end
}
