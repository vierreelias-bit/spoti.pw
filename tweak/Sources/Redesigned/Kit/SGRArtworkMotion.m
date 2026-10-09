// EliSpot v30: low-cost original motion effect on an existing UIImageView.
// Apple/Spotify video artwork requires real licensed video assets; this is
// deliberately a subtle Ken Burns-style scale on the cover already on screen.
#import "Core/SGCore.h"
#import "SGRTokens.h"
#import "SGRArtworkMotion.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString *const kCoverMotionKey = @"elispot.coverMotion";

void SGRUpdateArtworkMotion(UIImageView *imageView) {
    if (!imageView) return;
    BOOL enabled = SGRedesignedUI() &&
                   SGFlag(SGRKeyArtworkMotion, NO) &&
                   !SGRReduceMotion() &&
                   ![NSProcessInfo processInfo].lowPowerModeEnabled &&
                   imageView.window && imageView.image;
    if (!enabled) {
        [imageView.layer removeAnimationForKey:kCoverMotionKey];
        return;
    }
    if ([imageView.layer animationForKey:kCoverMotionKey]) return;

    CABasicAnimation *motion = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    motion.fromValue = @1.0;
    motion.toValue = @1.055;
    motion.duration = 10.0;
    motion.autoreverses = YES;
    motion.repeatCount = HUGE_VALF;
    motion.removedOnCompletion = NO;
    motion.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [imageView.layer addAnimation:motion forKey:kCoverMotionKey];
}
