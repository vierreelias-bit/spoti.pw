@AGENTS.md

# EliSpot rebuild instructions

Work on the clean-room EliSpot project in `elispot/` on branch `elispot-rebuild`.

## Target

- Spotify iOS 9.1.78
- Theos tweak, arm64
- iOS 16+ build target
- iOS 26 Liquid Glass APIs when available, with graceful fallback
- Spotify executable filter
- No Premium, ad-bypass, account-bypass, paywall-bypass, or entitlement spoofing features

## Known-good runtime facts

- EliSpot dylib loads successfully inside Spotify
- Visible diagnostic banner `EliSpot LOADED` has been confirmed on-device
- Spotify tab bar is found successfully
- Runtime class displayed on-device:
  `NavigationUI_TabBarImpl.TabBarView`
- Four stock items are found
- Spotify 9.1.78 tab navigation is driven by tap gesture recognizer target/action behavior rather than a normal public UITabBar API
- Existing runtime code already attempts to forward taps through Spotify's own recognizers

## Current UI problems to fix

1. The custom mini player is only a placeholder and must be replaced with a polished custom glass mini player.
2. Spotify's original mini/Now Playing bar is still visible behind the EliSpot one. Hide only the original mini-player presentation while keeping Spotify playback/state machinery alive.
3. Do not duplicate or replace the full Spotify playback engine. Read state from Spotify and present it in EliSpot.
4. Current custom tab buttons look too heavy and do not resemble Apple Liquid Glass.
5. Selection lens is too large and extends outside the pill.
6. The tab should NOT switch continuously while dragging.
   - During drag: move the glass lens only.
   - On release: snap to nearest tab, fire one haptic, then activate that Spotify tab once.
7. Remove temporary debug banners once the replacement navigation is confirmed stable.

## Desired navigation appearance

- Floating compact pill near the bottom safe area
- Real `UIGlassEffect` on supported systems
- Blur/material fallback on older systems
- Lens diameter around 62–68 pt, always contained visually within the navigation composition
- Thin subtle chromatic/RGB rim, not a large neon circle
- Home, Search, Library, Create
- SF Symbols may be used as a fallback, but prefer a restrained Apple-like appearance
- Active tab should feel magnified/lensed rather than merely scaled
- Smooth spring snap after release
- Haptic only when the final selection changes

## Desired mini player appearance

- Glass floating card above the navigation pill
- Artwork thumbnail on the left
- Real current track title and artist
- Play/pause control reflecting real playback state
- Rounded continuous corners
- Subtle border/highlight and depth
- Avoid an opaque black rectangle
- Hide Spotify's original mini-player visually after EliSpot has a valid replacement

## Implementation rules

- Prefer runtime discovery and resilient class-name matching over brittle one-off assumptions
- Keep Spotify source views alive when their recognizers/state are needed
- Do not globally disable Spotify navigation views before forwarding actions
- Avoid private API assumptions unless already validated for Spotify 9.1.78 in this repository
- Keep warnings clean because the build uses warnings-as-errors in practice
- Add nullability annotations to public Objective-C headers
- Build with:
  ```bash
  cd elispot
  make clean
  rm -rf .theos packages
  make package
  ```
- Package output is in `elispot/packages/`

## Relevant files

- `elispot/Sources/Tweak.x`
- `elispot/Sources/ELRuntime.h`
- `elispot/Sources/ELRuntime.m`
- `elispot/Sources/ELGlassTabBar.h`
- `elispot/Sources/ELGlassTabBar.m`
- `elispot/Sources/ELMiniPlayer.h`
- `elispot/Sources/ELMiniPlayer.m`
- `elispot/Sources/ELPlayerOverlay.h`
- `elispot/Sources/ELPlayerOverlay.m`

## Useful project skills

Before changing the UI, read and follow the relevant project skills under:

- `.claude/skills/liquid-glass`
- `.claude/skills/apple-design`
- `.claude/skills/apple-hig`
- `.claude/skills/animation-vocabulary`
- `.claude/skills/review-animations`

These entries may be symlinks into `.agents/skills/`.

## First task

Start by fixing the bottom navigation interaction and appearance:

- make the selection lens smaller and contained
- do not activate tabs while the finger is moving
- activate the nearest Spotify tab only when the drag ends
- verify button taps still activate the correct stock tab
- keep Spotify's own stock item views alive for their recognizers

Then replace the placeholder mini player and visually suppress Spotify's stock mini player only after the custom one is populated with real playback state.
