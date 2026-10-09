// Tab bar: Spotify's own bar stays where it is but goes invisible, and a system UITabBar sits on top
// of it. The glass *bar* remains, but the selected-item sliding glass
// indicator is deliberately removed. Gestures still pick the nearest tab
// on release without any visual preview moving under the finger. Spotify's bar keeps
// its frame, so the page insets and the now playing bar stay where Spotify puts them; where the system
// bar is taller than Spotify's, Spotify is made to leave it the room (see "room for the glass bar").
//
// A tab picked on the system bar is passed on as a tap on the hidden Spotify item it mirrors, and the
// system bar's selection follows whichever Spotify label is painted white. Navbar.x composes the
// hidden row, so its order, hidden tabs and tabs of the mod's own carry over. Always on in the redesign.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > UIStackView of
//   ElementContentView<TabBarItemElement>, each with an SPTEncoreIconView and an SPTEncoreLabel.
#import "Core/SGCore.h"
#import "Navbar.h"
#import "Redesigned/Kit/SGRTokens.h"
#import "Settings/SGPage.h"
#import "Headers/SPTEncoreIconView.h"
#import <objc/message.h>
#import <math.h>

static char kBarKey, kHostKey;
static __weak UIView *sg_stockBar;
static CGFloat sg_room, sg_glassHeight;   // see "room for the glass bar"

@interface SGRSystemTabBar : UITabBar <UITabBarDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *stockBar;
@property (nonatomic, copy) NSArray<UIView *> *sources;
@property (nonatomic, weak) UILongPressGestureRecognizer *hold;
@property (nonatomic, weak) UIPanGestureRecognizer *slide;
@property (nonatomic) BOOL holding;
@property (nonatomic) BOOL sliding;
@end

static void syncBar(UIView *stockBar);

#pragma mark - reading Spotify's items

// The items the bar shows, left to right as Navbar/Navbar.x placed them.
static NSArray<UIView *> *tabItems(UIView *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    for (UIView *item in SGRowIn(tabBar).arrangedSubviews) {
        if (!item.hidden && item.bounds.size.width >= 20) [items addObject:item];
    }
    return [items sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return [@(SGFrameIn(a, tabBar).origin.x) compare:@(SGFrameIn(b, tabBar).origin.x)];
    }];
}

// Navbar.x never reorders Spotify's row and appends the mod's own tabs after it, so Home stays first.
static BOOL isHome(UIView *item, UIView *tabBar) {
    return item && item == SGRowIn(tabBar).arrangedSubviews.firstObject;
}

static UILabel *labelIn(UIView *item) {
    __block UILabel *label = nil;
    SGForEachView(item, ^(UIView *v) {
        if (!label && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) label = (UILabel *)v;
    });
    return label;
}

static UIView *iconIn(UIView *item) {
    __block UIView *icon = nil;
    SGForEachView(item, ^(UIView *v) {
        if (icon || v.bounds.size.width < 2) return;
        if ([v isKindOfClass:UIImageView.class] || [NSStringFromClass(v.class) containsString:@"IconView"]) icon = v;
    });
    return icon;
}

// Spotify paints the selected tab's label white and the rest #B3B3B3.
static BOOL isActive(UIView *item) {
    UIColor *color = labelIn(item).textColor;
    CGFloat white = 0, alpha = 0, r, g, b;
    if (![color getWhite:&white alpha:&alpha] && [color getRed:&r green:&g blue:&b alpha:&alpha]) white = MIN(r, MIN(g, b));
    return white > 0.95;
}

static BOOL hasInk(UIImage *image) {
    CGImageRef cg = image.CGImage;
    size_t width = CGImageGetWidth(cg), height = CGImageGetHeight(cg);
    if (!width || !height) return NO;
    NSMutableData *pixels = [NSMutableData dataWithLength:width * height];
    CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cg);
    CGContextRelease(context);
    const uint8_t *alpha = pixels.bytes;
    for (size_t i = 0; i < pixels.length; i++) if (alpha[i] > 16) return YES;
    return NO;
}

