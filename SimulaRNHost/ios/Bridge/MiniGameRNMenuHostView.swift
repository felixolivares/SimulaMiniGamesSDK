import React
import SimulaMiniGameSDK
import SwiftUI
import UIKit

final class MiniGameRNMenuHostViewModel: ObservableObject {
    @Published var presented: Bool = false

    @Published var charName: String = "Companion"
    @Published var charID: String = "rn-character"
    @Published var charImageURL: URL?
    /// Empty string behaves like nil for SwiftUI (**`MiniGameMenuView`** optional description).
    @Published var charDescription: String = ""

    @Published var showBanner: Bool = true
    /// Empty → nil (**`publisherAdDomain`**).
    @Published var publisherAdDomain: String = ""

    @Published var maxGames: MaxGamesToShow = .six
    @Published var navigationKind: MiniGameNavigationKind = .dot
    @Published var delegateCharacterInGame: Bool = true
    /** Raw **` NSDictionary`** forwarded from **`SimulaMiniGameMenu`** **`theme`** prop — bridged via **`MiniGameThemePatch.bridging`**. */
    @Published var theme: NSDictionary?

    weak var hostingView: MiniGameRNMenuHostView?
}

private struct MiniGameRNMenuSwiftUIView: View {
    @ObservedObject private var vm: MiniGameRNMenuHostViewModel

    init(viewModel: MiniGameRNMenuHostViewModel) {
        self._vm = ObservedObject(initialValue: viewModel)
    }

    private var descriptionForMenu: String? {
        let d = vm.charDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return d.isEmpty ? nil : d
    }

    private var domainForBanner: String? {
        let d = vm.publisherAdDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        return d.isEmpty ? nil : d
    }

    var body: some View {
        ZStack {
            if vm.presented {
                MiniGameMenuView(
                    provider: MiniGameRNBridge.shared.provider,
                    isPresented: Binding(
                        get: { vm.presented },
                        set: { vm.presented = $0 }
                    ),
                    charName: vm.charName,
                    charID: vm.charID,
                    charImageURL: vm.charImageURL,
                    charDescription: descriptionForMenu,
                    maxGamesToShow: vm.maxGames,
                    theme: .default,
                    themeOverrides: MiniGameThemePatch.bridging(fromJSObject: vm.theme as Any?),
                    navigationKind: vm.navigationKind,
                    messages: [],
                    conversationId: nil,
                    entryPoint: nil,
                    delegateCharacterInGame: vm.delegateCharacterInGame,
                    showBanner: vm.showBanner,
                    publisherAdDomain: domainForBanner,
                    onGameOpen: { name, description in
                        vm.hostingView?.emitGameOpen(name: name, description: description)
                    },
                    onGameClose: { name, description in
                        vm.hostingView?.emitGameClose(name: name, description: description)
                    },
                    onImpression: { ctx in
                        vm.hostingView?.emitImpression(ctx)
                    },
                    opensHTTPAdClicksInSystemSafari: false,
                    onAdDestinationWithContext: { ctx in
                        vm.hostingView?.handleAdDestinationInApp(ctx)
                    }
                )
            }
        }
        .onChange(of: vm.presented) { newValue in
            vm.hostingView?.emitPresentedChanged(newValue)
        }
    }
}

/// Native view hosting **`MiniGameMenuView`** for React Native (`SimulaMiniGameMenu`).
final class MiniGameRNMenuHostView: UIView {

    private let viewModel = MiniGameRNMenuHostViewModel()
    private var hostingController: UIHostingController<MiniGameRNMenuSwiftUIView>?

    @objc var onGameOpen: RCTDirectEventBlock?
    @objc var onGameClose: RCTDirectEventBlock?
    @objc var onImpression: RCTDirectEventBlock?
    @objc var onDestinationOpen: RCTDirectEventBlock?
    @objc var onPresentedChange: RCTDirectEventBlock?

