#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"
#import "ELMiniPlayer.h"

@interface ELPlayerObserver : NSObject
@end

@interface ELOverlayHostView : UIView
@end

@implementation ELOverlayHostView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha <= .01 || !self.userInteractionEnabled) return nil;
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit && hit != self) return hit;
    return CGRectContainsPoint(self.bounds, point) ? self : nil;
}
@end

@interface ELAppearanceController : NSObject
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UISlider *miniSlider;
@property(nonatomic,strong) UISlider *tabsSlider;
- (void)showSettings:(UILongPressGestureRecognizer *)gesture;
@end

static ELGlassTabBar *ELBar = nil;
static ELMiniPlayer *ELMini = nil;
static ELOverlayHostView *ELOverlayHost = nil;
static __weak UIView *ELStockNowPlayingView = nil;
static __weak id ELSpotifyPlayer = nil;
static id ELCurrentState = nil;
static UIImage *ELCurrentArtwork = nil;
static NSTimer *ELProgressTimer = nil;
static BOOL ELFullPlayerVisible = NO;
static BOOL ELOpeningPlayer = NO;
static ELAppearanceController *ELAppearance = nil;

static NSString *const ELMiniOpacityKey = @"elispot.mini.opacity";
static NSString *const ELTabsOpacityKey = @"elispot.tabs.opacity";
static char ELLyricsGlassKey;

static id ELMsgId(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static BOOL ELMsgBool(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return YES;
    return ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
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
    return MIN(1.0, MAX(.18, value.doubleValue));
}

static void ELApplyAppearance(void) {
    [ELMini setGlassOpacity:ELOpacityForKey(ELMiniOpacityKey, .72)];
    [ELBar setGlassOpacity:ELOpacityForKey(ELTabsOpacityKey, .70)];
}

static void ELSetChromeHidden(BOOL hidden) {
    ELFullPlayerVisible = hidden;
    [UIView animateWithDuration:.22 animations:^{
        ELOverlayHost.alpha = hidden ? 0.0 : 1.0;
    }];
    ELOverlayHost.userInteractionEnabled = !hidden;
}

static UIImage *ELSystemArtwork(void) {
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    id raw = info[MPMediaItemPropertyArtwork];
    if (![raw isKindOfClass:MPMediaItemArtwork.class]) return nil;
    return [(MPMediaItemArtwork *)raw imageWithSize:CGSizeMake(300, 300)];
}

static NSString *ELCurrentAudioDeviceName(void) {
    AVAudioSessionRouteDescription *route = AVAudioSession.sharedInstance.currentRoute;
    AVAudioSessionPortDescription *output = route.outputs.firstObject;
    if (output.portName.length) return output.portName;
    return @"iPhone";
}

static void ELRefreshMiniPlayer(void) {
    if (!ELMini) return;

    UIImage *systemArtwork = ELSystemArtwork();
    if (systemArtwork) ELCurrentArtwork = systemArtwork;

    id state = ELCurrentState;
    id track = ELMsgId(state, @selector(track));
    NSString *title = ELStringValue(track, @selector(trackTitle));
    NSString *artist = ELStringValue(track, @selector(artistName));
    BOOL paused = ELMsgBool(state, @selector(isPaused));
    double position = ELMsgDouble(state, @selector(position));
    double duration = ELMsgDouble(state, @selector(duration));

    [ELMini setTitle:title ?: @"Ei kappaletta"
            subtitle:artist ?: @"Nyt soi"
             artwork:ELCurrentArtwork];
    [ELMini setPaused:paused];
    [ELMini setDeviceName:ELCurrentAudioDeviceName()];
    [ELMini setPosition:position duration:duration];
}

static void ELTogglePlayback(void) {
    id player = ELSpotifyPlayer;
    id state = ELCurrentState;
    if (!player || !state) return;

    BOOL paused = ELMsgBool(state, @selector(isPaused));
    SEL sel = paused ? @selector(resume:) : @selector(pause:);
    if (![player respondsToSelector:sel]) return;

    ((id (*)(id, SEL, id))objc_msgSend)(player, sel, nil);
}

static UIVisualEffect *ELTransitionGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

static void ELOpenFullPlayer(void) {
    UIView *stock = ELStockNowPlayingView;
    UIView *host = ELChromeHost();
    if (!stock || !host || !ELMini || ELOpeningPlayer) return;

    ELOpeningPlayer = YES;

    CGRect startFrame = [ELMini.superview convertRect:ELMini.frame toView:host];
    UIView *snapshot = [ELMini snapshotViewAfterScreenUpdates:NO];
    snapshot.frame = startFrame;
    snapshot.layer.cornerRadius = 31;
    snapshot.layer.cornerCurve = kCACornerCurveContinuous;
    snapshot.layer.masksToBounds = YES;

    UIView *backdrop = [[UIView alloc] initWithFrame:host.bounds];
    backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.0];
    backdrop.userInteractionEnabled = NO;

    [host addSubview:backdrop];
    [host addSubview:snapshot];
    [host bringSubviewToFront:snapshot];

    ELOverlayHost.alpha = 0.0;

    [UIView animateWithDuration:.46
                          delay:0
         usingSpringWithDamping:.90
          initialSpringVelocity:.08
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:.40];
        snapshot.frame = host.bounds;
        snapshot.layer.cornerRadius = 0;
    } completion:^(__unused BOOL finished) {
        ELActivateView(stock);

        [UIView animateWithDuration:.16 animations:^{
            snapshot.alpha = 0.0;
            backdrop.alpha = 0.0;
        } completion:^(__unused BOOL done) {
            [snapshot removeFromSuperview];
            [backdrop removeFromSuperview];
            ELOpeningPlayer = NO;
        }];
    }];
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

