local BONUS_COINS = 100

return {
    on_load = function(state, api)
        local runtime = state and state.fishing and state.fishing.runtime
        local shop = state and state.shop and state.shop.module
        local alert = state and state.ui and state.ui.alert

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
