local suit = require("SUIT")
local fishing = require("game.fishing")
local combat = require("game.combat")
local size = require("game.size")
local scrolling = require("game.scrolling")
local GameType = require("game.gametypes")
local constants = require("game.constants")
local sand = require("sand")

local port = require("shop.port").create({
    constants = constants,
    size = size,
    sand = sand
})

local economy = require("shop.economy").create({
    constants = constants,
    fishing = fishing,
    combat = combat
})

local shop = require("shop.controller").create({
    suit = suit,
    fishing = fishing,
    combat = combat,
    size = size,
    scrolling = scrolling,
    GameType = GameType,
    economy = economy,
    port = port,
    inventory_utils = require("shop.inventory_utils")
})

return shop
