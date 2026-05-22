import React

@objc(SimulaMiniGameMenuViewManager)
final class SimulaMiniGameMenuViewManager: RCTViewManager {

    override static func requiresMainQueueSetup() -> Bool { true }

    override func view() -> UIView! {
        MiniGameRNMenuHostView()
    }
}
