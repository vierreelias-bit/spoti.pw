#import <UIKit/UIKit.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"
#import "ELMiniPlayer.h"

static ELGlassTabBar *ELBar = nil;
static ELMiniPlayer *ELMini = nil;
static UILabel *ELLoadBanner = nil;
static UILabel *ELTabBanner = nil;

static UILabel *ELBanner(NSString *text, UIColor *color, CGFloat y) {
    UIWindow *window = ELKeyWindow();
    if (!window) return nil;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, y, window.bounds.size.width - 32, 48)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = color;
    label.textColor = UIColor.blackColor;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.text = text;
    label.layer.cornerRadius = 14;
    label.layer.cornerCurve = kCACornerCurveContinuous;
    label.clipsToBounds = YES;
    [window addSubview:label];
    return label;
}

static void ELShowLoadBanner(void) {
    if (ELLoadBanner) return;
    ELLoadBanner = ELBanner(@"EliSpot LOADED",
                            [UIColor colorWithRed:0.08 green:0.85 blue:0.35 alpha:0.95],
                            70);
}

static void ELShowTabFoundBanner(UIView *tabBar, NSUInteger itemCount) {
    if (ELTabBanner) return;

    NSString *name = NSStringFromClass(tabBar.class);
    NSString *text = [NSString stringWithFormat:@"TABBAR FOUND (%lu)\n%@",
                      (unsigned long)itemCount, name];

    ELTabBanner = ELBanner(text,
                          [UIColor colorWithRed:0.25 green:0.70 blue:1.0 alpha:0.96],
                          124);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            ELTabBanner.alpha = 0;
        } completion:^(BOOL finished) {
            [ELTabBanner removeFromSuperview];
            ELTabBanner = nil;
        }];
    });
}

static void ELInstallIfPossible(void) {
    UIWindow *window = ELKeyWindow();
    if (!window || !window.rootViewController) return;

    ELShowLoadBanner();

    UIView *spotifyBar = ELFindSpotifyTabBar(window.rootViewController.view);
    if (!spotifyBar) {
        NSLog(@"[EliSpot] 9.1.78 scan: no tab bar candidate yet");
        return;
    }

    NSArray *items = ELSpotifyTabItems(spotifyBar);
    ELShowTabFoundBanner(spotifyBar, items.count);

    NSLog(@"[EliSpot] 9.1.78 tab bar %@ with %lu items",
          NSStringFromClass(spotifyBar.class),
          (unsigned long)items.count);

    if (items.count < 3) {
        NSLog(@"[EliSpot] candidate found but item count is too low");
        return;
    }

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
        [ELMini setTitle:@"Now Playing" subtitle:@"Spotify 9.1.78" artwork:nil];
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
    NSLog(@"[EliSpot] dylib loaded (Spotify 9.1.78 diagnostic build)");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELShowLoadBanner();
    });

    for (NSInteger i = 1; i <= 8; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.75 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            ELInstallIfPossible();
        });
    }
}
