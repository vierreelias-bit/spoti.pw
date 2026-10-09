# EliSpot v30 — original feature implementation plan

**Branch:** `elispot-v30`  
**Development package:** `30.0.0~dev5`  
**Target:** user-built Ubuntu/WSL Theos `.deb` from EliSpot's own sources.

This is a progress tracker, **not** a claim that spoti.pw 0.50.0 code has
been imported. The published 0.50.0 source is under **PolyForm Strict 1.0.0**,
which does not grant redistribution/derivative-work permission.
Any similar features must be independently implemented from functional
requirements or used with separately obtained permission. No copyrighted
0.50.0 source has been transplanted into this branch.

## Implemented in v30 source (not yet compiled/device-tested)

- [x] Start a separate `elispot-v30` branch with v30 development metadata.
- [x] Offer a red accent preset in both Legacy and Redesign appearance menus.
- [x] Provide an appearance **Theme** picker: Spotify default, AMOLED
      black, Apple Music-inspired red, Midnight blue and Violet. Keep the
      independent system color picker for custom accents. Liquid Glass looks
      are only offered on compatible iOS versions.
- [x] Fix the Lyrics Sources row layout overflow by displaying the number
      of selected sources rather than all provider names in the accessory.
- [x] Rename misleading "Lyrics for every track" settings so users know
      that availability depends on selected sources; prevent activating
      it when no source is enabled.
- [x] Add **Test lyrics for current song** diagnostics, calling only the
      user's enabled providers and reporting whether they returned text.
- [ ] Validate fallback lyrics injection on the user's Spotify build:
      provider search success does not necessarily mean the Spotify player
      shows the card; this still needs testing.
- [x] Offer a one-tap **Apple Music-inspired look** preset on supported
      iOS versions. It combines EliSpot's own redesign, red accents, animated
      still artwork and moving field with a restart confirmation.
- [x] Replace the Ubuntu Audio effects unavailable screen with real
      controls wired to the existing speed/pitch audio unit when available,
      plus the existing control haptics and Music Haptics settings.
- [ ] Implement and verify JamesDSP equalizer, bass enhancement, reverb,
      convolver and other actual DSP effects in an Ubuntu build. These are
      **not available in dev4**; the Mac toolchain remains necessary.
- [ ] Support genuine motion-video album artwork with appropriately
      licensed assets; currently only subtle animations of static covers.

- [x] Expose an Albums page in the redesigned settings.
- [x] Add a switch to hide the artist subtitle under redesigned album tracks.
- [x] Add a **Show extra album sections** switch to restore the
      Spotify-provided sections below the track list. The earlier redesign
      omitted these unconditionally.
- [x] Add an **Artists** page with **Hide music videos** control. The old
      redesigned look hid artist video shelves unconditionally.
- [x] Add these new settings to Finnish, Swedish, German, Spanish and French
      UI dictionaries (English fallback).
- [x] Fix the Search browse cards' gradient layer stacking so the intended
      colored categories are no longer placed behind an opaque black card.
- [x] Add optional slowly animated **still** artwork to album hero and player
      cover images, switched from Albums or Player settings.
      Honors Reduce Motion and Low Power Mode and uses no third-party clips.
- [ ] Validate the search gradient and animated covers on an actual iPhone.
- [ ] For genuine video covers, source and play *authorized* animated artwork;
      the current v30 cover motion does not provide video assets.


- [x] Add an optional, manually opened **What's new** page; no automatic prompts.
- [x] Add v30-only language settings: System default, English, Finnish,
      Swedish, German, Spanish and French; translated common EliSpot settings
      labels, notes and value rows with English fallback.
- [ ] Complete the translation coverage of feature-specific controls and
      dialogs in all languages (partial currently); validate on iOS.

- [x] Retain prior Ubuntu SDK compatibility patches and Debian packaging.

## 0.50-era capabilities to audit or implement independently

These are feature goals, **not** claims of completed support. Many require
testing on Spotify 9.1.78 and iOS 26+. Check for existing EliSpot equivalents
first; do not duplicate working hooks.

### Player and controls

- [ ] Tappable progress bar seeking with Spotify's own seek APIs.
- [ ] Hold the artwork edge for temporary faster playback.
- [ ] Playback-speed / pitch-following options, where supported.
- [ ] Player's system-style overflow menu and stable open/close animations.
- [ ] Edge-to-edge redesigned player artwork and consistent gradients.
- [ ] Device picker and background settings on the Player page.
- [ ] Mini player integrated with the navigation bar.
- [ ] Reliable minimized/expanded mini player when list scrolling changes.
- [ ] Option to hide the video-switch control.
- [ ] Consistent player transitions, artwork size, and free-account UI hooks.

