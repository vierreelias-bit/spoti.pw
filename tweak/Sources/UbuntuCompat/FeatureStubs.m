#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Shared/Player/SpeedPitch.h"
#import "Shared/Haptics/Haptics.h"
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

// The Linux build has no libjamesdsp engine, but it DOES compile the
// independent Speed/Pitch audio unit and Music Haptics implementation.
// Expose only controls that really connect to those parts of the tweak.
UIViewController *SGDSPSettingsPage(void) {
    SGModRow *speed = SGSliderRow(@"Playback speed", @"Changes playback tempo when available.",
        0.5, 2.0, 0.05,
        ^double { return SGPlayerSpeed(); },
        ^(double value) { if (SGPlayerSpeedAllowed()) SGSetPlayerSpeed(value); },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%.2f×", value]; });
    speed.visible = ^BOOL { return SGPlayerSpeedAllowed(); };

    SGModRow *pitch = SGSliderRow(@"Pitch", @"Change the sound by semitones.",
        -12.0, 12.0, 1.0,
        ^double { return SGPlayerPitch(); },
        ^(double value) { if (SGPlayerPitchAvailable()) SGSetPlayerPitch(value); },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%+.0f st", value]; });
    pitch.visible = ^BOOL { return SGPlayerPitchAvailable(); };

    SGModRow *speedStatus = SGStatRow(@"Playback speed", ^NSString * {
        return SGPlayerSpeedAllowed() ? @"Available" : @"Waiting for audio";
    });
    speedStatus.visible = ^BOOL { return !SGPlayerSpeedAllowed(); };

    SGModRow *pitchStatus = SGStatRow(@"Pitch", ^NSString * {
        return SGPlayerPitchAvailable() ? @"Available" : @"Waiting for audio";
    });
    pitchStatus.visible = ^BOOL { return !SGPlayerPitchAvailable(); };

    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithArray:@[
        SGNotedSection(@"Sound processing", @[
            speed, speedStatus, pitch, pitchStatus,
            SGActionRow(@"Reset sound changes", nil, ^{
                SGSetPlayerSpeed(1.0);
                SGSetPlayerPitch(0.0f);
            }),
        ], @"These controls use EliSpot's built-in audio unit. Start playback before opening this page. Availability depends on the device and playback output."),
        SGNotedSection(@"Advanced effects", @[
            SGStatRow(@"JamesDSP equalizer / bass / reverb", ^NSString * { return @"Mac build only"; }),
        ], @"Ubuntu/WSL does not build the JamesDSP engine yet. The effects listed above are real controls; the JamesDSP effects are not enabled."),
    ]];
    // Music Haptics runs on the same audio output via its existing Core Haptics
    // implementation. Reuse the same settings rather than creating fake effects.
    [sections addObjectsFromArray:SGVibrationsSections()];
    return [[SGModPage alloc] initWithTitle:@"Audio effects" intro:nil sections:sections footer:nil];
}

NSString *SGDSPSummary(void) {
    return @"Speed, pitch & haptics";
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
