#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"
#import "ELMiniPlayer.h"

@interface ELPlayerObserver : NSObject
@end

static ELGlassTabBar *ELBar = nil;
static ELMiniPlayer *ELMini = nil;
static __weak UIView *ELStockNowPlayingView = nil;
static __weak id ELSpotifyPlayer = nil;
static id ELCurrentState = nil;
static UIImage *ELCurrentArtwork = nil;
static NSTimer *ELProgressTimer = nil;
static BOOL ELFullPlayerVisible = NO;

static id ELMsgId(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static BOOL ELMsgBool(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return NO;
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

static void ELSetChromeHidden(BOOL hidden) {
    ELFullPlayerVisible = hidden;

    [UIView animateWithDuration:.22 animations:^{
        ELBar.alpha = hidden ? 0.0 : 1.0;
        ELMini.alpha = hidden ? 0.0 : 1.0;
    }];

    ELBar.userInteractionEnabled = !hidden;
    ELMini.userInteractionEnabled = !hidden;
}

static void ELRefreshMiniPlayer(void) {
    if (!ELMini) return;

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
    UIWindow *window = ELKeyWindow();
    UIView *host = ELChromeHost();
    if (!window || !host) return;

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

    CGFloat miniH = 62.0;
    CGFloat miniY = CGRectGetMinY(ELBar.frame) - miniH - 8.0;

    if (!ELMini) {
        ELMini = [[ELMiniPlayer alloc] initWithFrame:CGRectMake(
            side,
            miniY,
            host.bounds.size.width - side * 2.0,
            miniH
        )];
        ELMini.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

        ELMini.playPauseHandler = ^{
            ELTogglePlayback();
        };
        ELMini.openHandler = ^{
            ELOpenFullPlayer();
        };

        [host addSubview:ELMini];
        ELRefreshMiniPlayer();
        ELStartProgressTimer();
    } else if (ELMini.superview != host) {
        [ELMini removeFromSuperview];
        [host addSubview:ELMini];
    }

    ELMini.frame = CGRectMake(
        side,
        miniY,
        host.bounds.size.width - side * 2.0,
        miniH
    );

    if (!ELFullPlayerVisible) {
        [host bringSubviewToFront:ELMini];
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
    NSLog(@"[EliSpot] loaded: Spotify 9.1.78 glass player v0.3.1");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELInstallUI();
    });
}
