#import "ELMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>
#import <AVKit/AVKit.h>
#import <objc/message.h>

static UIVisualEffect *ELGlassWithFallback(UIBlurEffectStyle fallback) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    SEL factory = NSSelectorFromString(@"effectWithStyle:");
    if (glass && [glass respondsToSelector:factory]) {
        return ((id (*)(id, SEL, NSInteger))objc_msgSend)(glass, factory, 0);
    }
    return [UIBlurEffect effectWithStyle:fallback];
}

static UIVisualEffect *ELMiniGlass(void) {
    return ELGlassWithFallback(UIBlurEffectStyleSystemChromeMaterialDark);
}

static UIVisualEffect *ELCardGlass(void) {
    return ELGlassWithFallback(UIBlurEffectStyleSystemMaterialDark);
}

static void ELShapeGlass(UIView *glass, CGFloat radius, BOOL capsule) {
    Class config = NSClassFromString(@"UICornerConfiguration");
    Class cornerRadius = NSClassFromString(@"UICornerRadius");
    id shape = nil;
    if (config && [glass respondsToSelector:NSSelectorFromString(@"setCornerConfiguration:")]) {
        if (capsule && [config respondsToSelector:NSSelectorFromString(@"capsuleConfiguration")]) {
            shape = ((id (*)(id, SEL))objc_msgSend)(config, NSSelectorFromString(@"capsuleConfiguration"));
        } else if ([config respondsToSelector:NSSelectorFromString(@"configurationWithUniformRadius:")] &&
                   [cornerRadius respondsToSelector:NSSelectorFromString(@"fixedRadius:")]) {
            id fixed = ((id (*)(id, SEL, CGFloat))objc_msgSend)(cornerRadius, NSSelectorFromString(@"fixedRadius:"), radius);
            shape = ((id (*)(id, SEL, id))objc_msgSend)(config, NSSelectorFromString(@"configurationWithUniformRadius:"), fixed);
        }
    }
    if (shape) {
        ((void (*)(id, SEL, id))objc_msgSend)(glass, NSSelectorFromString(@"setCornerConfiguration:"), shape);
        glass.clipsToBounds = NO;
    } else {
        glass.layer.cornerRadius = capsule ? glass.bounds.size.height / 2.0 : radius;
        glass.layer.cornerCurve = kCACornerCurveContinuous;
        glass.clipsToBounds = YES;
    }
}

static UIColor *ELGreen(void) {
    return [UIColor colorWithRed:30.0/255.0 green:215.0/255.0 blue:96.0/255.0 alpha:1.0];
}

@interface ELMiniPlayer ()
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic,strong) UIImageView *artworkView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UIView *progressTrack;
@property(nonatomic,strong) UIView *progressFill;
@property(nonatomic,strong) UIButton *deviceButton;
@property(nonatomic,strong) UIButton *saveButton;
@property(nonatomic,strong) UIButton *playButton;
@property(nonatomic,strong) UIViewController *presentedSheet;
@property(nonatomic,strong) NSString *deviceName;
@property(nonatomic,assign) BOOL liked;
@property(nonatomic,assign) CGFloat progress;
@end

@implementation ELMiniPlayer

