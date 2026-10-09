#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Pages.h"
#import "Shared/ArtistBlock/ArtistBlock.h"
#import "Shared/Gestures/Gestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerSettings.h"
#import "Native/Appearance/Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Native/NowPlayingBar/NowPlayingBar.h"
#import "Native/Player/NowPlaying.h"
#import "Shared/Haptics/Haptics.h"
#import "Shared/LiveActivity/LiveActivity.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Redesigned/Kit/SGRAccent.h"
#import "Redesigned/Player/Player.h"
#import "Redesigned/Kit/SGRArtworkMotion.h"

NSString *const SGRedesignedUIInfo = @"EliSpot's Apple Music-inspired redesign. This is an independent look, not Apple Music itself. It uses its own appearance settings and, on supported iOS versions, system Liquid Glass.\n\nThe original Spotify-style interface remains available as the legacy look.";

void SGSetRedesignedUI(BOOL on) {
    SGSetEnabled(SGKeyRedesign, on);
}

// The whole look changes hands at launch, so the switch asks for the restart straight away rather than
// leaving Spotify half in the old look.
static void offerRestart(BOOL on) {
    NSString *message = on
        ? @"The redesigned look will be used when Spotify restarts."
        : @"Your selected Spotify-style theme will be used when Spotify restarts.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"Restart Spotify")
        message:SGT(message) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SGT(@"Later") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:SGT(@"Restart now") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { SGRestartSpotify(); }]];
    [SGTopController() presentViewController:alert animated:YES completion:nil];
}

// Below iOS 26 the row is not a switch: Liquid Glass is the redesign, and the system draws it from
// that version on, so the row reads out what is missing and the card carries the native look's rows alone.
static SGModRow *unavailableRow(void) {
    SGModRow *row = SGStatActionRow(@"Redesigned UI", nil, ^NSString *{ return @"Needs iOS 26"; }, ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Redesigned UI"
            message:[NSString stringWithFormat:@"The redesign is built on Liquid Glass, which iOS 26 draws and no earlier version can. This phone runs iOS %@, so the mod gives you its legacy look instead: Spotify's own screens with everything else the mod adds on them.", UIDevice.currentDevice.systemVersion]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
    });
    return SGWithSymbol(row, @"sparkles");
}

// EliSpot v30: a native theme picker backed by existing preference keys.
// No system or Spotify entitlement changes. A restart is needed because
// redesigned-vs-native hooks are selected at process launch.
static void applyTheme(NSInteger theme) {
    BOOL redesign = theme >= 2 && SGRedesignAvailable();
    SGSetRedesignedUI(redesign);
    SGSetEnabled(SGKeyAmoled, theme != 0);
    NSInteger accent = -1;
    if (theme == 2) accent = 0xFA233B;       // Apple Music-inspired red
    if (theme == 3) accent = 0x588BFF;       // Midnight blue
    if (theme == 4) accent = 0xAD72F8;       // Violet
    SGSetInt(SGKeyAccent, accent);
    SGSetInt(SGRKeyAccent, accent);
    SGSetEnabled(SGRKeyPlayerMotion, redesign);
    SGSetEnabled(SGRKeyArtworkMotion, theme == 2);
}

static NSString *themeSummary(void) {
    BOOL redesign = SGFlag(SGKeyRedesign, NO);
    NSInteger accent = SGInt(redesign ? SGRKeyAccent : SGKeyAccent, -1);
    if (redesign) {
        if (accent == 0xFA233B) return SGT(@"Apple Music style");
        if (accent == 0x588BFF) return SGT(@"Midnight blue");
        if (accent == 0xAD72F8) return SGT(@"Violet");
        return SGT(@"Custom");
    }
    if (accent != -1) return SGT(@"Custom");
    return SGT(SGFlag(SGKeyAmoled, NO) ? @"AMOLED black" : @"Spotify default");
}

static SGModRow *themePickerRow(void) {
    SGModRow *row = SGStatActionRow(@"Theme",
        @"Choose a Spotify, AMOLED, Apple Music-inspired or coloured look.",
        ^NSString *{ return themeSummary(); }, ^{
            UIViewController *top = SGTopController();
            if (!top) return;
            UIAlertController *sheet = [UIAlertController alertControllerWithTitle:SGT(@"Theme")
                message:SGT(@"Pick a look. Use Accent colour for a custom colour. Changes require a Spotify restart.")
                preferredStyle:UIAlertControllerStyleActionSheet];
            NSArray<NSString *> *names = @[@"Spotify default", @"AMOLED black",
                                          @"Apple Music style", @"Midnight blue", @"Violet"];
            for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
                // Liquid Glass requires iOS 26+, so never offer unsupported
                // themes that would silently fail on an older device.
                if (i >= 2 && !SGRedesignAvailable()) continue;
                [sheet addAction:[UIAlertAction actionWithTitle:SGT(names[(NSUInteger)i])
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        applyTheme(i);
                        offerRestart(i >= 2);
                    }]];
            }
            [sheet addAction:[UIAlertAction actionWithTitle:SGT(@"Cancel")
                style:UIAlertActionStyleCancel handler:nil]];
            if (sheet.popoverPresentationController) {
                sheet.popoverPresentationController.sourceView = top.view;
                sheet.popoverPresentationController.sourceRect =
                    CGRectMake(CGRectGetMidX(top.view.bounds),
                               CGRectGetMidY(top.view.bounds), 0, 0);
                sheet.popoverPresentationController.permittedArrowDirections = 0;
            }
            [top presentViewController:sheet animated:YES completion:nil];
        });
    return SGWithSymbol(row, @"paintpalette.fill");
}

