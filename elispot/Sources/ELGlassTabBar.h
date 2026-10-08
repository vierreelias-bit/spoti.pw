#import <UIKit/UIKit.h>

@interface ELGlassTabBar : UIView
@property(nonatomic, weak) UIView *spotifyTabBar;
- (void)syncFromSpotify;
@end
