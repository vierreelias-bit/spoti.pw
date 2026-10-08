#import "ELRuntime.h"
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

static BOOL ELLooksLikeTabHost(UIViewController *vc) {
    if ([vc isKindOfClass:UITabBarController.class]) return YES;

    SEL getSel = NSSelectorFromString(@"selectedIndex");
    SEL setSel = NSSelectorFromString(@"setSelectedIndex:");
    if ([vc respondsToSelector:getSel] && [vc respondsToSelector:setSel]) {
        NSString *name = NSStringFromClass(vc.class).lowercaseString;
        if ([name containsString:@"tab"] || [name containsString:@"nav"]) {
            return YES;
        }
    }
    return NO;
}

UIViewController *ELFindTabHost(UIViewController *root) {
    if (!root) return nil;
    if (ELLooksLikeTabHost(root)) return root;

    UIViewController *presented = root.presentedViewController;
    if (presented) {
        UIViewController *found = ELFindTabHost(presented);
        if (found) return found;
    }

    for (UIViewController *child in root.childViewControllers) {
        UIViewController *found = ELFindTabHost(child);
        if (found) return found;
    }

    if ([root isKindOfClass:UINavigationController.class]) {
        UIViewController *visible = ((UINavigationController *)root).visibleViewController;
        UIViewController *found = ELFindTabHost(visible);
        if (found) return found;
    }

    return nil;
}

NSInteger ELSelectedIndex(UIViewController *host) {
    if (!host) return 0;
    if ([host isKindOfClass:UITabBarController.class]) {
        return ((UITabBarController *)host).selectedIndex;
    }

    SEL sel = NSSelectorFromString(@"selectedIndex");
    if ([host respondsToSelector:sel]) {
        NSInteger (*send)(id, SEL) = (void *)objc_msgSend;
        return send(host, sel);
    }
    return 0;
}

BOOL ELSetSelectedIndex(UIViewController *host, NSInteger index) {
    if (!host) return NO;
    if ([host isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabs = (UITabBarController *)host;
        if (index < 0 || index >= (NSInteger)tabs.viewControllers.count) return NO;
        tabs.selectedIndex = index;
        return YES;
    }

    SEL sel = NSSelectorFromString(@"setSelectedIndex:");
    if ([host respondsToSelector:sel]) {
        void (*send)(id, SEL, NSInteger) = (void *)objc_msgSend;
        send(host, sel, index);
        return YES;
    }
    return NO;
}

void ELFadeNativeTabBars(UIView *rootView) {
    if (!rootView) return;
    if ([rootView isKindOfClass:UITabBar.class]) {
        rootView.alpha = 0.0;
        rootView.userInteractionEnabled = NO;
    }
    for (UIView *subview in rootView.subviews) {
        ELFadeNativeTabBars(subview);
    }
}
