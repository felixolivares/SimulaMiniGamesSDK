/**
 * Thin JS wrapper around the native **`SimulaAdSDK`** module (iOS).
 */

import { NativeModules, Platform } from 'react-native';

export type SimulaAdNativeModuleType = {
  configure: (apiKey: string, devMode: boolean) => Promise<void>;
  bootstrapSession: () => Promise<void>;
  loadCatalog: () => Promise<void>;
};

const IOS_STUB: SimulaAdNativeModuleType = {
  configure: async () => {
    throw new Error('SimulaAdSDK is iOS-only in this bootstrap host.');
  },
  bootstrapSession: async () => {},
  loadCatalog: async () => {},
};

export const SimulaAdSDK: SimulaAdNativeModuleType =
  Platform.OS === 'ios'
    ? (NativeModules.SimulaAdSDK as SimulaAdNativeModuleType | undefined) ?? IOS_STUB
    : IOS_STUB;
