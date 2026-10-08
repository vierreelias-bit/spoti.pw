#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELMiniPlayer : UIView
@property(nonatomic, copy, nullable) void (^playPauseHandler)(void);
@property(nonatomic, copy, nullable) void (^openHandler)(void);
- (void)setTitle:(NSString *)title
        subtitle:(NSString *)subtitle
         artwork:(UIImage * _Nullable)artwork;
- (void)setPaused:(BOOL)paused;
- (void)setPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration;
@end

NS_ASSUME_NONNULL_END