SGModSection *SGAppearanceSection(void) {
    if (!SGRedesignAvailable()) {
        NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObjects:unavailableRow(), themePickerRow(), nil];
        [rows addObjectsFromArray:SGNativeAppearanceRows()];
        return SGNotedSection(@"Appearance", rows, @"Changes apply after you restart Spotify.");
    }
    SGModRow *redesign = SGOptionRow(@"Redesigned UI", nil, SGKeyRedesign);
    redesign.glows = YES;
    redesign.info = SGRedesignedUIInfo;
    redesign.changed = ^(BOOL on) {
        SGSetRedesignedUI(on);
        offerRestart(on);
    };
    NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObjects:SGWithSymbol(redesign, @"sparkles"), themePickerRow(), nil];
    [rows addObjectsFromArray:SGRedesignedUIStored() ? SGRAppearanceRows() : SGNativeAppearanceRows()];
    return SGNotedSection(@"Appearance", rows, @"Changes apply after you restart Spotify.");
}

UIViewController *SGNavbarPage(void) {
    return SGRedesignedUIStored() ? SGRNavbarSettingsPage() : SGNavbarSettingsPage();
}

// Pronunciation, translation and word sweeping exist only in the redesign's lyrics view.
static UIViewController *lyricsPage(void) {
    BOOL redesigned = SGRedesignedUIStored();
    NSMutableArray<SGModRow *> *more = [NSMutableArray arrayWithObject:SGLockScreenLyricsRow()];
    if (!redesigned) [more insertObject:SGGlassLyricsRow() atIndex:0];
    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObject:SGLyricsSourcesSection(redesigned)];
    if (redesigned) {
        [sections addObject:SGSection(@"Display", @[SGLyricsWordTimingRow(), SGRLyricsTextSizesRow(), SGLyricsTranslationLanguageRow()])];
    }
    [sections addObject:SGSection(nil, more)];
    return [[SGModPage alloc] initWithTitle:@"Lyrics" intro:SGRestartNote sections:sections footer:nil];
}

UIViewController *SGPlayerSettingsPage(void) {
    SGModRow *blocked = SGPageRow(@"Blocked artists", ^UIViewController *{ return SGArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return SGFlag(SGKeyArtistBlock, NO) ? @(SGBlockedArtists().count).stringValue : @"Off";
    };
    BOOL native = !SGRedesignedUIStored();

    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObject:SGSection(nil, @[
        SGWithSymbol(SGPageRow(@"Gestures", ^UIViewController *{ return SGGesturesSettingsPage(); }), @"hand.tap"),
        SGWithSymbol(SGPageRow(@"Lyrics", ^UIViewController *{ return lyricsPage(); }), @"quote.bubble"),
        SGWithSymbol(blocked, @"person.crop.circle.badge.xmark"),
    ])];
    NSMutableArray<SGModRow *> *pages = [NSMutableArray array];
    if (native) {
        [pages addObject:SGWithSymbol(SGPageRow(@"Now playing bar", ^UIViewController *{ return SGNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled")];
        [pages addObject:SGWithSymbol(SGPageRow(@"Queue & devices", ^UIViewController *{ return SGQueueSettingsPage(); }), @"text.line.first.and.arrowtriangle.forward")];
    } else {
        [pages addObject:SGWithSymbol(SGPageRow(@"Now playing", ^UIViewController *{ return SGRNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled")];
    }
    [pages addObject:SGWithSymbol(SGPageRow(@"Lock screen widget", ^UIViewController *{ return SGLockScreenWidgetPage(); }), @"lock")];
    [sections addObject:SGSection(nil, pages)];
    if (native) [sections addObjectsFromArray:SGNativePlayerScreenSections()];
    // Vibrations hook Spotify's own controls and its audio, so they answer under either look.
    [sections addObjectsFromArray:SGVibrationsSections()];

    return [[SGModPage alloc] initWithTitle:@"Player" intro:SGRestartNote sections:sections footer:nil];
}