static UIImage *renderLayer(CALayer *layer, CGSize size) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [layer renderInContext:context.CGContext];
    }];
    return hasInk(image) ? [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
}

// The SPTEncoreIcon an icon view was built with. Encore keeps it in a Swift ivar with no getter.
static id encoreIconOf(UIView *view) {
    Ivar ivar = class_getInstanceVariable(view.class, "icon");
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    return type && type[0] == '@' ? object_getIvar(view, ivar) : nil;
}

// Encore draws a tab's icon from one SPTEncoreIcon in two states: isActive picks its filled variant.
// Both are drawn on an icon view of our own, off screen, so the images do not wait for Spotify's
// views to lay out and paint, and UITabBar swaps image and selectedImage itself.
static UIImage *glyphOf(UIView *item, BOOL active) {
    UIView *live = iconIn(item);
    if (!live) return nil;
    CGSize size = live.bounds.size;
    id icon = encoreIconOf(live);
    Class viewClass = NSClassFromString(@"SPTEncoreIconView");
    if (icon && viewClass) {
        static NSCache<NSString *, UIImage *> *cache;
        if (!cache) cache = [NSCache new];
        NSString *key = [NSString stringWithFormat:@"%@ %d %@", [icon respondsToSelector:@selector(name)] ? [icon name] : icon, active, NSStringFromCGSize(size)];
        UIImage *cached = [cache objectForKey:key];
        if (cached) return cached;
        SPTEncoreIconView *view = [[viewClass alloc] initWithIcon:icon];
        view.frame = (CGRect){CGPointZero, size};
        [view setForegroundColor:UIColor.whiteColor];
        if ([view respondsToSelector:@selector(setActiveForegroundColor:)]) [view setActiveForegroundColor:UIColor.whiteColor];
        if ([view respondsToSelector:@selector(setIsActive:)]) [view setIsActive:active];
        [view layoutIfNeeded];
        UIImage *image = renderLayer(view.layer, size);
        if (image) {
            [cache setObject:image forKey:key];
            return image;
        }
    }
    // Tabs of the mod's own draw a UIImageView, or an icon Encore would not draw off screen.
    return size.width >= 2 ? renderLayer(live.layer, size) : nil;
}

#pragma mark - passing a tap on

// NavigationUI_TabBarImpl's TabBarItemElementUI answers a tap recognizer (-handleTap), so the tap is
// replayed through the recognizer's own target-action pairs, the same call a real touch ends in.
static BOOL fireTapRecognizers(UIView *view) {
    Ivar targetsIvar = class_getInstanceVariable(UIGestureRecognizer.class, "_targets");
    if (!targetsIvar) return NO;
    BOOL fired = NO;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if (![recognizer isKindOfClass:UITapGestureRecognizer.class] || !recognizer.enabled) continue;
        for (id pair in object_getIvar(recognizer, targetsIvar)) {
            Ivar targetIvar = class_getInstanceVariable([pair class], "_target");
            Ivar actionIvar = class_getInstanceVariable([pair class], "_action");
            if (!targetIvar || !actionIvar) continue;
            id target = object_getIvar(pair, targetIvar);
            SEL action = *(SEL *)((char *)(__bridge void *)pair + ivar_getOffset(actionIvar));
            if (!target || !action || ![target respondsToSelector:action]) continue;
            SGLog(@"tab bar: tap -> %@ %@", NSStringFromClass([target class]), NSStringFromSelector(action));
            ((void (*)(id, SEL, id))objc_msgSend)(target, action, recognizer);
            fired = YES;
        }
    }
    return fired;
}

