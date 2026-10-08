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
@property(nonatomic,assign) CGFloat progress;
@end

@implementation ELMiniPlayer

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .22;
    self.layer.shadowRadius = 18;
    self.layer.shadowOffset = CGSizeMake(0, 8);

    _glass = [[UIVisualEffectView alloc] initWithEffect:ELMiniGlass()];
    _glass.layer.cornerRadius = 23;
    _glass.layer.cornerCurve = kCACornerCurveContinuous;
    _glass.layer.borderWidth = .55;
    _glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.17].CGColor;
    _glass.clipsToBounds = YES;
    [self addSubview:_glass];

    UIView *tint = [UIView new];
    tint.tag = 3001;
    tint.backgroundColor = [UIColor colorWithWhite:0 alpha:.08];
    [_glass.contentView addSubview:tint];

    _artworkView = [UIImageView new];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.backgroundColor = [UIColor colorWithWhite:1 alpha:.06];
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
    _timeLabel.textColor = [UIColor colorWithWhite:1 alpha:.55];
    _timeLabel.textAlignment = NSTextAlignmentRight;
    _timeLabel.text = @"0:00 / 0:00";
    [_glass.contentView addSubview:_timeLabel];

    _progressTrack = [UIView new];
    _progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:.12];
    _progressTrack.layer.cornerRadius = 1.5;
    [_glass.contentView addSubview:_progressTrack];

    _progressFill = [UIView new];
    _progressFill.backgroundColor = [UIColor colorWithWhite:1 alpha:.72];
    _progressFill.layer.cornerRadius = 1.5;
    [_progressTrack addSubview:_progressFill];

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

    CGFloat textX = CGRectGetMaxX(self.artworkView.frame) + 10;
    CGFloat textRight = self.bounds.size.width - 10;
    CGFloat textWidth = MAX(20, textRight - textX);

    self.titleLabel.frame = CGRectMake(textX, 7, textWidth, 18);
    self.subtitleLabel.frame = CGRectMake(textX, 24, textWidth, 15);

    CGFloat timeWidth = 78;
    self.timeLabel.frame = CGRectMake(self.bounds.size.width - timeWidth - 9, h - 17, timeWidth, 12);

    CGFloat progressRight = CGRectGetMinX(self.timeLabel.frame) - 8;
    self.progressTrack.frame = CGRectMake(textX, h - 11, MAX(30, progressRight - textX), 3);
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
    (void)paused;
}

- (void)setPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration {
    if (!isfinite(position) || position < 0) position = 0;
    if (!isfinite(duration) || duration < 0) duration = 0;
    self.progress = duration > 0 ? MIN(1.0, MAX(0.0, position / duration)) : 0;
    self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@", ELTimeString(position), ELTimeString(duration)];
    [self setNeedsLayout];
}

- (void)setGlassOpacity:(CGFloat)opacity {
    self.alpha = MIN(1.0, MAX(0.20, opacity));
}

- (void)openTapped:(UITapGestureRecognizer *)tap {
    (void)tap;
    if (self.openHandler) self.openHandler();
}

@end
