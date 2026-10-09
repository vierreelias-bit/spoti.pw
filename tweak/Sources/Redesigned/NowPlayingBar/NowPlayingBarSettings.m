// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"
#import "Redesigned/Kit/SGRArtworkMotion.h"
#import "Redesigned/Kit/SGRAnimatedArtwork.h"

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", nil, SGRHideBarConnect),
        ]),
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