static void forwardTap(UIView *item) {
    __block BOOL sent = NO;
    SGForEachView(item, ^(UIView *v) {
        if (!sent) sent = fireTapRecognizers(v);
    });
    SGForEachView(item, ^(UIView *v) {
        if (sent || ![v isKindOfClass:UIControl.class]) return;
        SGLog(@"tab bar: tap -> control %@", NSStringFromClass(v.class));
        [(UIControl *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
        sent = YES;
    });
    if (!sent) {
        NSMutableString *out = [NSMutableString stringWithFormat:@"tab bar: nothing to tap in %@", NSStringFromClass(item.class)];
        SGForEachView(item, ^(UIView *v) {
            for (UIGestureRecognizer *r in v.gestureRecognizers) [out appendFormat:@"\n  %@ on %@", r, NSStringFromClass(v.class)];
        });
        SGLogLong(@"navbar", out);
    }
}

// An explicit transparent indicator is more reliable than the system's nil
// default, which can make UIKit draw its own moving selection pill.
static UIImage *noSelectionIndicator(void) {
    static UIImage *blank;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(2, 2)];
        blank = [[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {}]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return blank;
}

static void suppressSelectionBubble(UITabBar *bar) {
    // iOS 26 can draw its Liquid Glass selection with a separate view rather
    // than UITabBarAppearance's indicator image. Only suppress views explicitly
    // identified by UIKit as selection indicators; never hide icons or labels.
    SGForEachView(bar, ^(UIView *view) {
        if (view == bar) return;
        NSString *cls = NSStringFromClass(view.class);
        BOOL indicator = [cls rangeOfString:@"SelectionIndicator"
                                   options:NSCaseInsensitiveSearch].location != NSNotFound ||
                         [cls rangeOfString:@"SelectionHighlight"
                                   options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (indicator) {
            view.hidden = YES;
            view.userInteractionEnabled = NO;
        }
    });
}

#pragma mark - the system bar

@implementation SGRSystemTabBar

- (void)layoutSubviews {
    [super layoutSubviews];
    suppressSelectionBubble(self);
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    // A drag previews different tabs but must only navigate once on release.
    if (self.sliding) return;
    NSUInteger index = [self.items indexOfObject:item];
    if (index == NSNotFound || index >= self.sources.count) return;
    // Home tapped while on Home pops Spotify's stack, which would take Mod Settings straight off it.
    if (!self.holding) forwardTap(self.sources[index]);
    // Spotify repaints its labels a moment later; a tap it did not take snaps the selection back.
    UIView *stockBar = self.stockBar;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (stockBar) syncBar(stockBar);
    });
}

// UIKit's item views are private, so the item under a touch is the one whose title label or glyph is
// nearest. With the labels hidden only the glyph is left; UIKit shows the item's own image instance.
- (UITabBarItem *)itemAt:(CGPoint)point {
    __block UITabBarItem *nearest = nil;
    __block CGFloat best = CGFLOAT_MAX;
    SGForEachView(self, ^(UIView *v) {
        BOOL label = [v isKindOfClass:UILabel.class], glyph = [v isKindOfClass:UIImageView.class];
        if ((!label && !glyph) || v.bounds.size.width < 1) return;
        CGFloat distance = fabs([v convertPoint:CGPointMake(CGRectGetMidX(v.bounds), 0) toView:self].x - point.x);
        if (distance >= best) return;
        for (UITabBarItem *item in self.items) {
            UIImage *image = glyph ? ((UIImageView *)v).image : nil;
            if (label ? ![((UILabel *)v).text isEqualToString:item.title] : !image || (image != item.image && image != item.selectedImage)) continue;
            best = distance;
            nearest = item;
            break;
        }
    });
    return nearest;
}

// A horizontal swipe previews the nearest tab; on release the selection
// snaps to that tab and sends a single tap through Spotify's existing router.
// Normal taps and the long-press-on-Home shortcut keep their own behavior.
- (NSUInteger)nearestTabAtPoint:(CGPoint)point {
    NSUInteger count = MIN(self.items.count, self.sources.count);
    CGFloat width = CGRectGetWidth(self.bounds);
    if (!count || width <= 0) return NSNotFound;
    CGFloat x = fmax(0, fmin(point.x, width - 0.01));
    return MIN(count - 1, (NSUInteger)floor(x * count / width));
}

- (void)slid:(UIPanGestureRecognizer *)slide {
    UIGestureRecognizerState state = slide.state;
    if (state == UIGestureRecognizerStateBegan && !self.holding) self.sliding = YES;
    if (!self.sliding) return;
    // Do not preview the tab while the finger moves. The swipe is completely
    // invisible: it changes neither selectedItem nor any decoration until
    // the release, when the nearest item receives one real Spotify tap.
    if (state == UIGestureRecognizerStateEnded) {
        NSUInteger index = [self nearestTabAtPoint:[slide locationInView:self]];
        self.sliding = NO;
        if (index != NSNotFound) {
            UITabBarItem *target = self.items[index];
            if (self.selectedItem != target) self.selectedItem = target;
            suppressSelectionBubble(self);
            forwardTap(self.sources[index]);
            UIView *stockBar = self.stockBar;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (stockBar) syncBar(stockBar);
            });
            return;
        }
    }
    if (state == UIGestureRecognizerStateCancelled || state == UIGestureRecognizerStateFailed ||
        state == UIGestureRecognizerStateEnded) {
        self.sliding = NO;
        UIView *stockBar = self.stockBar;
        if (stockBar) syncBar(stockBar);
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if (recognizer == self.slide) {
        CGPoint delta = [(UIPanGestureRecognizer *)recognizer translationInView:self];
        // Don't steal vertical page scrolling or taps from the tab bar.
        return self.sources.count > 1 && !self.holding &&
               fabs(delta.x) > fabs(delta.y) * 1.25;
    }
    if (recognizer == self.hold) {
        NSUInteger index = [self.items indexOfObject:[self itemAt:[recognizer locationInView:self]]];
        return index < self.sources.count && !self.sliding &&
               isHome(self.sources[index], self.stockBar);
    }
    return [super gestureRecognizerShouldBegin:recognizer];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    // The pan cancels UITabBar's touch-up selection so a drag can't trigger
    // both a regular tap and its final snapped choice.
    if (recognizer == self.slide || other == self.slide) return NO;
    return YES;
}

