#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "About.h"
#import "App/Onboarding/Onboarding.h"

// Every key of the mod's is under one prefix, so a reset is a sweep of the defaults with the stock
// marker of SGPrefs.h left behind; the hooks read them at launch, so it ends in a restart.
static void resetAll(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSUInteger removed = 0;
    for (NSString *key in [store persistentDomainForName:NSBundle.mainBundle.bundleIdentifier].allKeys) {
        if (![key hasPrefix:@"spotifyglass."]) continue;
        [store removeObjectForKey:key];
        removed++;
    }
    [store setBool:YES forKey:SGKeyStock];
    SGLog(@"reset: removed %lu keys", (unsigned long)removed);
    SGRestartSpotify();
}

static void confirmReset(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset all settings?"
                                                                  message:@"Every switch goes off, flag overrides and the tab bar layout are cleared, and Spotify restarts as it came, with the mod doing nothing until asked. Spotify's own settings are untouched."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset and restart" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { resetAll(); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [SGTopController() presentViewController:alert animated:YES completion:nil];
}

static SGModRow *withSymbol(SGModRow *row, NSString *symbol) {
    row.symbol = symbol;
    return row;
}

// The changelog is available on demand. EliSpot never shows update/donation popups.
static UIViewController *v30WhatsNew(void) {
    return [[SGModPage alloc] initWithTitle:@"What's new"
        intro:@"EliSpot v30 is still in development. These changes are implemented in the v30 branch."
        sections:@[
            SGSection(@"Added so far", @[
                SGStatRow(@"Apple Music red accent", ^NSString *{ return @"Both looks"; }),
                SGStatRow(@"Album track artist switch", ^NSString *{ return @"Redesign"; }),
                SGStatRow(@"Optional album sections", ^NSString *{ return @"Redesign"; }),
                SGStatRow(@"Artist video visibility", ^NSString *{ return @"Redesign"; }),
                SGStatRow(@"Language selector", ^NSString *{ return @"7 choices"; }),
                SGStatRow(@"Apple Music-inspired preset", ^NSString *{ return @"Appearance"; }),
                SGStatRow(@"Ubuntu audio controls", ^NSString *{ return @"Speed / pitch / haptics"; }),
            ]),
            SGNotedSection(@"Planned", @[
                SGStatRow(@"0.50-style player and lyrics", ^NSString *{ return @"In progress"; }),
                SGStatRow(@"Tab bar and animated artwork", ^NSString *{ return @"In progress"; }),
            ], @"The complete progress list is in ELISPOT_V30_PLAN.md on GitHub."),
        ]
        footer:nil];
}

// Which build this is, whether GitHub has a newer release, and where to reach the mod: without these
// rows a build that is already installed has no way of telling its user that anything moved on.
UIViewController *SGAboutPage(void) {
    SGModRow *reset = withSymbol(SGActionRow(@"Reset all settings", nil, ^{ confirmReset(); }), @"trash");
    reset.color = SGRed();
    NSString *spotify = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    return [[SGModPage alloc] initWithTitle:@"Mod" intro:nil sections:@[
        SGSection(nil, @[
            SGStatRow(@"Version", ^NSString *{ return @(SG_VERSION); }),
            SGStatRow(@"Spotify", ^NSString *{ return spotify; }),
        ]),
        SGSection(nil, @[
            withSymbol(SGLinkRow(@"Website", nil, SGSiteURL), @"safari"),
            withSymbol(SGLinkRow(@"GitHub", nil, SGRepoURL), @"chevron.left.forwardslash.chevron.right"),
            withSymbol(SGActionRow(@"Welcome tour", nil, ^{ SGShowOnboarding(); }), @"map"),
            withSymbol(SGPageRow(@"What's new in v30", ^UIViewController *{ return v30WhatsNew(); }), @"sparkles"),
        ]),
        SGSection(nil, @[
            withSymbol(SGActionRow(@"Export settings", nil, ^{ SGExportSettings(); }), @"square.and.arrow.up"),
            withSymbol(SGActionRow(@"Import settings", nil, ^{ SGImportSettings(); }), @"square.and.arrow.down"),
        ]),
        SGSection(nil, @[reset]),
    ] footer:nil];
}
