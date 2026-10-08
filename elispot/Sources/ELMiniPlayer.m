#import "ELMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>

static UIVisualEffect *ELMiniGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

@interface ELMiniPlayer ()
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic,strong) UIView *highlight;
@property(nonatomic,strong) UIImageView *artworkView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UIButton *playButton;
@end

@implementation ELMiniPlayer

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .30;
    self.layer.shadowRadius = 22;
    self.layer.shadowOffset = CGSizeMake(0, 10);

    _glass = [[UIVisualEffectView alloc] initWithEffect:ELMiniGlass()];
    _glass.layer.cornerRadius = 24;
    _glass.layer.cornerCurve = kCACornerCurveContinuous;
    _glass.layer.borderWidth = .7;
    _glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    _glass.clipsToBounds = YES;
    [self addSubview:_glass];

    UIView *tint = [UIView new];
    tint.tag = 3001;
    tint.backgroundColor = [UIColor colorWithWhite:0 alpha:.16];
    [_glass.contentView addSubview:tint];

    _highlight = [UIView new];
    _highlight.userInteractionEnabled = NO;
    _highlight.backgroundColor = [UIColor colorWithWhite:1 alpha:.06];
    [_glass.contentView addSubview:_highlight];

    _artworkView = [UIImageView new];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.backgroundColor = [UIColor colorWithWhite:1 alpha:.06];
    _artworkView.layer.cornerRadius = 16;
    _artworkView.layer.cornerCurve = kCACornerCurveContinuous;
    _artworkView.clipsToBounds = YES;
    [_glass.contentView addSubview:_artworkView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:.58];
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_subtitleLabel];

    _playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _playButton.tintColor = UIColor.whiteColor;
    _playButton.backgroundColor = [UIColor colorWithWhite:1 alpha:.09];
    _playButton.layer.cornerRadius = 18;
    _playButton.layer.cornerCurve = kCACornerCurveContinuous;
    [_playButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [_glass.contentView addSubview:_playButton];

    [self setPaused:YES];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.glass.frame = self.bounds;
    [self.glass.contentView viewWithTag:3001].frame = self.glass.bounds;

    self.highlight.frame = CGRectMake(14, 1, MAX(0, self.bounds.size.width - 28), 1);

    CGFloat h = self.bounds.size.height;
    CGFloat artwork = h - 12;
    self.artworkView.frame = CGRectMake(6, 6, artwork, artwork);

    CGFloat buttonSize = 36;
    self.playButton.frame = CGRectMake(self.bounds.size.width - buttonSize - 10,
                                       (h - buttonSize) / 2.0,
                                       buttonSize,
                                       buttonSize);

    CGFloat textX = CGRectGetMaxX(self.artworkView.frame) + 11;
    CGFloat textRight = CGRectGetMinX(self.playButton.frame) - 10;
    CGFloat textWidth = MAX(20, textRight - textX);

    self.titleLabel.frame = CGRectMake(textX, 11, textWidth, 20);
    self.subtitleLabel.frame = CGRectMake(textX, 31, textWidth, 17);
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle artwork:(UIImage *)artwork {
    self.titleLabel.text = title.length ? title : @"Nothing playing";
    self.subtitleLabel.text = subtitle.length ? subtitle : @"Spotify";
    if (artwork) self.artworkView.image = artwork;
}

- (void)setPaused:(BOOL)paused {
    NSString *name = paused ? @"play.fill" : @"pause.fill";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    [self.playButton setImage:[UIImage systemImageNamed:name withConfiguration:cfg]
                     forState:UIControlStateNormal];
    self.playButton.accessibilityLabel = paused ? @"Play" : @"Pause";
}

- (void)playPauseTapped {
    if (self.playPauseHandler) self.playPauseHandler();
}

@end
