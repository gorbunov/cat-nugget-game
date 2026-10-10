# Nugget Cat · 0.11.5

A small pixel-art arcade game built with Godot 4.7.2 for macOS, Windows and Web.
An orange cat. Sixty seconds. An unreasonable amount of chicken.

## Project

Made together by a parent and child to learn how to plan a hobby project, iterate
on ideas, and follow through to a playable result. Making it together is as
important as the game itself.

**AI disclosure:** The game uses AI-generated images and music. Character, hand,
nugget and room artwork is processed into game-ready assets; music uses
AI-assisted composition and synthesis scripts. Crowd reactions and gulp sounds
are separate CC0 recordings, credited below and in the in-game Sources panel.
Preserve this story, disclosure and credits when publishing the game.

- [Deployment](DEPLOYMENT.md): build, signing, notarization, itch.io uploads and current release status.
- [Cloudflare deployment](DEPLOYMENT.md#cloudflare-custom-domain-web-deployment): Wrangler build/deploy workflow for `cat-nugget.gorbunov.dev`.
- [Planned work](RELEASE_PLAN.md): outstanding validation and future milestones only.
- [Repository guidance](AGENTS.md): implementation conventions and verification rules.

### Current state

- Gameplay polish passed owner playtesting on 2026-10-10.
- macOS, Windows and single-threaded Web exports have passed automated checks.
- Safari and Chrome passed owner browser playtesting; this does not establish
  itch.io embedded-play or Windows-device validation.
- Version 0.11.5 is uploaded and processed on all three itch.io channels.
- The Mac release is Developer ID-signed, notarized and stapled; see
  [deployment status](DEPLOYMENT.md#current-release-status).
- Offset touch dragging is implemented in source; tablet playtesting is pending.

## Play

**Secret Golden Kitty Club (source):** click or tap the title cat's nose seven times
to reveal the secret club screen, then choose **Let's feast!** for one golden round.
Only golden nuggets spawn (including the rare big golden), and the boss becomes
**The Big Golden Chomp**. Each golden round requires entering through the secret
screen again; title starts and results replays are normal rounds. Only the separate
club best score is saved, with no persistent unlock or toggle. Click elsewhere on
the portrait to meet another cat.

Open `project.godot` in Godot and press **F6/F5**, or build a native release:

```sh
python3 tools/build_release.py --targets macos
open "build/macos/Nugget Cat.app"
```

For browser playtesting:

```sh
python3 tools/build_release.py --targets web
python3 tools/serve_web.py
```

Open http://127.0.0.1:8060/. The itch.io project is
https://gorbunov.itch.io/nugget-cat; access depends on its dashboard visibility.

| Control | Action |
|---|---|
| Mouse | Move the cat's mouth; catches and bites happen automatically |
| Touch and drag | Move with the mouth above your finger; lift to leave the cat in place |
| Tap | Activate on-screen buttons; drag volume sliders in Settings |
| Enter / Space | Start or replay |
| Escape | Pause/resume, close a panel; quit from the desktop title screen |
| F11 / Option+Return | Desktop fullscreen (Fn+F11 on some keyboards) |
| On-screen fullscreen control / Alt+Enter | Browser fullscreen, where supported |
| Settings | Master, Music and Sounds volumes; soundtrack selection and fullscreen |

The game pauses on focus loss or a window/fullscreen resize during a round. Browser
audio waits for user interaction; fullscreen requires a gesture and is never
auto-restored. Browser F11 belongs to the browser. Browser/tablet title screens
omit Quit. Native scores/preferences use Godot's `user://` directory; browser
storage is local to the browser/origin and can be cleared by the player or browser.

Touch uses one finger at a time with a 64-pixel upward mouth offset on the logical
640 × 360 canvas. Movement is clamped to the playfield. Extra fingers are ignored
during a drag; pausing or changing screens ends the gesture. A real mouse movement
switches back to mouse control after the touch ends.

The playfield fits proportionally inside the available safe area, with solid
plum margins and a shaded warm frame on wider or taller screens. Low-contrast
pixel paws and sparkles, larger at the sides, form a loose arrangement with fine
corner decorations rather than a repeating pattern. Menu panels and the score
bar use plain backgrounds for readability.
The bottom margin also accepts
gameplay drags, providing extra room below the cat. Portrait shows a rotate-to-landscape
prompt; rotating back leaves an interrupted round paused until Resume is tapped.

### Game rules

Catch nuggets to build a combo. Every five consecutive catches raises the
multiplier for subsequent catches, up to ×5. Missing edible food resets the
combo and golden bonus; letting burnt food fly away has no penalty.

| Nugget | Base score | Behavior | Spawn chance |
|---|---:|---|---|
| Regular | 10 | One chomp | 70% per ordinary throw |
| Big regular | 30 | Three chomps | 15% per ordinary throw |
| Burnt | — | Costs up to 30 points, resets combo/golden bonus, and blocks edible bites for 2 seconds | 11% per ordinary throw |
| Golden | 20 | Adds a multiplier tier, capped at ×5 | 4% per ordinary throw |
| Big golden | 100 | Three chomps, then collects all edible flying nuggets | 18% chance per round |

Edible scores use the current multiplier. Big nuggets retain bite progress when
the cat moves away. Golden collection never eats burnt nuggets. Big regular,
burnt and golden throws unlock at 4, 8 and 12 seconds; locked types become regular
nuggets. Big golden spawns occur at 18–34 seconds; a second has a 0.09% overall
chance per round. The in-game Nugget Guide shows the rules and odds.

Ordinary throws stop at 41 seconds. The final 15 seconds feature a bouncing boss
nugget: track visible food to take 40 bites. Biting accelerates from 3 to 8 chomps
per second over three seconds of contact; brief slips preserve speed, longer gaps
cool it down. Finishing awards 500 points and a three-second belly dance; otherwise
the boss escapes and the earlier score remains.

A burnt bite triggers a two-second edible-bite lockout with an eight-pose
AI-generated reaction: wincing, gagging, spitting tiny droplets/crumbs, and
grimacing. It plays twice at eight frames per second, supports every cat palette,
freezes on pause, and restarts if another burnt nugget is eaten.

Each round chooses a cat name, one of seven palettes, and one of four rooms, with
no immediate color/room repeats. Clicking the title-screen portrait changes the
cat for the next round. Five soundtracks are available: Snack Time, Sunny Side Up,
Goofy Whiskers, Nugget Quest and Nugget Battle. Random selection avoids immediate
repeats; players can keep a chosen track. Music pace rises through the round and
the finale adds a synchronized layer.

## Development

Use Godot **4.7.2** with matching export templates. On this Mac the executable is
`/Applications/Godot.app/Contents/MacOS/Godot`. Python tools use the standard library.
Run commands from the repository root.

### Structure and decisions

itch.io is the main home for desktop downloads and browser play. Native iPad
testing uses TestFlight, with an App Store release considered afterward. Tablet
work does not block the desktop/Web release; iPhone and Android are optional.

| Path | Responsibility |
|---|---|
| `scripts/game.gd` | Round policy, ordered simulation phases, input, rendering and persistence |
| `scripts/game_audio.gd` | Audio players, looping, synchronized stems, reactions and volumes |
| `scripts/nugget.gd` | Typed mutable flight/bite state |
| `scripts/difficulty.gd` | Named pacing stages for throws, flight time and music rate |
| `scripts/screen_layout.gd` | Screen enum, shared button geometry and hit testing |
| `scripts/display_layout.gd` | Proportional playfield framing, safe areas, decorative margins and portrait prompt |
| `scripts/platform_policy.gd` | Platform-specific Quit/fullscreen behavior |
| `scripts/cat_appearance.gd` | Validated indexed palettes and cached recolored textures |
| `scripts/room_background.gd` | Room selection and drawing |
| `main.tscn` | Node2D game root and Audio child |
| `assets/` | Runtime sprites, metadata, font, audio and editable MIDI sources |
| `art_sources/` | Retained game source images, request metadata and sound references |
| `web/shell.html` | Branded Web loader with progress/error reporting |
| `tools/` | Asset preparation, previews, checks and release automation |
| `release.json` / `itch.json` | Release/engine pins, signing configuration and upload destinations |

The logical canvas is **640 × 360**, rendered with proportional scaling and nearest
filtering. The desktop window starts at 1280 × 720. `_step(delta)` orders
simulation phases; `_draw()` only renders. Route navigation through game helpers
and keep inactive overlay-background controls out of hit testing. Input Map
actions are defined in `project.godot`.

Golden collection runs after nugget iteration to avoid invalidating indices.
Preserve `_eat_nugget(nugget, false)` in the sweep to avoid recursive collection.

### Verification

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . -- --smoke-test
"$GODOT" --headless --path . --script tools/test_nuggets.gd
python3 tools/check_audio.py
python3 tools/test_release.py
```

Smoke checks cover rounds, pacing, palettes, music, persistence and navigation
without intervening draws. Nugget tests cover bites, hazards, bonuses, collection
and spawn odds. Test scenes set `game.test_mode = true` before entering the tree;
this disables live processing and normal save access. Persistence tests use
disposable `build/test_save.cfg`. Audio checks cover format, headroom, loop seams
and matching finale-stem lengths. Release tests cover rejection/tampering gates.

Visual checks require a graphical session, **not** `--headless`:

```sh
"$GODOT" --path . --script tools/preview.gd
"$GODOT" --path . --script tools/preview.gd -- --rooms --bites --boss
"$GODOT" --path . --script tools/preview.gd -- --check-settings
```

Screenshots are regenerated into `build/previews/`. Other flags include `--hands`,
`--cat-colors`, `--dance`, `--disgust`, `--sources`, `--layouts` and `--check-title-fullscreen`. User flags go
after `--`. Preview screenshots and editor/Python caches are disposable; retained
release archives, receipts and notarization logs are not temporary scratch files.

### Game assets

`assets/cat_indexed.png`, `assets/cat_dance_indexed.png` and
`assets/cat_disgust_indexed.png` are data: red bytes
encode palette-role IDs. Edit colors in `assets/cat_palettes.json`; geometry,
roles and anchors live in the corresponding sprite JSON files. Keep role IDs
stable, imports lossless, mipmaps disabled and `process/fix_alpha_border=false`.
`cat_appearance.gd` validates metadata and lazily caches recolored textures.

Offline converters preserve the active source selection:

| Converter | Output |
|---|---|
| `prepare_hands.gd` | Three-frame hand atlas from `hands_v001.png` |
| `prepare_cat.gd` | Indexed cat atlas, palette preview and icon from `cat_v001.png` |
| `prepare_cat_dance.gd` | Indexed dance atlas from `cat_dance_v001.png` |
| `prepare_cat_disgust.gd` | Eight aligned, palette-indexed burnt-reaction poses from `cat_disgust_v001.png` |
| `prepare_nuggets.gd` | Six-frame nugget atlas from `nuggets_v001.png` |
| `prepare_nugget_bites.gd` | Bite overlays from the active nugget atlas |
| `prepare_rooms.gd` | Four 640 × 360 rooms from `room_*_v002.png` |
| `prepare_wallpaper.gd` | Retained wallpaper experiment from `wallpaper_v002.png`; not used by the current frame |
| `prepare_boot_splash.gd` | Shared native/Web startup artwork |
| `generate_reactions.py` | CC0 recordings converted to WAV using macOS `afconvert` |

Run GDScript converters with `"$GODOT" --headless --path . --script tools/<name>.gd`,
then import before tests/export. `generate_nugget_sprites.gd` is a procedural
fallback that **overwrites** the active nugget atlas. `generate_assets.py` and
`compose_music.py` generate procedural assets/music; `generate_ai_hands.py` is the
hands-specific API helper. Keep game source art, runtime assets, `.import`, `.uid`
and `.gdignore` files tracked; `.godot/` and `build/` are ignored outputs.

To configure image-generation credentials:

```sh
python3 tools/setup_api_key.py
python3 tools/generate_ai_art.py --check-key
```

Credentials resolve from `OPENAI_API_KEY`, then macOS Keychain service
`CatNuggetGame.OpenAI`. Setup uses a hidden prompt and verifies Keychain read-back;
the availability check makes no API request and never displays the key.

For matching-character companion sheets, `generate_ai_art.py` accepts
`--reference art_sources/cat_v001.png` and uses the Image API edit endpoint.
For example, `--asset cat_disgust --name cat_disgust_v002 --reference art_sources/cat_v001.png`
creates a new candidate without activating it. The retained metadata records the
reference path and prompt; the converter selects the active source explicitly.

New artwork makes one billed request with no automatic retries. Use a fresh name:

```sh
python3 tools/generate_ai_art.py --asset nuggets --name nuggets_v002
python3 tools/generate_ai_art.py --asset rooms --room kitchen --quality high --name room_kitchen_v003
```

Generating a candidate does not activate it: inspect it, change the converter's
selected source, run the converter, and import. Existing source PNGs are protected.

## Sound credits

These recordings use [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Conversion uses mono WAV, normalized peaks and short edge fades; pitch is unchanged.

| Use | Recording | Creator | Edit |
|---|---|---|---|
| Burnt nugget | [Small crowd reactions](https://freesound.org/people/IENBA/sounds/488472/) | IENBA | First two seconds |
| Golden / big golden | [yay.mp3](https://freesound.org/people/zut50/sounds/162395/) | zut50 | Full clip |
| Big regular | [gulpCartoony.mp3](https://freesound.org/people/gary_in_wv/sounds/449868/) | gary_in_wv | Full clip |

`art_sources/reactions.json` retains source URLs, license references and clip
boundaries. The in-game Sources panel also links these credits and credits Godot.