- (UIButton *)glassButtonWithSymbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = UIColor.clearColor;
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 20;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = .55;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:.14].CGColor;

    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:ELMiniGlass()];
    glass.userInteractionEnabled = NO;
    glass.frame = CGRectMake(0, 0, 40, 40);
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glass.layer.cornerRadius = 20;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    glass.tag = 4100;
    [button addSubview:glass];

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .26;
    self.layer.shadowRadius = 22;
    self.layer.shadowOffset = CGSizeMake(0, 10);

    _glass = [[UIVisualEffectView alloc] initWithEffect:ELMiniGlass()];
    _glass.layer.borderWidth = .7;
    _glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    [self addSubview:_glass];

    UIView *shade = [UIView new];
    shade.tag = 3001;
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:.07];
    [_glass.contentView addSubview:shade];

    _artworkView = [UIImageView new];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.backgroundColor = [UIColor colorWithWhite:1 alpha:.05];
    _artworkView.layer.cornerCurve = kCACornerCurveContinuous;
    _artworkView.clipsToBounds = YES;
    [_glass.contentView addSubview:_artworkView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:.64];
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_glass.contentView addSubview:_subtitleLabel];

    _progressTrack = [UIView new];
    _progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:.16];
    _progressTrack.layer.cornerRadius = 1.5;
    [_glass.contentView addSubview:_progressTrack];

    _progressFill = [UIView new];
    _progressFill.backgroundColor = UIColor.whiteColor;
    _progressFill.layer.cornerRadius = 1.5;
    [_progressTrack addSubview:_progressFill];

    _deviceButton = [self glassButtonWithSymbol:@"airplayaudio" action:@selector(deviceTapped)];
    _saveButton = [self glassButtonWithSymbol:@"plus" action:@selector(saveTapped)];
    _playButton = [self glassButtonWithSymbol:@"play.fill" action:@selector(playTapped)];

    for (UIButton *button in @[_deviceButton, _saveButton, _playButton]) {
        [_glass.contentView addSubview:button];
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
    ELShapeGlass(self.glass, 31, YES);
    [self.glass.contentView viewWithTag:3001].frame = self.glass.bounds;

    CGFloat h = self.bounds.size.height;
    CGFloat art = h - 12;
    self.artworkView.frame = CGRectMake(6, 6, art, art);
    self.artworkView.layer.cornerRadius = art / 2.0;

    CGFloat bs = 40, gap = 8;
    CGFloat controlsW = bs * 3 + gap * 2;
    CGFloat controlsX = self.bounds.size.width - controlsW - 10;
    CGFloat controlsY = (h - bs) / 2.0;

    self.deviceButton.frame = CGRectMake(controlsX, controlsY, bs, bs);
    self.saveButton.frame = CGRectMake(controlsX + bs + gap, controlsY, bs, bs);
    self.playButton.frame = CGRectMake(controlsX + (bs + gap) * 2, controlsY, bs, bs);

    CGFloat textX = CGRectGetMaxX(self.artworkView.frame) + 12;
    CGFloat textRight = controlsX - 10;
    CGFloat textW = MAX(40, textRight - textX);
    self.titleLabel.frame = CGRectMake(textX, 11, textW, 21);
    self.subtitleLabel.frame = CGRectMake(textX, 34, textW, 19);

    self.progressTrack.frame = CGRectMake(8, h - 3, self.bounds.size.width - 16, 3);
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
    NSString *symbol = paused ? @"play.fill" : @"pause.fill";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
    [self.playButton setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]
                     forState:UIControlStateNormal];
}

- (void)setLiked:(BOOL)liked {
    _liked = liked;
    NSString *symbol = liked ? @"checkmark" : @"plus";
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
    [self.saveButton setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]
                     forState:UIControlStateNormal];
    self.saveButton.tintColor = liked ? UIColor.blackColor : UIColor.whiteColor;
    self.saveButton.backgroundColor = liked ? ELGreen() : UIColor.clearColor;

    UIVisualEffectView *glass = [self.saveButton viewWithTag:4100];
    glass.alpha = liked ? 0.0 : 1.0;
}

- (void)setDeviceName:(NSString *)deviceName {
    _deviceName = deviceName.length ? [deviceName copy] : @"iPhone";
}

- (void)setPosition:(NSTimeInterval)position duration:(NSTimeInterval)duration {
    if (!isfinite(position) || position < 0) position = 0;
    if (!isfinite(duration) || duration < 0) duration = 0;
    self.progress = duration > 0 ? MIN(1.0, MAX(0.0, position / duration)) : 0;
    [self setNeedsLayout];
}

