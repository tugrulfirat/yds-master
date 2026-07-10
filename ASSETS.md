# Art asset drop-in guide

Add each image to `YDSMaster/Assets.xcassets` (Xcode → drag the PNG in → rename
the image set to the exact name below). The app checks for these names at
runtime — **any asset you add instantly replaces the code-drawn placeholder**,
and anything missing keeps its vector fallback. Transparent-background PNGs
unless noted. @2x/@3x variants welcome but a single large PNG works.

## Arena backgrounds (full-screen, no transparency)

| Name | Content | Size |
|---|---|---|
| `arena_wordCannon` | Meadow/castle sky arena (dark-friendly) | 1290×2796 or any 9:19.5 |
| `arena_wordSlice` | Purple space/starfield arena | same |
| `arena_meaningFactory` | Factory hall with gears/pipes | same |
| `arena_monsterBattle` | Desert canyon boss arena | same |
| `arena_wordHuntMirror` | Cozy library/study arena — bookshelves, warm lamps | same |
| `arena_wordInvaders` | Retro space-shooter arena — deep space, distant stars, subtle grid horizon | same |

A dark overlay is applied automatically so HUD text stays readable — bright
mockup-style art is fine.

## Word Cannon

| Name | Content | Size / notes |
|---|---|---|
| `cannon_barrel` | Barrel only, pointing STRAIGHT UP (muzzle at top, breech at bottom) | ~360×760 portrait |
| `cannon_body` | Front-facing carriage/mount with wheels, NO barrel, open at the top | ~700×500 |
| `word_ball` | Empty ball/bubble the word is written on | ~220×220, word text is rendered on top |
| `shield` | Metal shield, word is rendered on top | ~340×310 |
| `shield_gold` | Golden bonus variant | same |

## Monster Battle

| Name | Content | Size / notes |
|---|---|---|
| `golem` | Normal word-golem, chest area kept plain (word is rendered on it) | ~750×850 |
| `golem_boss` | Bigger/angrier boss variant | ~900×1000 |

## Meaning Factory

| Name | Content | Size / notes |
|---|---|---|
| `crate` | Wooden crate, word is rendered on top | ~320×280 |

## Word Hunt Mirror

| Name | Content | Size / notes |
|---|---|---|
| `magnifier_tile` | A single mode icon: magnifying glass over a lettered tile | ~500×500 |

The letter grid itself stays plain UI (rounded cards) on purpose — art on every
cell would hurt legibility of the traced letters.

## Word Invaders

| Name | Content | Size / notes |
|---|---|---|
| `invader_ship` | The player's spaceship, viewed from behind/above, nose pointing up | ~300×300 |

Flying word pods and the boss ship stay code-drawn for now — no asset needed
unless you want to restyle them later (ask and I'll add the hooks).

## App icon

Drop a 1024×1024 PNG into `Assets.xcassets/AppIcon.appiconset`.

## Notes for generation

- Words/labels are always rendered by the app **on top of** the art — keep the
  center of shields, balls, crates, and the golem's chest relatively clean.
- The UI base stays dark premium; arenas can be colorful — the app dims them
  slightly for contrast.
- Style reference: the mockups (chunky outlines, glossy 3D cartoon objects,
  saturated colors).
