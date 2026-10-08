#import "Donate.h"

// EliSpot: support/donation prompts are intentionally disabled.
// Keep no-op symbols so older call sites or future merges cannot make the build fail.

NSString *const SGKofiURL = @"";
UIColor *SGKofiColor(void) { return UIColor.clearColor; }

@implementation SGKofiButton
- (instancetype)initWithTitle:(NSString *)title prominent:(BOOL)prominent {
    (void)title;
    (void)prominent;
    return [super initWithFrame:CGRectZero];
}
@end

void SGShowDonateSheet(void) {}
SGModRow *SGDonateRow(void) { return nil; }
void SGWatchForDonate(void) {}
void SGDonateAfterTour(BOOL restarting) { (void)restarting; }
BOOL SGDonateAfterTourPending(void) { return NO; }
void SGOfferDonate(void) {}
