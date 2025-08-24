local textToPrint  = 'love2d studio\nCode and debug Love2D games \nAll on your mobile device'
local printedText  = ""
local bg = require('background')
local interval = 0.2
local typeTimer = interval
local typePosition = 0
local waitCycles = 20
local lg = love.graphics
local screenWidth, screenHeight = love.window.getMode()

function love.load()
  local fontSize = 32
  if screenHeight < 500 or screenWidth < 500 then
     fontSize = 16
  end
  local textFont = lg.newFont(fontSize)
  lg.setFont(textFont)
end

function love.update(dt)
    typeTimer = typeTimer - dt
    if typeTimer <= 0 then
        typeTimer = interval
        typePosition = typePosition + 1
      if typePosition >#textToPrint + waitCycles then
          typePosition = 0
      end

        printedText = string.sub(textToPrint,0,typePosition)
    end
end


function love.draw()
  bg.draw()
  local left =40
  local top = 200
  if screenWidth < 500 or screenHeight < 500 then
     left = 20
  end
  lg.print(printedText, left, top)
end

function love.resize(w, h)
   print("love.resize")
   lg.clear()

   lg.present()
end


