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
// Cancel outdated requests and ignore their late callbacks.
static NSURLSessionDataTask *sg_activeTask;
static NSUInteger sg_lookupGeneration;
static NSString *sg_pendingOpenKey;

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
    id albumField = metadata[@"album_title"] ?: metadata[@"album_name"];
    NSString *album = [albumField isKindOfClass:NSString.class] ? albumField : nil;
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

static void showLookupNotice(NSString *message) {
    UIViewController *top = SGTopController();
    if (!top) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"Apple Music album")
        message:SGT(message) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SGT(@"OK")
        style:UIAlertActionStyleCancel handler:nil]];
    [top presentViewController:alert animated:YES completion:nil];
}

static void searchAlbum(BOOL manuallyRequested) {
    NSAssert(NSThread.isMainThread, @"Apple album lookup runs on main");
    NSString *artist = nil, *album = nil;
    NSString *key = currentKey(&artist, &album);
    if (!key) {
        if (sg_currentAlbumKey || sg_searching) {
            ++sg_lookupGeneration;
            [sg_activeTask cancel];
            sg_activeTask = nil;
        }
        sg_currentAlbumKey = nil;
        sg_pendingOpenKey = nil;
        sg_searching = NO;
        return;
    }
    if (![sg_currentAlbumKey isEqualToString:key]) {
        ++sg_lookupGeneration;
        [sg_activeTask cancel];
        sg_activeTask = nil;
        sg_currentAlbumKey = [key copy];
        sg_pendingOpenKey = nil;
        sg_searching = NO;
    }
    if (!manuallyRequested && !SGFlag(SGRKeyAppleAlbumLookup, NO)) return;
    if (!sg_albumMatches) sg_albumMatches = [NSMutableDictionary dictionary];
    if (sg_albumMatches[key] || sg_searching) return;
    sg_searching = YES;
    NSUInteger generation = ++sg_lookupGeneration;

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
        BOOL succeeded = code == 200 && [json isKindOfClass:NSDictionary.class];
        NSURL *match = succeeded ? matchingAlbum(json, artist, album) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Never show or open an answer for the wrong song.
            if (generation != sg_lookupGeneration ||
                ![sg_currentAlbumKey isEqualToString:key] ||
                ![currentKey(NULL, NULL) isEqualToString:key]) return;
            sg_searching = NO;
            sg_activeTask = nil;
            // Cache real search results but never a failed network request.
            if (succeeded) {
                if (sg_albumMatches.count >= 128) [sg_albumMatches removeAllObjects];
                sg_albumMatches[key] = match ?: NSNull.null;
            }
            if ([sg_pendingOpenKey isEqualToString:key]) {
                sg_pendingOpenKey = nil;
                if (match) {
                    [UIApplication.sharedApplication openURL:match options:@{} completionHandler:nil];
                } else {
                    showLookupNotice(succeeded ? @"No matching album found in Apple Music."
                                               : @"Apple Music search failed. Try again.");
                }
            }
        });
    }];
    sg_activeTask = task;
    [task resume];
}

@interface SGRAppleCatalogObserver : NSObject <SGPlayerStateObserver>
@property (nonatomic, copy) NSString *seenTrack;
@property (nonatomic, copy) NSString *seenKey;
@end
@implementation SGRAppleCatalogObserver
- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *trackURI = SGURIString(state.track.URI);
    NSString *key = currentKey(NULL, NULL);
    if ([self.seenTrack isEqualToString:trackURI] &&
        [self.seenKey isEqualToString:key]) return;
    self.seenTrack = [trackURI copy];
    self.seenKey = [key copy];
    searchAlbum(NO);

    // Spotify can first report a song before its album metadata is ready.
    // Recheck twice without contacting Apple until album data exists.
    if (trackURI.length && !key && SGFlag(SGRKeyAppleAlbumLookup, NO)) {
        for (NSNumber *delay in @[@1, @3]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                           (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (![SGURIString(SGPlayerState().track.URI) isEqualToString:trackURI]) return;
                NSString *now = currentKey(NULL, NULL);
                if (!now.length || [self.seenKey isEqualToString:now]) return;
                self.seenKey = [now copy];
                searchAlbum(NO);
            });
        }
    }
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
    if (!key) return SGT(SGPlayerState().track ? @"Album info unavailable" : @"Play a song");
    if (sg_searching && [sg_currentAlbumKey isEqualToString:key])
        return SGT(@"Searching Apple Music");
    id match = sg_albumMatches[key];
    if ([match isKindOfClass:NSURL.class]) return SGT(@"Album found");
    if (match == NSNull.null) return SGT(@"No album match");
    return SGT(@"Not searched");
}

void SGRAppleCatalogOpenCurrent(void) {
    NSString *key = currentKey(NULL, NULL);
    if (!key) {
        showLookupNotice(SGPlayerState().track
            ? @"Album info unavailable for this song."
            : @"Play a song to find its album.");
        return;
    }
    id cached = sg_albumMatches[key];
    if ([cached isKindOfClass:NSURL.class]) {
        [UIApplication.sharedApplication openURL:cached options:@{} completionHandler:nil];
        return;
    }
    // A manual tap can retry a prior "not found" result.
    if (cached == NSNull.null) [sg_albumMatches removeObjectForKey:key];
    searchAlbum(YES);
    // If there is already a lookup running, open as soon as it finishes.
    if (sg_searching) sg_pendingOpenKey = [key copy];
    else showLookupNotice(@"Apple Music search failed. Try again.");
}