- (void)held:(UILongPressGestureRecognizer *)hold {
    if (hold.state == UIGestureRecognizerStateBegan) {
        self.holding = YES;
        SGOpenModSettings(self);
    } else if (hold.state != UIGestureRecognizerStateChanged) {
        // The bar may still pick Home as the finger lifts, after this.
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            weakSelf.holding = NO;
        });
    }
}

@end

// The system bar's own view in Spotify's bar. UIKit measures the system bar and lays it out by the safe
// area of the view it stands in, and the room made under Spotify's bar is not the phone's: on a phone
// with a home button it went under the platter as well, squeezing it to 49 pt. So this view hands the
// bar the safe area without the room.
@interface SGRTabBarHost : UIView
@end

@implementation SGRTabBarHost
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets insets = [super safeAreaInsets];
    insets.bottom = MAX(0, insets.bottom - sg_room);
    return insets;
}
@end

@interface SGRHomeHold : UILongPressGestureRecognizer
@end

@implementation SGRHomeHold
+ (void)held:(SGRHomeHold *)hold {
    if (hold.state == UIGestureRecognizerStateBegan) SGOpenModSettings(hold.view);
}
@end

// On Spotify's own bar a hold that begins fails the item's tap recognizer, so Home is not tapped too.
static void holdHome(UIView *stockBar) {
    UIView *home = SGRowIn(stockBar).arrangedSubviews.firstObject;
    if (!home) return;
    for (UIGestureRecognizer *recognizer in home.gestureRecognizers) {
        if ([recognizer isKindOfClass:SGRHomeHold.class]) return;
    }
    [home addGestureRecognizer:[[SGRHomeHold alloc] initWithTarget:SGRHomeHold.class action:@selector(held:)]];
}

static void logBarOnce(UITabBar *bar) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SGLogLong(@"navbar", [NSString stringWithFormat:@"system tab bar %@\n%@", NSStringFromCGRect(bar.superview.frame), [bar recursiveDescription]]);
        });
    });
}

#pragma mark - room for the glass bar

