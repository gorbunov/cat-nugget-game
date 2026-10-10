# Cross-platform release plan

**Status: gameplay polish passed user playtesting on 2026-10-10. Step 1 complete.**
The accepted polish includes the 15-second bouncing boss finale, accelerated bites,
AI-sprite belly-dance reward, and randomized title-screen feeding with spawn sparks.
macOS, Windows and single-threaded Web exports now succeed using installed Godot
4.7.2 templates. Safari and Chrome passed user playtesting on 2026-10-10;
Firefox is deferred by the owner. Next: macOS public-download signing/notarization
(Step 2), Windows device testing (Step 3), and itch.io embedded-browser checks.
Local publishing automation is implemented in `tools/deploy_itch.py`. The owner
created the draft itch.io page and version 0.11.5 was uploaded and processed on
all three channels on 2026-10-10. Embedded play, install/update verification and
native tablet controls remain pending.

## Distribution decision

Use **itch.io as the main public home** for the game: Windows/macOS downloads,
browser play when ready, project background, credits, and links to other platforms.
Use **TestFlight for iPad testing**, then consider the App Store. The owner already
has an Apple developer account; confirm active paid Program membership when
configuring Developer ID signing and TestFlight.

| Platform | Testing | Public distribution |
|---|---|---|
| macOS | Local signed builds | itch.io, Developer ID signed and notarized |
| Windows | Private playtest builds | itch.io |
| Browser | Draft/restricted itch.io page | Embedded browser game on itch.io |
| iPad | TestFlight | App Store, linked from itch.io |
| Android, optional later | APK testing | itch.io APK and/or Google Play |

First public milestone: **one itch.io page with Windows/macOS downloads, plus
browser play if it passes testing.** Native tablet releases should not delay it.

## Step-by-step milestones

### 1. Establish a portable release baseline
- [x] Keep Godot and export templates pinned to matching versions.
- [x] Add Windows and Web export presets alongside macOS.
- [x] Adapt platform-specific behavior: desktop title-screen Esc quits;
  browser/tablet builds use appropriate navigation and omit Quit.
- [x] Expose fullscreen controls only where supported.
- [x] Centralize release versioning and define per-platform output folders.
- [x] Run existing tests and export all three targets.

**Done when:** macOS, Windows and Web export successfully with tests passing.
No publishing credentials are needed for this step.

**Verified 2026-10-10:** imports, smoke checks (including simulated platform
policies), nugget/boss mechanics, audio checks, native fullscreen/settings checks,
all three exports, and macOS signature verification. The local Web server serves
HTML/WASM correctly. Export success is not Windows/browser gameplay validation.

- `release.json` pins game/engine versions; `tools/build_release.py` synchronizes
  version metadata, checks the engine, imports, tests and exports.
- Artifacts: `build/macos/Nugget Cat.zip` plus `.app`,
  `build/windows/Nugget Cat-windows.zip` plus `.exe`, and `build/web/index.html`
  with supporting files. Build logs are in `build/logs/`.
- `python3 tools/serve_web.py` serves the Web build at http://127.0.0.1:8060/.
  Single-threaded Web templates are installed and used; no cross-origin isolation
  headers are required.

### 2. Prepare macOS for public downloads
- [x] Configure Developer ID Application signing, hardened runtime and appropriate
  entitlements using the Apple Developer account.
- [ ] Automate notarization with `notarytool`, then staple the accepted ticket.
- [ ] Package the app for itch.io while preserving its bundle and signature.
- [ ] Test an actual downloaded copy through the normal macOS launch flow.

**Done when:** the downloaded app verifies and launches without a Gatekeeper
workaround. Direct distribution does not require a Mac App Store listing.

**In progress 2026-10-10:** Developer ID signing (team `B5U2KSR3KF`), secure
timestamp and hardened runtime verified. Keychain profile `NuggetCat-notary`
works. `tools/notarize_macos.py` implements submission, resumable status polling,
stapling, validation and repackaging; itch deployments now require these checks.
Initial submission `fd5864c5-a387-45cb-84ad-9b4b5df2b81c` remains **In Progress**
at the last check. Retained build:
`build/itch/0.11.5-20261010T124553910938Z`. Resume with
`python3 tools/deploy_itch.py --resume build/itch/0.11.5-20261010T124553910938Z`.
No notarized replacement has been uploaded yet. Acceptance, ticket/Gatekeeper
checks and an actual browser-download launch remain to be verified.

### 3. Validate Windows
- [ ] Test on a real Windows machine: startup, mouse catches, audio, fullscreen,
  save persistence, replay and exit.
- [ ] Fix platform-specific issues and verify the downloadable package.
- [ ] Decide whether Windows code signing is worthwhile for the first release;
  unsigned downloads may receive SmartScreen warnings.

