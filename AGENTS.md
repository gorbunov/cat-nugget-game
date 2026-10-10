# Repository guidance

## Project context and publication
- Cross-platform publishing roadmap: `RELEASE_PLAN.md`. It is deferred until the next gameplay-polish round is complete; resume at Step 1 when requested.
- This is a parent-and-child hobby project, made to teach planning, iteration and following through to a playable result. Preserve this context in README and future publication materials.
- When preparing a public release, store page or announcement, carry forward README's AI-generated images/music disclosure and the third-party sound credits (`art_sources/reactions.json`). The crowd/gulp recordings are CC0 sources, not AI-generated audio.

## Runtime and structure
- Keep code searches, tools, generated assets and builds inside this repository.
- Use Godot 4.7.2 at `/Applications/Godot.app/Contents/MacOS/Godot`; Python tools use the standard library.
- `main.tscn` is a single `Node2D` wired to `scripts/game.gd`. Gameplay, custom-drawn UI, audio and persistence live there; `_step(delta)` advances simulation and `_draw()` renders it. Coordinates use a 640×360 canvas with integer scaling and nearest filtering.
- Golden collection runs after the nugget iteration in `_step` to avoid invalidating indices. Preserve `_eat_nugget(nugget, false)` inside the collection sweep to prevent recursive big-golden sweeps.

## Verification
Run from the repository root. Import after changing assets and before tests/export:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . -- --smoke-test
"$GODOT" --headless --path . --script tools/test_nuggets.gd
```

- The smoke test covers rounds, difficulty, palettes, music selection and saves; `test_nuggets.gd` focuses on bites, hazards, bonuses, collection and spawn odds.
- Test harnesses set `game.test_mode = true` before adding the scene to the tree. This disables live processing and normal save access; smoke-test persistence uses disposable `build/test_save.cfg`. Preserve this to protect player settings/scores.
- Visual checks require a graphical session, **not** `--headless`:
  `"$GODOT" --path . --script tools/preview.gd -- --nuggets`
  writes actual game screenshots to `build/previews/`. Other optional flags: `--hands`, `--cat-colors`, `--dance`, `--sources`, `--check-settings` (real fullscreen/music checks). User flags go after `--`.
- For audio changes, run `python3 tools/check_audio.py` for format, headroom, loop seams and matching finale-stem durations.

## Asset pitfalls
- `assets/cat_indexed.png` is data: its red bytes encode semantic palette roles. Edit colors in `assets/cat_palettes.json`; layout, roles and mouth anchor are in `assets/cat_sprite.json`. Keep role IDs/order stable unless rebuilding the atlas. `scripts/cat_appearance.gd` validates and lazily caches recolored textures.
- Keep the indexed atlas import lossless, mipmaps disabled and `process/fix_alpha_border=false`; treating it as ordinary color art corrupts role IDs.
- Active AI sprites are `assets/hands_ai.png`, `assets/cat_indexed.png` and `assets/nuggets.png`. Offline conversion uses `"$GODOT" --headless --path . --script tools/prepare_hands.gd` (or `prepare_cat.gd` / `prepare_nuggets.gd`). Each converter hardcodes its selected `art_sources/*_v001.png`; generating a new candidate does not activate it.
- `tools/generate_nugget_sprites.gd` is a fallback that **overwrites** the active API-derived `assets/nuggets.png`.
- Preserve generated game assets, retained source art, `.import`, `.uid` and `.gdignore` files in version control. `.godot/` and `build/` are ignored outputs.
- Image generation makes a billed request with no automatic retries. Use a fresh `--name` (existing source PNGs are protected), e.g. `python3 tools/generate_ai_art.py --asset nuggets --name nuggets_v002`. Prefer offline converters when no new artwork is needed.
- Credentials resolve from `OPENAI_API_KEY`, then macOS Keychain service `CatNuggetGame.OpenAI`. `python3 tools/generate_ai_art.py --check-key` checks availability without exposing the key or calling the API. For setup use interactive `python3 tools/setup_api_key.py`; it verifies native Keychain read-back and avoids the CLI password-prompt length issue. See README for the full art workflow.

## macOS packaging
- `python3 tools/fetch_template.py` fetches the pinned 4.7.2 macOS template into `build/templates/macos.zip`; the export preset uses this local template.
- Preserve `include_filter="assets/*.json"` in `export_presets.cfg`: runtime palette metadata must ship with the app.
- Export creates a zip; extract it to update the runnable app:

```sh
"$GODOT" --headless --path . --export-release macOS "build/Nugget Cat.zip"
ditto -x -k "build/Nugget Cat.zip" build
codesign --verify --deep --strict --verbose=2 "build/Nugget Cat.app"
open "build/Nugget Cat.app"
```

- Builds are ad-hoc signed local playtests, not notarized releases. When bumping a release, keep the README heading and both `application/short_version` and `application/version` in `export_presets.cfg` aligned.
