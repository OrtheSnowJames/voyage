# Voyage

Voyage is a grinding game meant to be played on spare time.

## Gameplay

### Fishing
To fish, press the `f` key. When the cooldown is done, all of your men will fish.

### Crew Management
- **Hiring**: Go to the shop to hire more crew members
- **Combat**: 
  - You need more men than the enemy to win fights
  - If you have fewer men, you'll lose the fight and your save data
  - If you have more men, you'll lose some men but get fainted men
  - Fainted men can be healed by sleeping next to a shop
  - **Warning**: If you bring 10x or more men than the enemy has, your crew will get careless and you'll lose 90% of them to friendly fire!

### Shop System
The shop allows you to:
- Sell your caught fish
- Buy upgrades and items
- Heal fainted crew members
- *(Planned)* Store prized fish in an inventory system

## Getting Started

### Prerequisites
You need LÖVE (a Lua game engine) to run the game.

On Arch-based systems:
```sh
sudo pacman -S love
```

### Installation
1. Clone the repository with submodules:
```sh
git clone --recursive https://github.com/OrtheSnowJames/voyage.git
```

2. If you already cloned without submodules, initialize them:
```sh
git submodule update --init --recursive
```

### Running the Game
In the game directory:
```sh
love .
```

## Roadmap
- Add better assets
- Give a makeover
- Make things more natural