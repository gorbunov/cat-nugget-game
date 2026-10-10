# Planned work

Only outstanding work is listed here. Current implementation and decisions are
in [README](README.md); release status and commands are in [Deployment](DEPLOYMENT.md).

## Next release validation

- [ ] Download the Mac build through a browser and verify normal launch, a full
  round, settings/save persistence and replay without a Gatekeeper workaround.
- [ ] Test Windows on a real device: install/extract, start, catch, audio,
  fullscreen, pause, save persistence, replay and exit.
- [ ] Decide whether Windows code signing is needed for the first public release.
- [ ] Verify itch.io embedded play in Safari and Chrome: correct HTML upload,
  click-to-launch, audio after interaction, fullscreen, focus/pause, a full round,
  replay and browser-local saves.
- [ ] Verify initial installation and a subsequent update through the itch.io app.
- [ ] Confirm page visibility, downloadable platform labels, controls, requirements,
  feedback route and version notes. Keep the parent-and-child story, AI disclosure
  and CC0 sound credits on the page before public release.

## Later: browser and release improvements

- [ ] Evaluate compressed music for download size and memory use.
- [ ] Move the proven local release pipeline to explicitly triggered CI; provision
  pinned Godot/templates, Developer ID signing, notarization and Butler credentials.
- [ ] Add release-note retention alongside the existing artifacts and receipts.

Firefox testing is deferred by the owner and is not a first-release blocker.

## Later: tablet controls

- [ ] Prototype drag controls with the mouth offset above the finger.
- [ ] Keep the cat in place on release and ignore extra gameplay touches.
- [ ] Adapt touch targets/instructions and landscape layouts, including 4:3 iPads
  and safe areas; start with letterboxing.
- [ ] Playtest on the owner's iPad in the browser and on Android when available.

## Later: native iPad distribution

- [ ] Configure iOS export, Xcode signing, bundle ID and provisioning.
- [ ] Start with an iPad-only landscape build and test pause/resume, audio
  interruptions, saves and device performance.
- [ ] Prepare App Store Connect information and distribute through TestFlight.
- [ ] Consider TestFlight upload automation after the first successful build.

App Store submission, Android distribution and iPhone support remain optional
milestones after the initial iPad playtest.
