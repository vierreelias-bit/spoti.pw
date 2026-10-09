// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"
#import "Redesigned/Kit/SGRArtworkMotion.h"
#import "Redesigned/Kit/SGRAnimatedArtwork.h"
#import "Redesigned/Kit/SGRAppleCatalogLookup.h"

static SGModRow *appleCatalogSwitch(void) {
    SGModRow *row = SGOptionRow(@"Find album automatically",
        @"Optional: send the playing artist and album name to Apple's public catalog search.",
        SGRKeyAppleAlbumLookup);
    row.changed = ^(BOOL on) {
        if (on) SGRAppleCatalogSearchCurrent();
    };
    return row;
}

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", nil, SGRHideBarConnect),
        ]),
        SGNotedSection(@"Apple Music album", @[
            appleCatalogSwitch(),
            SGWithSymbol(SGStatActionRow(@"Open matching album",
                @"Find and open the album in Apple Music. Video artwork is not downloaded.",
                ^NSString *{ return SGRAppleCatalogStatus(); },
                ^{ SGRAppleCatalogOpenCurrent(); }), @"music.note"),
        ], @"Apple's public catalog lookup provides album metadata and a link, not licensed motion-video files. To show a moving cover inside Spotify, import a video that you have permission to use."),
        SGSection(nil, @[
            SGSwitchRow(@"Moving background", nil, SGRKeyPlayerMotion),
            SGOptionRow(@"Animated video artwork",
                        @"Play a user-supplied MP4/MOV animated cover for the current song, if available. Respects Reduce Motion and Low Power Mode.",
                        SGRKeyVideoArtwork),
            SGWithSymbol(SGActionRow(@"Import animated cover",
                        @"Choose an authorized video in Files for the song playing now.",
                        ^{ SGRImportVideoForPlayingTrack(); }), @"square.and.arrow.down"),
            SGOptionRow(@"Animated cover motion",
                        @"Moves still cover art, not original video. Respects Reduce Motion and Low Power Mode.",
                        SGRKeyArtworkMotion),
        ]),
    ] footer:nil];
}
