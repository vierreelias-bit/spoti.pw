#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/message.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"
#import "ELMiniPlayer.h"

@interface ELPlayerObserver : NSObject
@end

@interface ELAppearanceController : NSObject
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UISlider *miniSlider;
@property(nonatomic,strong) UISlider *tabsSlider;
- (void)showSettings:(UILongPressGestureRecognizer *)gesture;
@end

static ELGlassTabBar *ELBar = nil;
static ELMiniPlayer *ELMini = nil;
static __weak UIView *ELStockNowPlayingView = nil;
static __weak id ELSpotifyPlayer = nil;
static id ELCurrentState = nil;
static UIImage *ELCurrentArtwork = nil;
static NSTimer *ELProgressTimer = nil;
static BOOL ELFullPlayerVisible = NO;
static ELAppearanceController *ELAppearance = nil;

static NSString *const ELMiniOpacityKey = @"elispot.mini.opacity";
static NSString *const ELTabsOpacityKey = @"elispot.tabs.opacity";

static id ELMsgId(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static double ELMsgDouble(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return 0;
    return ((double (*)(id, SEL))objc_msgSend)(obj, sel);
}

static NSString *ELStringValue(id obj, SEL sel) {
    id value = ELMsgId(obj, sel);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static UIView *ELChromeHost(void) {
    UIWindow *window = ELKeyWindow();
    UIViewController *root = window.rootViewController;
    return root.viewIfLoaded ?: root.view;
}

static CGFloat ELOpacityForKey(NSString *key, CGFloat fallback) {
    NSNumber *value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    if (![value isKindOfClass:NSNumber.class]) return fallback;
    return MIN(1.0, MAX(0.20, value.doubleValue));
}

static void ELApplyAppearance(void) {
    [ELMini setGlassOpacity:ELOpacityForKey(ELMiniOpacityKey, .92)];
    [ELBar setGlassOpacity:ELOpacityForKey(ELTabsOpacityKey, .90)];
}

static void ELSetChromeHidden(BOOL hidden) {
    ELFullPlayerVisible = hidden;

    [UIView animateWithDuration:.22 animations:^{
        ELBar.alpha = hidden ? 0.0 : 1.0;
        ELMini.alpha = hidden ? 0.0 : 1.0;
    }];

    ELBar.userInteractionEnabled = !hidden;
    ELMini.userInteractionEnabled = !hidden;
}

static UIImage *ELSystemArtwork(void) {
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    id raw = info[MPMediaItemPropertyArtwork];
    if (![raw isKindOfClass:MPMediaItemArtwork.class]) return nil;

    MPMediaItemArtwork *artwork = (MPMediaItemArtwork *)raw;
    UIImage *image = [artwork imageWithSize:CGSizeMake(300, 300)];
    return image;
}

static void ELRefreshMiniPlayer(void) {
    if (!ELMini) return;

    UIImage *systemArtwork = ELSystemArtwork();
    if (systemArtwork) ELCurrentArtwork = systemArtwork;

    id state = ELCurrentState;
    id track = ELMsgId(state, @selector(track));
    NSString *title = ELStringValue(track, @selector(trackTitle));
    NSString *artist = ELStringValue(track, @selector(artistName));
    double position = ELMsgDouble(state, @selector(position));
    double duration = ELMsgDouble(state, @selector(duration));

    [ELMini setTitle:title ?: @"Ei kappaletta"
            subtitle:artist ?: @"Nyt soi"
             artwork:ELCurrentArtwork];
    [ELMini setPosition:position duration:duration];
}

static void ELOpenFullPlayer(void) {
    UIView *stock = ELStockNowPlayingView;
    if (!stock) return;
    ELActivateView(stock);
}

static void ELStartProgressTimer(void) {
    if (ELProgressTimer) return;

    ELProgressTimer = [NSTimer scheduledTimerWithTimeInterval:.5
                                                     repeats:YES
                                                       block:^(__unused NSTimer *timer) {
        ELRefreshMiniPlayer();
    }];
}

static void ELCaptureArtworkFromView(UIView *view) {
    UIImage *artwork = ELBestArtworkImage(view);
    if (!artwork || artwork == ELCurrentArtwork) return;
    ELCurrentArtwork = artwork;
    ELRefreshMiniPlayer();
}

static BOOL ELViewLivesInsideStockNowPlaying(UIView *view) {
    UIView *stock = ELStockNowPlayingView;
    if (!stock || !view) return NO;

    for (UIView *cursor = view; cursor; cursor = cursor.superview) {
        if (cursor == stock) return YES;
    }
    return NO;
}

static void ELPositionMiniAboveTabs(void) {
    if (!ELMini || !ELBar || !ELStockNowPlayingView.superview) return;

    UIView *host = ELStockNowPlayingView.superview;
    if (ELMini.superview != host) {
        [ELMini removeFromSuperview];
        [host addSubview:ELMini];
    }

    CGRect barFrame = [ELBar.superview convertRect:ELBar.frame toView:host];
    CGFloat h = 62.0;
    CGFloat gap = 10.0;
    CGFloat y = CGRectGetMinY(barFrame) - h - gap;

    ELMini.frame = CGRectMake(CGRectGetMinX(barFrame),
                              y,
                              CGRectGetWidth(barFrame),
                              h);
    [host bringSubviewToFront:ELMini];
}

@implementation ELAppearanceController

- (UIVisualEffect *)panelEffect {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
}

- (void)showSettings:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    if (self.panel) {
        [self.panel removeFromSuperview];
        self.panel = nil;
        return;
    }

    UIView *host = ELChromeHost();
    if (!host) return;

    CGFloat width = MIN(330.0, host.bounds.size.width - 32.0);
    CGFloat height = 190.0;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((host.bounds.size.width - width) / 2.0,
                                                             host.safeAreaInsets.top + 70.0,
                                                             width,
                                                             height)];
    panel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    panel.layer.cornerRadius = 28;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.shadowColor = UIColor.blackColor.CGColor;
    panel.layer.shadowOpacity = .35;
    panel.layer.shadowRadius = 24;

    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[self panelEffect]];
    glass.frame = panel.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glass.layer.cornerRadius = 28;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.layer.borderWidth = .7;
    glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    glass.clipsToBounds = YES;
    [panel addSubview:glass];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, width - 70, 24)];
    title.text = @"EliSpot-ulkoasu";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [panel addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 48, 10, 38, 38);
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = UIColor.whiteColor;
    [close addTarget:self action:@selector(closeSettings) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:close];

    UILabel *miniLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 58, width - 40, 20)];
    miniLabel.text = @"Nyt soi -läpinäkyvyys";
    miniLabel.textColor = UIColor.whiteColor;
    miniLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [panel addSubview:miniLabel];

    UISlider *mini = [[UISlider alloc] initWithFrame:CGRectMake(20, 79, width - 40, 28)];
    mini.minimumValue = .20;
    mini.maximumValue = 1.0;
    mini.value = ELOpacityForKey(ELMiniOpacityKey, .92);
    [mini addTarget:self action:@selector(miniOpacityChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:mini];
    self.miniSlider = mini;

    UILabel *tabsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 112, width - 40, 20)];
    tabsLabel.text = @"Tabien läpinäkyvyys";
    tabsLabel.textColor = UIColor.whiteColor;
    tabsLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [panel addSubview:tabsLabel];

    UISlider *tabs = [[UISlider alloc] initWithFrame:CGRectMake(20, 133, width - 40, 28)];
    tabs.minimumValue = .20;
    tabs.maximumValue = 1.0;
    tabs.value = ELOpacityForKey(ELTabsOpacityKey, .90);
    [tabs addTarget:self action:@selector(tabsOpacityChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:tabs];
    self.tabsSlider = tabs;

    self.panel = panel;
    [host addSubview:panel];
}

