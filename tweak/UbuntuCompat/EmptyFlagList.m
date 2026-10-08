// EliSpot Ubuntu/WSL fallback when the Spotify-specific flag table has not
// been generated. With zero entries, the "All flags" list is simply empty.
// If SGFlagList.m is generated, the Makefile builds the real table instead.
#import "Shared/Flags/Flags.h"

const SGFlagDef SGFlagTable[] = {
    {NULL, SGFlagUnknown, 0, 0, 0},
};
const NSUInteger SGFlagCount = 0;
