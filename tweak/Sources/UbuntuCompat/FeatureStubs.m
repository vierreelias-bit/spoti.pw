#import <UIKit/UIKit.h>
#import "Shared/JamesDSP/JamesDSPPage.h"
#import "Shared/LiveActivity/LiveActivity.h"

static UIViewController *ELUnavailablePage(NSString *title, NSString *message) {
    UIViewController *vc = [UIViewController new];
    vc.title = title;
    vc.view.backgroundColor = UIColor.blackColor;

    UILabel *label = [UILabel new];
    label.text = message;
    label.textColor = [UIColor colorWithWhite:1 alpha:.72];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:28],
        [label.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-28],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
    ]];
    return vc;
}

UIViewController *SGDSPSettingsPage(void) {
    return ELUnavailablePage(@"Audio effects",
        @"JamesDSP source is included in EliSpot, but the Ubuntu/WSL .deb build skips its Apple-specific engine build.");
}

NSString *SGDSPSummary(void) {
    return @"Ubuntu build";
}

UIViewController *SGDSPLibraryPage(SGDSPFileKind kind) {
    (void)kind;
    return SGDSPSettingsPage();
}

UIViewController *SGDSPGraphicEqPage(void) {
    return SGDSPSettingsPage();
}

NSString *SGDSPChosenFile(SGDSPFileKind kind) {
    (void)kind;
    return @"Unavailable";
}

void SGSetLiveActivityEnabled(BOOL on) {
    (void)on;
}

UIViewController *SGLiveActivitySettingsPage(void) {
    return ELUnavailablePage(@"Live Activity",
        @"Live Activity and Dynamic Island source is included in EliSpot, but building it requires Apple's Swift/ActivityKit toolchain.");
}

NSString *SGLiveActivitySummary(void) {
    return @"Mac build only";
}
