# EliSpot v30 — original feature implementation plan

**Branch:** `elispot-v30`  
**Development package:** `30.0.0~dev15`  
**Target:** user-built Ubuntu/WSL Theos `.deb` from EliSpot's own sources.

This is a progress tracker, **not** a claim that spoti.pw 0.50.0 code has
been imported. The published 0.50.0 source is under **PolyForm Strict 1.0.0**,
which does not grant redistribution/derivative-work permission.
Any similar features must be independently implemented from functional
requirements or used with separately obtained permission. No copyrighted
0.50.0 source has been transplanted into this branch.

## v30 dev15 changes

- [x] Suppress UIKit's selected-item indicator image and tint in the
      redesigned tab bar (including the newer runtime appearance selectors
      while still building with iOS SDK 16.5).
- [x] Also conceal views explicitly identified as system selection
      indicators, without hiding the actual tab icons or titles.
- [x] Make horizontal swipes **invisible**: do not change the active tab
      visually while dragging, and navigate once to the nearest tab when
      the finger is released. Normal taps still work.
- [ ] The iOS 26+ Liquid Glass internal rendering varies by system
      release; test on an iPhone to verify every selection capsule is
      truly hidden. Ubuntu build has not yet been tested.

## v30 dev14 changes

- [x] Improve the existing **Colours follow song** theme. The active
      Spotify layers and dark gradients are tracked using weak references
      and refreshed when the current song's artwork changes, rather than
      waiting for Spotify to repaint the page.
- [x] Crossfade those colour changes over the shared theme animation
      duration; honor iOS Reduce Motion for immediate colour changes.
- [x] EliSpot's own Settings background gradient follows each new
      artwork colour while the page is open, without covering controls.
- [x] Handle monochrome covers with a neutral silver accent instead of
      keeping the last colour of a previous album.
- [x] Keep existing song-coloured Now Playing glass and system tab tint,
      including invisible swipe-to-change-tabs gesture.
- [ ] **Ubuntu build and iPhone appearance not yet verified.** Check
      performance and contrast across album changes and small devices.

## v30 dev13 changes

- [x] Add a **privacy opt-in automatic album match** for the playing artist
      and album using Apple's documented public iTunes Search API.
      It starts only when "Find album automatically" is switched on.
- [x] Show a status (not searched / searching / found / no match) and open
      the matching album using Apple's official album link.
- [x] Search is rate-limited by a local in-memory cache for each album.
      Strict artist/album matching avoids linking to an unrelated release.
- [x] Translate the new controls into Finnish and their key labels/statuses
      into Swedish, German, Spanish and French.
- [ ] **Apple Music video artwork is NOT automatically downloaded or played
      inside Spotify.** The public catalog result supplies album metadata
      and a link, not permission to reuse Apple's animated video assets.
      The existing import of user-owned/authorized video remains available.
- [ ] Test the public Apple catalog API from the target iPhone and complete
      an Ubuntu Theos build. No device/build success verified for dev13.

## v30 dev12 changes

- [x] **Removed the experimental inline lyrics preview** below the artwork,
      including its file, references, setting and translated labels. The
      regular full lyrics experience remains untouched.
- [x] **Removed the enlarged visual tab slider / lens entirely.** The
      existing horizontal pan gesture and nearest-tab selection on release
      remain; ordinary tab icons and a glass bar remain visible.
- [x] Added **Colours follow song** to Appearance > Theme. The current
      artwork's dominant colour is processed by the existing palette engine
      and used as a bright accent for controls, with dark matching background
      colours on surfaces as they repaint. Now Playing and the tab bar
      re-tint when the song changes; the player artwork field already
      crossfades between album colours.
- [x] Added **real looping animated cover video** from the user's
      own/authorized MP4, MOV or M4V file using the iOS Files picker:
      Now playing > Animated video artwork > Import animated cover.
      The chosen file is associated with the current Spotify song ID.
- [x] Video playback is muted, pauses for a paused song, backgrounding,
      Low Power Mode or Reduce Motion, and falls back to the usual static
      cover if no imported video is found.
- [ ] **No Apple Music animated-video catalog integration**: obtaining
      protected Apple Music motion artwork is not supported or promised;
      the user provides an authorized animation file.
- [ ] Test these modifications with Ubuntu `make package`, on-device
      tab gestures, changing tracks, video import, and memory use.
      The GitHub changes have not yet been build/device-verified.

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
- [x] Give the redesigned mini-player a translucent theme-coloured
      glass film and subtle outline instead of an indistinguishable black card.
- [x] Drag across the redesigned bottom tab bar to preview tabs. On
      release, choose the nearest tab and forward exactly one selection to
      Spotify; ordinary taps and the Home long-press shortcut remain.
- [ ] Verify the tab drag gesture, selection animation and navigation
      interact correctly with the system tab bar on a device.
- [x] Inset and round the actual UIKit tab bar into a capsule while keeping
      Spotify's existing tab hit targets and layout-safe-area measurements.
- [x] Give themed Home, Search, Library and Spotify settings surfaces subtle
      dark red/blue/violet undertones, while Spotify default and AMOLED
      black themes remain intentionally dark.
- [x] Draw a responsive, theme-tinted gradient behind EliSpot's own settings
      pages, without any image files or extra artwork assets.
- [ ] Validate the mini-player contrast, capsule bounds and theme backgrounds
      visually on an actual device. Source edits alone are not a build test.
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