### Artwork and lock screen

- [ ] Animated artwork from supported/authorized providers or Spotify Canvas.
- [ ] Fluid artwork motion and blur effects.
- [ ] Animated albums where licensed motion covers exist.
- [ ] Animated artwork behind player controls and synced lyrics.
- [ ] Animated lock-screen art, with a fallback for songs without clips.
- [ ] Lock-screen lyrics and optional animated per-line lyric visuals.
- [ ] Artwork retrieval options in Low Data Mode where supported.
- [ ] Lock-screen widget art/lyrics selector.
- [ ] Correct lock-screen seeking, sizing, and artwork transitions.

### Lyrics and karaoke

- [ ] Expanded full-player lyric display.
- [ ] Scroll-to-hide controls and optional inactivity fading.
- [ ] Landscape lyric presentation with album cover and controls.
- [ ] Tapping artwork restores the player while viewing lyrics.
- [ ] Support local-file lyrics where metadata or timed lyrics are available.
- [ ] User-authorized translations, including optional own-provider API key.
- [ ] Additional licensed lyric sources, where provider terms permit.
- [ ] Lyric display presets, live preview and text customization.
- [ ] Improved word-timing animation, line selection and stability.
- [ ] Karaoke voice control/model integration when compatible and authorized.
- [ ] Karaoke status and controls on the Lyrics page.

### Tabs, settings, albums and artists

- [ ] Add tab flow with label, link and icon.
- [ ] Rename Spotify tabs and choose icon styles.
- [ ] Scroll-up gesture to reveal hidden navigation bars.
- [ ] Redesign album/artist page sections with individual hide switches.
- [ ] Album and playlist attribution pictures where available.
- [ ] Redesigned artist artwork or licensed artist logo when available.
- [ ] Appropriate overflow menus on album, artist and playlist pages.
- [ ] Album cover-based background colouring and page transition fixes.
- [ ] Settings inspired by the system Settings app, with an Account page.
- [ ] App icon options supported by the target iOS version.
- [ ] Global app typography picker.
- [ ] Keep dependent settings visible but disabled with explanation.
- [ ] Better showcases/previews for appearance and player options.

### Sound and accessories

- [ ] Preset management, supported equalization and headphone corrections.
- [ ] Reverb and spatial audio where device frameworks allow.
- [ ] Restore JamesDSP/audio-engine build for supported toolchains.
- [ ] System Music Haptics support where permitted.
- [ ] AirPods motion gestures using compatible public APIs/entitlements.
- [ ] Better controls for AirPods gesture calibration.

### Library, local data and connectivity

- [ ] On-device listening history and import of user-provided Spotify data.
- [ ] Editing metadata on user-owned local music files.
- [ ] Playlist save/download action placement for eligible tracks.
- [ ] Device discovery/Connect compatibility without bypassing permissions.
- [ ] Warnings for conflicting injected tweaks.
- [ ] Non-intrusive Spotify version compatibility status.

### Distribution and platform integration

- [ ] Live Activity support on toolchains with ActivityKit/Swift support.
- [ ] Lock screen / StandBy / Apple Watch / CarPlay integration only via
      permitted APIs and compatible platforms.
- [ ] Legitimate feature licensing only; no bypass of paid entitlements.
- [ ] Optional, manually opened release notes without automatic update dialogs.
- [ ] Remove legacy donation nags and retain license/copyright notices.
- [ ] Continuous performance/compatibility and settings regression review.
- [ ] Reproducible successful Ubuntu `make package` test.
- [ ] Device testing and stability verification on supported iOS/Spotify.

## Deliberate limits

- **Do not override device thermal safety warnings.** Keep the operating
  system's heat protections active, including during karaoke.
- **Do not bypass paywalls, account checks, DRM or subscription entitlements.**
- **Do not copy PolyForm Strict 0.50.0 code into EliSpot** without appropriate
  permission.
- **Do not claim features complete until built and tested.** Mac-only/SDK 26
  features can remain unavailable in the Ubuntu/iOS 16.5 SDK build.

## Development

```sh
cd ~/spoti.pw
git fetch origin
git checkout elispot-v30
git pull --ff-only
cd tweak
make clean
set -o pipefail
make package 2>&1 | tee build.log
```

The user builds this locally; neither a compiled `.deb` nor a successful
device install has yet been verified for v30.
