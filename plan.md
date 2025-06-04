# Pirate Game Design Document

## Core Game Mechanics
- Fishing system with upgradeable equipment
- Crew management (hiring and recovery)
- Ship-to-ship combat
- Day-night cycle (12 minutes)
- Upgrade shop for equipment

## Detailed Game Systems

### 1. Fishing Mechanic
- Implement basic fishing as a timed/minigame action
- Upgrade fishing rod to:
  - Increase fish caught per attempt
  - Decrease wait time
- Add randomness to fish caught (rare fish varieties)

### 2. Crew Management
- Hire men to increase:
  - Fishing speed/efficiency
  - Combat strength
- UI Elements:
  - Men count display
  - Fish count
  - Stamina indicators

### 3. Ship Combat System
- Combat mechanics:
  - Compare crew size vs enemy
  - Use sword level as damage modifier
  - Calculate crew losses based on sword level and enemy strength
- Outcomes:
  - Victory: Gain surviving and fainted crew
  - Defeat: Game over and restart
- Track crew status (fainted vs active)

### 4. Crew Recovery System
- Recovery mechanics:
  - Fainted crew recover while on shore
  - Time-based recovery system
- Features:
  - Dedicated recovery area
  - Player-initiated recovery action
- Separate tracking for active and fainted crew

### 5. Day-Night Cycle
- 12-minute full cycle implementation
- Effects on gameplay:
  - Visual changes (lighting, background)
  - Potential impact on:
    - Fishing success
    - Combat effectiveness
    - Crew recovery speed

### 6. Upgrade Shop
- Available upgrades:
  - Fishing rod improvements
  - Sword enhancements
- Features:
  - Shop interface
  - Transaction system
  - Fish-based currency

## Development Guidelines

### Architecture
- Modular approach with separate Lua files
- State management system for different game states
- UI implementation using SUIT or similar library
- Basic save/load system using love.filesystem

### Project Structure
```
/game
  /fishing.lua
  /combat.lua
  /men.lua
  /shop.lua
  /daynight.lua
  main.lua
```

### Development Priority
1. Core fishing and crew hiring mechanics
2. Combat system implementation
3. Recovery system
4. Day-night cycle
5. Shop and upgrades
6. Polish and balance
