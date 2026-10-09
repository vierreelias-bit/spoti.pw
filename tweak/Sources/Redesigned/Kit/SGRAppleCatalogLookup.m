// EliSpot v30: optional Apple album matching via Apple's documented
// iTunes Search API (metadata only; no authentication or unofficial tokens).
// No HLS streams or protected motion-cover files are fetched. A matched
// album opens in Apple's own app/site where Apple controls presentation.
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "Shared/Player/PlayerState.h"
#import "SGRAppleCatalogLookup.h"

static NSMutableDictionary<NSString *, id> *sg_albumMatches; // NSURL or NSNull
static NSString *sg_currentAlbumKey;
static BOOL sg_searching;
static BOOL sg_started;

static NSString *fold(NSString *value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    NSString *normalized = [value stringByFoldingWithOptions:
        NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch locale:nil];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *word in [normalized componentsSeparatedByCharactersInSet:
                            NSCharacterSet.alphanumericCharacterSet.invertedSet]) {
        if (word.length) [parts addObject:word];
    }
    return [parts componentsJoinedByString:@" "];
}

static NSString *currentKey(NSString **artistOut, NSString **albumOut) {
    SPTPlayerTrack *track = SGPlayerState().track;
    NSDictionary *metadata = track.metadata;
    NSString *artist = [metadata[@"artist_name"] isKindOfClass:NSString.class]
        ? metadata[@"artist_name"] : track.artistName;
    NSString *album = [metadata[@"album_title"] isKindOfClass:NSString.class]
        ? metadata[@"album_title"] : nil;
    NSString *artistKey = fold(artist), *albumKey = fold(album);
    if (!artistKey.length || !albumKey.length) return nil;
    if (artistOut) *artistOut = artist;
    if (albumOut) *albumOut = album;
    return [NSString stringWithFormat:@"%@|%@", artistKey, albumKey];
}

static NSURL *matchingAlbum(NSDictionary *json, NSString *artist, NSString *album) {
    NSArray *results = [json[@"results"] isKindOfClass:NSArray.class] ? json[@"results"] : nil;
    NSString *artistKey = fold(artist), *albumKey = fold(album);
    for (NSDictionary *item in results) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *candidateArtist = fold(item[@"artistName"]);
        NSString *candidateAlbum = fold(item[@"collectionName"]);
        // Strict matching avoids accidentally associating a similarly
        // titled compilation or another performer's album with the song.
        if (![candidateArtist isEqualToString:artistKey] ||
            ![candidateAlbum isEqualToString:albumKey]) continue;
        NSString *address = item[@"collectionViewUrl"];
        NSURLComponents *components = [NSURLComponents componentsWithString:address];
        NSString *host = components.host.lowercaseString;
        if (![components.scheme.lowercaseString isEqualToString:@"https"] ||
            !([host isEqualToString:@"itunes.apple.com"] ||
              [host isEqualToString:@"music.apple.com"])) continue;
        return components.URL;
    }
    return nil;
}

static void searchAlbum(BOOL manuallyRequested) {
    NSAssert(NSThread.isMainThread, @"Apple album lookup runs on main");
    NSString *artist = nil, *album = nil;
    NSString *key = currentKey(&artist, &album);
    if (!key) {
        sg_currentAlbumKey = nil;
        return;
    }
    BOOL changed = ![sg_currentAlbumKey isEqualToString:key];
    if (changed) {
        sg_currentAlbumKey = [key copy];
        sg_searching = NO;
    }
    if (!manuallyRequested && !SGFlag(SGRKeyAppleAlbumLookup, NO)) return;
    if (!sg_albumMatches) sg_albumMatches = [NSMutableDictionary dictionary];
    if (sg_albumMatches[key] || sg_searching) return;
    sg_searching = YES;

    NSString *country = [[NSLocale.currentLocale objectForKey:NSLocaleCountryCode] uppercaseString];
    if (country.length != 2) country = @"FI";
    NSURLComponents *query = [NSURLComponents componentsWithString:@"https://itunes.apple.com/search"];
    query.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"term" value:
            [NSString stringWithFormat:@"%@ %@", artist, album]],
        [NSURLQueryItem queryItemWithName:@"media" value:@"music"],
        [NSURLQueryItem queryItemWithName:@"entity" value:@"album"],
        [NSURLQueryItem queryItemWithName:@"country" value:country],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"15"]
    ];
    NSURL *url = query.URL;
    if (!url) { sg_searching = NO; return; }
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = nil;
        if (data.length && !error)
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSInteger code = [response isKindOfClass:NSHTTPURLResponse.class]
            ? ((NSHTTPURLResponse *)response).statusCode : 0;
        NSURL *match = code == 200 && [json isKindOfClass:NSDictionary.class]
            ? matchingAlbum(json, artist, album) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![sg_currentAlbumKey isEqualToString:key]) return;
            sg_searching = NO;
            // Don't cache network failures, only real 200 search results.
            if (code == 200 && [json isKindOfClass:NSDictionary.class])
                sg_albumMatches[key] = match ?: NSNull.null;
        });
    }];
    [task resume];
}

@interface SGRAppleCatalogObserver : NSObject <SGPlayerStateObserver>
@property (nonatomic, copy) NSString *seenKey;
@end
@implementation SGRAppleCatalogObserver
- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *key = currentKey(NULL, NULL);
    if ([self.seenKey isEqualToString:key]) return;
    self.seenKey = [key copy];
    // Let the currently playing song trigger only one opt-in lookup.
    searchAlbum(NO);
}
@end

void SGRAppleCatalogStart(void) {
    if (sg_started) return;
    sg_started = YES;
    static SGRAppleCatalogObserver *observer;
    observer = [SGRAppleCatalogObserver new];
    SGAddPlayerStateObserver(observer);
    if (SGFlag(SGRKeyAppleAlbumLookup, NO)) searchAlbum(NO);
}

void SGRAppleCatalogSearchCurrent(void) {
    if (NSThread.isMainThread) searchAlbum(YES);
    else dispatch_async(dispatch_get_main_queue(), ^{ searchAlbum(YES); });
}

NSString *SGRAppleCatalogStatus(void) {
    NSString *key = currentKey(NULL, NULL);
    if (!key) return SGT(@"Play a song");
    if (sg_searching && [sg_currentAlbumKey isEqualToString:key])
        return SGT(@"Searching Apple Music");
    id match = sg_albumMatches[key];
    if ([match isKindOfClass:NSURL.class]) return SGT(@"Album found");
    if (match == NSNull.null) return SGT(@"No album match");
    return SGT(@"Not searched");
}

void SGRAppleCatalogOpenCurrent(void) {
    NSString *key = currentKey(NULL, NULL);
    NSURL *url = [sg_albumMatches[key] isKindOfClass:NSURL.class] ? sg_albumMatches[key] : nil;
    if (url) {
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        return;
    }
    // User explicitly opened the settings row, so an on-demand search is OK
    // even when automatic searching is disabled.
    SGRAppleCatalogSearchCurrent();
    UIViewController *top = SGTopController();
    if (!top) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"Apple Music album")
        message:SGT(@"Looking up this album. Return here shortly to open its Apple Music page. This does not import animated video.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SGT(@"OK")
        style:UIAlertActionStyleCancel handler:nil]];
    [top presentViewController:alert animated:YES completion:nil];
}