- (void)closeSettings {
    [self.panel removeFromSuperview];
    self.panel = nil;
}

- (void)miniOpacityChanged:(UISlider *)slider {
    [NSUserDefaults.standardUserDefaults setDouble:slider.value forKey:ELMiniOpacityKey];
    ELApplyAppearance();
}

- (void)tabsOpacityChanged:(UISlider *)slider {
    [NSUserDefaults.standardUserDefaults setDouble:slider.value forKey:ELTabsOpacityKey];
    ELApplyAppearance();
}

@end

@implementation ELPlayerObserver
- (void)player:(id)player stateDidChange:(id)state {
    ELSpotifyPlayer = player;
    ELCurrentState = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        ELRefreshMiniPlayer();
    });
}
@end

static ELPlayerObserver *ELObserver = nil;

static void ELInstallUI(void) {
    UIView *host = ELChromeHost();
    if (!host) return;

    UIView *spotifyBar = ELFindSpotifyTabBar(host);
    if (!spotifyBar) return;

    NSArray<UIView *> *items = ELSpotifyTabItems(spotifyBar);
    if (items.count < 4) return;

    ELFadeSpotifyTabBar(spotifyBar);

    CGFloat side = 16.0;
    CGFloat tabHeight = 64.0;
    CGFloat bottom = MAX(host.safeAreaInsets.bottom, 8.0) + 7.0;

    if (!ELBar) {
        ELBar = [[ELGlassTabBar alloc] initWithFrame:CGRectMake(
            side,
            host.bounds.size.height - bottom - tabHeight,
            host.bounds.size.width - side * 2.0,
            tabHeight
        )];
        ELBar.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [host addSubview:ELBar];

        if (!ELAppearance) ELAppearance = [ELAppearanceController new];
        UILongPressGestureRecognizer *hold =
            [[UILongPressGestureRecognizer alloc] initWithTarget:ELAppearance action:@selector(showSettings:)];
        hold.minimumPressDuration = .65;
        [ELBar addGestureRecognizer:hold];
    } else if (ELBar.superview != host) {
        [ELBar removeFromSuperview];
        [host addSubview:ELBar];
    }

    ELBar.frame = CGRectMake(
        side,
        host.bounds.size.height - bottom - tabHeight,
        host.bounds.size.width - side * 2.0,
        tabHeight
    );
    ELBar.spotifyTabBar = spotifyBar;
    [ELBar syncFromSpotify];

    if (!ELMini) {
        ELMini = [[ELMiniPlayer alloc] initWithFrame:CGRectMake(
            side,
            CGRectGetMinY(ELBar.frame) - 72.0,
            host.bounds.size.width - side * 2.0,
            62.0
        )];
        ELMini.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        ELMini.openHandler = ^{
            ELOpenFullPlayer();
        };
        [host addSubview:ELMini];
        ELRefreshMiniPlayer();
        ELStartProgressTimer();
    }

    if (ELStockNowPlayingView.superview) {
        ELPositionMiniAboveTabs();
    } else {
        if (ELMini.superview != host) {
            [ELMini removeFromSuperview];
            [host addSubview:ELMini];
        }
        ELMini.frame = CGRectMake(side,
                                  CGRectGetMinY(ELBar.frame) - 72.0,
                                  host.bounds.size.width - side * 2.0,
                                  62.0);
    }

    ELApplyAppearance();

    if (!ELFullPlayerVisible) {
        if (ELMini.superview) [ELMini.superview bringSubviewToFront:ELMini];
        [host bringSubviewToFront:ELBar];
    }
}

