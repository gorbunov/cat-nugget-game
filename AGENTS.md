# Repository guidance

## Project context and publication
- `README.md` describes the current game, architecture and development workflow. `DEPLOYMENT.md` owns release status, build/signing/upload procedures and a compact presentation reference. `RELEASE_PLAN.md` contains only outstanding work. Keep facts and planned work separate; remove superseded history rather than accumulating it.
- This is a parent-and-child hobby project, made to teach planning, iteration and following through to a playable result. Preserve this context in README and future publication materials.
- When preparing a public release, store page or announcement, carry forward README's AI-generated images/music disclosure and the third-party sound credits (`art_sources/reactions.json`). The crowd/gulp recordings are CC0 sources, not AI-generated audio.

## Runtime and structure
- Keep code searches, tools, generated assets and builds inside this repository.
- Use Godot 4.7.2 at `/Applications/Godot.app/Contents/MacOS/Godot`; Python tools use the standard library.
- `main.tscn` has a `Node2D` wired to `scripts/game.gd` and an `Audio` child wired to `scripts/game_audio.gd`. The game owns round policy, custom drawing, input and persistence; audio owns players, looping, synchronized stems, reactions and volumes.
- `_step(delta)` lists simulation phases in order; `_draw()` only renders. Coordinates use a 640×360 canvas with proportional scaling and nearest filtering. `scripts/display_layout.gd` owns safe-area framing, decorative margins and the portrait prompt; game input uses local coordinates after the game node's layout transform. `scripts/nugget.gd` holds typed mutable flight/bite state; `scripts/difficulty.gd` supplies named pacing values.
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
  writes actual game screenshots to `build/previews/`. Other optional flags: `--layouts` (tablet/phone/portrait/desktop framing and rotation checks), `--hands`, `--cat-colors`, `--dance`, `--sources`, `--check-settings` (real fullscreen/music checks). User flags go after `--`.
- For audio changes, run `python3 tools/check_audio.py` for format, headroom, loop seams and matching finale-stem durations.
- For release-tool changes, run `python3 tools/test_release.py` for notarization rejection/tampering gates.
- Cloudflare packaging uses `python3 tools/test_cloudflare.py`; after a Wrangler dry-run, add `--serve-check` to verify the actual local server's WASM decoding, headers and 404s.

## Asset pitfalls
- `assets/cat_indexed.png` is data: its red bytes encode semantic palette roles. Edit colors in `assets/cat_palettes.json`; layout, roles and mouth anchor are in `assets/cat_sprite.json`. Keep role IDs/order stable unless rebuilding the atlas. `scripts/cat_appearance.gd` validates and lazily caches recolored textures.
- Keep the indexed atlas import lossless, mipmaps disabled and `process/fix_alpha_border=false`; treating it as ordinary color art corrupts role IDs.
- The companion `assets/cat_disgust_indexed.png` uses the same role table and import rules. `tools/prepare_cat_disgust.gd` converts `art_sources/cat_disgust_v001.png`; `tools/preview.gd -- --disgust` previews its eight burnt-reaction poses. The cooldown drives animation so pause freezes it. Image generation supports `--asset cat_disgust --reference art_sources/cat_v001.png` for a matching-character candidate; always use a fresh `--name`.
- Active AI sprites are `assets/hands_ai.png`, `assets/cat_indexed.png` and `assets/nuggets.png`. Offline conversion uses `"$GODOT" --headless --path . --script tools/prepare_hands.gd` (or `prepare_cat.gd` / `prepare_nuggets.gd`). Each converter hardcodes its selected `art_sources/*_v001.png`; generating a new candidate does not activate it.
- `tools/generate_nugget_sprites.gd` is a fallback that **overwrites** the active API-derived `assets/nuggets.png`.
- Preserve generated game assets, retained source art, `.import`, `.uid` and `.gdignore` files in version control. `.godot/` and `build/` are ignored outputs.
- Keep temporary downloads, browser-test profiles, screenshots and caches out of Git; remove disposable scratch files after use. Retained release artifacts/receipts, pending Apple submissions and installed build tools/templates are operational data, not scratch files. itch.io theme development tools/artwork are outside this repository's maintained scope; keep only the compact design reference in DEPLOYMENT.md.
- Image generation makes a billed request with no automatic retries. Use a fresh `--name` (existing source PNGs are protected), e.g. `python3 tools/generate_ai_art.py --asset nuggets --name nuggets_v002`. Prefer offline converters when no new artwork is needed.
- Credentials resolve from `OPENAI_API_KEY`, then macOS Keychain service `CatNuggetGame.OpenAI`. `python3 tools/generate_ai_art.py --check-key` checks availability without exposing the key or calling the API. For setup use interactive `python3 tools/setup_api_key.py`; it verifies native Keychain read-back and avoids the CLI password-prompt length issue. See README for the full art workflow.

