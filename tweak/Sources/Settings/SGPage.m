#import "SGPage.h"
#import "SGPageStyle.h"
#import "Core/SGCore.h"
#import <QuartzCore/QuartzCore.h>


// Spotify's navigation controller asserts that everything on its stack is one of its own pages
// (SPNavigationController.m:645, "[viewController conformsToProtocol:@protocol(SPTPageController)]"),
// and the tab bar asks it for that page on every tab tap to log the interaction. A plain view
// controller of the mod's pushed onto that stack therefore takes the app down the next time a tab
// is pressed, from wherever it was left. The pages below answer the protocol's two questions
// instead and are registered as conforming at load; if the protocol is gone they are presented
// rather than pushed, so a rename in some later Spotify costs the push, not the app.
static BOOL sg_pagesConform;

// A quiet atmospheric gradient behind EliSpot settings, drawn only when a
// custom accent is selected. This is a real UITableView backgroundView rather
// than a decorative image: it fits every screen size and cannot cover cells.
@interface SGAmbientSettingsBackground : UIView
- (instancetype)initWithColor:(UIColor *)accent;
@end
@implementation SGAmbientSettingsBackground {
    CAGradientLayer *_gradient;
}
- (instancetype)initWithColor:(UIColor *)accent {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [accent getRed:&red green:&green blue:&blue alpha:&alpha];
    _gradient = [CAGradientLayer layer];
    _gradient.colors = @[
        (id)[UIColor colorWithRed:0.014 + red * 0.16 green:0.014 + green * 0.16 blue:0.018 + blue * 0.16 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.012 + red * 0.07 green:0.012 + green * 0.07 blue:0.018 + blue * 0.07 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.008 green:0.008 blue:0.016 alpha:1].CGColor,
    ];
    _gradient.locations = @[@0, @0.53, @1];
    [self.layer addSublayer:_gradient];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
}
@end

@implementation SGPage

// Inset grouped cards on Spotify's dark grey, a hairline between the rows of a card.
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = SGPageBackground();
    NSString *accentKey = SGRedesignedUI() ? @"spotifyglass.redesign.accent" : @"spotifyglass.accent";
    NSInteger rgb = SGInt(accentKey, -1);
    if (rgb >= 0 && rgb <= 0xFFFFFF) {
        UIColor *accent = [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                                         green:((rgb >> 8) & 255) / 255.0
                                          blue:(rgb & 255) / 255.0 alpha:1];
        self.tableView.backgroundView = [[SGAmbientSettingsBackground alloc] initWithColor:accent];
    }
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.1];
    self.tableView.sectionHeaderTopPadding = 0;
}

- (NSString *)spt_pageIdentifier {
    return @"spotifyglass";
}

- (NSURL *)spt_pageURI {
    return [NSURL URLWithString:@"spotify:internal:spotifyglass"];
}

@end

void SGRegisterPages(void) {
    // Swift's own name for the protocol, which is what the runtime registers it under.
    Protocol *page = objc_getProtocol("_TtP19Tome_PageAttributes17SPTPageController_") ?: objc_getProtocol("SPTPageController");
    sg_pagesConform = page && class_addProtocol(SGPage.class, page);
    if (!sg_pagesConform) SGLog(@"%@", @"SPTPageController not found, the mod's pages are presented instead of pushed");
}

void SGShowPage(UIViewController *owner, UIViewController *page) {
    if (owner.navigationController && sg_pagesConform) [owner.navigationController pushViewController:page animated:YES];
    else [owner presentViewController:[[UINavigationController alloc] initWithRootViewController:page] animated:YES completion:nil];
}
