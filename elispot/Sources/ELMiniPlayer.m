#import "ELMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>

static UIVisualEffect *ELMiniGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

static UIColor *ELGreen(void) {
    return [UIColor colorWithRed:30.0/255.0 green:215.0/255.0 blue:96.0/255.0 alpha:1.0];
}

static NSString *ELTime(NSTimeInterval seconds) {
    if (!isfinite(seconds) || seconds < 0) seconds = 0;
    NSInteger value = (NSInteger)llround(seconds);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60), (long)(value % 60)];
}

@interface ELMiniPlayer ()
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic,strong) UIImageView *artworkView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UILabel *deviceLabel;
@property(nonatomic,strong) UILabel *timeLabel;
@property(nonatomic,strong) UIView *progressTrack;
@property(nonatomic,strong) UIView *progressFill;
@property(nonatomic,strong) UIButton *likeButton;
@property(nonatomic,strong) UIButton *previousButton;
@property(nonatomic,strong) UIButton *playButton;
@property(nonatomic,strong) UIButton *nextButton;
@property(nonatomic,assign) CGFloat progress;
@end

@implementation ELMiniPlayer

- (UIButton *)button:(NSString *)symbol action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.tintColor = ELGreen();
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:.045];
    b.layer.cornerRadius = 15;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    b.layer.borderWidth = .45;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:.10].CGColor;
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
    [b setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    _glass = [[UIVisualEffectView alloc] initWithEffect:ELMiniGlass()];
    _glass.layer.cornerRadius = 23;
    _glass.layer.cornerCurve = kCACornerCurveContinuous;
    _glass.layer.borderWidth = .55;
    _glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.15].CGColor;
    _glass.clipsToBounds = YES;
    [self addSubview:_glass];

    UIView *tint = [UIView new];
    tint.tag = 3001;
    tint.backgroundColor = [UIColor colorWithWhite:0 alpha:.045];
    [_glass.contentView addSubview:tint];

    _artworkView = [UIImageView new];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.backgroundColor = [UIColor colorWithWhite:1 alpha:.05];
    _artworkView.layer.cornerRadius = 14;
    _artworkView.clipsToBounds = YES;
    [_glass.contentView addSubview:_artworkView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:.58];
    [_glass.contentView addSubview:_subtitleLabel];

    _deviceLabel = [UILabel new];
    _deviceLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
    _deviceLabel.textColor = ELGreen();
    _deviceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_deviceLabel];

    _timeLabel = [UILabel new];
    _timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:9.5 weight:UIFontWeightMedium];
    _timeLabel.textColor = [UIColor colorWithWhite:1 alpha:.50];
    _timeLabel.textAlignment = NSTextAlignmentRight;
    [_glass.contentView addSubview:_timeLabel];

    _progressTrack = [UIView new];
    _progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:.10];
    _progressTrack.layer.cornerRadius = 1.5;
    [_glass.contentView addSubview:_progressTrack];

    _progressFill = [UIView new];
    _progressFill.backgroundColor = ELGreen();
    _progressFill.layer.cornerRadius = 1.5;
    [_progressTrack addSubview:_progressFill];

    _likeButton = [self button:@"heart" action:@selector(likeTapped)];
    _previousButton = [self button:@"backward.fill" action:@selector(previousTapped)];
    _playButton = [self button:@"play.fill" action:@selector(playTapped)];
    _nextButton = [self button:@"forward.fill" action:@selector(nextTapped)];

    for (UIButton *b in @[_likeButton, _previousButton, _playButton, _nextButton]) {
        [_glass.contentView addSubview:b];
    }

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openTapped:)];
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glass.frame = self.bounds;
    [self.glass.contentView viewWithTag:3001].frame = self.glass.bounds;

    CGFloat h = self.bounds.size.height;
    CGFloat art = h - 12;
    self.artworkView.frame = CGRectMake(6, 6, art, art);

    CGFloat bs = 30, gap = 5;
    CGFloat total = bs * 4 + gap * 3;
    CGFloat x = self.bounds.size.width - total - 8;

    NSArray<UIButton *> *buttons = @[self.likeButton, self.previousButton, self.playButton, self.nextButton];
    for (NSInteger i = 0; i < buttons.count; i++) {
        buttons[i].frame = CGRectMake(x + i * (bs + gap), 6, bs, bs);
    }

    CGFloat textX = CGRectGetMaxX(self.artworkView.frame) + 10;
    CGFloat textRight = x - 8;
    CGFloat textWidth = MAX(20, textRight - textX);

    self.titleLabel.frame = CGRectMake(textX, 6, textWidth, 17);
    self.subtitleLabel.frame = CGRectMake(textX, 21, textWidth, 13);
    self.deviceLabel.frame = CGRectMake(textX, 34, textWidth, 12);

    CGFloat tw = 76;
    self.timeLabel.frame = CGRectMake(self.bounds.size.width - tw - 9, h - 14, tw, 10);

    CGFloat progressRight = CGRectGetMinX(self.timeLabel.frame) - 8;
    self.progressTrack.frame = CGRectMake(textX, h - 8, MAX(30, progressRight - textX), 3);
    self.progressFill.frame = CGRectMake(0, 0, self.progressTrack.bounds.size.width * self.progress, 3);
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle artwork:(UIImage *)artwork {
    self.titleLabel.text = title.length ? title : @"Ei kappaletta";
    self.subtitleLabel.text = subtitle.length ? subtitle : @"Nyt soi";
    if (artwork) self.artworkView.image = artwork;
}

- (void)setPaused:(BOOL)paused {
    NSString *symbol = paused ? @"play.fill" : @"pause.fill";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
    [self.playButton setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]
                     forState:UIControlStateNormal];
}

- (void)setDeviceName:(NSString *)deviceName {
    self.deviceLabel.text = deviceName.length ? deviceName : @"iPhone";
}

- (void)setLiked:(BOOL)liked {
    NSString *symbol = liked ? @"heart.fill" : @"heart";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
    [self.likeButton setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]
                     forState:UIControlStateNormal];
}

- (void)setPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration {
    if (!isfinite(position) || position < 0) position = 0;
    if (!isfinite(duration) || duration < 0) duration = 0;
    self.progress = duration > 0 ? MIN(1.0, MAX(0.0, position / duration)) : 0;
    self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@", ELTime(position), ELTime(duration)];
    [self setNeedsLayout];
}

- (void)setGlassOpacity:(CGFloat)opacity {
    self.glass.alpha = MIN(1.0, MAX(.18, opacity));
}

- (void)likeTapped { if (self.likeHandler) self.likeHandler(); }
- (void)previousTapped { if (self.previousHandler) self.previousHandler(); }
- (void)playTapped { if (self.playPauseHandler) self.playPauseHandler(); }
- (void)nextTapped { if (self.nextHandler) self.nextHandler(); }

- (void)openTapped:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self];
    for (UIButton *b in @[self.likeButton, self.previousButton, self.playButton, self.nextButton]) {
        CGRect r = [b.superview convertRect:b.frame toView:self];
        if (CGRectContainsPoint(r, p)) return;
    }
    if (self.openHandler) self.openHandler();
}
@end