static void ELLayoutOverlayHost(void) {
    UIView *host = ELChromeHost();
    if (!host || !ELOverlayHost || !ELBar || !ELMini) return;

    CGFloat side = 16.0;
    CGFloat tabHeight = 64.0;
    CGFloat miniHeight = 62.0;
    CGFloat gap = 10.0;
    CGFloat bottom = MAX(host.safeAreaInsets.bottom, 8.0) + 7.0;

    CGRect tabFrame = CGRectMake(side,
                                 host.bounds.size.height - bottom - tabHeight,
                                 host.bounds.size.width - side * 2.0,
                                 tabHeight);

    CGRect miniFrame = CGRectMake(side,
                                  CGRectGetMinY(tabFrame) - miniHeight - gap,
                                  host.bounds.size.width - side * 2.0,
                                  miniHeight);

    CGRect unionFrame = CGRectUnion(miniFrame, tabFrame);

    ELOverlayHost.frame = unionFrame;
    ELMini.frame = CGRectMake(0, 0, unionFrame.size.width, miniHeight);
    ELBar.frame = CGRectMake(0,
                             CGRectGetMinY(tabFrame) - CGRectGetMinY(unionFrame),
                             unionFrame.size.width,
                             tabHeight);
}

static void ELStyleLyricsTree(UIView *root) {
    for (UIView *view in root.subviews) {
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            CGFloat point = label.font.pointSize;
            CGFloat target = point >= 20 ? 30.0 : MAX(20.0, point + 5.0);
            label.font = [UIFont systemFontOfSize:target
                                          weight:(point >= 20 ? UIFontWeightSemibold : UIFontWeightMedium)];
            label.textColor = UIColor.whiteColor;
            label.numberOfLines = 0;
        }
        ELStyleLyricsTree(view);
    }
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
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((host.bounds.size.width - width) / 2.0,
                                                             host.safeAreaInsets.top + 70.0,
                                                             width,
                                                             190.0)];
    panel.layer.cornerRadius = 28;
    panel.layer.cornerCurve = kCACornerCurveContinuous;

    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[self panelEffect]];
    glass.frame = panel.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glass.layer.cornerRadius = 28;
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
    [panel addSubview:miniLabel];

    UISlider *mini = [[UISlider alloc] initWithFrame:CGRectMake(20, 79, width - 40, 28)];
    mini.minimumValue = .18;
    mini.maximumValue = 1.0;
    mini.value = ELOpacityForKey(ELMiniOpacityKey, .72);
    [mini addTarget:self action:@selector(miniOpacityChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:mini];
    self.miniSlider = mini;

    UILabel *tabsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 112, width - 40, 20)];
    tabsLabel.text = @"Tabien läpinäkyvyys";
    tabsLabel.textColor = UIColor.whiteColor;
    [panel addSubview:tabsLabel];

    UISlider *tabs = [[UISlider alloc] initWithFrame:CGRectMake(20, 133, width - 40, 28)];
    tabs.minimumValue = .18;
    tabs.maximumValue = 1.0;
    tabs.value = ELOpacityForKey(ELTabsOpacityKey, .70);
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

    if (!ELOverlayHost) {
        ELOverlayHost = [ELOverlayHostView new];
        ELOverlayHost.backgroundColor = UIColor.clearColor;
        ELOverlayHost.userInteractionEnabled = YES;
        [host addSubview:ELOverlayHost];
    } else if (ELOverlayHost.superview != host) {
        [ELOverlayHost removeFromSuperview];
        [host addSubview:ELOverlayHost];
    }

    if (!ELBar) {
        ELBar = [[ELGlassTabBar alloc] initWithFrame:CGRectZero];
        [ELOverlayHost addSubview:ELBar];

        if (!ELAppearance) ELAppearance = [ELAppearanceController new];
        UILongPressGestureRecognizer *hold =
            [[UILongPressGestureRecognizer alloc] initWithTarget:ELAppearance action:@selector(showSettings:)];
        hold.minimumPressDuration = .65;
        [ELBar addGestureRecognizer:hold];
    }

    if (!ELMini) {
        ELMini = [[ELMiniPlayer alloc] initWithFrame:CGRectZero];

        ELMini.saveHandler = ^(BOOL saved) {
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
            [ELMini setLiked:saved];
        };

        ELMini.playPauseHandler = ^{
            ELTogglePlayback();
        };

        ELMini.deviceHandler = ^{
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        };

        ELMini.openHandler = ^{
            ELOpenFullPlayer();
        };

        [ELOverlayHost addSubview:ELMini];
        ELRefreshMiniPlayer();
        ELStartProgressTimer();
    }

    ELBar.spotifyTabBar = spotifyBar;
    [ELBar syncFromSpotify];

    ELLayoutOverlayHost();
    ELApplyAppearance();

    [host bringSubviewToFront:ELOverlayHost];
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
    ELLayoutOverlayHost();
    ELRefreshMiniPlayer();
}
%end

