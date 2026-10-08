#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELMiniPlayer : UIView
@property(nonatomic, copy, nullable) void (^playPauseHandler)(void);
- (void)setTitle:(NSString *)title
        subtitle:(NSString *)subtitle
         artwork:(UIImage * _Nullable)artwork;
- (void)setPaused:(BOOL)paused;
@end

NS_ASSUME_NONNULL_END
