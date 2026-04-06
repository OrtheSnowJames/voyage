# Voyage

Voyage is a sailing and grinding game about managing a crew, taking risks, and pushing into deep waters.

## Gameplay Loop

* **Fish** to earn coins
* **Upgrade** your ship, rod, and sword
* **Fight ships** to gain crew (and risk losing your own)
* **Expand** into deeper, more dangerous waters

## Key Mechanics

### Fishing

Press `F` to fish. Your crew fishes automatically after the cooldown.

### Crew & Combat

* More crew than the enemy = victory
* Fewer crew = defeat (and save loss)
* Winning gives you **fainted enemy crew** you can recover
* Stronger swords reduce your losses

Bringing way more crew than the enemy causes **carelessness**, leading to heavy losses (most of your crew).

### Crew Hunger

* Crew hunger decays over time while sailing/fishing/shop states are active.
* If a crew member's hunger reaches `0`, that crew member dies.
* If all crew die from hunger, your run resets to menu (not tested yet!).
* You can feed crew from caught fish (manual `Feed` / `Feed All` controls).
* **Night fish** and **Gold Sturgeon** cannot be used as crew food (sadly).

### Progression

* Upgrade rods → easier fishing
* Upgrade swords → fewer losses
* Upgrade ship → move faster and explore further
* Unlock ports to survive deeper waters

### Shops

* Sell fish
* Buy upgrades
* Heal crew
* Store valuable fish

## Running the Game

Requires LÖVE2D.

```sh
sudo pacman -S love
git clone --recursive https://github.com/OrtheSnowJames/voyage.git
cd voyage
love .
```

Web:
```sh
sudo pacman -S love
npm -g i love.js
sh build_web.sh
sh host.sh
```
Then just go to localhost:8000

Mobile:
- Download the release to the files app
- Get love2DStudio
- Click the add icon and add the .love file
- Find main.lua
- Clck on it and press the play button (in top right corner)

## Notes

This project is actively evolving and being refined over time.
I just got motivation to start working on this after 7 months somehow :)

Getting love.js working was complicated to say the least.

## Thanks

Thanks to [LÖVE](love2d.org) for making this actually possible

Thanks to [love.js](https://github.com/Davidobot/love.js) for making web support possible
