#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELMiniPlayer : UIView
@property(nonatomic, copy, nullable) void (^likeHandler)(void);
@property(nonatomic, copy, nullable) void (^previousHandler)(void);
@property(nonatomic, copy, nullable) void (^playPauseHandler)(void);
@property(nonatomic, copy, nullable) void (^nextHandler)(void);
@property(nonatomic, copy, nullable) void (^openHandler)(void);
@property(nonatomic, copy, nullable) void (^deviceHandler)(void);
- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle artwork:(UIImage * _Nullable)artwork;
- (void)setPaused:(BOOL)paused;
- (void)setLiked:(BOOL)liked;
- (void)setDeviceName:(NSString *)deviceName;
- (void)setPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration;
- (void)setGlassOpacity:(CGFloat)opacity;
@end

NS_ASSUME_NONNULL_END
