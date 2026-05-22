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
- **Single UI entry**: `App.tsx` — replace **`DEMO_API_KEY`**, tap **Open mini-game menu**, watch Metro **`console`** for **`[SimulaRNHost:…]`** lifecycle logs.
- **Android** artifacts exist from the RN template but are optional for this take-home; focus is iOS + native module bridge.

## Task 2 spec (summary)

From the assessment: native module wrapping Swift `MiniGameMenu` / `MiniGameProvider`, JS API aligned with [`simula-ad-sdk`](https://github.com/Simula-AI-SDK/simula-ad-sdk), theme pass-through, lifecycle callbacks (`onGameOpen`, `onGameClose`, `onImpression`, `onDestinationOpen`), and in-app **StoreKit** / **SFSafariViewController** for ad destinations (no external App Store / Safari).
