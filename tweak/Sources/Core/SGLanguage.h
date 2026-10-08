// EliSpot v30 language selection for the mod's own settings interface.
// Does not override Spotify's original localization or account language.
#import <Foundation/Foundation.h>

#define SGKeyLanguage @"spotifyglass.language"

NSArray<NSString *> *SGLanguageNames(void);
NSString *SGT(NSString *english);
