# YDS Master 🎯⚔️🏭👾

An iOS arcade vocabulary game for Turkish students preparing for the YDS exam.
**Learn YDS vocabulary by playing fast, satisfying word games** — the word is not
just text; you throw it, slice it, sort it, and fight with it.

## Requirements

- Xcode 16+ (the project uses the modern folder-synchronized project format)
- iOS 17.0+ (iPhone, portrait)

Open `YDSMaster.xcodeproj`, pick an iPhone simulator, and Run. No dependencies,
no login, fully offline.

## The 4 game modes

| Mode | Mechanic | Best for |
|---|---|---|
| 🎯 Word Cannon | Grab a word ball, aim with a live trajectory preview, flick it at the meaning target (SpriteKit physics) | Learning new words |
| ⚔️ Word Slice | Words are tossed across the screen; swipe-slice only the correct one (SpriteKit, combo + lives + slow-motion) | Confusing look-alikes (prevent/provide/prove…) |
| 🏭 Meaning Factory | Words ride a conveyor belt; drag each crate into the right meaning machine before it escapes | Fast review of many words |
| 👾 Monster Battle | Flick word weapons at monsters; wrong answers get eaten and the monster strikes back. Final monster is a **boss** built from your missed words | Weak-word revenge & review |

All modes support **English → Turkish**, **Turkish → English**, and **Mixed**
(direction resolved per question).

## Learning system

- Every word has a mastery score 0–100 (New / Familiar / Strong / Mastered bands).
- Correct answers raise mastery and push `nextReviewAt` further out (4h → 1d → 3d → 7d);
  wrong answers drop mastery and bring the word back within minutes — invisible spaced repetition.
- Repeatedly missed words become **weak words**, resurface more often, feed the
  Weak Words mode and the Monster Battle boss.
- Daily Mission chains all 4 games (new → review → weak words) for a +100 XP bonus.
- XP, levels, streaks, combos, badges, and limited power-ups
  (First Letter, Remove Wrong, Slow Motion, Magnet, Shield).

## Architecture

```
YDSMaster/
├── App/                    App entry + root routing
├── Core/
│   ├── Models/             Word, WordProgress (SRS), UserProfile, GameTypes, WordPack
│   ├── Data/               WordDataSource protocol, JSON/CSV importers, words.json,
│   │                       PersistenceController (profile + progress as JSON)
│   └── Services/           WordEngine (smart distractors), WordStore (selection, stats,
│                           streaks, missions), GameSession (shared round logic),
│                           Haptics, SoundManager
├── Games/                  One folder per mode; SpriteKit scenes + SwiftUI wrappers
├── UI/                     Theme, reusable components, screens (Home, Onboarding,
│                           Results, Word Bank, Game Select)
└── Resources/Sounds/       Sound-effect placeholders (see its README)
```

Key rule: **game screens contain zero learning logic.** `GameSession` owns the
question queue, validation, XP/combo, and progress updates; games only render,
animate, and forward the answer the player physically produced.

## Importing the 5000-word database

The prototype ships 46 sample words in `Core/Data/words.json`. To load the full
database, either:

1. **JSON** — replace `words.json` with a 5000-entry file in the same shape, or
2. **CSV** — use `CSVWordDataSource` (column format documented in
   `WordDataSource.swift`), or
3. add a new `WordDataSource` conformer (SQLite, Core Data…) and inject it into
   `WordStore(dataSource:)` in `YDSMasterApp.swift`.

User progress is stored separately (keyed by word ID), so swapping the database
never loses progress. `WordPack` groups words into themed packs
(Essential 100, Confusing Words, …) by ID.

## Verified

The platform-independent core (models, word engine, spaced repetition, session
logic, persistence) is covered by a 59-assertion test harness that compiles and
runs with plain `swiftc` — distractor quality, mastery math, weak-word flow,
daily mission, power-ups, and persistence round-trips are all exercised.
