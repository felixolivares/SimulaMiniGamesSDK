/**
 * Simula RN host — boots the native **`SimulaAdSDK`** module and **`SimulaMiniGameMenu`** SwiftUI subtree.
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  Modal,
  Platform,
  Pressable,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';

import { SimulaAdSDK } from './src/native/SimulaAdSDK';
import {
  SimulaMiniGameMenu,
  type MiniGameDestinationEvent,
  type MiniGameImpressionEvent,
  type MiniGameOpenCloseEvent,
  type MiniGamePresentedEvent,
} from './src/native/SimulaMiniGameMenu';

/** Publisher API key wired into **`SimulaAdSDK.configure`** (Swift **`MiniGameProvider`** bearer). */
const DEMO_API_KEY = 'pub_eeee14c661ce47659a289db29364723a';

/** `false` → live/production: real session + playable shell ad slots. `true` → dev shell (muted in-shell refresh). */
const SIMULA_DEV_MODE = false;

/**
 * Flip to **`true`** to **`console.log`** mapped catalog (**`[SimulaMiniGameSDK]`**) while Metro is attached to a
 * Release bundle (**`__DEV__`** **`false`**).
 */
const SIMULA_FORCE_SDK_MAPPED_CATALOG_METRO_LOG = false;

/**
 * Native **`Swift.print`** from **`SimulaMiniGameSDK`** never reaches Metro — only Xcode / device logs.
 * To see mapped catalog lines in Metro, **`SimulaAdSDK`** calls **`debugPeekCatalogMappedSummary`** from JS (below).
 */
const SIMULA_LOG_SDK_MAPPED_TO_METRO =
  (typeof __DEV__ !== 'undefined' && __DEV__) || SIMULA_FORCE_SDK_MAPPED_CATALOG_METRO_LOG;

/** Showcases **`RCT_EXPORT`** theme injection — aligns with web **`MiniGameTheme`** knobs. */
const SIMULA_NATIVE_MENU_THEME = {
  backgroundColor: '#0f172a',
  headerColor: '#1e293b',
  borderColor: '#38bdf8',
  titleFontColor: '#f8fafc',
  secondaryFontColor: '#94a3b8',
  accentColor: '#a855f7',
  playableBorderColor: '#334155',
  titleFont: 'rounded',
  secondaryFont: 'rounded',
  titleFontSize: 20,
  secondaryFontSize: 14,
  cardTitleFontSize: 17,
  iconCornerRadius: 10,
  catalogCardCornerRadius: 20,
  playableHeight: '82%',
};

function logLifecycle(tag: string, payload?: Record<string, unknown>): void {
  if (payload !== undefined) {
    console.log(`[SimulaRNHost:${tag}]`, payload);
    return;
  }
  console.log(`[SimulaRNHost:${tag}]`);
}

