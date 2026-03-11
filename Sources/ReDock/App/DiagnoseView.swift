import SwiftUI
import AppKit

/// Diagnostic check results for system permissions and app health.
struct DiagnoseView: View {
    @State private var checks: [DiagnosticCheck] = []
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("diagnose.title"))
                    .font(.headline)
                Spacer()
                Button(L10n.string("diagnose.runAll")) {
                    runDiagnostics()
                }
                .disabled(isRunning)
            }

            if checks.isEmpty {
                Text(L10n.string("diagnose.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(checks) { check in
                        DiagnosticRowView(check: check)
                    }
                }
            }
        }
    }

    private func runDiagnostics() {
        isRunning = true
        checks = DiagnosticRunner.runAll()
        isRunning = false
    }
}

// MARK: - Diagnostic Row

private struct DiagnosticRowView: View {
    let check: DiagnosticCheck

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name)
                    .font(.body)
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let action = check.action {
                Button(action.label) {
                    action.handler()
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch check.status {
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Model

struct DiagnosticCheck: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let status: Status
    let action: Action?

    enum Status {
        case passed
        case warning
        case failed
    }

    struct Action {
        let label: String
        let handler: () -> Void
    }
}

// MARK: - Runner

enum DiagnosticRunner {
    static func runAll() -> [DiagnosticCheck] {
        [
            checkAccessibility(),
            checkDisplays(),
            checkWindows(),
            checkLayouts(),
        ]
    }

    private static func checkAccessibility() -> DiagnosticCheck {
        let apiTrusted = AXIsProcessTrusted()

        // Also verify by actually reading the focused app via AX API
        let canReadWindows: Bool
        if apiTrusted {
            let systemWide = AXUIElementCreateSystemWide()
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(
                systemWide,
                kAXFocusedApplicationAttribute as CFString,
                &value
            )
            canReadWindows = (result == .success)
        } else {
            canReadWindows = false
        }

        let granted = apiTrusted && canReadWindows
        let detail: String
        if granted {
            detail = L10n.string("diagnose.granted")
        } else if apiTrusted && !canReadWindows {
            detail = L10n.string("diagnose.notGrantedToggleHint")
        } else {
            detail = L10n.string("diagnose.notGrantedToggleHint")
        }

        return DiagnosticCheck(
            name: L10n.string("diagnose.accessibility"),
            detail: detail,
            status: granted ? .passed : .failed,
            action: granted ? nil : DiagnosticCheck.Action(
                label: L10n.string("diagnose.requestPermission"),
                handler: {
                    _ = AppDelegate.services.permissions.check(promptIfNeeded: true)
                }
            )
        )
    }

    private static func checkDisplays() -> DiagnosticCheck {
        let count = NSScreen.screens.count
        let status: DiagnosticCheck.Status = count > 0 ? .passed : .failed
        return DiagnosticCheck(
            name: L10n.string("diagnose.displays"),
            detail: String(format: L10n.string("diagnose.displaysDetail"), count),
            status: status,
            action: nil
        )
    }

    private static func checkWindows() -> DiagnosticCheck {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let count: Int
        if let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] {
            count = list.filter { dict in
                guard let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
                      let layer = dict[kCGWindowLayer as String] as? Int else {
                    return false
                }
                return pid != ownPid && layer == 0
            }.count
        } else {
            count = 0
        }

        let status: DiagnosticCheck.Status
        let detail: String
        if count > 0 {
            status = .passed
            detail = String(format: L10n.string("diagnose.windowsDetail"), count)
        } else {
            status = .warning
            detail = L10n.string("diagnose.noWindows")
        }
        return DiagnosticCheck(
            name: L10n.string("diagnose.windows"),
            detail: detail,
            status: status,
            action: nil
        )
    }

    private static func checkLayouts() -> DiagnosticCheck {
        let store = AppDelegate.services.layoutStore
        let layouts = store.loadAll()
        let count = layouts.count
        return DiagnosticCheck(
            name: L10n.string("diagnose.layouts"),
            detail: String(format: L10n.string("diagnose.layoutsDetail"), count),
            status: count > 0 ? .passed : .warning,
            action: nil
        )
    }
}
