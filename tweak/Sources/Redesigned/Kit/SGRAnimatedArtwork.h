// Optional true motion covers for user-owned or otherwise authorized video.
// No access to Apple Music media streams, DRM or subscription entitlements.
#import <UIKit/UIKit.h>

#define SGRKeyVideoArtwork @"spotifyglass.redesign.videoArtwork"

void SGRUpdateVideoArtwork(UIImageView *cover);
void SGRStartVideoArtworkObservers(void);
void SGRImportVideoForPlayingTrack(void);