// UIKit's glass bar asks for 83 pt, the platter the top 62 of it, over no more safe area than a Face ID
// phone's 34 (simulator, iOS 26.5 and 27). Spotify's bar is its 49 pt row over the bottom safe area of
// TabBarContainerImpl's view: a guide from 49 pt above the safe area's bottom to the view's bottom sets
// its height (its viewDidLoad, 0x100840a2c), the now playing bar stands on that guide's top
// (MainUIContainer's chrome bottom anchor, 0x100ae0178), the bar slides away by the inset plus 49 when
// Spotify hides it (0x1037169a4) and the pages get 49 on top of the inset (0x10707bde4). A Face ID
// phone gives the view 34 and the two bars match. A phone with a home button gives it none, and so does
// Spotify's message bar (LimitedExperienceIndicatorBar: Offline, Private Session) coming in under the
// tab bar, which takes the home indicator's inset for itself: the glass bar stood 34 pt above
// Spotify's, over the now playing bar. So the view gets the rest of the glass bar's height as safe
// area, and Spotify lays its bar, the now playing bar, the pages and the hide out for the glass bar
// itself, and moves them all with the message bar.
static const CGFloat kStockRow = 49;

// UIKit asks for 62 + max(21, inset) on a phone with a home button, max(83, 49 + inset) on a Face ID
// phone, by the safe area of the view the bar stands in. SGRTabBarHost keeps the room out of that; if
// it ever reached the bar again, the bar would ask for more room every pass, so what it asks for with
// no room made is what is kept.
static CGFloat glassHeight(UITabBar *bar, UIView *stockBar) {
    if (sg_room < 0.5 || sg_glassHeight <= 0) sg_glassHeight = [bar sizeThatFits:CGSizeMake(stockBar.bounds.size.width, kStockRow)].height;
    return sg_glassHeight;
}

static UIViewController *containerOf(UIView *stockBar) {
    Class containerClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl19TabBarContainerImpl");
    for (UIResponder *r = stockBar.nextResponder; r; r = r.nextResponder) {
        if ([r isKindOfClass:containerClass]) return (UIViewController *)r;
    }
    return nil;
}

static void makeRoom(UIViewController *container) {
    UIView *stockBar = sg_stockBar;
    UITabBar *bar = stockBar ? objc_getAssociatedObject(stockBar, &kBarKey) : nil;
    if (!bar.window || !container.isViewLoaded || ![stockBar isDescendantOfView:container.view]) return;
    UIEdgeInsets extra = container.additionalSafeAreaInsets;
    CGFloat inset = container.view.safeAreaInsets.bottom - extra.bottom;
    CGFloat height = glassHeight(bar, stockBar);
    // Spotify's regular width bar is a fixed 76 pt that ignores the inset.
    BOOL compact = container.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    CGFloat room = compact ? MAX(0, ceil(height - kStockRow - inset)) : 0;
    if (fabs(extra.bottom - room) < 0.5) return;
    sg_room = extra.bottom = room;
    container.additionalSafeAreaInsets = extra;
    SGLog(@"tab bar: %.0f pt of room made under Spotify's bar for the glass bar's %.0f, over an inset of %.0f", room, height, inset);
}

