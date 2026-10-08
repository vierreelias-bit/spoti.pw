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
            (id)[UIColor colorWithRed:1 green:.08 blue:.25 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:1 green:.58 blue:.08 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:.15 green:1 blue:.42 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:.04 green:.78 blue:1 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:.62 green:.10 blue:1 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:1 green:.08 blue:.25 alpha:.95].CGColor
        ];
        [self.layer addSublayer:_gradient];

        _maskLayer = [CAShapeLayer layer];
        _maskLayer.fillColor = UIColor.clearColor.CGColor;
        _maskLayer.strokeColor = UIColor.whiteColor.CGColor;
        _maskLayer.lineWidth = 2.0;
        _gradient.mask = _maskLayer;

        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0;
        spin.toValue = @(M_PI * 2.0);
        spin.duration = 4.0;
        spin.repeatCount = HUGE_VALF;
        [_gradient addAnimation:spin forKey:@"elispot.rgb"];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradient.frame = self.bounds;
    self.maskLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, 2, 2)].CGPath;
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
@property(nonatomic,assign) BOOL dragging;
@property(nonatomic,assign) CGFloat itemWidth;
@end

@implementation ELGlassTabBar

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .32;
    self.layer.shadowRadius = 24;
    self.layer.shadowOffset = CGSizeMake(0, 10);

    _pill = [[UIVisualEffectView alloc] initWithEffect:ELGlassEffect()];
    _pill.layer.cornerRadius = 38;
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    _pill.layer.borderWidth = .65;
    _pill.layer.borderColor = [UIColor colorWithWhite:1 alpha:.20].CGColor;
    _pill.clipsToBounds = YES;
    [self addSubview:_pill];

    UIView *dark = [UIView new];
    dark.tag = 1001;
    dark.backgroundColor = [UIColor colorWithWhite:0 alpha:.20];
    [_pill.contentView addSubview:dark];

    _lens = [[UIVisualEffectView alloc] initWithEffect:ELGlassEffect()];
    _lens.layer.cornerRadius = 52;
    _lens.layer.cornerCurve = kCACornerCurveContinuous;
    _lens.layer.borderWidth = .9;
    _lens.layer.borderColor = [UIColor colorWithWhite:1 alpha:.36].CGColor;
    _lens.clipsToBounds = YES;
    [self addSubview:_lens];

    UIView *shine = [UIView new];
    shine.tag = 1002;
    shine.backgroundColor = [UIColor colorWithWhite:1 alpha:.065];
    [_lens.contentView addSubview:shine];

    _ring = [ELRGBRing new];
    [self addSubview:_ring];

    NSArray *icons = @[@"house.fill", @"magnifyingglass", @"books.vertical.fill", @"plus"];
    NSArray *titles = @[@"Koti", @"Haku", @"Kirjasto", @"Luo"];
    NSMutableArray *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = i;

        UIImageSymbolConfiguration *sym =
            [UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:icons[i] withConfiguration:sym];

        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
            cfg.image = image;
            cfg.title = titles[i];
            cfg.imagePlacement = NSDirectionalRectEdgeTop;
            cfg.imagePadding = 3;
            cfg.baseForegroundColor = UIColor.whiteColor;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(5, 2, 4, 2);
            button.configuration = cfg;
        }

        [button addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_pill.contentView addSubview:button];
        [buttons addObject:button];
    }

    self.buttons = buttons;

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragLens:)];
    [self addGestureRecognizer:pan];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.pill.frame = self.bounds;
    [self.pill.contentView viewWithTag:1001].frame = self.pill.bounds;

    CGFloat pad = 8;
    self.itemWidth = (self.bounds.size.width - pad * 2) / 4.0;

    for (NSInteger i = 0; i < self.buttons.count; i++) {
        self.buttons[i].frame = CGRectMake(
            pad + self.itemWidth * i, 5, self.itemWidth, self.bounds.size.height - 10
        );
    }

    if (!self.dragging) [self placeLens:self.selectedIndex];
    [self.lens.contentView viewWithTag:1002].frame = self.lens.bounds;
}

- (CGFloat)centerForIndex:(NSInteger)index {
    return 8 + self.itemWidth * index + self.itemWidth / 2.0;
}

- (void)placeLens:(NSInteger)index {
    CGFloat size = 104;
    CGFloat x = [self centerForIndex:index];
    self.lens.frame = CGRectMake(x - size/2, (self.bounds.size.height-size)/2, size, size);
    self.ring.frame = CGRectInset(self.lens.frame, -4, -4);
}

- (void)refreshButtons {
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        BOOL active = i == self.selectedIndex;
        UIButton *button = self.buttons[i];
        button.alpha = active ? 1.0 : .64;
        button.transform = active ? CGAffineTransformMakeScale(1.08, 1.08)
                                  : CGAffineTransformIdentity;
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated activate:(BOOL)activate {
    index = MAX(0, MIN(3, index));
    self.selectedIndex = index;

    if (activate && self.spotifyTabBar) {
        ELActivateSpotifyTab(self.spotifyTabBar, index);
    }

    void (^changes)(void) = ^{
        [self placeLens:index];
        [self refreshButtons];
    };

    if (animated) {
        [UIView animateWithDuration:.36
                              delay:0
             usingSpringWithDamping:.74
              initialSpringVelocity:.45
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)tabPressed:(UIButton *)sender {
    [self selectIndex:sender.tag animated:YES activate:YES];
    [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
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
        nearest = MAX(0, MIN(3, nearest));

        if (nearest != self.selectedIndex) {
            self.selectedIndex = nearest;
            if (self.spotifyTabBar) ELActivateSpotifyTab(self.spotifyTabBar, nearest);
            [self refreshButtons];
            [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
        }
    } else {
        self.dragging = NO;
        [self selectIndex:self.selectedIndex animated:YES activate:NO];
    }
}

- (void)syncFromSpotify {
    // We keep the custom state when Spotify does not expose a stable public selected index.
    [self refreshButtons];
}

@end
