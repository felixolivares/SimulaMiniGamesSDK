#import <React/RCTViewManager.h>

// `RCT_EXTERN_MODULE` leaves the JS name empty (`moduleName` becomes `@""`), so
// `requireNativeComponent('SimulaMiniGameMenu')` cannot find a view config →
// "Cannot read property 'bubblingEventTypes' of null". Use REMAP explicitly.
@interface RCT_EXTERN_REMAP_MODULE(SimulaMiniGameMenu, SimulaMiniGameMenuViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(visible, BOOL)
RCT_EXPORT_VIEW_PROPERTY(charName, NSString)
RCT_EXPORT_VIEW_PROPERTY(charID, NSString)
RCT_EXPORT_VIEW_PROPERTY(charDescription, NSString)
RCT_EXPORT_VIEW_PROPERTY(charImageURL, NSString)

RCT_EXPORT_VIEW_PROPERTY(showBanner, BOOL)
RCT_EXPORT_VIEW_PROPERTY(publisherAdDomain, NSString)
RCT_EXPORT_VIEW_PROPERTY(maxGamesToShow, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(navigationKind, NSString)
RCT_EXPORT_VIEW_PROPERTY(delegateCharacterInGame, BOOL)

RCT_EXPORT_VIEW_PROPERTY(onGameOpen, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onGameClose, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onImpression, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDestinationOpen, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPresentedChange, RCTDirectEventBlock)

@end
