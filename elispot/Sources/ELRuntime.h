#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIWindow * _Nullable ELKeyWindow(void);
UIView * _Nullable ELFindSpotifyTabBar(UIView *rootView);
NSArray<UIView *> *ELSpotifyTabItems(UIView *tabBar);
NSInteger ELSpotifySelectedIndex(UIView *tabBar);
BOOL ELActivateSpotifyTab(UIView *tabBar, NSInteger index);
void ELFadeSpotifyTabBar(UIView *tabBar);
UIImage * _Nullable ELBestArtworkImage(UIView *rootView);
void ELHideStockNowPlayingView(UIView *rootView);

NS_ASSUME_NONNULL_END
