#import <UIKit/UIKit.h>

@interface ELPlayerOverlay : UIView
@property(nonatomic,strong,readonly) UIImageView *artworkView;
- (void)showLyricsPlaceholder;
- (void)startArtworkMotion;
@end
