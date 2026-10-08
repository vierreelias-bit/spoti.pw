#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"
#import "ELMiniPlayer.h"

@interface ELPlayerObserver : NSObject
@end

static ELGlassTabBar *ELBar = nil;
static ELMiniPlayer *ELMini = nil;
static __weak id ELSpotifyPlayer = nil;
static id ELCurrentState = nil;
static UIImage *ELCurrentArtwork = nil;

static id ELMsgId(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static BOOL ELMsgBool(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
}

static NSString *ELStringValue(id obj, SEL sel) {
    id value = ELMsgId(obj, sel);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static void ELRefreshMiniPlayer(void) {
    if (!ELMini) return;

    id state = ELCurrentState;
    id track = ELMsgId(state, @selector(track));
    NSString *title = ELStringValue(track, @selector(trackTitle));
    NSString *artist = ELStringValue(track, @selector(artistName));
    BOOL paused = ELMsgBool(state, @selector(isPaused));

    [ELMini setTitle:title ?: @"Nothing playing"
            subtitle:artist ?: @"Spotify"
             artwork:ELCurrentArtwork];
    [ELMini setPaused:paused];
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
    if (!window || !window.rootViewController) return;

    UIView *spotifyBar = ELFindSpotifyTabBar(window.rootViewController.view);
    if (!spotifyBar) return;

    NSArray<UIView *> *items = ELSpotifyTabItems(spotifyBar);
    if (items.count < 4) return;

    ELFadeSpotifyTabBar(spotifyBar);

    CGFloat side = 16.0;
    CGFloat tabHeight = 70.0;
    CGFloat bottom = MAX(window.safeAreaInsets.bottom, 8.0) + 7.0;

    if (!ELBar) {
        ELBar = [[ELGlassTabBar alloc] initWithFrame:CGRectMake(
            side,
            window.bounds.size.height - bottom - tabHeight,
            window.bounds.size.width - side * 2.0,
            tabHeight
        )];
        ELBar.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:ELBar];
    }

    ELBar.spotifyTabBar = spotifyBar;
    [ELBar syncFromSpotify];

    if (!ELMini) {
        CGFloat miniH = 58.0;
        CGFloat y = CGRectGetMinY(ELBar.frame) - miniH - 8.0;
        ELMini = [[ELMiniPlayer alloc] initWithFrame:CGRectMake(
            side,
            y,
            window.bounds.size.width - side * 2.0,
            miniH
        )];
        ELMini.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        __weak ELMiniPlayer *weakMini = ELMini;
        ELMini.playPauseHandler = ^{
            (void)weakMini;
            ELTogglePlayback();
        };
        [window addSubview:ELMini];
        ELRefreshMiniPlayer();
    }

    [window bringSubviewToFront:ELMini];
    [window bringSubviewToFront:ELBar];
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
    UIImage *artwork = ELBestArtworkImage(stock);
    if (artwork) ELCurrentArtwork = artwork;

    ELHideStockNowPlayingView(stock);
    ELInstallUI();
    ELRefreshMiniPlayer();
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
    NSLog(@"[EliSpot] loaded: Spotify 9.1.78 glass rebuild");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELInstallUI();
    });
}
