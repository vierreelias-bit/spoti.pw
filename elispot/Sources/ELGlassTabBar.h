#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELGlassTabBar : UIView
@property(nonatomic, weak, nullable) UIView *spotifyTabBar;
- (void)syncFromSpotify;
@end

NS_ASSUME_NONNULL_END
