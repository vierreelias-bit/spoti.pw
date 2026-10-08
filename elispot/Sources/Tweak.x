#import <UIKit/UIKit.h>
#import "ELRuntime.h"
#import "ELGlassTabBar.h"

static ELGlassTabBar *ELBar = nil;

static void ELInstallIfPossible(void) {
    UIWindow *window = ELKeyWindow();
    if (!window || !window.rootViewController) return;

    UIViewController *host = ELFindTabHost(window.rootViewController);
    if (!host) {
        NSLog(@"[EliSpot] loaded, but no tab host found yet");
        return;
    }

    ELFadeNativeTabBars(window.rootViewController.view);

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
        ELBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:ELBar];
        NSLog(@"[EliSpot] glass tab bar installed on %@", NSStringFromClass(host.class));
    }

    ELBar.tabHost = host;
    [ELBar syncSelection];
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
