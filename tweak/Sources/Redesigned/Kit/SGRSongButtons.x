// Song-matched accents for visible actions in the redesigned UI.
// Only enabled by "Colours follow song". Repaint UIKit buttons, custom
// Spotify Encore glyphs, EliSpot action capsules and menu controls when a new
// cover arrives; never recolour album artwork or ordinary text labels.
#import "Core/SGCore.h"
#import "SGRAccent.h"
#import "SGRActionRow.h"
#import "Headers/SPTEncoreIconView.h"

static char kLastTintKey;
static BOOL sg_refreshQueued;

static BOOL insideButton(UIView *view) {
    for (UIView *parent = view; parent; parent = parent.superview) {
        if ([parent isKindOfClass:UIControl.class] &&
            ![parent isKindOfClass:UISlider.class] &&
            ![parent isKindOfClass:UITextField.class]) return YES;
        if ((parent.accessibilityTraits & UIAccessibilityTraitButton) != 0) return YES;
        if ([NSStringFromClass(parent.class) rangeOfString:@"Button"
                options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
        if (parent == view.window) break;
    }
    return NO;
}

static void recolorTree(UIView *root, UIColor *accent, NSInteger rgb) {
    if (!root) return;
    SGForEachView(root, ^(UIView *view) {
        if (view.hidden || view.alpha < 0.01) return;
        if ([view isKindOfClass:SGRPlayCapsule.class]) {
            SGRPlayCapsule *capsule = (SGRPlayCapsule *)view;
            capsule.fillColor = accent;
            // Song accent is a bright button surface: use dark content.
            capsule.contentColor = UIColor.blackColor;
            if (capsule.source) [capsule feedFrom:capsule.source];
            [capsule setNeedsLayout];
            return;
        }
        if ([view isKindOfClass:SGRMirrorButton.class]) {
            SGRMirrorButton *button = (SGRMirrorButton *)view;
            BOOL hasOnState = button.onGlyphColor != nil;
            button.glyphColor = [accent colorWithAlphaComponent:0.72];
            if (hasOnState) button.onGlyphColor = accent;
            if (button.source) [button feedFrom:button.source];
            return;
        }
        if ([view isKindOfClass:UISlider.class] ||
            [view isKindOfClass:UITextField.class]) return;
        if ([view isKindOfClass:UIControl.class]) {
            UIControl *control = (UIControl *)view;
            if (control.enabled && ![control.tintColor isEqual:accent])
                control.tintColor = accent;
            if ([control isKindOfClass:UISwitch.class])
                ((UISwitch *)control).onTintColor = accent;
        }
        if ([view isKindOfClass:SPTEncoreIconView.class] && insideButton(view)) {
            NSNumber *previous = objc_getAssociatedObject(view, &kLastTintKey);
            if (previous.integerValue != rgb) {
                // Encore renders its own images, bypassing UIView.tintColor.
                [(SPTEncoreIconView *)view setForegroundColor:accent];
                [(SPTEncoreIconView *)view setActiveForegroundColor:accent];
                objc_setAssociatedObject(view, &kLastTintKey, @(rgb),
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        if ([view isKindOfClass:UIImageView.class] && insideButton(view)) {
            UIImageView *icon = (UIImageView *)view;
            if (icon.image.renderingMode == UIImageRenderingModeAlwaysTemplate &&
                icon.bounds.size.width <= 90 && icon.bounds.size.height <= 90 &&
                ![icon.tintColor isEqual:accent])
                icon.tintColor = accent;
        }
    });
}

static void refreshVisibleButtons(void) {
    NSInteger rgb = SGRSongColorRGB();
    if (rgb < 0) return;
    UIColor *accent = SGRAccentColor();
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.hidden || window.alpha < 0.01) continue;
        recolorTree(window, accent, rgb);
    }
}

static void scheduleButtonRefresh(void) {
    if (sg_refreshQueued || SGRSongColorRGB() < 0) return;
    sg_refreshQueued = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        sg_refreshQueued = NO;
        refreshVisibleButtons();
    });
}

%hook UIControl
- (void)didMoveToWindow {
    %orig;
    if (self.window) scheduleButtonRefresh();
}
%end

%hook SPTEncoreIconView
- (void)didMoveToWindow {
    %orig;
    if (self.window && insideButton((UIView *)self)) scheduleButtonRefresh();
}
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    scheduleButtonRefresh();
}
%end

%ctor {
    if (!SGRedesignedUI() || !SGFlag(SGRKeySongTheme, NO)) return;
    %init;
    [NSNotificationCenter.defaultCenter
        addObserverForName:@"elispot.songAccentChanged"
        object:nil queue:NSOperationQueue.mainQueue
        usingBlock:^(NSNotification *note) { scheduleButtonRefresh(); }];
    SGRequireClasses(@[@"SPTEncoreIconView"]);
}