%hook SPTEsperantoPlayer
- (void)addPlayerObserver:(id)observer {
    %orig;

    ELSpotifyPlayer = self;
    if (!ELObserver) {
        ELObserver = [ELPlayerObserver new];
        %orig(ELObserver);
    }

    id state = ELMsgId(self, @selector(state));
    if (state) {
        ELCurrentState = state;
        dispatch_async(dispatch_get_main_queue(), ^{
            ELRefreshMiniPlayer();
        });
    }
}
%end

%hook _TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation
- (void)player:(id)player stateDidChange:(id)state {
    %orig;
    ELSpotifyPlayer = player;
    ELCurrentState = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        ELRefreshMiniPlayer();
    });
}
%end

%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;

    UIView *stock = ((UIViewController *)self).view;
    ELStockNowPlayingView = stock;

    ELCaptureArtworkFromView(stock);
    ELHideStockNowPlayingView(stock);
    ELInstallUI();
    ELPositionMiniAboveTabs();
    ELRefreshMiniPlayer();
}
%end

%hook _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView
- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (view.bounds.size.width >= 40) {
        ELCaptureArtworkFromView(view);
    }
}
%end

%hook _TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    ELSetChromeHidden(YES);
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    ELSetChromeHidden(NO);
    ELApplyAppearance();
}
%end

%hook UIImageView
- (void)setImage:(UIImage *)image {
    %orig;

    if (!image) return;
    UIView *view = (UIView *)self;
    if (!ELViewLivesInsideStockNowPlaying(view)) return;

    CGSize size = image.size;
    if (size.width < 40 || size.height < 40) return;

    CGFloat ratio = size.height > 0 ? size.width / size.height : 0;
    if (ratio < 0.80 || ratio > 1.25) return;

    ELCurrentArtwork = image;
    dispatch_async(dispatch_get_main_queue(), ^{
        ELRefreshMiniPlayer();
    });
}
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        ELInstallUI();
    });
}
%end

%ctor {
    NSLog(@"[EliSpot] loaded: Spotify 9.1.78 glass player v0.3.3");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELInstallUI();
    });
}
