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
            (id)[UIColor colorWithRed:1 green:.10 blue:.22 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:1 green:.56 blue:.08 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:.15 green:1 blue:.42 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:.05 green:.76 blue:1 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:.60 green:.12 blue:1 alpha:.95].CGColor,
            (id)[UIColor colorWithRed:1 green:.10 blue:.22 alpha:.95].CGColor
        ];
        [self.layer addSublayer:_gradient];

        _maskLayer = [CAShapeLayer layer];
        _maskLayer.fillColor = UIColor.clearColor.CGColor;
        _maskLayer.strokeColor = UIColor.whiteColor.CGColor;
        _maskLayer.lineWidth = 2.2;
        _gradient.mask = _maskLayer;

        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0;
        spin.toValue = @(M_PI * 2.0);
        spin.duration = 3.8;
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
    Class cls = NSClassFromString(@"UIGlassEffect");
    if (cls) return [[cls alloc] init];
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

    self.backgroundColor = UIColor.clearColor;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = .35;
    self.layer.shadowRadius = 24;
    self.layer.shadowOffset = CGSizeMake(0, 10);

    _pill = [[UIVisualEffectView alloc] initWithEffect:ELGlassEffect()];
    _pill.layer.cornerRadius = 38;
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    _pill.layer.borderWidth = .7;
    _pill.layer.borderColor = [UIColor colorWithWhite:1 alpha:.20].CGColor;
    _pill.clipsToBounds = YES;
    [self addSubview:_pill];

    UIView *dark = [UIView new];
    dark.backgroundColor = [UIColor colorWithWhite:0 alpha:.22];
    dark.tag = 101;
    [_pill.contentView addSubview:dark];

    _lens = [[UIVisualEffectView alloc] initWithEffect:ELGlassEffect()];
    _lens.layer.cornerRadius = 52;
    _lens.layer.cornerCurve = kCACornerCurveContinuous;
    _lens.layer.borderWidth = .9;
    _lens.layer.borderColor = [UIColor colorWithWhite:1 alpha:.34].CGColor;
    _lens.clipsToBounds = YES;
    [self addSubview:_lens];

    UIView *shine = [UIView new];
    shine.backgroundColor = [UIColor colorWithWhite:1 alpha:.06];
    shine.tag = 102;
    [_lens.contentView addSubview:shine];

    _ring = [ELRGBRing new];
    [self addSubview:_ring];

    NSArray *icons = @[@"house.fill", @"magnifyingglass", @"books.vertical.fill", @"plus"];
    NSArray *titles = @[@"Koti", @"Haku", @"Kirjasto", @"Luo"];
    NSMutableArray *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = i;

        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:21 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:icons[i] withConfiguration:symbolConfig];

        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
            config.image = image;
            config.title = titles[i];
            config.imagePlacement = NSDirectionalRectEdgeTop;
            config.imagePadding = 3;
            config.baseForegroundColor = UIColor.whiteColor;
            config.contentInsets = NSDirectionalEdgeInsetsMake(5, 2, 4, 2);
            button.configuration = config;
        }

        [button addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_pill.contentView addSubview:button];
        [buttons addObject:button];
    }

    self.buttons = buttons;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragLens:)];
    [self addGestureRecognizer:pan];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.pill.frame = self.bounds;
    [self.pill.contentView viewWithTag:101].frame = self.pill.bounds;

    CGFloat pad = 8;
    self.itemWidth = (self.bounds.size.width - pad * 2) / 4.0;
    for (NSInteger i = 0; i < 4; i++) {
        self.buttons[i].frame = CGRectMake(pad + self.itemWidth * i, 5, self.itemWidth, self.bounds.size.height - 10);
    }

    if (!self.dragging) [self placeLensAtIndex:self.selectedIndex];
    [self.lens.contentView viewWithTag:102].frame = self.lens.bounds;
}

- (CGFloat)centerForIndex:(NSInteger)index {
    return 8 + self.itemWidth * index + self.itemWidth / 2.0;
}

- (void)placeLensAtIndex:(NSInteger)index {
    CGFloat size = 104;
    CGFloat x = [self centerForIndex:index];
    self.lens.frame = CGRectMake(x - size/2, (self.bounds.size.height-size)/2, size, size);
    self.ring.frame = CGRectInset(self.lens.frame, -4, -4);
}

- (void)refreshButtons {
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = self.buttons[i];
        BOOL active = i == self.selectedIndex;
        button.alpha = active ? 1.0 : .66;
        button.transform = active ? CGAffineTransformMakeScale(1.08, 1.08) : CGAffineTransformIdentity;
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated {
    index = MAX(0, MIN(3, index));
    self.selectedIndex = index;
    ELSetSelectedIndex(self.tabHost, index);

    void (^changes)(void) = ^{
        [self placeLensAtIndex:index];
        [self refreshButtons];
    };

    if (animated) {
        [UIView animateWithDuration:.36
                              delay:0
             usingSpringWithDamping:.74
              initialSpringVelocity:.45
                            options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)tabPressed:(UIButton *)sender {
    [self selectIndex:sender.tag animated:YES];
    [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}

- (void)dragLens:(UIPanGestureRecognizer *)pan {
    CGPoint p = [pan locationInView:self];
    CGFloat minX = [self centerForIndex:0];
    CGFloat maxX = [self centerForIndex:3];
    CGFloat x = MAX(minX, MIN(maxX, p.x));

    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        self.dragging = YES;
        self.lens.center = CGPointMake(x, CGRectGetMidY(self.bounds));
        self.ring.center = self.lens.center;

        NSInteger nearest = lround((x-minX)/self.itemWidth);
        nearest = MAX(0, MIN(3, nearest));
        if (nearest != self.selectedIndex) {
            self.selectedIndex = nearest;
            ELSetSelectedIndex(self.tabHost, nearest);
            [self refreshButtons];
            [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
        }
    } else {
        self.dragging = NO;
        [self selectIndex:self.selectedIndex animated:YES];
    }
}

- (void)syncSelection {
    NSInteger index = ELSelectedIndex(self.tabHost);
    if (index >= 0 && index < 4 && index != self.selectedIndex && !self.dragging) {
        self.selectedIndex = index;
        [self setNeedsLayout];
        [self refreshButtons];
    }
}

@end
