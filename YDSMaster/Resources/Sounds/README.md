# Sounds

All audio sourced from Pixabay (pixabay.com) under the Pixabay Content
License — free for commercial use in apps, no attribution required.
Downloaded 2026-07-08.

| File | Pixabay track | Use |
|---|---|---|
| sfx_pop.mp3 | "Bubble Pop 06" | correct answer |
| sfx_bonk.mp3 | "BUZZER OR WRONG ANSWER" | wrong answer |
| sfx_slice.mp3 | "sword slash" | Word Slice cut |
| sfx_cannonFire.mp3 | "Cannon Shot" | cannon / shot |
| sfx_explosion.mp3 | "Explosion" | target destroyed |
| sfx_stamp.mp3 | "traditional stamp" | factory accept |
| sfx_reject.mp3 | "Error Notification" | factory reject |
| sfx_monsterHit.mp3 | "Punch 03" | monster damaged |
| sfx_monsterRoar.mp3 | "Monster Growl" | monster attacks |
| sfx_comboUp.mp3 | "UI Success Chime" | combo milestone |
| sfx_levelUp.mp3 | "Level Passed" | level up |
| sfx_victory.mp3 | "Success Fanfare Trumpets" | round complete |
| sfx_bossDefeat.mp3 | "Winner game sound." | boss defeated |
| bgm_menu.m4a | "Pixel Dreams" (AAC re-encode) | menu music loop |
| bgm_arena.m4a | "Chiptune Video Game Games Music" (AAC re-encode) | gameplay music loop |

Playback/naming contract lives in Core/Services/SoundManager.swift:
`sfx_<SoundEffect.rawValue>` and `bgm_<MusicTrack.rawValue>`, any of
.caf/.m4a/.mp3/.wav. Replace a file (same name) to swap a sound.
