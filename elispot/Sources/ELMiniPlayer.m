#import "ELMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>
#import <AVKit/AVKit.h>

static UIVisualEffect *ELMiniGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

static UIVisualEffect *ELCardGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
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
@property(nonatomic,strong) UIButton *deviceButton;
@property(nonatomic,strong) UIViewController *presentedSheet;
@property(nonatomic,assign) BOOL liked;
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
    b.backgroundColor = UIColor.clearColor;
    b.layer.cornerRadius = 15;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    b.layer.borderWidth = .45;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:.14].CGColor;
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:ELCardGlass()];
    glass.frame = CGRectMake(0, 0, 30, 30);
    glass.userInteractionEnabled = NO;
    glass.layer.cornerRadius = 15;
    glass.clipsToBounds = YES;
    [b insertSubview:glass atIndex:0];
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

    _deviceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _deviceButton.backgroundColor = UIColor.clearColor;
    _deviceButton.layer.cornerRadius = 8;
    _deviceButton.layer.cornerCurve = kCACornerCurveContinuous;
    _deviceButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _deviceButton.tintColor = ELGreen();
    [_deviceButton addTarget:self action:@selector(deviceTapped) forControlEvents:UIControlEventTouchUpInside];

    UIVisualEffectView *deviceGlass = [[UIVisualEffectView alloc] initWithEffect:ELCardGlass()];
    deviceGlass.userInteractionEnabled = NO;
    deviceGlass.layer.cornerRadius = 8;
    deviceGlass.clipsToBounds = YES;
    deviceGlass.tag = 3201;
    [_deviceButton addSubview:deviceGlass];

    _deviceLabel = [UILabel new];
    _deviceLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightSemibold];
    _deviceLabel.textColor = ELGreen();
    _deviceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _deviceLabel.userInteractionEnabled = NO;
    [_deviceButton addSubview:_deviceLabel];
    [_glass.contentView addSubview:_deviceButton];

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
    self.deviceButton.frame = CGRectMake(textX, 33, MIN(textWidth, 112), 16);
    UIVisualEffectView *deviceGlass = [self.deviceButton viewWithTag:3201];
    deviceGlass.frame = self.deviceButton.bounds;
    self.deviceLabel.frame = CGRectMake(6, 0, self.deviceButton.bounds.size.width - 10, 16);

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
    self.liked = liked;
    NSString *symbol = liked ? @"heart.fill" : @"heart";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
    [self.likeButton setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]
                     forState:UIControlStateNormal];
    self.likeButton.tintColor = liked ? ELGreen() : [UIColor colorWithWhite:1 alpha:.88];
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

- (UIViewController *)topController {
    UIWindow *window = self.window;
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

- (UIView *)glassCardWithFrame:(CGRect)frame radius:(CGFloat)radius {
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:ELCardGlass()];
    glass.frame = frame;
    glass.layer.cornerRadius = radius;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.layer.borderWidth = .6;
    glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.13].CGColor;
    glass.clipsToBounds = YES;
    return glass;
}

- (void)dismissPresentedSheet {
    [self.presentedSheet dismissViewControllerAnimated:YES completion:nil];
    self.presentedSheet = nil;
}

- (void)presentSaveSheet {
    UIViewController *vc = [UIViewController new];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.view.backgroundColor = [UIColor colorWithWhite:0 alpha:.28];

    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = UIScreen.mainScreen.bounds.size.height;
    UIView *sheet = [self glassCardWithFrame:CGRectMake(0, 120, w, h - 120) radius:28];
    [vc.view addSubview:sheet];

    UILabel *cancel = [[UILabel alloc] initWithFrame:CGRectMake(28, 64, 100, 30)];
    cancel.text = @"Peruuta";
    cancel.textColor = UIColor.whiteColor;
    cancel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [sheet addSubview:cancel];

    UILabel *doneTop = [[UILabel alloc] initWithFrame:CGRectMake(w - 100, 64, 72, 30)];
    doneTop.text = @"Valmis";
    doneTop.textAlignment = NSTextAlignmentRight;
    doneTop.textColor = UIColor.whiteColor;
    doneTop.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [sheet addSubview:doneTop];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(28, 118, w - 56, 36)];
    title.text = @"Tallennuspaikka";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [sheet addSubview:title];

    NSArray<NSString *> *rows = @[@"Tykkätyt kappaleet", @"Soittolista", @"Uusi soittolista"];
    for (NSInteger i = 0; i < rows.count; i++) {
        UIView *row = [self glassCardWithFrame:CGRectMake(22, 180 + i * 76, w - 44, 62) radius:18];
        [sheet addSubview:row];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(18, 0, row.bounds.size.width - 76, 62)];
        label.text = rows[i];
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [row addSubview:label];

        UIImageView *plus = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:(i == 0 ? @"checkmark.circle.fill" : @"plus.circle")]];
        plus.tintColor = (i == 0 ? ELGreen() : [UIColor colorWithWhite:1 alpha:.7]);
        plus.frame = CGRectMake(row.bounds.size.width - 46, 15, 32, 32);
        [row addSubview:plus];
    }

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.frame = CGRectMake((w - 240) / 2.0, sheet.bounds.size.height - 110, 240, 56);
    done.layer.cornerRadius = 28;
    done.backgroundColor = ELGreen();
    [done setTitle:@"Valmis" forState:UIControlStateNormal];
    [done setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [done addTarget:self action:@selector(saveDoneTapped) forControlEvents:UIControlEventTouchUpInside];
    [sheet addSubview:done];

    self.presentedSheet = vc;
    [[self topController] presentViewController:vc animated:YES completion:nil];
}

