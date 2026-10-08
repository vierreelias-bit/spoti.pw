#import "ELRuntime.h"

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

static BOOL ELNameLooksLikeTabBar(NSString *name) {
    NSString *lower = name.lowercaseString;
    if ([lower containsString:@"tabbarview"]) return YES;
    if ([lower containsString:@"navigationui"] && [lower containsString:@"tabbar"]) return YES;
    if ([lower containsString:@"tabbarimpl"] && ![lower containsString:@"item"]) return YES;
    return NO;
}

static NSInteger ELTabBarScore(UIView *view, UIWindow *window) {
    if (!view || !window) return NSIntegerMin;

    NSString *name = NSStringFromClass(view.class);
    if (!ELNameLooksLikeTabBar(name)) return NSIntegerMin;

    CGRect rect = [view convertRect:view.bounds toView:window];
    if (CGRectIsEmpty(rect) || CGRectIsNull(rect)) return NSIntegerMin;

    NSInteger score = 0;

    if ([name containsString:@"NavigationUI"]) score += 30;
    if ([name containsString:@"TabBarImpl"]) score += 30;
    if ([name containsString:@"TabBarView"]) score += 40;

    CGFloat distanceFromBottom = fabs(CGRectGetMaxY(window.bounds) - CGRectGetMaxY(rect));
    if (distanceFromBottom < 140.0) score += 50;
    if (CGRectGetWidth(rect) > window.bounds.size.width * 0.65) score += 25;
    if (CGRectGetHeight(rect) >= 40.0 && CGRectGetHeight(rect) <= 160.0) score += 20;
    if (!view.hidden && view.alpha > 0.01) score += 10;

    return score;
}

static void ELFindBestTabBar(UIView *view, UIWindow *window, UIView **best, NSInteger *bestScore) {
    if (!view) return;

    NSInteger score = ELTabBarScore(view, window);
    if (score > *bestScore) {
        *bestScore = score;
        *best = view;
    }

    for (UIView *child in view.subviews) {
        ELFindBestTabBar(child, window, best, bestScore);
    }
}

UIView *ELFindSpotifyTabBar(UIView *rootView) {
    if (!rootView) return nil;

    UIWindow *window = rootView.window ?: ELKeyWindow();
    if (!window) return nil;

    UIView *best = nil;
    NSInteger bestScore = NSIntegerMin;
    ELFindBestTabBar(rootView, window, &best, &bestScore);

    if (best) {
        NSLog(@"[EliSpot] tab candidate %@ score=%ld frame=%@",
              NSStringFromClass(best.class),
              (long)bestScore,
              NSStringFromCGRect([best convertRect:best.bounds toView:window]));
    }

    return best;
}

static BOOL ELNameLooksLikeItem(NSString *name) {
    NSString *lower = name.lowercaseString;
    if ([lower containsString:@"tabbaritemelementview"]) return YES;
    if ([lower containsString:@"createmenutabbaritemview"]) return YES;
    if ([lower containsString:@"tabbaritem"] && ![lower containsString:@"tabbarview"]) return YES;
    return NO;
}

static void ELCollectSpotifyItems(UIView *view, NSMutableArray<UIView *> *out) {
    if (!view) return;

    NSString *name = NSStringFromClass(view.class);
    if (ELNameLooksLikeItem(name)) {
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

    if (items.count < 3) {
        for (UIView *child in tabBar.subviews) {
            if (child.userInteractionEnabled && !child.hidden && child.alpha > 0.01) {
                CGRect r = [child convertRect:child.bounds toView:tabBar];
                if (CGRectGetWidth(r) > 35.0 && CGRectGetHeight(r) > 30.0) {
                    [items addObject:child];
                }
            }
        }
    }

    NSOrderedSet *unique = [NSOrderedSet orderedSetWithArray:items];
    items = [unique.array mutableCopy];

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

    if ([item accessibilityActivate]) {
        NSLog(@"[EliSpot] activated Spotify tab %ld via accessibility on %@",
              (long)index, NSStringFromClass(item.class));
        return YES;
    }

    UIControl *control = ELFindControl(item);
    if (control) {
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSLog(@"[EliSpot] activated Spotify tab %ld via UIControl %@",
              (long)index, NSStringFromClass(control.class));
        return YES;
    }

    CGPoint point = CGPointMake(CGRectGetMidX(item.bounds), CGRectGetMidY(item.bounds));
    UIView *hit = [item hitTest:point withEvent:nil];
    if ([hit isKindOfClass:UIControl.class]) {
        [(UIControl *)hit sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSLog(@"[EliSpot] activated Spotify tab %ld via hit-test control %@",
              (long)index, NSStringFromClass(hit.class));
        return YES;
    }

    NSLog(@"[EliSpot] Spotify tab %ld found (%@), but no activatable control exposed",
          (long)index, NSStringFromClass(item.class));
    return NO;
}

void ELFadeSpotifyTabBar(UIView *tabBar) {
    if (!tabBar) return;
    tabBar.alpha = 0.001;
    tabBar.userInteractionEnabled = NO;
}