- (void)setGlassOpacity:(CGFloat)opacity {
    self.glass.alpha = MIN(1.0, MAX(.18, opacity));
}

- (UIViewController *)topController {
    UIViewController *vc = self.window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

- (UIVisualEffectView *)glassCardWithFrame:(CGRect)frame radius:(CGFloat)radius {
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:ELCardGlass()];
    glass.frame = frame;
    glass.layer.cornerRadius = radius;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.layer.borderWidth = .6;
    glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.13].CGColor;
    glass.clipsToBounds = YES;
    return glass;
}

- (UIButton *)textButton:(NSString *)title frame:(CGRect)frame selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)dismissPresentedSheet {
    [self.presentedSheet dismissViewControllerAnimated:YES completion:nil];
    self.presentedSheet = nil;
}

- (void)presentSaveSheet {
    UIViewController *vc = [UIViewController new];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.view.backgroundColor = [UIColor colorWithWhite:0 alpha:.36];

    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = UIScreen.mainScreen.bounds.size.height;
    CGFloat sheetY = 105;
    UIVisualEffectView *sheet = [self glassCardWithFrame:CGRectMake(0, sheetY, w, h - sheetY) radius:30];
    [vc.view addSubview:sheet];

    UIView *handle = [[UIView alloc] initWithFrame:CGRectMake((w - 54)/2.0, 18, 54, 5)];
    handle.backgroundColor = [UIColor colorWithWhite:1 alpha:.35];
    handle.layer.cornerRadius = 2.5;
    [sheet.contentView addSubview:handle];

    [sheet.contentView addSubview:[self textButton:@"Peruuta"
                                             frame:CGRectMake(24, 52, 100, 40)
                                          selector:@selector(cancelSaveSheet)]];
    UIButton *doneTop = [self textButton:@"Valmis"
                                   frame:CGRectMake(w - 112, 52, 88, 40)
                                selector:@selector(saveDoneTapped)];
    doneTop.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [sheet.contentView addSubview:doneTop];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 112, w - 48, 36)];
    title.text = @"Tallennuspaikka";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [sheet.contentView addSubview:title];

    UILabel *newPlaylist = [[UILabel alloc] initWithFrame:CGRectMake(w - 180, 112, 156, 36)];
    newPlaylist.text = @"Uusi soittolista";
    newPlaylist.textAlignment = NSTextAlignmentRight;
    newPlaylist.textColor = ELGreen();
    newPlaylist.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [sheet.contentView addSubview:newPlaylist];

    NSArray<NSString *> *names = @[@"Tykkätyt kappaleet", @"ə", @"🇮🇱 🇮🇱", @"💪 TOP"];
    NSArray<NSString *> *counts = @[@"", @"277 kappaletta", @"162 kappaletta", @"52 kappaletta"];

    for (NSInteger i = 0; i < names.count; i++) {
        CGFloat y = 170 + i * 82;
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(18, y, w - 36, 72)];
        [sheet.contentView addSubview:row];

        UIImageView *thumb = [[UIImageView alloc] initWithFrame:CGRectMake(0, 7, 58, 58)];
        thumb.layer.cornerRadius = 10;
        thumb.clipsToBounds = YES;
        thumb.contentMode = UIViewContentModeScaleAspectFill;
        if (i == 0) {
            thumb.backgroundColor = [UIColor colorWithRed:.42 green:.31 blue:.95 alpha:1];
            UIImageView *heart = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill"]];
            heart.tintColor = UIColor.whiteColor;
            heart.frame = CGRectMake(17, 17, 24, 24);
            [thumb addSubview:heart];
        } else if (self.artworkView.image) {
            thumb.image = self.artworkView.image;
        } else {
            thumb.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        }
        [row addSubview:thumb];

        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(72, 8, row.bounds.size.width - 132, 28)];
        name.text = names[i];
        name.textColor = UIColor.whiteColor;
        name.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
        [row addSubview:name];

        if (counts[i].length) {
            UILabel *count = [[UILabel alloc] initWithFrame:CGRectMake(72, 36, row.bounds.size.width - 132, 24)];
            count.text = counts[i];
            count.textColor = [UIColor colorWithWhite:1 alpha:.58];
            count.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            [row addSubview:count];
        }

        UIImageView *action = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:(i == 0 ? @"checkmark.circle.fill" : @"plus.circle")]];
        action.frame = CGRectMake(row.bounds.size.width - 44, 18, 36, 36);
        action.tintColor = (i == 0 ? ELGreen() : [UIColor colorWithWhite:1 alpha:.72]);
        [row addSubview:action];
    }

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.frame = CGRectMake((w - 220)/2.0, sheet.bounds.size.height - 96, 220, 58);
    done.layer.cornerRadius = 29;
    done.layer.cornerCurve = kCACornerCurveContinuous;
    done.backgroundColor = ELGreen();
    [done setTitle:@"Valmis" forState:UIControlStateNormal];
    [done setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [done addTarget:self action:@selector(saveDoneTapped) forControlEvents:UIControlEventTouchUpInside];
    [sheet.contentView addSubview:done];

    self.presentedSheet = vc;
    [[self topController] presentViewController:vc animated:YES completion:nil];
}

