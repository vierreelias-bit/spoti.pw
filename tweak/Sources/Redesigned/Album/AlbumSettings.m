// EliSpot v30: redesigned album settings implemented independently.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Album.h"

UIViewController *SGRAlbumSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Albums"
        intro:SGRestartNote
        sections:@[
            SGSection(@"Track list", @[
                SGHideRow(@"Hide track artists",
                          @"Hide the subtitle below songs on album pages.",
                          SGRKeyHideAlbumTrackArtists),
            ]),
        ]
        footer:nil];
}
