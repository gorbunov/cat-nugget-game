# Nugget Cat · 0.11.5

A tiny, original pixel-art arcade game for Godot 4.7.2 and macOS.
An orange cat. Sixty seconds. An unreasonable amount of chicken.

## Why we made this

This game was made together with my kid as a hands-on way to learn how to plan
a hobby project, iterate on ideas, and follow through to a finished, playable
result. The process of making something together is as important as the game.

**AI disclosure:** This game uses AI-generated images and music. The character,
hand, nugget and room artwork was generated with AI and processed into game-ready
sprites; the music was made through AI-assisted composition and synthesis scripts.
The crowd reactions and gulp are separately sourced CC0 recordings, credited in
the sound references below and in the in-game Sources panel.

This project background and AI disclosure should accompany the game if we
publish or share it publicly.

## Play

Open **`build/Nugget Cat.app`**, or import `project.godot` in Godot and press **F6/F5**.

- **Mouse:** move the cat's mouth; catches happen automatically.
- **Enter / Space:** start a round or replay from results.
- **Escape:** quit from the title screen, pause/resume during a round, or close a settings/guide/sources panel. The game also pauses when it loses focus.
- **F11 / Option+Return:** toggle fullscreen. On keyboards with media keys, use **Fn+F11**.
- **Start-screen square expand/contract icon:** switch fullscreen mode with one click.
- **Settings:** fullscreen toggle, music selection, and Master/Music/Sounds volume sliders.

Click or drag a volume slider, or use its −/+ buttons. Master controls all audio
and saves with the other preferences; zero mutes the game. Older saves default
Master to 100%. Music now reaches full gain at 100%, with effects and crowd
reactions balanced below it.

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
Cocoa → amber, Lavender → honey-gold, Mint → blue, Charcoal → emerald**. Colored
irises retain dark pupils and bright highlights; blinking and sleeping eyes stay
closed. Charcoal uses soft gray highlights for a readable black-ish coat.
Each cat also gets one of 20 cute names, such as Mochi, Biscuit, Waffles, Dumpling,
Pudding, or Boba. The name appears on the title, gameplay, and results screens;
the color is also shown along the bottom of the play area.
Click the cat portrait on the title screen to meet another randomly named and
colored cat, with no immediate repeats of either. That name/color pair is used
for the next round; subsequent replays resume automatic randomization.

### AI cat art and editable palettes

The cat now uses an AI-generated eight-frame animation sheet, cleaned up into
64×64 pixel-art frames. A single **palette-indexed** atlas contains the shape and
animation information for every color variant. Its red channel stores role IDs,
not visible colors, so `assets/cat_indexed.png` looks nearly black on its own.

- **`assets/cat_palettes.json`** — editable colors and named palettes.
- **`assets/cat_sprite.json`** — role names, frame layout, display size and mouth anchor.
- **`scripts/cat_appearance.gd`** — validated palette loading and lazy texture cache.
- **`art_sources/cat_v001.png`** — original API-generated source image.
- **`art_sources/cat_v001_palette_preview.png`** — all palettes and expressions.

Each palette can override fur/shadow/highlight, belly, iris/highlight, pink
accents, outline and white highlights. Omitted colors inherit `defaults`.
To add another color, append an entry to the `palettes` array, for example:

```json
{
  "name": "PEACH",
  "colors": {
    "fur_shadow": "b87569",
    "fur": "e9a18a",
    "fur_light": "ffd0ab",
    "belly_shadow": "d9b79a",
    "belly": "ffe8ca",
    "iris": "77a685",
    "iris_light": "c1e6b5"
  }
}
```

Restart the game to load palette edits; rebuild the app to ship them. No API call,
new artwork, or gameplay-code change is needed. Random selection automatically
includes added palettes. Role IDs/order in `cat_sprite.json` describe the atlas
format: keep them stable unless rebuilding the indexed sheet. Keep that texture's
import lossless, without mipmaps or alpha-border fixing.

Recoloring uses byte-indexed lookup tables, not source-RGB comparisons or manually
painted eye coordinates. A texture is created on first use of a palette, then
cached and reused; there is no recoloring work during animation playback.

