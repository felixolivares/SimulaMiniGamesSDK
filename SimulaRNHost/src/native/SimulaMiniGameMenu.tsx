/**
 * **`SimulaMiniGameMenu`** — native **`MiniGameMenuView`** surfaced as a React Native component.
 */

import React from 'react';
import {
  type NativeSyntheticEvent,
  Platform,
  requireNativeComponent,
  type ViewProps,
} from 'react-native';

/** Payload for direct events from **`SimulaMiniGameMenu`**. */
export type MiniGameOpenCloseEvent = NativeSyntheticEvent<{
  name: string;
  description: string;
}>;

export type MiniGameImpressionEvent = NativeSyntheticEvent<{
  placement: string;
  gameTypeId: string;
  gameName: string;
  serveId?: string | null;
  adId?: string | null;
  showBanner: boolean;
}>;

export type MiniGameDestinationEvent = NativeSyntheticEvent<{
  url: string;
  /** Catalog hint (`GameData`), or inferred from the tapped **`url`** when the catalog row lacked it (**`apps.apple.com`** → **`appStore`**). */
  catalogDestinationHint?: 'appStore' | 'web' | 'unknown';
  /** Present when **`MiniGameMenuView`** attached a playable row (interstitial/playable taps). */
  focusedCatalogGameId?: string;
}>;

export type MiniGamePresentedEvent = NativeSyntheticEvent<{
  presented: boolean;
}>;

export type MiniGameNavigationKindRN = 'dot' | 'arrow' | 'pagination';

/**
 * Mirrors **`MiniGameTheme`** (**`simula-ad-sdk`** / web) plus optional native aliases (**`experienceTitleFontSize`**, **`catalogCardCornerRadius`**, …).
 * Forwarded verbatim to **`MiniGameThemePatch.bridging(fromJSObject:)`** on iOS.
 */
export type SimulaMiniGameMenuTheme = {
  backgroundColor?: string;
  headerColor?: string;
  borderColor?: string;
  titleFont?: string;
  secondaryFont?: string;
  titleFontColor?: string;
  secondaryFontColor?: string;
  /** Hero **“Play a game with…”** typography (`catalogHeroTitlePointSize`). */
  titleFontSize?: number;
  /** Playable chrome toolbar title (`experienceToolbarTitlePointSize`). */
  experienceTitleFontSize?: number;
  /** Alias for **`experienceTitleFontSize`**. */
  toolbarTitleFontSize?: number;
  /** Catalog loading line / muted body / pagination baseline. */
  secondaryFontSize?: number;
  /** Game tile footer title (`catalogCoverTitlePointSize`). */
  cardTitleFontSize?: number;
  iconCornerRadius?: number;
  /** Poster rounding (`catalogCoverCornerRadius`); **`iconCornerRadius`** still clips inlined iframe chrome. */
  catalogCardCornerRadius?: number;
  accentColor?: string;
  playableHeight?: number | string;
  playableBorderColor?: string;
};

export interface SimulaMiniGameMenuProps extends ViewProps {
  visible?: boolean;
  charName?: string;
  charID?: string;
  charDescription?: string;
  charImageURL?: string;
  showBanner?: boolean;
  publisherAdDomain?: string;
  /** Partial theme (**` NSDictionary`**) layered over **`MiniGameTheme.default`** in SwiftUI. */
  theme?: SimulaMiniGameMenuTheme;
  /** Catalog cap (closest of 3 / 6 / 9 supported by **`MaxGamesToShow`**). */
  maxGamesToShow?: number;
  navigationKind?: MiniGameNavigationKindRN;
  delegateCharacterInGame?: boolean;

  onGameOpen?: (event: MiniGameOpenCloseEvent) => void;
  onGameClose?: (event: MiniGameOpenCloseEvent) => void;
  onImpression?: (event: MiniGameImpressionEvent) => void;
  onDestinationOpen?: (event: MiniGameDestinationEvent) => void;
  /** Fires whenever native **`isPresented`** changes (backdrop / X dismissals as well as post-game **`onGameClose`**). Keep RN **`visible`** in sync here. */
  onPresentedChange?: (event: MiniGamePresentedEvent) => void;
}

type NativeSimulaMiniGameMenuProps = SimulaMiniGameMenuProps;

const RCTSimulaMiniGameMenu =
  Platform.OS === 'ios'
    ? requireNativeComponent<NativeSimulaMiniGameMenuProps>('SimulaMiniGameMenu')
    : null;

/**
 * Prefer **`Presentation`** layering in your app (**`Modal`**) so the fullscreen overlay behaves like **`MiniGameMenu`** on web.
 */
export function SimulaMiniGameMenu(props: SimulaMiniGameMenuProps): React.ReactElement | null {
  if (Platform.OS !== 'ios' || !RCTSimulaMiniGameMenu) {
    return null;
  }

  return <RCTSimulaMiniGameMenu collapsable={false} {...props} />;
}
