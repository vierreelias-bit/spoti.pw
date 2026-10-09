// The redesign's accent colour, chosen apart from the native look's: its copy of Native/Appearance/Accent.x.
// Accent colour: Spotify's green, #1ED760, is one token. Its three components occur once in the
// whole binary, and every green the app draws, from the play button to the "Zobrazit vše" links
// and the progress bar, is that token or a state blended from it. So it is swapped where it is
// born, in the UIColor initialiser, and the blends follow. Lottie animations carry their own green
// and are caught at the layer, below. Image assets with green baked in, the logo above all, are
// out of reach.
#import "Core/SGCore.h"
#import "SGRAccent.h"
#import "Settings/SGPageStyle.h"
#import "SGRBridges.h"
#import "SGRPalette.h"
#import <stdatomic.h>
#import <stdbool.h>

// The greens the app is known to build from literals: the token, and the older brand green the
// upsell backend still names.
static const uint32_t kGreens[] = {0x1ED760, 0x1DB954};

static NSInteger sg_accent = -1;   // 0xRRGGBB once chosen, read at launch
static BOOL sg_songTheme;
static atomic_uint sg_songRGB;        // read by CALayer hooks on background queues
static atomic_bool sg_songReady;     // don't show Spotify green before the first cover arrives
static NSUInteger sg_songGeneration; // rejects palette work for a previous song

// A separate signal lets the tab bar and existing controls redraw when the
// currently playing artwork changes; no Spotify account/media APIs involved.
static NSString *const kSongAccentChanged = @"elispot.songAccentChanged";

// The redesign's own green until another is picked; Spotify's is a pick of its own, stored as -1.
static const NSInteger kDefaultAccent = 0x37F200;
static const uint32_t kWaitingAccent = 0xB5B6C0;

static NSInteger chosen(void) {
    NSInteger rgb = sg_songTheme ? (NSInteger)atomic_load_explicit(&sg_songRGB, memory_order_relaxed)
                                   : SGInt(SGRKeyAccent, kDefaultAccent);
    return rgb >= 0 && rgb <= 0xFFFFFF ? rgb : -1;
}

static void unpack(uint32_t rgb, CGFloat *r, CGFloat *g, CGFloat *b) {
    *r = ((rgb >> 16) & 0xFF) / 255.0;
    *g = ((rgb >> 8) & 0xFF) / 255.0;
    *b = (rgb & 0xFF) / 255.0;
}

NSInteger SGRSongColorRGB(void) {
    return sg_songTheme && atomic_load_explicit(&sg_songReady, memory_order_acquire)
        ? (NSInteger)atomic_load_explicit(&sg_songRGB, memory_order_relaxed) : -1;
}

UIColor *SGRSongFieldColor(void) {
    NSInteger rgb = SGRSongColorRGB();
    if (rgb < 0) return nil;
    CGFloat r, g, b, h = 0, s = 0, v = 0, a = 1;
    unpack((uint32_t)rgb, &r, &g, &b);
    [[UIColor colorWithRed:r green:g blue:b alpha:1] getHue:&h saturation:&s brightness:&v alpha:&a];
    if (s < 0.12) return [UIColor colorWithWhite:0.17 alpha:1];
    // More of the album's hue without sacrificing white label contrast.
    return [UIColor colorWithHue:h saturation:MIN(0.88, MAX(0.62, s)) brightness:0.34 alpha:1];
}

UIColor *SGRAccentColor(void) {
    NSInteger rgb = chosen();
    if (rgb < 0) return nil;
    CGFloat r, g, b;
    unpack((uint32_t)rgb, &r, &g, &b);
    return [UIColor colorWithRed:r green:g blue:b alpha:1];
}

NSString *SGRAccentLabel(void) {
    NSInteger rgb = chosen();
    if (sg_songTheme || SGFlag(SGRKeySongTheme, NO)) return @"Matches song artwork";
    return rgb < 0 ? @"Spotify green" : [NSString stringWithFormat:@"#%06lX", (long)rgb];
}

#pragma mark - picker

@interface SGRAccentPicker : NSObject <UIColorPickerViewControllerDelegate>
@end

@implementation SGRAccentPicker

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [picker.selectedColor getRed:&r green:&g blue:&b alpha:&a];
    uint32_t rgb = ((uint32_t)lround(MIN(1, MAX(0, r)) * 255) << 16)
                 | ((uint32_t)lround(MIN(1, MAX(0, g)) * 255) << 8)
                 | (uint32_t)lround(MIN(1, MAX(0, b)) * 255);
    SGSetInt(SGRKeyAccent, rgb);
}

@end

void SGRPickAccent(void) {
    static SGRAccentPicker *delegate;
    if (!delegate) delegate = [SGRAccentPicker new];
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.supportsAlpha = NO;
    picker.selectedColor = SGRAccentColor() ?: [UIColor colorWithRed:0x1E / 255.0 green:0xD7 / 255.0 blue:0x60 / 255.0 alpha:1];
    picker.delegate = delegate;
    [SGTopController() presentViewController:picker animated:YES completion:nil];
}

// A darker green than the token comes out as the accent darkened by the same amount, so the two
// keep their relation.
static BOOL swap(CGFloat *r, CGFloat *g, CGFloat *b) {
    for (size_t i = 0; i < sizeof(kGreens) / sizeof(kGreens[0]); i++) {
        CGFloat gr, gg, gb;
        unpack(kGreens[i], &gr, &gg, &gb);
        if (fabs(*r - gr) > 0.01 || fabs(*g - gg) > 0.01 || fabs(*b - gb) > 0.01) continue;
        CGFloat ar, ag, ab;
        unpack(sg_songTheme ? atomic_load_explicit(&sg_songRGB, memory_order_relaxed)
                            : (uint32_t)sg_accent, &ar, &ag, &ab);
        CGFloat factor = MAX(gr, MAX(gg, gb)) / (0xD7 / 255.0);
        *r = MIN(1, ar * factor);
        *g = MIN(1, ag * factor);
        *b = MIN(1, ab * factor);
        return YES;
    }
    return NO;
}