Regular catches earn 10 points times your multiplier. Every five consecutive catches
raises the multiplier for subsequent catches, up to ×5. A miss resets the combo
without subtracting points. The last **15 seconds** are a **BOSS NUGGET** encounter.
New throws stop at 41 seconds, letting existing food be eaten or fly away naturally.
A **BOSS IN 3... 2... 1...** warning and rising sound cues announce the transition
at 45 seconds; the finale music layer joins when the boss arrives. Any lingering
food clears without an extra miss penalty. The larger 96-pixel boss moves faster
and bounces off the playfield edges. Put the mouth anywhere on its visible food
to take 40 automatic bites—there is no center target. Bite holes are not food.
Biting ramps from 3 to 8 chomps per second over three seconds of contact. Brief
slips preserve speed for 0.25 seconds; longer gaps gradually cool it down. Damage
persists, but bites never accumulate while away. Perfect tracking takes about six
seconds. Finishing awards a fixed 500-point bonus and freezes the countdown for
a three-second, palette-matched upright belly dance, which loops on results.
If time runs out, the boss escapes and you keep your earlier score.
The exclusive boss-win dance uses an eight-pose OpenAI-generated sprite sheet,
converted offline to a 96×96 palette-indexed atlas. It includes raised paws,
hip sways, a belly-forward pose and a happy blink in all seven cat palettes.
The retained source and request metadata are `art_sources/cat_dance_v001.png`
and `.json`; `assets/cat_dance_sprite.json` defines the frame geometry and roles.
Rebuild it offline with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_cat_dance.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview.gd -- --boss
```

Keep `assets/cat_dance_indexed.png` lossless with mipmaps and alpha-border fixing
disabled, just like the gameplay cat atlas. To request a new candidate, use
`python3 tools/generate_ai_art.py --asset cat_dance --quality high --name cat_dance_v002`
(one billed request); selecting a new source requires updating the converter.
At the end of each round, your cat celebrates with a looping victory dance:
hops, squishy landings, side-to-side wiggles, turns, silly expressions and sparkles.
The same cat, name, fur and eye palette carry through to the results screen.

### Nugget types and spawn odds

Open **Nugget Guide + Odds** on the title screen, or **Nugget Guide** while paused.

| Type | Base score | Effect | Chance |
|---|---:|---|---:|
| Regular | 10 | One automatic chomp; two crispy silhouettes | 70% per ordinary throw |
| Big regular | 30 | Three automatic chomps | 15% per ordinary throw |
| Burnt | — | Avoid; eating one costs up to 30 points and resets combo/golden bonus | 11% per ordinary throw |
| Golden | 20 | Adds one multiplier tier, capped at ×5 | 4% per ordinary throw |
| Big golden | 100 | Three chomps, then collects all edible flying nuggets | 18% chance per round |

All edible base scores use the current multiplier. Stay on a big nugget to chomp
three times, 0.2 seconds apart; bite progress is retained if you move away. Each
bite slows it down and its three pips show progress. Missing edible food resets
the combo and golden bonus. Letting burnt food fly away has no penalty. Burnt
nuggets remain on screen during a golden collection wave; the wave never eats them.

Burnt catches play the first two seconds of IENBA's **Small crowd reactions**;
either golden type plays zut50's **Yay!**; finishing a big regular plays
gary_in_wv's **Cartoony Gulp**. Reactions follow effects volume; collection waves
keep a single cheer. All three recordings are CC0; source links and license
details are retained in `art_sources/reactions.json` alongside their high-quality
Freesound MP3 previews. Prepare the bundled WAVs offline with
`python3 tools/generate_reactions.py` (requires macOS `afconvert`). Conversion
preserves natural pitch and timing, applies peak normalization and tiny edge fades.

#### Sound credits and references

The title screen's **Sources** panel credits the creators and links to each sound
and its license. These recordings are released under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), permitting commercial
use and modification without required attribution.

| Use | Recording | Creator | Edit |
|---|---|---|---|
| Burnt nugget | [Small crowd reactions](https://freesound.org/people/IENBA/sounds/488472/) | IENBA | First 2 seconds |
| Golden / big golden | [yay.mp3](https://freesound.org/people/zut50/sounds/162395/) | zut50 | Full clip |
| Big regular | [gulpCartoony.mp3](https://freesound.org/people/gary_in_wv/sounds/449868/) | gary_in_wv | Full clip |

All three are converted to mono WAV with normalized peaks and tiny edge fades;
pitch is unchanged. `art_sources/reactions.json` retains the source-page URLs,
download URLs, license references and clip boundaries for future documentation.
Preview the in-game credits with
`/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview.gd -- --sources`.

Big regulars unlock after 4 seconds, burnt after 8, and golden after 12. Until a
type unlocks, its share becomes regular nuggets. The percentages in the table
apply after the warm-up; rare big-golden spawns replace an ordinary throw.
An eligible round gets one big golden between 18–34 seconds. Only 0.5% of those
rounds get a second at 36–38 seconds: **0.09% of all rounds**, about 1 in 1,100.
There are never more than two. Golden bonuses do not inflate the actual catch streak.

The six-frame `assets/nuggets.png` atlas includes two regular shapes and the four
special appearances. The active sprites were generated through the image API,
then cropped, scaled and palette-reduced into crisp 32px frames. The original
sheet and enlarged game-ready preview are retained at
`art_sources/nuggets_v001.png` and `art_sources/nuggets_v001_pixel_preview.png`.
The local generation tool remains available as an offline fallback.

Big regular and big golden nuggets now show actual missing bites and pale exposed
centers after each chomp. The separate `assets/nugget_bites.png` atlas is derived
offline from the active sprites by `tools/prepare_nugget_bites.gd`; regenerate it
after replacing `assets/nuggets.png`. The bite shape rotates with the nugget and
persists if the cat moves away before finishing it.

### Randomized pixel-art rooms

Sage Kitchen, Strawberry Cafe, Sunroom and Moonlit Study each use an individual
1536×1024 OpenAI image generated at high quality. The selected sources are
`art_sources/room_{kitchen,cafe,sunroom,study}_v002.png`, with prompts and non-secret
request metadata retained alongside them. `tools/prepare_rooms.gd` converts these
directly to native 640×360 room frames in `assets/rooms.png`, preserving the source
material colors and fine detail. Runtime integer scaling uses nearest filtering.
The muted sage, pink, botanical and lavender themes keep scenery quieter than the
cat and food. The original four-room candidate remains in `art_sources/rooms_v001.png`.

Each round chooses a different room without immediate repeats, with randomized
left/right furniture orientation. It stays fixed through pause and results;
scenery randomness is independent of gameplay randomness.

```sh
# Offline conversions (no API request).
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_rooms.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_nugget_bites.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
# Actual game screenshots, including all bite stages against every room.
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview.gd -- --rooms --bites
# Verify the start-screen toggle and capture rooms at actual fullscreen size.
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/preview.gd -- --rooms --check-title-fullscreen
```

To generate another room candidate, use
`python3 tools/generate_ai_art.py --asset rooms --room kitchen --quality high --name room_kitchen_v003`
(one billed request, no automatic retries). Room choices are `kitchen`, `cafe`,
`sunroom` and `study`. Inspect it, then update `SOURCES` in
`tools/prepare_rooms.gd` to activate it via the offline conversion.

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
New throws stop at 41 seconds; the boss arrives at 45 seconds.
Throw intervals and flight times apply only to ordinary food;
the music continues its speed ramp during the boss encounter.
Music speed and pitch rise together for an arcade-style build-up; the main tune
and finale layer use the same rate. Settings previews, results, and title music
return to normal speed. Resuming restores the current round's musical pace.

The game opens at 1280×720 with a 640×360 logical canvas and integer scaling.
Best score and volume settings are saved through Godot's standard `user://`
location (`~/Library/Application Support/Godot/app_userdata/Nugget Cat/`).

