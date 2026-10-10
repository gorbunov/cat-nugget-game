# Builds and deployment

`release.json` owns the game/engine versions and public signing configuration.
`itch.json` owns `gorbunov/nugget-cat` and the `mac`, `windows`, `html5` channels.
Releases are explicitly triggered locally; future work is in [Planned work](RELEASE_PLAN.md).

## Current release status

Checked **2026-10-10** against Butler and Apple's notarization service:

| Item | State |
|---|---|
| Game / engine | 0.11.5 / Godot 4.7.2 |
| itch.io `mac` | Processed build #2100342; Developer ID-signed, notarized and stapled |
| itch.io `windows` | Processed build #2099807 |
| itch.io `html5` | Processed build #2099810 |
| Developer ID signature | Verified, with secure timestamp and hardened runtime |
| Apple submission | `fd5864c5-a387-45cb-84ad-9b4b5df2b81c` — **Accepted**; ticket/signature validation and Gatekeeper assessment passed |

The project page exists; public access is not confirmed (an unauthenticated request
returned 404). Embedded play and desktop download/install/update checks are
not yet verified. All three exports and
game/audio checks have passed; Safari and Chrome passed owner browser playtesting.

Retained notarized release directory: `build/itch/0.11.5-20261010T124553910938Z`.
Keep its archives, `build.json`, `macos/notarization.json`, `deployment.json` and logs intact.

```sh
xcrun notarytool info fd5864c5-a387-45cb-84ad-9b4b5df2b81c --keychain-profile NuggetCat-notary
build/butler/butler status gorbunov/nugget-cat:mac
```

## Local builds

Install matching Godot 4.7.2 export templates. Single-threaded Web uses
`web_nothreads_debug.zip` and `web_nothreads_release.zip`; no cross-origin isolation
headers are required. `tools/fetch_template.py` is an optional macOS-template
fallback; presets use installed templates by default.

```sh
python3 tools/build_release.py
python3 tools/build_release.py --targets web
python3 tools/build_release.py --check-version
```

The builder syncs README/project/export versions, verifies the engine, imports,
runs smoke/nugget/audio checks, exports, and packages selected targets. After
editing `release.json`, `--sync-only` updates version metadata without a build.
`--godot` or `GODOT` selects the executable. `--output-dir` selects a directory
inside `build/`; logs and `build.json` are retained there.

| Target | Default output |
|---|---|
| macOS | `build/macos/Nugget Cat.zip` and extracted `Nugget Cat.app` |
| Windows | `build/windows/Nugget Cat.exe` and `Nugget Cat-windows.zip` |
| Web | `build/web/index.html` and supporting files |

Default Mac builds are ad-hoc signed. `include_filter="assets/*.json"` in
`export_presets.cfg` must remain: runtime palette metadata must ship in exports.
Serve Web builds with `python3 tools/serve_web.py`, not `file://`.

## macOS public distribution

This Mac has **Developer ID Application: Oleg Gorbunov (B5U2KSR3KF)** and working
Keychain profile **NuggetCat-notary**. Certificate/private key and credentials
stay in Keychain. `MACOS_SIGNING_IDENTITY` and `NOTARY_KEYCHAIN_PROFILE` override
the configured names. Credential setup on another Mac is interactive:

```sh
xcrun notarytool store-credentials "NuggetCat-notary"
python3 tools/build_release.py --targets macos --notarize
```

`tools/notarize_macos.py` signs with Developer ID, timestamp and hardened runtime,
submits to Apple, and records the submission ID/archive SHA-256. This GDScript-only
game requires no JIT, native plug-in or debugging entitlement exceptions;
`tools/macos_entitlements.plist` is empty.

The tool waits up to ten minutes. Only **Accepted** submissions proceed to ticket
stapling, ticket/signature validation, Gatekeeper assessment and repackaging. The
uploaded ZIP must contain the stapled app. These final steps passed for the
current Mac release.

```sh
xcrun notarytool history --keychain-profile NuggetCat-notary
xcrun notarytool log <submission-id> --keychain-profile NuggetCat-notary
python3 tools/notarize_macos.py build --resume
```

Apple continues processing after a timeout. Resume the original directory rather
than submitting another copy. The archive hash must still match the receipt.
Use a fresh output directory for a new submission after changing the app.

## itch.io uploads

Butler **15.32.0** is installed at `build/butler/butler` (darwin-arm64). On another
machine, install [Butler](https://itch.io/docs/butler/installing.html) there or on
PATH. Authenticate with `build/butler/butler login`; unattended runners can use
`BUTLER_API_KEY` from secret storage. Never put tokens in Git or `itch.json`.

```sh
# Build/test all targets, notarize Mac, then upload.
python3 tools/deploy_itch.py

# Update only Web.
python3 tools/deploy_itch.py --targets web

# Check payloads without itch.io uploads; Mac STILL submits to Apple.
python3 tools/deploy_itch.py --dry-run

# Resume existing artifacts; optionally select remaining targets.
python3 tools/deploy_itch.py --resume build/itch/<version>-<timestamp> --targets web

build/butler/butler status gorbunov/nugget-cat
```

Bump `release.json` for a new release. Fresh builds are retained in
`build/itch/<version>-<UTC timestamp>/`. `build.json` records the tested/exported
version and targets; `deployment.json` records completed uploads for that run.
All selected exports and checks finish before uploads. Mac uploads require an
accepted, stapled, unchanged notarized archive, including during `--dry-run`.

Uploads are sequential, not atomic. If one fails, inspect the receipt and resume
only the remaining targets. `--resume` uses the retained version/artifacts and
does not rebuild; it does not automatically skip previously uploaded targets.
`--butler` / `BUTLER` and `--godot` / `GODOT` override executable paths.

Desktop channels receive ZIP contents; Web receives the whole export directory
with `index.html` at its root. A downloaded copy of the current `html5` upload
confirmed that layout. In the dashboard, use project kind **HTML** and mark only
`html5` as **This file will be played in the browser**. Keep native platform labels
on the desktop uploads. The embed configuration is 960 × 540, click-to-launch,
fullscreen enabled, without SharedArrayBuffer or mobile-friendly flags.

Page visibility and content are managed in the dashboard. Include the project
story, controls, AI disclosure and all three CC0 sound links from README.

### Compact presentation reference

Recorded palette/design choices (live dashboard values have not been audited):

| Role | Game page | Creator profile |
|---|---|---|
| Background | `#2B2332` | `#121F2E` |
| Content | `#403547` | `#243448` |
| Text | `#FFEDBD` | `#F5E8CE` |
| Links | `#EE9AAA` | `#8BD5CA` |
| Headings | `#FFC76B` | `#F2B66D` |
| Buttons | `#A84865` | `#8BD5CA` |

Game-page direction: warm plum/cream/gold, single column, Nunito body and Pixelify
Sans headings. Embed artwork uses muted silhouettes, separator lines and a small
bottom tagline, leaving the launch-button area clear. Creator-profile direction:
“Small Worlds Workshop,” navy/star background and cream/mint accents. Theme
development assets/tooling are outside the maintained game-project scope.
