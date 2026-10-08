#import "ELRuntime.h"
#import <objc/runtime.h>
#import <objc/message.h>

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
    return [lower containsString:@"tabbarview"] ||
           ([lower containsString:@"navigationui"] && [lower containsString:@"tabbar"]) ||
           ([lower containsString:@"tabbarimpl"] && ![lower containsString:@"item"]);
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
    return score;
}

static void ELFindBestTabBar(UIView *view, UIWindow *window, UIView **best, NSInteger *bestScore) {
    if (!view) return;
    NSInteger score = ELTabBarScore(view, window);
    if (score > *bestScore) {
        *bestScore = score;
        *best = view;
    }
    for (UIView *child in view.subviews) ELFindBestTabBar(child, window, best, bestScore);
}

UIView *ELFindSpotifyTabBar(UIView *rootView) {
    if (!rootView) return nil;
    UIWindow *window = rootView.window ?: ELKeyWindow();
    if (!window) return nil;

    UIView *best = nil;
    NSInteger bestScore = NSIntegerMin;
    ELFindBestTabBar(rootView, window, &best, &bestScore);
    return best;
}

static BOOL ELNameLooksLikeItem(NSString *name) {
    NSString *lower = name.lowercaseString;
    return [lower containsString:@"tabbaritemelementview"] ||
           [lower containsString:@"createmenutabbaritemview"] ||
           ([lower containsString:@"tabbaritem"] && ![lower containsString:@"tabbarview"]);
}

static void ELCollectSpotifyItems(UIView *view, NSMutableArray<UIView *> *out) {
    if (!view) return;
    if (ELNameLooksLikeItem(NSStringFromClass(view.class))) {
        [out addObject:view];
        return;
    }
    for (UIView *child in view.subviews) ELCollectSpotifyItems(child, out);
}

NSArray<UIView *> *ELSpotifyTabItems(UIView *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    ELCollectSpotifyItems(tabBar, items);

    NSOrderedSet *unique = [NSOrderedSet orderedSetWithArray:items];
    items = [unique.array mutableCopy];

    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMidX([a convertRect:a.bounds toView:tabBar]);
        CGFloat bx = CGRectGetMidX([b convertRect:b.bounds toView:tabBar]);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return items;
}

static BOOL ELInvokeTapTargets(UIGestureRecognizer *recognizer) {
    Ivar targetsIvar = class_getInstanceVariable(UIGestureRecognizer.class, "_targets");
    if (!targetsIvar) return NO;

    id pairs = object_getIvar(recognizer, targetsIvar);
    if (![pairs isKindOfClass:NSArray.class]) return NO;

    BOOL fired = NO;
    for (id pair in (NSArray *)pairs) {
        Ivar targetIvar = class_getInstanceVariable([pair class], "_target");
        Ivar actionIvar = class_getInstanceVariable([pair class], "_action");
        if (!targetIvar || !actionIvar) continue;

        id target = object_getIvar(pair, targetIvar);
        SEL action = *(SEL *)((uint8_t *)(__bridge void *)pair + ivar_getOffset(actionIvar));
        if (!target || !action || ![target respondsToSelector:action]) continue;

        ((void (*)(id, SEL, id))objc_msgSend)(target, action, recognizer);
        NSLog(@"[EliSpot] forwarded tap -> %@ %@",
              NSStringFromClass([target class]), NSStringFromSelector(action));
        fired = YES;
    }
    return fired;
}

static BOOL ELFireTapInTree(UIView *view) {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:UITapGestureRecognizer.class] &&
            recognizer.enabled &&
            ELInvokeTapTargets(recognizer)) {
            return YES;
        }
    }

    for (UIView *child in view.subviews) {
        if (ELFireTapInTree(child)) return YES;
    }
    return NO;
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
    if (index < 0 || index >= (NSInteger)items.count) return NO;

    UIView *item = items[index];

    if (ELFireTapInTree(item)) {
        NSLog(@"[EliSpot] activated tab %ld via Spotify tap recognizer", (long)index);
        return YES;
    }

    UIControl *control = ELFindControl(item);
    if (control) {
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSLog(@"[EliSpot] activated tab %ld via UIControl", (long)index);
        return YES;
    }

    if ([item accessibilityActivate]) {
        NSLog(@"[EliSpot] activated tab %ld via accessibility", (long)index);
        return YES;
    }

    NSLog(@"[EliSpot] no action found for tab %ld", (long)index);
    return NO;
}

void ELFadeSpotifyTabBar(UIView *tabBar) {
    if (!tabBar) return;
    for (UIView *subview in tabBar.subviews) subview.alpha = 0.001;
}
