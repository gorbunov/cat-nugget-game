# Nugget Cat · 0.8.0

A tiny, original pixel-art arcade game for Godot 4.7.2 and macOS.
An orange cat. Sixty seconds. An unreasonable amount of chicken.

## Play

Open **`build/Nugget Cat.app`**, or import `project.godot` in Godot and press **F6/F5**.

- **Mouse:** move the cat's mouth; catches happen automatically.
- **Enter / Space:** start a round or replay from results.
- **Escape:** pause/resume. The game also pauses when it loses focus.
- **F11 / Option+Return:** toggle fullscreen. On keyboards with media keys, use **Fn+F11**.
- **Settings:** fullscreen toggle, music selection, and separate music/effects volumes.

Fullscreen switching during a round pauses the game so window changes never cost a
catch. Press Escape or Keep Munching to continue. Windowed size and position are
restored when leaving fullscreen. Fullscreen and soundtrack preferences are saved.

### Soundtrack

By default, a random track is selected at launch and at the start of each round,
with no back-to-back repeats. **Settings → Music: Random Each Round** toggles
randomization. The arrow buttons preview a track and switch to **Keep This Track**
mode. This preference is saved, including when upgrading an older save.

| Track | Character | Tempo |
|---|---|---|
| Snack Time | Original bouncy chip melody | 128 BPM |
| Sunny Side Up | Sunny bell lead, light arpeggios, breezy rhythm | 112 BPM |
| Goofy Whiskers | Staccato jumps, swung offbeats, bouncing bass | 144 BPM |
| Nugget Quest | Adventurous pulse lead, rising melodies, layered harmony | 132 BPM |
| Nugget Battle | Minor-key battle melody, driving eighth-note bass, stronger drums | 152 BPM |

The v0.6 arrangements use lower-register leads, rounded synth waveforms, softer
attacks/releases, and gentle treble filtering. Finale arpeggios are lower and
quieter too. The battle track gets its intensity from rhythm and harmony while
using the same softened chip instruments. It is included in random selection.

Each new track has a 32-bar arrangement with phrase variations and its own
tempo/harmony-matched finale layer. Tracks loop; each round's track starts fresh
with each round. The music selector previews audio even from the paused game.
The new tracks also have editable **`.mid` files in `assets/`**. The game plays
rendered WAVs so no MIDI synth or soundfont installation is needed.

### Random cat colors

Every round gets a random **Ginger, Snow, Silver, Cocoa, Lavender, Mint, or Charcoal** cat,
without repeating the preceding color. Its color stays the same during gameplay,
pause, and results. The palette swap changes fur, highlights, and belly while
preserving mouth, blush, outlines, and transparency across all animations.
Eyes are coordinated with the fur: **Ginger → green, Snow → blue, Silver → teal,
Cocoa → amber, Lavender → honey-gold, Mint → blue, Charcoal → gold**. Colored
irises retain dark pupils and bright highlights; blinking and sleeping eyes stay
closed. Charcoal uses soft gray highlights for a readable black-ish coat.
Each cat also gets one of 20 cute names, such as Mochi, Biscuit, Waffles, Dumpling,
Pudding, or Boba. The name appears on the title, gameplay, and results screens;
the color is also shown along the bottom of the play area.
Click the cat portrait on the title screen to meet another randomly named and
colored cat, with no immediate repeats of either. That name/color pair is used
for the next round; subsequent replays resume automatic randomization.

Each catch earns 10 points times your multiplier. Every five consecutive catches
raises the multiplier for subsequent catches, up to ×5. A miss resets the combo
without subtracting points. The last ten seconds are **SNACK PANIC!**
Nuggets still airborne at the buzzer are discarded, not counted as misses.

### Difficulty and musical pace

The first hand appears after 0.25 seconds and releases its nugget roughly one
second into the round. Throw frequency, flight speed, and music speed follow a
shared smooth curve:

| Time into round | Average throw interval | Flight time to target | Music speed |
|---|---|---|---|
| 0 seconds | 0.82 s | 1.05 s | 1.00× |
| 15 seconds | 0.64 s | 0.95 s | 1.04× |
| 35 seconds | 0.48 s | 0.82 s | 1.09× |
| 50 seconds | 0.36 s | 0.75 s | 1.14× |
| 60 seconds | 0.30 s | 0.68 s | 1.20× |

Throws have ±8% timing variation, with the same readable wind-up throughout.
Music speed and pitch rise together for an arcade-style build-up; the main tune
and finale layer use the same rate. Settings previews, results, and title music
return to normal speed. Resuming restores the current round's musical pace.

The game opens at 1280×720 with a 640×360 logical canvas and integer scaling.
Best score and volume settings are saved through Godot's standard `user://`
location (`~/Library/Application Support/Godot/app_userdata/Nugget Cat/`).

## Project layout

| Path | Purpose |
|---|---|
| `scripts/game.gd` | Gameplay, UI, animation, sound playback, persistence |
| `main.tscn` | Main scene |
| `assets/` | Original PNG sprite sheets, bitmap font, synthesized WAV audio |
| `tools/generate_assets.py` | Reproducible art/audio generator, Python standard library only |
| `tools/compose_music.py` | Four additional compositions, MIDI sources and matching finale layers |
| `tools/check_audio.py` | Checks music format, headroom, loop boundaries and matching stem durations |
| `tools/generate_ai_hands.py` | One OpenAI Image API request; reads `OPENAI_API_KEY` from the environment |
| `tools/prompts/hands.txt` | Art direction and pose/layout prompt |
| `tools/prepare_hands.gd` | Offline cleanup, 14-color palette reduction and wrist alignment |
| `art_sources/` | Generated source, request metadata and enlarged sprite preview; ignored by Godot |
| `tools/fetch_template.py` | Fetch matching macOS template into this project using HTTP byte ranges |
| `tools/preview.gd` | Render five actual game screens for inspection |
| `export_presets.cfg` | Local macOS export configuration |
| `build/` | App, zip, export template, and preview screenshots; ignored by Godot |

## Development commands

Run from this project folder:

```sh
# Recreate the procedural assets and music.
python3 tools/generate_assets.py

# Recreate the game hand sheet from the retained AI source (offline, no API call).
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_hands.gd

# Check generated music files.
python3 tools/check_audio.py

# Import resources.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit

# Run deterministic behavior checks without changing saved scores/settings.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke-test

# Render screenshots (requires graphical session).
mkdir -p build/previews
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview.gd

# Also verify actual fullscreen transitions and music previews.
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview.gd -- --check-settings

# Get only the macOS template; no global Godot installation changes.
python3 tools/fetch_template.py

# Export an ad-hoc-signed local build.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release macOS "build/Nugget Cat.zip"
ditto -x -k "build/Nugget Cat.zip" build
open "build/Nugget Cat.app"
```

The macOS app is a local playtest release, ad-hoc signed rather than notarized
for public distribution. The source project is also playable directly in Godot.

## First playtest

Try a full round and a replay. Feedback for the next iteration:

1. Is the mouth target clear, and are catches forgiving enough?
2. Does the ramp from gentle throws to the finale feel right?
3. Should the cat be bigger, floppier, or more unhinged?
4. Does the chiptune feel cheerful or get repetitive?

All game art, font glyphs, melody, and sound effects are generated specifically
for this project; no downloaded art/music packs or external Python libraries.
The v0.7 hands were generated with OpenAI's `gpt-image-2.5-flare`, then processed
locally into three aligned 64×48 pixel-art frames: ready, wind-up and release.
The original PNG and non-secret request metadata are retained in `art_sources/`.
The game uses `assets/hands_ai.png`; procedural asset regeneration preserves it.

To request another candidate (this makes a billed API request):

```sh
python3 tools/generate_ai_hands.py --name hands_v002
```

The generator never stores the API key. New candidates do not replace the active
sprites automatically; `tools/prepare_hands.gd` records the selected source and
its wrist anchors. An enlarged first-candidate preview is available at
`art_sources/hands_v001_pixel_preview.png`.
