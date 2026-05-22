import Foundation
import React

@objc(SimulaAdSDK)
final class SimulaAdSDK: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { true }

    @objc(configure:devMode:resolve:reject:)
    func configure(
        _ apiKey: NSString,
        devMode: Bool,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        DispatchQueue.main.async {
            MiniGameRNBridge.shared.configure(apiKey: apiKey as String, devMode: devMode)
            resolve(NSNull())
        }
    }

    @objc(bootstrapSession:reject:)
    func bootstrapSession(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            await MiniGameRNBridge.shared.provider.bootstrapSession()
            resolve(NSNull())
        }
    }

    @objc(loadCatalog:reject:)
    func loadCatalog(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            await MiniGameRNBridge.shared.provider.loadCatalog(force: true)
            resolve(NSNull())
        }
    }
}
