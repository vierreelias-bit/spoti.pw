#import "ELGlassTabBar.h"
#import "ELRuntime.h"
#import <QuartzCore/QuartzCore.h>

@interface ELRGBRing : UIView
@property(nonatomic,strong) CAGradientLayer *gradient;
@property(nonatomic,strong) CAShapeLayer *maskLayer;
@end

@implementation ELRGBRing
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = UIColor.clearColor;

        _gradient = [CAGradientLayer layer];
        _gradient.type = kCAGradientLayerConic;
        _gradient.startPoint = CGPointMake(.5, .5);
        _gradient.endPoint = CGPointMake(1, .5);
        _gradient.colors = @[
            (id)[UIColor colorWithRed:1 green:.12 blue:.32 alpha:.72].CGColor,
            (id)[UIColor colorWithRed:1 green:.68 blue:.12 alpha:.68].CGColor,
            (id)[UIColor colorWithRed:.22 green:1 blue:.56 alpha:.68].CGColor,
            (id)[UIColor colorWithRed:.12 green:.72 blue:1 alpha:.72].CGColor,
            (id)[UIColor colorWithRed:.66 green:.20 blue:1 alpha:.72].CGColor,
            (id)[UIColor colorWithRed:1 green:.12 blue:.32 alpha:.72].CGColor
        ];
        [self.layer addSublayer:_gradient];

        _maskLayer = [CAShapeLayer layer];
        _maskLayer.fillColor = UIColor.clearColor.CGColor;
        _maskLayer.strokeColor = UIColor.whiteColor.CGColor;
        _maskLayer.lineWidth = .85;
        _gradient.mask = _maskLayer;
        _gradient.opacity = .42;
        self.alpha = .70;
        self.layer.shadowColor = UIColor.whiteColor.CGColor;
        self.layer.shadowOpacity = .22;
        self.layer.shadowRadius = 9.0;
        self.layer.shadowOffset = CGSizeZero;

        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0;
        spin.toValue = @(M_PI * 2.0);
        spin.duration = 7.0;
        spin.repeatCount = HUGE_VALF;
        [_gradient addAnimation:spin forKey:@"elispot.rgb"];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradient.frame = self.bounds;
    self.maskLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, 1.5, 1.5)].CGPath;
}
@end

static UIVisualEffect *ELGlassEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

@interface ELGlassTabBar ()
@property(nonatomic,strong) UIVisualEffectView *pill;
@property(nonatomic,strong) UIVisualEffectView *lens;
@property(nonatomic,strong) ELRGBRing *ring;
@property(nonatomic,strong) NSArray<UIButton *> *buttons;
@property(nonatomic,assign) NSInteger selectedIndex;
@property(nonatomic,assign) NSInteger previewIndex;
@property(nonatomic,assign) BOOL dragging;
@property(nonatomic,assign) CGFloat itemWidth;
@end

@implementation ELGlassTabBar

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .30;
    self.layer.shadowRadius = 22;
    self.layer.shadowOffset = CGSizeMake(0, 10);

    _pill = [[UIVisualEffectView alloc] initWithEffect:ELGlassEffect()];
    _pill.layer.cornerRadius = 34;
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    _pill.layer.borderWidth = .7;
    _pill.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    _pill.clipsToBounds = YES;
    [self addSubview:_pill];

    UIView *shade = [UIView new];
    shade.tag = 1001;
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:.055];
    [_pill.contentView addSubview:shade];

    _lens = [[UIVisualEffectView alloc] initWithEffect:ELGlassEffect()];
    _lens.userInteractionEnabled = NO;
    _lens.layer.cornerRadius = 32;
    _lens.layer.cornerCurve = kCACornerCurveContinuous;
    _lens.layer.borderWidth = .8;
    _lens.layer.borderColor = [UIColor colorWithWhite:1 alpha:.28].CGColor;
    _lens.clipsToBounds = YES;
    [self addSubview:_lens];

    UIView *shine = [UIView new];
    shine.tag = 1002;
    shine.backgroundColor = [UIColor colorWithWhite:1 alpha:.035];
    [_lens.contentView addSubview:shine];

    _ring = [ELRGBRing new];
    [self addSubview:_ring];

    NSArray<NSString *> *icons = @[@"house.fill", @"magnifyingglass", @"books.vertical.fill", @"plus"];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = i;
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:.018];
        button.tintColor = UIColor.whiteColor;
        button.layer.cornerRadius = 22;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.layer.borderWidth = .45;
        button.layer.borderColor = [UIColor colorWithWhite:1 alpha:.07].CGColor;

        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
        [button setImage:[UIImage systemImageNamed:icons[i] withConfiguration:cfg] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];

        [self addSubview:button];
        [buttons addObject:button];
    }
    self.buttons = buttons;

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragLens:)];
    pan.cancelsTouchesInView = NO;
    [self addGestureRecognizer:pan];

    self.selectedIndex = 0;
    self.previewIndex = 0;
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.pill.frame = CGRectInset(self.bounds, 0, 2);
    [self.pill.contentView viewWithTag:1001].frame = self.pill.bounds;

    CGFloat pad = 8;
    self.itemWidth = (self.bounds.size.width - pad * 2) / 4.0;

    for (NSInteger i = 0; i < self.buttons.count; i++) {
        CGFloat buttonSide = 44.0;
        CGFloat cx = pad + self.itemWidth * i + self.itemWidth / 2.0;
        self.buttons[i].frame = CGRectMake(cx - buttonSide / 2.0,
                                           (self.bounds.size.height - buttonSide) / 2.0,
                                           buttonSide,
                                           buttonSide);
    }

    if (!self.dragging) [self placeLens:self.selectedIndex];
    [self.lens.contentView viewWithTag:1002].frame = self.lens.bounds;
}

