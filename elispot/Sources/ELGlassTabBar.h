#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELGlassTabBar : UIView
@property(nonatomic, weak, nullable) UIView *spotifyTabBar;
- (void)syncFromSpotify;
- (void)setGlassOpacity:(CGFloat)opacity;
@end

NS_ASSUME_NONNULL_END
