import SwiftUI

/// Minimap preview of a saved window layout, showing window positions on each display.
struct LayoutPreviewView: View {
    let layout: WindowLayout

    private var displayGroups: [DisplayGroup] {
        let grouped = Dictionary(grouping: layout.windows, by: \.display)
        return grouped.map { (fingerprint, windows) in
            DisplayGroup(fingerprint: fingerprint, windows: windows)
        }
        .sorted { ($0.fingerprint.bounds.origin.x, $0.fingerprint.bounds.origin.y) < ($1.fingerprint.bounds.origin.x, $1.fingerprint.bounds.origin.y) }
    }

    var body: some View {
        if layout.windows.isEmpty {
            emptyState
        } else {
            multiDisplayPreview
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No windows saved")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var multiDisplayPreview: some View {
        GeometryReader { geo in
            let arranged = arrangeDisplays(in: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(Array(arranged.enumerated()), id: \.offset) { _, item in
                    displayView(item: item)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func displayView(item: ArrangedDisplay) -> some View {
        ZStack(alignment: .topLeading) {
            // Display background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            // Display label
            VStack {
                Text(item.group.fingerprint.localizedName ?? "Display")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
                Spacer()
            }
            .frame(width: item.rect.width)

            // Window tiles
            ForEach(Array(item.group.windows.enumerated()), id: \.offset) { _, window in
                windowTile(window: window, displayRect: item.rect)
            }
        }
        .frame(width: item.rect.width, height: item.rect.height)
        .offset(x: item.rect.origin.x, y: item.rect.origin.y)
    }

    private func windowTile(window: WindowSnapshot, displayRect: CGRect) -> some View {
        let inset: CGFloat = 2
        let usableWidth = displayRect.width - inset * 2
        let usableHeight = displayRect.height - 14 - inset
        let tileRect = CGRect(
            x: inset + window.relativeFrame.x * usableWidth,
            y: 14 + window.relativeFrame.y * usableHeight,
            width: max(window.relativeFrame.width * usableWidth, 8),
            height: max(window.relativeFrame.height * usableHeight, 8)
        )

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(windowColor(for: window).opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(windowColor(for: window).opacity(0.6), lineWidth: 0.5)
                )

            Text(window.appName.prefix(12))
                .font(.system(size: max(min(tileRect.height * 0.35, 9), 6)))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 2)
                .padding(.top, 1)
        }
        .frame(width: tileRect.width, height: tileRect.height)
        .offset(x: tileRect.origin.x, y: tileRect.origin.y)
        .help("\(window.appName)\(window.title.map { " — \($0)" } ?? "")")
    }

    // MARK: - Layout Calculation

    private struct ArrangedDisplay {
        var group: DisplayGroup
        var rect: CGRect
    }

    private func arrangeDisplays(in size: CGSize) -> [ArrangedDisplay] {
        guard !displayGroups.isEmpty else { return [] }

        // Calculate bounding box of all displays in CG coordinates
        let allBounds = displayGroups.map(\.fingerprint.bounds)
        let minX = allBounds.map(\.minX).min() ?? 0
        let minY = allBounds.map(\.minY).min() ?? 0
        let maxX = allBounds.map(\.maxX).max() ?? 1
        let maxY = allBounds.map(\.maxY).max() ?? 1
        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        guard totalWidth > 0, totalHeight > 0 else { return [] }

        let padding: CGFloat = 8
        let available = CGSize(
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )

        let scale = min(available.width / totalWidth, available.height / totalHeight)
        let scaledWidth = totalWidth * scale
        let scaledHeight = totalHeight * scale
        let offsetX = padding + (available.width - scaledWidth) / 2
        let offsetY = padding + (available.height - scaledHeight) / 2

        return displayGroups.map { group in
            let b = group.fingerprint.bounds
            let rect = CGRect(
                x: offsetX + (b.origin.x - minX) * scale,
                y: offsetY + (b.origin.y - minY) * scale,
                width: b.width * scale,
                height: b.height * scale
            )
            return ArrangedDisplay(group: group, rect: rect)
        }
    }

    // MARK: - Helpers

    private func windowColor(for window: WindowSnapshot) -> Color {
        let hash = window.appBundleID.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.8)
    }
}

// MARK: - Supporting Types

private struct DisplayGroup {
    var fingerprint: DisplayFingerprint
    var windows: [WindowSnapshot]
}

// MARK: - Preview Detail Panel

/// Shows layout metadata and window list alongside the minimap.
struct LayoutDetailView: View {
    let layout: WindowLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Minimap
            LayoutPreviewView(layout: layout)
                .frame(height: 160)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                metaRow("Windows", value: "\(layout.windows.count)")
                metaRow("Created", value: formatted(layout.createdAt))
                metaRow("Updated", value: formatted(layout.updatedAt))

                if let trigger = layout.trigger {
                    metaRow("Trigger", value: trigger.displayDescription)
                }
            }

            // Window list
            if !layout.windows.isEmpty {
                Text("Windows")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(layout.windows) { window in
                            windowRow(window)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .lineLimit(1)
        }
    }

    private func windowRow(_ window: WindowSnapshot) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(windowColor(for: window))
                .frame(width: 8, height: 8)
            Text(window.appName)
                .font(.system(size: 11))
                .lineLimit(1)
            if let title = window.title, !title.isEmpty {
                Text("— \(title)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(positionLabel(window.relativeFrame))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func windowColor(for window: WindowSnapshot) -> Color {
        let hash = window.appBundleID.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.8)
    }

    private func positionLabel(_ frame: RelativeFrame) -> String {
        let w = Int(frame.width * 100)
        let h = Int(frame.height * 100)
        return "\(w)x\(h)"
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
