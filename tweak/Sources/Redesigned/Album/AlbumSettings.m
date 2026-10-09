// EliSpot v30: redesigned album settings implemented independently.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Album.h"

UIViewController *SGRAlbumSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Albums"
        intro:SGRestartNote
        sections:@[
            SGSection(@"Artwork", @[
                SGOptionRow(@"Animated cover motion",
                            @"Moves still cover art, not original video. Respects Reduce Motion and Low Power Mode.",
                            SGRKeyArtworkMotion),
            ]),
            SGSection(@"Track list", @[
                SGHideRow(@"Hide track artists",
                          @"Hide the subtitle below songs on album pages.",
                          SGRKeyHideAlbumTrackArtists),
            ]),
            SGSection(@"Extra sections", @[
                SGOptionRow(@"Show extra album sections",
                            @"Show album recommendations, videos and other sections below the tracks.",
                            SGRKeyShowAlbumExtraSections),
            ]),
        ]
        footer:nil];
}
