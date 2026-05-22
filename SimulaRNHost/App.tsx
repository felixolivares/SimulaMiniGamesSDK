/**
 * Simula RN host — boots the native **`SimulaAdSDK`** module and **`SimulaMiniGameMenu`** SwiftUI subtree.
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  Modal,
  Pressable,
  SafeAreaView,
  StatusBar,
  StyleSheet,
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

/** Replace before shipping; **`devMode: true`** matches Swift **`MiniGameProvider.devMode`**. */
const DEMO_API_KEY = 'YOUR_PUBLISHER_API_KEY_HERE';

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

  useEffect(() => {
    let cancelled = false;

    void (async () => {
      try {
        await SimulaAdSDK.configure(DEMO_API_KEY, true);
        await SimulaAdSDK.bootstrapSession();
        await SimulaAdSDK.loadCatalog();
        if (!cancelled) {
          logLifecycle('bootstrap', { configured: true });
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
    marginBottom: 20,
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