## Cross-platform builds and macOS packaging
- `release.json` owns game and engine versions. `python3 tools/build_release.py` syncs README/project/export versions, verifies the engine, imports, tests and exports macOS/Windows/Web into `build/macos`, `build/windows` and `build/web`. Logs go to `build/logs`. Use `--targets web` (or `macos` / `windows`) for a single target; `--sync-only` updates version metadata and `--check-version` checks it without writing.
- Presets use installed matching Godot templates. Single-threaded Web requires `web_nothreads_debug.zip` and `web_nothreads_release.zip`. `python3 tools/serve_web.py` serves `build/web` on localhost:8060; no cross-origin isolation headers are required.
- `tools/fetch_template.py` remains an optional local macOS-template fallback; it reads the engine pin from `release.json`, but presets now default to the installed templates.
- `scripts/platform_policy.gd` gates Quit/fullscreen in drawing, hit testing and actions. Browser fullscreen requires a user gesture and is never auto-restored; browser audio also waits for a gesture.
- Preserve `include_filter="assets/*.json"` in `export_presets.cfg`: runtime palette metadata must ship with the app.
- The builder exports a ZIP and extracts it to update the runnable Mac app:

```sh
python3 tools/build_release.py --targets macos
open "build/macos/Nugget Cat.app"
```

- Default macOS builds are ad-hoc signed playtests. `build_release.py --targets macos --notarize` uses `release.json`'s Developer ID identity and Keychain profile, with optional `MACOS_SIGNING_IDENTITY` / `NOTARY_KEYCHAIN_PROFILE` overrides. Mac itch deployments require notarization even during `--dry-run`. Apple timeouts are resumable with `deploy_itch.py --resume <build-directory>`; never rebuild just to poll a pending submission. Consult DEPLOYMENT.md for the current submission and retained directory before cleaning builds.
- itch.io: `itch.json` configures `gorbunov/nugget-cat` and `mac`/`windows`/`html5` channels. `python3 tools/deploy_itch.py` explicitly builds, tests and uploads; `--dry-run` suppresses itch.io uploads, and `--targets web` limits the release. Butler is installed locally in `build/butler/`; credentials stay in Butler's own store or `BUTLER_API_KEY`. Each run retains artifacts/logs and a partial-completion receipt under `build/itch/`. See DEPLOYMENT.md for current channel state and setup.
- Cloudflare: `tools/cloudflare/wrangler.jsonc` owns the `cat-nugget.gorbunov.dev` custom domain. Use `npm --prefix tools/cloudflare ci`, then `npm --prefix tools/cloudflare run check` (dry-run) or `run deploy` (publishes). Both invoke the Web build/check pipeline through `tools/prepare_cloudflare.py`. WASM is precompressed under the 25 MiB static-asset limit and served by a small Worker with manual gzip encoding; do not replace this with static Content-Encoding headers, which double-compress the payload. Artifacts stay in `build/cloudflare/`, credentials in Wrangler's store or environment variables.
