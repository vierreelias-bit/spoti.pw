#import "ELMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>

static UIVisualEffect *ELMiniGlass(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    if (glass) return [[glass alloc] init];
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

@interface ELMiniPlayer ()
@property(nonatomic,strong) UIVisualEffectView *glass;
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
    self.layer.shadowOpacity = .28;
    self.layer.shadowRadius = 18;
    self.layer.shadowOffset = CGSizeMake(0, 8);

    _glass = [[UIVisualEffectView alloc] initWithEffect:ELMiniGlass()];
    _glass.layer.cornerRadius = 22;
    _glass.layer.cornerCurve = kCACornerCurveContinuous;
    _glass.layer.borderWidth = .6;
    _glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:.16].CGColor;
    _glass.clipsToBounds = YES;
    [self addSubview:_glass];

    UIView *tint = [UIView new];
    tint.tag = 3001;
    tint.backgroundColor = [UIColor colorWithWhite:0 alpha:.18];
    [_glass.contentView addSubview:tint];

    _artworkView = [UIImageView new];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.layer.cornerRadius = 14;
    _artworkView.layer.cornerCurve = kCACornerCurveContinuous;
    _artworkView.clipsToBounds = YES;
    [_glass.contentView addSubview:_artworkView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.whiteColor;
    [_glass.contentView addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:.62];
    [_glass.contentView addSubview:_subtitleLabel];

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    _playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_playButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:cfg] forState:UIControlStateNormal];
    _playButton.tintColor = UIColor.whiteColor;
    [_glass.contentView addSubview:_playButton];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glass.frame = self.bounds;
    [self.glass.contentView viewWithTag:3001].frame = self.glass.bounds;

    CGFloat h = self.bounds.size.height;
    CGFloat art = h - 12;
    self.artworkView.frame = CGRectMake(6, 6, art, art);

    CGFloat textX = CGRectGetMaxX(self.artworkView.frame) + 10;
    CGFloat buttonW = 42;
    CGFloat textW = self.bounds.size.width - textX - buttonW - 10;

    self.titleLabel.frame = CGRectMake(textX, 12, textW, 18);
    self.subtitleLabel.frame = CGRectMake(textX, 31, textW, 16);
    self.playButton.frame = CGRectMake(self.bounds.size.width - buttonW - 4, (h-buttonW)/2, buttonW, buttonW);
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle artwork:(UIImage *)artwork {
    self.titleLabel.text = title.length ? title : @"Now Playing";
    self.subtitleLabel.text = subtitle.length ? subtitle : @"Spotify";
    self.artworkView.image = artwork;
}

@end
