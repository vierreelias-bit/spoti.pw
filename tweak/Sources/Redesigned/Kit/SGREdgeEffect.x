// Redesigned soft top edge. Runtime API lookup keeps Ubuntu's older SDK compatible.
#import <objc/runtime.h>
#import "Core/SGCore.h"

static void soften(UIScrollView *scrollView) {
    if (@available(iOS 26.0, *)) {
        SEL topSel = NSSelectorFromString(@"topEdgeEffect");
        SEL styleSel = NSSelectorFromString(@"style");
        SEL setStyleSel = NSSelectorFromString(@"setStyle:");
        Class styleClass = NSClassFromString(@"UIScrollEdgeEffectStyle");
        SEL softSel = NSSelectorFromString(@"softStyle");

        if (![scrollView respondsToSelector:topSel] ||
            !styleClass || ![styleClass respondsToSelector:softSel]) return;

        id (*getObject)(id, SEL) = (void *)[scrollView methodForSelector:topSel];
        id top = getObject(scrollView, topSel);
        if (!top || ![top respondsToSelector:styleSel] || ![top respondsToSelector:setStyleSel]) return;

        id (*makeSoft)(id, SEL) = (void *)[styleClass methodForSelector:softSel];
        id soft = makeSoft(styleClass, softSel);

        id (*getStyle)(id, SEL) = (void *)[top methodForSelector:styleSel];
        id current = getStyle(top, styleSel);
        if (current == soft || [current isEqual:soft]) return;

        void (*setStyle)(id, SEL, id) = (void *)[top methodForSelector:setStyleSel];
        setStyle(top, setStyleSel, soft);

        static dispatch_once_t once;
        dispatch_once(&once, ^{
            SGLog(@"soft top edge: first scroll view %@", NSStringFromClass(scrollView.class));
        });
    }
}

%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    if (self.window) soften(self);
}

- (void)layoutSubviews {
    %orig;
    if (self.window) soften(self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
}
