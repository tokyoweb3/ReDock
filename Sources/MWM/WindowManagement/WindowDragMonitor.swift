import AppKit

final class WindowDragMonitor {
    private static let minimumWindowDragDistance: CGFloat = 12

    private let windowQuerying: WindowQuerying
    private let screenRegistry: ScreenRegistry
    private let overlayWindow: DropZoneOverlayWindow
    private let placementService: WindowPlacementService
    private let activationBandHeightProvider: () -> CGFloat

    private var draggedMonitor: Any?
    private var mouseUpMonitor: Any?
    private var session: DropZoneSession?
    private var pendingWindow: WindowInfo?
    private var pendingWindowInitialFrame: CGRect?

    init(
        windowQuerying: WindowQuerying,
        screenRegistry: ScreenRegistry,
        overlayWindow: DropZoneOverlayWindow,
        placementService: WindowPlacementService,
        activationBandHeightProvider: @escaping () -> CGFloat = { AppSettings.defaultDropZoneActivationBandHeight }
    ) {
        self.windowQuerying = windowQuerying
        self.screenRegistry = screenRegistry
        self.overlayWindow = overlayWindow
        self.placementService = placementService
        self.activationBandHeightProvider = activationBandHeightProvider
    }

    func start() {
        guard draggedMonitor == nil, mouseUpMonitor == nil else { return }

        draggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.handleDrag(at: NSEvent.mouseLocation)
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.handleMouseUp()
        }
    }

    func stop() {
        if let draggedMonitor {
            NSEvent.removeMonitor(draggedMonitor)
            self.draggedMonitor = nil
        }

        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }

        overlayWindow.hide()
        session = nil
        pendingWindow = nil
        pendingWindowInitialFrame = nil
    }

    deinit {
        stop()
    }

    private func handleDrag(at point: CGPoint) {
        DispatchQueue.main.async { [weak self] in
            let cgPoint = ScreenGeometry.globalMousePointToCG(point)
            self?.handleDragOnMain(at: cgPoint)
        }
    }

    private func handleDragOnMain(at point: CGPoint) {
        guard let screen = screen(containing: point) else {
            return
        }

        let hadSession = session != nil
        let previousScreenFrame = session?.screen.map { ScreenGeometry.frameInCG(for: $0) }
        let screenFrame = ScreenGeometry.frameInCG(for: screen)

        let window: WindowInfo
        if let existingSession = session {
            window = existingSession.window
        } else {
            guard let focusedWindow = windowQuerying.focusedWindow(),
                  focusedWindow.isResizable,
                  let draggedWindow = resolveDraggedWindow(from: focusedWindow) else {
                return
            }
            window = draggedWindow
        }

        let visibleFrame = screenRegistry.visibleFrame(for: screen)
        let activationBandFrame = CGRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: visibleFrame.width,
            height: activationBandHeightProvider()
        )

        var currentSession = session ?? DropZoneSession(window: window, screen: screen, screenFrame: visibleFrame)
        currentSession.screen = screen
        currentSession.screenFrame = visibleFrame

        let zones = DropZoneResolver.basicZones(in: visibleFrame)
        let shouldShowZones = Self.shouldKeepDropZonesVisible(
            point: point,
            visibleFrame: visibleFrame,
            bandHeight: activationBandHeightProvider(),
            zones: zones
        )
        currentSession.zones = shouldShowZones ? zones : []
        currentSession.updateHover(at: point)
        self.session = currentSession

        let needsRehost = Self.shouldRehostOverlay(
            currentScreenFrame: previousScreenFrame,
            nextScreenFrame: screenFrame
        )

        if !hadSession || needsRehost {
            overlayWindow.show(
                on: screen,
                zones: currentSession.zones,
                activationBandFrame: activationBandFrame
            )
            overlayWindow.updateActiveZone(currentSession.activeZoneID)
        } else {
            overlayWindow.update(
                zones: currentSession.zones,
                activeZoneID: currentSession.activeZoneID,
                activationBandFrame: activationBandFrame
            )
        }
    }

    private func handleMouseUp() {
        DispatchQueue.main.async { [weak self] in
            self?.handleMouseUpOnMain()
        }
    }

    private func handleMouseUpOnMain() {
        guard var session else { return }

        if let target = session.activeTarget, let screen = session.screen {
            placementService.apply(target: target, to: session.window, on: screen)
        }

        overlayWindow.hide()
        session.end()
        self.session = nil
        pendingWindow = nil
        pendingWindowInitialFrame = nil
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        screenRegistry.sortedScreens.first { screen in
            ScreenGeometry.frameInCG(for: screen).contains(point)
        }
    }

    private func resolveDraggedWindow(from focusedWindow: WindowInfo) -> WindowInfo? {
        if let pendingWindow, !Self.isSameWindow(pendingWindow, focusedWindow) {
            self.pendingWindow = focusedWindow
            pendingWindowInitialFrame = focusedWindow.frame
            return nil
        }

        if pendingWindow == nil {
            pendingWindow = focusedWindow
            pendingWindowInitialFrame = focusedWindow.frame
            return nil
        }

        guard let initialFrame = pendingWindowInitialFrame else {
            pendingWindowInitialFrame = focusedWindow.frame
            return nil
        }

        guard Self.isMeaningfulWindowDrag(initialFrame: initialFrame, currentFrame: focusedWindow.frame) else {
            return nil
        }

        pendingWindow = nil
        pendingWindowInitialFrame = nil
        return focusedWindow
    }

    static func isWithinActivationBand(point: CGPoint, visibleFrame: CGRect, bandHeight: CGFloat) -> Bool {
        point.y <= visibleFrame.minY + bandHeight
    }

    static func isMeaningfulWindowDrag(initialFrame: CGRect, currentFrame: CGRect) -> Bool {
        let deltaX = currentFrame.origin.x - initialFrame.origin.x
        let deltaY = currentFrame.origin.y - initialFrame.origin.y
        return hypot(deltaX, deltaY) >= minimumWindowDragDistance
    }

    static func shouldKeepDropZonesVisible(
        point: CGPoint,
        visibleFrame: CGRect,
        bandHeight: CGFloat,
        zones: [DropZone]
    ) -> Bool {
        isWithinActivationBand(point: point, visibleFrame: visibleFrame, bandHeight: bandHeight) ||
        zones.contains { $0.frame.contains(point) }
    }

    static func shouldRehostOverlay(currentScreenFrame: CGRect?, nextScreenFrame: CGRect) -> Bool {
        currentScreenFrame != nextScreenFrame
    }

    private static func isSameWindow(_ lhs: WindowInfo, _ rhs: WindowInfo) -> Bool {
        CFEqual(lhs.element.element, rhs.element.element)
    }
}