%hook UIColor
- (UIColor *)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    swap(&r, &g, &b);
    return %orig(r, g, b, a);
}
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    swap(&r, &g, &b);
    return %orig(r, g, b, a);
}
%end

// Lottie draws its animations, the play indicator and the checkmarks among them, from colours
// in the animation file straight onto shape layers, or into colour keyframes, never through
// UIColor. The same swap goes on the CGColor. Layers get set off the main thread too, so the
// copy is made with CoreGraphics alone; NULL when the colour is not one of the greens.
static CGColorRef swappedCopy(CGColorRef color) {
    if (!color || CFGetTypeID(color) != CGColorGetTypeID() || CGColorGetNumberOfComponents(color) != 4) return NULL;
    const CGFloat *c = CGColorGetComponents(color);
    CGFloat r = c[0], g = c[1], b = c[2];
    if (!swap(&r, &g, &b)) return NULL;
    CGFloat out[] = {r, g, b, c[3]};
    return CGColorCreate(CGColorGetColorSpace(color), out);
}

static id swappedValue(id value) {
    CGColorRef swapped = swappedCopy((__bridge CGColorRef)value);
    if (!swapped) return value;
    id boxed = (__bridge_transfer id)swapped;
    return boxed;
}

%hook CAShapeLayer
- (void)setFillColor:(CGColorRef)color {
    CGColorRef swapped = swappedCopy(color);
    CGColorRef used = swapped ?: color;
    %orig(used);
    if (swapped) CGColorRelease(swapped);
}
- (void)setStrokeColor:(CGColorRef)color {
    CGColorRef swapped = swappedCopy(color);
    CGColorRef used = swapped ?: color;
    %orig(used);
    if (swapped) CGColorRelease(swapped);
}
%end

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    CGColorRef swapped = swappedCopy(color);
    CGColorRef used = swapped ?: color;
    %orig(used);
    if (swapped) CGColorRelease(swapped);
}
%end

%hook CABasicAnimation
- (void)setFromValue:(id)value {
    id used = swappedValue(value);
    %orig(used);
}
- (void)setToValue:(id)value {
    id used = swappedValue(value);
    %orig(used);
}
%end

%hook CAKeyframeAnimation
- (void)setValues:(NSArray *)values {
    NSMutableArray *mapped = nil;
    for (NSUInteger i = 0; i < values.count; i++) {
        id swapped = swappedValue(values[i]);
        if (swapped == values[i] && !mapped) continue;
        if (!mapped) mapped = [values mutableCopy];
        mapped[i] = swapped;
    }
    NSArray *used = mapped ?: values;
    %orig(used);
}
%end

// Let the existing palette engine analyse the artwork off the main thread.
// Monochrome covers get a neutral silver accent rather than incorrectly
// keeping the previous song's bright colour.
static void updateSongAccent(UIImage *image) {
    if (!image || !sg_songTheme) return;
    NSUInteger generation = ++sg_songGeneration;
    SGRPaletteRequest request = {CGSizeZero, NO, YES, YES};
    [SGRPalette paletteForImage:image request:request completion:^(SGRPalette *palette) {
        if (!palette || generation != sg_songGeneration) return;
        UIColor *source = palette.flowColors.lastObject ?: palette.edgeColor;
        CGFloat h = 0, s = 0, v = 0, a = 0;
        BOOL hasHue = [source getHue:&h saturation:&s brightness:&v alpha:&a];
        // Bright enough for a clear accent over Spotify's dark player.
        UIColor *accent = (!hasHue || s < 0.12)
            ? [UIColor colorWithWhite:0.78 alpha:1.0]
            : [UIColor colorWithHue:h saturation:MIN(0.91, MAX(0.55, s))
                         brightness:0.94 alpha:1];
        CGFloat red = 0, green = 0, blue = 0;
        [accent getRed:&red green:&green blue:&blue alpha:&a];
        uint32_t rgb = ((uint32_t)lround(red * 255) << 16) |
                       ((uint32_t)lround(green * 255) << 8) |
                       (uint32_t)lround(blue * 255);
        uint32_t previous = atomic_exchange_explicit(&sg_songRGB, rgb, memory_order_relaxed);
        BOOL wasReady = atomic_exchange_explicit(&sg_songReady, true, memory_order_release);
        if (!wasReady || rgb != previous)
            [NSNotificationCenter.defaultCenter postNotificationName:kSongAccentChanged object:nil];
    }];
}

%ctor {
    if (!SGRedesignedUI()) return;
    sg_songTheme = SGFlag(SGRKeySongTheme, NO);
    atomic_init(&sg_songRGB, kWaitingAccent);
    atomic_init(&sg_songReady, false);
    sg_accent = chosen();
    if (sg_songTheme || sg_accent >= 0) %init;
    if (sg_songTheme) {
        [NSNotificationCenter.defaultCenter addObserverForName:SGRNowPlayingArtworkDidChangeNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                UIImage *image = note.userInfo[@"image"];
                if ([image isKindOfClass:UIImage.class]) updateSongAccent(image);
            }];
        updateSongAccent(SGRNowPlayingArtwork(NULL, NULL));
    }
}
