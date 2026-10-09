// EliSpot v30: opt-in, official Apple iTunes catalog metadata search.
// This finds a matching Apple Music album link only. It does not fetch,
// download, decode or grant playback rights to Apple Music video artwork.
#import <Foundation/Foundation.h>

#define SGRKeyAppleAlbumLookup @"spotifyglass.redesign.appleAlbumLookup"

void SGRAppleCatalogStart(void);
void SGRAppleCatalogSearchCurrent(void);
NSString *SGRAppleCatalogStatus(void);
void SGRAppleCatalogOpenCurrent(void);
