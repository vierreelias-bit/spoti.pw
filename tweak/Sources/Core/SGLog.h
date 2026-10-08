#import <Foundation/Foundation.h>
#import <os/log.h>

// Render the NSString formatting outside the os_log macro. Passing a no-argument
// NSString literal directly to stringWithFormat from a macro triggers -Wformat-security
// with the older iOS SDK used by Ubuntu/WSL. A normal variadic function accepts both
// SGLog(@"message") and SGLog(@"value %@", value) without that false positive.
FOUNDATION_EXPORT void SGLogMessage(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
#define SGLog(...) SGLogMessage(__VA_ARGS__)

// Long dumps, split into numbered parts under the unified log's size cap.
void SGLogLong(NSString *tag, NSString *text);
// Logs every class of the list that this Spotify does not have; a feature calls it from its %ctor.
void SGRequireClasses(NSArray<NSString *> *names);
