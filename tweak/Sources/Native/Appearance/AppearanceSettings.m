#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Appearance.h"

// Going back to Spotify's green is offered only once a colour of the mod's is set, so a stray tap
// cannot wipe it.
// EliSpot v30: original accent presets; individual selections use the same
// preference as the standard colour picker. Changes take effect on restart.
static void chooseAccent(void) {
    UIViewController *top = SGTopController();
    if (!top) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:SGT(@"Accent colour")
        message:SGT(@"Choose a preset or your own colour. Restart Spotify to apply.")
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:SGT(@"Pick a colour")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) { SGPickAccent(); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SGT(@"Apple Music red")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) { SGSetInt(SGKeyAccent, 0xFA233B); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SGT(@"Spotify green")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) { SGSetInt(SGKeyAccent, -1); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:SGT(@"Cancel")
        style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 0, 0);
    sheet.popoverPresentationController.permittedArrowDirections = 0;
    [top presentViewController:sheet animated:YES completion:nil];
}

// The native look's rows of the Appearance card (App/Pages.m).
NSArray<SGModRow *> *SGNativeAppearanceRows(void) {
    return @[
        SGWithSymbol(SGOptionRow(@"AMOLED background", nil, SGKeyAmoled), @"moon"),
        SGWithSymbol(SGStatActionRow(@"Accent colour", nil, ^NSString *{ return SGAccentLabel(); }, ^{ chooseAccent(); }), @"paintpalette"),
    ];
}
