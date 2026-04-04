# Voyage

Voyage is a sailing and grinding game about managing a crew, taking risks, and pushing into very deep waters.

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

## Notes

This project is actively evolving and being refined over time.
I just got motivation to start working on this after 7 months somehow :)
