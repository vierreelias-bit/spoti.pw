// EliSpot v30 experimental inline lyric preview.
// Shows two lyrics lines in the unused band between the artwork and song
// information without replacing Spotify's cover or full lyrics screen.
//
// Only the user's enabled lyrics providers are asked. No lyric strings are
// bundled or synthesized. The compact view never intercepts touches.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"
#import "Player.h"

static char kInlinePreviewKey, kInlineTitleKey;

@interface SGRInlineLyricsView : UIView
- (void)refresh;
@end

@implementation SGRInlineLyricsView {
    UILabel *_active;
    UILabel *_following;
    NSTimer *_clock;
    NSString *_track;
    NSArray<SGKaraokeLine *> *_lines;
    BOOL _requested;
    NSInteger _shownLine;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = NO;
    self.clipsToBounds = YES;

    _active = [UILabel new];
    _active.font = SGRFont(UIFontTextStyleTitle2, UIFontWeightBold,
                          UIContentSizeCategoryExtraExtraExtraLarge);
    _active.textColor = SGRPrimary();
    _active.numberOfLines = 2;
    _active.adjustsFontSizeToFitWidth = YES;
    _active.minimumScaleFactor = 0.8;
    _active.textAlignment = NSTextAlignmentLeft;

    _following = [UILabel new];
    _following.font = SGRFont(UIFontTextStyleHeadline, UIFontWeightSemibold,
                             UIContentSizeCategoryExtraExtraExtraLarge);
    _following.textColor = SGRSecondary();
    _following.numberOfLines = 2;
    _following.adjustsFontSizeToFitWidth = YES;
    _following.minimumScaleFactor = 0.8;
    _following.textAlignment = NSTextAlignmentLeft;

    [self addSubview:_active];
    [self addSubview:_following];
    _shownLine = NSNotFound;
    self.hidden = YES;
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat gap = 8.0;
    CGFloat usable = MAX(0, self.bounds.size.height - gap);
    CGFloat activeHeight = MIN(70, usable * 0.56);
    _active.frame = CGRectMake(0, 0, self.bounds.size.width, activeHeight);
    _following.frame = CGRectMake(0, activeHeight + gap, self.bounds.size.width,
                                  MAX(0, usable - activeHeight));
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_clock invalidate];
    _clock = nil;
    if (self.window) {
        __weak typeof(self) weakSelf = self;
        _clock = [NSTimer scheduledTimerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *timer) {
            [weakSelf refresh];
        }];
        [self refresh];
    }
}

- (void)refresh {
    if (!SGFlag(SGRKeyInlineLyrics, NO) || SGRPlayerLyricsOpen() || !self.window ||
        self.bounds.size.height < 68 || SGRPlayerIsTransitioning()) {
        self.hidden = YES;
        return;
    }
    NSString *track = SGKaraokePlayingTrack();
    if (!track.length) {
        self.hidden = YES;
        return;
    }
    if (![_track isEqualToString:track]) {
        _track = [track copy];
        _lines = nil;
        _requested = NO;
        _shownLine = NSNotFound;
        _active.text = nil;
        _following.text = nil;
        self.hidden = YES;
    }

    NSArray<SGKaraokeLine *> *known = SGKaraokeLinesForTrack(track);
    if (known.count && (!_lines.count ||
          SGKaraokeLinesTiming(known) < SGKaraokeLinesTiming(_lines))) {
        _lines = known;
        _shownLine = NSNotFound;
    }

    // Spotify's own page sometimes has no lyrics. Use only providers the user
    // selected, once per track, as a fallback to the cached native lines.
    if (!_lines.count && !_requested && SGLyricsEnabled()) {
        _requested = YES;
        NSString *askedFor = [track copy];
        __weak typeof(self) weakSelf = self;
        SGLyricsFetch(track, ^(SGLyricsResult *result) {
            SGRInlineLyricsView *preview = weakSelf;
            if (!preview || ![preview->_track isEqualToString:askedFor]) return;
            NSArray<SGKaraokeLine *> *received = result.karaokeLines;
            if (!received.count && result.texts.count) {
                if (result.synced && result.starts.count == result.texts.count)
                    received = SGKaraokeEstimatedLines(result.starts, result.texts);
                else
                    received = SGKaraokeStaticLines(result.texts);
            }
            if (received.count) {
                preview->_lines = received;
                preview->_shownLine = NSNotFound;
                // Share the recovered lyrics with the existing player lyrics
                // view instead of making a second disconnected lyric database.
                SGKaraokeKeepLines(askedFor, received);
                [preview refresh];
            }
        });
    }

    if (!_lines.count) {
        self.hidden = YES;
        return;
    }

    NSInteger position = SGKaraokePositionMs();
    NSInteger lineIndex = 0;
    if (position >= 0 && SGKaraokeLinesTiming(_lines) != SGKaraokeTimingNone) {
        lineIndex = MAX(0, SGKaraokeLeadLine(_lines, position));
    }
    lineIndex = MIN(lineIndex, (NSInteger)_lines.count - 1);
    if (_shownLine == lineIndex && !self.hidden) return;
    _shownLine = lineIndex;

    SGKaraokeLine *current = _lines[(NSUInteger)lineIndex];
    _active.text = SGKaraokeLineText(current);
    NSInteger nextIndex = lineIndex + 1;
    _following.text = nextIndex < (NSInteger)_lines.count
        ? SGKaraokeLineText(_lines[(NSUInteger)nextIndex]) : nil;
    self.hidden = !_active.text.length;
    self.accessibilityLabel = _following.text.length
        ? [NSString stringWithFormat:@"%@. %@", _active.text, _following.text]
        : _active.text;
}
@end

// Called from the same player layout hook as the existing lyrics overlay.
// The view stays out of UIKit stacks so it never changes playback controls'
// positions or swallows tap/seek gestures.
void SGRInlineLyricsRelayout(UIView *host) {
    if (!host || !SGFlag(SGRKeyInlineLyrics, NO)) return;
    SGRInlineLyricsView *preview = objc_getAssociatedObject(host, &kInlinePreviewKey);
    if (!preview) {
        preview = [[SGRInlineLyricsView alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(host, &kInlinePreviewKey, preview, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (preview.superview != host) [host addSubview:preview];

    UIView *title = SGRFindByIdentifier(host, @"now-playing-title-label", &kInlineTitleKey);
    CGRect cover = SGRPlayerCoverFrameIn(host);
    if (!title || CGRectIsNull(cover) || !title.window || SGRPlayerLyricsOpen()) {
        preview.hidden = YES;
        return;
    }
    CGRect titleFrame = [host convertRect:title.bounds fromView:title];
    CGFloat start = CGRectGetMaxY(cover) + 12;
    CGFloat end = CGRectGetMinY(titleFrame) - 12;
    CGFloat available = end - start;
    if (available < 86 || host.bounds.size.width < 200) {
        preview.hidden = YES;
        return;
    }
    CGFloat height = MIN(155, available);
    CGRect area = CGRectMake(30, start + (available - height) / 2.0,
                             host.bounds.size.width - 60, height);
    if (!CGRectEqualToRect(preview.frame, area)) preview.frame = area;
    [preview refresh];
}

void SGRInlineLyricsHide(UIView *host) {
    SGRInlineLyricsView *preview = objc_getAssociatedObject(host, &kInlinePreviewKey);
    preview.hidden = YES;
}
