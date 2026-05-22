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
}>;

export type MiniGamePresentedEvent = NativeSyntheticEvent<{
  presented: boolean;
}>;

export type MiniGameNavigationKindRN = 'dot' | 'arrow' | 'pagination';

export interface SimulaMiniGameMenuProps extends ViewProps {
  visible?: boolean;
  charName?: string;
  charID?: string;
  charDescription?: string;
  charImageURL?: string;
  showBanner?: boolean;
  publisherAdDomain?: string;
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