- (void)cancelSaveSheet {
    [self setLiked:NO];
    if (self.saveHandler) self.saveHandler(NO);
    [self dismissPresentedSheet];
}

- (void)saveDoneTapped {
    [self setLiked:YES];
    if (self.saveHandler) self.saveHandler(YES);
    [self dismissPresentedSheet];
}

- (void)presentConnectSheet {
    UIViewController *vc = [UIViewController new];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.view.backgroundColor = [UIColor colorWithWhite:0 alpha:.34];

    CGFloat w = UIScreen.mainScreen.bounds.size.width;
    CGFloat h = UIScreen.mainScreen.bounds.size.height;
    CGFloat sheetY = MAX(105.0, h * .40);

    UIVisualEffectView *sheet =
        [self glassCardWithFrame:CGRectMake(8, sheetY, w - 16, h - sheetY - 8) radius:30];
    [vc.view addSubview:sheet];

    UIView *handle = [[UIView alloc] initWithFrame:CGRectMake((sheet.bounds.size.width - 54)/2.0, 18, 54, 5)];
    handle.backgroundColor = [UIColor colorWithWhite:1 alpha:.35];
    handle.layer.cornerRadius = 2.5;
    [sheet.contentView addSubview:handle];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 56, sheet.bounds.size.width - 48, 38)];
    title.text = @"Connect";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [sheet.contentView addSubview:title];

    UIVisualEffectView *deviceCard =
        [self glassCardWithFrame:CGRectMake(16, 116, sheet.bounds.size.width - 32, 126) radius:22];
    [sheet.contentView addSubview:deviceCard];

    UILabel *device = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, 190, 34)];
    device.text = self.deviceName.length ? self.deviceName : @"iPhone";
    device.textColor = UIColor.whiteColor;
    device.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBold];
    [deviceCard.contentView addSubview:device];

    UILabel *normal = [[UILabel alloc] initWithFrame:CGRectMake(178, 22, 74, 28)];
    normal.text = @"Normaali";
    normal.textAlignment = NSTextAlignmentCenter;
    normal.textColor = [UIColor colorWithWhite:1 alpha:.68];
    normal.backgroundColor = [UIColor colorWithWhite:1 alpha:.10];
    normal.layer.cornerRadius = 7;
    normal.clipsToBounds = YES;
    normal.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [deviceCard.contentView addSubview:normal];

    UILabel *track = [[UILabel alloc] initWithFrame:CGRectMake(20, 66, deviceCard.bounds.size.width - 92, 26)];
    track.text = [NSString stringWithFormat:@"%@ — %@", self.titleLabel.text ?: @"", self.subtitleLabel.text ?: @""];
    track.textColor = ELGreen();
    track.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [deviceCard.contentView addSubview:track];

    AVRoutePickerView *picker =
        [[AVRoutePickerView alloc] initWithFrame:CGRectMake(deviceCard.bounds.size.width - 72, 36, 52, 52)];
    picker.tintColor = ELGreen();
    picker.activeTintColor = ELGreen();
    picker.prioritizesVideoDevices = NO;
    [deviceCard.contentView addSubview:picker];

    UILabel *jam = [[UILabel alloc] initWithFrame:CGRectMake(28, 264, sheet.bounds.size.width - 130, 58)];
    jam.text = @"Kutsu lähellä olevia henkilöitä\nautomaattisesti Jamiin";
    jam.numberOfLines = 2;
    jam.textColor = UIColor.whiteColor;
    jam.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [sheet.contentView addSubview:jam];

    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(sheet.bounds.size.width - 88, 274, 64, 36)];
    toggle.onTintColor = ELGreen();
    [sheet.contentView addSubview:toggle];

    UIVisualEffectView *devicesRow =
        [self glassCardWithFrame:CGRectMake(16, 338, sheet.bounds.size.width - 32, 68) radius:18];
    [sheet.contentView addSubview:devicesRow];

    UIImageView *devIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"hifispeaker.2"]];
    devIcon.tintColor = [UIColor colorWithWhite:1 alpha:.82];
    devIcon.frame = CGRectMake(18, 20, 28, 28);
    [devicesRow.contentView addSubview:devIcon];

    UILabel *devicesLabel = [[UILabel alloc] initWithFrame:CGRectMake(58, 0, devicesRow.bounds.size.width - 110, 68)];
    devicesLabel.text = @"Toista musiikkia laitteillasi";
    devicesLabel.textColor = UIColor.whiteColor;
    devicesLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [devicesRow.contentView addSubview:devicesLabel];

    UIImageView *chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chev.tintColor = [UIColor colorWithWhite:1 alpha:.7];
    chev.frame = CGRectMake(devicesRow.bounds.size.width - 42, 22, 24, 24);
    [devicesRow.contentView addSubview:chev];

    CGFloat buttonW = (sheet.bounds.size.width - 50) / 2.0;
    NSArray<NSString *> *titles = @[@"Aloita Jam", @"Bluetooth ja AirPlay"];
    NSArray<NSString *> *icons = @[@"person.2.wave.2", @"airplayaudio"];

    for (NSInteger i = 0; i < 2; i++) {
        UIVisualEffectView *card =
            [self glassCardWithFrame:CGRectMake(16 + i * (buttonW + 18),
                                                sheet.bounds.size.height - 92,
                                                buttonW,
                                                72)
                              radius:20];
        [sheet.contentView addSubview:card];

        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icons[i]]];
        icon.tintColor = UIColor.whiteColor;
        icon.frame = CGRectMake(14, 22, 28, 28);
        [card.contentView addSubview:icon];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, buttonW - 54, 72)];
        label.text = titles[i];
        label.numberOfLines = 2;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
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

- (void)saveTapped {
    BOOL target = !self.liked;
    [self setLiked:target];
    if (self.saveHandler) self.saveHandler(target);

    if (target) {
        [self presentSaveSheet];
    }
}

- (void)deviceTapped {
    if (self.deviceHandler) self.deviceHandler();
    [self presentConnectSheet];
}

- (void)playTapped {
    if (self.playPauseHandler) self.playPauseHandler();
}

- (void)openTapped:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self];
    for (UIButton *button in @[self.deviceButton, self.saveButton, self.playButton]) {
        CGRect r = [button.superview convertRect:button.frame toView:self];
        if (CGRectContainsPoint(r, p)) return;
    }
    if (self.openHandler) self.openHandler();
}

@end
