// EliSpot v30: original preferences for the redesigned artist page.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Artist.h"

UIViewController *SGRArtistSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Artists"
        intro:SGRestartNote
        sections:@[
            SGSection(@"Sections", @[
                SGSwitchRow(@"Hide music videos",
                            @"Remove video shelves from redesigned artist pages.",
                            SGRKeyArtistHideVideos),
            ]),
        ]
        footer:nil];
}
