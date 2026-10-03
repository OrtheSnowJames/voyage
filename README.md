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

* Hold bonus: enter the catch circle, reach center within 2 seconds, then stay centered for `+60` quality score.

### Crew & Combat

* More crew than the enemy = victory
* Fewer crew = defeat (and save loss)
* Winning gives you **fainted enemy crew** you can recover
* If you lose every **loyal** crew member (the ones you hired, including Jonas) while enemy crew are still aboard, the enemy crew rebel and kill you. Your run ends and resets to the menu.
* Stronger swords reduce your losses
* Rare flock spawns (1 in 20) can fill remaining enemy slots with a tight enemy cluster.

Bringing way more crew than the enemy causes **carelessness**, leading to heavy losses (most of your crew).

### Crew Hunger

* Crew hunger decays over time while sailing/fishing/shop states are active.
* If a crew member's hunger reaches `0`, that crew member dies.
* If all crew die from hunger, your run resets to menu (not tested yet!).
* You can feed crew from caught fish (manual `Feed` / `Feed All` controls).
* **Night fish** and **Gold Sturgeon** cannot be used as crew food (sadly).

### Selling Crew Members

* You can sell crew members to get couns back.
* If a crew member is sold, the shop will revert the price to before the crew member was bought.
* You can only sell crew members bought from the shop.
* Enemy crew cannot be sold.

### Jonas's Journal

* You start with one crew member, **Jonas**. He is very loyal: he can never be sold, and he is the one who writes the journal.
* Each day, Jonas records a synopsis of the day's events.
* Open it from the crew tab with the **Jonas's Journal** button (the Crew button becomes **Close**; `Esc`, `Enter` and `Space` also close it).
* Use the left and right arrows to browse days. Going past the last day wraps to the first, and vice versa.
* When you wake up, the journal opens on the day that just ended, and then the new day starts ("Day 2", and so on).
* Each page lists:
  * Milestones: leaving shore for the first time, new sections of water, rod and sword upgrades, Sturgeon, Gold Sturgeon, and shipwrecks
  * A short note from Jonas about how the day went, for example after a shipwreck: *"We lost five men today. I don't know how the captain managed to get us to shore, but somehow we made it."*
  * Stats: fish discovered, fish caught, coins gained and lost, crew gained and lost, enemies defeated, and steps walked (pixels / 10)

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

### Storms

Storms have about a 1/10 chance of happening, but the chance gets higher the further out you are 
(similar to real life).

* Spawn at night around 9 o' clock
* Lightning can strike your boat
* If lightning strikes your boat, you have to swim to shore so you don't drown. Most of your stuff will be lost at sea.
* Staying on an island is your best bet.

### Mods

* Built-in mod loader (terminal) with enable/disable and a lua repl because why not
* Mods are loaded from `mods/` and can hook into runtime systems

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

Thanks to [Foolze](https://foozlecc.itch.io/) on itch.io for [sprites](https://foozlecc.itch.io/scallywag-pirates)