    @objc var visible: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.presented = self?.visible ?? false
            }
        }
    }

    @objc var charName: NSString = "Companion" {
        didSet { viewModel.charName = charName as String }
    }

    @objc var charID: NSString = "rn-character" {
        didSet { viewModel.charID = charID as String }
    }

    @objc var charDescription: NSString? {
        didSet { viewModel.charDescription = (charDescription as String?) ?? "" }
    }

    @objc var charImageURL: NSString? {
        didSet {
            if let charImageURL, let url = URL(string: charImageURL as String) {
                viewModel.charImageURL = url
            } else {
                viewModel.charImageURL = nil
            }
        }
    }

    @objc var showBanner: Bool = true {
        didSet { viewModel.showBanner = showBanner }
    }

    @objc var publisherAdDomain: NSString? {
        didSet { viewModel.publisherAdDomain = (publisherAdDomain as String?) ?? "" }
    }

    @objc var maxGamesToShow: NSNumber? {
        didSet {
            let raw = maxGamesToShow?.intValue ?? 6
            viewModel.maxGames = MaxGamesToShow.clamping(raw)
        }
    }

    @objc var navigationKind: NSString? {
        didSet {
            guard let navigationKind else {
                viewModel.navigationKind = .dot
                return
            }
            switch (navigationKind as String).lowercased() {
            case "arrow":
                viewModel.navigationKind = .arrow
            case "pagination":
                viewModel.navigationKind = .pagination
            default:
                viewModel.navigationKind = .dot
            }
        }
    }

    @objc var delegateCharacterInGame: Bool = true {
        didSet { viewModel.delegateCharacterInGame = delegateCharacterInGame }
    }

    /// Partial palette + typography keyed like web **`MiniGameTheme`** (**`RCT_EXPORT`** **` NSDictionary`** → **`MiniGameThemePatch.bridging`**).
    @objc var theme: NSDictionary? {
        didSet { viewModel.theme = theme }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = true
        viewModel.hostingView = self

        let hc = UIHostingController(rootView: MiniGameRNMenuSwiftUIView(viewModel: viewModel))
        hc.view.backgroundColor = .clear
        hostingController = hc
        addSubview(hc.view)
    }

    deinit {
        if let hc = hostingController {
            hc.willMove(toParent: nil)
            hc.view.removeFromSuperview()
            hc.removeFromParent()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostingController?.view.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reconcileHostingParent()
    }

    /// Attach **`UIHostingController`** under the same **`UIViewController`** as the React root so modal safe-area / rotation behave like other RN children.
    private func reconcileHostingParent() {
        guard let hc = hostingController, window != nil else { return }
        guard let parentVC = rn_enclosingViewController() else { return }

        if hc.parent !== parentVC {
            hc.willMove(toParent: nil)
            hc.view.removeFromSuperview()
            hc.removeFromParent()

            parentVC.addChild(hc)
            addSubview(hc.view)
            hc.view.frame = bounds
            hc.didMove(toParent: parentVC)
        }
    }

    fileprivate func emitGameOpen(name: String, description: String) {
        onGameOpen?(["name": name, "description": description])
    }

    fileprivate func emitGameClose(name: String, description: String) {
        onGameClose?(["name": name, "description": description])
    }

    fileprivate func emitImpression(_ ctx: MiniGameShellImpressionContext) {
        onImpression?([
            "placement": ctx.placement,
            "gameTypeId": ctx.gameTypeId,
            "gameName": ctx.gameName,
            "serveId": ctx.serveId as Any,
            "adId": ctx.adId as Any,
            "showBanner": ctx.showBanner,
        ])
    }

    fileprivate func handleAdDestinationInApp(_ context: MiniGameAdDestinationContext) {
        emitDestinationPayload(context)

        DispatchQueue.main.async { [weak self] in
            guard let self, let presenter = rn_enclosingViewController() else { return }
            AdDestinationPresenter.present(context: context, from: presenter)
        }
    }

    fileprivate func emitDestinationPayload(_ context: MiniGameAdDestinationContext) {
        var payload: [String: Any] = [
            "url": context.url.absoluteString,
            "catalogDestinationHint": context.resolvedDestinationHint.rawValue,
        ]
        if let gid = context.focusedGame?.id {
            payload["focusedCatalogGameId"] = gid
        }
        onDestinationOpen?(payload)
    }

    fileprivate func emitPresentedChanged(_ presented: Bool) {
        onPresentedChange?(["presented": presented])
    }
}

private extension UIView {
    func rn_enclosingViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController {
                return vc
            }
            responder = current.next
        }
        return nil
    }
}