static void syncBar(UIView *stockBar) {
    sg_stockBar = stockBar;

    SGRSystemTabBar *bar = objc_getAssociatedObject(stockBar, &kBarKey);
    if (!bar) {
        bar = [[SGRSystemTabBar alloc] initWithFrame:stockBar.bounds];
        // UIKit draws the glass in the appearance the bar inherits, and the bar is outside the navigation
        // stacks Spotify makes dark itself (-[SPNavigationController viewDidLoad] while +[SPTLiquidGlass
        // isEnabled]), so a phone in light mode had it light over Spotify's black. Spotify is dark whatever
        // the system is, and so is the bar.
        bar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        bar.delegate = bar;
        // Suppress UIKit's built-in selection background, not the actual
        // selected icon/title. Preserve the system glass behind all tabs.
        UIImage *blank = noSelectionIndicator();
        UITabBarAppearance *appearance = [bar.standardAppearance copy];
        if (!appearance) appearance = [UITabBarAppearance new];
        // These UITabBarAppearance selectors are new on recent iOS; call
        // them conditionally so the Ubuntu iOS 16.5 SDK can still compile.
        SEL setImage = NSSelectorFromString(@"setSelectionIndicatorImage:");
        SEL setTint = NSSelectorFromString(@"setSelectionIndicatorTintColor:");
        if ([appearance respondsToSelector:setImage])
            ((void (*)(id, SEL, UIImage *))objc_msgSend)(appearance, setImage, blank);
        if ([appearance respondsToSelector:setTint])
            ((void (*)(id, SEL, UIColor *))objc_msgSend)(appearance, setTint, UIColor.clearColor);
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = [appearance copy];
        bar.selectionIndicatorImage = blank;
        bar.stockBar = stockBar;
        UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:bar action:@selector(held:)];
        hold.delegate = bar;
        [bar addGestureRecognizer:hold];
        bar.hold = hold;
        UIPanGestureRecognizer *slide = [[UIPanGestureRecognizer alloc]
            initWithTarget:bar action:@selector(slid:)];
        slide.delegate = bar;
        slide.maximumNumberOfTouches = 1;
        slide.cancelsTouchesInView = YES;
        [bar addGestureRecognizer:slide];
        bar.slide = slide;
        objc_setAssociatedObject(stockBar, &kBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGRTabBarHost *host = [SGRTabBarHost new];
        [host addSubview:bar];
        objc_setAssociatedObject(stockBar, &kHostKey, host, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    bar.tintColor = SGRAccent();
    UIView *host = objc_getAssociatedObject(stockBar, &kHostKey);

    for (UIView *sub in stockBar.subviews) {
        if (sub == host) continue;
        sub.alpha = 0;
        sub.userInteractionEnabled = NO;
    }
    stockBar.superview.layer.backgroundColor = NULL;

    NSArray<UIView *> *sources = tabItems(stockBar);
    if (!sources.count) return;
    // An item with no title is drawn by UIKit as its glyph alone, centred, on a bar of the same height.
    BOOL hideLabels = SGHidden(SGRKeyNavbarHideLabels);

    if (![sources isEqualToArray:bar.sources]) {
        NSMutableArray<UITabBarItem *> *items = [NSMutableArray array];
        for (UIView *source in sources) [items addObject:[[UITabBarItem alloc] initWithTitle:hideLabels ? nil : labelIn(source).text image:nil tag:items.count]];
        bar.sources = sources;
        [bar setItems:items animated:NO];
        NSMutableString *out = [NSMutableString stringWithString:@"tab bar icons"];
        for (UIView *source in sources) {
            UIView *live = iconIn(source);
            id icon = live ? encoreIconOf(live) : nil;
            id variant = [icon respondsToSelector:NSSelectorFromString(@"active")] ? ((id (*)(id, SEL))objc_msgSend)(icon, NSSelectorFromString(@"active")) : nil;
            [out appendFormat:@"\n  %@: %@ icon %@ active-variant %@ live-isActive %d label-white %d", labelIn(source).text, NSStringFromClass(live.class),
                 [icon respondsToSelector:@selector(name)] ? [icon name] : icon, [variant respondsToSelector:@selector(name)] ? [variant name] : variant,
                 [live respondsToSelector:@selector(isActive)] ? [(SPTEncoreIconView *)live isActive] : -1, isActive(source)];
        }
        SGLogLong(@"navbar", out);
    }

    UITabBarItem *selected = nil;
    BOOL missing = NO;
    for (NSUInteger i = 0; i < sources.count; i++) {
        UITabBarItem *item = bar.items[i];
        if (!item.image) item.image = glyphOf(sources[i], NO);
        if (!item.selectedImage || item.selectedImage == item.image) item.selectedImage = glyphOf(sources[i], YES);
        missing |= !item.image || !item.selectedImage;
        NSString *title = hideLabels ? nil : labelIn(sources[i]).text;
        if (hideLabels ? item.title != nil : title.length && ![title isEqualToString:item.title]) item.title = title;
        if (!selected && isActive(sources[i])) selected = item;
    }
    // No moving selection indicator during swipes. Keep the selected icon
    // in sync with Spotify only when the finger has been released.
    if (selected && !bar.sliding && bar.selectedItem != selected) bar.selectedItem = selected;
    // An icon view Spotify has not built yet is looked for again shortly, not on the next touch.
    static NSUInteger retries;
    if (missing && retries++ < 40) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            syncBar(stockBar);
        });
    }

    CGRect bounds = stockBar.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = MAX(bounds.size.height, glassHeight(bar, stockBar));
    // Move the floating tab capsule down by a few points, keeping its
    // normal touch targets and the existing invisible swipe navigation.
    CGFloat down = stockBar.window.safeAreaInsets.bottom >= 12 ? 5.0 : 2.0;
    CGRect frame = CGRectMake(0, CGRectGetMaxY(bounds) - height + down, width, height);
    if (!CGRectEqualToRect(host.frame, frame)) host.frame = frame;
    // EliSpot v30: keep Spotify's safe-area/height calculations, but inset
    // the actual tab bar to form a floating rounded capsule instead of the
    // full-width rectangular slab. Hit targets remain on the real UITabBar.
    CGFloat side = MIN(12.0, MAX(0, (width - 250) / 2));
    CGRect barFrame = CGRectMake(side, 0, width - 2 * side, height);
    if (!CGRectEqualToRect(bar.frame, barFrame)) bar.frame = barFrame;
    CGFloat capsuleRadius = MIN(32.0, height / 2);
    bar.layer.cornerRadius = capsuleRadius;
    bar.layer.cornerCurve = kCACornerCurveContinuous;
    bar.layer.masksToBounds = YES;
    // A fine neutral rim keeps the entire capsule glass-like over artwork.
    bar.backgroundColor = UIColor.clearColor;
    bar.translucent = YES;
    bar.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.24].CGColor;
    bar.layer.borderWidth = 0.85;
    if (host.superview != stockBar) [stockBar addSubview:host];
    else if (stockBar.subviews.lastObject != host) [stockBar bringSubviewToFront:host];
    logBarOnce(bar);
    makeRoom(containerOf(stockBar));
}