function App(): React.JSX.Element {
  const { width, height } = useWindowDimensions();
  const [menuVisible, setMenuVisible] = useState(false);
  /** When false, matches Swift demo with palette toggle off (native `MiniGameTheme.default`). */
  const [injectBridgedMenuTheme, setInjectBridgedMenuTheme] = useState(false);

  useEffect(() => {
    let cancelled = false;

    void (async () => {
      try {
        await SimulaAdSDK.configure(DEMO_API_KEY, SIMULA_DEV_MODE);
        await SimulaAdSDK.bootstrapSession();
        await SimulaAdSDK.loadCatalog();
        if (!cancelled) {
          logLifecycle('bootstrap', { configured: true, devMode: SIMULA_DEV_MODE });
        }
        if (
          SIMULA_LOG_SDK_MAPPED_TO_METRO &&
          !cancelled &&
          SimulaAdSDK.debugPeekCatalogMappedSummary
        ) {
          const peek = await SimulaAdSDK.debugPeekCatalogMappedSummary();
          console.log(peek);
        } else if (
          SIMULA_LOG_SDK_MAPPED_TO_METRO &&
          Platform.OS === 'ios' &&
          SimulaAdSDK.debugPeekCatalogMappedSummary == null
        ) {
          logLifecycle('native_peek_missing', {
            message:
              'Rebuild the iOS app (pod install); native SimulaAdSDK.debugPeekCatalogMappedSummary is unavailable.',
          });
        }
      } catch (error) {
        logLifecycle('bootstrap_error', {
          message: error instanceof Error ? error.message : String(error),
        });
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  const onGameOpen = useCallback((e: MiniGameOpenCloseEvent): void => {
    logLifecycle('onGameOpen', e.nativeEvent);
  }, []);

  const onGameClose = useCallback((e: MiniGameOpenCloseEvent): void => {
    logLifecycle('onGameClose', e.nativeEvent);
  }, []);

  const onImpression = useCallback((e: MiniGameImpressionEvent): void => {
    logLifecycle('onImpression', { ...e.nativeEvent });
  }, []);

  const onDestinationOpen = useCallback((e: MiniGameDestinationEvent): void => {
    logLifecycle('onDestinationOpen', e.nativeEvent);
  }, []);

  const onPresentedChange = useCallback((e: MiniGamePresentedEvent): void => {
    logLifecycle('onPresentedChange', e.nativeEvent);
    setMenuVisible(e.nativeEvent.presented);
  }, []);

  return (
    <SafeAreaView style={styles.root}>
      <StatusBar barStyle="light-content" />
      <View style={styles.content}>
        <Text style={styles.title}>Simula RN Host</Text>
        <Text style={styles.subtitle}>
          TypeScript • iOS 16+ • Swift SDK bridged via SimulaAdBridge
        </Text>

        <View style={styles.themeToggleRow}>
          <View style={styles.themeToggleCopy}>
            <Text style={styles.themeToggleTitle}>Inject JS theme into native menu</Text>
            <Text style={styles.themeToggleHint}>
              When off: Swift default styling. When on: bridged palette (NSDictionary → MiniGameThemePatch).
            </Text>
          </View>
          <Switch
            accessibilityLabel="Inject bridged menu theme"
            value={injectBridgedMenuTheme}
            onValueChange={setInjectBridgedMenuTheme}
            trackColor={{ false: '#334155', true: '#7c3aed' }}
            thumbColor="#f8fafc"
            ios_backgroundColor="#334155"
          />
        </View>

        <Pressable accessibilityRole="button" style={styles.cta} onPress={() => setMenuVisible(true)}>
          <Text style={styles.ctaLabel}>Open mini-game menu</Text>
        </Pressable>
      </View>

      <Modal
        visible={menuVisible}
        animationType="fade"
        presentationStyle="fullScreen"
        transparent
        onRequestClose={() => setMenuVisible(false)}>
        <SimulaMiniGameMenu
          style={[styles.menuHost, { width, height }]}
          visible={menuVisible}
          charName="RN Companion"
          charID="rn-host-character"
          charDescription="Bridged via SimulaMiniGameMenu"
          showBanner
          publisherAdDomain=""
          navigationKind="dot"
          {...(injectBridgedMenuTheme ? { theme: SIMULA_NATIVE_MENU_THEME } : {})}
          delegateCharacterInGame
          maxGamesToShow={6}
          onGameOpen={onGameOpen}
          onGameClose={onGameClose}
          onImpression={onImpression}
          onDestinationOpen={onDestinationOpen}
          onPresentedChange={onPresentedChange}
        />
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#0b1220',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: '#f8fafc',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    color: '#94a3b8',
    marginBottom: 16,
  },
  themeToggleRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
    marginBottom: 22,
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 12,
    backgroundColor: 'rgba(15, 23, 42, 0.72)',
    borderWidth: 1,
    borderColor: 'rgba(148, 163, 184, 0.2)',
    maxWidth: 420,
  },
  themeToggleCopy: {
    flex: 1,
    paddingRight: 4,
  },
  themeToggleTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#f1f5f9',
    marginBottom: 4,
  },
  themeToggleHint: {
    fontSize: 13,
    lineHeight: 18,
    color: '#94a3b8',
  },
  cta: {
    alignSelf: 'flex-start',
    paddingVertical: 12,
    paddingHorizontal: 18,
    backgroundColor: '#2563eb',
    borderRadius: 10,
  },
  ctaLabel: {
    color: '#f8fafc',
    fontSize: 16,
    fontWeight: '600',
  },
  menuHost: {
    flex: 1,
  },
});

export default App;