## Project layout

| Path | Purpose |
|---|---|
| `scripts/game.gd` | Round lifecycle, simulation, input, custom drawing and persistence |
| `scripts/game_audio.gd` | Scene-owned music, synchronized finale, effects pool and reaction voice |
| `scripts/screen_layout.gd` | Screen enum and shared geometry for drawing and button hit testing |
| `scripts/nugget.gd` | Typed mutable nugget flight and bite state |
| `scripts/difficulty.gd` | Smooth pacing curve with named throw interval, flight time and music rate |
| `scripts/cat_appearance.gd` | Indexed palette validation and cached cat textures |
| `main.tscn` | Main Node2D with an Audio child node |
| `assets/` | Original PNG sprite sheets, bitmap font, synthesized WAV audio |
| `tools/generate_assets.py` | Reproducible art/audio generator, Python standard library only |
| `tools/compose_music.py` | Four additional compositions, MIDI sources and matching finale layers |
| `tools/check_audio.py` | Checks music format, headroom, loop boundaries and matching stem durations |
| `tools/generate_ai_hands.py` | One OpenAI Image API request; reads `OPENAI_API_KEY` from the environment |
| `tools/generate_ai_art.py` | Shared API generator for hand, cat, nugget and room sheets; one candidate per request |
| `tools/prompts/hands.txt` | Art direction and pose/layout prompt |
| `tools/prompts/cat.txt` | Eight cat expressions and source color-role instructions |
| `tools/prepare_hands.gd` | Offline cleanup, 14-color palette reduction and wrist alignment |
| `tools/prepare_cat.gd` | Offline cat alignment, semantic index map, palette preview and app icon |
| `tools/generate_nugget_sprites.gd` | Local six-frame nugget art for offline playtests |
| `tools/prepare_nuggets.gd` | Convert the API nugget sheet into the same game atlas |
| `tools/prepare_nugget_bites.gd` | Derive transparent bite stages from the active big nugget sprites |
| `tools/prepare_rooms.gd` | Convert the API room sheet to pixel-grid backgrounds with muted palettes |
| `tools/test_nuggets.gd` | Multi-chomp, hazard, buff, sweep and probability integration checks |
| `tools/test_smoke.gd` | Round, music, palette, persistence and navigation checks; invoked with `--smoke-test` |
| `art_sources/` | Generated source, request metadata and enlarged sprite preview; ignored by Godot |
| `tools/fetch_template.py` | Fetch matching macOS template into this project using HTTP byte ranges |
| `tools/preview.gd` | Render actual game screens; `--rooms --bites` covers scenery and bite stages |
| `export_presets.cfg` | Local macOS export configuration |
| `build/` | App, zip, export template, and preview screenshots; ignored by Godot |

