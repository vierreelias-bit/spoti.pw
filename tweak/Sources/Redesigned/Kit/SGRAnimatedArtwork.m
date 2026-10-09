// EliSpot v30: real animated artwork when the user supplies a licensed
// local MP4/MOV/M4V for the playing song. Never accesses Apple Music streams,
// downloads copyrighted videos, or modifies entitlement checks.
#import "Core/SGCore.h"
#import "SGRAnimatedArtwork.h"
#import "SGRTokens.h"
#import "SGRBridges.h"
#import "Settings/SGPageStyle.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerState.h"
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static char kVideoSurfaceKey;
static NSHashTable<UIImageView *> *sg_videoCovers;
static BOOL sg_started;

static NSString *safeTrack(void) {
    NSString *track = SGKaraokePlayingTrack();
    if (track.length != 22) return nil;
    NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    return [track rangeOfCharacterFromSet:invalid].location == NSNotFound ? track : nil;
}

static NSURL *videoURL(NSString *track) {
    if (!track) return nil;
    NSString *folder = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/EliSpot/AnimatedArtwork"];
    return [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:
        [track stringByAppendingPathExtension:@"mp4"]]];
}

@interface SGRLocalVideoSurface : NSObject
@property (nonatomic, strong) AVQueuePlayer *player;
@property (nonatomic, strong) AVPlayerLooper *looper;
@property (nonatomic, strong) AVPlayerLayer *layer;
@property (nonatomic, copy) NSString *track;
- (void)stop;
- (void)updateForCover:(UIImageView *)cover;
@end

@implementation SGRLocalVideoSurface

- (void)stop {
    [self.player pause];
    [self.layer removeFromSuperlayer];
    self.layer.player = nil;
    [self.player removeAllItems];
    self.looper = nil;
    self.layer = nil;
    self.player = nil;
    self.track = nil;
}

- (void)dealloc {
    [self stop];
}

- (void)updateForCover:(UIImageView *)cover {
    NSString *track = safeTrack();
    NSURL *file = videoURL(track);
    BOOL active = SGRedesignedUI() && SGFlag(SGRKeyVideoArtwork, NO) &&
        !SGRReduceMotion() && !NSProcessInfo.processInfo.lowPowerModeEnabled &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        cover.window && track && [[NSFileManager defaultManager] fileExistsAtPath:file.path];
    if (active) {
        for (UIView *view = cover; view; view = view.superview)
            if (view.hidden || view.alpha < 0.01) { active = NO; break; }
    }
    if (!active) {
        [self stop];
        return;
    }
    if (![track isEqualToString:self.track] || !self.player) {
        [self stop];
        self.track = [track copy];
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:file];
        self.player = [AVQueuePlayer queuePlayerWithItems:@[]];
        self.player.muted = YES;
        self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        self.looper = [[AVPlayerLooper alloc] initWithPlayer:self.player templateItem:item];
        self.layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        // UIImageView's bitmap remains underneath as the natural fallback
        // while the video decodes its first frame.
        [cover.layer addSublayer:self.layer];
    }
    self.layer.frame = cover.bounds;
    if (self.layer.superlayer != cover.layer) [cover.layer addSublayer:self.layer];
    [self.player play];
}
@end

void SGRUpdateVideoArtwork(UIImageView *cover) {
    if (!cover) return;
    SGRLocalVideoSurface *surface = objc_getAssociatedObject(cover, &kVideoSurfaceKey);
    if (!surface) {
        surface = [SGRLocalVideoSurface new];
        objc_setAssociatedObject(cover, &kVideoSurfaceKey, surface,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [sg_videoCovers addObject:cover];
    [surface updateForCover:cover];
}

static void updateAllVideos(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ updateAllVideos(); });
        return;
    }
    for (UIImageView *cover in sg_videoCovers.allObjects) SGRUpdateVideoArtwork(cover);
}

@interface SGRVideoObserver : NSObject <SGPlayerStateObserver>
@property (nonatomic, copy) NSString *lastTrack;
@end

@implementation SGRVideoObserver
- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = safeTrack();
    if ([track isEqualToString:self.lastTrack]) return;
    self.lastTrack = [track copy];
    updateAllVideos();
}
@end

void SGRStartVideoArtworkObservers(void) {
    if (sg_started) return;
    sg_started = YES;
    sg_videoCovers = [NSHashTable weakObjectsHashTable];
    static SGRVideoObserver *observer;
    observer = [SGRVideoObserver new];
    SGAddPlayerStateObserver(observer);
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSNotificationName name in @[UIApplicationDidBecomeActiveNotification,
                UIApplicationWillResignActiveNotification,
                NSProcessInfoPowerStateDidChangeNotification,
                UIAccessibilityReduceMotionStatusDidChangeNotification,
                @"elispot.localAnimatedCoverChanged"]) {
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                       usingBlock:^(NSNotification *notice) { updateAllVideos(); }];
    }
}

static void showVideoNotice(NSString *message) {
    UIViewController *top = SGTopController();
    if (!top) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGT(@"Animated artwork")
        message:SGT(message) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SGT(@"OK")
        style:UIAlertActionStyleCancel handler:nil]];
    [top presentViewController:alert animated:YES completion:nil];
}

@interface SGRVideoImporter : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, copy) NSString *selectedTrack;
@end
@implementation SGRVideoImporter
- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject, *destination = videoURL(self.selectedTrack);
    if (!source || !destination) return;
    NSString *extension = source.pathExtension.lowercaseString;
    if (![@[@"mp4", @"mov", @"m4v"] containsObject:extension]) {
        showVideoNotice(@"Choose an MP4, MOV or M4V video that you may use.");
        return;
    }
    BOOL scoped = [source startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSNumber *size = nil;
    [source getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
    if (size.unsignedLongLongValue > 100ULL * 1024 * 1024) {
        if (scoped) [source stopAccessingSecurityScopedResource];
        showVideoNotice(@"Video is larger than 100 MB.");
        return;
    }
    [[NSFileManager defaultManager] createDirectoryAtURL:[destination URLByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:&error];
    if (!error) {
        // Document-picker returns a user-approved local copy, not a protected
        // Apple Music URL. Store it privately under this Spotify installation.
        [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:source toURL:destination error:&error];
    }
    if (scoped) [source stopAccessingSecurityScopedResource];
    if (error) showVideoNotice(@"Couldn't save the animated cover. Try a local MP4 file.");
    else {
        [NSNotificationCenter.defaultCenter postNotificationName:
            @"elispot.localAnimatedCoverChanged" object:nil];
        showVideoNotice(@"Animated cover added for the selected song.");
    }
}
@end

void SGRImportVideoForPlayingTrack(void) {
    NSString *track = safeTrack();
    if (!track) {
        showVideoNotice(@"Play a Spotify song first, then import its animated cover.");
        return;
    }
    static SGRVideoImporter *importer;
    if (!importer) importer = [SGRVideoImporter new];
    importer.selectedTrack = track;

    // Users can select only their own/authorized video files with Files.
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    for (NSString *ext in @[@"mp4", @"mov", @"m4v"]) {
        UTType *type = [UTType typeWithFilenameExtension:ext];
        if (type) [types addObject:type];
    }
    if (!types.count) [types addObject:UTTypeMovie];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = importer;
    [SGTopController() presentViewController:picker animated:YES completion:nil];
}
