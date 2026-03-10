import CoreGraphics
import SwiftUI

struct DropZoneOverlayViewModel: Equatable {
    enum SnapPreview: Equatable {
        case leftHalf
        case rightHalf
        case topHalf
        case bottomHalf
    }

    struct ActivationBand: Equatable {
        let topInset: CGFloat
        let height: CGFloat
        let title: String
    }

    struct Section: Equatable, Identifiable {
        let id: String
        let title: String
        let items: [Item]
    }

    struct Item: Equatable, Identifiable {
        let id: String
        let title: String
        let preview: SnapPreview?
        let isActive: Bool
    }

    let activationBand: ActivationBand?
    let sections: [Section]

    static func make(
        from zones: [DropZone],
        activeZoneID: String? = nil,
        activationBandFrame: CGRect? = nil,
        screenFrame: CGRect? = nil
    ) -> DropZoneOverlayViewModel {
        let basicItems = zones
            .compactMap { zone -> Item? in
                guard case .basic(let action) = zone.target,
                      let preview = SnapPreview(action: action) else {
                    return nil
                }
                return Item(id: zone.id, title: zone.title, preview: preview, isActive: zone.id == activeZoneID)
            }

        var sections: [Section] = []
        if !basicItems.isEmpty {
            sections.append(Section(id: "snap", title: "Snap", items: basicItems))
        }

        let band: ActivationBand?
        if let activationBandFrame {
            band = ActivationBand(
                topInset: screenFrame.map { max(0, activationBandFrame.minY - $0.minY) } ?? 0,
                height: activationBandFrame.height,
                title: L10n.string("dropZone.activationBand")
            )
        } else {
            band = nil
        }

        return DropZoneOverlayViewModel(activationBand: band, sections: sections)
    }
}

struct DropZoneOverlayView: View {
    let model: DropZoneOverlayViewModel

    var body: some View {
        ZStack(alignment: .top) {
            if let band = model.activationBand {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .frame(height: band.height)

                    Text(band.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.top, band.topInset)
                .padding(.horizontal, 28)
            }

            VStack(alignment: .center, spacing: 18) {
                ForEach(model.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 14) {
                            ForEach(section.items) { item in
                                VStack(spacing: 10) {
                                    if let preview = item.preview {
                                        SnapPreviewIcon(preview: preview, isActive: item.isActive)
                                    }

                                    Text(item.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                }
                                    .frame(minWidth: 140, minHeight: 96)
                                    .background(item.isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.16))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(item.isActive ? 0.85 : 0.18), lineWidth: item.isActive ? 2 : 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.clear)
    }
}

extension DropZoneOverlayViewModel.SnapPreview {
    init?(action: WindowAction) {
        switch action {
        case .leftHalf:
            self = .leftHalf
        case .rightHalf:
            self = .rightHalf
        case .topHalf:
            self = .topHalf
        case .bottomHalf:
            self = .bottomHalf
        default:
            return nil
        }
    }

    func highlightRect(in bounds: CGRect) -> CGRect {
        switch self {
        case .leftHalf:
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width / 2, height: bounds.height)
        case .rightHalf:
            return CGRect(x: bounds.midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height)
        case .topHalf:
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height / 2)
        case .bottomHalf:
            return CGRect(x: bounds.minX, y: bounds.midY, width: bounds.width, height: bounds.height / 2)
        }
    }
}

private struct SnapPreviewIcon: View {
    let preview: DropZoneOverlayViewModel.SnapPreview
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: 44, height: 30)
            .overlay {
                GeometryReader { proxy in
                    let bounds = CGRect(origin: .zero, size: proxy.size)
                    let rect = preview.highlightRect(in: bounds)

                    Rectangle()
                        .fill(Color.white.opacity(isActive ? 0.85 : 0.45))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 0.9 : 0.45), lineWidth: 1.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
        }
}