- (void)saveDoneTapped {
    [self setLiked:YES];
    if (self.likeHandler) self.likeHandler();
    [self dismissPresentedSheet];
}

- (void)presentConnectSheet {
    UIViewController *vc = [UIViewController new];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.view.backgroundColor = [UIColor colorWithWhite:0 alpha:.28];

    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = UIScreen.mainScreen.bounds.size.height;
    UIView *sheet = [self glassCardWithFrame:CGRectMake(0, 120, w, h - 120) radius:28];
    [vc.view addSubview:sheet];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(28, 62, w - 56, 38)];
    title.text = @"Connect";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [sheet addSubview:title];

    UIView *deviceCard = [self glassCardWithFrame:CGRectMake(18, 120, w - 36, 130) radius:22];
    [sheet addSubview:deviceCard];

    UILabel *device = [[UILabel alloc] initWithFrame:CGRectMake(22, 18, deviceCard.bounds.size.width - 100, 34)];
    device.text = self.deviceLabel.text.length ? self.deviceLabel.text : @"iPhone";
    device.textColor = UIColor.whiteColor;
    device.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBold];
    [deviceCard addSubview:device];

    UILabel *track = [[UILabel alloc] initWithFrame:CGRectMake(22, 64, deviceCard.bounds.size.width - 44, 28)];
    track.text = [NSString stringWithFormat:@"%@ — %@", self.titleLabel.text ?: @"", self.subtitleLabel.text ?: @""];
    track.textColor = ELGreen();
    track.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [deviceCard addSubview:track];

    AVRoutePickerView *picker = [[AVRoutePickerView alloc] initWithFrame:CGRectMake(deviceCard.bounds.size.width - 76, 38, 56, 56)];
    picker.tintColor = UIColor.whiteColor;
    picker.activeTintColor = ELGreen();
    picker.prioritizesVideoDevices = NO;
    [deviceCard addSubview:picker];

    NSArray<NSString *> *titles = @[@"Aloita Jam", @"Bluetooth ja AirPlay"];
    NSArray<NSString *> *icons = @[@"person.2.wave.2", @"airplayaudio"];
    CGFloat buttonW = (w - 54) / 2.0;
    for (NSInteger i = 0; i < 2; i++) {
        UIVisualEffectView *card = (UIVisualEffectView *)[self glassCardWithFrame:CGRectMake(18 + i * (buttonW + 18), sheet.bounds.size.height - 126, buttonW, 72) radius:20];
        [sheet addSubview:card];

        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icons[i]]];
        icon.tintColor = UIColor.whiteColor;
        icon.frame = CGRectMake(14, 23, 26, 26);
        [card.contentView addSubview:icon];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(46, 0, buttonW - 54, 72)];
        label.text = titles[i];
        label.numberOfLines = 2;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [card.contentView addSubview:label];

        if (i == 1) {
            AVRoutePickerView *bottomPicker = [[AVRoutePickerView alloc] initWithFrame:card.bounds];
            bottomPicker.tintColor = UIColor.clearColor;
            bottomPicker.activeTintColor = UIColor.clearColor;
            [card.contentView addSubview:bottomPicker];
        }
    }

    self.presentedSheet = vc;
    [[self topController] presentViewController:vc animated:YES completion:nil];
}

- (void)likeTapped {
    if (!self.liked) {
        [self presentSaveSheet];
        return;
    }

    [self setLiked:NO];
    if (self.likeHandler) self.likeHandler();
}

- (void)deviceTapped {
    if (self.deviceHandler) self.deviceHandler();
    [self presentConnectSheet];
}
- (void)previousTapped { if (self.previousHandler) self.previousHandler(); }
- (void)playTapped { if (self.playPauseHandler) self.playPauseHandler(); }
- (void)nextTapped { if (self.nextHandler) self.nextHandler(); }

- (void)openTapped:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self];
    for (UIButton *b in @[self.likeButton, self.previousButton, self.playButton, self.nextButton, self.deviceButton]) {
        CGRect r = [b.superview convertRect:b.frame toView:self];
        if (CGRectContainsPoint(r, p)) return;
    }
    if (self.openHandler) self.openHandler();
}
@end
