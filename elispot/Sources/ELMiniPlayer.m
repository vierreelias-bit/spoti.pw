#import "ELMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>

static UIVisualEffect *ELMiniGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

static NSString *ELTimeString(NSTimeInterval seconds) {
    if (!isfinite(seconds) || seconds < 0) seconds = 0;
    NSInteger value = (NSInteger)llround(seconds);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(value / 60), (long)(value % 60)];
}

@interface ELMiniPlayer ()
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic,strong) UIImageView *artworkView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UILabel *timeLabel;
@property(nonatomic,strong) UIView *progressTrack;
@property(nonatomic,strong) UIView *progressFill;
@property(nonatomic,strong) UIButton *playButton;
@property(nonatomic,assign) CGFloat progress;
@end

@implementation ELMiniPlayer

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .18;
    self.layer.shadowRadius = 18;
    self.layer.shadowOffset = CGSizeMake(0, 8);

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
    _artworkView.layer.cornerCurve = kCACornerCurveContinuous;
    _artworkView.clipsToBounds = YES;
    [_glass.contentView addSubview:_artworkView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:.58];
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_subtitleLabel];

    _timeLabel = [UILabel new];
    _timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
    _timeLabel.textColor = [UIColor colorWithWhite:1 alpha:.50];
    _timeLabel.textAlignment = NSTextAlignmentRight;
    _timeLabel.text = @"0:00 / 0:00";
    [_glass.contentView addSubview:_timeLabel];

    _progressTrack = [UIView new];
    _progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:.10];
    _progressTrack.layer.cornerRadius = 1.5;
    [_glass.contentView addSubview:_progressTrack];

    _progressFill = [UIView new];
    _progressFill.backgroundColor = [UIColor colorWithWhite:1 alpha:.70];
    _progressFill.layer.cornerRadius = 1.5;
    [_progressTrack addSubview:_progressFill];

    _playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _playButton.tintColor = UIColor.whiteColor;
    _playButton.backgroundColor = [UIColor colorWithWhite:1 alpha:.055];
    _playButton.layer.cornerRadius = 17;
    _playButton.layer.cornerCurve = kCACornerCurveContinuous;
    _playButton.layer.borderWidth = .45;
    _playButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:.11].CGColor;
    [_playButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [_glass.contentView addSubview:_playButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openTapped:)];
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.glass.frame = self.bounds;
    [self.glass.contentView viewWithTag:3001].frame = self.glass.bounds;

    CGFloat h = self.bounds.size.height;
    CGFloat artwork = h - 12;
    self.artworkView.frame = CGRectMake(6, 6, artwork, artwork);

    CGFloat buttonSide = 34;
    self.playButton.frame = CGRectMake(self.bounds.size.width - buttonSide - 8,
                                       (h - buttonSide) / 2.0,
                                       buttonSide,
                                       buttonSide);

    CGFloat textX = CGRectGetMaxX(self.artworkView.frame) + 10;
    CGFloat textRight = CGRectGetMinX(self.playButton.frame) - 9;
    CGFloat textWidth = MAX(20, textRight - textX);

    self.titleLabel.frame = CGRectMake(textX, 7, textWidth, 18);
    self.subtitleLabel.frame = CGRectMake(textX, 24, textWidth, 15);

    CGFloat timeWidth = 78;
    CGFloat timeRight = CGRectGetMinX(self.playButton.frame) - 7;
    self.timeLabel.frame = CGRectMake(timeRight - timeWidth, h - 17, timeWidth, 12);

    CGFloat progressRight = CGRectGetMinX(self.timeLabel.frame) - 8;
    self.progressTrack.frame = CGRectMake(textX, h - 11, MAX(28, progressRight - textX), 3);
    self.progressFill.frame = CGRectMake(0, 0,
                                         self.progressTrack.bounds.size.width * self.progress,
                                         self.progressTrack.bounds.size.height);
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle artwork:(UIImage *)artwork {
    self.titleLabel.text = title.length ? title : @"Ei kappaletta";
    self.subtitleLabel.text = subtitle.length ? subtitle : @"Nyt soi";
    if (artwork) self.artworkView.image = artwork;
}

- (void)setPaused:(BOOL)paused {
    NSString *name = paused ? @"play.fill" : @"pause.fill";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    [self.playButton setImage:[UIImage systemImageNamed:name withConfiguration:cfg]
                     forState:UIControlStateNormal];
    self.playButton.accessibilityLabel = paused ? @"Toista" : @"Tauko";
}

- (void)setPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration {
    if (!isfinite(position) || position < 0) position = 0;
    if (!isfinite(duration) || duration < 0) duration = 0;
    self.progress = duration > 0 ? MIN(1.0, MAX(0.0, position / duration)) : 0;
    self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@", ELTimeString(position), ELTimeString(duration)];
    [self setNeedsLayout];
}

- (void)setGlassOpacity:(CGFloat)opacity {
    self.glass.alpha = MIN(1.0, MAX(0.18, opacity));
}

- (void)playPauseTapped {
    if (self.playPauseHandler) self.playPauseHandler();
}

- (void)openTapped:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:self];
    CGRect playFrame = [self.playButton.superview convertRect:self.playButton.frame toView:self];
    if (CGRectContainsPoint(playFrame, point)) return;
    if (self.openHandler) self.openHandler();
}

@end
