// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"
#import "Redesigned/Kit/SGRArtworkMotion.h"

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", nil, SGRHideBarConnect),
        ]),
        SGSection(@"Lyrics preview", @[
            SGOptionRow(@"Inline lyrics (experimental)",
                        @"Show two lyric lines between the album cover and the song title. Uses selected lyric sources if Spotify has none.",
                        SGRKeyInlineLyrics),
        ]),
        SGSection(nil, @[
            SGSwitchRow(@"Moving background", nil, SGRKeyPlayerMotion),
            SGOptionRow(@"Animated cover motion",
                        @"Moves still cover art, not original video. Respects Reduce Motion and Low Power Mode.",
                        SGRKeyArtworkMotion),
        ]),
    ] footer:nil];
}