%hook _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView
- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (view.bounds.size.width >= 40) ELCaptureArtworkFromView(view);
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

%hook _TtC22Lyrics_NPVContainerKit19LyricsContainerView
- (void)layoutSubviews {
    %orig;

    UIView *host = (UIView *)self;
    UIVisualEffectView *glass = objc_getAssociatedObject(host, &ELLyricsGlassKey);

    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:ELTransitionGlass()];
        glass.userInteractionEnabled = NO;
        glass.layer.cornerRadius = 28;
        glass.layer.cornerCurve = kCACornerCurveContinuous;
        glass.clipsToBounds = YES;
        objc_setAssociatedObject(host, &ELLyricsGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [host insertSubview:glass atIndex:0];
    }

    glass.frame = CGRectInset(host.bounds, 4, 4);
    host.backgroundColor = UIColor.clearColor;
    ELStyleLyricsTree(host);
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
    if (ratio < .80 || ratio > 1.25) return;

    ELCurrentArtwork = image;
    dispatch_async(dispatch_get_main_queue(), ^{
        ELRefreshMiniPlayer();
    });
}
%end

%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (ELOverlayHost && !ELOverlayHost.hidden && ELOverlayHost.alpha > .01 && ELOverlayHost.userInteractionEnabled) {
        CGPoint p = [ELOverlayHost convertPoint:point fromView:self];
        if (CGRectContainsPoint(ELOverlayHost.bounds, p)) {
            UIView *hit = [ELOverlayHost hitTest:p withEvent:event];
            if (hit) return hit;
            return ELOverlayHost;
        }
    }
    return %orig;
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
    NSLog(@"[EliSpot] loaded: Spotify 9.1.78 glass player v0.3.10");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELInstallUI();
    });
}
