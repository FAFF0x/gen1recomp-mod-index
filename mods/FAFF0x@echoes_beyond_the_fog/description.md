# Echoes Beyond the Fog

Version 2.1.0

A post-game quest mod for Gen1Recomp inspired by the atmosphere and central mystery of the anime episode **Mystery at the Lighthouse**.

## Requirements

- Gen1Recomp 0.1.38 or newer
- Quest System 1.0.3 or newer

## Unlock conditions

- Complete Bill's original Sea Cottage event.
- Obtain the Soul Badge.
- Speak to the human Bill in Bill's House.

## Visible interaction markers

A bright yellow **`!`** marks the exact interaction tile.

Walk onto the marker to:

- inspect a story object;
- solve a puzzle;
- activate a console;
- start an encounter;
- use a locked route.

Mandatory interactions are not hidden. The quest journal and the route boards near each major entrance repeat the current objective.

## Dungeon structure

### Cape Signal Observatory

1. **Study:** read Bill's field log and learn what happened when the giant Dragonite originally approached the lighthouse.
2. **Engine Room:** restore the generator using the breaker order `SEA -> LENS -> HORN`.
3. **Beacon Dome:** broadcast `LOW-HIGH-LOW` and open the cliff route.

### Fogbound Caverns

1. Cross the upper echo caves using the worked path, bridges and cyan landmarks.
2. Decode the natural relay and identify the giant Dragonite's call as **A GREETING**.
3. Defeat the Black Tide scout, obtain the MAG-KEY and enter the dock route.

### Black Tide Hideout

1. Cross the warehouse and reach the resonance laboratories.
2. Disable the three yellow-marked resonance anchors.
3. Reach the control deck and stop Captain Morrow's final transmitter.

## Story direction

Years ago, Bill reproduced a mysterious call from his lighthouse. A gigantic Dragonite emerged from the fog because the signal resembled the voice of another of its kind. The creature did not come to attack; it came because it believed it was no longer alone. Team Rocket fired on it, and it disappeared before Bill could answer again.

The new quest begins when Bill's original recording is stolen and retransmitted beneath the cape. Black Tide intends to repeat the old encounter as a controlled capture operation. The player must restore the authentic lighthouse signal, understand the meaning of the call and destroy the artificial resonance net.

The giant Dragonite is never captured. It answers Bill's real call and returns to the open sea. The reward is a separate Dragonite rescued from Black Tide's laboratories.

## Reward

- Level 50 Dragonite
- Maximum Gen 1 DVs
- Maximum Stat Exp in every statistic
- Fully healed when received

If the party is full, Dragonite is sent to the first available PC Box. If the party and every Box are full, Bill keeps the reward safely until space becomes available.

## Replay

After completing the quest, speak to Bill and choose **REPLAY QUEST**. All quest puzzles, battles and area flags are reset. The original Dragonite reward is preserved and cannot be duplicated.

## Included files

- `MAP_GUIDE.md`: concise objective guide
- `MAP_OVERVIEW.png`: overview of all nine dungeon floors
- `tests/echoes_beyond_the_fog_test.lua`: geometry, tileset, marker and script validation