### Code organization

The game keeps its 640×360 custom renderer and a small scene tree. `game.gd`
coordinates a round; `_step(delta)` lists the simulation phases in execution
order. Golden collection runs after nugget collisions, so removing collected
food cannot invalidate that iteration. Each flying nugget is a shared, typed
`RefCounted` record used by simulation, drawing and the preview tools.

`game_audio.gd` owns playback nodes and volume application. The game decides when
to select a track, pause, or start the finale; the audio component handles how.
It is an ordinary child of the main scene, with no global singleton state.

Screen changes use `ScreenLayout.Screen` and the transition helpers in
`game.gd`. Button rectangles live in `screen_layout.gd`; drawing and hit testing
use that same geometry. Only the active screen accepts clicks, even before its
first draw. Keyboard shortcuts are the `confirm`, `back`, and
`toggle_fullscreen` actions in Project Settings → Input Map.

When extending the game:
- Add nugget rules in `NUGGET_TYPES` and the consumption/spawn helpers, and cover
  new mechanics in `tools/test_nuggets.gd`.
- Add a screen's button geometry in `screen_layout.gd`, its presentation and
  actions in `game.gd`, and navigation checks in `tools/test_smoke.gd`.
- Keep rendering free of simulation changes and random-number consumption.
- Set `test_mode` before adding test scenes to the tree. It suppresses live
  processing, audio playback and normal save access; persistence tests use a
  disposable file under `build/`.

## Development commands

### Persistent image API credentials on macOS

Store the key once in macOS Keychain. Run this helper in your terminal:

```sh
python3 tools/setup_api_key.py
```

Paste your complete OpenAI API key at the hidden prompt. The helper writes through
the native Keychain API and verifies an exact read-back, avoiding possible length
limits in the `security` CLI's interactive password prompt. The key never appears
in command arguments or shell history. Image-generation tools first
check `OPENAI_API_KEY`, then this Keychain entry. The key stays outside the project
and persists across terminal/OpenCode restarts. To confirm availability without
displaying the key or making a billed request:

```sh
python3 tools/generate_ai_art.py --check-key
```

### Build and asset commands

Run from this project folder:

```sh
# Recreate the procedural assets and music.
python3 tools/generate_assets.py

# Recreate the game hand sheet from the retained AI source (offline, no API call).
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_hands.gd

# Recreate the indexed cat atlas, preview and icon from the retained AI source.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_cat.gd

# Check generated music files.
python3 tools/check_audio.py

# Import resources.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit

# Run deterministic behavior checks without changing saved scores/settings.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke-test

# Verify special nugget mechanics and spawn distributions.
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/test_nuggets.gd

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

Game art, font glyphs, melodies and synthesized effects are generated specifically
for this project; crowd/gulp reactions use the credited CC0 recordings above.
Python tools require no external libraries.
The v0.7 hands were generated with OpenAI's `gpt-image-2.5-flare`, then processed
locally into three aligned 64×48 pixel-art frames: ready, wind-up and release.
The original PNG and non-secret request metadata are retained in `art_sources/`.
The game uses `assets/hands_ai.png`; procedural asset regeneration preserves it.

To request another candidate (this makes a billed API request):

```sh
python3 tools/generate_ai_hands.py --name hands_v002
python3 tools/generate_ai_art.py --asset cat --name cat_v002
python3 tools/generate_ai_art.py --asset nuggets
# After inspecting the generated nugget source:
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/prepare_nuggets.gd
```

The generator never stores the API key. New candidates do not replace the active
sprites automatically; `tools/prepare_hands.gd` records the selected source and
its wrist anchors, and `tools/prepare_cat.gd` records cat frame alignment. The
v0.9 cat sheet also used `gpt-image-2.5-flare`. Source PNGs, prompts and non-secret
request metadata are retained for both assets. Enlarged previews are available
in `art_sources/`.