**Done when:** a tester can download, extract and play complete rounds reliably.

### 4. Create the itch.io page and upload desktop builds
- [x] Start with a draft or restricted page (owner confirmed creation).
- [ ] Add screenshots, description, controls, requirements, feedback route and
  version notes.
- [ ] Include the parent-and-child project story, AI images/music disclosure and
  third-party sound credits from README and `art_sources/reactions.json`.
- [x] Configure Butler and separate macOS/Windows upload channels.
- [ ] Verify both initial installation and a subsequent update.

**Done when:** testers get both desktop builds from one page and can update them.

**Uploaded 2026-10-10:** `gorbunov/nugget-cat`, version **0.11.5**. Butler confirmed
processed builds on `mac` (#2099799), `windows` (#2099807), and `html5` (#2099810).
The local dry run and real pipeline passed import, smoke, nugget and audio checks,
all exports, and macOS signature verification. Browser tagging/page presentation
and actual itch.io play/install/update checks are still pending.

### 5. Make browser play comfortable
- [x] Implement audio start after a user interaction; actual browser autoplay
  behavior remains part of the browser playtests below.
- [ ] Adapt fullscreen, exit/navigation and embedded display sizing.
- [ ] Verify browser-local save persistence and document its limitations.
- [ ] Investigate compressed music to reduce download size and memory use.
- [x] Use a single-threaded Web export with matching installed templates; serve
  via HTTP(S), without cross-origin isolation requirements.
- [x] Safari and Chrome: user reports browser play working (2026-10-10).
- [ ] Verify itch.io embedded play and fullscreen after uploading the build.
- Firefox: deferred by the owner; not a first-release blocker.

The Web loader is branded with Nugget Cat artwork, colors and download progress;
the native boot splash uses the same happy cat. A Chrome startup check verified
the loader reaches the game and removes its overlay. The Sources screen carries
the "Made with Godot" engine credit.

**Done when:** a visitor can click Play on itch.io and finish a round without setup.

### 6. Design and test tablet controls
- [ ] Prototype drag controls with the mouth offset above the finger so food stays
  visible; tune the offset through playtesting.
- [ ] Keep the cat in place on finger release and ignore extra gameplay touches.
- [ ] Increase touch targets and use touch-appropriate instructions.
- [ ] Support landscape tablet proportions, including 4:3 iPads and safe areas;
  start with letterboxing rather than redesigning the canvas.
- [ ] Test on the owner's iPad using the browser build first, and on Android when
  a device is available.

**Done when:** catching feels enjoyable and intentional with touch.

### 7. Ship an iPad TestFlight build
- [ ] Configure the iOS export, Xcode signing, bundle identifier and provisioning.
- [ ] Start with iPad-only landscape support if appropriate; iPhone is optional.
- [ ] Test pause/resume, audio interruptions, saves and performance on device.
- [ ] Prepare required app information and upload to App Store Connect.
- [ ] Distribute via TestFlight; allow for beta review for external testers.

**Done when:** invited testers can install and update through TestFlight.

### 8. Automate releases and publish
- [ ] First prove local release scripts on the Mac; then move the workflow to CI.
- [x] Use an explicit release command or manually triggered workflow initially,
  rather than publishing every commit.
- [ ] Automate import, tests, exports, signing/notarization, packaging and uploads.
- [ ] Retain release artifacts and matching version notes.
- [ ] Optionally automate TestFlight uploads using supported Apple tools or Fastlane.
- [ ] Treat App Store submission and Android support as separate later milestones.

**Done when:** a repeatable, explicitly triggered release produces tested artifacts
and updates the selected distribution channels.

## Publishing automation outline

[itch.io Butler](https://itch.io/docs/butler/) supports incremental uploads and
updates for users of the itch.io app. Configure the project page, platform labels
and browser-play settings separately during initial setup.

The destination and channels are configured in `itch.json` as
`gorbunov/nugget-cat` (`mac`, `windows`, `html5`). The local pipeline builds into a
fresh retained directory, runs import/game/audio checks, exports all selected
targets, then pushes them with Butler and the version from `release.json`:

```sh
build/butler/butler login
python3 tools/deploy_itch.py --dry-run
python3 tools/deploy_itch.py
```

Keep Apple signing material, notarization credentials and Butler tokens outside
the repository, using Keychain locally and secret storage in CI.
Butler login manages its own local credential store. See README's itch.io
deployment section for page settings, partial-upload recovery and runner setup.
Signing/notarization automation is implemented; the first submission is pending
Apple's processing. Hosted CI is not yet implemented.

## Publication context to preserve

The game was made by a parent and child to learn planning, iteration and following
through to a playable result. Carry this story and the AI-generated images/music
disclosure into publication materials. Crowd reactions and gulp sounds are
separately sourced CC0 recordings; retain their references and credits.
