// The Lyrics page's parts; App/Pages.m assembles the page.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h" // SGTopController()
#import "Lyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"

SGModSection *SGLyricsSourcesSection(BOOL namingSource) {
    SGModRow *sources = SGPageRow(@"Sources", ^UIViewController *{ return SGLyricsSourcesPage(); });
    // A long provider list becomes wider than the entire cell, pushing its
    // title beyond the left edge. The detail stays on the Sources page.
    sources.value = ^NSString *{
        NSUInteger count = SGLyricsOrder().count;
        if (!count) return SGT(@"Off");
        if (count == 1) return SGT(@"1 source");
        return [NSString stringWithFormat:@"%lu %@", (unsigned long)count, SGT(@"sources")];
    };
    SGModRow *allTracks = SGOptionRow(@"Lyrics where Spotify has none",
        @"Search your selected sources for missing lyrics.",
        SGKeyLyricsAllTracks);
    allTracks.info = @"A source must provide lyrics for the track. Turning this on cannot guarantee lyrics for every song. Restart Spotify after changing this option or the sources.";
    allTracks.changed = ^(BOOL on) {
        if (!on || SGLyricsEnabled()) return;
        // The network hooks require at least one configured source at startup.
        // Avoid saving a misleading ON state that cannot serve any lyrics.
        SGSetEnabled(SGKeyLyricsAllTracks, NO);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"No lyrics sources")
            message:SGT(@"Enable at least one lyrics source, then restart Spotify.")
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:SGT(@"OK") style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *top = SGTopController();
        [top presentViewController:alert animated:YES completion:nil];
    };
    SGModRow *test = SGActionRow(@"Test lyrics for current song",
        @"Check whether your enabled sources can find lyrics for the playing track.", ^{
        NSString *track = SGKaraokePlayingTrack();
        if (!SGLyricsEnabled() || !track.length) {
            NSString *message = SGLyricsEnabled()
                ? @"Play a song first, then try again."
                : @"Enable at least one source in Sources, then restart Spotify.";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"Lyrics source test")
                message:SGT(message) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:SGT(@"OK") style:UIAlertActionStyleCancel handler:nil]];
            [SGTopController() presentViewController:alert animated:YES completion:nil];
            return;
        }
        // Explicit diagnostic: query only the sources the user enabled.
        SGLyricsFetch(track, ^(SGLyricsResult *result) {
            NSString *detail = result.karaokeLines.count || result.texts.count
                ? [NSString stringWithFormat:@"%@: %@", SGT(@"Found lyrics"), SGLyricsProviderFor(result.provider).name ?: result.provider ?: @"source"]
                : SGT(@"No lyrics found for this track from the selected sources.");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"Lyrics source test")
                message:detail preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:SGT(@"OK") style:UIAlertActionStyleCancel handler:nil]];
            [SGTopController() presentViewController:alert animated:YES completion:nil];
        });
    });
    NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObjects:sources, allTracks, test, nil];
    if (namingSource) [rows addObject:SGOptionRow(@"Show source", nil, SGKeyLyricsCredit)];
    return SGNotedSection(@"Sources", rows,
        @"Lyrics only appear when a selected provider finds them. Restart Spotify after changing these settings.");
}

SGModRow *SGLockScreenLyricsRow(void) {
    return SGOptionRow(@"Lock screen lyrics", @"Current line in place of the artist", SGKeyLockScreenLyrics);
}

SGModRow *SGLyricsTranslationLanguageRow(void) {
    SGModRow *row = SGChoiceRow(@"Translation language", nil, SGKeyLyricsTranslationLanguage, SGLyricsTranslationLanguageNames(), 0);
    row.choiceFooter = @"Used when the lyrics come with translations. Any shows the first.";
    return row;
}

// Only the redesign's lyrics view sweeps words.
SGModRow *SGLyricsWordTimingRow(void) {
    return SGOptionRow(@"Simulate word timing", nil, SGKeyLyricsSimulateWords);
}
