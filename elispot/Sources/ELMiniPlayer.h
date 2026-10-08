#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELMiniPlayer : UIView
- (void)setTitle:(NSString *)title
        subtitle:(NSString *)subtitle
         artwork:(UIImage * _Nullable)artwork;
@end

NS_ASSUME_NONNULL_END
