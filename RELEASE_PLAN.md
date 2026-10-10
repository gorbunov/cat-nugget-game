# Cross-platform release plan

**Status: gameplay polish passed user playtesting on 2026-10-10. Step 1 complete.**
The accepted polish includes the 15-second bouncing boss finale, accelerated bites,
AI-sprite belly-dance reward, and randomized title-screen feeding with spawn sparks.
macOS, Windows and single-threaded Web exports now succeed using installed Godot
4.7.2 templates. Safari and Chrome passed user playtesting on 2026-10-10;
Firefox is deferred by the owner. Next: macOS public-download signing/notarization
(Step 2), Windows device testing (Step 3), and itch.io embedded-browser checks.
Publishing/upload
automation and native tablet controls are still later milestones.

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
- [ ] Configure Developer ID Application signing, hardened runtime and appropriate
  entitlements using the Apple Developer account.
- [ ] Automate notarization with `notarytool`, then staple the accepted ticket.
- [ ] Package the app for itch.io while preserving its bundle and signature.
- [ ] Test an actual downloaded copy through the normal macOS launch flow.

**Done when:** the downloaded app verifies and launches without a Gatekeeper
workaround. Direct distribution does not require a Mac App Store listing.

### 3. Validate Windows
- [ ] Test on a real Windows machine: startup, mouse catches, audio, fullscreen,
  save persistence, replay and exit.
- [ ] Fix platform-specific issues and verify the downloadable package.
- [ ] Decide whether Windows code signing is worthwhile for the first release;
  unsigned downloads may receive SmartScreen warnings.

**Done when:** a tester can download, extract and play complete rounds reliably.

### 4. Create the itch.io page and upload desktop builds
- [ ] Start with a draft or restricted page.
- [ ] Add screenshots, description, controls, requirements, feedback route and
  version notes.
- [ ] Include the parent-and-child project story, AI images/music disclosure and
  third-party sound credits from README and `art_sources/reactions.json`.
- [ ] Configure Butler and separate macOS/Windows upload channels.
- [ ] Verify both initial installation and a subsequent update.

**Done when:** testers get both desktop builds from one page and can update them.

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
- [ ] Use an explicit release command or manually triggered workflow initially,
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

Illustrative commands; replace placeholders after choosing the account, project
slug and artifact layout:

```sh
butler push <mac-build-folder> <account>/nugget-cat:mac --userversion <version>
butler push <windows-build-folder> <account>/nugget-cat:windows --userversion <version>
butler push <web-build-folder> <account>/nugget-cat:html5 --userversion <version>
```

Keep Apple signing material, notarization credentials and Butler tokens outside
the repository, using Keychain locally and secret storage in CI.

## Publication context to preserve

The game was made by a parent and child to learn planning, iteration and following
through to a playable result. Carry this story and the AI-generated images/music
disclosure into publication materials. Crowd reactions and gulp sounds are
separately sourced CC0 recordings; retain their references and credits.