#pragma mark - hooks

static UIView *tabBarOf(UIView *item) {
    Class barClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl10TabBarView");
    for (UIView *v = item.superview; v; v = v.superview) if ([v isKindOfClass:barClass]) return v;
    return nil;
}

%hook _TtC23NavigationUI_TabBarImpl10TabBarView
- (void)layoutSubviews {
    %orig;
    SGRComposeTabBar((UIView *)self);
    for (UIView *sub in ((UIView *)self).subviews) {
        if (![sub isKindOfClass:SGRTabBarHost.class]) [sub layoutIfNeeded];
    }
    holdHome((UIView *)self);
    syncBar((UIView *)self);
    SGRLogTabBarRow((UIView *)self);
}
%end

// The bar's own pass runs before Spotify has filled the row; the items lay out as they arrive.
static void itemDidLayOut(UIView *item) {
    UIView *bar = tabBarOf(item);
    if (!bar) return;
    SGRComposeTabBar(bar);
    holdHome(bar);
    syncBar(bar);
    SGRLogTabBarRow(bar);
}

%hook _TtC23NavigationUI_TabBarImpl21TabBarItemElementView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

%hook _TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

// A tab changed from elsewhere (a link, the side drawer) repaints the labels without a layout pass.
%hook _TtC23NavigationUI_TabBarImpl19TabBarContainerImpl
- (void)setSelectedViewController:(UIViewController *)controller {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *bar = sg_stockBar;
        if (bar) syncBar(bar);
    });
}
// The message bar coming or going changes the view's safe area before Spotify lays the bar out for it,
// so the room follows in that same pass, and inside the message bar's animation.
- (void)viewSafeAreaInsetsDidChange {
    %orig;
    makeRoom((UIViewController *)self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    // Re-tint the real system tab when artwork changes in Song Colours theme.
    [NSNotificationCenter.defaultCenter addObserverForName:@"elispot.songAccentChanged"
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
            UIView *bar = sg_stockBar;
            if (bar) syncBar(bar);
        }];
    SGRequireClasses(@[
        @"_TtC23NavigationUI_TabBarImpl10TabBarView",
        @"_TtC23NavigationUI_TabBarImpl21TabBarItemElementView",
        @"_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView",
        @"_TtC23NavigationUI_TabBarImpl19TabBarContainerImpl",
    ]);
}
