#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELPlayerOverlay : UIView
@property(nonatomic,strong,readonly) UIImageView *artworkView;
- (void)showLyricsPlaceholder;
- (void)startArtworkMotion;
@end

NS_ASSUME_NONNULL_END
