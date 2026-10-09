// The redesign's AMOLED background, always on: its copy of Native/Appearance/Amoled.x without the switch.
// AMOLED background: Spotify paints its base surface #121212; with the switch on, that grey and
// the gradients fading into it go pure black. Lighter greys stay (#1F1F1F placeholders, #292929
// cards), so elevated surfaces still read against the black.
//
// Trees: #121212 sits on the Home, Search, Library and settings scroll views, on list rows, the
// message bar and the player's bottom gradient view.
#import "Core/SGCore.h"
#import "SGRAccent.h"

// Keep weak references only to Spotify surfaces we recolour. On a song
// change, replay the *original* #121212 paint through our existing hook.
// Without this, a previously tinted layer stays on the previous song's
// colour until Spotify happens to redraw it.
static NSObject *trackingLock(void) {
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSObject new]; });
    return lock;
}

static NSMapTable<CALayer *, id> *surfaceSeeds(void) {
    static NSMapTable<CALayer *, id> *seeds;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seeds = [NSMapTable weakToStrongObjectsMapTable]; });
    return seeds;
}

static NSMapTable<CAGradientLayer *, NSArray *> *gradientSeeds(void) {
    static NSMapTable<CAGradientLayer *, NSArray *> *seeds;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seeds = [NSMapTable weakToStrongObjectsMapTable]; });
    return seeds;
}

static void rememberSurface(CALayer *layer, CGColorRef original) {
    if (SGRSongColorRGB() < 0) return;
    @synchronized (trackingLock()) {
        [surfaceSeeds() setObject:(__bridge id)original forKey:layer];
    }
}

static void rememberGradient(CAGradientLayer *layer, NSArray *original, BOOL tinted) {
    if (SGRSongColorRGB() < 0) return;
    @synchronized (trackingLock()) {
        if (tinted) [gradientSeeds() setObject:original forKey:layer];
        else [gradientSeeds() removeObjectForKey:layer];
    }
}

static void refreshSongSurfaces(void) {
    NSArray<CALayer *> *layers;
    NSMutableArray *originals;
    NSArray<CAGradientLayer *> *gradients;
    NSMutableArray *gradientColours;
    @synchronized (trackingLock()) {
        layers = surfaceSeeds().keyEnumerator.allObjects;
        originals = [NSMutableArray arrayWithCapacity:layers.count];
        for (CALayer *layer in layers) {
            id original = [surfaceSeeds() objectForKey:layer];
            [originals addObject:original ?: NSNull.null];
        }
        gradients = gradientSeeds().keyEnumerator.allObjects;
        gradientColours = [NSMutableArray arrayWithCapacity:gradients.count];
        for (CAGradientLayer *gradient in gradients) {
            [gradientColours addObject:[gradientSeeds() objectForKey:gradient] ?: NSNull.null];
        }
    }
    // Calls the hooks below again, but does not recurse into this notification.
    for (NSUInteger i = 0; i < layers.count; i++) {
        if (originals[i] != NSNull.null)
            layers[i].backgroundColor = (__bridge CGColorRef)originals[i];
    }
    for (NSUInteger i = 0; i < gradients.count; i++) {
        if (gradientColours[i] != NSNull.null)
            gradients[i].colors = gradientColours[i];
    }
}

// Neutral and darker than #1A1A1A, but not already black.
static BOOL isBaseGrey(CGColorRef color) {
    if (!color || CFGetTypeID(color) != CGColorGetTypeID()) return NO;
    const CGFloat *c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    if (n == 2) return c[0] > 0.01 && c[0] <= 0.10;
    if (n < 3) return NO;
    return c[0] > 0.01 && c[0] <= 0.10 && fabs(c[0] - c[1]) < 0.02 && fabs(c[1] - c[2]) < 0.02;
}

