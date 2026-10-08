# EliSpot rebuild

Clean-room EliSpot prototype. This folder does not reuse the spoti.pw tweak implementation.

## Current milestone
- Spotify-only bundle filter
- load diagnostics in Console: `[EliSpot]`
- discovers a tab host at runtime
- replaces visible native `UITabBar` views with a custom dark glass bar
- four tab buttons
- draggable selection lens
- RGB/chromatic ring
- haptic tab changes
- `UIGlassEffect` when available, blur fallback otherwise

## Build

```bash
cd elispot
make clean
rm -rf .theos packages
make package
```

The .deb will be in `packages/`.

## Target
Start with Spotify 9.1.78 while the runtime hooks are being stabilized.

## Important
This is intentionally a separate clean-room implementation. Premium/account/ad bypass features are out of scope.
