#import "ELPlayerOverlay.h"

@interface ELPlayerOverlay ()
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic,strong,readwrite) UIImageView *artworkView;
@property(nonatomic,strong) UILabel *lyricsLabel;
@end

@implementation ELPlayerOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;

    UIVisualEffect *effect;
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    effect = glassClass ? [[glassClass alloc] init]
                        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];

    _glass = [[UIVisualEffectView alloc] initWithEffect:effect];
    _glass.layer.cornerRadius = 32;
    _glass.layer.cornerCurve = kCACornerCurveContinuous;
    _glass.layer.borderWidth = .7;
    _glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    _glass.clipsToBounds = YES;
    [self addSubview:_glass];

    _artworkView = [UIImageView new];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.layer.cornerRadius = 28;
    _artworkView.layer.cornerCurve = kCACornerCurveContinuous;
    _artworkView.clipsToBounds = YES;
    [_glass.contentView addSubview:_artworkView];

    _lyricsLabel = [UILabel new];
    _lyricsLabel.numberOfLines = 3;
    _lyricsLabel.textAlignment = NSTextAlignmentLeft;
    _lyricsLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    _lyricsLabel.textColor = UIColor.whiteColor;
    _lyricsLabel.alpha = 0;
    [_glass.contentView addSubview:_lyricsLabel];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glass.frame = self.bounds;
    CGFloat inset = 12;
    self.artworkView.frame = CGRectInset(self.glass.bounds, inset, inset);
    self.lyricsLabel.frame = CGRectInset(self.glass.bounds, 24, 24);
}

- (void)startArtworkMotion {
    [self.artworkView.layer removeAnimationForKey:@"elispot.artwork"];
    CABasicAnimation *zoom = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    zoom.fromValue = @1.0;
    zoom.toValue = @1.055;
    zoom.duration = 7.0;
    zoom.autoreverses = YES;
    zoom.repeatCount = HUGE_VALF;
    zoom.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.artworkView.layer addAnimation:zoom forKey:@"elispot.artwork"];
}

- (void)showLyricsPlaceholder {
    self.lyricsLabel.text = @"Lyrics";
    self.lyricsLabel.alpha = 1;
}

@end
