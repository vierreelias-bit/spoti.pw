#import <UIKit/UIKit.h>

@interface ELGlassTabBar : UIView
@property(nonatomic, weak) UIViewController *tabHost;
- (void)syncSelection;
@end
