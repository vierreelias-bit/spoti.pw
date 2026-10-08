# EliSpot rebuild

Clean-room EliSpot prototype.

## v0.2 runtime change

The old build guessed that Spotify used a normal UITabBarController. This one does not.

Inspection of the supplied 0.50.0 package showed Spotify's real tab UI class names:
- `_TtC23NavigationUI_TabBarImpl10TabBarView`
- `_TtC23NavigationUI_TabBarImpl21TabBarItemElementView`
- `_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView`

EliSpot now discovers those views at runtime, keeps Spotify's real tab bar alive but visually faded, and activates its original item views from the custom glass bar.

## Current milestone

- Spotify-only bundle filter
- `[EliSpot]` load diagnostics
- Spotify-specific tab bar discovery
- custom Liquid Glass bar
- four buttons
- draggable selection lens
- RGB/chromatic ring
- haptics
- original Spotify tab item activation
- `UIGlassEffect` when available, blur fallback otherwise

## Build

```bash
cd elispot
make clean
rm -rf .theos packages
make package
```

The .deb will be in `packages/`.

Start testing against Spotify 9.1.78 while these hooks are stabilized.

Premium/account/ad bypass features are intentionally out of scope.
