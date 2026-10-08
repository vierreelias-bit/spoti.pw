#import <UIKit/UIKit.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"

static ELGlassTabBar *ELBar = nil;

static void ELInstallIfPossible(void) {
    UIWindow *window = ELKeyWindow();
    if (!window || !window.rootViewController) return;

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

    if (!ELBar) {
        CGFloat side = 18.0;
        CGFloat height = 78.0;
        CGFloat bottom = MAX(window.safeAreaInsets.bottom, 8.0) + 8.0;

        ELBar = [[ELGlassTabBar alloc] initWithFrame:CGRectMake(
            side,
            window.bounds.size.height - bottom - height,
            window.bounds.size.width - side * 2.0,
            height
        )];

        ELBar.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:ELBar];

        NSLog(@"[EliSpot] custom Liquid Glass bar installed");
    }

    ELBar.spotifyTabBar = spotifyBar;
    [ELBar syncFromSpotify];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        ELInstallIfPossible();
    });
}
