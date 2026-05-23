# SimulaRNHost

Minimal **React Native 0.76** + **TypeScript** host for the Task 2 **SimulaMiniGame Swift SDK → JS** bridge (`SimulaAdSDK`).

## Requirements

- Node 18+
- Xcode 15+ (iOS 16 Simulator or device)

## Setup

```bash
cd SimulaRNHost
npm install
cd ios && bundle install && bundle exec pod install && cd ..
```

(if you do not use Bundler, `cd ios && pod install && cd ..` is fine)

## Run (iOS)

```bash
npx react-native run-ios --simulator="iPhone 16 Pro"
```

Metro (if not started automatically):

```bash
npm start
```

## Notes

- **Deployment target**: iOS **16.0** (app target + Pods `post_install`).
- **Native bridge**: Repo-root **`SimulaMiniGameSDK.podspec`** exposes SwiftPM sources as **`SimulaMiniGameSDK`**; **`ios/SimulaAdBridge.podspec`** (`SimulaAdBridge`) adds **`SimulaAdSDK`** (`RCT_EXTERN_MODULE`) + **`SimulaMiniGameMenu`** view manager (Objective-C stubs in **`ios/Bridge/*.m`**). JS wrappers live under **`src/native/`**.
- **Single UI entry**: `App.tsx` — **`DEMO_API_KEY`** configures **`SimulaAdSDK`** on mount; tap **Open mini-game menu**, watch Metro **`console`** for **`[SimulaRNHost:…]`** lifecycle logs.
- **Theming (JS → native)**: Optional **`theme`** on **`SimulaMiniGameMenu`**; **`App.tsx`** includes a **Switch** (**Inject JS theme…**) mirroring **`SampleIntegrationViews`** “bridged palette” — off → **`MiniGameTheme.default`**, on → **`SIMULA_NATIVE_MENU_THEME`** via **`NSDictionary`**. See **`SimulaMiniGameMenuTheme`** in **`src/native/SimulaMiniGameMenu.tsx`**.
- **Debugging catalog / `Swift.print`**: Native **`Swift.print`** from **`SimulaMiniGameSDK`** (and **`RCTLog`**) goes to **Xcode’s Debug area / unified logs**, not Metro. After **`loadCatalog`**, **`App.tsx`** **`console.log`**s **`await SimulaAdSDK.debugPeekCatalogMappedSummary()`** when **`SIMULA_LOG_SDK_MAPPED_TO_METRO`** is on (bundled with **`__DEV__`**; set **`SIMULA_FORCE_SDK_MAPPED_CATALOG_METRO_LOG`** to **`true`** in **`App.tsx`** if Metro is attached to a **Release** bundle where **`__DEV__`** is **`false`**). Mapped lines are prefixed **`[SimulaMiniGameSDK]`**.
- **Android** artifacts exist from the RN template but are optional for this take-home; focus is iOS + native module bridge.

## Task 2 spec (summary)

From the assessment: native module wrapping Swift `MiniGameMenu` / `MiniGameProvider`, JS API aligned with [`simula-ad-sdk`](https://github.com/Simula-AI-SDK/simula-ad-sdk), theme pass-through, lifecycle callbacks (`onGameOpen`, `onGameClose`, `onImpression`, `onDestinationOpen`), and in-app **StoreKit** / **SFSafariViewController** for ad destinations (no external App Store / Safari).