// Keep the original AMOLED black for Spotify's default look, but give the
// selected red/blue/violet theme a *dark* tint instead of removing all colour
// from the Home, Search and Library surfaces. The value is fixed at launch,
// the same time redesign hooks are chosen. CoreGraphics owns the returned
// colour so this remains safe inside background-thread CALayer setters.
static CGColorRef copyBlack(CGColorRef color) {
    CGFloat alpha = CGColorGetAlpha(color);
    // In adaptive theme mode, the background colour updates as Spotify
    // repaints its surfaces; the player artwork field already crossfades on
    // every song without requiring a new view.
    NSInteger accent = SGRSongColorRGB();
    if (accent >= 0) {
        CGFloat red = ((accent >> 16) & 255) / 255.0;
        CGFloat green = ((accent >> 8) & 255) / 255.0;
        CGFloat blue = (accent & 255) / 255.0;
        return CGColorCreateGenericRGB(0.010 + red * 0.105,
                                       0.010 + green * 0.105,
                                       0.015 + blue * 0.105, alpha);
    }
    accent = SGInt(SGRKeyAccent, -1);
    switch (accent) {
        case 0xFA233B: return CGColorCreateGenericRGB(0.072, 0.027, 0.042, alpha);
        case 0x588BFF: return CGColorCreateGenericRGB(0.026, 0.042, 0.087, alpha);
        case 0xAD72F8: return CGColorCreateGenericRGB(0.053, 0.028, 0.083, alpha);
        default: return CGColorCreateGenericGray(0, alpha);
    }
}

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (!isBaseGrey(color)) {
        if (SGRSongColorRGB() >= 0) {
            @synchronized (trackingLock()) { [surfaceSeeds() removeObjectForKey:(CALayer *)self]; }
        }
        %orig;
        return;
    }
    rememberSurface((CALayer *)self, color);
    CGColorRef black = copyBlack(color);
    %orig(black);
    CGColorRelease(black);
}
%end

%hook CAGradientLayer
- (void)setColors:(NSArray *)colors {
    NSMutableArray *mapped = [[NSMutableArray alloc] initWithCapacity:colors.count];
    BOOL hasBaseGrey = NO;
    for (id entry in colors) {
        CGColorRef color = (__bridge CGColorRef)entry;
        if (!isBaseGrey(color)) {
            [mapped addObject:entry];
            continue;
        }
        hasBaseGrey = YES;
        CGColorRef black = copyBlack(color);
        [mapped addObject:(__bridge id)black];
        CGColorRelease(black);
    }
    rememberGradient((CAGradientLayer *)self, colors, hasBaseGrey);
    %orig(colors ? mapped : nil);
}
%end

// Spotify's settings list paints nothing of its own and shows whatever sits under it, which is not
// the base grey the hooks above turn black. The list is the top surface, so it takes the black.
%hook _TtC21Settings_PlatformImpl26SettingsListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    for (UIView *sub in ((UIViewController *)self).view.subviews) {
        if ([sub isKindOfClass:UICollectionView.class]) {
            // Avoid a pure black slab inside themed Spotify Settings pages.
            NSInteger accent = SGRSongColorRGB();
            if (accent >= 0) {
                CGFloat red = ((accent >> 16) & 255) / 255.0;
                CGFloat green = ((accent >> 8) & 255) / 255.0;
                CGFloat blue = (accent & 255) / 255.0;
                sub.backgroundColor = [UIColor colorWithRed:0.010 + red * 0.105
                                                    green:0.010 + green * 0.105
                                                     blue:0.015 + blue * 0.105 alpha:1];
            } else {
                accent = SGInt(SGRKeyAccent, -1);
                if (accent == 0xFA233B) sub.backgroundColor = [UIColor colorWithRed:.072 green:.027 blue:.042 alpha:1];
            else if (accent == 0x588BFF) sub.backgroundColor = [UIColor colorWithRed:.026 green:.042 blue:.087 alpha:1];
            else if (accent == 0xAD72F8) sub.backgroundColor = [UIColor colorWithRed:.053 green:.028 blue:.083 alpha:1];
                else sub.backgroundColor = UIColor.blackColor;
            }
        }
    }
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    if (SGFlag(SGRKeySongTheme, NO)) {
        [NSNotificationCenter.defaultCenter addObserverForName:@"elispot.songAccentChanged"
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                refreshSongSurfaces();
            }];
    }
}