- (CGFloat)centerForIndex:(NSInteger)index {
    return 8 + self.itemWidth * index + self.itemWidth / 2.0;
}

- (void)placeLens:(NSInteger)index {
    CGFloat size = MIN(64.0, self.bounds.size.height - 6.0);
    CGFloat x = [self centerForIndex:index];
    self.lens.frame = CGRectMake(x - size / 2.0,
                                 (self.bounds.size.height - size) / 2.0,
                                 size,
                                 size);
    self.ring.frame = CGRectInset(self.lens.frame, -2.0, -2.0);
}

- (void)refreshButtonsForIndex:(NSInteger)index {
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *button = self.buttons[i];
        BOOL active = i == index;
        button.alpha = active ? .98 : .52;
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:(active ? .045 : .015)];
        button.transform = active ? CGAffineTransformMakeScale(1.03, 1.03)
                                  : CGAffineTransformIdentity;
    }
}

- (void)commitIndex:(NSInteger)index animated:(BOOL)animated {
    index = MAX(0, MIN(3, index));
    NSInteger old = self.selectedIndex;
    self.selectedIndex = index;
    self.previewIndex = index;

    if (self.spotifyTabBar) ELActivateSpotifyTab(self.spotifyTabBar, index);

    void (^changes)(void) = ^{
        [self placeLens:index];
        [self refreshButtonsForIndex:index];
    };

    if (animated) {
        [UIView animateWithDuration:.34
                              delay:0
             usingSpringWithDamping:.78
              initialSpringVelocity:.35
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }

    if (old != index) {
        [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    }
}

- (void)tabPressed:(UIButton *)sender {
    [self commitIndex:sender.tag animated:YES];
}

- (void)dragLens:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan locationInView:self];
    CGFloat minX = [self centerForIndex:0];
    CGFloat maxX = [self centerForIndex:3];
    CGFloat x = MAX(minX, MIN(maxX, point.x));

    if (pan.state == UIGestureRecognizerStateBegan ||
        pan.state == UIGestureRecognizerStateChanged) {
        self.dragging = YES;
        self.lens.center = CGPointMake(x, CGRectGetMidY(self.bounds));
        self.ring.center = self.lens.center;

        NSInteger nearest = lround((x - minX) / self.itemWidth);
        self.previewIndex = MAX(0, MIN(3, nearest));
        [self refreshButtonsForIndex:self.previewIndex];
        return;
    }

    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled ||
        pan.state == UIGestureRecognizerStateFailed) {
        self.dragging = NO;
        [self commitIndex:self.previewIndex animated:YES];
    }
}

- (void)syncFromSpotify {
    if (!self.spotifyTabBar || self.dragging) return;
    NSInteger index = ELSpotifySelectedIndex(self.spotifyTabBar);
    if (index == NSNotFound || index < 0 || index > 3) {
        [self refreshButtonsForIndex:self.selectedIndex];
        return;
    }

    self.selectedIndex = index;
    self.previewIndex = index;
    [self placeLens:index];
    [self refreshButtonsForIndex:index];
}

- (void)setGlassOpacity:(CGFloat)opacity {
    CGFloat value = MIN(1.0, MAX(0.20, opacity));
    self.pill.alpha = value;
    self.lens.alpha = value;
    self.ring.alpha = MIN(1.0, value + .05);
}

@end
