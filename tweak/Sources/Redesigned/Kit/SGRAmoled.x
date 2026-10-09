// The redesign's AMOLED background, always on: its copy of Native/Appearance/Amoled.x without the switch.
// AMOLED background: Spotify paints its base surface #121212; with the switch on, that grey and
// the gradients fading into it go pure black. Lighter greys stay (#1F1F1F placeholders, #292929
// cards), so elevated surfaces still read against the black.
//
// Trees: #121212 sits on the Home, Search, Library and settings scroll views, on list rows, the
// message bar and the player's bottom gradient view.
#import "Core/SGCore.h"
#import "SGRAccent.h"

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
    NSInteger accent = SGInt(SGRKeyAccent, -1);
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
        %orig;
        return;
    }
    CGColorRef black = copyBlack(color);
    %orig(black);
    CGColorRelease(black);
}
%end

%hook CAGradientLayer
- (void)setColors:(NSArray *)colors {
    NSMutableArray *mapped = [[NSMutableArray alloc] initWithCapacity:colors.count];
    for (id entry in colors) {
        CGColorRef color = (__bridge CGColorRef)entry;
        if (!isBaseGrey(color)) {
            [mapped addObject:entry];
            continue;
        }
        CGColorRef black = copyBlack(color);
        [mapped addObject:(__bridge id)black];
        CGColorRelease(black);
    }
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
            NSInteger accent = SGInt(SGRKeyAccent, -1);
            if (accent == 0xFA233B) sub.backgroundColor = [UIColor colorWithRed:.072 green:.027 blue:.042 alpha:1];
            else if (accent == 0x588BFF) sub.backgroundColor = [UIColor colorWithRed:.026 green:.042 blue:.087 alpha:1];
            else if (accent == 0xAD72F8) sub.backgroundColor = [UIColor colorWithRed:.053 green:.028 blue:.083 alpha:1];
            else sub.backgroundColor = UIColor.blackColor;
        }
    }
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
}
