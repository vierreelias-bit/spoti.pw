#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIWindow * _Nullable ELKeyWindow(void);
UIViewController * _Nullable ELFindTabHost(UIViewController *root);
NSInteger ELSelectedIndex(UIViewController *host);
BOOL ELSetSelectedIndex(UIViewController *host, NSInteger index);
void ELFadeNativeTabBars(UIView *rootView);

NS_ASSUME_NONNULL_END
