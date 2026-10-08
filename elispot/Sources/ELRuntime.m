#import "ELRuntime.h"

static BOOL ELClassNameEquals(UIView *view, NSString *name) {
    return [NSStringFromClass(view.class) isEqualToString:name];
}

UIWindow *ELKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return nil;
}

UIView *ELFindSpotifyTabBar(UIView *rootView) {
    if (!rootView) return nil;

    NSString *name = NSStringFromClass(rootView.class);
    if ([name isEqualToString:@"_TtC23NavigationUI_TabBarImpl10TabBarView"]) {
        return rootView;
    }

    for (UIView *child in rootView.subviews) {
        UIView *found = ELFindSpotifyTabBar(child);
        if (found) return found;
    }
    return nil;
}

static void ELCollectSpotifyItems(UIView *view, NSMutableArray<UIView *> *out) {
    if (!view) return;

    NSString *name = NSStringFromClass(view.class);
    if ([name isEqualToString:@"_TtC23NavigationUI_TabBarImpl21TabBarItemElementView"] ||
        [name isEqualToString:@"_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView"]) {
        [out addObject:view];
        return;
    }

    for (UIView *child in view.subviews) {
        ELCollectSpotifyItems(child, out);
    }
}

NSArray<UIView *> *ELSpotifyTabItems(UIView *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    ELCollectSpotifyItems(tabBar, items);

    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGRect ra = [a convertRect:a.bounds toView:tabBar];
        CGRect rb = [b convertRect:b.bounds toView:tabBar];
        CGFloat ax = CGRectGetMidX(ra);
        CGFloat bx = CGRectGetMidX(rb);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return items;
}

static UIControl *ELFindControl(UIView *view) {
    if ([view isKindOfClass:UIControl.class]) return (UIControl *)view;
    for (UIView *child in view.subviews) {
        UIControl *control = ELFindControl(child);
        if (control) return control;
    }
    return nil;
}

BOOL ELActivateSpotifyTab(UIView *tabBar, NSInteger index) {
    NSArray<UIView *> *items = ELSpotifyTabItems(tabBar);
    if (index < 0 || index >= (NSInteger)items.count) {
        NSLog(@"[EliSpot] tab index %ld out of range; Spotify exposed %lu items",
              (long)index, (unsigned long)items.count);
        return NO;
    }

    UIView *item = items[index];

    // UIKit/SwiftUI-backed controls commonly expose accessibilityActivate,
    // which keeps Spotify's own navigation action in charge.
    if ([item accessibilityActivate]) {
        NSLog(@"[EliSpot] activated Spotify tab %ld via accessibility", (long)index);
        return YES;
    }

    UIControl *control = ELFindControl(item);
    if (control) {
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSLog(@"[EliSpot] activated Spotify tab %ld via UIControl", (long)index);
        return YES;
    }

    NSLog(@"[EliSpot] Spotify tab %ld found, but no activatable control was exposed", (long)index);
    return NO;
}

void ELFadeSpotifyTabBar(UIView *tabBar) {
    if (!tabBar) return;
    // Keep it alive so its own controls/navigation logic still work when invoked programmatically.
    tabBar.alpha = 0.001;
    tabBar.userInteractionEnabled = NO;
}
