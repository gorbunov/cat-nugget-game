# Repository guidance

## Project context and publication
- Cross-platform publishing roadmap: `RELEASE_PLAN.md`. Gameplay polish passed user playtesting on 2026-10-10. The portable release baseline is implemented; see the roadmap for verification status and next steps.
- This is a parent-and-child hobby project, made to teach planning, iteration and following through to a playable result. Preserve this context in README and future publication materials.
- When preparing a public release, store page or announcement, carry forward README's AI-generated images/music disclosure and the third-party sound credits (`art_sources/reactions.json`). The crowd/gulp recordings are CC0 sources, not AI-generated audio.

## Runtime and structure
- Keep code searches, tools, generated assets and builds inside this repository.
- Use Godot 4.7.2 at `/Applications/Godot.app/Contents/MacOS/Godot`; Python tools use the standard library.
- `main.tscn` has a `Node2D` wired to `scripts/game.gd` and an `Audio` child wired to `scripts/game_audio.gd`. The game owns round policy, custom drawing, input and persistence; audio owns players, looping, synchronized stems, reactions and volumes.
- `_step(delta)` lists simulation phases in order; `_draw()` only renders. Coordinates use a 640×360 canvas with integer scaling and nearest filtering. `scripts/nugget.gd` holds typed mutable flight/bite state; `scripts/difficulty.gd` supplies named pacing values.
- Screen state uses `ScreenLayout.Screen`. Shared button geometry and hit testing live in `scripts/screen_layout.gd`, independently of drawing. Route transitions through the game helpers and keep inactive overlay-background controls out of hit testing. Keyboard bindings are Input Map actions in `project.godot`.
- Golden collection runs after the nugget iteration in `_step` to avoid invalidating indices. Preserve `_eat_nugget(nugget, false)` inside the collection sweep to prevent recursive big-golden sweeps.

## Verification
Run from the repository root. Import after changing assets and before tests/export:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . -- --smoke-test
"$GODOT" --headless --path . --script tools/test_nuggets.gd
```

- `tools/test_smoke.gd` is invoked by the game's `--smoke-test` entry point and covers rounds, difficulty, palettes, music selection, saves and navigation without intervening draws; `test_nuggets.gd` focuses on bites, hazards, bonuses, collection and spawn odds.
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

## Cross-platform builds and macOS packaging
- `release.json` owns game and engine versions. `python3 tools/build_release.py` syncs README/project/export versions, verifies the engine, imports, tests and exports macOS/Windows/Web into `build/macos`, `build/windows` and `build/web`. Logs go to `build/logs`. Use `--targets web` (or `macos` / `windows`) for a single target; `--sync-only` updates version metadata and `--check-version` checks it without writing.
- Presets use installed matching Godot templates. Single-threaded Web requires `web_nothreads_debug.zip` and `web_nothreads_release.zip`. `python3 tools/serve_web.py` serves `build/web` on localhost:8060; no cross-origin isolation headers are required.
- `tools/fetch_template.py` remains an optional local macOS-template fallback; it reads the engine pin from `release.json`, but presets now default to the installed templates.
- `scripts/platform_policy.gd` gates Quit/fullscreen in drawing, hit testing and actions. Browser fullscreen requires a user gesture and is never auto-restored; browser audio also waits for a gesture. Native tablet controls remain a later milestone.
- Preserve `include_filter="assets/*.json"` in `export_presets.cfg`: runtime palette metadata must ship with the app.
- Export creates a zip; extract it to update the runnable app:

```sh
python3 tools/build_release.py --targets macos
open "build/macos/Nugget Cat.app"
```

- Default macOS builds are ad-hoc signed local playtests. `build_release.py --targets macos --notarize` uses `release.json`'s Developer ID identity and Keychain profile, with optional `MACOS_SIGNING_IDENTITY` / `NOTARY_KEYCHAIN_PROFILE` overrides. `tools/notarize_macos.py` signs with hardened runtime, submits, waits, staples, validates and repackages; `tools/test_release.py` tests rejection/tampering gates. Mac itch deployments require notarization even during `--dry-run`. Apple timeouts are resumable with `deploy_itch.py --resume <build-directory>`; never rebuild just to poll a pending submission. Initial submission `fd5864c5-a387-45cb-84ad-9b4b5df2b81c` in `build/itch/0.11.5-20261010T124553910938Z` is pending; see RELEASE_PLAN.md. Windows exports and itch.io embedded Web exports still need platform playtesting before publication.
- itch.io: `itch.json` configures `gorbunov/nugget-cat` and `mac`/`windows`/`html5` channels. `python3 tools/deploy_itch.py` explicitly builds, tests and uploads; `--dry-run` builds and checks payloads without uploading, and `--targets web` limits the release. Butler is installed locally in `build/butler/`; credentials stay in Butler's own store or `BUTLER_API_KEY`. Each run retains fresh artifacts/logs and a partial-completion receipt under `build/itch/`. Version 0.11.5 was uploaded and processed on all three channels on 2026-10-10; browser tagging, embedded play and install/update checks remain dashboard/playtest steps. See README for setup.
