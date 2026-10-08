#import <UIKit/UIKit.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"
#import "ELMiniPlayer.h"

static ELGlassTabBar *ELBar = nil;
static ELMiniPlayer *ELMini = nil;
static UILabel *ELLoadBanner = nil;

static void ELShowLoadBanner(void) {
    if (ELLoadBanner) return;

    UIWindow *window = ELKeyWindow();
    if (!window) return;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, window.bounds.size.width - 40, 44)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = [UIColor colorWithRed:0.08 green:0.85 blue:0.35 alpha:0.95];
    label.textColor = UIColor.blackColor;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"EliSpot LOADED";
    label.layer.cornerRadius = 14;
    label.layer.cornerCurve = kCACornerCurveContinuous;
    label.clipsToBounds = YES;
    [window addSubview:label];
    ELLoadBanner = label;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            label.alpha = 0;
        } completion:^(BOOL finished) {
            [label removeFromSuperview];
            if (ELLoadBanner == label) ELLoadBanner = nil;
        }];
    });
}

static void ELInstallIfPossible(void) {
    UIWindow *window = ELKeyWindow();
    if (!window || !window.rootViewController) return;

    ELShowLoadBanner();

    UIView *spotifyBar = ELFindSpotifyTabBar(window.rootViewController.view);
    if (!spotifyBar) {
        NSLog(@"[EliSpot] loaded; waiting for Spotify TabBarView");
        return;
    }

    NSArray *items = ELSpotifyTabItems(spotifyBar);
    NSLog(@"[EliSpot] found Spotify TabBarView with %lu item views",
          (unsigned long)items.count);

    if (items.count < 3) return;

    ELFadeSpotifyTabBar(spotifyBar);

    CGFloat side = 18.0;
    CGFloat tabHeight = 78.0;
    CGFloat bottom = MAX(window.safeAreaInsets.bottom, 8.0) + 8.0;

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
        NSLog(@"[EliSpot] custom Liquid Glass bar installed");
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
        [ELMini setTitle:@"Now Playing" subtitle:@"Spotify" artwork:nil];
        [window addSubview:ELMini];
        NSLog(@"[EliSpot] mini player shell installed");
    }
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        ELInstallIfPossible();
    });
}
%end

%ctor {
    NSLog(@"[EliSpot] dylib loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELShowLoadBanner();
        ELInstallIfPossible();
    });
}
