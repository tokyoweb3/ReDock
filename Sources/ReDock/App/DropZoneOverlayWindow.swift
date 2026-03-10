import AppKit
import SwiftUI

final class DropZoneOverlayWindow {
    private var panel: NSPanel?
    private var zones: [DropZone] = []
    private var activeZoneID: String?
    private var activationBandFrame: CGRect?
    private var screenFrame: CGRect?

    func show(on screen: NSScreen, zones: [DropZone], activationBandFrame: CGRect? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.zones = zones
            self?.activeZoneID = nil
            self?.activationBandFrame = activationBandFrame
            self?.screenFrame = ScreenGeometry.frameInCG(for: screen)
            self?.showOnMainThread(screen: screen)
        }
    }

    func updateActiveZone(_ id: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.activeZoneID = id
            self?.refreshContent()
        }
    }

    func update(zones: [DropZone], activeZoneID: String?, activationBandFrame: CGRect?) {
        DispatchQueue.main.async { [weak self] in
            self?.zones = zones
            self?.activeZoneID = activeZoneID
            self?.activationBandFrame = activationBandFrame
            self?.refreshContent()
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.zones = []
            self?.activeZoneID = nil
            self?.activationBandFrame = nil
            self?.screenFrame = nil
        }
    }

    private func showOnMainThread(screen: NSScreen) {
        panel?.orderOut(nil)
        panel = nil

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel

        refreshContent()
        panel.orderFrontRegardless()
    }

    private func refreshContent() {
        guard let panel else { return }
        panel.contentView = NSHostingView(
            rootView: DropZoneOverlayView(
                model: DropZoneOverlayViewModel.make(
                    from: zones,
                    activeZoneID: activeZoneID,
                    activationBandFrame: activationBandFrame,
                    screenFrame: screenFrame
                )
            )
        )
    }
}
